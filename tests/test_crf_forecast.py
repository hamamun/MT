#!/usr/bin/env python3
"""Closed-bar state machine tests with C++ stubs; broker state is separate."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
program = r'''
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
struct MqlRates { double open,high,low,close; long long tick_volume; };
template<class T> int ArraySize(const std::vector<T>& x){return int(x.size());}
#include "MT_CRF_Forecast.mqh"
int main(){
 int fails=0;auto check=[&](bool x,const char*s){if(!x){std::cerr<<"FAIL "<<s<<"\n";fails++;}};
 CRFParameters p{300,4,2,5,2,3,2,55,1.2};
 std::vector<MqlRates> bars;
 for(int cycle=0;cycle<40;cycle++){
   for(int j=0;j<5;j++){double c=130-j;bars.push_back({c+0.6,c+0.8,c-0.2,c,100});}
   bars.push_back({125,127,124.8,126.8,100});
   bars.push_back({127,128,126.5,127.5,100});
   bars.push_back({127.5,129,127,128,100});
   bars.push_back({128,130,127.5,129,100});
   bars.push_back({129,131,128.5,130,100});
 }
 CRFForecastState state{};CRFResetForecast(state);
 bars.resize(396);
 check(CRFForecastOnBar(bars,1,p,state) && state.pending.direction==1 && state.last_event==1,"candidate starts without immediate confirmation");
 check(CRFForecastOnBar(bars,1,p,state) && state.pending_elapsed==0,"duplicate bar ignored");
 bars.push_back({127,128,126.5,127.5,100});
 check(CRFForecastOnBar(bars,2,p,state) && state.pending.direction==0 && state.last_signal.direction==1 && state.last_estimate.available && state.active_direction==1,"next bar confirmation and analog estimate");
 int prior=state.remaining;
 check(CRFForecastOnBar(bars,2,p,state) && state.remaining==prior,"duplicate does not consume duration");
 bars.push_back({127.5,129,100,128,100});
 check(CRFForecastOnBar(bars,3,p,state) && state.last_result==2 && state.active_direction==0,"stop ends display forecast");
 // A seeded SELL candidate remains signed and expires only after two later closes.
 CRFResetForecast(state); state.pending.direction=-1; state.pending.break_level=99;
 state.pending.stop=102;state.pending.atr=1;state.pending.pattern=1;state.pending.volume=1;state.pending.trend=1;
 check(CRFForecastOnBar(bars,10,p,state) && state.pending.direction==-1 && state.pending_elapsed==1,"sell waiting first bar");
 check(CRFForecastOnBar(bars,11,p,state) && state.pending.direction==0 && state.last_event==3,"candidate expires second later bar");
 CRFResetForecast(state); state.pending.direction=-1; state.pending.break_level=129;
 state.pending.stop=131;state.pending.atr=1;state.pending.pattern=1;state.pending.volume=1;state.pending.trend=1;
 check(CRFForecastOnBar(bars,20,p,state) && state.last_signal.direction==-1 && state.pending.direction==0,"sell confirmation preserves sign");
 CRFResetForecast(state); state.active_direction=1;state.remaining=1;state.active_stop=95;state.active_target=105;
 bars.back()={100,102,99,101,100};
 check(CRFForecastOnBar(bars,30,p,state) && state.last_result==4 && state.active_direction==0,"hard duration expiry");
 CRFResetForecast(state);state.active_direction=1;state.remaining=1;state.active_stop=105;state.active_target=95;
 check(!CRFForecastOnBar(bars,31,p,state) && state.remaining==1 && state.last_bar==0,"invalid state does not partially advance");
 if(!fails)std::cout<<"CRF forecast state tests passed\n";
 return fails?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
    path=Path(tmp)
    for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh'):
        text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars')
        (path/name).write_text(text)
    (path/'test.cpp').write_text(program)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',tmp,str(path/'test.cpp'),'-o',str(path/'test')],check=True)
    subprocess.run([str(path/'test')],check=True)
