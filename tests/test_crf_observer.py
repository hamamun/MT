#!/usr/bin/env python3
"""Observer persistence ordering/recovery using isolated C++ stubs."""
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
program=r'''
#include <cmath>
#include <limits>
#include <vector>
#include <algorithm>
#include <cstring>
#include <iostream>
#include <string>
#define EMPTY_VALUE std::numeric_limits<double>::max()
#define MT_CRF_M15_MQH
#define MT_CRF_JOURNAL_MQH
#define MT_CRF_CACHE_MQH
using string=std::string;using datetime=long;using ulong=unsigned long;
#define PERIOD_M15 15
#define SERIES_SYNCHRONIZED 1
#define SERIES_FIRSTDATE 2
void ResetLastError(){} int GetLastError(){return 0;} ulong GetTickCount64(){return 0;}
string StringFormat(const char*,int a,int b,int c){return std::to_string(a)+"/"+std::to_string(b)+"/"+std::to_string(c);}
template<class T> void ArrayFree(std::vector<T>&x){x.clear();}
template<class T> bool ArraySetAsSeries(std::vector<T>&,bool b){return !b;}
bool MathIsValidNumber(double x){return std::isfinite(x);}
double MathAbs(double x){return std::abs(x);}
double MathSqrt(double x){return std::sqrt(x);}
template<class T,class U> double MathMax(T x,U y){return std::max(double(x),double(y));}
template<class T,class U> double MathMin(T x,U y){return std::min(double(x),double(y));}
template<class T> void ZeroMemory(T &x){std::memset(&x,0,sizeof(x));}
struct MqlRates { long time; double open,high,low,close; long long tick_volume; };
template<class T> int ArraySize(const std::vector<T>& x){return int(x.size());}
template<class T> int ArrayResize(std::vector<T>& x,int n,int reserve=0){(void)reserve;x.resize(n);return n;}
template<class T> int ArrayCopy(std::vector<T>& a,const std::vector<T>& b,int dst,int src,int n){if(src<0||dst<0||src+n>int(b.size())||dst+n>int(a.size()))return -1;std::copy(b.begin()+src,b.begin()+src+n,a.begin()+dst);return n;}
#include "MT_CRF_Feed.mqh"
enum CRF_JOURNAL_RESULT{CRF_JOURNAL_OK,CRF_JOURNAL_MISSING,CRF_JOURNAL_INVALID,CRF_JOURNAL_CONFIG_CHANGED,CRF_JOURNAL_IO_ERROR};
enum CRF_M15_RESULT{CRF_M15_OK,CRF_M15_WAIT_HISTORY,CRF_M15_HISTORY_CHANGED,CRF_M15_TOO_MUCH_HISTORY,CRF_M15_ANCHOR_MISSING,CRF_M15_BAD_INPUT};
static bool exists=false,fail_save=false,fail_history=false,corrupt=false,partial_copy=false;static int save_count=0;
static CRFForecastState durable;static std::vector<MqlRates> source;
bool SeriesInfoInteger(const string&,int,int what,long &out){out=what==SERIES_SYNCHRONIZED?!fail_history:(source.empty()?0:source.front().time);return true;}
datetime iTime(const string&,int,int shift){return shift>=1 && shift<=int(source.size())?source[source.size()-shift].time:0;}
int iBarShift(const string&,int,datetime bar,bool){for(size_t i=0;i<source.size();i++)if(source[i].time==bar)return int(source.size()-i);return -1;}
bool CRFM15SameOverlap(const std::vector<MqlRates>&a,const std::vector<MqlRates>&b,int n){int i=int(a.size())-1,j=n-1;while(i>=0 && j>=0){if(a[i].time!=b[j].time||a[i].open!=b[j].open||a[i].high!=b[j].high||a[i].low!=b[j].low||a[i].close!=b[j].close||a[i].tick_volume!=b[j].tick_volume)return false;i--;j--;}return true;}
int CRFFirstUsableM15Shift(const string &s,long first){return iBarShift(s,PERIOD_M15,first,true);}
int CopyRates(const string&,int,int start,int count,std::vector<MqlRates>&out){if(fail_history || start<1 || start+count-1>int(source.size()))return -1;out.assign(source.end()-start+1-count,source.end()-start+1);if(partial_copy){out.pop_back();return count-1;}return count;}
CRF_JOURNAL_RESULT CRFLoadForecast(const string&,int,const CRFParameters&,CRFForecastState &s){if(corrupt)return CRF_JOURNAL_INVALID;if(!exists)return CRF_JOURNAL_MISSING;s=durable;return CRF_JOURNAL_OK;}
bool CRFSaveForecast(const string&,int,const CRFParameters&,const CRFForecastState &s){save_count++;if(fail_save)return false;durable=s;exists=true;return true;}
CRF_M15_RESULT CRFReadClosedM15Detailed(const string&,const CRFParameters&,long,std::vector<MqlRates> &out,bool &first,long &latest,string &detail){if(fail_history){detail="simulated copy failure";return CRF_M15_WAIT_HISTORY;}detail="";out=source;first=true;latest=source.back().time;return CRF_M15_OK;}
void CRFCacheInit(const string&,int,const CRFParameters&){}
bool CRFCacheMatches(const std::vector<MqlRates>&){return true;}
bool CRFCacheUpdate(const std::vector<MqlRates>&){return true;}
#include "MT_CRF_Observer.mqh"
int main(){
 int failures=0;auto check=[&](bool x,const char *s){if(!x){std::cerr<<"FAIL "<<s<<"\n";failures++;}};
 for(int i=0;i<20;i++)source.push_back({i+1,100,101,99,100,100});
 CRFParameters p{100,4,2,5,2,3,2,55,1.2};CRFObserver observer{};std::vector<CRFFeedUpdate> u;
 check(CRFObserverInit(observer,"X","x",0,p,false)==CRF_OBSERVER_INVALID && !observer.ready,"lock required");
 check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_OK && observer.ready,"init empty");
 fail_history=true;check(CRFObserverPoll(observer,u)==CRF_OBSERVER_HISTORY_UNAVAILABLE && observer.forecast.last_bar==0 && u.empty() && observer.history_detail.find("synchronizing")!=string::npos,"history failure reason retained without mutation");fail_history=false;
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_OK && u.size()==1 && u[0].bootstrap && durable.last_bar==20 && observer.forecast.last_bar==20,"bootstrap saved before exposure");
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_OK && u.empty() && save_count==1,"duplicates do not write");
 source.push_back({21,100,101,99,100,100});fail_save=true;
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_JOURNAL_ERROR && u.empty() && !observer.ready && observer.forecast.last_bar==20 && durable.last_bar==20,"failed save latches and hides events");
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_INVALID,"latched observer cannot continue");
 fail_save=false;check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_OK && observer.forecast.last_bar==20,"reload durable anchor");
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_OK && u.size()==1 && !u[0].bootstrap && u[0].bar==21 && durable.last_bar==21,"missed bar replayed after restart");
 // Long bootstrap uses bounded slabs, retains full historical state, and
 // never exposes historical signals before a durable caught-up save.
 source.clear();for(int cycle=0;cycle<150;cycle++){
   for(int j=0;j<5;j++){double c=130-j;source.push_back({long(source.size()+1),c+.6,c+.8,c-.2,c,100});}
   source.push_back({long(source.size()+1),125,127,124.8,126.8,100});
   source.push_back({long(source.size()+1),127,128,126.5,127.5,100});
   source.push_back({long(source.size()+1),127.5,129,127,128,100});
   source.push_back({long(source.size()+1),128,130,127.5,129,100});
   source.push_back({long(source.size()+1),129,131,128.5,130,100});
 }
 exists=false;save_count=0;corrupt=false;CRFResetForecast(durable);
 check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_OK,"fresh long bootstrap initialized");
 CRF_OBSERVER_RESULT status=CRFObserverPoll(observer,u);
 check(status==CRF_OBSERVER_BOOTSTRAPPING && observer.forecast.last_bar==0 && u.empty() && save_count==0,"partial bootstrap is not saved or exposed");
 // A revised bar in the next slab's overlap must restart staged bootstrap.
 auto revisedIndex=size_t(g_crfBootState.last_bar-1);source[revisedIndex].close-=.1;
 status=CRFObserverPoll(observer,u);
 check(status==CRF_OBSERVER_HISTORY_UNAVAILABLE && observer.forecast.last_bar==0 && u.empty() && save_count==0 && observer.history_detail.find("revised")!=string::npos,"revised overlapping history rejects staged forecast");
 source[revisedIndex].close+=.1;status=CRFObserverPoll(observer,u);
 source.push_back({1501,100,101,99,100,100});int passes=0;
 while(status==CRF_OBSERVER_BOOTSTRAPPING && passes++<100) {
   check(int(g_crfBootRates.size())<=p.history+30+128,"bootstrap memory stays bounded");
   status=CRFObserverPoll(observer,u);
 }
 CRFForecastState expected{};CRFResetForecast(expected);std::vector<CRFFeedUpdate> full;
 check(CRFProcessClosedBars(source,1501,p,true,expected,full)==CRF_FEED_OK && expected.signal_bar>0,"full bootstrap oracle includes confirmed signals");
 check(status==CRF_OBSERVER_OK && u.size()==1 && u[0].bootstrap && save_count==1 && observer.forecast.last_bar==1501 &&
       observer.forecast.signal_bar==expected.signal_bar && observer.forecast.last_result==expected.last_result &&
       observer.forecast.active_direction==expected.active_direction && observer.forecast.last_estimate.confidence==expected.last_estimate.confidence &&
       observer.forecast.last_estimate.target==expected.last_estimate.target && observer.forecast.last_estimate.samples==expected.last_estimate.samples &&
       observer.forecast.remaining==expected.remaining && observer.forecast.pending.direction==expected.pending.direction,
       "slab bootstrap catches new bars and matches full chronological replay");
 // A large offline gap must be loaded in slabs and persisted without
 // exposing intermediate signals; final state equals uninterrupted replay.
 for(int i=1502;i<=2100;i++)source.push_back({long(i),100,101,99,100,100});
 auto anchorBefore=observer.forecast;save_count=0;
 status=CRFObserverPoll(observer,u);
 check(status==CRF_OBSERVER_BOOTSTRAPPING && u.empty() && observer.forecast.last_bar>1501 && observer.forecast.last_bar<2100 && save_count==1,"large catch-up persists one slab without dispatching old signals");
 auto savedAnchor=observer.forecast.last_bar;
 partial_copy=true;status=CRFObserverPoll(observer,u);partial_copy=false;
 check(status==CRF_OBSERVER_HISTORY_UNAVAILABLE && observer.forecast.last_bar==savedAnchor && durable.last_bar==savedAnchor && u.empty(),"partial catch-up copy leaves committed state unchanged");
 fail_history=true;status=CRFObserverPoll(observer,u);fail_history=false;
 check(status==CRF_OBSERVER_HISTORY_UNAVAILABLE && observer.forecast.last_bar==savedAnchor && u.empty(),"missing history blocks catch-up");
 fail_save=true;status=CRFObserverPoll(observer,u);fail_save=false;
 check(status==CRF_OBSERVER_JOURNAL_ERROR && !observer.ready && observer.forecast.last_bar==savedAnchor && u.empty(),"catch-up journal failure latches without exposing signals");
 check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_OK && observer.forecast.last_bar==savedAnchor,"restart resumes durable catch-up slab");
 source.push_back({2101,100,101,99,100,100});status=CRFObserverPoll(observer,u);
 passes=0;while(status==CRF_OBSERVER_BOOTSTRAPPING && passes++<20)status=CRFObserverPoll(observer,u);
 CRFForecastState expectedCatchup=anchorBefore;std::vector<CRFFeedUpdate> allCatchup;
 check(CRFProcessClosedBars(source,2101,p,true,expectedCatchup,allCatchup)==CRF_FEED_OK,"full catch-up oracle succeeds");
 check(status==CRF_OBSERVER_OK && observer.forecast.last_bar==2101 && observer.forecast.signal_bar==expectedCatchup.signal_bar && observer.forecast.last_result==expectedCatchup.last_result,"slab catch-up matches uninterrupted replay");
 source.clear();for(int i=0;i<100050;i++)source.push_back({long(i+1),100,101,99,100,100});
 exists=false;save_count=0;check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_OK,"oversize bootstrap initialized");
 status=CRFObserverPoll(observer,u);passes=0;
 while(status==CRF_OBSERVER_BOOTSTRAPPING && passes++<1000) status=CRFObserverPoll(observer,u);
 check(status==CRF_OBSERVER_OK && observer.forecast.last_bar==100050 && u.size()==1 && u[0].bootstrap && save_count==1,"over 100000 bars bootstrapped without cap or actionable signals");
 corrupt=true;check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_JOURNAL_ERROR && !observer.ready,"corrupt state held");
 if(!failures)std::cout<<"CRF observer persistence checks passed\n";
 return failures?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)
 for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh','MT_CRF_Feed.mqh','MT_CRF_Observer.mqh'):
  text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars').replace('const MqlRates &rates[]','const std::vector<MqlRates> &rates').replace('CRFFeedUpdate &updates[]','std::vector<CRFFeedUpdate> &updates').replace('MqlRates prefix[];','std::vector<MqlRates> prefix;').replace('MqlRates rates[];','std::vector<MqlRates> rates;').replace('MqlRates probe[];','std::vector<MqlRates> probe;').replace('MqlRates g_crfBootRates[], g_crfBootPrefix[];','std::vector<MqlRates> g_crfBootRates, g_crfBootPrefix;').replace('CRFFeedUpdate staged[];','std::vector<CRFFeedUpdate> staged;')
  (p/name).write_text(text)
 (p/'MT_CRF_M15.mqh').write_text('')
 (p/'MT_CRF_Journal.mqh').write_text('')
 (p/'MT_CRF_Cache.mqh').write_text('')
 (p/'test.cpp').write_text(program)
 subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-I',tmp,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
