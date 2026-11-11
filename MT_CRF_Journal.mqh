#ifndef MT_CRF_JOURNAL_MQH
#define MT_CRF_JOURNAL_MQH
#include "MT_CRF_Forecast.mqh"

// Forecast-only journal. The caller must hold the account/server/symbol lock
// and must separately persist and reconcile broker request/order/position state.
// A failed write/read is never permission to place or retry a broker request.
enum CRF_JOURNAL_RESULT
{
   CRF_JOURNAL_OK=0,
   CRF_JOURNAL_MISSING=1,
   CRF_JOURNAL_INVALID=2,
   CRF_JOURNAL_CONFIG_CHANGED=3,
   CRF_JOURNAL_IO_ERROR=4
};

bool CRFCandidateValid(const CRFCandidate &c)
{
   if(!MathIsValidNumber(c.break_level) || !MathIsValidNumber(c.stop) ||
      !MathIsValidNumber(c.marker) || !MathIsValidNumber(c.atr) ||
      !MathIsValidNumber(c.volume) || !MathIsValidNumber(c.trend) ||
      !MathIsValidNumber(c.location)) return false;
   if(c.direction==0) return true;
   return (c.direction==1 || c.direction==-1) && c.pattern>=1 && c.pattern<=3 &&
          CRFValidPrice(c.break_level) && CRFValidPrice(c.stop) && CRFValidPrice(c.marker) &&
          MathIsValidNumber(c.atr) && c.atr>0 && MathIsValidNumber(c.volume) &&
          MathIsValidNumber(c.trend) && MathIsValidNumber(c.location) &&
          (c.direction>0 ? c.stop<c.break_level : c.stop>c.break_level);
}
bool CRFForecastValid(const CRFParameters &p, const CRFForecastState &s)
{
   if(!CRFParametersValid(p) || s.last_bar<0 || s.last_event_bar<0 || s.last_event_bar>s.last_bar || s.signal_bar<0 || s.signal_bar>s.last_bar ||
      s.bull_cooldown<0 || s.bull_cooldown>p.swing+2 || s.bear_cooldown<0 || s.bear_cooldown>p.swing+2 ||
      s.pending_elapsed<0 || s.pending_elapsed>1 || (s.pending.direction==0 && s.pending_elapsed!=0) ||
      !CRFCandidateValid(s.pending) || !CRFCandidateValid(s.last_signal) ||
      s.last_result<0 || s.last_result>6 || s.last_event<0 || s.last_event>6 ||
      s.last_estimate.reason<1 || s.last_estimate.reason>5 ||
      s.last_estimate.samples<0 || s.last_estimate.samples>p.history ||
      s.last_estimate.duration_low<0 || s.last_estimate.duration_high<0 ||
      s.last_estimate.duration_low>p.horizon || s.last_estimate.duration_high>p.horizon ||
      !MathIsValidNumber(s.last_entry) || !MathIsValidNumber(s.active_stop) ||
      !MathIsValidNumber(s.active_target) || !MathIsValidNumber(s.last_estimate.target) ||
      !MathIsValidNumber(s.last_estimate.confidence) || s.last_estimate.confidence<0 || s.last_estimate.confidence>100.0000001 ||
      !MathIsValidNumber(s.last_estimate.move_atr) || s.last_estimate.move_atr<0 ||
      !MathIsValidNumber(s.last_estimate.duration) || s.last_estimate.duration<0 || s.last_estimate.duration>p.horizon ||
      (s.active_direction!=0 && s.active_direction!=1 && s.active_direction!=-1)) return false;
   if(s.last_signal.direction==0)
   {
      if(s.signal_bar!=0 || s.last_estimate.available || s.last_estimate.ready || s.active_direction!=0) return false;
   }
   else if(s.signal_bar<=0 || !CRFValidPrice(s.last_entry) ||
           (s.last_signal.direction>0 ? s.last_entry<=s.last_signal.break_level : s.last_entry>=s.last_signal.break_level)) return false;
   if(s.last_estimate.available)
   {
      if(s.last_signal.direction==0 || s.last_estimate.samples<2 || s.last_estimate.reason<2 ||
         s.last_estimate.ready!=(s.last_estimate.reason==5) ||
         !CRFValidPrice(s.last_estimate.target) || s.last_estimate.move_atr<=0 ||
         s.last_estimate.duration<=0 || s.last_estimate.duration_low<1 ||
         s.last_estimate.duration_high<1) return false;
      double target=s.last_entry+s.last_signal.direction*s.last_estimate.move_atr*s.last_signal.atr;
      double target_tolerance=MathMax(1.0,MathAbs(target))*1e-12;
      if(!CRFValidPrice(target) || MathAbs(s.last_estimate.target-target)>target_tolerance) return false;
      int expected_reason=5;
      if(s.last_estimate.samples<p.minimum_analogs) expected_reason=2;
      else if(s.last_estimate.confidence<p.followthrough) expected_reason=3;
      else if(s.last_estimate.move_atr<MathAbs(s.last_entry-s.last_signal.stop)/s.last_signal.atr*p.reward_risk) expected_reason=4;
      if(s.last_estimate.reason!=expected_reason) return false;
   }
   else if(s.last_estimate.ready || s.last_estimate.reason!=1) return false;
   if(s.active_direction!=0)
   {
      if(!s.last_estimate.available || s.active_direction!=s.last_signal.direction ||
         s.remaining<1 || s.remaining>s.last_estimate.duration_high ||
         !CRFValidPrice(s.active_stop) || !CRFValidPrice(s.active_target) ||
         s.active_stop!=s.last_signal.stop || s.active_target!=s.last_estimate.target) return false;
   }
   else if(s.remaining!=0) return false;
   return true;
}
void CRFWriteCandidate(int h, const CRFCandidate &c)
{
   FileWriteInteger(h,c.direction,INT_VALUE); FileWriteInteger(h,c.pattern,INT_VALUE);
   FileWriteInteger(h,c.variant,INT_VALUE); FileWriteDouble(h,c.break_level); FileWriteDouble(h,c.stop);
   FileWriteDouble(h,c.marker); FileWriteDouble(h,c.atr); FileWriteDouble(h,c.volume);
   FileWriteDouble(h,c.trend); FileWriteDouble(h,c.location);
}
void CRFReadCandidate(int h, CRFCandidate &c)
{
   c.direction=FileReadInteger(h,INT_VALUE); c.pattern=FileReadInteger(h,INT_VALUE);
   c.variant=FileReadInteger(h,INT_VALUE); c.break_level=FileReadDouble(h); c.stop=FileReadDouble(h);
   c.marker=FileReadDouble(h); c.atr=FileReadDouble(h); c.volume=FileReadDouble(h);
   c.trend=FileReadDouble(h); c.location=FileReadDouble(h);
}
void CRFWriteParameters(int h, const CRFParameters &p)
{
   FileWriteInteger(h,p.history,INT_VALUE); FileWriteInteger(h,p.horizon,INT_VALUE);
   FileWriteInteger(h,p.atr,INT_VALUE); FileWriteInteger(h,p.trend,INT_VALUE);
   FileWriteInteger(h,p.volume,INT_VALUE); FileWriteInteger(h,p.swing,INT_VALUE);
   FileWriteInteger(h,p.minimum_analogs,INT_VALUE); FileWriteInteger(h,p.followthrough,INT_VALUE);
   FileWriteDouble(h,p.reward_risk);
}
void CRFReadParameters(int h, CRFParameters &p)
{
   p.history=FileReadInteger(h,INT_VALUE); p.horizon=FileReadInteger(h,INT_VALUE);
   p.atr=FileReadInteger(h,INT_VALUE); p.trend=FileReadInteger(h,INT_VALUE);
   p.volume=FileReadInteger(h,INT_VALUE); p.swing=FileReadInteger(h,INT_VALUE);
   p.minimum_analogs=FileReadInteger(h,INT_VALUE); p.followthrough=FileReadInteger(h,INT_VALUE);
   p.reward_risk=FileReadDouble(h);
}
bool CRFParametersEqual(const CRFParameters &a, const CRFParameters &b)
{
   return a.history==b.history && a.horizon==b.horizon && a.atr==b.atr &&
          a.trend==b.trend && a.volume==b.volume && a.swing==b.swing &&
          a.minimum_analogs==b.minimum_analogs && a.followthrough==b.followthrough &&
          a.reward_risk==b.reward_risk;
}

bool CRFSaveForecast(const string filename, const int flags, const CRFParameters &p,
                     const CRFForecastState &s)
{
   if(filename=="" || !CRFForecastValid(p,s)) return false;
   string tmp=filename+".tmp";
   int h=FileOpen(tmp,FILE_WRITE|FILE_BIN|flags);
   if(h==INVALID_HANDLE) return false;
   ResetLastError();
   FileWriteInteger(h,1296253510,INT_VALUE); FileWriteInteger(h,1,INT_VALUE);
   CRFWriteParameters(h,p);
   FileWriteLong(h,s.last_bar); FileWriteInteger(h,s.pending_elapsed,INT_VALUE);
   FileWriteInteger(h,s.bull_cooldown,INT_VALUE); FileWriteInteger(h,s.bear_cooldown,INT_VALUE);
   CRFWriteCandidate(h,s.pending); CRFWriteCandidate(h,s.last_signal);
   FileWriteDouble(h,s.last_entry);
   FileWriteInteger(h,s.last_estimate.available?1:0,INT_VALUE);
   FileWriteInteger(h,s.last_estimate.ready?1:0,INT_VALUE);
   FileWriteInteger(h,s.last_estimate.samples,INT_VALUE); FileWriteInteger(h,s.last_estimate.duration_low,INT_VALUE);
   FileWriteInteger(h,s.last_estimate.duration_high,INT_VALUE); FileWriteInteger(h,s.last_estimate.reason,INT_VALUE);
   FileWriteDouble(h,s.last_estimate.confidence); FileWriteDouble(h,s.last_estimate.move_atr);
   FileWriteDouble(h,s.last_estimate.duration); FileWriteDouble(h,s.last_estimate.target);
   FileWriteInteger(h,s.active_direction,INT_VALUE); FileWriteInteger(h,s.remaining,INT_VALUE);
   FileWriteInteger(h,s.last_result,INT_VALUE); FileWriteInteger(h,s.last_event,INT_VALUE);
   FileWriteDouble(h,s.active_stop); FileWriteDouble(h,s.active_target); FileWriteLong(h,s.last_event_bar);
   FileWriteLong(h,s.signal_bar);
   FileFlush(h);
   bool ok=(GetLastError()==0 && FileSize(h)==316);
   FileClose(h);
   if(!ok) return false;
   return FileMove(tmp,flags,filename,flags|FILE_REWRITE);
}

CRF_JOURNAL_RESULT CRFLoadForecast(const string filename, const int flags,
                                   const CRFParameters &expected, CRFForecastState &state)
{
   if(filename=="" || !CRFParametersValid(expected)) return CRF_JOURNAL_INVALID;
   if(!FileIsExist(filename,flags)) return CRF_JOURNAL_MISSING;
   int h=FileOpen(filename,FILE_READ|FILE_BIN|flags);
   if(h==INVALID_HANDLE) return CRF_JOURNAL_IO_ERROR;
   if(FileSize(h)!=316) { FileClose(h); return CRF_JOURNAL_INVALID; }
   ResetLastError();
   int magic=FileReadInteger(h,INT_VALUE), version=FileReadInteger(h,INT_VALUE);
   CRFParameters actual; CRFReadParameters(h,actual);
   CRFForecastState s; CRFResetForecast(s);
   s.last_bar=FileReadLong(h); s.pending_elapsed=FileReadInteger(h,INT_VALUE);
   s.bull_cooldown=FileReadInteger(h,INT_VALUE); s.bear_cooldown=FileReadInteger(h,INT_VALUE);
   CRFReadCandidate(h,s.pending); CRFReadCandidate(h,s.last_signal);
   s.last_entry=FileReadDouble(h);
   int available=FileReadInteger(h,INT_VALUE), ready=FileReadInteger(h,INT_VALUE);
   s.last_estimate.available=available==1; s.last_estimate.ready=ready==1;
   s.last_estimate.samples=FileReadInteger(h,INT_VALUE); s.last_estimate.duration_low=FileReadInteger(h,INT_VALUE);
   s.last_estimate.duration_high=FileReadInteger(h,INT_VALUE); s.last_estimate.reason=FileReadInteger(h,INT_VALUE);
   s.last_estimate.confidence=FileReadDouble(h); s.last_estimate.move_atr=FileReadDouble(h);
   s.last_estimate.duration=FileReadDouble(h); s.last_estimate.target=FileReadDouble(h);
   s.active_direction=FileReadInteger(h,INT_VALUE); s.remaining=FileReadInteger(h,INT_VALUE);
   s.last_result=FileReadInteger(h,INT_VALUE); s.last_event=FileReadInteger(h,INT_VALUE);
   s.active_stop=FileReadDouble(h); s.active_target=FileReadDouble(h); s.last_event_bar=FileReadLong(h);
   s.signal_bar=FileReadLong(h);
   bool io=(GetLastError()==0 && FileTell(h)==FileSize(h)); FileClose(h);
   if(!io) return CRF_JOURNAL_IO_ERROR;
   if(magic!=1296253510 || version!=1 || (available!=0 && available!=1) || (ready!=0 && ready!=1) ||
      !CRFParametersValid(actual) || !CRFForecastValid(actual,s)) return CRF_JOURNAL_INVALID;
   if(!CRFParametersEqual(actual,expected)) return CRF_JOURNAL_CONFIG_CHANGED;
   state=s;
   return CRF_JOURNAL_OK;
}
#endif
