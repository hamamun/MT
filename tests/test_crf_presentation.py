#!/usr/bin/env python3
"""Compile the actual CRF presentation helpers against broker/chart stubs."""
from pathlib import Path
import os, runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
b=runpy.run_path(str(root/'tests/test_crf_execution.py'))
extra=b['extra'].replace('struct CRFCandidate{int direction=0;double stop=99,atr=1;};','struct CRFCandidate{int direction=0,variant=0;double marker=0,stop=99,atr=1;};').replace('struct CRFEstimate{bool ready=false,available=true;int duration_high=0,reason=1,samples=6;double confidence=60,move_atr=2;};','struct CRFEstimate{bool ready=false,available=true;int duration_high=0,duration_low=0,reason=1,samples=6;double target=0,confidence=60,move_atr=2,duration=0;};').replace('int active_direction=0;long signal_bar=0,last_bar=0;','int active_direction=0,remaining=0,pending_elapsed=0,last_result=0,last_event=0;long signal_bar=0,last_bar=0,last_event_bar=0;')
chart=r'''
using color=int;
bool CRFValidPrice(double x){return isfinite(x) && x!=EMPTY_VALUE;}
string StringSubstr(const string &s,int pos){return s.substr(pos);}
#define TIME_DATE 1
#define TIME_MINUTES 2
#define OBJ_TREND 1
#define OBJ_ARROW 2
#define OBJPROP_RAY_RIGHT 1
#define OBJPROP_COLOR 2
#define OBJPROP_STYLE 3
#define OBJPROP_WIDTH 4
#define OBJPROP_SELECTABLE 5
#define OBJPROP_HIDDEN 6
#define OBJPROP_ARROWCODE 7
#define OBJPROP_BACK 8
#define STYLE_SOLID 0
#define clrAqua 1
#define clrRed 2
#define clrYellow 3
#define clrLimeGreen 4
struct ChartObject{double price=0;int color=0,type=0;bool back=false;};map<string,ChartObject> chart;
int ObjectFind(int,string n){return chart.count(n)?0:-1;}
bool ObjectCreate(int,string n,int kind,int,datetime,double price,datetime=0,double=0){chart[n].type=kind;chart[n].price=price;return true;}
bool ObjectMove(int,string n,int,datetime,double price){chart[n].price=price;return true;}
bool ObjectDelete(int,string n){chart.erase(n);return true;}
bool ObjectSetDouble(int,string n,int,double v){chart[n].price=v;return true;}
bool ObjectSetInteger(int,string n,int prop,long v){if(prop==OBJPROP_COLOR)chart[n].color=int(v);if(prop==OBJPROP_BACK)chart[n].back=bool(v);return true;}
void ObjectsDeleteAll(int,string prefix){for(auto i=chart.begin();i!=chart.end();)if(i->first.find(prefix)==0)i=chart.erase(i);else ++i;}
string TimeToString(datetime,int){return "2026.11.02 10:00";}
int Bars(string,int){return 1000;}
double iLow(string,int,int){return 98;}
double iHigh(string,int,int){return 102;}
'''
s=(root/'MT_CRF_Presentation.mqh').read_text().replace('string &rows[]','vector<string> &rows')
main=r'''
int main(){int fails=0;auto check=[&](bool b,const char*m){if(!b){cerr<<"FAIL "<<m<<"\n";fails++;}};
 InpUseAutoSchedule=false;P5Init();P4Init();CRFRefreshBroker();g_crfObserverAvailable=true;g_crfForecastCurrent=true;
 auto &f=g_crfObserver.forecast;f.active_direction=1;f.signal_bar=1000;f.last_bar=1000;f.last_entry=100;f.active_stop=99;f.active_target=102;
 f.last_signal.direction=1;f.last_signal.variant=21;f.last_signal.stop=99;f.remaining=4;
 f.last_estimate.available=true;f.last_estimate.ready=true;f.last_estimate.reason=5;f.last_estimate.samples=6;f.last_estimate.duration=3;f.last_estimate.duration_low=2;f.last_estimate.duration_high=4;f.last_estimate.target=102;f.last_estimate.move_atr=1.5;
 check(CRFDisplayM15() && CRFReadingLine().find("~4b")!=string::npos,"CRF M15 state");
 InpAutoTrading=true;InpAllowAutoM15=false;
 check(CRFAutoLine().find("Auto: ON")!=string::npos && CRFPlanLine().find("Auto ON")!=string::npos && CRFHeaderStatus().find("Auto ON")!=string::npos && CRFHeaderStatus().find("MT M15 switch OFF")!=string::npos,"CRF auto remains on and MT M15 off is explicitly labeled");
 g_p4View[3].state=P4_OPEN;g_p4View[3].direction=1;g_p4View[3].entry=100;g_p4View[3].sl=99;g_p4View[3].tp=102;g_p4View[3].lot=.1;
 check(CRFAutoLine().find("Auto: ON")!=string::npos && CRFAutoLine().find("BUY OPEN")!=string::npos && CRFAutoLine().find("CRF strategy 30007")!=string::npos,"open CRF row remains ON with MT M15 off");
 g_p4View[3].state=P4_EMPTY;
 InpAutoTrading=false;check(CRFAutoLine().find("Auto: OFF")!=string::npos && CRFPlanLine().find("Auto OFF")!=string::npos,"master off is shown for CRF");
 InpAutoTrading=true;InpAllowAutoM15=true;check(CRFAutoLine().find("Auto: ON")!=string::npos && CRFHeaderStatus().find("MT M15 switch ON")!=string::npos,"CRF and MT M15 enabled shown separately");
 g_crfStatus="CRF entry: Daily timer paused";
 check(CRFAutoLine().find("CRF | CRF")==string::npos && CRFAutoLine().find("Daily timer paused")!=string::npos,"auto row avoids duplicate CRF label and shows specific reason");
 check(CRFPlanLine().find("BUY (CRF)")!=string::npos && CRFPlanLine().find("Hammer")!=string::npos && CRFPlanLine().find("Meets selected filters")!=string::npos,"CRF plan details");
 vector<string> rows;CRFDashboardRows(rows);check(rows.size()==15 && rows[0].find("BUY")!=string::npos && rows[12].find("4 bars")!=string::npos,"active dashboard 15 rows");
 InpMode=MT_CRF_MODE_CRF;InpCrfAutoFollowthroughPct=55;f.last_estimate.ready=false;f.last_estimate.reason=3;f.last_estimate.confidence=19;
 CRFProcessExecution(true);
 check(CRFAutoLine().find("Blocked: below follow-through filter (min 55%)")!=string::npos && CRFHeaderStatus().find("Blocked: below follow-through filter")!=string::npos,"weak forecast reason displayed in auto and header");
 check(CRFPlanLine().find("Lot: --")!=string::npos && CRFPlanLine().find("Lot unavailable: auto filters not met")!=string::npos,"blocked lot is explained, not presented as an executable lot");
 check(sends==0,"weak forecast does not send an order");
 InpCrfAutoFollowthroughPct=15;check(CRFAutoFilterReady(f) && CRFPlanLine().find("Auto filter 15%: PASS")!=string::npos,"reference 55 percent status does not block 15 percent auto filter");
 check(CRFHeaderStatus().find("CRF auto filter 15%")!=string::npos && CRFHeaderStatus().find("min 4 samples")!=string::npos && CRFPlanLine().find("Auto min samples 4")!=string::npos,"selected auto filters visible in header and plan");
 f.last_estimate.samples=4;f.last_estimate.reason=2;
 check(CRFAutoFilterReady(f) && CRFPlanLine().find("Low sample count")!=string::npos && CRFPlanLine().find("Auto filter 15%: PASS")!=string::npos,"reference six-sample quality remains distinct from auto minimum");
 InpCrfAutoMinimumSamples=5;check(CRFPlanLine().find("Lot unavailable: auto filters not met")!=string::npos,"below selected auto samples explains unavailable lot");
 InpCrfAutoMinimumSamples=4;f.last_estimate.samples=6;f.last_estimate.reason=3;
 InpAutoTrading=false; CRFUpdatePlan();
 check(CRFPlanLine().find("Lot: --")==string::npos && CRFPlanLine().find("Lot unavailable:")==string::npos && sends==0,"lot preview appears for eligible confirmed signal even with master auto off");
 P3Plan probeForPresentation; MqlTick savedQuote=current;current.bid=100.59;current.ask=100.60;
 CRFUpdatePlan();check(CRFPlanLine().find("Lot: --")==string::npos && CRFLiveEntryReason(f,current,probeForPresentation)=="Below live R/R filter","frozen lot stays visible even when live entry is blocked");current=savedQuote;
 calcOk=false;CRFUpdatePlan();check(CRFPlanLine().find("Lot: --")==string::npos,"temporary sizing failure does not erase frozen lot");calcOk=true;
 current.bid=102;current.ask=102.02;CRFUpdatePlan();
 check(CRFPlanLine().find("Signal: NONE")!=string::npos && CRFPlanLine().find("target passed")!=string::npos && CRFHeaderStatus().find("Target passed")!=string::npos,"target-passed plan disappears from plan and header");
 CRFDashboardRows(rows);check(rows[1].find("Target passed")!=string::npos && rows[5].find("Last entry")!=string::npos,"details distinguish stale forecast from active plan");
 current=savedQuote;f.active_direction=0;CRFUpdatePlan();f.active_direction=1;CRFUpdatePlan();
 check(CRFHeaderStatus().find("CRF trailstop ON")!=string::npos,"default trail input visible");
 InpCrfTrailStop=false;check(CRFHeaderStatus().find("CRF trailstop OFF")!=string::npos,"disabled trail input visible");InpCrfTrailStop=true;
 check(CRFHeaderStatus().find("CRF risk bypass OFF")!=string::npos && CRFPlanLine().find("CRF risk bypass OFF")!=string::npos,"CRF bypass default OFF visible");
 f.last_estimate.move_atr=1;check(!CRFAutoFilterReady(f),"reference forecast R/R blocked when bypass off");
 InpCrfRiskBypass=true;check(CRFAutoFilterReady(f) && CRFHeaderStatus().find("CRF risk bypass ON")!=string::npos && CRFPlanLine().find("CRF risk bypass ON")!=string::npos,"CRF bypass ON and auto status visible");
 InpCrfRiskBypass=false;f.last_estimate.move_atr=1.5;
 CRFDashboardRows(rows);check(rows[10].find("reference 55%")!=string::npos && rows[10].find("Auto filter 15%: PASS")!=string::npos,"dashboard distinguishes reference and auto filters");
 f.last_estimate.ready=true;f.last_estimate.reason=5;InpMode=MT_CRF_MODE_BOTH;
 check(CRFSetLevel("entry",1000,1001,100,clrAqua) && CRFSetMarker(1000,false,1,98),"finite line and marker objects created");
 string stamp=StringFormat("%I64d",(long)1000);string entryKey="MTCRF_entry_"+stamp,markerKey="MTCRF_marker_"+stamp+"_confirmed";
 check(chart[entryKey].back && chart[markerKey].back,"forecast lines and markers are behind foreground panel");
 chart[entryKey].back=false;check(CRFSetLevel("entry",1000,1001,100,clrAqua) && chart[entryKey].back,"updates restore background layer on existing objects");
 check(CRFSetLevel("negative",1000,1001,-1,clrRed) && CRFSetMarker(1001,true,-1,0),"finite zero or negative historical prices are not discarded");
 f.active_direction=0;f.remaining=0;
 CRFDashboardRows(rows);check(rows[5].find("Last entry")!=string::npos && rows[7].find("Last TP")!=string::npos,"idle retained values labelled last");
 InpMode=MT_CRF_MODE_MT;check(!CRFDisplayM15() && CRFModeText()=="MT only","MT-only hides CRF");
 if(fails)return 1;cout<<"CRF presentation stub checks passed\n";
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp);(p/'test.cpp').write_text(b['stubs']+extra+b['kernel']+b['runtime']+b['auto']+b['exposure']+b['execution']+chart+s+main)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-Wno-missing-field-initializers','-I',str(root),*flags,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
