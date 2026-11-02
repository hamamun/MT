#!/usr/bin/env python3
"""Run Phase 2's actual numerical and lane code with C++ MT5 stubs.
Not an MQL compiler or a MetaTrader runtime/integration test.
"""
import os, pathlib, re, subprocess, tempfile

source = (pathlib.Path(__file__).resolve().parents[1] / 'MT.mq5').read_text()
assert not re.search(r'\b(?:OrderSend|OrderSendAsync|CTrade|PositionOpen|PositionClose)\s*(?:\(|\w+)', source), 'Phase 2 must not place or manage orders'
engine = source[source.index('// Phase 2 numerical kernels'):]
# Translate MQL's dynamic-array spelling to vectors. Fixed arrays are unchanged.
engine = re.sub(r'\bconst (double|int|MqlRates) &(\w+)\[\]', r'const vector<\1> &\2', engine)
engine = re.sub(r'\b(double|int|MqlRates) &(\w+)\[\]', r'vector<\1> &\2', engine)
def arrays(m):
    typ, names = m.group(1), m.group(2)
    return '; '.join('vector<' + typ + '> ' + x.strip()[:-2] for x in names.split(',')) + ';'
engine = re.sub(r'\b(double|int|MqlRates)\s+((?:\w+\[\]\s*,\s*)*\w+\[\])\s*;', arrays, engine)

stubs = r'''
#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstdint>
#include <iostream>
#include <map>
#include <random>
#include <string>
#include <vector>
using namespace std;
using datetime=long long; using ulong=unsigned long; using uint=unsigned int;
#define EMPTY_VALUE 1.7976931348623157e+308
#define P2_WARMUP 700
#define P2_START_HISTORY 12000
#define P2_MIN_RUNS 20
#define P2_WAIT 99
#define ACCOUNT_SERVER 1
#define ACCOUNT_LOGIN 2
#define SYMBOL_TRADE_TICK_SIZE 3
#define SYMBOL_POINT 4
#define TERMINAL_MAXBARS 5
#define PERIOD_M5 5
#define PERIOD_M15 15
#define PERIOD_M30 30
using ENUM_TIMEFRAMES=int;
struct MqlRates {datetime time; double open,high,low,close;};
struct P2Countdown {bool loaded=false,valid=false;int label=0,age=0,remaining=0;datetime anchor=0;};
struct P2Lane {string line;datetime lastBar=0,attemptedBar=0;ulong lastAttempt=0;int requested=0,lastGoodRequest=0;bool retry=false;P2Countdown pt,score;};
P2Lane g_p2[3]; string _Symbol="TEST"; vector<MqlRates> feed; map<string,double> globals;
ulong ticks=100000; int copyCalls=0; int maxBars=100001, maxCopy=2147483647;
template<class T> int ArraySize(const vector<T>& v){return (int)v.size();}
template<class T> int ArrayResize(vector<T>& v,int n){v.resize(n);return n;}
template<class T> void ArrayInitialize(vector<T>& v,T x){fill(v.begin(),v.end(),x);}
template<class T,size_t N> void ArrayInitialize(T (&v)[N],T x){fill(v,v+N,x);}
template<class T> void ArraySort(vector<T>& v){sort(v.begin(),v.end());}
template<class T,size_t N> void ArraySort(T (&v)[N]){sort(v,v+N);}
template<class T> void ArraySetAsSeries(vector<T>&,bool){}
template<class T> T MathMax(T a,T b){return max(a,b);}
template<class T> T MathMin(T a,T b){return min(a,b);}
double MathAbs(double x){return abs(x);} double MathSqrt(double x){return sqrt(x);}
double MathLog(double x){return log(x);} double MathExp(double x){return exp(x);}
double MathCos(double x){return cos(x);} double MathRound(double x){return round(x);}
bool MathIsValidNumber(double x){return isfinite(x);}
string StringFormat(const char *fmt, ...){char b[1024];va_list a;va_start(a,fmt);vsnprintf(b,sizeof b,fmt,a);va_end(a);return b;}
int StringLen(string s){return (int)s.size();} unsigned short StringGetCharacter(string s,int i){return s.at(i);}
string IntegerToString(int x){return to_string(x);}
string AccountInfoString(int){return "Broker";} long long AccountInfoInteger(int){return 12345;}
bool GlobalVariableCheck(string s){return globals.count(s);}
double GlobalVariableGet(string s){return globals.at(s);}
datetime GlobalVariableSet(string s,double d){globals[s]=d;return 1;}
bool GlobalVariableDel(string s){return globals.erase(s)>0;}
double SymbolInfoDouble(string,int){return 0.01;}
long TerminalInfoInteger(int prop){return prop==TERMINAL_MAXBARS ? maxBars : 0;}
int CopyRates(string,int,int start,int count,vector<MqlRates>& out){copyCalls++;if(start+count>maxBars || count>maxCopy)return -1;int n=min(count,(int)feed.size());out.assign(feed.end()-n,feed.end());return n;}
datetime iTime(string,int,int){return feed.empty()?0:feed.back().time;}
ulong GetTickCount64(){return ticks;}
'''
# VS and gcc use %lld; MetaTrader uses %I64d.
engine = engine.replace('%I64d', '%lld')
main = r'''
bool ReferenceRemaining(const vector<int>& v,int last,int &age,int &remaining){
 int current=v[last];if(current==P2_WAIT)return false;
 int start=last;while(start>0 && v[start-1]==current)start--;
 if(start==0 || v[start-1]==P2_WAIT)return false;
 age=last-start+1;vector<int> sample;
 for(int k=0;k<start;){int begin=k;while(k<start && v[k]==v[begin])k++;
   int len=k-begin;
   if(begin>0 && v[begin]==current && v[begin-1]!=P2_WAIT && v[k]!=P2_WAIT && len>=age)sample.push_back(len-age);
 }
 if(sample.size()<20)return false;sort(sample.begin(),sample.end());int n=(int)sample.size();
 remaining=n%2?sample[n/2]:(int)round((sample[n/2-1]+sample[n/2])/2.0);return true;
}
int main(){int failures=0;auto check=[&](bool b,const char *n){if(!b){cerr<<"FAIL "<<n<<"\n";failures++;}};
 check(P2Status(1,1)==1 && P2Status(-1,-1)==-1 && P2Status(0,0)==0,"status equal");
 check(P2Status(1,-1)==2 && P2Status(-1,1)==2,"status conflict symmetric");
 check(P2Status(0,1)==3 && P2Status(-1,0)==3,"status mixed symmetric");
 check(P2Status(P2_WAIT,1)==P2_WAIT && P2Status(1,P2_WAIT)==P2_WAIT,"status missing");
 vector<double> up(2000),flat(2000,100); for(int i=0;i<2000;i++)up[i]=100+i;
 check(P2Global(up,100,0.01)==1,"global upward regression");
 for(int i=0;i<2000;i++)up[i]=2000-i;
 check(P2Global(up,100,0.01)==-1,"global downward regression");
 check(P2Global(flat,100,0.01)==0 && P2Global(flat,100,0)==P2_WAIT,"zero-change tick safeguard");
 check(P2Hurst(flat,1800,1536)==EMPTY_VALUE,"hurst degenerate is unavailable");
 check(P2Hurst(flat,100,1536)==EMPTY_VALUE,"hurst short history unavailable");
 vector<double> sc(21,100), hi(21,200), lo={105,104,103,102,100,102,103,104,105,104,103,102,99,102,103,104,105,106,107,108,109};
 sc[20]=101; check(P2StructureVote(sc,hi,lo,20,20,1)==0,"lower confirmed low invalidates bullish structure");
 lo[12]=101; check(P2StructureVote(sc,hi,lo,20,20,1)==1,"higher confirmed low allows bullish structure");
 sc[20]=100.25; check(P2StructureVote(sc,hi,lo,20,20,1)==0,"structure deadband inclusive");
 flat[1000]=0; check(P2Hurst(flat,1800,1536)==EMPTY_VALUE,"hurst invalid price unavailable");
 vector<int> labels; labels.push_back(0);
 for(int j=0;j<20;j++){labels.push_back(3);labels.push_back(0);} labels.push_back(3);
 int age=0,rem=-1;
 check(P2Remaining(labels,0,(int)labels.size()-1,age,rem) && age==1 && rem==0,"twenty zero residuals counted");
 labels.erase(labels.begin()+1,labels.begin()+3);
 check(!P2Remaining(labels,0,(int)labels.size()-1,age,rem),"nineteen runs insufficient");
 vector<int> incomplete(1,0);
 for(int j=0;j<20;j++){incomplete.push_back(3);incomplete.push_back(P2_WAIT);incomplete.push_back(0);} incomplete.push_back(3);
 check(!P2Remaining(incomplete,0,(int)incomplete.size()-1,age,rem),"runs ending in WAIT are not completed");
 mt19937 random(98173);vector<int> randomLabels(6000);
 for(int &v:randomLabels){unsigned x=random()%8;v=x==7?P2_WAIT:(int)(x%3)-1;}
 for(int end=100;end<(int)randomLabels.size();end+=13){int aa=0,rr=0,ab=0,rb=0;
   bool actual=P2Remaining(randomLabels,0,end,aa,rr), expected=ReferenceRemaining(randomLabels,end,ab,rb);
   check(actual==expected && (!actual || (aa==ab && rr==rb)),"run counting matches independent randomized oracle");
 }
 for(int trial=0;trial<8;trial++){vector<double> randomHp(4000);vector<int> cycleFast(4000);
   for(double &x:randomHp)x=(int)(random()%3)-1;P2Cycles(randomHp,cycleFast);
   for(int i=0;i<4000;i++)check(cycleFast[i]==P2ObservationCycleAt(randomHp,i),"randomized cycle median matches reference");
 }
 vector<int> longruns; longruns.push_back(0);
 for(int j=0;j<20;j++){for(int k=0;k<4;k++)longruns.push_back(3);longruns.push_back(0);}longruns.push_back(3);
 vector<MqlRates> rates(longruns.size());for(int i=0;i<(int)rates.size();i++)rates[i].time=1000+i;
 check(P2Remaining(longruns,0,(int)longruns.size()-1,age,rem) && age==1 && rem==3,"age conditioned median");
 vector<int> opposite=longruns; opposite.back()=-3;
 check(!P2Remaining(opposite,0,(int)opposite.size()-1,age,rem),"opposite signed scores never share runs");
 P2Countdown c; int end=(int)longruns.size()-1; globals.clear();
 check(P2CountdownText(0,true,c,longruns,rates,0,end)=="75%L","score life start");
 longruns.push_back(3);rates.push_back({1000+(long long)rates.size(),0,0,0,0});end++;
 check(P2CountdownText(0,true,c,longruns,rates,0,end)=="50%L","score life counts down");
 P2Countdown restored;
 check(P2CountdownText(0,true,restored,longruns,rates,0,end)=="50%L","restart restores verified countdown");
 vector<int> corrected=longruns; corrected[end-2]=3; P2Countdown changedHistory;
 check(P2CountdownText(0,true,changedHistory,corrected,rates,0,end)=="--%L","restart rejects a corrected anchor age");
 P2Save(0,true,c); // Restore the valid checkpoint for later restart checks.
 vector<int> oldScore(202,3);oldScore[0]=0; vector<MqlRates> oldBars(202);
 for(int i=0;i<202;i++)oldBars[i].time=100000+i;
 P2Countdown nearly;nearly.loaded=true;nearly.valid=true;nearly.label=3;nearly.age=201;nearly.remaining=1;nearly.anchor=oldBars.back().time;
 check(P2CountdownText(1,true,nearly,oldScore,oldBars,0,201)=="<1%L","positive remaining does not display zero percent");
 longruns.push_back(3);rates.push_back({1000+(long long)rates.size(),0,0,0,0});end++;
 check(P2CountdownText(0,true,c,longruns,rates,0,end)=="25%L","third score bar");
 longruns.push_back(3);rates.push_back({1000+(long long)rates.size(),0,0,0,0});end++;
 check(P2CountdownText(0,true,c,longruns,rates,0,end)=="~0%L","estimated end");
 longruns.push_back(3);rates.push_back({1000+(long long)rates.size(),0,0,0,0});end++;
 check(P2CountdownText(0,true,c,longruns,rates,0,end)=="past est.","past estimate shown");
 longruns.push_back(2);rates.push_back({1000+(long long)rates.size(),0,0,0,0});end++;
 check(P2CountdownText(0,true,c,longruns,rates,0,end)=="--%L","exact score change resets");
 longruns.push_back(3);rates.push_back({1000+(long long)rates.size(),0,0,0,0});end++;
 P2Countdown stale;
 check(P2CountdownText(0,true,stale,longruns,rates,0,end)=="75%L","return to same score is fresh run");
 P2Countdown p;globals.clear();
 check(P2CountdownText(0,false,p,longruns,rates,0,end)=="~3b","PT separate duration");
 for(int k=0;k<4;k++){longruns.push_back(3);rates.push_back({1000+(long long)rates.size(),0,0,0,0});end++;}
 check(P2CountdownText(0,false,p,longruns,rates,0,end)=="0b+","PT beyond estimate");
 // Full lane replay using non-constant synthetic price data.
 feed.clear(); globals.clear();
 for(int i=0;i<5000;i++){double price=100 + 0.002*i + 2*sin(i*0.13) + 0.4*sin(i*0.047);feed.push_back({10000+60LL*i,price,price+0.3,price-0.3,price});}
 P2Reset();P2Evaluate(0,PERIOD_M5,feed.back().time);
 check(g_p2[0].line.find("M5 | GT: ")==0,"full lane evaluated");
 check(g_p2[0].line.find("CT: WAIT")==string::npos && g_p2[0].line.find("SC: WAIT")==string::npos,"CT and score available");
 check(g_p2[0].line.find("RG: WAIT")==string::npos,"full own M5 Hurst history");
 check(g_p2[0].lastBar==feed.back().time,"latest closed bar recorded");
 vector<double> all; for(auto &r:feed) all.push_back(r.close); double hp[],*unused=nullptr; (void)unused;
 vector<double> hp40,hp1,hp2;P2HighPass3(all,40,hp40);
 vector<double> prefix(all.begin(),all.begin()+4000), hpPrefix;P2HighPass3(prefix,40,hpPrefix);
 check(abs(hpPrefix.back()-hp40[3999])<1e-12 && P2ObservationCycleAt(hpPrefix,3999)==P2ObservationCycleAt(hp40,3999),"future bars do not affect historical cycle");
 vector<int> fast(all.size());P2Cycles(hp40,fast);for(int i=0;i<(int)all.size();i++) check(fast[i]==P2ObservationCycleAt(hp40,i),"incremental adaptive cycle matches reference");int cycle=P2ObservationCycleAt(hp40,(int)all.size()-1);
 P2HighPass3(all,max(90,min(225,(int)round(cycle*6.25))),hp1);P2HighPass3(all,cycle,hp2);
 int dir=hp1.back()>hp2.back()?1:(hp1.back()<hp2.back()?-1:0);
 check(g_p2[0].line.find("CT: "+P2StateText(dir))!=string::npos,"current CT matches independently filtered latest cycle");
 feed.resize(600);P2Evaluate(1,PERIOD_M15,feed.back().time);
 check(g_p2[1].line.find("CT: WAIT")!=string::npos && g_p2[1].line.find("GT: WAIT")==string::npos && g_p2[1].line.find("RG: WAIT")==string::npos,"partial history keeps independently available GT and RG");
 P2Evaluate(0,PERIOD_M5,feed.back().time);
 check(g_p2[0].line.find("RG: WAIT")!=string::npos,"M5 does not borrow available M15 regime");
 maxBars=600;P2Reset();P2Evaluate(1,PERIOD_M15,feed.back().time);
 check(g_p2[1].line.find("GT: WAIT")==string::npos && g_p2[1].line.find("RG: WAIT")==string::npos,"terminal maximum does not prevent usable history");
 check(g_p2[1].requested<=maxBars-1,"history request respects terminal bar limit");
 maxBars=200001;
 check(P2HistoryLimit()==200000 && P2NextHistoryRequest(100000,P2HistoryLimit())==200000,"history can expand beyond 100000");
 check(P2NextHistoryRequest(150000,200000)==200000,"growth respects terminal maximum");
 check(P2NextHistoryRequest(1500000000,2147483646)==2147483646,"history growth does not overflow int");
 // A larger download can fail while a smaller range is already available.
 maxBars=1501;P2Reset();P2Evaluate(1,PERIOD_M15,feed.back().time);
 check(!g_p2[1].line.empty(),"initial smaller range usable");
 maxBars=100001;maxCopy=2000;P2Evaluate(1,PERIOD_M15,feed.back().time);
 check(!g_p2[1].line.empty() && g_p2[1].requested==12000,"failed deeper request retains usable readings and keeps retrying");
 maxCopy=2147483647;maxBars=1;P2Reset();
 maxBars=100001;P2Evaluate(1,PERIOD_M15,feed.back().time);
 check(!g_p2[1].line.empty() && g_p2[1].requested>=12000,"history requests recover after terminal bar limit becomes available");
 P2Evaluate(2,PERIOD_M30,feed.back().time+1);
 check(g_p2[2].line.empty(),"stale copied data never presented as latest");
 double goodClose=feed.back().close;feed.back().close=feed.back().high+1;
 P2Evaluate(1,PERIOD_M15,feed.back().time);
 check(g_p2[1].line.empty(),"invalid latest OHLC is unavailable");feed.back().close=goodClose;
 feed.back().close=EMPTY_VALUE;P2Evaluate(1,PERIOD_M15,feed.back().time);
 check(g_p2[1].line.empty(),"EMPTY_VALUE latest close is unavailable");feed.back().close=goodClose;
 P2Reset();copyCalls=0;ticks=100000;P2Update();int firstCalls=copyCalls;
 ticks+=1000;P2Update();check(copyCalls==firstCalls,"same-bar history retry is throttled");
 feed.push_back({feed.back().time+60,100,101,99,100});P2Update();
 check(copyCalls>firstCalls,"new closed bar updates without retry delay");
 if(failures) return 1;
 cout<<"Phase 2 indicator, history, countdown and lane checks passed.\n";
}
'''
main = main.replace('double hp[],*unused=nullptr; (void)unused;', '')
with tempfile.TemporaryDirectory() as tmp:
    path = pathlib.Path(tmp)
    (path / 'test.cpp').write_text(stubs + engine + main)
    flags = ['-fsanitize=address,undefined', '-fno-omit-frame-pointer'] if os.getenv('MT_TEST_SANITIZERS') else []
    subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation'] + flags + [str(path/'test.cpp'),'-o',str(path/'test')],check=True)
    subprocess.run([str(path/'test')],check=True)
