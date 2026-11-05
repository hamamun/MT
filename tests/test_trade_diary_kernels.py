#!/usr/bin/env python3
"""Exercise the broker-deal aggregation source via C++ stubs, not MT5."""
from pathlib import Path
import re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'MT_TradeDiary.mqh').read_text().replace('#include "MT_Phase3.mqh"','')
s=re.sub(r'const P5Deal &(\w+)\[\]',r'const vector<P5Deal> &\1',s)
stubs=r'''
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <vector>
using namespace std;
#define EMPTY_VALUE numeric_limits<double>::max()
bool MathIsValidNumber(double x){return isfinite(x);}
double MathMin(double a,double b){return min(a,b);}
double MathFloor(double x){return floor(x);} double MathAbs(double x){return abs(x);}
template<class T> int ArraySize(const vector<T>& x){return int(x.size());}
#include "MT_Phase3.mqh"
'''
main=r'''
int main(){int fails=0;auto ck=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';fails++;}};
 vector<P5Deal> d={{1,101,201,1,1000,0.1,100,0,-0.10,0,0},
                   {2,101,301,2,2000,0.04,102,0.08,-0.04,0,-0.01},
                   {3,101,302,2,3000,0.06,103,0.18,-0.06,-0.02,0}};
 P5TradeResult r{};
 ck(P5ClosedTrade(d,101,201,0.01,false,false,r),"complete position reconciles");
 ck(abs(r.entryVolume-0.1)<1e-12 && abs(r.exitVolume-0.1)<1e-12 && abs(r.exitPrice-102.6)<1e-12,"partial exits volume and weighted price");
 ck(abs(r.net-0.03)<1e-12 && r.outcome==1 && r.entryMs==1000 && r.exitMs==3000,"realized net including costs");
 ck(!P5ClosedTrade(d,101,201,0.01,true,false,r),"visible position is not closed");
 ck(!P5ClosedTrade(d,101,201,0.01,false,true,r),"entry remainder holds closure");
 auto saved=d;d.pop_back();ck(!P5ClosedTrade(d,101,201,0.01,false,false,r),"incomplete closure not a result");
 d=saved;d.push_back(d.back());ck(!P5ClosedTrade(d,101,201,0.01,false,false,r),"duplicate deal rejected");
 d=saved;d[0].order=999;ck(!P5ClosedTrade(d,101,201,0.01,false,false,r),"unmatched entry order rejected");
 d=saved;d[1].position=102;ck(!P5ClosedTrade(d,101,201,0.01,false,false,r),"wrong position rejected");
 d=saved;d[2].profit=numeric_limits<double>::quiet_NaN();ck(!P5ClosedTrade(d,101,201,0.01,false,false,r),"missing money rejected");
 d=saved;d[2].fee=EMPTY_VALUE;ck(!P5ClosedTrade(d,101,201,0.01,false,false,r),"missing fee sentinel rejected");
 d=saved;d[1].timeMs=1000;ck(!P5ClosedTrade(d,101,201,0.01,false,false,r),"ambiguous deal time held");
 d=saved;d[2].profit=-1;ck(P5ClosedTrade(d,101,201,0.01,false,false,r) && r.outcome==-1,"negative realized net is loss");
 if(!fails)cout<<"Broker-trade aggregation kernel checks passed\n";
 return fails?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+s+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
