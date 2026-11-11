#ifndef MT_CRF_M15_MQH
#define MT_CRF_M15_MQH
#include "MT_CRF_Feed.mqh"

// The loader itself never places orders. Its caller must hold the forecast
// journal/coordinator lock, save state, and reconcile the broker.
// A cap avoids monopolising an MT5 terminal on a huge initial chart history;
// hitting it is an explicit unavailable result, never a truncated bootstrap.
#define CRF_MAX_LOADED_BARS 100000

enum CRF_M15_RESULT
{
   CRF_M15_OK=0,
   CRF_M15_WAIT_HISTORY=1,
   CRF_M15_HISTORY_CHANGED=2,
   CRF_M15_TOO_MUCH_HISTORY=3,
   CRF_M15_ANCHOR_MISSING=4,
   CRF_M15_BAD_INPUT=5
};

CRF_M15_RESULT CRFReadClosedM15(const string symbol, const CRFParameters &p,
                                const long anchor, MqlRates &out[],
                                bool &starts_at_known_first_bar, long &latest)
{
   ArrayResize(out,0); starts_at_known_first_bar=false; latest=0;
   if(symbol=="" || !CRFParametersValid(p) || anchor<0) return CRF_M15_BAD_INPUT;
   long synchronized=0, first_date=0;
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_SYNCHRONIZED,synchronized) || synchronized==0 ||
      !SeriesInfoInteger(symbol,PERIOD_M15,SERIES_FIRSTDATE,first_date) || first_date<=0)
      return CRF_M15_WAIT_HISTORY;
   int total=Bars(symbol,PERIOD_M15);
   datetime closed=iTime(symbol,PERIOD_M15,1);
   if(total<3 || closed<=0) return CRF_M15_WAIT_HISTORY;
   int count=total-1;
   if(anchor>0)
   {
      int shift=iBarShift(symbol,PERIOD_M15,(datetime)anchor,true);
      if(shift<1) return CRF_M15_ANCHOR_MISSING;
      int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
      long required=(long)shift+p.history+context+2;
      if(required<count) count=(int)required;
   }
   if(count>CRF_MAX_LOADED_BARS) return CRF_M15_TOO_MUCH_HISTORY;
   if(!ArraySetAsSeries(out,false)) return CRF_M15_WAIT_HISTORY;
   int copied=CopyRates(symbol,PERIOD_M15,1,count,out);
   if(copied!=count || ArraySize(out)!=count)
   { ArrayResize(out,0); return CRF_M15_WAIT_HISTORY; }
   long synchronized_after=0, first_after=0;
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_SYNCHRONIZED,synchronized_after) || synchronized_after==0 ||
      !SeriesInfoInteger(symbol,PERIOD_M15,SERIES_FIRSTDATE,first_after) || first_after!=first_date ||
      Bars(symbol,PERIOD_M15)!=total || iTime(symbol,PERIOD_M15,1)!=closed || out[count-1].time!=closed)
   { ArrayResize(out,0); return CRF_M15_HISTORY_CHANGED; }
   if(count==total-1)
   {
      if((long)out[0].time!=first_date)
      { ArrayResize(out,0); return CRF_M15_HISTORY_CHANGED; }
      starts_at_known_first_bar=true;
   }
   latest=(long)closed;
   return CRF_M15_OK;
}
#endif
