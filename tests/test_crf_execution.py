#!/usr/bin/env python3
"""Exercise CRF order intent, safety gates and close/restart using MT-like stubs."""
from pathlib import Path
import os, re, runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
base=runpy.run_path(str(root/'tests/test_trade_diary_runtime.py'))
stubs=base['stubs']
stubs=stubs.replace('#define POSITION_PROFIT 48','#define POSITION_PROFIT 48\n#define POSITION_SWAP 80')
stubs=stubs.replace('double entry=0,sl=0,tp=0,lot=0,profit=0;string symbol,comment;', 'double entry=0,sl=0,tp=0,lot=0,profit=0,swap=0;string symbol,comment;')
stubs=stubs.replace('p==POSITION_PROFIT?o.profit:o.lot;', 'p==POSITION_PROFIT?o.profit:p==POSITION_SWAP?o.swap:o.lot;')
stubs=stubs.replace('unsigned long magic=0,order=0;double volume', 'unsigned long magic=0,order=0,position=0;double volume')
stubs=stubs.replace('datetime bar=1000; bool barProxy=false;', 'datetime bar=1000; bool barProxy=false,priced=false;')
stubs=stubs.replace(' sends++; if(sendMode==1)', ' if(r.position!=0){closeSends++;if(closeMode==1){out.order=777;out.retcode=TRADE_RETCODE_REJECT;return false;}out.retcode=10009;return true;}\n sends++; if(sendMode==1)')
stubs=stubs.replace('int sendMode=0,sends=0,cancels=0,modifies=0;', 'int sendMode=0,sends=0,cancels=0,modifies=0,closeSends=0,closeMode=0;')
stubs=stubs.replace('bool OrderCheck(MqlTradeRequest &,MqlTradeCheckResult &out){', 'bool moveOnCheck=false; bool OrderCheck(MqlTradeRequest &,MqlTradeCheckResult &out){if(moveOnCheck){current.bid=101.10;current.ask=101.12;}')
extra=base['extra']+r'''
bool FileCopy(string a,int,string b,int){if(diskFail||!files.count(a)||files.count(b))return false;files[b]=files[a];return true;}
using ENUM_TIMEFRAMES=int;const int PERIOD_M15=1;
bool PositionSelectByTicket(ulong tk){for(size_t i=0;i<positions.size();i++)if(positions[i].ticket==tk){selectedPosition=int(i);return true;}return false;}
template<class T> void ZeroMemory(T &x){x=T{};}
bool P3HasBidBars(){return true;}
double P3Down(double v,double t){return floor(v/t+1e-9)*t;}
double P3Up(double v,double t){return ceil(v/t-1e-9)*t;}
enum ENUM_MT_CRF_MODE{MT_CRF_MODE_BOTH=0,MT_CRF_MODE_MT=1,MT_CRF_MODE_CRF=2};
ENUM_MT_CRF_MODE InpMode=MT_CRF_MODE_BOTH;bool InpCrfCloseProfitableM15=true,InpCrfRiskBypass=false;
int InpCrfHistoryBars=600,InpCrfMaxHorizon=24,InpCrfAtrLength=14,InpCrfTrendLength=12,InpCrfVolumeLength=20,InpCrfSwingLength=20,InpCrfMinimumAnalogs=6,InpCrfMinFollowthroughPct=55,InpCrfAutoFollowthroughPct=15;double InpCrfMinRewardRisk=1.2;
struct CRFParameters{int history,horizon,atr,trend,volume,swing,minimum_analogs,followthrough;double reward_risk;};
struct CRFCandidate{int direction=0;double stop=99,atr=1;};struct CRFEstimate{bool ready=false,available=true;int duration_high=0,reason=1,samples=6;double confidence=60,move_atr=2;};
struct CRFForecastState{int active_direction=0;long signal_bar=0,last_bar=0;double last_entry=0,active_stop=0,active_target=0;CRFEstimate last_estimate;CRFCandidate pending,last_signal;};
struct CRFObserver{bool ready=false;string history_detail;CRFForecastState forecast;};
struct CRFFeedUpdate{bool bootstrap=false;};
enum CRF_OBSERVER_RESULT{CRF_OBSERVER_OK,CRF_OBSERVER_INVALID,CRF_OBSERVER_JOURNAL_ERROR,CRF_OBSERVER_HISTORY_UNAVAILABLE,CRF_OBSERVER_CALCULATION_ERROR,CRF_OBSERVER_BOOTSTRAPPING};
CRF_OBSERVER_RESULT CRFObserverInit(CRFObserver &o,string,string,int,const CRFParameters&,bool locked){o.ready=locked;return locked?CRF_OBSERVER_OK:CRF_OBSERVER_INVALID;}
CRF_OBSERVER_RESULT pollResult=CRF_OBSERVER_OK;
CRF_OBSERVER_RESULT CRFObserverPoll(CRFObserver &o,vector<CRFFeedUpdate>&){if(pollResult==CRF_OBSERVER_HISTORY_UNAVAILABLE)o.history_detail="M15 copy requires 100001 closed bars; limit is 100000";return pollResult;}
'''
kernel=base['kernel']
runtime=(root/'MT_CRF_TradeDiaryRuntime.mqh').read_text().replace('#include "MT_TradeDiary.mqh"','')
runtime=re.sub(r'\b(P5Row|P5Deal|string) (\w+)\[\];',r'vector<\1> \2;',runtime)
auto=(root/'MT_CRF_AutoRuntime.mqh').read_text().replace('#include "MT_AutoPolicy.mqh"','').replace('#include "MT_CRF_TradeDiaryRuntime.mqh"','')
inputs='\n'.join(line for line in (root/'MT_PlanRuntime.mqh').read_text().splitlines() if line.startswith('input ') and any(re.search(r'\b'+n+r'\b',line) for n in ('InpAutoTrading','InpPlaceStopLoss','InpAllowAutoM5','InpAllowAutoM15','InpAllowAutoM30','InpUseAutoSchedule','InpAutoStartTime','InpAutoEndTime')))
auto=re.sub(r'^input ','',inputs,flags=re.M)+'\n'+auto
execution=(root/'MT_CRF_Execution.mqh').read_text().replace('#include "MT_CRF_Observer.mqh"','').replace('#include "MT_CRF_Exposure.mqh"','')
execution=execution.replace('CRFFeedUpdate updates[];','vector<CRFFeedUpdate> updates;')
exposure=(root/'MT_CRF_Exposure.mqh').read_text()
main=r'''
int main(){int f=0;auto check=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';f++;}};
 InpUseAutoSchedule=false;InpPlaceStopLoss=false;P5Init();P4Init();CRFRefreshBroker();P4Refresh(1);
 g_crfObserverAvailable=true;g_crfForecastCurrent=true;g_crfObserver.ready=true;g_crfTakeover=1;
 auto &forecast=g_crfObserver.forecast;forecast.active_direction=1;forecast.signal_bar=1000;forecast.last_entry=100;
 pollResult=CRF_OBSERVER_HISTORY_UNAVAILABLE;g_crfForecastCurrent=false;CRFUpdateForecast();
 check(!g_crfForecastCurrent && g_crfStatus.find("100001 closed bars; limit is 100000")!=string::npos,"live forecast reports exact history failure and stays unavailable");
 pollResult=CRF_OBSERVER_OK;g_crfForecastCurrent=true;
 forecast.active_stop=99;forecast.active_target=102;forecast.last_estimate.ready=true;forecast.last_estimate.duration_high=4;
 MqlTick q=current;
 // A confirmed but low-quality forecast is visible, never tradeable, and
 // the execution status must say why instead of suggesting it is idle.
 InpMode=MT_CRF_MODE_CRF;InpAutoTrading=true;g_crfTakeover=0;InpCrfAutoFollowthroughPct=55;
 forecast.last_estimate.ready=false;forecast.last_estimate.reason=3;forecast.last_estimate.samples=6;forecast.last_estimate.confidence=19;
 CRFProcessExecution(true);
 check(sends==0 && !CRFPlaceMarket(q) && g_crfStatus=="Blocked: below follow-through filter (min 55%)","confirmed weak follow-through is explicitly blocked, never sent");
 forecast.last_estimate.reason=2;forecast.last_estimate.samples=3;CRFProcessExecution(true);
 check(sends==0 && g_crfStatus=="Blocked: low sample count (3 / min 6)","low-sample reason visible");
 forecast.last_estimate.samples=6;forecast.last_estimate.confidence=60;forecast.last_estimate.reason=4;forecast.last_estimate.move_atr=1;CRFProcessExecution(true);
 check(sends==0 && g_crfStatus=="Blocked: below forecast reward/risk filter","forecast reward/risk reason visible");
 forecast.pending.direction=1;CRFProcessExecution(true);check(g_crfStatus.find("candidate waiting confirmation")!=string::npos,"new candidate remains visible alongside blocked forecast");
 forecast.pending.direction=0;forecast.last_estimate.move_atr=2;forecast.last_estimate.ready=true;InpCrfAutoFollowthroughPct=15;InpMode=MT_CRF_MODE_BOTH;InpAutoTrading=false;g_crfTakeover=1;
 check(CRFNativeLaneBlocked(1) && !CRFNativeLaneBlocked(0) && !CRFNativeLaneBlocked(2),"combined mode blocks only M15");
 check(!CRFPlaceMarket(q) && sends==0,"master off blocks CRF entry");InpAutoTrading=true;
 InpAllowAutoM15=false;
 check(!CRFPlaceMarket(q) && sends==0,"M15 switch off blocks CRF entry in combined mode");
 InpMode=MT_CRF_MODE_CRF;check(!CRFPlaceMarket(q) && sends==0,"M15 switch off blocks CRF entry in CRF-only mode");
 InpMode=MT_CRF_MODE_BOTH;InpAllowAutoM15=true;
 // Auto threshold is independent of the reference indicator's 55% quality.
 CRFForecastState filtered=forecast;filtered.last_estimate.ready=false;filtered.last_estimate.reason=3;
 filtered.last_estimate.confidence=19;filtered.last_estimate.samples=6;filtered.last_estimate.move_atr=2;
 check(CRFAutoFilterReady(filtered),"19 percent passes 15 percent auto threshold despite reference quality");
 InpCrfAutoFollowthroughPct=20;check(CRFAutoFilterReason(filtered)==3,"19 percent fails 20 percent auto threshold");
 InpCrfAutoFollowthroughPct=19;check(CRFAutoFilterReady(filtered),"equal-to threshold passes");
 InpCrfAutoFollowthroughPct=1;filtered.last_estimate.confidence=1;check(CRFAutoFilterReady(filtered),"lower endpoint 1 percent supported");
 InpCrfAutoFollowthroughPct=100;filtered.last_estimate.confidence=99.99;check(CRFAutoFilterReason(filtered)==3,"100 percent rejects below 100");
 filtered.last_estimate.confidence=100;check(CRFAutoFilterReady(filtered),"100 percent endpoint accepted");
 InpCrfAutoFollowthroughPct=0;check(!CRFAutoFilterReady(filtered),"invalid below-range threshold fails closed");
 InpCrfAutoFollowthroughPct=101;check(!CRFAutoFilterReady(filtered),"invalid above-range threshold fails closed");
 InpCrfAutoFollowthroughPct=15;filtered.last_estimate.confidence=19;filtered.last_estimate.samples=5;
 check(CRFAutoFilterReason(filtered)==2,"threshold cannot bypass minimum samples");
 filtered.last_estimate.samples=6;filtered.last_estimate.move_atr=1.1;
 check(CRFAutoFilterReason(filtered)==4,"threshold cannot bypass original forecast reward/risk");
 filtered.last_estimate.move_atr=2;filtered.last_estimate.available=false;
 check(!CRFAutoFilterReady(filtered),"threshold cannot bypass missing forecast estimate");
 // The actual request path must use the auto input, not reference quality.
 forecast.last_estimate.ready=false;forecast.last_estimate.reason=3;forecast.last_estimate.confidence=19;
 InpCrfAutoFollowthroughPct=20;check(!CRFPlaceMarket(q) && sends==0,"19 percent confirmation blocked by 20 percent auto threshold");
 InpCrfAutoFollowthroughPct=15;check(CRFAutoFilterReady(forecast),"19 percent confirmation admitted by 15 percent auto threshold");
 check(CRFInputParameters().followthrough==55,"auto input does not change reference forecast or journal parameters");
 g_crfTakeover=0;InpCrfAutoFollowthroughPct=20;check(!CRFNativeLaneBlocked(1),"below-threshold CRF signal does not block native M15");
 InpCrfAutoFollowthroughPct=15;check(CRFNativeLaneBlocked(1),"newly eligible CRF signal blocks native M15 for takeover");g_crfTakeover=1;
 // A late market price must still satisfy the original 1.2 R/R filter.
 // Prices are examples only; both sides use the executable quote and the
 // same broker-tick rounded SL/TP that the eventual request carries.
 P3Plan probe{};CRFForecastState rr=forecast;rr.active_target=101.2;
 MqlTick boundary=q;boundary.bid=99.98;boundary.ask=100.0;
 check(CRFLiveEntryReason(rr,boundary,probe)=="", "BUY at exactly 1.2 R/R is permitted");
 MqlTick late=q;late.bid=100.59;late.ask=100.60;
 check(CRFLiveEntryReason(rr,late,probe)=="Below live R/R filter", "BUY halfway to target is blocked");
 rr.active_stop=99.003;rr.active_target=101.209;
 check(CRFLiveEntryReason(rr,boundary,probe)=="" && MathAbs(probe.stop-99)<1e-8 && MathAbs(probe.target-101.2)<1e-8,"BUY ratio uses broker-rounded levels");
 rr=forecast;rr.active_direction=-1;rr.active_stop=101;rr.active_target=98.8;
 boundary.bid=100;boundary.ask=100.02;
 check(CRFLiveEntryReason(rr,boundary,probe)=="", "SELL at exactly 1.2 R/R is permitted");
 late.bid=99.4;late.ask=99.42;
 check(CRFLiveEntryReason(rr,late,probe)=="Below live R/R filter", "SELL halfway to target is blocked");
 rr.active_stop=100.997;rr.active_target=98.791;
 check(CRFLiveEntryReason(rr,boundary,probe)=="" && MathAbs(probe.stop-101)<1e-8 && MathAbs(probe.target-98.8)<1e-8,"SELL ratio uses broker-rounded levels");
 MqlTick stale=boundary;stale.time=terminalTime-20;
 check(CRFLiveEntryReason(rr,stale,probe)!="", "stale quote fails closed");
 rr.active_direction=0;check(CRFLiveEntryReason(rr,boundary,probe)!="", "inactive forecast fails closed");
 rr=forecast;rr.active_target=101.2;late.bid=100.59;late.ask=100.60;
 InpBypassRisk=true;check(!CRFMakeRequestPlan(rr,late,probe),"bypass risk cannot bypass live R/R");
 InpMinimumLot=true;check(!CRFMakeRequestPlan(rr,late,probe),"minimum lot cannot bypass live R/R");
 InpBypassRisk=false;InpMinimumLot=false;
 // Test actual request plan sizing, independently of native MT score.
 P3Plan normal{},bypass{},minimum{};equity=10000;InpBypassRisk=false;InpMinimumLot=false;
 g_p3[1].score=-3;check(CRFMakeRequestPlan(forecast,q,normal) && MathAbs(normal.lot-0.49)<1e-8,"normal CRF sizing uses live stop and 0.5 percent equity despite opposing MT score");
 calcOk=false;check(!CRFMakeRequestPlan(forecast,q,normal),"normal sizing blocks when stop loss calculation unavailable");
 InpBypassRisk=true;g_p3[1].score=3;
 check(CRFMakeRequestPlan(forecast,q,bypass) && MathAbs(bypass.lot-0.10)<1e-8,"bypass uses balance ladder and no MT score multiplier or loss calculation");
 InpMinimumLot=true;check(CRFMakeRequestPlan(forecast,q,minimum) && MathAbs(minimum.lot-volMin)<1e-8,"minimum lot overrides bypass");
 InpMinimumLot=false;volMax=0.05;check(CRFMakeRequestPlan(forecast,q,bypass) && MathAbs(bypass.lot-0.05)<1e-8,"bypass respects broker maximum");volMax=100;
 MqlTick excessive=q;excessive.ask=101.1;check(!CRFMakeRequestPlan(forecast,excessive,bypass),"bypass does not bypass spread safety");
 calcOk=true;InpBypassRisk=false;equity=1;check(CRFMakeRequestPlan(forecast,q,normal) && MathAbs(normal.lot-volMin)<1e-8,"normal below-minimum result uses broker minimum");equity=10000;
 InpBypassRisk=true;calcOk=false;
 long oldMode=orderMode;orderMode=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_TP;
 check(!CRFPlaceMarket(q) && sends==0,"CRF requires broker SL even with bypass on and MT SL disabled");orderMode=oldMode;
 checkOk=false;check(!CRFPlaceMarket(q) && sends==0,"bypass does not bypass OrderCheck");checkOk=true;uptime+=6000;
 moveOnCheck=true;check(!CRFPlaceMarket(q) && sends==0,"price change between OrderCheck and final scan blocks entry");
 moveOnCheck=false;current=q;uptime+=6000;
 check(CRFPlaceMarket(q) && sends==1 && lastRequest.magic==(ulong)P4Magic(3) && lastRequest.sl>0 && lastRequest.tp>0 && lastRequest.comment=="MT4-CRF","19 percent reference-blocked forecast can send under 15 percent auto filter with mandatory protection");
 check(CRFNativeReserved(),"shared native M15 journal reserved while CRF is open");
 P4Refresh(1);check(g_p4View[1].state==P4_UNCERTAIN && g_p4View[1].note.find("no order ticket")!=string::npos,"original-compatible reservation is REVIEW, never free");
 check(g_p5.size()==1 && g_p5[0].strategy==30007 && g_p5[0].score==0 && g_p5[0].stopInput==1 && g_p5[0].bypass==1 && MathAbs(lastRequest.volume-0.10)<1e-8,"CRF bypass request and diary identity");
 calcOk=true;InpBypassRisk=false;
 check(!CRFPlaceMarket(q) && sends==1,"no duplicate request while position visible");
 CRFRefreshBroker();check(g_p4View[3].state==P4_OPEN && g_p4[3].position!=0,"broker-confirmed CRF position");
 forecast.active_direction=0;CRFProcessExecution(false);check(closeSends==0 && g_p4[3].active==1,"candle touch does not close position");
 laneBars[1].insert(laneBars[1].end(),{1002,1003,1004,1005});uptime+=6000;
 InpAutoTrading=false;CRFProcessExecution(false);check(closeSends==0,"master off prevents CRF expiry close request");InpAutoTrading=true;
 InpAllowAutoM15=false;closeMode=1;CRFProcessExecution(false);closeMode=0;InpAllowAutoM15=true;
 check(closeSends==1 && g_crfCloseKind==2,"contradictory rejection with order ticket retains durable close intent");
 CRFProcessExecution(false);check(closeSends==1,"unconfirmed close cannot be resent");
 P4Close();P4Init();check(g_p4Ready && g_crfCloseKind==2 && g_crfOrderSignalBar==1000,"close intent survives restart");
 CRFRefreshBroker();CRFProcessExecution(false);check(closeSends==1,"restart cannot duplicate ambiguous close");
 auto pos=positions[0];positions.clear();deals.push_back({pos.id,DEAL_ENTRY_OUT,pos.lot,999,1700000000002L,DEAL_REASON_TP,101,1,-.1,0,0});
 uptime+=6000;CRFRefreshBroker();check(g_p4[3].active==0 && g_crfCloseKind==0 && g_crfReleaseBar==1004,"broker-confirmed exit anchors M15 release");
 check(!CRFNativeReserved() && g_p4[1].cooldown==2,"reservation cleared only after confirmed CRF exit with cooldown");
 check(CRFNativeLaneBlocked(1),"native M15 waits for later closed bar");
 laneBars[1].push_back(1006);check(!CRFNativeLaneBlocked(1),"M15 released after later close");
 InpMode=MT_CRF_MODE_CRF;check(CRFNativeLaneBlocked(0) && CRFNativeLaneBlocked(1) && CRFNativeLaneBlocked(2),"CRF-only blocks native lanes");

 // An existing MT M15 pending limit must be canceled and confirmed; CRF
 // cannot enter until the subsequent M15 close.
 P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 for(int i=0;i<3;i++){plans[i]=P3Plan{};g_p3[i].score=0;g_p3[i].volumeState=-1;}
 laneBars[1]={700,800,900,1000,1001};sends=0;cancels=0;closeSends=0;uptime=30000;
 InpMode=MT_CRF_MODE_BOTH;InpAutoTrading=true;g_crfObserverAvailable=true;g_crfForecastCurrent=true;g_crfObserver.ready=true;
 forecast=CRFForecastState{};P5Init();P4Init();CRFRefreshBroker();
 plans[1]={1,true,false,99.9,99,101,0.05,1000};g_p3[1].score=2;
 P4Process(true);P4Process(false);check(orders.size()==1 && g_p4View[1].state==P4_PENDING,"native M15 pending established");
 forecast.active_direction=1;forecast.signal_bar=1000;forecast.last_entry=100;forecast.active_stop=99;forecast.active_target=102;
 forecast.last_estimate.ready=true;forecast.last_estimate.duration_high=4;g_crfTakeover=1;
 uptime+=6000;P4Process(false);check(orders.empty() && cancels==1,"CRF takeover cancels native pending only");
 P4Process(false);check(!g_p4[1].active && g_p4[1].cooldown==2,"cancellation confirmed and cooldown recorded");
 int oldSends=sends;uptime+=6000;check(!CRFPlaceMarket(q) && sends==oldSends,"no immediate CRF replacement");
 laneBars[1].push_back(1002);uptime+=6000;check(CRFPlaceMarket(q) && sends==oldSends+1,"CRF entry after later M15 close");

 // Native M15 market position takeover requires reliable net and a cost reserve.
 P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 for(int i=0;i<3;i++){plans[i]=P3Plan{};g_p3[i].score=0;g_p3[i].volumeState=-1;}
 laneBars[1]={700,800,900,1000,1001};sends=0;closeSends=0;uptime=80000;sendMode=0;
 InpMode=MT_CRF_MODE_BOTH;InpAutoTrading=true;g_crfObserverAvailable=true;g_crfForecastCurrent=true;g_crfObserver.ready=true;
 forecast=CRFForecastState{};P5Init();P4Init();CRFRefreshBroker();
 plans[1]={1,true,true,100,99,102,0.05,1000};g_p3[1].score=3;
 P4Process(true);P4Process(false);check(positions.size()==1 && g_p4View[1].state==P4_OPEN,"native M15 open established");
 forecast.active_direction=1;forecast.signal_bar=1000;forecast.last_entry=100;forecast.active_stop=99;forecast.active_target=102;
 forecast.last_estimate.ready=true;forecast.last_estimate.duration_high=4;g_crfTakeover=1;
 CRFExposure ex;double net=0,buffer=0;
 check(CRFScanExposure(_Symbol,P4Magic(1),P4Magic(3),true,ex) && ex.kind==CRF_EXPOSURE_MT_OPEN,"native exposure observed");
 positions[0].profit=20;deals[0].commission=0;deals[0].fee=0;
 check(!CRFNetAndCloseBuffer(ex,q,net,buffer),"unknown future commission fails safe");
 deals[0].commission=-0.2;positions[0].profit=0.1;
 check(CRFNetAndCloseBuffer(ex,q,net,buffer) && net<=buffer,"below-cost position remains open");
 uptime+=6000;CRFProcessExecution(false);check(closeSends==0,"below-cost position not closed");
 positions[0].profit=20;InpAllowAutoM15=false;
 check(!CRFRequestPositionClose(1,ex,q) && closeSends==0,"disabled M15 blocks direct takeover close");
 CRFProcessExecution(true);check(closeSends==0 && g_crfTakeover==0 && g_crfAttemptedSignalBar==1000 && g_crfStatus=="M15 autotrading OFF","disabled M15 releases takeover, consumes signal and leaves native position");
 InpAllowAutoM15=true;CRFProcessExecution(true);check(closeSends==0,"re-enabling cannot replay disabled confirmation");
 // Simulate a new confirmation, distinct from the consumed one.
 forecast.signal_bar=1001;g_crfTakeover=1;
 positions[0].profit=20;InpCrfCloseProfitableM15=false;uptime+=6000;CRFProcessExecution(false);
 check(closeSends==0,"takeover close input off prevents close");
 InpCrfCloseProfitableM15=true;InpAutoTrading=false;CRFProcessExecution(false);check(closeSends==0,"master off prevents native close");
 InpAutoTrading=true;uptime+=6000;
 current.bid=101.10;current.ask=101.12;
 check(!CRFRequestPositionClose(1,ex,current) && closeSends==0,"direct takeover close blocked by deteriorated live R/R");
 CRFProcessExecution(false);check(closeSends==0 && g_crfStatus=="CRF entry: Below live R/R filter", "profitable native position remains open when live R/R is too low");
 InpCrfRiskBypass=true;positions[0].profit=0.1;uptime+=6000;CRFProcessExecution(false);
 check(closeSends==0 && g_crfStatus.find("Waiting for closing | net")==0,"CRF bypass never closes below-cost native M15");
 positions[0].profit=20;checkOk=false;uptime+=6000;CRFProcessExecution(false);
 check(closeSends==0 && g_crfStatus=="M15 close waiting for broker","CRF bypass allows late takeover check but retains broker precheck");
 InpCrfRiskBypass=false;checkOk=true;current=q;uptime+=6000;moveOnCheck=true;
 check(!CRFRequestPositionClose(1,ex,q) && closeSends==0,"price change between close check and final scan blocks takeover close");
 moveOnCheck=false;current=q;uptime+=6000;CRFProcessExecution(false);
 check(closeSends==1 && g_crfCloseKind==1 && positions.size()==1,"profitable native close is requested, not assumed");
 CRFProcessExecution(false);check(closeSends==1 && sends==1,"unconfirmed native close neither repeated nor replaced");
 P4Close();P4Init();P4Process(false);CRFRefreshBroker();CRFProcessExecution(false);
 check(closeSends==1 && g_crfCloseKind==1,"native close intent survives restart");
 auto nativePos=positions[0];positions.clear();deals.push_back({nativePos.id,DEAL_ENTRY_OUT,nativePos.lot,999,1700000000002L,DEAL_REASON_TP,101,20,-.2,0,0});
 uptime+=6000;P4Process(false);CRFProcessExecution(false);
 check(g_crfCloseKind==0 && g_crfReleaseBar==1000 && !CRFPlaceMarket(q),"confirmed native close waits for later M15 close");
 laneBars[1].push_back(1002);uptime+=6000;
 current.bid=101.10;current.ask=101.12;
 CRFProcessExecution(true);check(sends==1 && g_crfStatus=="CRF entry: Below live R/R filter", "after close and cooldown, deteriorated live R/R prevents entry");
 check(!CRFPlaceMarket(current) && sends==1,"direct CRF placement cannot bypass live R/R");
 current=q;uptime+=6000;check(CRFPlaceMarket(q) && sends==2,"CRF can enter after price improves while forecast remains active");

 // An ambiguous send is durable and cannot be repeated across restart.
 P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 laneBars[1]={700,800,900,1000,1001};sends=0;uptime=50000;sendMode=1;
 P5Init();P4Init();CRFRefreshBroker();P4Refresh(1);g_crfTakeover=1;g_crfAttemptedSignalBar=0;
 check(CRFPlaceMarket(q) && sends==1 && g_p4[3].active && g_p4[3].order==0,"ambiguous CRF request retains persisted intent");
 P4Close();P4Init();CRFRefreshBroker();uptime+=6000;
 check(!CRFPlaceMarket(q) && sends==1 && g_p4View[3].state==P4_UNCERTAIN,"ambiguous send never blindly retried after restart");


 // An unclaimed forecast found on restart is display-only; a crash after the
 // forecast save must not turn an old confirmation into a fresh order.
 P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 laneBars[1]={700,800,900,1000,1001};uptime=90000;sendMode=0;InpMode=MT_CRF_MODE_BOTH;
 P5Init();P4Init();forecast=CRFForecastState{};forecast.active_direction=1;forecast.signal_bar=1000;forecast.last_bar=1000;
 forecast.last_estimate.ready=true;forecast.last_estimate.duration_high=4;
 CRFInitRuntime();check(g_crfObserverAvailable && g_crfAttemptedSignalBar==1000 && g_crfTakeover==0,"restart consumes unclaimed forecast without placing order");
 P4Close();P4Init();check(g_crfAttemptedSignalBar==1000,"restart safety marker is durable");
 // Simulate a crash between writing native and CRF journals. The reservation
 // is recoverable only after a clean empty broker scan, with a bar cooldown.
 g_p4[1].active=1;g_p4[1].direction=1;g_p4[1].planBar=1000;g_p4[1].modEntry=CRF_NATIVE_RESERVATION_MARKER;
 check(P4Persist(),"orphan reservation persisted");P4Close();P4Init();CRFRefreshBroker();P4Refresh(1);
 CRFProcessExecution(false);check(!CRFNativeReserved() && g_p4[1].cooldown==2 && g_crfReleaseBar==1000,"orphan reservation recovers only after empty broker scan");

 // Polling still updates the forecast with M15 disabled but must not create
 // a takeover. Re-enabling can create one for a genuinely fresh event.
 P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 P5Init();P4Init();CRFRefreshBroker();P4Refresh(1);g_crfObserverAvailable=true;g_crfObserver.ready=true;g_crfForecastCurrent=false;
 forecast=CRFForecastState{};forecast.active_direction=1;forecast.signal_bar=1000;forecast.last_bar=1000;forecast.last_entry=100;forecast.last_estimate.ready=true;
 g_crfTakeover=0;g_crfAttemptedSignalBar=0;InpMode=MT_CRF_MODE_BOTH;InpAllowAutoM15=false;
 CRFUpdateForecast();check(g_crfForecastCurrent && g_crfTakeover==0,"disabled M15 still forecasts but cannot claim takeover");
 CRFProcessExecution(true);check(g_crfAttemptedSignalBar==1000 && g_crfStatus=="M15 autotrading OFF","disabled confirmation consumed");
 InpAllowAutoM15=true;forecast.signal_bar=1001;forecast.last_bar=1001;forecast.last_estimate.ready=false;forecast.last_estimate.reason=3;forecast.last_estimate.confidence=19;g_crfForecastCurrent=false;CRFUpdateForecast();
 check(g_crfTakeover==1,"fresh 19 percent confirmation can claim takeover at 15 percent after M15 enabled");
 InpAllowAutoM15=false;g_crfObserverAvailable=false;g_crfForecastCurrent=false;CRFProcessExecution(false);
 check(g_crfTakeover==0 && g_crfStatus=="M15 autotrading OFF","disabled M15 releases unfilled takeover even if forecast is unavailable");
 // CRF-only risk bypass is independent of the shared lot-sizing switch.
 P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 laneBars[1]={700,800,900,1000,1001};sends=0;closeSends=0;uptime=200000;sendMode=0;equity=10000;
 InpMode=MT_CRF_MODE_CRF;InpAutoTrading=true;InpAllowAutoM15=true;InpUseAutoSchedule=false;
 InpBypassRisk=false;InpMinimumLot=false;InpCrfRiskBypass=false;InpCrfAutoFollowthroughPct=15;calcOk=false;
 P5Init();P4Init();CRFRefreshBroker();P4Refresh(1);g_crfObserverAvailable=true;g_crfForecastCurrent=true;g_crfObserver.ready=true;
 forecast=CRFForecastState{};forecast.active_direction=1;forecast.signal_bar=1000;forecast.last_bar=1000;forecast.last_entry=100;
 forecast.active_stop=99;forecast.active_target=101.1;forecast.last_estimate.available=true;forecast.last_estimate.samples=6;
 forecast.last_estimate.confidence=19;forecast.last_estimate.move_atr=1.1;forecast.last_estimate.duration_high=4;
 current={100.79,100.80,terminalTime};g_crfAttemptedSignalBar=0;g_crfTakeover=1;
 check(!CRFPlaceMarket(current) && sends==0,"default-off CRF bypass still blocks weak forecast R/R");
 InpCrfRiskBypass=true;
 check(CRFInputParameters().followthrough==55 && CRFInputParameters().reward_risk==1.2,"CRF bypass does not change reference forecast parameters");
 double nativeLot=0;P3Plan nativePlan{1,true,true,100,99,102,0.05,1000};
 check(!P4RequestLot(nativePlan,current,nativeLot),"CRF bypass does not bypass native MT risk sizing");
 check(CRFAutoFilterReady(forecast),"CRF bypass skips forecast R/R");
 P3Plan relaxed{};check(CRFMakeRequestPlan(forecast,current,relaxed) && MathAbs(relaxed.lot-0.10)<1e-8,"CRF bypass skips live R/R and uses balance sizing even with shared bypass off");
 InpMinimumLot=true;check(CRFMakeRequestPlan(forecast,current,relaxed) && MathAbs(relaxed.lot-volMin)<1e-8,"minimum lot takes precedence over CRF bypass");InpMinimumLot=false;
 forecast.last_estimate.samples=5;check(!CRFAutoFilterReady(forecast),"CRF bypass retains minimum analog filter");forecast.last_estimate.samples=6;
 forecast.last_estimate.confidence=14;check(!CRFAutoFilterReady(forecast),"CRF bypass retains follow-through filter");forecast.last_estimate.confidence=19;
 CRFForecastState sell=forecast;sell.active_direction=-1;sell.last_signal.stop=101;sell.active_stop=101;sell.active_target=98.9;
 MqlTick sellQuote=current;sellQuote.bid=99.20;sellQuote.ask=99.22;
 check(CRFMakeRequestPlan(sell,sellQuote,relaxed),"CRF bypass supports late SELL with valid levels");
 InpCrfRiskBypass=false;check(!CRFMakeRequestPlan(sell,sellQuote,relaxed),"late SELL forecast risk remains blocked with bypass off");InpCrfRiskBypass=true;
 MqlTick badQuote=current;badQuote.ask=101.2;check(!CRFMakeRequestPlan(forecast,badQuote,relaxed),"CRF bypass retains live-level and spread checks");
 long savedOrderMode=orderMode;orderMode=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_TP;
 check(!CRFPlaceMarket(current) && sends==0,"CRF bypass cannot omit broker SL");orderMode=savedOrderMode;
 InpAutoTrading=false;check(!CRFPlaceMarket(current),"CRF bypass cannot override master off");InpAutoTrading=true;
 InpAllowAutoM15=false;check(!CRFPlaceMarket(current),"CRF bypass cannot override M15 switch");InpAllowAutoM15=true;
 checkOk=false;check(!CRFPlaceMarket(current) && sends==0,"CRF bypass cannot override OrderCheck");checkOk=true;
 uptime+=6000;check(CRFPlaceMarket(current) && sends==1 && MathAbs(lastRequest.volume-0.10)<1e-8 && lastRequest.sl>0 && lastRequest.tp>0,"CRF bypass can send once all retained safety checks pass");
 check(g_p5.size()==1 && g_p5[0].bypass==2,"CRF bypass recorded separately from shared bypass");
 P5Close();P5Init();check(g_p5Ready && g_p5.size()==1 && g_p5[0].bypass==2,"CRF bypass diary flag survives restart");
 P5Export();bool exported=false;for(auto &line:csvLines)if(line.size()>18 && line[17]=="30007" && line[15]=="0" && line[line.size()-2]=="1")exported=true;
 check(exported,"CSV separately exports shared bypass off and CRF risk bypass on");
 InpBypassRisk=true;check(CRFMakeRequestPlan(forecast,current,relaxed),"restore valid plan for diary flag test");int bothBypasses=P5BeginCrf(relaxed,current);
 check(bothBypasses==1 && g_p5[bothBypasses].bypass==3,"diary preserves both bypass flags");
 int nativeRow=P5Begin(1,relaxed,current,true,83);
 check(nativeRow==2 && g_p5[nativeRow].bypass==1,"native diary keeps shared bypass only");
 P5Close();P5Init();check(g_p5Ready && g_p5.size()==3 && g_p5[1].bypass==3 && g_p5[2].bypass==1,"both bypass flags and native record survive restart");
 InpCrfRiskBypass=false;InpBypassRisk=false;calcOk=true;

 // Confirm the panel receives the actual failed entry gate and timer refresh
 // cannot replace an order-check failure with a fictional occupied slot.
 P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 laneBars[1]={700,800,900,1000,1001};sends=0;uptime=400000;sendMode=0;checkOk=true;permission=true;hedging=true;
 InpMode=MT_CRF_MODE_CRF;InpAutoTrading=true;InpAllowAutoM15=true;InpUseAutoSchedule=false;
 InpMinimumLot=false;InpBypassRisk=false;InpCrfRiskBypass=false;orderMode=51;g_marketState=MARKET_OPEN;current=q;
 P5Init();P4Init();CRFRefreshBroker();P4Refresh(1);g_crfObserverAvailable=true;g_crfForecastCurrent=true;g_crfObserver.ready=true;
 forecast=CRFForecastState{};forecast.active_direction=1;forecast.signal_bar=1000;forecast.last_bar=1000;forecast.last_entry=100;
 forecast.active_stop=99;forecast.active_target=102;forecast.last_estimate.duration_high=4;g_crfTakeover=1;g_crfAttemptedSignalBar=0;
 g_crfEntryReason="";g_crfOrderCheckReason="";g_crfEntryReasonSignal=0;
 CRFProcessExecution(false);check(g_crfStatus=="Waiting for market tick to check entry","timer doesn't invent slot blocker before first entry check");
 g_crfAttemptedSignalBar=1000;CRFProcessExecution(false);
 check(g_crfStatus.find("already used or display-only")!=string::npos,"old/consumed confirmation is not misreported as watching");
 g_crfAttemptedSignalBar=0;g_crfTakeover=1;g_crfReleaseBar=0;
 InpAutoTrading=false;CRFProcessExecution(true);check(g_crfStatus=="Auto trading OFF" && sends==0,"master off reported");InpAutoTrading=true;
 connected=false;CRFProcessExecution(true);check(g_crfStatus=="Broker disconnected: REVIEW" && sends==0,"disconnection is distinct from slot occupancy");connected=true;
 permission=false;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: Trading permission unavailable" && sends==0,"permission blocker reported");permission=true;
 InpUseAutoSchedule=true;g_p4ScheduleValid=false;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: Daily timer settings invalid","invalid timer reported");
 g_p4ScheduleValid=true;g_p4ScheduleStart=0;g_p4ScheduleEnd=1;CRFProcessExecution(true);
 check(g_crfStatus=="CRF entry: Daily timer paused","paused timer reported");InpUseAutoSchedule=false;
 hedging=false;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: Hedging account required","account mode blocker reported");hedging=true;
 g_marketState=1;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: Market not open","market blocker reported");g_marketState=MARKET_OPEN;
 current.time=0;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: Fresh quote unavailable","stale quote reported");current=q;
 orderMode=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_TP;CRFProcessExecution(true);
 check(g_crfStatus.find("Broker market order / SL / TP")!=string::npos,"required broker protection blocker reported");orderMode=51;
 g_crfReleaseBar=1000;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: Waiting for next closed M15 bar after release","release cooldown reported accurately");g_crfReleaseBar=0;
 g_p4[1].cooldown=1;g_p4[1].waitBar=1000;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: Waiting for next closed M15 bar after previous trade","execution cooldown reported accurately");g_p4[1].cooldown=0;
 calcOk=false;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: CRF lot sizing unavailable","lot sizing failure reported");calcOk=true;
 symbolFill=0;CRFProcessExecution(true);check(g_crfStatus=="CRF entry: Broker filling mode unavailable","filling mode failure reported");symbolFill=SYMBOL_FILLING_FOK;
 checkOk=false;uptime+=6000;CRFProcessExecution(true);
 check(g_crfStatus.find("CRF entry: Order check:")==0 && g_crfStatus.find("Not enough money")!=string::npos && sends==0,"broker order check code and message reported");
 CRFProcessExecution(false);check(g_crfStatus.find("Last entry attempt: Order check:")==0 && g_crfStatus.find("Not enough money")!=string::npos,"timer retains last order-check reason");
 CRFProcessExecution(true);check(g_crfStatus.find("Not enough money")!=string::npos && g_crfStatus.find("retry delay")!=string::npos,"retry delay preserves broker reason");
 checkOk=true;uptime+=6000;moveOnCheck=true;CRFProcessExecution(true);
 check(g_crfStatus=="CRF entry: Quote changed during order check; retrying" && sends==0,"changed quote correctly reported without sending");
 moveOnCheck=false;current=q;uptime+=6000;sendMode=2;CRFProcessExecution(true);
 check(g_crfStatus.find("Order rejected:")==0 && sends==1,"definite broker rejection is not reported as placed");
 CRFRefreshBroker();CRFProcessExecution(false);check(g_crfStatus.find("Order rejected:")!=string::npos,"rejection survives timer reconciliation");
 if(!f)cout<<"CRF execution integration stub checks passed\n";
 return f?1:0;}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(stubs+extra+kernel+runtime+auto+exposure+execution+main)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-Wno-missing-field-initializers','-I',str(root),*flags,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
