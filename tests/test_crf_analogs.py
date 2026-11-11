#!/usr/bin/env python3
"""Run source-derived CRF historical replay kernels with C++ stubs (not MT5)."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
program = r'''
#include <cmath>
#include <limits>
#include <vector>
#include <algorithm>
#include <iostream>
#define EMPTY_VALUE std::numeric_limits<double>::max()
bool MathIsValidNumber(double x){return std::isfinite(x);}
double MathAbs(double x){return std::abs(x);}
double MathSqrt(double x){return std::sqrt(x);}
template<class T,class U> double MathMax(T x,U y){return std::max(double(x),double(y));}
template<class T,class U> double MathMin(T x,U y){return std::min(double(x),double(y));}
struct MqlRates { double open,high,low,close; long long tick_volume; };
template<class T> int ArraySize(const std::vector<T>& x){return int(x.size());}
#include "MT_CRF_Analogs.mqh"
int main(){
 int fails=0; auto check=[&](bool x,const char *s){if(!x){std::cerr<<"FAIL "<<s<<"\n";fails++;}};
 CRFParameters p{100,4,2,5,2,3,2,55,1.2};
 check(CRFParametersValid(p),"valid inputs");
 CRFParameters bad=p; bad.horizon=3; check(!CRFParametersValid(bad),"invalid horizon");
 CRFCandidate s{}; s.direction=1; s.pattern=1; s.atr=1; s.stop=99; s.volume=1; s.trend=1; s.location=0;
 CRFCandidate h=s;
 check(CRFSimilarity(s,h)==4,"identical features");
 h.volume=1.5; h.trend=2.5; h.location=2; h.pattern=2;
 check(CRFSimilarity(s,h)==2,"similarity inclusive boundaries");
 h.volume=std::numeric_limits<double>::quiet_NaN(); check(CRFSimilarity(s,h)==1,"nonfinite similarity fails safe");
 std::vector<MqlRates> bars(20,{100,100.5,99.5,100,100});
 bars[11]={100,101.5,99.8,101,100}; // target reached
 bars[12]={101,103,98.8,101,100};   // later stop does not alter success; move continues
 bars[13]={100,102,99.5,100,100};
 bars[14]={100,102,99.5,100,100};
 CRFEpisode e{};
 check(CRFReplayEpisode(bars,10,s,100,p,e) && e.success && e.move==3 && e.duration==4,"target records success but episode continues");
 bars[11]={100,102,98.9,100,100}; // stop and target same bar
 check(CRFReplayEpisode(bars,10,s,100,p,e) && !e.success && e.move==3,"stop wins tie and excursion still observed");
 check(!CRFReplayEpisode(bars,17,s,100,p,e),"must have complete outcome horizon");
 bars[11].high=std::numeric_limits<double>::quiet_NaN();
 check(!CRFReplayEpisode(bars,10,s,100,p,e),"invalid path fails closed");
 std::vector<MqlRates> repeated;
 for(int cycle=0;cycle<40;cycle++){
   double base=130;
   for(int j=0;j<5;j++){double c=base-j;repeated.push_back({c+0.6,c+0.8,c-0.2,c,100});}
   repeated.push_back({125,127,124.8,126.8,100});
   repeated.push_back({127,128,126.5,127.5,100});
   repeated.push_back({127.5,129,127,128,100});
   repeated.push_back({128,130,127.5,129,100});
   repeated.push_back({129,131,128.5,130,100});
 }
 CRFCandidate signal{};
 check(CRFDetectAt(repeated,395,2,5,2,3,signal) && signal.direction==1,"repeated candidate");
 CRFEstimate estimate{}; p.history=300;
 check(CRFEstimateAt(repeated,signal,127.5,p,estimate),"estimate succeeds");
 check(estimate.samples>=2 && estimate.available && estimate.duration_high<=4,"spaced complete historical analogs");
 auto prior=estimate;
 // A distant bar outside the replay window cannot alter the estimate.
 repeated[0].high=9999;
 check(CRFEstimateAt(repeated,signal,127.5,p,estimate) && estimate.samples==prior.samples && estimate.target==prior.target,"excluded history cannot affect result");
 check(!CRFEstimateAt(repeated,signal,127.5,bad,estimate) && !estimate.available,"invalid params fail closed");
 if(!fails)std::cout<<"CRF analog replay tests passed\n";
 return fails?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp)
    for name in ('MT_CRF_Kernels.mqh', 'MT_CRF_Analogs.mqh'):
        text = (root / name).read_text().replace('const MqlRates &bars[]', 'const std::vector<MqlRates> &bars')
        (path / name).write_text(text)
    (path / 'test.cpp').write_text(program)
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',tmp,str(path/'test.cpp'),'-o',str(path/'test')],check=True)
    subprocess.run([str(path/'test')],check=True)
