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
using string=std::string;
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
static bool exists=false,fail_save=false,fail_history=false,corrupt=false;static int save_count=0;
static CRFForecastState durable;static std::vector<MqlRates> source;
CRF_JOURNAL_RESULT CRFLoadForecast(const string&,int,const CRFParameters&,CRFForecastState &s){if(corrupt)return CRF_JOURNAL_INVALID;if(!exists)return CRF_JOURNAL_MISSING;s=durable;return CRF_JOURNAL_OK;}
bool CRFSaveForecast(const string&,int,const CRFParameters&,const CRFForecastState &s){save_count++;if(fail_save)return false;durable=s;exists=true;return true;}
CRF_M15_RESULT CRFReadClosedM15(const string&,const CRFParameters&,long,std::vector<MqlRates> &out,bool &first,long &latest){if(fail_history)return CRF_M15_WAIT_HISTORY;out=source;first=true;latest=source.back().time;return CRF_M15_OK;}
#include "MT_CRF_Observer.mqh"
int main(){
 int failures=0;auto check=[&](bool x,const char *s){if(!x){std::cerr<<"FAIL "<<s<<"\n";failures++;}};
 for(int i=0;i<20;i++)source.push_back({i+1,100,101,99,100,100});
 CRFParameters p{100,4,2,5,2,3,2,55,1.2};CRFObserver observer{};std::vector<CRFFeedUpdate> u;
 check(CRFObserverInit(observer,"X","x",0,p,false)==CRF_OBSERVER_INVALID && !observer.ready,"lock required");
 check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_OK && observer.ready,"init empty");
 fail_history=true;check(CRFObserverPoll(observer,u)==CRF_OBSERVER_HISTORY_UNAVAILABLE && observer.forecast.last_bar==0 && u.empty(),"history failure no mutation");fail_history=false;
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_OK && u.size()==1 && u[0].bootstrap && durable.last_bar==20 && observer.forecast.last_bar==20,"bootstrap saved before exposure");
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_OK && u.empty() && save_count==1,"duplicates do not write");
 source.push_back({21,100,101,99,100,100});fail_save=true;
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_JOURNAL_ERROR && u.empty() && !observer.ready && observer.forecast.last_bar==20 && durable.last_bar==20,"failed save latches and hides events");
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_INVALID,"latched observer cannot continue");
 fail_save=false;check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_OK && observer.forecast.last_bar==20,"reload durable anchor");
 check(CRFObserverPoll(observer,u)==CRF_OBSERVER_OK && u.size()==1 && !u[0].bootstrap && u[0].bar==21 && durable.last_bar==21,"missed bar replayed after restart");
 corrupt=true;check(CRFObserverInit(observer,"X","x",0,p,true)==CRF_OBSERVER_JOURNAL_ERROR && !observer.ready,"corrupt state held");
 if(!failures)std::cout<<"CRF observer persistence checks passed\n";
 return failures?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)
 for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh','MT_CRF_Feed.mqh','MT_CRF_Observer.mqh'):
  text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars').replace('const MqlRates &rates[]','const std::vector<MqlRates> &rates').replace('CRFFeedUpdate &updates[]','std::vector<CRFFeedUpdate> &updates').replace('MqlRates prefix[];','std::vector<MqlRates> prefix;').replace('MqlRates rates[];','std::vector<MqlRates> rates;').replace('CRFFeedUpdate staged[];','std::vector<CRFFeedUpdate> staged;')
  (p/name).write_text(text)
 (p/'MT_CRF_M15.mqh').write_text('')
 (p/'MT_CRF_Journal.mqh').write_text('')
 (p/'test.cpp').write_text(program)
 subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-I',tmp,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
