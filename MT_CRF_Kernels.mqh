#ifndef MT_CRF_KERNELS_MQH
#define MT_CRF_KERNELS_MQH

// Small closed-bar primitives only. This is NOT a complete CRF forecast or
// order engine. The candidate must be created on an earlier closed M15 bar;
// callers must invoke this at most once for each later closed M15 bar.
enum CRF_CONFIRM_EVENT
{
   CRF_CONFIRM_INVALID = -1,
   CRF_CONFIRM_WAIT = 0,
   CRF_CONFIRM_BUY = 1,
   CRF_CONFIRM_SELL = 2,
   CRF_CONFIRM_EXPIRED = 3
};

bool CRFValidPrice(const double x)
{
   return MathIsValidNumber(x) && x != EMPTY_VALUE;
}

CRF_CONFIRM_EVENT CRFAdvanceConfirmation(const int direction,
                                         const double break_level,
                                         const double closed_price,
                                         int &elapsed)
{
   if((direction != 1 && direction != -1) || elapsed < 0 || elapsed >= 2 ||
      !CRFValidPrice(break_level) || !CRFValidPrice(closed_price))
      return CRF_CONFIRM_INVALID;
   elapsed++;
   if(direction == 1 && closed_price > break_level) return CRF_CONFIRM_BUY;
   if(direction == -1 && closed_price < break_level) return CRF_CONFIRM_SELL;
   if(elapsed >= 2) return CRF_CONFIRM_EXPIRED;
   return CRF_CONFIRM_WAIT;
}

// Indie bar-touch results are display statistics, NOT broker fill evidence.
// 0 = still active, 1 = target, 2 = stop, 4 = hard duration expiry.
int CRFBarResult(const int direction, const double stop, const double target,
                 const double high, const double low, const int remaining_after_bar)
{
   if((direction != 1 && direction != -1) || !CRFValidPrice(stop) ||
      !CRFValidPrice(target) || !CRFValidPrice(high) || !CRFValidPrice(low) ||
      high < low || remaining_after_bar < 0 ||
      (direction == 1 && stop >= target) || (direction == -1 && stop <= target))
      return -1;
   if(direction == 1)
   {
      if(low <= stop) return 2;
      if(high >= target) return 1;
   }
   else
   {
      if(high >= stop) return 2;
      if(low <= target) return 1;
   }
   if(remaining_after_bar == 0) return 4;
   return 0;
}
// Chronological closed bars (oldest first). This extracts the candidate only;
// the caller supplies a complete history and separately manages confirmation,
// cooldown, historical analogs and broker state.
struct CRFCandidate
{
   int direction, pattern, variant;
   double break_level, stop, marker, atr, volume, trend, location;
};

bool CRFDetectAt(const MqlRates &bars[], const int i, const int atr_len,
                 const int trend_len, const int volume_len, const int swing_len,
                 CRFCandidate &out)
{
   out.direction=0; out.pattern=0; out.variant=0;
   out.break_level=EMPTY_VALUE; out.stop=EMPTY_VALUE; out.marker=EMPTY_VALUE;
   out.atr=0; out.volume=1; out.trend=0; out.location=0;
   if(atr_len < 2 || trend_len < 2 || volume_len < 2 || swing_len < 3 ||
      i >= ArraySize(bars) || i < atr_len || i < trend_len ||
      i < volume_len || i < swing_len || i < 2) return false;
   int lookback = (int)MathMax(MathMax(atr_len, trend_len), MathMax(volume_len, swing_len));
   for(int j=i-lookback; j<=i; j++)
   {
      if(!CRFValidPrice(bars[j].open) || !CRFValidPrice(bars[j].high) ||
         !CRFValidPrice(bars[j].low) || !CRFValidPrice(bars[j].close) ||
         bars[j].high < bars[j].low || bars[j].open > bars[j].high ||
         bars[j].open < bars[j].low || bars[j].close > bars[j].high ||
         bars[j].close < bars[j].low) return false;
   }
   double tr=0;
   for(int k=0; k<atr_len; k++)
   {
      int j=i-k;
      double true_range=bars[j].high-bars[j].low;
      if(bars[j-1].close>bars[j].high) true_range=bars[j-1].close-bars[j].low;
      else if(bars[j-1].close<bars[j].low) true_range=bars[j].high-bars[j-1].close;
      tr+=true_range;
   }
   double atr=tr/atr_len;
   if(!MathIsValidNumber(atr)) return false;
   // Zero ATR means no new candidate, not missing data: an existing pending
   // candidate and active forecast still advance on this closed bar.
   if(atr<=0) return true;
   double volume_sum=0, swing_low=bars[i-1].low, swing_high=bars[i-1].high;
   for(int k=1;k<=volume_len;k++) volume_sum+=(double)bars[i-k].tick_volume;
   for(int k=1;k<=swing_len;k++)
   {
      swing_low=MathMin(swing_low,bars[i-k].low);
      swing_high=MathMax(swing_high,bars[i-k].high);
   }
   double average=volume_sum/volume_len, volume=1;
   if(average>0 && bars[i].tick_volume>=0) volume=(double)bars[i].tick_volume/average;
   double bull_trend=(bars[i-trend_len].close-bars[i-1].close)/atr;
   double bear_trend=-bull_trend;
   bool bull_context=bull_trend>=1.0 && bars[i].low<=swing_low+atr;
   bool bear_context=bear_trend>=1.0 && bars[i].high>=swing_high-atr;
   double range=bars[i].high-bars[i].low;
   double body=MathAbs(bars[i].close-bars[i].open);
   double body_low=MathMin(bars[i].open,bars[i].close);
   double body_high=MathMax(bars[i].open,bars[i].close);
   double lower=body_low-bars[i].low, upper=bars[i].high-body_high;
   bool small=range>0 && body>0 && body<=range*0.35;
   bool lower_shape=small && lower>=body*2 && lower>=range*0.50 && body_low>=bars[i].low+range*0.65;
   bool upper_shape=small && upper>=body*2 && upper>=range*0.50 && body_high<=bars[i].low+range*0.35;
   bool bull_engulf=bull_context && bars[i].close>bars[i].open && bars[i-1].close<bars[i-1].open &&
                    bars[i].open<=bars[i-1].close && bars[i].close>=bars[i-1].open && body>0;
   bool bear_engulf=bear_context && bars[i].close<bars[i].open && bars[i-1].close>bars[i-1].open &&
                    bars[i].open>=bars[i-1].close && bars[i].close<=bars[i-1].open && body>0;
   double first_range=bars[i-2].high-bars[i-2].low;
   double first_body=MathAbs(bars[i-2].close-bars[i-2].open);
   double middle_range=bars[i-1].high-bars[i-1].low;
   double middle_body=MathAbs(bars[i-1].close-bars[i-1].open);
   double first_mid=(bars[i-2].open+bars[i-2].close)*0.5;
   double star_low=MathMin(bars[i-2].low,MathMin(bars[i-1].low,bars[i].low));
   double star_high=MathMax(bars[i-2].high,MathMax(bars[i-1].high,bars[i].high));
   bool doji=middle_range>0 && middle_body<=middle_range*0.10;
   bool small_middle=middle_range>0 && first_body>0 && body>0 && middle_body<=middle_range*0.30 &&
                     middle_body<=first_body*0.60 && middle_body<=body*0.60;
   bool large_first=first_range>0 && first_body>=first_range*0.50;
   bool large_third=range>0 && body>=range*0.50;
   bool morning=bull_context && small_middle && large_first && large_third &&
                bars[i-2].close<bars[i-2].open && bars[i].close>bars[i].open && bars[i].close>=first_mid &&
                bars[i-1].low<=bars[i-2].low+first_range*0.25 && bars[i-1].low<=bars[i].low+range*0.25;
   bool evening=bear_context && small_middle && large_first && large_third &&
                bars[i-2].close>bars[i-2].open && bars[i].close<bars[i].open && bars[i].close<=first_mid &&
                bars[i-1].high>=bars[i-2].high-first_range*0.25 && bars[i-1].high>=bars[i].high-range*0.25;
   int bp=0,bv=0,sp=0,sv=0;
   if(morning) { bp=3; bv=doji?33:31; }
   else if(bull_engulf) { bp=1; bv=11; }
   else if(bull_context && lower_shape) { bp=2; bv=21; }
   else if(bull_context && upper_shape) { bp=2; bv=22; }
   if(evening) { sp=3; sv=doji?34:32; }
   else if(bear_engulf) { sp=1; sv=12; }
   else if(bear_context && lower_shape) { sp=2; sv=23; }
   else if(bear_context && upper_shape) { sp=2; sv=24; }
   int dir=0;
   if(bp>0 && sp>0)
   {
      if(bull_trend>bear_trend+0.25) dir=1;
      else if(bear_trend>bull_trend+0.25) dir=-1;
   }
   else if(bp>0) dir=1;
   else if(sp>0) dir=-1;
   if(dir==0) return true;
   out.direction=dir; out.pattern=dir>0?bp:sp; out.variant=dir>0?bv:sv;
   out.break_level=dir>0?bars[i].high:bars[i].low;
   out.marker=dir>0?(out.pattern==3?star_low:bars[i].low):(out.pattern==3?star_high:bars[i].high);
   out.stop=out.marker-dir*atr*0.15;
   out.atr=atr; out.volume=volume; out.trend=dir>0?bull_trend:bear_trend;
   out.location=dir>0?(bars[i].low-swing_low)/atr:(swing_high-bars[i].high)/atr;
   return MathIsValidNumber(out.stop) && MathIsValidNumber(out.volume) &&
          MathIsValidNumber(out.trend) && MathIsValidNumber(out.location);
}
#endif
