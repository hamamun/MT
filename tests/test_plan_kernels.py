#!/usr/bin/env python3
"""C++ translation tests for the actual closed-bar plan kernels; not MT5."""
from pathlib import Path
import re, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
s = (root/'MT_Plan.mqh').read_text().replace('#include "MT_Phase3.mqh"','')
s = re.sub(r'const (MqlRates|int) &(\w+)\[\]',r'const vector<\1> &\2',s)
s = re.sub(r'\bdouble (\w+)\[\];',r'vector<double> \1;',s)
stubs = r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <vector>
using namespace std;
#define EMPTY_VALUE numeric_limits<double>::max()
struct MqlRates { long time=0; double open=0,high=0,low=0,close=0; int spread=0; };
bool MathIsValidNumber(double x){return isfinite(x);}
double MathFloor(double x){return floor(x);} double MathCeil(double x){return ceil(x);}
double MathAbs(double x){return abs(x);}
template<class T, class U> double MathMax(T a,U b){return max(double(a),double(b));}
template<class T, class U> double MathMin(T a,U b){return min(double(a),double(b));}
template<class T> int ArraySize(const vector<T>& x){return int(x.size());}
template<class T> int ArrayResize(vector<T>& x,int n){x.resize(n);return n;}
template<class T> void ArraySort(vector<T>& x){sort(x.begin(),x.end());}
#include "MT_Phase3.mqh"
'''
main=r'''
int main(){int fails=0;auto check=[&](bool v,const char*s){if(!v){cerr<<"FAIL "<<s<<'\n';fails++;}};
 vector<MqlRates> bars(1000); vector<int> scores(1000,3), gts(1000,1), cts(1000,1), status(1000,1);
 for(int i=0;i<1000;i++){
   double base=100+0.02*i+sin(i*0.37)*0.5;
   bars[i]={i+1,base,base+0.8,base-0.8,base+0.05,2};
 }
 P3Geometry g{};
 check(P3GeometryAt(bars,999,0,1,true,120.0,120.02,0.01,0.05,g),"market buy geometry");
 check(g.entry==120.02 && g.stop<g.entry && g.stop<=119.95,"market buy stop side/distance");
 check(P3GeometryAt(bars,999,1,-1,false,120.0,120.02,0.01,0.05,g),"limit sell geometry");
 check(g.entry>=120.05-1e-8 && g.stop>g.entry,"limit sell ordering");
 for(auto &b:bars){b.open=100;b.high=101;b.low=99;b.close=100;}
 check(P3GeometryAt(bars,999,0,1,false,100,100.02,0.01,0.05,g),"no swing buy fallback");
 check(g.entry<=99.97+1e-8 && g.stop<g.entry,"buy fallback ordering");
 check(P3GeometryAt(bars,999,0,-1,false,100,100.02,0.01,0.05,g),"no swing sell fallback");
 check(g.entry>=100.05-1e-8 && g.stop>g.entry,"sell fallback ordering");
 bars[999].high=0;check(!P3GeometryAt(bars,999,0,1,true,100,100.02,0.01,0.05,g),"invalid bar rejected");bars[999].high=101;
 int count1=0,count2=0;double r1=P3ObservedTargetR(bars,scores,gts,cts,status,900,0,3,P3_AUTO,true,0.01,0.01,0.05,0.02,count1);
 for(int i=900;i<1000;i++){bars[i].high=100000; scores[i]=-3;}
 double r2=P3ObservedTargetR(bars,scores,gts,cts,status,900,0,3,P3_AUTO,true,0.01,0.01,0.05,0.02,count2);
 check(count1>0 && count1==count2 && r1==r2,"historical replay cannot see future outside window");
 check(isfinite(r1) && r1>=0,"historical result finite");
 fill(cts.begin(),cts.end(),-1); int rejected=0;
 P3ObservedTargetR(bars,scores,gts,cts,status,900,0,3,P3_AUTO,false,0.01,0.01,0.05,0.02,rejected);
 check(rejected==0,"historical strict-trend filter honored");
 if(!fails)cout<<"Phase 3 plan-kernel checks passed\n";
 return fails?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+s+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
