#ifndef MT_CRF_EXECUTION_MQH
#define MT_CRF_EXECUTION_MQH
#include "MT_CRF_Observer.mqh"
#include "MT_CRF_Exposure.mqh"

// Never use forecast candle touches as broker fill or closure evidence.
CRFObserver g_crfObserver;
bool g_crfObserverAvailable=false, g_crfForecastCurrent=false;
string g_crfStatus="Starting";
// Last actual entry check, scoped to the signal so timer refreshes cannot
// replace a broker rejection with a misleading generic slot message.
string g_crfEntryReason="", g_crfOrderCheckReason="";
long g_crfEntryReasonSignal=0;
bool CRFEntryBlocked(const string reason) { g_crfEntryReason=reason; return false; }

CRFParameters CRFInputParameters()
{
   CRFParameters p;
   p.history=InpCrfHistoryBars; p.horizon=InpCrfMaxHorizon;
   p.atr=InpCrfAtrLength; p.trend=InpCrfTrendLength; p.volume=InpCrfVolumeLength;
   p.swing=InpCrfSwingLength; p.minimum_analogs=InpCrfMinimumAnalogs;
   p.followthrough=InpCrfMinFollowthroughPct; p.reward_risk=InpCrfMinRewardRisk;
   return p;
}

bool CRFLaterM15Bar()
{
   if(g_crfReleaseBar==0) return true;
   int shift=iBarShift(_Symbol,PERIOD_M15,g_crfReleaseBar,true);
   return shift>=2;
}

// Keep the reference forecast/indicator quality at 55%, including its saved
// journal. This separate, user-selected gate affects auto trading only.
// 0=eligible, 1=unavailable/invalid, 2=samples, 3=follow-through, 4=R/R.
int CRFAutoFilterReason(const CRFForecastState &f)
{
   if(InpCrfAutoFollowthroughPct<1 || InpCrfAutoFollowthroughPct>100 ||
      (f.active_direction!=1 && f.active_direction!=-1) || f.signal_bar<=0 ||
      !f.last_estimate.available || !P3Positive(f.last_entry) ||
      !P3Positive(f.last_signal.stop) || !P3Positive(f.last_signal.atr) ||
      !P3Positive(f.last_estimate.move_atr) || !MathIsValidNumber(f.last_estimate.confidence) ||
      f.last_estimate.confidence<0 || f.last_estimate.confidence>100.0000001) return 1;
   if(f.last_estimate.samples<InpCrfMinimumAnalogs) return 2;
   if(f.last_estimate.confidence<InpCrfAutoFollowthroughPct) return 3;
   double riskATR=MathAbs(f.last_entry-f.last_signal.stop)/f.last_signal.atr;
   if(!P3Positive(riskATR) || !MathIsValidNumber(riskATR*InpCrfMinRewardRisk)) return 1;
   if(!InpCrfRiskBypass && f.last_estimate.move_atr<riskATR*InpCrfMinRewardRisk) return 4;
   return 0;
}
bool CRFAutoFilterReady(const CRFForecastState &f) { return CRFAutoFilterReason(f)==0; }

// Called by the copied MT engine, never by the original MT EA.
bool CRFNativeLaneBlocked(int lane)
{
   if(InpMode==MT_CRF_MODE_CRF) return true;
   if(lane!=1) return false;
   if(!g_p4Ready || g_crfCloseKind!=0 || g_p4[3].active!=0 ||
      g_p4View[3].state!=P4_EMPTY || !CRFLaterM15Bar()) return true;
   if(InpMode==MT_CRF_MODE_MT || !P4LaneEnabled(1)) return false;
   if(!g_crfObserverAvailable || !g_crfForecastCurrent || !g_crfObserver.ready || g_crfTakeover!=0) return true;
   CRFForecastState f=g_crfObserver.forecast;
   return f.active_direction!=0 && CRFAutoFilterReady(f) && f.signal_bar!=g_crfAttemptedSignalBar;
}

void CRFInitRuntime()
{
   g_crfObserverAvailable=false; g_crfForecastCurrent=false; g_crfStatus="Waiting for coordinator";
   g_crfEntryReason=""; g_crfOrderCheckReason=""; g_crfEntryReasonSignal=0;
   if(!g_p4Ready) return;
   if(InpMode==MT_CRF_MODE_MT) { g_crfStatus="MT only"; return; }
   CRFParameters p=CRFInputParameters();
   CRF_OBSERVER_RESULT result=CRFObserverInit(g_crfObserver,_Symbol,P3DiaryKey()+"_crf_forecast.bin",
                                               g_p4Flags,p,g_p4Ready);
   if(result!=CRF_OBSERVER_OK) { g_crfStatus="Forecast journal or inputs: REVIEW"; return; }
   // A forecast may have been saved immediately before a crash, before its
   // execution intent was saved. Never replay such an unclaimed signal on
   // restart. A previously persisted takeover or broker intent is reconciled.
   if(g_crfObserver.forecast.signal_bar>0 && g_crfTakeover==0 && g_p4[3].active==0 &&
      g_crfObserver.forecast.signal_bar!=g_crfAttemptedSignalBar)
   {
      g_crfAttemptedSignalBar=(datetime)g_crfObserver.forecast.signal_bar;
      if(!P4Persist()) { g_crfStatus="Execution journal unavailable: REVIEW"; return; }
   }
   g_crfObserverAvailable=true; g_crfStatus="Waiting for M15 history";
}

void CRFUpdateForecast()
{
   if(InpMode==MT_CRF_MODE_MT || !g_crfObserverAvailable || !g_p4Ready) return;
   datetime closed=iTime(_Symbol,PERIOD_M15,1);
   if(g_crfForecastCurrent && closed>0 && (long)closed==g_crfObserver.forecast.last_bar) return;
   CRFFeedUpdate updates[];
   CRF_OBSERVER_RESULT r=CRFObserverPoll(g_crfObserver,updates);
   if(r!=CRF_OBSERVER_OK)
   {
      g_crfStatus=r==CRF_OBSERVER_HISTORY_UNAVAILABLE?"M15 history unavailable: REVIEW":"Forecast state unavailable: REVIEW";
      g_crfForecastCurrent=false;
      if(r==CRF_OBSERVER_JOURNAL_ERROR || r==CRF_OBSERVER_INVALID) g_crfObserverAvailable=false;
      return;
   }
   g_crfForecastCurrent=true;
   if(ArraySize(updates)>0 && g_p4[3].active==0 && g_crfTakeover==0 &&
      (updates[0].bootstrap || g_crfObserver.forecast.signal_bar!=g_crfObserver.forecast.last_bar))
   {
      // Bootstrap and older catch-up confirmations are display-only.
      g_crfAttemptedSignalBar=(datetime)g_crfObserver.forecast.signal_bar;
      if(!P4Persist()) { g_crfObserverAvailable=false; g_crfStatus="Execution journal unavailable: REVIEW"; return; }
   }
   CRFForecastState f=g_crfObserver.forecast;
   if(P4LaneEnabled(1) && f.active_direction!=0 && CRFAutoFilterReady(f) && f.signal_bar!=g_crfAttemptedSignalBar && g_crfTakeover==0)
   {
      g_crfTakeover=1;
      if(!P4Persist()) { g_crfObserverAvailable=false; g_crfStatus="Execution journal unavailable: REVIEW"; return; }
   }
}

bool CRFProtectionAllowed()
{
   long orderMode=0, expiration=0, lifetime=0;
   if(!SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE,orderMode) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE,expiration) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_ORDER_GTC_MODE,lifetime)) return false;
   long required=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
   return (orderMode&required)==required && (expiration&SYMBOL_EXPIRATION_GTC)!=0 &&
          (lifetime==SYMBOL_ORDERS_GTC || lifetime==SYMBOL_ORDERS_DAILY_EXCLUDING_STOPS);
}

// The original quality filter is evaluated at the confirmation close. A late
// market entry must also satisfy it at the live executable price unless the
// CRF risk bypass is on. All live-level and spread checks remain mandatory.
string CRFLiveEntryReason(const CRFForecastState &f, const MqlTick &q, P3Plan &plan)
{
   ZeroMemory(plan);
   if((f.active_direction!=1 && f.active_direction!=-1) || !CRFAutoFilterReady(f) ||
      f.signal_bar<=0 || !P3Positive(f.last_entry) || !P3Positive(f.active_stop) ||
      !P3Positive(f.active_target) || !P4FreshQuote(q)) return "Forecast or quote unavailable";
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(!P3Positive(tick) || !P3Positive(InpCrfMinRewardRisk)) return "Live R/R unavailable";
   plan.signal=f.active_direction; plan.market=true; plan.bar=(datetime)f.signal_bar;
   plan.barProxy=!P3HasBidBars(); plan.entry=f.last_entry;
   plan.stop=plan.signal>0?P3Down(f.active_stop,tick):P3Up(f.active_stop,tick);
   plan.target=plan.signal>0?P3Down(f.active_target,tick):P3Up(f.active_target,tick);
   if(!P3Positive(plan.stop) || !P3Positive(plan.target)) return "Live SL/TP unavailable";
   string levelReason=P4LiveLevelReason(q,plan);
   if(levelReason!="") return levelReason;
   double price=plan.signal>0?q.ask:q.bid;
   if(!P4SpreadOK(plan.signal,price,plan.target,q)) return "Spread too high";
   double risk=plan.signal*(price-plan.stop), reward=plan.signal*(plan.target-price);
   if(!P3Positive(risk) || !P3Positive(reward) || !MathIsValidNumber(InpCrfMinRewardRisk*risk))
      return "Live R/R unavailable";
   if(!InpCrfRiskBypass && reward+tick*1e-8<InpCrfMinRewardRisk*risk) return "Below live R/R filter";
   return "";
}

bool CRFMakeRequestPlan(const CRFForecastState &f, const MqlTick &q, P3Plan &plan)
{
   if(CRFLiveEntryReason(f,q,plan)!="") return false;
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(!P3Positive(minimum) || !P3Positive(maximum) || !P3Positive(step)) return false;
   double price=plan.signal>0?q.ask:q.bid;
   double requested=0;
   if(InpMinimumLot) requested=minimum;
   else if(InpBypassRisk || InpCrfRiskBypass)
   {
      double balance=AccountInfoDouble(ACCOUNT_BALANCE);
      if(!P3Positive(balance)) return false;
      // CRF has no score, so no score-based 1.5 multiplier is invented.
      requested=balance/1000.0*0.01;
   }
   else
   {
      double equity=AccountInfoDouble(ACCOUNT_EQUITY), loss=0;
      if(!P3Positive(equity) || !OrderCalcProfit(plan.signal>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,
           _Symbol,minimum,price,plan.stop,loss) || !MathIsValidNumber(loss) || loss>=0) return false;
      requested=equity*0.005/(-loss/minimum);
   }
   plan.lot=InpMinimumLot?minimum:P3Volume(requested,minimum,maximum,step);
   if(!P3Positive(plan.lot)) return false;
   plan.priced=true; plan.valid=true;
   return true;
}

// Compute net and a conservative exit reserve from position-linked broker
// deals. Unknown/missing/contradictory history or no evidence of exit costs
// remains REVIEW, never permission to close an MT position.
bool CRFNetAndCloseBuffer(const CRFExposure &v, const MqlTick &q, double &net, double &buffer)
{
   net=0; buffer=0;
   if(v.kind!=CRF_EXPOSURE_MT_OPEN || v.position_id==0 || v.position_ticket==0 ||
      g_p4[1].active==0 || g_p4[1].order==0 || g_p4[1].position!=v.position_id ||
      g_p4View[1].state!=P4_OPEN || g_p4View[1].position!=v.position_id ||
      !P4FreshQuote(q) || !PositionSelectByTicket(v.position_ticket)) return false;
   long identifier=0,magic=0,type=0; string symbol="";
   double floating=0,swap=0,volume=0;
   if(!PositionGetInteger(POSITION_IDENTIFIER,identifier) || (ulong)identifier!=v.position_id ||
      !PositionGetInteger(POSITION_MAGIC,magic) || magic!=P4Magic(1) ||
      !PositionGetInteger(POSITION_TYPE,type) || !PositionGetString(POSITION_SYMBOL,symbol) || symbol!=_Symbol ||
      !PositionGetDouble(POSITION_PROFIT,floating) || !PositionGetDouble(POSITION_SWAP,swap) ||
      !PositionGetDouble(POSITION_VOLUME,volume) || !P3Positive(volume) ||
      !MathIsValidNumber(floating) || !MathIsValidNumber(swap) || !HistorySelectByPosition(v.position_id)) return false;
   double entered=0,exited=0,booked=0,charges=0;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i); long id=0,how=0,order=0;
      double vol=0,profit=0,commission=0,fee=0,dealSwap=0;
      if(deal==0 || !HistoryDealGetInteger(deal,DEAL_POSITION_ID,id) || (ulong)id!=v.position_id ||
         !HistoryDealGetInteger(deal,DEAL_ENTRY,how) || !HistoryDealGetInteger(deal,DEAL_ORDER,order) ||
         !HistoryDealGetDouble(deal,DEAL_VOLUME,vol) || !HistoryDealGetDouble(deal,DEAL_PROFIT,profit) ||
         !HistoryDealGetDouble(deal,DEAL_COMMISSION,commission) || !HistoryDealGetDouble(deal,DEAL_FEE,fee) ||
         !HistoryDealGetDouble(deal,DEAL_SWAP,dealSwap) || !P3Positive(vol) || !MathIsValidNumber(profit) ||
         !MathIsValidNumber(commission) || !MathIsValidNumber(fee) || !MathIsValidNumber(dealSwap)) return false;
      if(how==DEAL_ENTRY_IN)
      {
         if((ulong)order!=g_p4[1].order) return false;
         entered+=vol;
      }
      else if(how==DEAL_ENTRY_OUT || how==DEAL_ENTRY_OUT_BY) exited+=vol;
      else return false;
      booked+=profit+dealSwap+commission+fee; charges+=MathAbs(commission)+MathAbs(fee);
   }
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP), tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(!P3Positive(step) || !P3Positive(tick) || !P3Positive(entered) || charges<=0 ||
      MathAbs(entered-exited-volume)>step*1e-7 || MathAbs(volume-v.volume)>step*1e-7) return false;
   int direction=type==POSITION_TYPE_BUY?1:(type==POSITION_TYPE_SELL?-1:0);
   if(direction!=v.direction) return false;
   double base=direction>0?q.bid:q.ask, adverse=base-direction*(q.ask-q.bid+tick), cost=0;
   if(!P3Positive(adverse) || !OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,
      _Symbol,volume,base,adverse,cost) || !MathIsValidNumber(cost) || cost>0) return false;
   net=floating+swap+booked;
   buffer=-cost+2.0*charges*volume/entered;
   return MathIsValidNumber(net) && MathIsValidNumber(buffer) && buffer>=0;
}

bool CRFRequestPositionClose(const int kind, const CRFExposure &v, const MqlTick &q)
{
   if((kind!=1 && kind!=2) || !InpAutoTrading || g_crfCloseKind!=0 || !g_p4Ready || !P4CanTrade() ||
      g_marketState!=MARKET_OPEN || !P4FreshQuote(q) || v.position_ticket==0 || v.position_id==0 ||
      !PositionSelectByTicket(v.position_ticket)) return false;
   if(kind==1 && (!InpAutoTrading || !P4LaneEnabled(1) || !InpCrfCloseProfitableM15 || InpMode!=MT_CRF_MODE_BOTH ||
      AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)) return false;
   P3Plan crfPlan;
   if(kind==1 && (!g_crfObserverAvailable || !g_crfForecastCurrent ||
      g_crfObserver.forecast.signal_bar==g_crfAttemptedSignalBar ||
      CRFLiveEntryReason(g_crfObserver.forecast,q,crfPlan)!="")) return false;
   long id=0,magic=0,type=0; string symbol=""; double volume=0;
   long expected=kind==1?P4Magic(1):P4Magic(3);
   if(!PositionGetInteger(POSITION_IDENTIFIER,id) || (ulong)id!=v.position_id ||
      !PositionGetInteger(POSITION_MAGIC,magic) || magic!=expected ||
      !PositionGetInteger(POSITION_TYPE,type) || !PositionGetString(POSITION_SYMBOL,symbol) || symbol!=_Symbol ||
      !PositionGetDouble(POSITION_VOLUME,volume) || !P3Positive(volume) || volume!=v.volume ||
      (type!=POSITION_TYPE_BUY && type!=POSITION_TYPE_SELL)) return false;
   ENUM_ORDER_TYPE_FILLING fill;
   if(!P4FillMode(true,fill)) return false;
   ulong now=GetTickCount64(); if(g_p4Attempt[3]!=0 && now-g_p4Attempt[3]<5000) return false;
   MqlTradeRequest request={}; MqlTradeCheckResult check={}; MqlTradeResult result={};
   request.action=TRADE_ACTION_DEAL; request.position=v.position_ticket; request.symbol=_Symbol;
   request.magic=(ulong)expected; request.volume=volume;
   request.type=type==POSITION_TYPE_BUY?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   request.price=type==POSITION_TYPE_BUY?q.bid:q.ask; request.deviation=10; request.type_filling=fill;
   request.comment=kind==1?"MT4-CRF takeover":"MT4-CRF exit";
   g_p4Attempt[3]=now;
   if(!OrderCheck(request,check) || check.retcode!=0) return false;
   CRFExposure again; MqlTick latest;
   if(!CRFScanExposure(_Symbol,P4Magic(1),P4Magic(3),P4Connected(),again) ||
      again.kind!=(kind==1?CRF_EXPOSURE_MT_OPEN:CRF_EXPOSURE_CRF_OPEN) ||
      again.position_id!=v.position_id || again.position_ticket!=v.position_ticket || again.volume!=volume ||
      !SymbolInfoTick(_Symbol,latest) || !P4FreshQuote(latest) || latest.bid!=q.bid || latest.ask!=q.ask ||
      !P4CanTrade() || !InpAutoTrading || (kind==1 && !P4LaneEnabled(1))) return false;
   if(kind==1)
   {
      double net=0, buffer=0;
      if(!g_crfObserverAvailable || !g_crfForecastCurrent ||
         g_crfObserver.forecast.signal_bar==g_crfAttemptedSignalBar ||
         CRFLiveEntryReason(g_crfObserver.forecast,latest,crfPlan)!="" ||
         !CRFNetAndCloseBuffer(again,latest,net,buffer) || net<=buffer) return false;
   }
   g_crfCloseKind=kind; g_crfClosePosition=v.position_id; g_crfCloseTicket=v.position_ticket; g_crfCloseVolume=volume;
   if(!P4Persist()) return false;
   bool sent=OrderSend(request,result);
   if(result.order==0 && result.deal==0 && P4DefiniteReject(result.retcode))
   {
      g_crfCloseKind=0; g_crfClosePosition=0; g_crfCloseTicket=0; g_crfCloseVolume=0;
      if(!P4Persist()) return false;
   }
   if(!sent) PrintFormat("MT CRF close request result %u error %d; awaiting reconciliation",result.retcode,GetLastError());
   return true;
}

bool CRFPlaceMarket(const MqlTick &q)
{
   if(g_crfEntryReasonSignal!=g_crfObserver.forecast.signal_bar) g_crfOrderCheckReason="";
   g_crfEntryReason="";
   g_crfEntryReasonSignal=g_crfObserver.forecast.signal_bar;
   if(!g_p4Ready) return CRFEntryBlocked("Execution coordinator unavailable: REVIEW");
   if(!g_p5Ready) return CRFEntryBlocked("Trade diary unavailable: REVIEW");
   if(!g_crfObserverAvailable || !g_crfForecastCurrent) return CRFEntryBlocked("Forecast unavailable");
   if(InpMode==MT_CRF_MODE_MT) return CRFEntryBlocked("CRF disabled in MT-only mode");
   if(!InpAutoTrading) return CRFEntryBlocked("Auto trading OFF");
   if(!P4LaneEnabled(1)) return CRFEntryBlocked("M15 autotrading OFF");
   if(!P4CanTrade()) return CRFEntryBlocked("Trading permission unavailable");
   if(!P4ScheduleOpen())
   {
      if(!g_p4ScheduleValid) return CRFEntryBlocked("Daily timer settings invalid");
      int minute=0;
      if(!P4ScheduleLocalMinute(minute)) return CRFEntryBlocked("Daily timer local clock unavailable");
      return CRFEntryBlocked("Daily timer paused");
   }
   if(!P4ScheduleBarReady(1)) return CRFEntryBlocked("Timer: waiting for next closed M15 bar");
   if(g_marketState!=MARKET_OPEN) return CRFEntryBlocked("Market not open");
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return CRFEntryBlocked("Hedging account required");
   if(!P4FreshQuote(q)) return CRFEntryBlocked("Fresh quote unavailable");
   if(!CRFProtectionAllowed()) return CRFEntryBlocked("Broker market order / SL / TP or protection lifetime unavailable");
   if(g_crfCloseKind!=0) return CRFEntryBlocked("Previous close awaiting broker reconciliation");
   if(!CRFLaterM15Bar()) return CRFEntryBlocked("Waiting for next closed M15 bar after release");
   CRFForecastState f=g_crfObserver.forecast;
   if(f.signal_bar<=0 || f.active_direction==0) return CRFEntryBlocked("Forecast unavailable");
   if(f.signal_bar==g_crfAttemptedSignalBar) return CRFEntryBlocked("Signal already used or not eligible for replay");
   if(!CRFAutoFilterReady(f)) return CRFEntryBlocked("Forecast auto filters not met");
   P4Refresh(1); P4Refresh(3);
   if(!g_p4Ready) return CRFEntryBlocked("Execution coordinator unavailable: REVIEW");
   CRFExposure exposure;
   if(!CRFScanExposure(_Symbol,P4Magic(1),P4Magic(3),P4Connected(),exposure) || exposure.kind==CRF_EXPOSURE_REVIEW)
      return CRFEntryBlocked("Broker state unavailable: REVIEW");
   if(exposure.kind!=CRF_EXPOSURE_EMPTY) return CRFEntryBlocked("M15 slot occupied; broker reconciliation required");
   if(g_p4View[1].state!=P4_EMPTY || g_p4View[3].state!=P4_EMPTY || g_p4[1].active!=0 || g_p4[3].active!=0)
      return CRFEntryBlocked("M15 execution state awaiting reconciliation");
   if(!P4CooldownReady(1)) return CRFEntryBlocked(g_p4Ready?"Waiting for next closed M15 bar after previous trade":"Execution coordinator unavailable: REVIEW");
   if(!g_p4Ready) return CRFEntryBlocked("Execution coordinator unavailable: REVIEW");
   P3Plan plan;
   string reason=CRFLiveEntryReason(f,q,plan);
   if(reason!="") return CRFEntryBlocked(reason);
   if(!CRFMakeRequestPlan(f,q,plan)) return CRFEntryBlocked("CRF lot sizing unavailable");
   ENUM_ORDER_TYPE_FILLING fill;
   if(!P4FillMode(true,fill)) return CRFEntryBlocked("Broker filling mode unavailable");
   ulong now=GetTickCount64();
   if(g_p4Attempt[3]!=0 && now-g_p4Attempt[3]<5000)
      return CRFEntryBlocked(g_crfOrderCheckReason!=""?g_crfOrderCheckReason+"; retry delay":"Request retry delay");
   MqlTradeRequest request={}; MqlTradeCheckResult check={}; MqlTradeResult result={};
   request.action=TRADE_ACTION_DEAL; request.symbol=_Symbol; request.magic=(ulong)P4Magic(3);
   request.volume=plan.lot; request.type=plan.signal>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   request.price=plan.signal>0?q.ask:q.bid; request.sl=plan.stop; request.tp=plan.target;
   request.deviation=10; request.type_filling=fill; request.type_time=ORDER_TIME_GTC; request.comment="MT4-CRF";
   g_p4Attempt[3]=now;
   ResetLastError();
   if(!OrderCheck(request,check) || check.retcode!=0)
   {
      string why=StringFormat("Order check: %u (error %d)",check.retcode,GetLastError());
      if(check.comment!="") why+=" "+check.comment;
      g_crfOrderCheckReason=why;
      return CRFEntryBlocked(why);
   }
   g_crfOrderCheckReason="";
   if(!P4ScheduleOpen()) return CRFEntryBlocked("Daily timer paused during order check");
   CRFExposure again; MqlTick latest;
   if(!CRFScanExposure(_Symbol,P4Magic(1),P4Magic(3),P4Connected(),again) || again.kind==CRF_EXPOSURE_REVIEW)
      return CRFEntryBlocked("Broker state unavailable after order check: REVIEW");
   if(again.kind!=CRF_EXPOSURE_EMPTY) return CRFEntryBlocked("M15 slot changed during order check");
   if(!SymbolInfoTick(_Symbol,latest) || !P4FreshQuote(latest)) return CRFEntryBlocked("Fresh quote unavailable after order check");
   if(latest.bid!=q.bid || latest.ask!=q.ask) return CRFEntryBlocked("Quote changed during order check; retrying");
   if(!P4CanTrade()) return CRFEntryBlocked("Trading permission unavailable after order check");
   if(!InpAutoTrading || !P4LaneEnabled(1)) return CRFEntryBlocked("Autotrading switched off during order check");
   P3Plan livePlan;
   reason=CRFLiveEntryReason(f,latest,livePlan);
   if(reason!="") return CRFEntryBlocked(reason);
   // Reserve the shared native M15 lane before saving CRF intent. P4Save
   // writes the native journal first, so a crash between the two saves can
   // only leave a conservative REVIEW reservation, never an unguarded send.
   g_p4[1].active=1; g_p4[1].direction=plan.signal; g_p4[1].planBar=plan.bar;
   g_p4[1].modEntry=CRF_NATIVE_RESERVATION_MARKER;
   g_p4[3].active=1; g_p4[3].direction=plan.signal; g_p4[3].cancel=0;
   g_p4[3].order=0; g_p4[3].position=0; g_p4[3].birthBar=0; g_p4[3].planBar=plan.bar;
   g_crfOrderSignalBar=plan.bar; g_crfAttemptedSignalBar=plan.bar; g_crfOrderDuration=f.last_estimate.duration_high;
   if(!P4Persist()) return CRFEntryBlocked("Execution journal unavailable: REVIEW");
   int row=P5BeginCrf(plan,q);
   if(row<0)
   {
      P4Clear(3); if(CRFNativeReserved()) P4Clear(1); P4Persist(); return CRFEntryBlocked("Trade diary unavailable: REVIEW");
   }
   ResetLastError();
   bool sent=OrderSend(request,result); int sendError=GetLastError();
   P5SendResult(row,result.order,result.retcode,result.deal==0 && P4DefiniteReject(result.retcode));
   if(result.order>0) g_p4[3].order=result.order;
   else if(result.deal==0 && P4DefiniteReject(result.retcode))
   { P4Clear(3); if(CRFNativeReserved()) P4Clear(1); }
   if(!P4Persist()) return CRFEntryBlocked("Execution journal unavailable: REVIEW");
   g_p4View[3].state=P4_UNCERTAIN; g_p4View[3].note="CRF order awaiting broker";
   if(result.deal==0 && P4DefiniteReject(result.retcode))
   {
      g_crfStatus=StringFormat("Order rejected: %u (error %d)",result.retcode,sendError);
      if(result.comment!="") g_crfStatus+=" "+result.comment;
      g_crfEntryReason=g_crfStatus;
   }
   else g_crfStatus=StringFormat("Order request %u; awaiting broker reconciliation",result.retcode);
   if(!sent) PrintFormat("MT CRF order result %u error %d; awaiting broker",result.retcode,sendError);
   return true;
}

// Reconcile CRF identity before the native loop can consider M15 entries.
void CRFRefreshBroker()
{
   if(!g_p4Ready) return;
   bool active=g_p4[3].active!=0;
   P5Track(1,g_p4[3].active,g_p4[3].direction,g_p4[3].order,g_p4[3].position,g_p4[3].planBar,P4Magic(3),true);
   P4Refresh(3);
   P5Track(1,g_p4[3].active,g_p4[3].direction,g_p4[3].order,g_p4[3].position,g_p4[3].planBar,P4Magic(3),true);
   if(!g_p4Ready) return;
   if(active && g_p4[3].active==0 && g_p4View[3].state==P4_EMPTY)
   {
      g_crfReleaseBar=iTime(_Symbol,PERIOD_M15,1); g_crfTakeover=0;
      if(CRFNativeReserved()) P4Clear(1,true);
      if(g_crfCloseKind==2) { g_crfCloseKind=0; g_crfClosePosition=0; g_crfCloseTicket=0; g_crfCloseVolume=0; }
      if(g_crfReleaseBar<=0 || !P4Persist()) { g_p4Ready=false; g_crfStatus="CRF close reconciliation: REVIEW"; }
   }
}

// A forecast may be confirmed and displayed but still fail the historical
// quality filters. Make this explicit instead of reporting that CRF is idle.
string CRFQualityBlockedStatus(const CRFForecastState &f)
{
   int reason=CRFAutoFilterReason(f);
   if(reason==2)
      return "Blocked: low sample count ("+IntegerToString(f.last_estimate.samples)+" / min "+IntegerToString(InpCrfMinimumAnalogs)+")";
   if(reason==3)
      return "Blocked: below follow-through filter (min "+IntegerToString(InpCrfAutoFollowthroughPct)+"%)";
   if(reason==4) return "Blocked: below forecast reward/risk filter";
   return "Blocked: forecast filters unavailable";
}

void CRFProcessExecution(bool allowEntry)
{
   if(!g_p4Ready) return;
   CRFExposure v;
   if(!P4Connected()) { g_crfStatus="Broker disconnected: REVIEW"; return; }
   if(!CRFScanExposure(_Symbol,P4Magic(1),P4Magic(3),P4Connected(),v) || v.kind==CRF_EXPOSURE_REVIEW)
   { g_crfStatus="Broker state: REVIEW"; return; }
   if(CRFNativeReserved() && g_p4[3].active==0 && g_p4View[3].state==P4_EMPTY &&
      v.kind==CRF_EXPOSURE_EMPTY && g_crfCloseKind==0)
   {
      P4Clear(1,true); g_crfReleaseBar=iTime(_Symbol,PERIOD_M15,1);
      if(g_crfReleaseBar<=0 || !P4Persist()) { g_p4Ready=false; g_crfStatus="M15 reservation: REVIEW"; return; }
   }
   if(g_crfCloseKind!=0)
   {
      int lane=g_crfCloseKind==1?1:3;
      if(g_p4[lane].active==0 && g_p4View[lane].state==P4_EMPTY &&
         P4PositionClosed(g_crfClosePosition))
      {
         g_crfCloseKind=0; g_crfClosePosition=0; g_crfCloseTicket=0; g_crfCloseVolume=0;
         g_crfReleaseBar=iTime(_Symbol,PERIOD_M15,1);
         if(g_crfReleaseBar<=0 || !P4Persist()) { g_p4Ready=false; g_crfStatus="Close reconciliation: REVIEW"; return; }
      }
      else { g_crfStatus="Close requested; awaiting broker"; return; }
   }
   if(v.kind==CRF_EXPOSURE_CRF_OPEN)
   {
      if(!g_p4[3].active || g_p4View[3].state!=P4_OPEN || v.position_id!=g_p4[3].position)
      { g_crfStatus="CRF position identity: REVIEW"; return; }
      if(InpMode==MT_CRF_MODE_MT) { g_crfStatus="CRF position remains open: REVIEW"; return; }
      int shift=iBarShift(_Symbol,PERIOD_M15,g_crfOrderSignalBar,true);
      if(shift<1) { g_crfStatus="CRF expiry history unavailable: REVIEW"; return; }
      bool expired=shift-1>=g_crfOrderDuration;
      bool replacement=g_crfObserverAvailable && g_crfForecastCurrent &&
                       g_crfObserver.forecast.signal_bar>g_crfOrderSignalBar;
      if(expired || replacement)
      {
         MqlTick q;
         if(SymbolInfoTick(_Symbol,q) && CRFRequestPositionClose(2,v,q)) g_crfStatus="CRF close requested";
         else g_crfStatus="CRF close waiting for broker";
      }
      else if(!g_crfObserverAvailable || !g_crfForecastCurrent) g_crfStatus="CRF position: forecast unavailable";
      else g_crfStatus=v.protective_levels_present?"CRF position open":"CRF position SL/TP missing: REVIEW";
      return;
   }
   if(InpMode==MT_CRF_MODE_MT) { g_crfStatus="MT only"; return; }
   if(!P4LaneEnabled(1))
   {
      // Input changes reinitialize the EA. Consume a disabled signal and
      // release any unfilled takeover so it cannot trigger after re-enabling.
      bool changed=false;
      if(g_crfObserverAvailable && g_crfObserver.forecast.signal_bar>0 &&
         g_crfObserver.forecast.signal_bar!=g_crfAttemptedSignalBar)
      { g_crfAttemptedSignalBar=(datetime)g_crfObserver.forecast.signal_bar; changed=true; }
      if(g_crfTakeover!=0 && g_p4[3].active==0 && g_p4View[3].state==P4_EMPTY)
      {
         g_crfTakeover=0; g_crfReleaseBar=iTime(_Symbol,PERIOD_M15,1); changed=true;
         if(g_crfReleaseBar<=0) { g_p4Ready=false; g_crfStatus="M15 release: REVIEW"; return; }
      }
      if(changed && !P4Persist()) { g_p4Ready=false; g_crfStatus="Execution journal unavailable: REVIEW"; return; }
      g_crfStatus="M15 autotrading OFF"; return;
   }
   if(!g_crfObserverAvailable || !g_crfForecastCurrent) return;
   CRFForecastState f=g_crfObserver.forecast;
   bool fresh=f.active_direction!=0 && CRFAutoFilterReady(f) && f.signal_bar!=g_crfAttemptedSignalBar;
   if(!fresh && g_crfTakeover!=0 && g_p4[3].active==0 && g_p4View[3].state==P4_EMPTY)
   {
      g_crfTakeover=0; g_crfReleaseBar=iTime(_Symbol,PERIOD_M15,1);
      if(g_crfReleaseBar<=0 || !P4Persist()) { g_p4Ready=false; g_crfStatus="M15 release: REVIEW"; return; }
   }
   if(!fresh)
   {
      if(f.active_direction!=0 && !CRFAutoFilterReady(f))
      {
         g_crfStatus=CRFQualityBlockedStatus(f);
         if(f.pending.direction!=0) g_crfStatus+="; candidate waiting confirmation";
      }
      else if(g_p4[3].active!=0 || g_p4View[3].state!=P4_EMPTY)
         g_crfStatus="CRF request awaiting broker reconciliation";
      else if(f.active_direction!=0 && f.signal_bar>0 && f.signal_bar==g_crfAttemptedSignalBar &&
              g_crfEntryReasonSignal==f.signal_bar && g_crfEntryReason!="")
         g_crfStatus="Last entry attempt: "+g_crfEntryReason;
      else if(f.active_direction!=0 && f.signal_bar>0 && f.signal_bar==g_crfAttemptedSignalBar)
      {
         g_crfStatus="Confirmed signal already used or display-only after restart/catch-up";
         if(f.pending.direction!=0) g_crfStatus+="; candidate waiting confirmation";
      }
      else g_crfStatus=f.pending.direction!=0?"Candidate waiting confirmation":"Watching M15 closed candles";
      return;
   }
   if(v.kind==CRF_EXPOSURE_MT_PENDING) { g_crfStatus="Waiting for M15 pending cancellation"; return; }
   if(v.kind==CRF_EXPOSURE_MT_OPEN)
   {
      if(InpMode!=MT_CRF_MODE_BOTH) { g_crfStatus="Existing MT M15 position open (CRF-only mode)"; return; }
      if(!InpCrfCloseProfitableM15) { g_crfStatus="Existing MT M15 position open; takeover close disabled"; return; }
      if(!InpAutoTrading) { g_crfStatus="Auto trading OFF; existing MT M15 position open"; return; }
      MqlTick q; double net=0,buffer=0;
      if(!SymbolInfoTick(_Symbol,q) || !CRFNetAndCloseBuffer(v,q,net,buffer))
      { g_crfStatus="M15 close blocked: position, quote or costs unavailable"; return; }
      if(net<=buffer) { g_crfStatus="Waiting for closing | net "+DoubleToString(net,2); return; }
      P3Plan livePlan; string reason=CRFLiveEntryReason(f,q,livePlan);
      if(reason!="") { g_crfStatus="CRF entry: "+reason; return; }
      if(CRFRequestPositionClose(1,v,q)) g_crfStatus="M15 close requested";
      else g_crfStatus="M15 close waiting for broker";
      return;
   }
   if(v.kind==CRF_EXPOSURE_EMPTY)
   {
      if(!InpAutoTrading) { g_crfStatus="Auto trading OFF"; return; }
      if(allowEntry)
      {
         MqlTick q;
         if(!SymbolInfoTick(_Symbol,q))
         {
            g_crfEntryReasonSignal=f.signal_bar; g_crfEntryReason="Fresh quote unavailable";
            g_crfStatus="CRF entry: "+g_crfEntryReason;
         }
         else if(!CRFPlaceMarket(q)) g_crfStatus="CRF entry: "+g_crfEntryReason;
      }
      else if(g_crfEntryReasonSignal==f.signal_bar && g_crfEntryReason!="")
         g_crfStatus="Last entry attempt: "+g_crfEntryReason;
      else g_crfStatus="Waiting for market tick to check entry";
   }
}
#endif
