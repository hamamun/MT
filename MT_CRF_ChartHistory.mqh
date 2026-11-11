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
long g_crfChartFirstBar=0;
bool g_crfChartStarted=false, g_crfChartReady=false, g_crfChartError=false;
ulong g_crfChartRetry=0;

void CRFChartHistoryReset()
{
   ArrayFree(g_crfChartRates); ArrayFree(g_crfChartPrefix);
   CRFResetForecast(g_crfChartState);
   g_crfChartIndex=0; g_crfChartFirstBar=0; g_crfChartStarted=false; g_crfChartReady=false;
   g_crfChartError=false; g_crfChartRetry=0;
}
string CRFChartHistoryStatus()
{
   if(g_crfChartError) return " | chart history unavailable; retrying";
   if(!g_crfChartReady) return " | rebuilding chart history";
   return "";
}
void CRFChartHistoryFail(const string reason)
{
   Print("MT CRF chart history: ",reason);
   // A partial reconstruction must not be mistaken for a complete one.
   CRFRemoveObjects();
   ArrayFree(g_crfChartRates); ArrayFree(g_crfChartPrefix);
   CRFResetForecast(g_crfChartState);
   g_crfChartIndex=0; g_crfChartFirstBar=0; g_crfChartStarted=false; g_crfChartReady=false;
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

bool CRFChartLoadBatch()
{
   CRFParameters p=CRFInputParameters();
   bool first=false; long latest=0;
   long anchor=g_crfChartStarted?g_crfChartState.last_bar:0;
   CRF_M15_RESULT read=CRFReadClosedM15(_Symbol,p,anchor,g_crfChartRates,first,latest);
   if(read!=CRF_M15_OK) return false;
   int n=ArraySize(g_crfChartRates);
   int context=(int)MathMax(MathMax(p.atr,p.trend),MathMax(p.volume,p.swing))+3;
   if(n<context+2 || latest!=(long)g_crfChartRates[n-1].time) return false;
   for(int i=0;i<n;i++)
      if(g_crfChartRates[i].time<=0 || (i>0 && g_crfChartRates[i].time<=g_crfChartRates[i-1].time)) return false;
   int start=context+1;
   if(anchor==0)
   {
      if(!first) return false;
      g_crfChartFirstBar=(long)g_crfChartRates[0].time;
      CRFResetForecast(g_crfChartState);
   }
   else
   {
      int found=-1;
      for(int i=n-1;i>=0;i--) if((long)g_crfChartRates[i].time==anchor) { found=i; break; }
      if(found<context+1 || (!first && found+2<p.history+context)) return false;
      start=found+1;
   }
   ArrayFree(g_crfChartPrefix);
   if(ArrayResize(g_crfChartPrefix,start,n)!=start ||
      ArrayCopy(g_crfChartPrefix,g_crfChartRates,0,0,start)!=start) return false;
   g_crfChartIndex=start; g_crfChartStarted=true; g_crfChartReady=false;
   g_crfChartError=false;
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
      { g_crfChartReady=true; return; }
      if(!CRFChartLoadBatch()) { CRFChartHistoryFail("M15 history unavailable or incomplete"); return; }
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
   ArrayFree(g_crfChartRates); ArrayFree(g_crfChartPrefix);
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
}
#endif
