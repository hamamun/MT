#!/usr/bin/env python3
"""M15-only history loader with terminal API stubs; not native MT5."""
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
#define PERIOD_M15 15
#define SERIES_SYNCHRONIZED 1
#define SERIES_FIRSTDATE 2
using string=std::string;using datetime=long;
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
template<class T> bool ArraySetAsSeries(std::vector<T>&,bool flag){return !flag;}
std::vector<MqlRates> source;bool sync_ok=true,partial=false,changed=false;int bars_calls=0;
bool SeriesInfoInteger(const string&,int period,int property,long &v){if(period!=PERIOD_M15)return false;v=property==SERIES_SYNCHRONIZED?sync_ok:source.front().time;return true;}
int Bars(const string&,int period){if(period!=PERIOD_M15)return 0;bars_calls++;return int(source.size())+(changed && bars_calls>1?1:0);}
datetime iTime(const string&,int period,int shift){if(period!=PERIOD_M15 || shift<0 || shift>=int(source.size()))return 0;return source[source.size()-1-shift].time;}
int iBarShift(const string&,int period,datetime when,bool exact){if(period!=PERIOD_M15 || !exact)return -1;for(size_t i=0;i<source.size();i++)if(source[i].time==when)return int(source.size()-1-i);return -1;}
int CopyRates(const string&,int period,int start,int count,std::vector<MqlRates>& out){
 if(period!=PERIOD_M15 || start!=1 || count<0 || count>int(source.size())-1)return -1;
 if(partial)count--;
 out.assign(source.end()-1-count,source.end()-1);return count;
}
#include "MT_CRF_M15.mqh"
int main(){
 int fails=0;auto check=[&](bool x,const char*s){if(!x){std::cerr<<"FAIL "<<s<<"\n";fails++;}};
 for(int i=0;i<500;i++)source.push_back({long(1000+i*900),100,101,99,100,100});
 CRFParameters p{100,4,2,5,2,3,2,55,1.2};std::vector<MqlRates> out;bool first=false;long latest=0;
 check(CRFReadClosedM15("EURUSD",p,0,out,first,latest)==CRF_M15_OK && first && out.size()==499 && latest==source[498].time,"full closed M15 bootstrap");
 bars_calls=0;long anchor=source[480].time;
 check(CRFReadClosedM15("EURUSD",p,anchor,out,first,latest)==CRF_M15_OK && !first && out.size()<499 && out.back().time==source[498].time,"incremental bounded lookback");
 sync_ok=false;bars_calls=0;
 check(CRFReadClosedM15("EURUSD",p,anchor,out,first,latest)==CRF_M15_WAIT_HISTORY && out.empty(),"unsynchronized history held");sync_ok=true;
 partial=true;bars_calls=0;
 check(CRFReadClosedM15("EURUSD",p,anchor,out,first,latest)==CRF_M15_WAIT_HISTORY && out.empty(),"partial copy rejected");partial=false;
 changed=true;bars_calls=0;
 check(CRFReadClosedM15("EURUSD",p,anchor,out,first,latest)==CRF_M15_HISTORY_CHANGED && out.empty(),"history change rejected");changed=false;
 bars_calls=0;check(CRFReadClosedM15("EURUSD",p,123,out,first,latest)==CRF_M15_ANCHOR_MISSING,"missing anchor rejected");
 bars_calls=0;check(CRFReadClosedM15("EURUSD",p,source.back().time,out,first,latest)==CRF_M15_ANCHOR_MISSING,"forming bar cannot be anchor");
 source.resize(100002);bars_calls=0;
 for(size_t i=0;i<source.size();i++)source[i].time=long(1000+i*900);
 check(CRFReadClosedM15("EURUSD",p,0,out,first,latest)==CRF_M15_TOO_MUCH_HISTORY && out.empty(),"bootstrap cap never truncates silently");
 if(!fails)std::cout<<"CRF M15 loader checks passed\n";
 return fails?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)
 for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh','MT_CRF_Feed.mqh','MT_CRF_M15.mqh'):
  text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars').replace('const MqlRates &rates[]','const std::vector<MqlRates> &rates').replace('MqlRates &out[]','std::vector<MqlRates> &out').replace('CRFFeedUpdate &updates[]','std::vector<CRFFeedUpdate> &updates').replace('MqlRates prefix[];','std::vector<MqlRates> prefix;').replace('CRFFeedUpdate staged[];','std::vector<CRFFeedUpdate> staged;')
  (p/name).write_text(text)
 (p/'test.cpp').write_text(program)
 subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-I',tmp,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
