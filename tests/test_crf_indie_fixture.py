#!/usr/bin/env python3
"""Differential check against a Python-emulated Indie fixture, not native Indie."""
import json
import math
from pathlib import Path
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
fixture=json.loads((root/'tests/fixtures/crf_indie_emulated.json').read_text())
assert fixture['source_sha256']=='c9bee5bf0154a9eb49e9957a9c6879072ef5b187feabaadb7494c9bf19b4a1ee'
rows=',\n'.join('{%.17g,%.17g,%.17g,%.17g,%d}'%(r['o'],r['h'],r['l'],r['c'],r['v']) for r in fixture['rows'])
program=r'''
#include <cmath>
#include <limits>
#include <vector>
#include <algorithm>
#include <cstring>
#include <iostream>
#include <iomanip>
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
 std::vector<MqlRates> all={ROWS},bars;
 CRFParameters p{300,4,2,5,2,3,2,55,1.2};CRFForecastState s{};CRFResetForecast(s);
 std::cout<<std::setprecision(17);
 for(size_t i=0;i<all.size();i++){
   bars.push_back(all[i]);bool ok=CRFForecastOnBar(bars,(long)i+1,p,s);
   if(i+1<12)continue;
   if(!ok){std::cerr<<"forecast failure "<<i+1<<"\n";return 2;}
   std::cout<<i+1<<" "<<s.pending.direction<<" "<<s.pending_elapsed<<" "<<s.bull_cooldown<<" "<<s.bear_cooldown<<" "
     <<s.active_direction<<" "<<s.remaining<<" "<<s.last_result<<" "<<s.last_event<<" "
     <<s.last_signal.direction<<" "<<s.last_signal.pattern<<" "<<s.last_signal.variant<<" "
     <<s.last_entry<<" "<<s.last_signal.stop<<" "<<s.last_estimate.target<<" "<<s.last_estimate.confidence<<" "
     <<s.last_estimate.samples<<" "<<s.last_estimate.duration<<" "<<s.last_estimate.duration_low<<" "<<s.last_estimate.duration_high<<" "
     <<s.last_estimate.move_atr<<" "<<s.last_estimate.available<<" "<<s.last_estimate.reason<<"\n";
 }
}
'''.replace('ROWS',rows)
with tempfile.TemporaryDirectory() as tmp:
    p=Path(tmp)
    for name in ('MT_CRF_Kernels.mqh','MT_CRF_Analogs.mqh','MT_CRF_Forecast.mqh'):
        text=(root/name).read_text().replace('const MqlRates &bars[]','const std::vector<MqlRates> &bars')
        (p/name).write_text(text)
    (p/'test.cpp').write_text(program)
    subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-I',tmp,str(p/'test.cpp'),'-o',str(p/'test')],check=True)
    output=subprocess.check_output([str(p/'test')],text=True).splitlines()
assert len(output)==len(fixture['results'])
for line,(expected_n,expected) in zip(output,fixture['results']):
    nums=[float(v) for v in line.split()]
    assert nums[0]==expected_n
    for key,actual,want in zip(fixture['keys'],nums[1:],expected):
        if want is None:
            assert actual>1e300, (expected_n,key,actual,want)
        else:
            assert math.isclose(actual,want,rel_tol=1e-9,abs_tol=1e-8), (expected_n,key,actual,want)
print('CRF emulated Indie fixture comparison passed (not native Indie parity)')
