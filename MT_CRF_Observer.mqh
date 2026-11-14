#ifndef MT_CRF_OBSERVER_MQH
#define MT_CRF_OBSERVER_MQH
#include "MT_CRF_M15.mqh"
#include "MT_CRF_Journal.mqh"
#include "MT_CRF_Cache.mqh"

// Read-only forecast observer. NOT an execution engine. The calling EA must
// own an account/server/symbol coordinator lock before using this observer;
// this module does not independently prevent another EA from sending orders.
enum CRF_OBSERVER_RESULT
{
   CRF_OBSERVER_OK=0,
   CRF_OBSERVER_INVALID=1,
   CRF_OBSERVER_JOURNAL_ERROR=2,
   CRF_OBSERVER_HISTORY_UNAVAILABLE=3,
   CRF_OBSERVER_CALCULATION_ERROR=4,
   CRF_OBSERVER_BOOTSTRAPPING=5
};
struct CRFObserver
{
   bool ready;
   string symbol, filename, history_detail;
   int flags;
   CRFParameters parameters;
   CRFForecastState forecast;
};

// Bootstrap is staged in memory and is never a trading signal. Read and replay
// bounded M15 slabs until caught up, then save a single complete state.
#define CRF_BOOTSTRAP_SLAB_BARS 128
#define CRF_BOOTSTRAP_BUDGET_MS 50
MqlRates g_crfBootRates[], g_crfBootPrefix[];
CRFForecastState g_crfBootState;
long g_crfBootFirst=0, g_crfBootUsableFirst=0;
bool g_crfBootStarted=false;
void CRFBootReset()
{
   ArrayFree(g_crfBootRates); ArrayFree(g_crfBootPrefix);
   CRFResetForecast(g_crfBootState); g_crfBootFirst=0; g_crfBootUsableFirst=0; g_crfBootStarted=false;
}
CRF_OBSERVER_RESULT CRFObserverBootstrap(CRFObserver &observer, CRFFeedUpdate &updates[])
{
   string symbol=observer.symbol; CRFParameters p=observer.parameters;
   long sync=0,first=0;
   MqlRates probe[];
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_SYNCHRONIZED,sync) || sync==0)
   {
      CopyRates(symbol,PERIOD_M15,1,1,probe);
      observer.history_detail="M15 series synchronizing; history requested";
      CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE;
   }
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_FIRSTDATE,first) || first<=0)
   { observer.history_detail="M15 first available bar unavailable"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   if(g_crfBootStarted && first!=g_crfBootFirst)
   { observer.history_detail="M15 history changed during forecast bootstrap"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   int firstShift=CRFFirstUsableM15Shift(symbol,first);
   if(g_crfBootStarted && (long)iTime(symbol,PERIOD_M15,firstShift)!=g_crfBootUsableFirst)
   { observer.history_detail="M15 usable history boundary changed during forecast bootstrap"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
   datetime latest=iTime(symbol,PERIOD_M15,1);
   if(firstShift<context+2 || latest<=0)
   { observer.history_detail="M15 history insufficient for forecast bootstrap"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   int next=firstShift-context-1;
   if(g_crfBootStarted)
   {
      int anchor=iBarShift(symbol,PERIOD_M15,(datetime)g_crfBootState.last_bar,true);
      if(anchor<1 || anchor>firstShift)
      { observer.history_detail="M15 bootstrap anchor unavailable"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
      next=anchor-1;
   }
   if(next>0)
   {
      int batch=(int)MathMin(CRF_BOOTSTRAP_SLAB_BARS,next);
      int overlap=(int)MathMin(p.history+context+2,firstShift-next);
      int newest=next-batch+1, count=batch+overlap;
      ArrayResize(g_crfBootRates,0);
      if(!ArraySetAsSeries(g_crfBootRates,false))
      { observer.history_detail="M15 bootstrap array setup failed"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
      ResetLastError();
      int copied=CopyRates(symbol,PERIOD_M15,newest,count,g_crfBootRates), err=GetLastError();
      if(copied!=count || ArraySize(g_crfBootRates)!=count)
      { observer.history_detail=StringFormat("M15 bootstrap slab returned %d of %d bars (error %d)",copied,count,err); CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
      long after=0,syncAfter=0;
      if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_SYNCHRONIZED,syncAfter) || syncAfter==0 ||
         !SeriesInfoInteger(symbol,PERIOD_M15,SERIES_FIRSTDATE,after) || after!=first ||
         iTime(symbol,PERIOD_M15,newest)!=(datetime)g_crfBootRates[count-1].time ||
         iTime(symbol,PERIOD_M15,next)!=(datetime)g_crfBootRates[overlap].time ||
         (g_crfBootStarted && g_crfBootRates[overlap-1].time!=g_crfBootState.last_bar))
      { observer.history_detail="M15 history changed during bootstrap slab"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
      for(int i=0;i<count;i++)
         if(g_crfBootRates[i].time<=0 || (i>0 && g_crfBootRates[i].time<=g_crfBootRates[i-1].time))
         { observer.history_detail="M15 bootstrap slab not chronological"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
      if(!g_crfBootStarted)
      {
         if(overlap!=context+1 || g_crfBootRates[0].time!=iTime(symbol,PERIOD_M15,firstShift))
         { observer.history_detail="M15 first bootstrap bar could not be verified"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
         g_crfBootFirst=first; g_crfBootUsableFirst=(long)g_crfBootRates[0].time; CRFResetForecast(g_crfBootState); g_crfBootStarted=true;
      }
      if(g_crfBootStarted && ArraySize(g_crfBootPrefix)>0 && !CRFM15SameOverlap(g_crfBootPrefix,g_crfBootRates,overlap))
      { observer.history_detail="M15 history revised during forecast bootstrap"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
      ArrayFree(g_crfBootPrefix);
      if(ArrayResize(g_crfBootPrefix,overlap,count)!=overlap || ArrayCopy(g_crfBootPrefix,g_crfBootRates,0,0,overlap)!=overlap)
      { observer.history_detail="M15 bootstrap memory unavailable"; CRFBootReset(); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
      ulong started=GetTickCount64();
      for(int i=overlap;i<count;i++)
      {
         if(ArrayResize(g_crfBootPrefix,i+1,count)!=i+1) { CRFBootReset(); return CRF_OBSERVER_CALCULATION_ERROR; }
         g_crfBootPrefix[i]=g_crfBootRates[i];
         if(!CRFForecastOnBar(g_crfBootPrefix,(long)g_crfBootRates[i].time,p,g_crfBootState))
         { CRFBootReset(); return CRF_OBSERVER_CALCULATION_ERROR; }
         if(GetTickCount64()-started>=CRF_BOOTSTRAP_BUDGET_MS) break;
      }
   }
   if(g_crfBootState.last_bar!=(long)iTime(symbol,PERIOD_M15,1)) return CRF_OBSERVER_BOOTSTRAPPING;
   if(ArrayResize(updates,1)!=1) { CRFBootReset(); return CRF_OBSERVER_CALCULATION_ERROR; }
   updates[0].bar=g_crfBootState.last_bar; updates[0].bootstrap=true; updates[0].forecast=g_crfBootState;
   if(!CRFSaveForecast(observer.filename,observer.flags,p,g_crfBootState))
   { ArrayResize(updates,0); observer.ready=false; CRFBootReset(); return CRF_OBSERVER_JOURNAL_ERROR; }
   observer.forecast=g_crfBootState; observer.history_detail="";
   CRFCacheUpdate(g_crfBootPrefix); // optional cache; never gates execution
   CRFBootReset(); return CRF_OBSERVER_OK;
}

CRF_OBSERVER_RESULT CRFObserverInit(CRFObserver &observer, const string symbol,
                                    const string filename, const int flags,
                                    const CRFParameters &parameters,
                                    const bool coordinator_locked)
{
   observer.ready=false; observer.history_detail=""; CRFBootReset();
   if(!coordinator_locked || symbol=="" || filename=="" || !CRFParametersValid(parameters))
      return CRF_OBSERVER_INVALID;
   CRFForecastState loaded; CRFResetForecast(loaded);
   CRF_JOURNAL_RESULT result=CRFLoadForecast(filename,flags,parameters,loaded);
   if(result!=CRF_JOURNAL_OK && result!=CRF_JOURNAL_MISSING)
      return CRF_OBSERVER_JOURNAL_ERROR;
   CRFCacheInit(filename,flags,parameters);
   observer.symbol=symbol; observer.filename=filename; observer.flags=flags;
   observer.parameters=parameters; observer.forecast=loaded; observer.ready=true;
   return CRF_OBSERVER_OK;
}

// Large offline gaps are caught up in bounded slabs. Each completed slab is
// journaled, but no partial batch is exposed as a fresh trading opportunity.
CRF_OBSERVER_RESULT CRFObserverCatchupSlab(CRFObserver &observer, const int anchorShift,
                                          CRFFeedUpdate &updates[])
{
   string symbol=observer.symbol; CRFParameters p=observer.parameters;
   long sync=0,first=0;
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_SYNCHRONIZED,sync) || sync==0)
   {
      MqlRates probe[]; CopyRates(symbol,PERIOD_M15,1,1,probe);
      observer.history_detail="M15 series synchronizing; history requested"; return CRF_OBSERVER_HISTORY_UNAVAILABLE;
   }
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_FIRSTDATE,first) || first<=0)
   { observer.history_detail="M15 first available bar unavailable"; return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   int firstShift=CRFFirstUsableM15Shift(symbol,first);
   int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
   if(anchorShift<2 || firstShift<anchorShift)
   { observer.history_detail="M15 catch-up anchor or first bar missing"; return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   int batch=(int)MathMin(CRF_BOOTSTRAP_SLAB_BARS,anchorShift-1);
   int overlap=(int)MathMin(p.history+context+2,firstShift-anchorShift+1);
   int newest=anchorShift-batch,count=batch+overlap;
   MqlRates rates[];
   if(!ArraySetAsSeries(rates,false))
   { observer.history_detail="M15 catch-up array setup failed"; return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   ResetLastError();
   int copied=CopyRates(symbol,PERIOD_M15,newest,count,rates), err=GetLastError();
   if(copied!=count || ArraySize(rates)!=count)
   { observer.history_detail=StringFormat("M15 catch-up slab returned %d of %d bars (error %d)",copied,count,err); return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   long after=0,syncAfter=0;
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_SYNCHRONIZED,syncAfter) || syncAfter==0 ||
      !SeriesInfoInteger(symbol,PERIOD_M15,SERIES_FIRSTDATE,after) || after!=first ||
      iTime(symbol,PERIOD_M15,newest)!=(datetime)rates[count-1].time ||
      iTime(symbol,PERIOD_M15,anchorShift)!=(datetime)rates[overlap-1].time ||
      rates[overlap-1].time!=observer.forecast.last_bar)
   { observer.history_detail="M15 history changed during catch-up slab"; return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   bool startsFirst=(overlap==firstShift-anchorShift+1 && rates[0].time==iTime(symbol,PERIOD_M15,firstShift));
   if(!CRFCacheMatches(rates))
   { observer.history_detail="M15 cached history differs from terminal; forecast may be stale"; return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   CRFForecastState working=observer.forecast;
   CRFFeedUpdate staged[];
   CRF_FEED_RESULT result=CRFProcessClosedBars(rates,(long)rates[count-1].time,p,startsFirst,working,staged);
   if(result!=CRF_FEED_OK) return CRF_OBSERVER_CALCULATION_ERROR;
   bool finalBatch=(newest==1 && working.last_bar==(long)iTime(symbol,PERIOD_M15,1));
   if(finalBatch)
   {
      int n=ArraySize(staged);
      if(ArrayResize(updates,n)!=n) return CRF_OBSERVER_CALCULATION_ERROR;
      for(int i=0;i<n;i++) updates[i]=staged[i];
   }
   if(!CRFSaveForecast(observer.filename,observer.flags,p,working))
   { ArrayResize(updates,0); observer.ready=false; return CRF_OBSERVER_JOURNAL_ERROR; }
   observer.forecast=working; observer.history_detail=""; CRFCacheUpdate(rates);
   // Intermediate bars are reconciled into state, not dispatched as trades.
   if(!finalBatch || working.last_bar!=(long)iTime(symbol,PERIOD_M15,1))
   { ArrayResize(updates,0); return CRF_OBSERVER_BOOTSTRAPPING; }
   return CRF_OBSERVER_OK;
}

// Outputs are available only after a successful forecast save. On any failed
// save this instance is latched off until reinitialization: a caller must not
// infer whether a request could safely be retried from an ambiguous I/O result.
// Catch-up updates are not a durable execution queue. The execution journal
// must independently persist its own signal identity and deadline, and on
// every restart reconcile replacements and expiry from persisted broker state;
// never rely only on having consumed these in-memory updates.
CRF_OBSERVER_RESULT CRFObserverPoll(CRFObserver &observer, CRFFeedUpdate &updates[])
{
   ArrayResize(updates,0);
   if(!observer.ready) return CRF_OBSERVER_INVALID;
   if(observer.forecast.last_bar==0) return CRFObserverBootstrap(observer,updates);
   int anchorShift=iBarShift(observer.symbol,PERIOD_M15,(datetime)observer.forecast.last_bar,true);
   if(anchorShift>CRF_BOOTSTRAP_SLAB_BARS+1) return CRFObserverCatchupSlab(observer,anchorShift,updates);
   MqlRates rates[]; bool first=false; long latest=0;
   CRF_M15_RESULT read=CRFReadClosedM15Detailed(observer.symbol,observer.parameters,
                                               observer.forecast.last_bar,rates,first,latest,
                                               observer.history_detail);
   if(read!=CRF_M15_OK) return CRF_OBSERVER_HISTORY_UNAVAILABLE;
   if(!CRFCacheMatches(rates))
   { observer.history_detail="M15 cached history differs from terminal; forecast may be stale"; return CRF_OBSERVER_HISTORY_UNAVAILABLE; }
   CRFForecastState working=observer.forecast;
   CRFFeedUpdate staged[];
   CRF_FEED_RESULT processed=CRFProcessClosedBars(rates,latest,observer.parameters,first,working,staged);
   if(processed!=CRF_FEED_OK) return CRF_OBSERVER_CALCULATION_ERROR;
   int count=ArraySize(staged);
   if(count==0) return CRF_OBSERVER_OK;
   // Reserve output memory before the durable commit: failure after the commit
   // would otherwise discard catch-up events while advancing the anchor.
   if(ArrayResize(updates,count)!=count) return CRF_OBSERVER_CALCULATION_ERROR;
   for(int i=0;i<count;i++) updates[i]=staged[i];
   if(!CRFSaveForecast(observer.filename,observer.flags,observer.parameters,working))
   {
      ArrayResize(updates,0); observer.ready=false;
      return CRF_OBSERVER_JOURNAL_ERROR;
   }
   observer.forecast=working;
   CRFCacheUpdate(rates); // only new valid closed bars replace the cached suffix
   return CRF_OBSERVER_OK;
}
#endif
