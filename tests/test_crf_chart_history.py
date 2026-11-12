#!/usr/bin/env python3
"""Replay production forecast/chart code against a synthetic M15 terminal.

This checks reconstruction, restart, catch-up, object geometry, and failures;
it is not a native MT5 renderer or an Indie runtime comparison.
"""
from pathlib import Path
import json, os, re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
fixture=json.loads((root/'tests/fixtures/crf_indie_emulated.json').read_text())
rows=',\n'.join('{%d,%.17g,%.17g,%.17g,%.17g,%d}'%(1000+i*900,r['o'],r['h'],r['l'],r['c'],r['v']) for i,r in enumerate(fixture['rows']))
presentation=(root/'MT_CRF_Presentation.mqh').read_text().split('void CRFRemoveObjects()',1)[1].rsplit('#endif',1)[0]
presentation='void CRFRemoveObjects()'+presentation
history=(root/'MT_CRF_ChartHistory.mqh').read_text()
assert not re.search(r'\b(?:OrderSend|OrderCheck|P4Persist|CRFObserverPoll)\s*\(',history)
program=r'''
#include <cmath>
#include <limits>
#include <vector>
#include <algorithm>
#include <cstring>
#include <iostream>
#include <string>
#include <map>
#include <cstdarg>
using namespace std;
using datetime=long;using ulong=unsigned long;using color=int;
#define EMPTY_VALUE std::numeric_limits<double>::max()
#define PERIOD_M15 15
#define SERIES_SYNCHRONIZED 1
#define SERIES_FIRSTDATE 2
#define OBJ_TREND 1
#define OBJ_ARROW 2
#define OBJPROP_RAY_RIGHT 1
#define OBJPROP_COLOR 2
#define OBJPROP_STYLE 3
#define OBJPROP_WIDTH 4
#define OBJPROP_SELECTABLE 5
#define OBJPROP_HIDDEN 6
#define OBJPROP_ARROWCODE 7
#define STYLE_SOLID 0
#define clrAqua 1
#define clrRed 2
#define clrYellow 3
#define clrLimeGreen 4
bool MathIsValidNumber(double x){return std::isfinite(x);} double MathAbs(double x){return std::abs(x);} double MathSqrt(double x){return std::sqrt(x);}
template<class T,class U> double MathMax(T x,U y){return std::max(double(x),double(y));}
template<class T,class U> double MathMin(T x,U y){return std::min(double(x),double(y));}
template<class T> void ZeroMemory(T &x){std::memset(&x,0,sizeof(x));}
struct MqlRates{long time;double open,high,low,close;long long tick_volume;};
template<class T> int ArraySize(const vector<T>&x){return int(x.size());}
template<class T> int ArrayResize(vector<T>&x,int n,int reserve=0){(void)reserve;x.resize(n);return n;}
template<class T> int ArrayCopy(vector<T>&a,const vector<T>&b,int dst,int src,int n){if(src<0||dst<0||src+n>int(b.size())||dst+n>int(a.size()))return -1;std::copy(b.begin()+src,b.begin()+src+n,a.begin()+dst);return n;}
template<class T> bool ArraySetAsSeries(vector<T>&,bool b){return !b;}
template<class T> void ArrayFree(vector<T>&x){x.clear();x.shrink_to_fit();}
string _Symbol="EURUSD";vector<MqlRates> source;bool sync_ok=true,partial=false;ulong uptime=10000;
bool SeriesInfoInteger(const string&,int period,int property,long &v){if(period!=PERIOD_M15||source.empty())return false;v=property==SERIES_SYNCHRONIZED?sync_ok:source.front().time;return true;}
int Bars(const string&,int period){return period==PERIOD_M15?int(source.size()):0;}
datetime iTime(const string&,int period,int shift){if(period!=PERIOD_M15||shift<0||shift>=int(source.size()))return 0;return source[source.size()-1-shift].time;}
int iBarShift(const string&,int period,datetime when,bool exact){if(period!=PERIOD_M15||!exact)return -1;for(size_t i=0;i<source.size();i++)if(source[i].time==when)return int(source.size()-1-i);return -1;}
int CopyRates(const string&,int period,int start,int count,vector<MqlRates>&out){if(period!=PERIOD_M15||start!=1||count<0||count>int(source.size())-1)return -1;if(partial)count--;out.assign(source.end()-1-count,source.end()-1);return count;}
ulong GetTickCount64(){return uptime;}
string StringFormat(const char*,long n){return std::to_string(n);}
bool P3Positive(double v){return std::isfinite(v)&&v!=EMPTY_VALUE&&v>0;}
struct Obj{int type=0,ink=0;long start=0,end=0;double price=0;};map<string,Obj> objects;bool objectFailure=false;
int ObjectFind(int,string n){return objects.count(n)?0:-1;}
bool ObjectCreate(int,string n,int type,int,datetime t,double price,datetime end=0,double=0){if(objectFailure){objectFailure=false;return false;}objects[n]={type,0,t,end,price};return true;}
bool ObjectMove(int,string n,int point,datetime t,double price){if(!objects.count(n))return false;auto &o=objects[n];if(point==0)o.start=t;else o.end=t;o.price=price;return true;}
bool ObjectSetInteger(int,string n,int prop,long v){if(!objects.count(n))return false;if(prop==OBJPROP_COLOR)objects[n].ink=int(v);return true;}
void ObjectsDeleteAll(int,string prefix){for(auto i=objects.begin();i!=objects.end();)if(i->first.find(prefix)==0)i=objects.erase(i);else ++i;}
void Print(const char*,string){}
#include "MT_CRF_M15.mqh"
struct CRFObserver{bool ready=true;CRFForecastState forecast;};
CRFObserver g_crfObserver;bool g_crfObserverAvailable=true,g_crfForecastCurrent=true;
int InpMode=0;const int MT_CRF_MODE_MT=1;bool chartSupported=true;bool ChartSupported(){return chartSupported;}
CRFParameters params{300,4,2,5,2,3,2,55,1.2};CRFParameters CRFInputParameters(){return params;}
PRESENTATION
#include "MT_CRF_ChartHistory.mqh"
vector<MqlRates> fixture={ROWS};
CRFForecastState observerAtEnd(){CRFForecastState f{};CRFResetForecast(f);vector<MqlRates> prefix;for(size_t i=0;i+1<source.size();i++){prefix.push_back(source[i]);if(i>=size_t(max(max(params.atr,params.trend),max(params.volume,params.swing))+4) && !CRFForecastOnBar(prefix,source[i].time,params,f)){cerr<<"observer error\n";exit(2);}}return f;}
void expectedLevel(map<string,Obj>&expected,string key,const CRFForecastState &s,long end,int ink,double price){expected["MTCRF_"+key+"_"+to_string(s.signal_bar)]={OBJ_TREND,ink,s.signal_bar,end,price};}
map<string,Obj> expectedChart(){
 map<string,Obj> out;CRFForecastState f{};CRFResetForecast(f);vector<MqlRates> prefix;
 int start=max(max(params.atr,params.trend),max(params.volume,params.swing))+4;
 for(size_t i=0;i+1<source.size();i++){
  auto bar=source[i];prefix.push_back(bar);if(int(i)<start)continue;
  auto prev=f;if(!CRFForecastOnBar(prefix,bar.time,params,f)){cerr<<"expected forecast error\n";exit(2);}
  if(prev.active_direction!=0 && (f.active_direction==0 || f.signal_bar!=prev.signal_bar)){
   expectedLevel(out,"entry",prev,bar.time,clrAqua,prev.last_entry);expectedLevel(out,"stop",prev,bar.time,clrRed,prev.active_stop);expectedLevel(out,"target",prev,bar.time,clrYellow,prev.active_target);}
  if(f.last_event_bar==bar.time && f.last_event==1)out["MTCRF_marker_"+to_string(bar.time)+"_candidate"]={OBJ_ARROW,clrYellow,bar.time,0,f.pending.marker};
  if(f.signal_bar==bar.time && f.last_signal.direction!=0)out["MTCRF_marker_"+to_string(bar.time)+"_confirmed"]={OBJ_ARROW,f.last_signal.direction>0?clrLimeGreen:clrRed,bar.time,0,f.last_signal.direction>0?bar.low:bar.high};
 }
 if(f.active_direction!=0){long end=source.back().time;expectedLevel(out,"entry",f,end,clrAqua,f.last_entry);expectedLevel(out,"stop",f,end,clrRed,f.active_stop);expectedLevel(out,"target",f,end,clrYellow,f.active_target);}
 return out;
}
bool equalChart(const map<string,Obj>&a,const map<string,Obj>&b){if(a.size()!=b.size())return false;for(const auto &kv:a){auto i=b.find(kv.first);if(i==b.end())return false;auto x=kv.second,y=i->second;if(x.type!=y.type||x.ink!=y.ink||x.start!=y.start||x.end!=y.end||fabs(x.price-y.price)>1e-8)return false;}return true;}
int main(){int failures=0;auto check=[&](bool ok,const char*m){if(!ok){cerr<<"FAIL "<<m<<"\n";failures++;}};
 source.assign(fixture.begin(),fixture.begin()+501);g_crfObserver.forecast=observerAtEnd();auto original=g_crfObserver.forecast;
 CRFChartHistoryReset();CRFChartHistoryStep();check(!g_crfChartReady && g_crfChartIndex<=256+20,"long histories are processed in bounded slices");
 // New closed candles arrive while the old snapshot is being replayed.
 source=fixture;{auto forming=source.back();forming.time+=900;source.push_back(forming);}g_crfObserver.forecast=observerAtEnd();original=g_crfObserver.forecast;
 for(int i=0;i<50 && !g_crfChartReady;i++){uptime+=100;CRFChartHistoryStep();}
 check(g_crfChartReady && g_crfChartState.last_bar==source[source.size()-2].time,"history and new bars caught up");
 auto expected=expectedChart();int candidates=0,buy=0,sell=0,lines=0;
 for(auto &kv:expected){if(kv.second.type==OBJ_TREND)lines++;else if(kv.second.ink==clrYellow)candidates++;else if(kv.second.ink==clrLimeGreen)buy++;else if(kv.second.ink==clrRed)sell++;}
 check(candidates>0 && buy>0 && sell>0 && lines>=6,"fixture includes candidate, buy, sell and forecast levels");
 {CRFForecastState f{};CRFResetForecast(f);vector<MqlRates> prefix;int noEstimate=0;
  int start=max(max(params.atr,params.trend),max(params.volume,params.swing))+4;
  for(size_t i=0;i+1<source.size();i++){prefix.push_back(source[i]);if(int(i)<start)continue;CRFForecastOnBar(prefix,source[i].time,params,f);
   if(f.signal_bar==source[i].time && !f.last_estimate.available){noEstimate++;check(objects.count("MTCRF_marker_"+to_string(source[i].time)+"_confirmed")!=0,"confirmation without analog estimate has its marker");}}
  check(noEstimate>0,"fixture includes confirmation without historical estimate");}
 check(equalChart(objects,expected),"all markers and finite forecast segments match independent full replay");
 check(CRFChartForecastMatches(original,g_crfObserver.forecast),"visual replay does not mutate trading forecast");
 // Remove EA/chart objects and restart on exactly the same data.
 CRFRemoveObjects();CRFChartHistoryReset();for(int i=0;i<50 && !g_crfChartReady;i++){uptime+=100;CRFChartHistoryStep();}
 check(g_crfChartReady && equalChart(objects,expected),"restart reconstructs identical historical objects");
 // New bar after reconstruction is replayed through the same path.
 auto last=source.back();last.time+=900;source.push_back(last);g_crfObserver.forecast=observerAtEnd();
 for(int i=0;i<50 && (!g_crfChartReady || g_crfChartState.last_bar!=g_crfObserver.forecast.last_bar);i++){uptime+=100;CRFChartHistoryStep();}
 check(g_crfChartReady && equalChart(objects,expectedChart()),"new bar after reconstruction stays synchronized");
 // Broken data and chart-object failures clear partial drawings and retry.
 CRFRemoveObjects();CRFChartHistoryReset();sync_ok=false;CRFChartHistoryStep();check(g_crfChartError && objects.empty(),"unsynchronized history reported and no partial chart");
 check(CRFChartHistoryStatus().find("historical CRF drawings unavailable")!=string::npos && CRFChartHistoryStatus().find("chart history unavailable")==string::npos,"label describes historical CRF drawings rather than MT5 history");
 sync_ok=true;partial=true;uptime+=5001;CRFChartHistoryStep();
 check(g_crfChartError && objects.empty(),"partial history copy is not presented as complete");
 partial=false;uptime+=5001;for(int i=0;i<50 && !g_crfChartReady;i++){uptime+=100;CRFChartHistoryStep();}
 check(g_crfChartReady && equalChart(objects,expectedChart()),"history automatically retries after synchronization");
 CRFRemoveObjects();CRFChartHistoryReset();objectFailure=true;CRFChartHistoryStep();check(g_crfChartError && objects.empty(),"object failure clears incomplete chart");
 uptime+=5001;for(int i=0;i<50 && !g_crfChartReady;i++){uptime+=100;CRFChartHistoryStep();}
 check(g_crfChartReady && equalChart(objects,expectedChart()),"object failure retries reconstruction");
 CRFRemoveObjects();CRFChartHistoryReset();g_crfObserver.forecast.last_result=42;
 for(int i=0;i<50 && !g_crfChartError;i++){uptime+=100;CRFChartHistoryStep();}
 check(g_crfChartError && objects.empty(),"reconstruction inconsistent with saved observer fails visibly");
 g_crfObserver.forecast=observerAtEnd();uptime+=5001;for(int i=0;i<50 && !g_crfChartReady;i++){uptime+=100;CRFChartHistoryStep();}
 check(g_crfChartReady && equalChart(objects,expectedChart()),"matched observer state recovers");
 // Detect a change in the earliest history while replaying; rebuild from the
 // new complete series, rather than silently omitting newly changed history.
 CRFRemoveObjects();CRFChartHistoryReset();CRFChartHistoryStep();source.erase(source.begin());g_crfObserver.forecast=observerAtEnd();uptime+=100;CRFChartHistoryStep();
 check(g_crfChartError && objects.empty(),"changed earliest history discards partial reconstruction");
 uptime+=5001;for(int i=0;i<50 && !g_crfChartReady;i++){uptime+=100;CRFChartHistoryStep();}
 check(g_crfChartReady && equalChart(objects,expectedChart()),"changed earliest history replays completely");
 CRFRemoveObjects();CRFChartHistoryReset();InpMode=MT_CRF_MODE_MT;CRFChartHistoryStep();check(objects.empty(),"MT-only mode draws no CRF objects");
 if(!failures)cout<<"CRF chart history reconstruction checks passed\n";return failures?1:0;
}
'''.replace('PRESENTATION',presentation).replace('ROWS',rows)
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)
 for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh','MT_CRF_Feed.mqh','MT_CRF_M15.mqh','MT_CRF_ChartHistory.mqh'):
  text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars').replace('const MqlRates &rates[]','const std::vector<MqlRates> &rates').replace('MqlRates &out[]','std::vector<MqlRates> &out').replace('CRFFeedUpdate &updates[]','std::vector<CRFFeedUpdate> &updates').replace('MqlRates prefix[];','std::vector<MqlRates> prefix;').replace('CRFFeedUpdate staged[];','std::vector<CRFFeedUpdate> staged;').replace('MqlRates g_crfChartRates[], g_crfChartPrefix[];','std::vector<MqlRates> g_crfChartRates, g_crfChartPrefix;')
  (p/name).write_text(text)
 (p/'test.cpp').write_text(program)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-I',tmp,*flags,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
