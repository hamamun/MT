#ifndef MT_CRF_OBSERVER_MQH
#define MT_CRF_OBSERVER_MQH
#include "MT_CRF_M15.mqh"
#include "MT_CRF_Journal.mqh"

// Read-only forecast observer. NOT an execution engine. The calling EA must
// own an account/server/symbol coordinator lock before using this observer;
// this module does not independently prevent another EA from sending orders.
enum CRF_OBSERVER_RESULT
{
   CRF_OBSERVER_OK=0,
   CRF_OBSERVER_INVALID=1,
   CRF_OBSERVER_JOURNAL_ERROR=2,
   CRF_OBSERVER_HISTORY_UNAVAILABLE=3,
   CRF_OBSERVER_CALCULATION_ERROR=4
};
struct CRFObserver
{
   bool ready;
   string symbol, filename;
   int flags;
   CRFParameters parameters;
   CRFForecastState forecast;
};

CRF_OBSERVER_RESULT CRFObserverInit(CRFObserver &observer, const string symbol,
                                    const string filename, const int flags,
                                    const CRFParameters &parameters,
                                    const bool coordinator_locked)
{
   observer.ready=false;
   if(!coordinator_locked || symbol=="" || filename=="" || !CRFParametersValid(parameters))
      return CRF_OBSERVER_INVALID;
   CRFForecastState loaded; CRFResetForecast(loaded);
   CRF_JOURNAL_RESULT result=CRFLoadForecast(filename,flags,parameters,loaded);
   if(result!=CRF_JOURNAL_OK && result!=CRF_JOURNAL_MISSING)
      return CRF_OBSERVER_JOURNAL_ERROR;
   observer.symbol=symbol; observer.filename=filename; observer.flags=flags;
   observer.parameters=parameters; observer.forecast=loaded; observer.ready=true;
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
   MqlRates rates[]; bool first=false; long latest=0;
   CRF_M15_RESULT read=CRFReadClosedM15(observer.symbol,observer.parameters,
                                       observer.forecast.last_bar,rates,first,latest);
   if(read!=CRF_M15_OK) return CRF_OBSERVER_HISTORY_UNAVAILABLE;
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
   return CRF_OBSERVER_OK;
}
#endif
