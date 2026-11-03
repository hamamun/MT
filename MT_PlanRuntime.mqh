#ifndef MT_PLAN_RUNTIME_MQH
#define MT_PLAN_RUNTIME_MQH
#include "MT_Plan.mqh"

input P3_TREND_CHOICE InpTrendM5 = P3_AUTO;       // Trend to follow M5
input P3_TREND_CHOICE InpTrendM15 = P3_AUTO;      // Trend to follow M15
input P3_TREND_CHOICE InpTrendM30 = P3_AUTO;      // Trend to follow M30
input bool InpAgainstM5 = true;                    // Allow against trend M5
input bool InpAgainstM15 = true;                   // Allow against trend M15
input bool InpAgainstM30 = true;                   // Allow against trend M30
input bool InpBypassRisk = false;                   // Bypass risk
input bool InpMinimumLot = false;                  // Minimum lot use
input bool InpShowDetails = false;                 // Show diary details

struct P3LaneData
{
   int gt, ct, st, score;
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
   g_p3[lane].regime = "WAIT";
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
                                       stopDistance,q.ask-q.bid,g_p3[lane].samples);
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

bool P3MakePlanAt(int lane, const MqlTick &q, P3Plan &plan)
{
   plan.valid=false; plan.priced=false; plan.barProxy=!P3HasBidBars(); plan.entry=0; plan.stop=0; plan.target=0; plan.lot=0;
   plan.slMoney=0; plan.tpMoney=0; plan.bar=g_p3[lane].bar;
   int selected=P3SelectedTrend(lane,P3Choice(lane),g_p3[lane].gt,g_p3[lane].ct,g_p3[lane].st);
   plan.signal=P3Signal(g_p3[lane].score,selected,P3Against(lane));
   if(plan.signal == 0 || plan.signal == P3_WAIT) return(false);
   plan.market=MathAbs(g_p3[lane].score)==3;
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
   if(geo.barrier>0.0)
   {
      if(plan.signal>0 && geo.barrier>geo.entry && geo.barrier<target) target=geo.barrier;
      if(plan.signal<0 && geo.barrier<geo.entry && geo.barrier>target) target=geo.barrier;
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

bool P3MakePlan(int lane, P3Plan &plan)
{
   MqlTick q;
   q.bid=0.0; q.ask=0.0;
   SymbolInfoTick(_Symbol,q);
   return(P3MakePlanAt(lane,q,plan));
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
