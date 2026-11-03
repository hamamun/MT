#!/usr/bin/env python3
"""Test the actual observed-price diary kernels, not MT5 integration."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
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
#include "MT_Diary.mqh"
int main(){
 int n=0; auto check=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';n++;}};
 P3Observation buy{};
 check(P3ObservationStart(buy,1,false,100,95,105,1000),"start buy limit");
 check(P3ObservationQuote(buy,1100,100,100.2) && buy.state==P3_PENDING,"buy limit uses ask");
 check(P3ObservationQuote(buy,1200,99.8,100) && buy.state==P3_OPEN && buy.entryMs==1200 && buy.entryQuote==100,"buy entry touched");
 check(P3ObservationQuote(buy,1300,104.9,105.1) && buy.state==P3_OPEN,"buy target uses bid");
 check(P3ObservationQuote(buy,1400,105,105.2) && buy.state==P3_TARGET && buy.resolutionMs==1400 && buy.exitQuote==105,"buy target observed");
 check(!P3ObservationQuote(buy,1500,94,94.1) && buy.state==P3_TARGET,"completed observation immutable");
 P3Observation sell{};
 check(P3ObservationStart(sell,-1,false,100,105,95,1000),"start sell limit");
 check(P3ObservationQuote(sell,1100,99.9,100.1) && sell.state==P3_PENDING,"sell entry uses bid");
 check(P3ObservationQuote(sell,1200,100,100.1) && sell.state==P3_OPEN,"sell entry touched");
 check(P3ObservationQuote(sell,1300,104.9,105) && sell.state==P3_STOP,"sell stop uses ask");
 P3Observation gap{};
 check(P3ObservationStart(gap,1,true,100,95,105,1000),"market observation starts open");
 P3ObservationGap(gap);
 check(gap.state==P3_UNKNOWN && !P3ObservationQuote(gap,2000,105,105.1),"unknown on unrecovered gap");
 P3Observation invalid{};
 check(!P3ObservationStart(invalid,1,true,100,101,105,1),"bad stop rejected");
 check(!P3ObservationStart(invalid,-1,false,100,105,106,1),"bad sell target rejected");
 P3Observation time{}; P3ObservationStart(time,1,false,100,95,105,1000);
 check(!P3ObservationQuote(time,999,99,100) && time.state==P3_PENDING,"pre-signal tick rejected");
 check(!P3ObservationQuote(time,1001,101,100) && time.state==P3_PENDING,"invalid quote rejected");
 check(P3ObservationQuote(time,1000,99,100) && time.state==P3_OPEN,"same timestamp allowed");
 P3ObservationCounts c{};
 P3CountObservation(buy,1300,2000,c); P3CountObservation(sell,1300,2000,c); P3CountObservation(gap,1300,2000,c);
 check(c.signalAll==3 && c.signalToday==0 && c.winAll==1 && c.lossAll==1 && c.winToday==1 && c.lossToday==1,"overnight counts and unknown excluded");
 if(!n) cout<<"Diary observation-kernel checks passed\n";
 return n?1:0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
    cpp = Path(tmp) / 'test.cpp'
    exe = Path(tmp) / 'test'
    cpp.write_text(stubs + main)
    subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-I', str(root), str(cpp), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
