#!/usr/bin/env python3
"""Closed-bar feed batching and recovery; test uses C++ stubs, not MT5."""
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
#define EMPTY_VALUE std::numeric_limits<double>::max()
bool MathIsValidNumber(double x){return std::isfinite(x);}
double MathAbs(double x){return std::abs(x);}
double MathSqrt(double x){return std::sqrt(x);}
template<class T,class U> double MathMax(T x,U y){return std::max(double(x),double(y));}
template<class T,class U> double MathMin(T x,U y){return std::min(double(x),double(y));}
template<class T> void ZeroMemory(T &x){std::memset(&x,0,sizeof(x));}
struct MqlRates { long time; double open,high,low,close; long long tick_volume; };
template<class T> int ArraySize(const std::vector<T>& x){return int(x.size());}
template<class T> int ArrayResize(std::vector<T>& x,int n,int reserve=0){(void)reserve;x.resize(n);return n;}
template<class T> int ArrayCopy(std::vector<T>& a,const std::vector<T>& b,int dst,int src,int n){
 if(src<0||dst<0||src+n>int(b.size())||dst+n>int(a.size()))return -1;
 std::copy(b.begin()+src,b.begin()+src+n,a.begin()+dst);return n;
}
#include "MT_CRF_Feed.mqh"
int main(){
 int failures=0;auto check=[&](bool ok,const char *s){if(!ok){std::cerr<<"FAIL "<<s<<"\n";failures++;}};
 CRFParameters p{300,4,2,5,2,3,2,55,1.2};
 std::vector<MqlRates> bars;
 for(int cycle=0;cycle<20;cycle++){
  for(int j=0;j<5;j++){double c=130-j;bars.push_back({long(bars.size()+1),c+0.6,c+0.8,c-0.2,c,100});}
  bars.push_back({long(bars.size()+1),125,127,124.8,126.8,100});
  bars.push_back({long(bars.size()+1),127,128,126.5,127.5,100});
  bars.push_back({long(bars.size()+1),127.5,129,127,128,100});
  bars.push_back({long(bars.size()+1),128,130,127.5,129,100});
  bars.push_back({long(bars.size()+1),129,131,128.5,130,100});
 }
 CRFForecastState s{};CRFResetForecast(s);std::vector<CRFFeedUpdate> u;
 auto part=std::vector<MqlRates>(bars.begin(),bars.begin()+150);
 check(CRFProcessClosedBars(part,150,p,true,s,u)==CRF_FEED_OK && u.size()==1 && u[0].bootstrap && s.last_bar==150,"bootstrap reconstruction, not actionable");
 auto before=s;
 CRFForecastState uninitialized{};CRFResetForecast(uninitialized);
 check(CRFProcessClosedBars(part,150,p,false,uninitialized,u)==CRF_FEED_INSUFFICIENT && uninitialized.last_bar==0,"bootstrap needs verified first bar");
 check(CRFProcessClosedBars(part,150,p,false,s,u)==CRF_FEED_INSUFFICIENT && s.last_bar==150,"truncated incremental history rejected");
 check(CRFProcessClosedBars(part,151,p,true,s,u)==CRF_FEED_STALE && s.last_bar==before.last_bar && u.empty(),"partial/stale copy rejected atomically");
 check(CRFProcessClosedBars(part,150,p,true,s,u)==CRF_FEED_OK && u.empty(),"duplicate bar has no event");
 part.assign(bars.begin(),bars.begin()+160);
 check(CRFProcessClosedBars(part,160,p,true,s,u)==CRF_FEED_OK && u.size()==10 && !u[0].bootstrap && u[0].bar==151 && u[9].bar==160 && s.last_bar==160,"each missed bar surfaced in order");
 CRFForecastState direct{};CRFResetForecast(direct);
 std::vector<CRFFeedUpdate> bootstrap;
 check(CRFProcessClosedBars(part,160,p,true,direct,bootstrap)==CRF_FEED_OK && direct.remaining==s.remaining && direct.last_event==s.last_event && direct.last_signal.direction==s.last_signal.direction && direct.last_estimate.target==s.last_estimate.target,"catch-up equals full replay");
 auto missing=std::vector<MqlRates>(bars.begin()+170,bars.end());before=s;
 check(CRFProcessClosedBars(missing,200,p,true,s,u)==CRF_FEED_ANCHOR_MISSING && s.last_bar==before.last_bar && u.empty(),"missing persisted anchor fails closed");
 part=bars;part[175].time=part[174].time;
 check(CRFProcessClosedBars(part,200,p,true,s,u)==CRF_FEED_BAD_SERIES && s.last_bar==before.last_bar && u.empty(),"duplicate times rejected");
 part=bars;part[170].high=std::numeric_limits<double>::quiet_NaN();
 check(CRFProcessClosedBars(part,200,p,true,s,u)==CRF_FEED_CALCULATION_FAILED && s.last_bar==before.last_bar && u.empty(),"bad catch-up bar leaves state unchanged");
 std::vector<MqlRates> shortbars(bars.begin(),bars.begin()+5);CRFResetForecast(s);
 check(CRFProcessClosedBars(shortbars,5,p,true,s,u)==CRF_FEED_INSUFFICIENT && s.last_bar==0,"warmup required");
 if(!failures)std::cout<<"CRF feed replay checks passed\n";
 return failures?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)
 for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh','MT_CRF_Feed.mqh'):
  text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars').replace('const MqlRates &rates[]','const std::vector<MqlRates> &rates').replace('CRFFeedUpdate &updates[]','std::vector<CRFFeedUpdate> &updates').replace('MqlRates prefix[];','std::vector<MqlRates> prefix;').replace('CRFFeedUpdate staged[];','std::vector<CRFFeedUpdate> staged;')
  (p/name).write_text(text)
 (p/'test.cpp').write_text(program)
 subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-I',tmp,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
