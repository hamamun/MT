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
struct MqlTick {double bid=100,ask=100.02;datetime time=1001;};
MqlTick current{}; datetime closed[3]={1000,1000,1000}, opened[3]={1001,1001,1001};
datetime iTime(string,int tf,int shift){int i=tf==5?0:tf==15?1:2;return shift?closed[i]:opened[i];}
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
bool SymbolInfoTick(string,MqlTick &q){q=current;return true;}
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
 vector<int> scores(1000,2),gts(1000,1),cts(1000,1),status(1000,1);
 P3Reset();P3ResetSnapshots();P3Remember(0,1,1,1,2,"MIXED",1000,feed,scores,gts,cts,status);
 P3Plan p{};check(!P3MakePlan(0,p)&&p.signal==1,"no plan until observed tick");
 current.time=1000;P3CaptureQuotes();P3FreezePlans();check(!P3MakePlan(0,p),"pre-close quote is not captured");
 current.time=1001;P3CaptureQuotes();P3FreezePlans();check(P3MakePlan(0,p) && p.valid && p.signal==1 && !p.market,"buy limit snapshot");
 check(p.entry<100.02 && p.stop<p.entry && p.target>p.entry && p.slMoney<0 && p.tpMoney>0,"buy plan ordering");
 check(P3PlanLine(0).find("BUY")!=string::npos && P3PlanLine(0).find("USD")!=string::npos,"buy display");
 P3Plan frozen=p;current.bid=104;current.ask=104.2;P3CaptureQuotes();P3FreezePlans();P3MakePlan(0,p);
 check(p.entry==frozen.entry && p.stop==frozen.stop && p.target==frozen.target && p.lot==frozen.lot,"prices and lot frozen mid bar");
 check(P3LotText(0.05)=="0.05" && P3LotText(1.0)=="1" && P3LotText(0.000001)=="0.000001","lot display precision");
 // A new M5 bar cannot use the old snapshot; other lanes keep theirs.
 P3Remember(2,1,-1,2,-3,"MIXED",1000,feed,scores,gts,cts,status);P3FreezePlans();
 P3Plan other{};check(P3MakePlan(2,other) && other.market && other.entry==100,"sell market frozen first quote");
 closed[0]=1001;opened[0]=1002;current.time=1002;feed.push_back({1001,100,101,99,100,2});
 P3MakePlan(0,p);check(p.signal==P3_WAIT && !p.valid,"old bar held before refresh");
 P3CaptureQuotes();P3Remember(0,1,1,1,2,"MIXED",1001,feed,scores,gts,cts,status);P3FreezePlans();
 check(P3MakePlan(0,p) && p.entry!=frozen.entry,"new M5 snapshot updates");P3MakePlan(2,p);check(p.entry==other.entry && p.stop==other.stop,"M30 unaffected by M5 close");
 // Same bar retry with revised data cannot silently reinterpret frozen plan.
 P3Remember(0,1,1,1,-3,"MIXED",1001,feed,scores,gts,cts,status);P3FreezePlans();
 check(!P3MakePlan(0,p) && p.signal==-1 && !p.priced,"changed signal holds mismatched snapshot");
 P3Invalidate(0);P3MakePlan(0,p);check(p.signal==P3_WAIT,"missing readings held");
 // Capture original quote even if history and sizing recover on a later tick.
 closed[1]=1001;opened[1]=1002;P3CaptureQuotes();current.bid=105;current.ask=105.2;
 P3Remember(1,1,1,1,3,"MIXED",1001,feed,scores,gts,cts,status);P3FreezePlans();
 check(P3MakePlan(1,p) && p.entry==104.2,"late history uses captured quote");
 closed[1]=1002;opened[1]=1003;current.time=1003;P3CaptureQuotes();
 feed.push_back({1002,100,101,99,100,2});calcFail=true;
 P3Remember(1,1,1,1,3,"MIXED",1002,feed,scores,gts,cts,status);P3FreezePlans();
 check(!P3MakePlan(1,p) && p.priced && !p.valid,"sizing failure keeps price snapshot");
 calcFail=false;current.ask=106;P3FreezePlans();P3MakePlan(1,p);check(!p.valid && p.entry==105.2,"sizing failure frozen until next bar");
 if(!f)cout<<"Phase 3 plan-runtime stub checks passed\n";
 return f?1:0;}

'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+s+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
