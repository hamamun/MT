#!/usr/bin/env python3
"""Real observer, slab loader, forecast journal and disk cache with MT5 stubs."""
from pathlib import Path
import os, runpy, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
base=runpy.run_path(str(root/'tests/test_crf_journal.py'))['program'].split('#include "MT_CRF_Journal.mqh"')[0]
extra=r'''
#include <cstdarg>
using datetime=long;using ulong=unsigned long;
#define PERIOD_M15 15
#define SERIES_SYNCHRONIZED 1
#define SERIES_FIRSTDATE 2
#define TERMINAL_MAXBARS 3
std::vector<MqlRates> source;bool synchronized=true;int maxRequest=0;
ulong GetTickCount64(){return 0;} long TerminalInfoInteger(int){return 200000;}
string StringFormat(const char *fmt,...){char b[512];va_list a;va_start(a,fmt);vsnprintf(b,sizeof(b),fmt,a);va_end(a);return b;}
template<class T> void ArrayFree(std::vector<T>&v){v.clear();}
template<class T> bool ArraySetAsSeries(std::vector<T>&,bool b){return !b;}
bool SeriesInfoInteger(const string&,int,int k,long &v){v=k==SERIES_SYNCHRONIZED?synchronized:(source.empty()?0:source.front().time);return true;}
int Bars(const string&,int){return int(source.size())+1;}
datetime iTime(const string&,int,int shift){return shift>=1 && shift<=int(source.size())?source[source.size()-shift].time:0;}
int iBarShift(const string&,int,datetime t,bool){for(size_t i=0;i<source.size();i++)if(source[i].time==t)return int(source.size()-i);return -1;}
int CopyRates(const string&,int,int start,int count,std::vector<MqlRates>&v){maxRequest=std::max(maxRequest,count);if(!synchronized || start<1 || start+count-1>int(source.size()))return -1;v.assign(source.end()-start+1-count,source.end()-start+1);return count;}
#include "MT_CRF_Observer.mqh"
'''
main=r'''
int main(int argc,char **argv){
 if(argc!=2)return 2;int fails=0;auto ck=[&](bool b,const char*m){if(!b){std::cerr<<"FAIL "<<m<<"\n";fails++;}};
 string file=argv[1];CRFParameters p{100,4,2,5,2,3,2,55,1.2};
 for(int i=0;i<2000;i++)source.push_back({long(i+1),100,101,99,100,100});
 CRFObserver observer{};std::vector<CRFFeedUpdate> updates;
 ck(CRFObserverInit(observer,"X",file,0,p,true)==CRF_OBSERVER_OK,"fresh observer initialized");
 auto result=CRFObserverPoll(observer,updates);int steps=0;
 while(result==CRF_OBSERVER_BOOTSTRAPPING && steps++<100)result=CRFObserverPoll(observer,updates);
 ck(result==CRF_OBSERVER_OK && observer.forecast.last_bar==2000 && updates.size()==1 && updates[0].bootstrap,"bounded bootstrap persisted without dispatch");
 ck(maxRequest<=p.history+20+128 && FileIsExist(file,0) && FileIsExist(file+".rates",0),"bounded slabs and local rolling history saved");
 ck(g_crfCacheRates.size()==110 && g_crfCacheRates.front().time==1891,"cache contains bounded latest closed bars");
 CRFObserver reloaded{};ck(CRFObserverInit(reloaded,"X",file,0,p,true)==CRF_OBSERVER_OK && g_crfCacheRates.size()==110 && reloaded.forecast.last_bar==2000,"forecast and history cache survive restart");
 source.push_back({2001,100,101,99,100,110});maxRequest=0;result=CRFObserverPoll(reloaded,updates);
 ck(result==CRF_OBSERVER_OK && reloaded.forecast.last_bar==2001 && !updates.empty() && !updates[0].bootstrap,"new live close processed after restart");
 ck(g_crfCacheRates.front().time==1892 && g_crfCacheRates.back().time==2001 && maxRequest<200,"cache rotates oldest bar; live verification stays bounded");
 g_crfCacheRates.back().close=100.5;
 source.push_back({2002,100,101,99,100,111});result=CRFObserverPoll(reloaded,updates);
 ck(result==CRF_OBSERVER_HISTORY_UNAVAILABLE && updates.empty() && reloaded.forecast.last_bar==2001 && reloaded.history_detail.find("differs")!=string::npos,"cache revision mismatch blocks stale forecast and emits reason");
 ck(!synchronized || maxRequest<2000,"does not fetch all historical bars at once");
 source.clear();for(int i=0;i<100050;i++)source.push_back({long(i+1),100,101,99,100,100});
 string largeFile=file+".large";CRFObserver large{};maxRequest=0;
 ck(CRFObserverInit(large,"X",largeFile,0,p,true)==CRF_OBSERVER_OK,"large real observer initialized");
 result=CRFObserverPoll(large,updates);steps=0;
 while(result==CRF_OBSERVER_BOOTSTRAPPING && steps++<1000)result=CRFObserverPoll(large,updates);
 ck(result==CRF_OBSERVER_OK && large.forecast.last_bar==100050 && updates.size()==1 && updates[0].bootstrap && maxRequest<250 && g_crfCacheRates.size()==110,"real loader bootstraps more than 100000 bars with bounded requests and disk cache");
 if(!fails)std::cout<<"CRF history/observer/cache integration checks passed\n";return fails?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)
 for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh','MT_CRF_Feed.mqh','MT_CRF_M15.mqh','MT_CRF_Journal.mqh','MT_CRF_Cache.mqh','MT_CRF_Observer.mqh'):
  text=(root/name).read_text().replace('const MqlRates &previous[]','const std::vector<MqlRates> &previous').replace('const MqlRates &current[]','const std::vector<MqlRates> &current').replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars').replace('const MqlRates &rates[]','const std::vector<MqlRates> &rates').replace('MqlRates &rates[]','std::vector<MqlRates> &rates').replace('MqlRates &out[]','std::vector<MqlRates> &out').replace('CRFFeedUpdate &updates[]','std::vector<CRFFeedUpdate> &updates').replace('MqlRates prefix[];','std::vector<MqlRates> prefix;').replace('MqlRates rates[];','std::vector<MqlRates> rates;').replace('MqlRates probe[];','std::vector<MqlRates> probe;').replace('CRFFeedUpdate staged[];','std::vector<CRFFeedUpdate> staged;').replace('MqlRates g_crfBootRates[], g_crfBootPrefix[];','std::vector<MqlRates> g_crfBootRates, g_crfBootPrefix;').replace('MqlRates g_crfCacheRates[];','std::vector<MqlRates> g_crfCacheRates;')
  (p/name).write_text(text)
 (p/'test.cpp').write_text(base+extra+main)
 flags=['-fsanitize=undefined','-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
 subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-Wno-misleading-indentation',*flags,'-I',tmp,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test'),str(p/'forecast.bin')],check=True)
