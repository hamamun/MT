#!/usr/bin/env python3
"""Exercise isolated CRF closed-bar primitives with C++ stubs, not MT5."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = r'''
#include <cmath>
#include <limits>
#include <iostream>
#include <vector>
#include <algorithm>
#define EMPTY_VALUE std::numeric_limits<double>::max()
bool MathIsValidNumber(double x) { return std::isfinite(x); }
double MathAbs(double x) { return std::abs(x); }
template<class T,class U> double MathMax(T x,U y){return std::max(double(x),double(y));}
template<class T,class U> double MathMin(T x,U y){return std::min(double(x),double(y));}
struct MqlRates { double open,high,low,close; long long tick_volume; };
template<class T> int ArraySize(const std::vector<T>& x){return int(x.size());}
#include "crf_cpp.hpp"
int main() {
  int f=0;
  auto check=[&](bool v,const char *s){ if(!v){std::cerr<<"FAIL "<<s<<"\n"; ++f;} };
  int age=0;
  check(CRFAdvanceConfirmation(1,100,100,age)==CRF_CONFIRM_WAIT && age==1,"buy strict equality waits");
  check(CRFAdvanceConfirmation(1,100,101,age)==CRF_CONFIRM_BUY && age==2,"buy second bar confirms");
  age=0;
  check(CRFAdvanceConfirmation(-1,100,99,age)==CRF_CONFIRM_SELL && age==1,"sell direction preserved");
  age=0;
  check(CRFAdvanceConfirmation(-1,100,100,age)==CRF_CONFIRM_WAIT,"sell equality waits");
  check(CRFAdvanceConfirmation(-1,100,101,age)==CRF_CONFIRM_EXPIRED,"second nonbreak expires");
  age=0;
  check(CRFAdvanceConfirmation(0,100,101,age)==CRF_CONFIRM_INVALID && age==0,"invalid direction");
  check(CRFAdvanceConfirmation(1,EMPTY_VALUE,101,age)==CRF_CONFIRM_INVALID && age==0,"empty level");
  check(CRFAdvanceConfirmation(1,100,std::numeric_limits<double>::quiet_NaN(),age)==CRF_CONFIRM_INVALID && age==0,"nan close");
  check(CRFBarResult(1,95,105,106,94,1)==2,"buy stop wins tie");
  check(CRFBarResult(-1,105,95,106,94,1)==2,"sell stop wins tie");
  check(CRFBarResult(1,95,105,105,99,0)==1,"target before expiry");
  check(CRFBarResult(-1,105,95,101,96,0)==4,"expiry no touch");
  check(CRFBarResult(1,95,105,101,99,1)==0,"active");
  check(CRFBarResult(1,105,95,101,99,1)==-1,"invalid geometry");
  check(CRFBarResult(1,95,105,98,99,1)==-1,"invalid candle");
  std::vector<MqlRates> bars;
  for(int j=0;j<25;j++){double c=130-j;bars.push_back({c+0.6,c+0.8,c-0.2,c,100});}
  bars[24]={106,108,105.8,107.8,200};
  CRFCandidate candidate{};
  check(CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==1 && candidate.variant==11,"bull engulf with downtrend");
  check(candidate.break_level==108 && candidate.stop<105.8 && candidate.volume==2,"candidate features");
  check(!CRFDetectAt(bars,2,4,4,4,4,candidate) && candidate.direction==0,"short history rejected");
  for(int j=0;j<25;j++){double c=100+j;bars[j]={c-0.6,c+0.2,c-0.8,c,100};}
  bars[24]={124,124.2,122,122.2,100};
  check(CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==-1 && candidate.variant==12,"bear engulf with uptrend");
  bars[24]={124,125,123,124,100};
  check(CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==0,"doji alone is not directional");
  for(int j=0;j<25;j++){double c=130-j;bars[j]={c+0.6,c+0.8,c-0.2,c,100};}
  bars[24]={107.8,108.2,105.9,108.1,100};
  check(CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==1 && candidate.variant==21,"hammer at downtrend swing");
  bars[24]={106.2,108.4,106.1,106.5,100};
  check(CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==1 && candidate.variant==22,"inverted hammer at downtrend swing");
  bars[22]={110,110.2,107.8,108,100};
  bars[23]={107.9,108.1,107.5,107.9,100};
  bars[24]={108,109.7,107.9,109.5,100};
  check(CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==1 && candidate.variant==33 && candidate.marker==107.5,"morning doji star");
  for(auto &bar:bars){double o=bar.open,h=bar.high,l=bar.low,c=bar.close; bar.open=240-o;bar.high=240-l;bar.low=240-h;bar.close=240-c;}
  check(CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==-1 && candidate.variant==34 && candidate.marker==132.5,"evening doji star");
  for(auto &bar:bars)bar={100,100,100,100,100};
  check(CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==0,"flat zero ATR is valid with no candidate");
  bars[24].high=std::numeric_limits<double>::quiet_NaN();
  check(!CRFDetectAt(bars,24,4,4,4,4,candidate) && candidate.direction==0,"invalid candle rejected");
  if(!f) std::cout<<"CRF primitive tests passed\n";
  return f?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
    cpp = Path(tmp) / 'test.cpp'
    exe = Path(tmp) / 'test'
    cpp.write_text(source)
    kernel = (root / 'MT_CRF_Kernels.mqh').read_text().replace('const MqlRates &bars[]', 'const std::vector<MqlRates> &bars')
    (Path(tmp) / 'crf_cpp.hpp').write_text(kernel)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(Path(tmp)),str(cpp),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
