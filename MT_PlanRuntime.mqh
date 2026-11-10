#ifndef MT_PLAN_RUNTIME_MQH
#define MT_PLAN_RUNTIME_MQH
#include "MT_Plan.mqh"

// Keep the MT5 Inputs tab in the order used by traders; retain input names.
input bool InpAutoTrading = false;                    // Auto trading
input bool InpPlaceStopLoss = false;                  // Stop Loss Placement
input bool InpBypassRisk = false;                     // Bypass Risk
input bool InpMinimumLot = false;                     // Minimum Lot use
input int InpTPPercentM5 = 81;                        // TP% for M5 (lower = closer)
input int InpTPPercentM15 = 83;                       // TP% for M15 (lower = closer)
input int InpTPPercentM30 = 85;                       // TP% for M30 (lower = closer)
input P3_TREND_CHOICE InpTrendM5 = P3_AUTO;           // trend to follow M5
input P3_TREND_CHOICE InpTrendM15 = P3_AUTO;          // trend to follow M15
input P3_TREND_CHOICE InpTrendM30 = P3_AUTO;          // trend to follow M30
input bool InpAgainstM5 = false;                      // Allow against trend M5
input bool InpAgainstM15 = false;                     // Allow against trend M15
input bool InpAgainstM30 = false;                     // Allow against trend M30
input bool InpAllowAutoM5 = true;                     // Allow autotrading M5
input bool InpAllowAutoM15 = true;                    // Allow autotrading M15
input bool InpAllowAutoM30 = true;                    // Allow autotrading M30
input bool InpUseAutoSchedule = true;                 // Use Daily trading timer (PC/VPS local time)
input string InpAutoStartTime = "09:15";               // Timer Start (Local HH:MM)
input string InpAutoEndTime = "17:00";                 // Timer Stop (Local HH:MM)
input bool InpShowDetails = false;                    // Show diary Details

struct P3LaneData
{
   int gt, ct, st, score, volumeState;
   string regime;
   datetime bar;
   double targetR;
   int samples;
};
P3LaneData g_p3[3];

void P3Invalidate(int lane)
{
   g_p3[lane].gt = P3_WAIT; g_p3[lane].ct = P3_WAIT;
   g_p3[lane].st = P3_WAIT; g_p3[lane].score = P3_WAIT;
   g_p3[lane].bar = 0; g_p3[lane].targetR = 0.0; g_p3[lane].samples = 0;
   g_p3[lane].regime = "WAIT"; g_p3[lane].volumeState = -1;
}

void P3Reset()
{
   for(int i = 0; i < 3; i++) P3Invalidate(i);
}

P3_TREND_CHOICE P3Choice(int lane)
{
   return(lane == 0 ? InpTrendM5 : (lane == 1 ? InpTrendM15 : InpTrendM30));
}

bool P3Against(int lane)
{
   return(lane == 0 ? InpAgainstM5 : (lane == 1 ? InpAgainstM15 : InpAgainstM30));
}

int P3TPPercentInput(int lane)
{
   return(lane==0 ? InpTPPercentM5 : (lane==1 ? InpTPPercentM15 : (lane==2 ? InpTPPercentM30 : 0)));
}

// An invalid value reverts only that lane to the original TP logic. The
// header reports INVALID so the fallback is not mistaken for a test value.
int P3TPPercent(int lane)
{
   int value=P3TPPercentInput(lane);
   return(value>=1 && value<=100 ? value : 0);
}

bool P3UseSecondSwing(int lane)
{
   return((lane==1 || lane==2) && P3TPPercent(lane)>0);
}

int P3Strategy(int lane)
{
   return(P3TPPercent(lane)>0?30006:30004);
}

// MT5 bars can be based on Bid or Last. The historical replay below uses
// Bid OHLC; Last bars must not be silently treated as historical Bid quotes.
bool P3HasBidBars()
{
   long mode=0;
   return(SymbolInfoInteger(_Symbol,SYMBOL_CHART_MODE,mode) && mode==SYMBOL_CHART_MODE_BID);
}

void P3Remember(int lane, int gt, int ct, int st, int score, string regime,
                datetime bar, const MqlRates &rates[], const int &scores[],
                const int &gts[], const int &cts[], const int &statuses[])
{
   g_p3[lane].gt=gt; g_p3[lane].ct=ct; g_p3[lane].st=st; g_p3[lane].score=score;
   g_p3[lane].regime=regime; g_p3[lane].bar=bar;
   g_p3[lane].volumeState=P3VolumeState(rates,ArraySize(rates)-1);
   g_p3[lane].targetR=0.0; g_p3[lane].samples=0;
   if(score < -3 || score > 3 || MathAbs(score) < 2 || !P3HasBidBars()) return;
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || !P3Positive(tick) || !P3Positive(point) ||
      !P3Positive(q.bid) || q.ask < q.bid) return;
   double stopDistance=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   g_p3[lane].targetR=P3ObservedTargetR(rates,scores,gts,cts,statuses,ArraySize(rates),lane,score,
                                       P3Choice(lane),P3Against(lane),tick,point,
                                       stopDistance,q.ask-q.bid,g_p3[lane].samples,P3TPPercent(lane));
}

struct P3Plan
{
   int signal;
   bool valid;
   bool priced;
   bool market;
   bool barProxy;
   double entry, stop, target, lot, slMoney, tpMoney;
   datetime bar;
};

// One observed post-close quote and one priced plan per lane/bar. Quotes are
// captured only on chart ticks, not by timer/panel refreshes. On attachment or
// after a data gap this is the first tick observed by this EA, not necessarily
// the first tick in the broker's history.
MqlTick g_p3Quote[3];
datetime g_p3QuoteBar[3];
P3Plan g_p3Plan[3];
bool g_p3Frozen[3];

void P3ResetSnapshots()
{
   for(int lane=0;lane<3;lane++) { g_p3QuoteBar[lane]=0; g_p3Frozen[lane]=false; }
}

ENUM_TIMEFRAMES P3Timeframe(int lane)
{
   return(lane==0?PERIOD_M5:(lane==1?PERIOD_M15:PERIOD_M30));
}

void P3CaptureQuotes()
{
   MqlTick q;
   if(g_marketState!=MARKET_OPEN || !SymbolInfoTick(_Symbol,q) || q.time<=0 ||
      !P3Positive(q.bid) || !P3Positive(q.ask) || q.ask<q.bid) return;
   for(int lane=0;lane<3;lane++)
   {
      ENUM_TIMEFRAMES tf=P3Timeframe(lane);
      datetime closed=iTime(_Symbol,tf,1), opened=iTime(_Symbol,tf,0);
      if(closed<=0 || opened<=closed || q.time<opened) continue;
      if(g_p3QuoteBar[lane]!=closed)
      {
         g_p3Quote[lane]=q; g_p3QuoteBar[lane]=closed; g_p3Frozen[lane]=false;
      }
   }
}

bool P3MakePlanAt(int lane, const MqlTick &q, P3Plan &plan)
{
   plan.valid=false; plan.priced=false; plan.barProxy=!P3HasBidBars(); plan.entry=0; plan.stop=0; plan.target=0; plan.lot=0;
   plan.slMoney=0; plan.tpMoney=0; plan.bar=g_p3[lane].bar;
   int selected=P3SelectedTrend(lane,P3Choice(lane),g_p3[lane].gt,g_p3[lane].ct,g_p3[lane].st);
   plan.signal=P3Signal(g_p3[lane].score,selected,P3Against(lane));
   if(plan.signal == 0 || plan.signal == P3_WAIT) return(false);
   plan.market=P3MarketStyle(g_p3[lane].score,g_p3[lane].volumeState);
   if(!P3Positive(q.bid) || !P3Positive(q.ask) || q.ask<q.bid) return(false);
   // A stale or closed market must not turn a cached quote into a current entry.
   if(g_marketState != MARKET_OPEN) return(false);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(!P3Positive(tick) || !P3Positive(point)) return(false);
   double minDist=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   ENUM_TIMEFRAMES tf=lane==0?PERIOD_M5:(lane==1?PERIOD_M15:PERIOD_M30);
   MqlRates bars[];
   ArraySetAsSeries(bars,false);
   int n=CopyRates(_Symbol,tf,1,100,bars);
   if(n<4 || bars[n-1].time != g_p3[lane].bar) return(false);
   P3Geometry geo;
   bool geometry=P3GeometryAt(bars,n-1,lane,plan.signal,plan.market,q.bid,q.ask,tick,minDist,geo);
   plan.entry=geo.entry; plan.stop=geo.stop;
   if(!geometry) return(false);
   double risk=MathAbs(geo.entry-geo.stop);
   double distance=(g_p3[lane].samples>=20 && g_p3[lane].targetR>0.0)
                   ? risk*g_p3[lane].targetR : geo.fallbackMove;
   // Respect executable quote-side broker minimum and the entry price.
   double floorDistance=MathMax(tick,minDist);
   double target=plan.signal>0 ? P3Down(geo.entry+distance,tick) : P3Up(geo.entry-distance,tick);
   double barrier=(P3UseSecondSwing(lane) && geo.secondBarrier>0.0) ? geo.secondBarrier : geo.barrier;
   if(barrier>0.0)
   {
      if(plan.signal>0 && barrier>geo.entry && barrier<target) target=barrier;
      if(plan.signal<0 && barrier<geo.entry && barrier>target) target=barrier;
   }
   double base=plan.market ? (plan.signal>0?q.bid:q.ask) : geo.entry;
   if(plan.signal>0) target=P3Up(MathMax(target,MathMax(geo.entry+tick,base+floorDistance)),tick);
   else target=P3Down(MathMin(target,MathMin(geo.entry-tick,base-floorDistance)),tick);
   if(!P3Positive(target) || (plan.signal>0 && target<=geo.entry) ||
      (plan.signal<0 && target>=geo.entry)) return(false);
   plan.target=target; plan.priced=true;
   if(!P3Positive(vmin) || !P3Positive(vmax) || !P3Positive(step)) return(false);
   ENUM_ORDER_TYPE order=plan.signal>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double perLotLoss=0.0;
   if(!InpBypassRisk && !InpMinimumLot)
   {
      double minLoss=0;
      if(!OrderCalcProfit(order,_Symbol,vmin,geo.entry,geo.stop,minLoss) ||
         !MathIsValidNumber(minLoss) || minLoss>=0.0) return(false);
      perLotLoss=-minLoss/vmin;
   }
   double lot=P3Lot(AccountInfoDouble(ACCOUNT_EQUITY),AccountInfoDouble(ACCOUNT_BALANCE),
                    perLotLoss,g_p3[lane].score,InpBypassRisk,InpMinimumLot,vmin,vmax,step);
   if(!P3Positive(lot)) return(false);
   plan.lot=lot;
   double sl=0,tp=0;
   if(!OrderCalcProfit(order,_Symbol,lot,geo.entry,geo.stop,sl) ||
      !OrderCalcProfit(order,_Symbol,lot,geo.entry,target,tp) ||
      !MathIsValidNumber(sl) || !MathIsValidNumber(tp) || sl>=0 || tp<=0) return(false);
   plan.entry=geo.entry; plan.stop=geo.stop; plan.target=target; plan.lot=lot;
   plan.slMoney=sl; plan.tpMoney=tp; plan.valid=true;
   return(true);
}

// Build from the captured quote once price geometry is available. A transient
// missing history/quote may be retried without replacing that quote. Once
// priced, all values (including an unavailable sizing result) stay frozen.
void P3FreezePlans()
{
   for(int lane=0;lane<3;lane++)
   {
      if(g_p3Frozen[lane] || g_p3QuoteBar[lane]<=0 ||
         g_p3[lane].bar!=g_p3QuoteBar[lane] ||
         iTime(_Symbol,P3Timeframe(lane),1)!=g_p3QuoteBar[lane]) continue;
      P3Plan candidate;
      P3MakePlanAt(lane,g_p3Quote[lane],candidate);
      if(candidate.priced) { g_p3Plan[lane]=candidate; g_p3Frozen[lane]=true; }
   }
}

bool P3MakePlan(int lane, P3Plan &plan)
{
   // Do not use an old plan if bar history or current signal is unavailable.
   plan.valid=false; plan.priced=false; plan.market=false; plan.barProxy=!P3HasBidBars();
   plan.entry=0; plan.stop=0; plan.target=0; plan.lot=0; plan.slMoney=0; plan.tpMoney=0;
   plan.bar=g_p3[lane].bar;
   int selected=P3SelectedTrend(lane,P3Choice(lane),g_p3[lane].gt,g_p3[lane].ct,g_p3[lane].st);
   plan.signal=P3Signal(g_p3[lane].score,selected,P3Against(lane));
   if(g_p3[lane].bar<=0 || iTime(_Symbol,P3Timeframe(lane),1)!=g_p3[lane].bar)
   { plan.signal=P3_WAIT; return(false); }
   bool market=P3MarketStyle(g_p3[lane].score,g_p3[lane].volumeState);
   plan.market=market;
   if(!g_p3Frozen[lane] || g_p3QuoteBar[lane]!=g_p3[lane].bar ||
      g_p3Plan[lane].signal!=plan.signal || g_p3Plan[lane].market!=market) return(false);
   plan=g_p3Plan[lane];
   return(plan.valid);
}

string P3LotText(double lot)
{
   string value=DoubleToString(lot,8);
   while(StringLen(value)>0 && StringSubstr(value,StringLen(value)-1,1)=="0")
      value=StringSubstr(value,0,StringLen(value)-1);
   if(StringLen(value)>0 && StringSubstr(value,StringLen(value)-1,1)==".")
      value=StringSubstr(value,0,StringLen(value)-1);
   return(value);
}

string P3PlanLine(int lane)
{
   P3Plan p; P3MakePlan(lane,p);
   string tf=lane==0?"M5":(lane==1?"M15":"M30");
   if(p.signal==P3_WAIT) return(tf+" | Signal: WAIT");
   if(p.signal==0) return(tf+" | Signal: NONE");
   string s=tf+" | Signal: "+(p.signal>0?"BUY":"SELL");
   if(MathAbs(g_p3[lane].score)==3)
   {
      s+=" | Volume: ";
      s+=(g_p3[lane].volumeState<0?"--":(g_p3[lane].volumeState==0?"LOW":"OK"));
   }
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   string currency=AccountInfoString(ACCOUNT_CURRENCY);
   if(!P3Positive(p.entry)) return(s+" | Entry: -- | Plan data unavailable");
   if(!p.valid)
      return(s+" | "+(p.market?"MARKET":"LIMIT")+" Entry: "+DoubleToString(p.entry,digits)+
             " | Lot: "+(p.lot>0?P3LotText(p.lot):"--")+" | SL: "+(p.stop>0?DoubleToString(p.stop,digits):"--")+
             " | TP: "+(p.target>0?DoubleToString(p.target,digits):"--")+" | Amounts unavailable"+
             (p.barProxy?" | Bars: Last/unknown proxy":""));
   return(s+" | "+(p.market?"MARKET":"LIMIT")+" Entry: "+DoubleToString(p.entry,digits)+
          " | Lot: "+P3LotText(p.lot)+" | SL: "+DoubleToString(p.stop,digits)+
          " ("+DoubleToString(p.slMoney,2)+" "+currency+") | TP: "+DoubleToString(p.target,digits)+
          " (+"+DoubleToString(p.tpMoney,2)+" "+currency+")"+
          (p.barProxy?" | Bars: Last/unknown proxy":""));
}
#endif
