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

// Bars()/SERIES_FIRSTDATE may expose more than CopyRates is allowed to
// retrieve. MT5 limits CopyRates to TERMINAL_MAXBARS including shift zero.
int CRFFirstUsableM15Shift(const string symbol, const long first)
{
   if(first<=0) return -1;
   int total=Bars(symbol,PERIOD_M15);
   if(total<2) return -1;
   int shift=total-1;
   long maxBars=TerminalInfoInteger(TERMINAL_MAXBARS);
   if(maxBars>1 && (long)shift>maxBars-1) shift=(int)(maxBars-1);
   return iTime(symbol,PERIOD_M15,shift)>0?shift:-1;
}

// Compare the common tail of consecutive slab prefixes, including OHLC and
// tick volume; a broker revision must not be mixed into a staged replay.
bool CRFM15SameOverlap(const MqlRates &previous[], const MqlRates &current[], const int overlap)
{
   int old=ArraySize(previous)-1, next=overlap-1;
   while(old>=0 && next>=0)
   {
      if(previous[old].time!=current[next].time || previous[old].open!=current[next].open ||
         previous[old].high!=current[next].high || previous[old].low!=current[next].low ||
         previous[old].close!=current[next].close || previous[old].tick_volume!=current[next].tick_volume)
         return false;
      old--; next--;
   }
   return true;
}

// Report the failing operation, not merely "history unavailable". Do not
// substitute a shorter copy: bootstraps and catch-up require the same complete
// validated series as before, and diagnostics must not change trade behavior.
CRF_M15_RESULT CRFReadClosedM15Detailed(const string symbol, const CRFParameters &p,
                                        const long anchor, MqlRates &out[],
                                        bool &starts_at_known_first_bar, long &latest,
                                        string &detail)
{
   ArrayResize(out,0); starts_at_known_first_bar=false; latest=0; detail="";
   if(symbol=="" || !CRFParametersValid(p) || anchor<0)
   { detail="invalid symbol, parameters or history anchor"; return CRF_M15_BAD_INPUT; }
   long synchronized=0, first_date=0;
   ResetLastError();
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_SYNCHRONIZED,synchronized))
   { detail=StringFormat("M15 synchronization query failed (error %d)",GetLastError()); return CRF_M15_WAIT_HISTORY; }
   if(synchronized==0)
   {
      // Trigger MT5's asynchronous history preparation rather than only
      // polling a synchronization flag that may never start a download.
      MqlRates probe[]; CopyRates(symbol,PERIOD_M15,1,1,probe);
      detail="M15 series is not synchronized; history requested"; return CRF_M15_WAIT_HISTORY;
   }
   ResetLastError();
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_FIRSTDATE,first_date) || first_date<=0)
   { detail=StringFormat("M15 first available bar unavailable (error %d)",GetLastError()); return CRF_M15_WAIT_HISTORY; }
   ResetLastError();
   int total=Bars(symbol,PERIOD_M15);
   if(total<3)
   { detail=StringFormat("M15 has fewer than 3 available bars (Bars=%d, error %d)",total,GetLastError()); return CRF_M15_WAIT_HISTORY; }
   ResetLastError();
   datetime closed=iTime(symbol,PERIOD_M15,1);
   if(closed<=0)
   { detail=StringFormat("latest closed M15 bar unavailable (error %d)",GetLastError()); return CRF_M15_WAIT_HISTORY; }
   int available=total-1;
   long maxBars=TerminalInfoInteger(TERMINAL_MAXBARS);
   if(maxBars>1 && (long)available>maxBars-1) available=(int)(maxBars-1);
   int count=available;
   if(anchor>0)
   {
      ResetLastError();
      int shift=iBarShift(symbol,PERIOD_M15,(datetime)anchor,true);
      if(shift<1)
      { detail=StringFormat("saved M15 anchor not found (error %d)",GetLastError()); return CRF_M15_ANCHOR_MISSING; }
      int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
      long required=(long)shift+p.history+context+2;
      if(required<count) count=(int)required;
   }
   if(count>CRF_MAX_LOADED_BARS)
   {
      detail=StringFormat("M15 copy requires %d closed bars; limit is %d",count,CRF_MAX_LOADED_BARS);
      return CRF_M15_TOO_MUCH_HISTORY;
   }
   ResetLastError();
   if(!ArraySetAsSeries(out,false))
   { detail=StringFormat("M15 array setup failed (error %d)",GetLastError()); return CRF_M15_WAIT_HISTORY; }
   ResetLastError();
   int copied=CopyRates(symbol,PERIOD_M15,1,count,out);
   int copy_error=GetLastError();
   if(copied!=count || ArraySize(out)!=count)
   {
      detail=StringFormat("M15 CopyRates returned %d of %d bars (array %d, error %d)",copied,count,ArraySize(out),copy_error);
      ArrayResize(out,0); return CRF_M15_WAIT_HISTORY;
   }
   long synchronized_after=0, first_after=0;
   ResetLastError();
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_SYNCHRONIZED,synchronized_after) || synchronized_after==0)
   { detail=StringFormat("M15 series lost synchronization during copy (error %d)",GetLastError()); ArrayResize(out,0); return CRF_M15_HISTORY_CHANGED; }
   ResetLastError();
   if(!SeriesInfoInteger(symbol,PERIOD_M15,SERIES_FIRSTDATE,first_after) || first_after!=first_date)
   { detail=StringFormat("M15 first available bar changed during copy (error %d)",GetLastError()); ArrayResize(out,0); return CRF_M15_HISTORY_CHANGED; }
   if(Bars(symbol,PERIOD_M15)!=total || iTime(symbol,PERIOD_M15,1)!=closed || out[count-1].time!=closed)
   { detail="M15 bar count or latest closed bar changed during copy"; ArrayResize(out,0); return CRF_M15_HISTORY_CHANGED; }
   if(count==available)
   {
      datetime firstUsable=iTime(symbol,PERIOD_M15,available);
      if(firstUsable<=0 || out[0].time!=firstUsable)
      { detail="M15 copied first bar differs from first usable chart bar"; ArrayResize(out,0); return CRF_M15_HISTORY_CHANGED; }
      starts_at_known_first_bar=true;
   }
   latest=(long)closed;
   return CRF_M15_OK;
}

CRF_M15_RESULT CRFReadClosedM15(const string symbol, const CRFParameters &p,
                                const long anchor, MqlRates &out[],
                                bool &starts_at_known_first_bar, long &latest)
{
   string detail="";
   return CRFReadClosedM15Detailed(symbol,p,anchor,out,starts_at_known_first_bar,latest,detail);
}
#endif
