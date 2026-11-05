// Broker-deal aggregation for the realized-trade diary.
// This kernel does not send orders or infer fills from market-price touches.
#ifndef MT_TRADE_DIARY_MQH
#define MT_TRADE_DIARY_MQH
#include "MT_Phase3.mqh"

struct P5Deal
{
   ulong ticket, position, order;
   int entry; // 1=entry, 2=exit; other deal types require review
   long timeMs;
   double volume, price, profit, commission, swap, fee;
};
struct P5TradeResult
{
   double entryVolume, exitVolume, entryPrice, exitPrice;
   double profit, commission, swap, fee, net;
   long entryMs, exitMs;
   int outcome; // 1=positive net, -1=negative net, 0=zero net
};

bool P5Money(double value)
{
   return(MathIsValidNumber(value) && value!=EMPTY_VALUE);
}

// Caller must gather every relevant broker deal for one position using
// verified property reads. A false result is unresolved, not a loss, win,
// or zero; prices or account cash flows must not be fabricated. The caller
// must retry incomplete history and exclude unresolved rows from totals.
bool P5ClosedTrade(const P5Deal &deals[], ulong position, ulong entryOrder,
                   double volumeStep, bool positionOpen, bool entryPending,
                   P5TradeResult &out)
{
   out.entryVolume=0; out.exitVolume=0; out.entryPrice=0; out.exitPrice=0;
   out.profit=0; out.commission=0; out.swap=0; out.fee=0; out.net=0;
   out.entryMs=0; out.exitMs=0; out.outcome=0;
   if(position==0 || entryOrder==0 || !P3Positive(volumeStep) ||
      positionOpen || entryPending) return(false);
   double entryWeighted=0, exitWeighted=0;
   long latestEntry=0, earliestExit=0;
   for(int i=0;i<ArraySize(deals);i++)
   {
      P5Deal d=deals[i];
      if(d.ticket==0 || d.position!=position || d.order==0 || d.timeMs<=0 ||
         !P3Positive(d.volume) || !P3Positive(d.price) ||
         !P5Money(d.profit) || !P5Money(d.commission) ||
         !P5Money(d.swap) || !P5Money(d.fee)) return(false);
      for(int j=0;j<i;j++) if(deals[j].ticket==d.ticket) return(false);
      if(d.entry==1)
      {
         // Other entry orders cannot safely be attributed to this idea.
         if(d.order!=entryOrder) return(false);
         out.entryVolume+=d.volume;
         entryWeighted+=d.volume*d.price;
         if(out.entryMs==0 || d.timeMs<out.entryMs) out.entryMs=d.timeMs;
         if(d.timeMs>latestEntry) latestEntry=d.timeMs;
      }
      else if(d.entry==2)
      {
         out.exitVolume+=d.volume;
         exitWeighted+=d.volume*d.price;
         if(earliestExit==0 || d.timeMs<earliestExit) earliestExit=d.timeMs;
         if(d.timeMs>out.exitMs) out.exitMs=d.timeMs;
      }
      else return(false);
      out.profit+=d.profit; out.commission+=d.commission;
      out.swap+=d.swap; out.fee+=d.fee;
   }
   // Conservatively defer entries/exits with ambiguous same-millisecond
   // ordering, or a position with unmatched partial exit volume.
   if(!P3Positive(out.entryVolume) || !P3Positive(out.exitVolume) ||
      earliestExit<=latestEntry || MathAbs(out.entryVolume-out.exitVolume)>volumeStep*1e-7)
      return(false);
   out.entryPrice=entryWeighted/out.entryVolume;
   out.exitPrice=exitWeighted/out.exitVolume;
   out.net=out.profit+out.commission+out.swap+out.fee;
   if(!P3Positive(out.entryPrice) || !P3Positive(out.exitPrice) ||
      !P5Money(out.profit) || !P5Money(out.commission) ||
      !P5Money(out.swap) || !P5Money(out.fee) ||
      !P5Money(out.net)) return(false);
   out.outcome=out.net>0.0?1:(out.net<0.0?-1:0);
   return(true);
}
#endif
