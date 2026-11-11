#ifndef MT_CRF_FORECAST_MQH
#define MT_CRF_FORECAST_MQH
#include "MT_CRF_Analogs.mqh"

// Forecast state is descriptive only. Never treat a candle touch as proof that
// an order filled or a broker position closed. Persistence/broker ownership
// and catch-up are provided by the separate runtime.
struct CRFForecastState
{
   long last_bar;
   int pending_elapsed, bull_cooldown, bear_cooldown;
   CRFCandidate pending, last_signal;
   double last_entry;
   CRFEstimate last_estimate;
   int active_direction, remaining, last_result, last_event;
   double active_stop, active_target;
   long last_event_bar, signal_bar;
};

void CRFResetForecast(CRFForecastState &s)
{
   ZeroMemory(s);
   s.last_entry=EMPTY_VALUE; s.active_stop=EMPTY_VALUE; s.active_target=EMPTY_VALUE;
   s.pending.break_level=EMPTY_VALUE; s.pending.stop=EMPTY_VALUE;
   s.last_signal.stop=EMPTY_VALUE; s.last_estimate.target=EMPTY_VALUE;
   s.last_estimate.reason=1;
}

// Called once per chronological closed M15 bar with history ending on that bar.
// The caller must replay every missed close in order before accepting new
// signals; a repeated or older bar is ignored. Failure is atomic.
bool CRFForecastOnBar(const MqlRates &bars[], const long bar_id,
                      const CRFParameters &p, CRFForecastState &state)
{
   int n=ArraySize(bars);
   if(!CRFParametersValid(p) || bar_id<=0 || n<=0) return false;
   if(bar_id<=state.last_bar) return true;
   int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
   if(n+1<=context+2) return false;
   CRFCandidate raw;
   if(!CRFDetectAt(bars,n-1,p.atr,p.trend,p.volume,p.swing,raw)) return false;
   CRFForecastState next=state;
   if(next.bull_cooldown>0) next.bull_cooldown--;
   if(next.bear_cooldown>0) next.bear_cooldown--;
   if(next.active_direction!=0)
   {
      if(next.remaining<=0) return false;
      next.remaining--;
      int result=CRFBarResult(next.active_direction,next.active_stop,next.active_target,
                              bars[n-1].high,bars[n-1].low,next.remaining);
      if(result<0) return false;
      if(result>0)
      {
         next.last_result=result; next.last_event=4; next.last_event_bar=bar_id;
         next.active_direction=0; next.remaining=0;
         next.active_stop=EMPTY_VALUE; next.active_target=EMPTY_VALUE;
      }
   }
   bool skip_candidate=false;
   if(next.pending.direction!=0)
   {
      CRF_CONFIRM_EVENT confirmation=CRFAdvanceConfirmation(next.pending.direction,
                                      next.pending.break_level,bars[n-1].close,next.pending_elapsed);
      if(confirmation==CRF_CONFIRM_INVALID) return false;
      if(confirmation==CRF_CONFIRM_BUY || confirmation==CRF_CONFIRM_SELL)
      {
         CRFCandidate confirmed=next.pending;
         next.last_event=2; next.last_event_bar=bar_id;
         if(next.active_direction!=0)
         {
            next.last_result=next.active_direction==confirmed.direction?5:3;
            next.active_direction=0; next.remaining=0;
            next.active_stop=EMPTY_VALUE; next.active_target=EMPTY_VALUE;
         }
         next.last_signal=confirmed; next.last_entry=bars[n-1].close; next.signal_bar=bar_id;
         CRFEstimate estimate;
         if(!CRFEstimateAt(bars,confirmed,next.last_entry,p,estimate)) return false;
         next.last_estimate=estimate;
         if(estimate.available)
         {
            if(next.last_result==6) next.last_result=0;
            next.active_direction=confirmed.direction; next.remaining=estimate.duration_high;
            next.active_stop=confirmed.stop; next.active_target=estimate.target;
         }
         else { next.last_result=6; next.last_event=5; }
         next.pending.direction=0; next.pending_elapsed=0; skip_candidate=true;
      }
      else if(confirmation==CRF_CONFIRM_EXPIRED)
      {
         next.pending.direction=0; next.pending_elapsed=0; skip_candidate=true;
         next.last_event=3; next.last_event_bar=bar_id;
      }
   }
   if(!skip_candidate && next.pending.direction!=0 && raw.direction!=0)
   { next.last_event=6; next.last_event_bar=bar_id; }
   if(!skip_candidate && next.pending.direction==0 && raw.direction!=0 && raw.atr>0 &&
      CRFValidPrice(raw.break_level) && CRFValidPrice(raw.stop))
   {
      bool allowed=raw.direction>0?next.bull_cooldown<=0:next.bear_cooldown<=0;
      if(allowed)
      {
         next.pending=raw; next.pending_elapsed=0;
         if(raw.direction>0) next.bull_cooldown=p.swing+2;
         else next.bear_cooldown=p.swing+2;
         next.last_event=1;
      }
      else next.last_event=6;
      next.last_event_bar=bar_id;
   }
   next.last_bar=bar_id;
   state=next;
   return true;
}
#endif
