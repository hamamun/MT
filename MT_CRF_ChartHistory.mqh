#ifndef MT_CRF_CHART_HISTORY_MQH
#define MT_CRF_CHART_HISTORY_MQH

// Presentation-only replay. It never writes the forecast/execution journals,
// changes the observer, makes takeover decisions, or sends trade requests.
// Processing is sliced after broker management so a large history does not
// monopolize one timer/tick event. Historical results are never trade signals.
#define CRF_CHART_BATCH_BARS 256
#define CRF_CHART_BATCH_MS 75
#define CRF_CHART_RETRY_MS 5000
MqlRates g_crfChartRates[], g_crfChartPrefix[];
CRFForecastState g_crfChartState;
int g_crfChartIndex=0;
long g_crfChartFirstBar=0, g_crfChartUsableFirst=0;
bool g_crfChartStarted=false, g_crfChartReady=false, g_crfChartError=false;
ulong g_crfChartRetry=0;
string g_crfChartLoadDetail="", g_crfChartReportedReason="";

void CRFChartHistoryReset()
{
   ArrayFree(g_crfChartRates); ArrayFree(g_crfChartPrefix);
   CRFResetForecast(g_crfChartState);
   g_crfChartIndex=0; g_crfChartFirstBar=0; g_crfChartUsableFirst=0; g_crfChartStarted=false; g_crfChartReady=false;
   g_crfChartError=false; g_crfChartRetry=0; g_crfChartLoadDetail=""; g_crfChartReportedReason="";
}
string CRFChartHistoryStatus()
{
   if(g_crfChartError) return " | historical CRF drawings unavailable; retrying";
   if(!g_crfChartReady) return " | rebuilding historical CRF drawings";
   return "";
}
void CRFChartHistoryFail(const string reason)
{
   // Retry normally but do not flood Experts with the same error every 5s.
   if(reason!=g_crfChartReportedReason)
   { Print("MT CRF chart history: ",reason); g_crfChartReportedReason=reason; }
   // A partial reconstruction must not be mistaken for a complete one.
   CRFRemoveObjects();
   ArrayFree(g_crfChartRates); ArrayFree(g_crfChartPrefix);
   CRFResetForecast(g_crfChartState);
   g_crfChartIndex=0; g_crfChartFirstBar=0; g_crfChartUsableFirst=0; g_crfChartStarted=false; g_crfChartReady=false;
   g_crfChartError=true; g_crfChartRetry=GetTickCount64();
}

bool CRFChartCandidateMatches(const CRFCandidate &a, const CRFCandidate &b)
{
   return a.direction==b.direction && a.pattern==b.pattern && a.variant==b.variant &&
          a.break_level==b.break_level && a.stop==b.stop && a.marker==b.marker &&
          a.atr==b.atr && a.volume==b.volume && a.trend==b.trend && a.location==b.location;
}
bool CRFChartForecastMatches(const CRFForecastState &a, const CRFForecastState &b)
{
   return a.last_bar==b.last_bar && a.signal_bar==b.signal_bar &&
          a.pending_elapsed==b.pending_elapsed && a.bull_cooldown==b.bull_cooldown &&
          a.bear_cooldown==b.bear_cooldown && CRFChartCandidateMatches(a.pending,b.pending) &&
          CRFChartCandidateMatches(a.last_signal,b.last_signal) && a.last_entry==b.last_entry &&
          a.last_estimate.available==b.last_estimate.available && a.last_estimate.ready==b.last_estimate.ready &&
          a.last_estimate.samples==b.last_estimate.samples && a.last_estimate.duration_low==b.last_estimate.duration_low &&
          a.last_estimate.duration_high==b.last_estimate.duration_high && a.last_estimate.reason==b.last_estimate.reason &&
          a.last_estimate.confidence==b.last_estimate.confidence && a.last_estimate.move_atr==b.last_estimate.move_atr &&
          a.last_estimate.duration==b.last_estimate.duration && a.last_estimate.target==b.last_estimate.target &&
          a.active_direction==b.active_direction && a.remaining==b.remaining && a.last_result==b.last_result &&
          a.last_event==b.last_event && a.last_event_bar==b.last_event_bar &&
          a.active_stop==b.active_stop && a.active_target==b.active_target;
}

bool CRFChartLevels(const CRFForecastState &s, const datetime through)
{
   if(s.active_direction==0) return true;
   return CRFSetLevel("entry",s.signal_bar,through,s.last_entry,clrAqua) &&
          CRFSetLevel("stop",s.signal_bar,through,s.active_stop,clrRed) &&
          CRFSetLevel("target",s.signal_bar,through,s.active_target,clrYellow);
}

// Both marker types refer to the just-closed M15 candle. In Indie the
// indicator executes on the following bar and uses offset=-1; shifting an
// already-closed M15 candle once more would draw on the wrong candle.
bool CRFChartApplyBar(const CRFForecastState &before, const CRFForecastState &after,
                      const MqlRates &bar)
{
   if(before.active_direction!=0 &&
      (after.active_direction==0 || after.signal_bar!=before.signal_bar) &&
      !CRFChartLevels(before,(datetime)bar.time)) return false;
   if(after.last_event_bar==(long)bar.time && after.last_event==1 &&
      !CRFSetMarker((long)bar.time,true,after.pending.direction,after.pending.marker)) return false;
   // A confirmation is still plotted when no historical estimate exists
   // (last_event == 5); signal_bar records both estimated and unestimated ones.
   if(after.signal_bar==(long)bar.time && after.last_signal.direction!=0 &&
      !CRFSetMarker((long)bar.time,false,after.last_signal.direction,
                    after.last_signal.direction>0?bar.low:bar.high)) return false;
   return true;
}

// Fetch bounded slabs from oldest to newest. Keep enough preceding context
// in each slab for the exact same forecast/analog calculation, without
// silently truncating old chart drawings or imposing the full-copy cap.
bool CRFChartLoadBatch()
{
   CRFParameters p=CRFInputParameters();
   long synchronized=0, first=0;
   // A CopyRates request can initiate terminal synchronization; simply
   // checking SERIES_SYNCHRONIZED repeatedly need not start a download.
   MqlRates probe[];
   if(!SeriesInfoInteger(_Symbol,PERIOD_M15,SERIES_SYNCHRONIZED,synchronized) || synchronized==0)
   {
      CopyRates(_Symbol,PERIOD_M15,1,1,probe);
      g_crfChartLoadDetail="M15 series synchronizing; history requested"; return false;
   }
   if(!SeriesInfoInteger(_Symbol,PERIOD_M15,SERIES_FIRSTDATE,first) || first<=0)
   { g_crfChartLoadDetail="M15 first available bar unavailable"; return false; }
   if(g_crfChartStarted && first!=g_crfChartFirstBar)
   { g_crfChartLoadDetail="M15 first available bar changed during replay"; return false; }
   int firstShift=CRFFirstUsableM15Shift(_Symbol,first);
   if(g_crfChartStarted && (long)iTime(_Symbol,PERIOD_M15,firstShift)!=g_crfChartUsableFirst)
   { g_crfChartLoadDetail="M15 usable history boundary changed during replay"; return false; }
   int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
   int targetShift=iBarShift(_Symbol,PERIOD_M15,(datetime)g_crfObserver.forecast.last_bar,true);
   if(firstShift<context+2 || targetShift<1)
   { g_crfChartLoadDetail="M15 replay boundaries unavailable or insufficient"; return false; }
   int nextShift=firstShift-context-1;
   if(g_crfChartStarted)
   {
      int anchorShift=iBarShift(_Symbol,PERIOD_M15,(datetime)g_crfChartState.last_bar,true);
      if(anchorShift<1 || anchorShift>firstShift)
      { g_crfChartLoadDetail="M15 replay anchor missing"; return false; }
      nextShift=anchorShift-1;
   }
   if(nextShift<targetShift)
   { g_crfChartLoadDetail="M15 replay target moved behind its anchor"; return false; }
   int batch=(int)MathMin(CRF_CHART_BATCH_BARS,nextShift-targetShift+1);
   int overlap=(int)MathMin(p.history+context+2,firstShift-nextShift);
   int newest=nextShift-batch+1, count=batch+overlap;
   ArrayResize(g_crfChartRates,0);
   if(!ArraySetAsSeries(g_crfChartRates,false))
   { g_crfChartLoadDetail="M15 slab array setup failed"; return false; }
   ResetLastError();
   int copied=CopyRates(_Symbol,PERIOD_M15,newest,count,g_crfChartRates), err=GetLastError();
   if(copied!=count || ArraySize(g_crfChartRates)!=count)
   { g_crfChartLoadDetail=StringFormat("M15 slab CopyRates returned %d of %d bars (error %d)",copied,count,err); return false; }
   long firstAfter=0,syncAfter=0;
   if(!SeriesInfoInteger(_Symbol,PERIOD_M15,SERIES_SYNCHRONIZED,syncAfter) || syncAfter==0 ||
      !SeriesInfoInteger(_Symbol,PERIOD_M15,SERIES_FIRSTDATE,firstAfter) || firstAfter!=first ||
      iTime(_Symbol,PERIOD_M15,newest)!=(datetime)g_crfChartRates[count-1].time ||
      iTime(_Symbol,PERIOD_M15,nextShift)!=(datetime)g_crfChartRates[overlap].time ||
      (g_crfChartStarted && g_crfChartRates[overlap-1].time!=g_crfChartState.last_bar))
   { g_crfChartLoadDetail="M15 history changed during slab copy"; return false; }
   for(int i=0;i<count;i++)
      if(g_crfChartRates[i].time<=0 || (i>0 && g_crfChartRates[i].time<=g_crfChartRates[i-1].time))
      { g_crfChartLoadDetail="M15 slab is not in chronological order"; return false; }
   if(!g_crfChartStarted)
   {
      if(overlap!=context+1 || g_crfChartRates[0].time!=iTime(_Symbol,PERIOD_M15,firstShift))
      { g_crfChartLoadDetail="M15 first replay bar could not be verified"; return false; }
      g_crfChartFirstBar=first; g_crfChartUsableFirst=(long)g_crfChartRates[0].time; CRFResetForecast(g_crfChartState);
   }
   if(g_crfChartStarted && ArraySize(g_crfChartPrefix)>0 && !CRFM15SameOverlap(g_crfChartPrefix,g_crfChartRates,overlap))
   { g_crfChartLoadDetail="M15 history revised during chart replay"; return false; }
   ArrayFree(g_crfChartPrefix);
   if(ArrayResize(g_crfChartPrefix,overlap,count)!=overlap ||
      ArrayCopy(g_crfChartPrefix,g_crfChartRates,0,0,overlap)!=overlap)
   { g_crfChartLoadDetail="M15 replay allocation or copy failed"; return false; }
   g_crfChartIndex=overlap; g_crfChartStarted=true; g_crfChartReady=false; g_crfChartError=false;
   return true;
}

void CRFChartHistoryStep()
{
   if(InpMode==MT_CRF_MODE_MT || !ChartSupported()) return;
   if(!g_crfObserverAvailable || !g_crfForecastCurrent || !g_crfObserver.ready) return;
   ulong now=GetTickCount64();
   if(g_crfChartError && now-g_crfChartRetry<CRF_CHART_RETRY_MS) return;
   if(g_crfChartStarted)
   {
      long synchronized=0, first=0;
      if(!SeriesInfoInteger(_Symbol,PERIOD_M15,SERIES_SYNCHRONIZED,synchronized) || synchronized==0 ||
         !SeriesInfoInteger(_Symbol,PERIOD_M15,SERIES_FIRSTDATE,first) || first!=g_crfChartFirstBar)
      { CRFChartHistoryFail("M15 history changed or is not synchronized"); return; }
   }
   if(ArraySize(g_crfChartRates)==0)
   {
      if(g_crfChartStarted && g_crfChartState.last_bar==g_crfObserver.forecast.last_bar)
      {
         if(!CRFChartForecastMatches(g_crfChartState,g_crfObserver.forecast))
         { CRFChartHistoryFail("replay differs from saved forecast; check M15 history"); return; }
         g_crfChartReady=true; return;
      }
      if(!CRFChartLoadBatch()) { CRFChartHistoryFail(g_crfChartLoadDetail!=""?g_crfChartLoadDetail:"M15 replay data unavailable"); return; }
   }
   CRFParameters p=CRFInputParameters();
   int n=ArraySize(g_crfChartRates), processed=0; ulong started=GetTickCount64();
   while(g_crfChartIndex<n && processed<CRF_CHART_BATCH_BARS)
   {
      int i=g_crfChartIndex;
      if(ArrayResize(g_crfChartPrefix,i+1,n)!=i+1)
      { CRFChartHistoryFail("history allocation failed"); return; }
      g_crfChartPrefix[i]=g_crfChartRates[i];
      CRFForecastState previous=g_crfChartState, next=previous;
      if(!CRFForecastOnBar(g_crfChartPrefix,(long)g_crfChartRates[i].time,p,next) ||
         !CRFChartApplyBar(previous,next,g_crfChartRates[i]))
      { CRFChartHistoryFail("replay or chart object failed"); return; }
      g_crfChartState=next; g_crfChartIndex++; processed++;
      if(GetTickCount64()-started>=CRF_CHART_BATCH_MS) break;
   }
   if(g_crfChartIndex<n) return;
   ArrayFree(g_crfChartRates);
   // Keep the bounded prefix until the next slab to detect revised overlap.
   // The live observer may have advanced during replay. Catch up using its
   // newly available history before drawing the final active segment.
   if(g_crfChartState.last_bar!=g_crfObserver.forecast.last_bar) return;
   if(!CRFChartForecastMatches(g_crfChartState,g_crfObserver.forecast))
   { CRFChartHistoryFail("replay differs from saved forecast; check M15 history"); return; }
   int shift=iBarShift(_Symbol,PERIOD_M15,(datetime)g_crfChartState.last_bar,true);
   datetime through=shift>=1?iTime(_Symbol,PERIOD_M15,shift-1):0;
   if(g_crfChartState.active_direction!=0 && (through<=0 || !CRFChartLevels(g_crfChartState,through)))
   { CRFChartHistoryFail("active forecast chart object failed"); return; }
   g_crfChartReady=true;
   if(g_crfChartReportedReason!="")
   { Print("MT CRF chart history: ","historical CRF drawings rebuilt"); g_crfChartReportedReason=""; }
}
#endif
