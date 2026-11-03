#!/usr/bin/env python3
"""Compile and exercise the actual Phase 3 decision kernels as C++.
This is not MQL5 compilation, broker validation, or a strategy backtest.
"""
from pathlib import Path
import subprocess
import tempfile
import re

root = Path(__file__).resolve().parents[1]
source = (root / 'MT_Phase3.mqh').read_text()
for path in [root/'MT.mq5', *(root/name for name in ['MT_Phase3.mqh','MT_Plan.mqh','MT_PlanRuntime.mqh','MT_Diary.mqh','MT_DiaryRuntime.mqh'])]:
    assert not re.search(r'\b(?:OrderSend|OrderSendAsync|CTrade|PositionOpen|PositionClose)\s*(?:\(|\w+)', path.read_text()), f'{path.name} must not place or manage trades'
stubs = r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
using namespace std;
#define EMPTY_VALUE numeric_limits<double>::max()
bool MathIsValidNumber(double x) { return isfinite(x); }
double MathMin(double a, double b) { return min(a,b); }
double MathFloor(double x) { return floor(x); }
'''
main = r'''
int main() {
  int failed = 0;
  auto check = [&](bool v, const char *s) { if (!v) { cerr << "FAIL " << s << '\n'; failed++; } };
  auto near = [](double a, double b) { return abs(a-b) < 1e-9; };
  check(P3SelectedTrend(0,P3_AUTO,1,-1,2)==-1,"M5 auto CT");
  check(P3SelectedTrend(1,P3_AUTO,1,-1,2)==2,"M15 auto ST");
  check(P3SelectedTrend(2,P3_AUTO,1,-1,2)==1,"M30 auto GT");
  check(P3SelectedTrend(0,P3_FOLLOW_GT,1,-1,2)==1,"override GT");
  check(P3SelectedTrend(2,P3_FOLLOW_CT,1,-1,2)==-1,"override CT");
  check(P3SelectedTrend(0,P3_FOLLOW_ST,1,-1,3)==3,"override ST mixed");
  check(P3SelectedTrend(2,P3_AUTO,99,-1,99)==99,"unavailable selected trend");
  check(P3SelectedTrend(0,P3_AUTO,1,2,2)==99,"invalid CT status");
  check(P3SelectedTrend(3,P3_AUTO,1,1,1)==99,"invalid lane");
  for(int score=-3;score<=3;score++) for(int trend=-1;trend<=3;trend++) {
    int expected = score>=2 ? 1 : (score<=-2 ? -1 : 0);
    check(P3Signal(score,trend,true)==expected,"countertrend score decision");
    check(P3Signal(score,trend,false)==(expected==trend ? expected : 0),"strict trend decision");
  }
  check(P3Signal(2,99,true)==99 && P3Signal(99,1,true)==99,"missing is not neutral");
  check(P3Signal(4,1,true)==99 && P3Signal(2,-2,true)==99,"invalid readings");
  check(near(P3Volume(0.005,0.01,100,0.01),0.01),"automatic minimum");
  check(near(P3Volume(1.237,0.01,100,0.01),1.23),"round down");
  check(near(P3Volume(0.49,0.1,5,0.2),0.3),"non-decimal grid");
  check(near(P3Volume(100,0.1,0.95,0.2),0.9),"maximum on non-aligned grid");
  check(P3Volume(1,0,10,0.01)==0 && P3Volume(1,1,0.5,0.1)==0,"invalid volume properties");
  check(P3Volume(numeric_limits<double>::infinity(),0.01,10,0.01)==0,"invalid request");
  check(near(P3Lot(10000,10000,1000,2,false,false,0.01,100,0.01),0.05),"normal equity 0.5 percent");
  check(near(P3Lot(10000,10000,20000,-2,false,false,0.01,100,0.01),0.01),"minimum above risk budget");
  check(near(P3Lot(10000,10000,1000,2,true,false,0.01,100,0.01),0.10),"bypass score 2");
  check(near(P3Lot(10000,10000,1000,-3,true,false,0.01,100,0.01),0.15),"bypass score 3");
  check(near(P3Lot(10000,10000,1000,2,true,true,0.05,100,0.01),0.05),"force minimum bypass");
  check(near(P3Lot(10000,10000,1000,2,false,true,0.05,100,0.01),0.05),"force minimum normal");
  check(P3Lot(10000,10000,0,2,false,false,0.01,100,0.01)==0,"missing loss cannot size");
  check(P3Lot(10000,10000,1000,0,false,false,0.01,100,0.01)==0,"no directional signal");
  check(P3Lot(10000,10000,1000,0,false,true,0.01,100,0.01)==0,"forced minimum does not create signal");
  for(int i=1;i<=10000;i++) {
    double requested = 0.01 + i*0.00071;
    double vol = P3Volume(requested, 0.01, 3.0, 0.01);
    check(vol >= 0.01 && vol <= 3.0 && vol <= requested + 1e-10,"volume properties");
  }
  if(!failed) cout << "Phase 3 decision-kernel checks passed\n";
  return failed ? 1 : 0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
    cpp = Path(tmp) / 'test.cpp'
    exe = Path(tmp) / 'test'
    cpp.write_text(stubs + '\n' + source + '\n' + main)
    subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', str(cpp), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
