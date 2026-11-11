#ifndef MT_CRF_FEED_MQH
#define MT_CRF_FEED_MQH
#include "MT_CRF_Forecast.mqh"

// A feed result reports every replayed close. Bootstrapping reconstructs the
// display only: the eventual execution layer must NOT trade an old signal.
struct CRFFeedUpdate
{
   long bar;
   bool bootstrap;
   CRFForecastState forecast;
};
enum CRF_FEED_RESULT
{
   CRF_FEED_OK=0,
   CRF_FEED_INSUFFICIENT=1,
   CRF_FEED_STALE=2,
   CRF_FEED_BAD_SERIES=3,
   CRF_FEED_ANCHOR_MISSING=4,
   CRF_FEED_CALCULATION_FAILED=5,
   CRF_FEED_MEMORY_FAILED=6
};

// Rates must be M15 *closed* candles in strictly increasing time order. The
// expected_latest value is read from the terminal independently of the copy,
// to reject a partial/stale CopyRates result. A recovery cannot skip a missing
// anchor: the caller must obtain more history or remain in REVIEW.
// `starts_at_known_first_bar` must be true only when the caller has verified
// the copy begins at the actual first available chart bar, not merely the
// start of an arbitrary truncated copy. Bootstrap requires it so retained
// last-result fields cannot silently omit older events. An incremental replay
// with a short pre-anchor lookback likewise requires it.
// Failed batches never update state or expose partially calculated events.
CRF_FEED_RESULT CRFProcessClosedBars(const MqlRates &rates[], const long expected_latest,
                                     const CRFParameters &p, const bool starts_at_known_first_bar,
                                     CRFForecastState &state,
                                     CRFFeedUpdate &updates[])
{
   ArrayResize(updates,0);
   if(!CRFParametersValid(p) || expected_latest<=0) return CRF_FEED_BAD_SERIES;
   int n=ArraySize(rates);
   int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
   if(n<context+2) return CRF_FEED_INSUFFICIENT;
   for(int i=0;i<n;i++)
   {
      if(rates[i].time<=0 || (i>0 && rates[i].time<=rates[i-1].time))
         return CRF_FEED_BAD_SERIES;
   }
   if((long)rates[n-1].time!=expected_latest) return CRF_FEED_STALE;
   bool bootstrap=(state.last_bar==0);
   if(bootstrap && !starts_at_known_first_bar) return CRF_FEED_INSUFFICIENT;
   int anchor=-1;
   if(!bootstrap)
   {
      for(int i=n-1;i>=0;i--) if((long)rates[i].time==state.last_bar) { anchor=i; break; }
      if(anchor<0 || anchor<context+1) return CRF_FEED_ANCHOR_MISSING;
      if(!starts_at_known_first_bar && anchor+2<p.history+context)
         return CRF_FEED_INSUFFICIENT;
   }
   CRFForecastState working;
   if(bootstrap) CRFResetForecast(working);
   else working=state;
   int start=bootstrap?context+1:anchor+1;
   MqlRates prefix[];
   CRFFeedUpdate staged[];
   for(int i=start;i<n;i++)
   {
      if(ArrayResize(prefix,i+1,n)!=i+1) return CRF_FEED_MEMORY_FAILED;
      if(i==start)
      {
         if(ArrayCopy(prefix,rates,0,0,i+1)!=i+1) return CRF_FEED_MEMORY_FAILED;
      }
      else prefix[i]=rates[i];
      if(!CRFForecastOnBar(prefix,(long)rates[i].time,p,working)) return CRF_FEED_CALCULATION_FAILED;
      // All catch-up events are returned, in order, so the broker layer can
      // handle expiry/replacement even when several bars elapsed offline.
      if(!bootstrap)
      {
         int count=ArraySize(staged);
         if(ArrayResize(staged,count+1)!=count+1) return CRF_FEED_MEMORY_FAILED;
         staged[count].bar=(long)rates[i].time; staged[count].bootstrap=false;
         staged[count].forecast=working;
      }
   }
   if(bootstrap)
   {
      if(ArrayResize(staged,1)!=1) return CRF_FEED_MEMORY_FAILED;
      staged[0].bar=working.last_bar; staged[0].bootstrap=true; staged[0].forecast=working;
   }
   int count=ArraySize(staged);
   if(ArrayResize(updates,count)!=count) { ArrayResize(updates,0); return CRF_FEED_MEMORY_FAILED; }
   for(int j=0;j<count;j++) updates[j]=staged[j];
   state=working;
   return CRF_FEED_OK;
}
#endif
