#!/usr/bin/env python3
"""Compile the real plan runtime via C++ stubs; does not execute MT5 APIs."""
from pathlib import Path
import re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'MT_Plan.mqh').read_text().replace('#include "MT_Phase3.mqh"','')+'\n'+(root/'MT_PlanRuntime.mqh').read_text().replace('#include "MT_Plan.mqh"','')
s=re.sub(r'const (MqlRates|int) &(\w+)\[\]',r'const vector<\1> &\2',s)
s=re.sub(r'\bdouble (\w+)\[\];',r'vector<double> \1;',s)
s=re.sub(r'\bMqlRates (\w+)\[\];',r'vector<MqlRates> \1;',s)
s=re.sub(r'^input ', '', s,flags=re.M)
stubs=r'''
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <sstream>
#include <iostream>
#include <limits>
#include <string>
#include <vector>
using namespace std;
#define EMPTY_VALUE numeric_limits<double>::max()
using datetime=long long; using ENUM_TIMEFRAMES=int; using ENUM_ORDER_TYPE=int;
#define PERIOD_M5 5
#define PERIOD_M15 15
#define PERIOD_M30 30
#define ORDER_TYPE_BUY 1
#define ORDER_TYPE_SELL -1
#define SYMBOL_TRADE_TICK_SIZE 1
#define SYMBOL_POINT 2
#define SYMBOL_VOLUME_MIN 3
#define SYMBOL_VOLUME_MAX 4
#define SYMBOL_VOLUME_STEP 5
#define SYMBOL_TRADE_STOPS_LEVEL 6
#define SYMBOL_DIGITS 7
#define SYMBOL_CHART_MODE 11
#define SYMBOL_CHART_MODE_BID 0
#define ACCOUNT_EQUITY 8
#define ACCOUNT_BALANCE 9
#define ACCOUNT_CURRENCY 10
#define MARKET_OPEN 0
int g_marketState=0;
string _Symbol="TEST";
struct MqlRates {datetime time=0; double open=0,high=0,low=0,close=0; int spread=0;};
struct MqlTick {double bid=100,ask=100.02;};
vector<MqlRates> feed;
bool MathIsValidNumber(double x){return isfinite(x);}
double MathFloor(double x){return floor(x);} double MathCeil(double x){return ceil(x);}
double MathAbs(double x){return abs(x);}
template<class T,class U> double MathMax(T a,U b){return max(double(a),double(b));}
template<class T,class U> double MathMin(T a,U b){return min(double(a),double(b));}
template<class T> int ArraySize(const vector<T>& x){return int(x.size());}
template<class T> int ArrayResize(vector<T>& x,int n){x.resize(n);return n;}
template<class T> void ArraySort(vector<T>& x){sort(x.begin(),x.end());}
template<class T> void ArraySetAsSeries(vector<T>&,bool){}
bool SymbolInfoTick(string,MqlTick &q){q=MqlTick{};return true;}
double SymbolInfoDouble(string,int prop){if(prop==SYMBOL_VOLUME_MIN || prop==SYMBOL_VOLUME_STEP)return 0.01;if(prop==SYMBOL_VOLUME_MAX)return 100;return 0.01;}
long SymbolInfoInteger(string,int prop){return prop==SYMBOL_DIGITS?2:5;}
long chartMode=SYMBOL_CHART_MODE_BID;bool modeAvailable=true;
bool SymbolInfoInteger(string,int prop,long &out){if(prop!=SYMBOL_CHART_MODE || !modeAvailable)return false;out=chartMode;return true;}
double AccountInfoDouble(int){return 10000;}
string AccountInfoString(int){return "USD";}
int CopyRates(string,int,int,int count,vector<MqlRates>& out){int n=min(count,int(feed.size()));out.assign(feed.end()-n,feed.end());return n;}
bool calcFail=false;
bool OrderCalcProfit(int dir,string,double lot,double entry,double exit,double &p){if(calcFail)return false;p=dir*lot*(exit-entry)*1000;return true;}
int StringLen(string s){return int(s.size());}
string StringSubstr(string s,int a,int n){return s.substr(a,n);}
string DoubleToString(double n,int digits){ostringstream o;o<<fixed<<setprecision(digits)<<n;return o.str();}
#include "MT_Phase3.mqh"
'''
main=r'''
int main(){int f=0;auto check=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';f++;}};
 for(int i=0;i<1000;i++){double p=100+sin(i*0.3)*0.3;feed.push_back({i+1,p,p+0.8,p-0.8,p+0.1,2});}
 vector<int> scores(1000,2),gts(1000,1),cts(1000,1),status(1000,1); P3Reset(); P3Remember(0,1,1,1,2,"MIXED",1000,feed,scores,gts,cts,status);
 P3Plan p{};check(P3MakePlan(0,p) && p.valid && p.signal==1 && !p.market,"buy limit plan");
 check(p.entry<100.02 && p.stop<p.entry && p.target>p.entry && p.slMoney<0 && p.tpMoney>0,"buy plan ordering");
 check(P3PlanLine(0).find("BUY")!=string::npos && P3PlanLine(0).find("USD")!=string::npos,"buy display");
 check(P3LotText(0.05)=="0.05" && P3LotText(1.0)=="1" && P3LotText(0.000001)=="0.000001","lot display precision");
 InpMinimumLot=true;check(P3MakePlan(0,p)&&abs(p.lot-0.01)<1e-9,"minimum input");InpMinimumLot=false;
 calcFail=true;P3MakePlan(0,p);check(p.priced && !p.valid && p.entry>0 && p.target>0 && P3PlanLine(0).find("Lot: --")!=string::npos,"sizing failure preserves entry and target");InpBypassRisk=true;P3MakePlan(0,p);check(p.priced && !p.valid && p.lot>0 && P3PlanLine(0).find("Lot: --")==string::npos,"bypass still sizes when profit calculation fails");InpBypassRisk=false;calcFail=false;
 P3Remember(2,1,-1,2,-3,"MIXED",1000,feed,scores,gts,cts,status);
 check(P3MakePlan(2,p)&&p.signal==-1&&p.market && p.stop>p.entry && p.target<p.entry,"countertrend sell market");
 InpAgainstM30=false;P3MakePlan(2,p);check(p.signal==0,"countertrend switch false");
 g_marketState=1;P3MakePlan(0,p);check(p.signal==1 && !p.valid,"closed market keeps signal but no entry");
 g_marketState=0;chartMode=1;P3Remember(0,1,1,1,2,"MIXED",1000,feed,scores,gts,cts,status);
 check(g_p3[0].samples==0 && g_p3[0].targetR==0 && P3PlanLine(0).find("Last/unknown proxy")!=string::npos,"Last bars use labelled fallback, not Bid replay");
 modeAvailable=false;P3Remember(0,1,1,1,2,"MIXED",1000,feed,scores,gts,cts,status);
 check(g_p3[0].samples==0 && P3PlanLine(0).find("Last/unknown proxy")!=string::npos,"unknown chart mode uses labelled fallback");
 P3Invalidate(0);P3MakePlan(0,p);check(p.signal==99,"missing readings");
 if(!f)cout<<"Phase 3 plan-runtime stub checks passed\n";
 return f?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+s+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
