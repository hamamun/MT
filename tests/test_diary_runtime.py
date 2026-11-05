#!/usr/bin/env python3
"""Compile the diary runtime against in-memory MT5-like file/tick stubs.
This is not a native MT5 integration or persistence test.
"""
from pathlib import Path
import re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'MT_DiaryRuntime.mqh').read_text().replace('#include "MT_Diary.mqh"','')
s=s.replace('(string)AccountInfoInteger(ACCOUNT_LOGIN)','to_string(AccountInfoInteger(ACCOUNT_LOGIN))')
s=s.replace('%I64u','%lu')
s=re.sub(r'\b(P3DiaryRow|MqlTick|int) (\w+)\[\];',r'vector<\1> \2;',s)
stubs=r'''
#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <sstream>
#include <string>
#include <vector>
using namespace std;
#define EMPTY_VALUE numeric_limits<double>::max()
using datetime=long long;
#define INVALID_HANDLE -1
#define FILE_READ 1
#define FILE_WRITE 2
#define FILE_BIN 4
#define FILE_COMMON 8
#define FILE_REWRITE 16
#define INT_VALUE 4
#define MQL_TESTER 1
#define ACCOUNT_SERVER 2
#define ACCOUNT_LOGIN 3
#define ACCOUNT_EQUITY 20
#define ACCOUNT_BALANCE 21
#define SYMBOL_DIGITS 4
#define COPY_TICKS_ALL 0
#define MARKET_OPEN 0
#define TERMINAL_CONNECTED 11
bool connected=true; long TerminalInfoInteger(int){return connected?1:0;}
int g_marketState=MARKET_OPEN;
string _Symbol="XAU";
bool InpBypassRisk=false,InpMinimumLot=false;
bool MathIsValidNumber(double x){return isfinite(x);}
double MathMin(double a,double b){return min(a,b);}
double MathFloor(double x){return floor(x);}
template<class T> int ArraySize(const vector<T>&x){return int(x.size());}
template<class T> int ArrayResize(vector<T>&x,int n){x.resize(n);return n;}
string AccountInfoString(int){return "broker";} long long AccountInfoInteger(int){return 42;}
double AccountInfoDouble(int){return 10000;}
int MQLInfoInteger(int){return 0;} long SymbolInfoInteger(string,int){return 2;}
int StringLen(string x){return int(x.size());} unsigned short StringGetCharacter(string x,int i){return x[i];}
string IntegerToString(int i){return to_string(i);}
string DoubleToString(double x,int n){ostringstream s;s<<fixed<<setprecision(n)<<x;return s.str();}
string StringFormat(const char *f,...){char b[1024];va_list a;va_start(a,f);vsnprintf(b,sizeof(b),f,a);va_end(a);return b;}
template<class T> void Print(T x){cerr<<x<<'\n';}
struct MqlDateTime{int year,mon,day,hour,min,sec;};
void TimeToStruct(datetime t,MqlDateTime& d){time_t x=t;tm *v=gmtime(&x);d={v->tm_year+1900,v->tm_mon+1,v->tm_mday,v->tm_hour,v->tm_min,v->tm_sec};}
datetime StructToTime(MqlDateTime d){tm x={};x.tm_year=d.year-1900;x.tm_mon=d.mon-1;x.tm_mday=d.day;x.tm_hour=d.hour;x.tm_min=d.min;x.tm_sec=d.sec;return timegm(&x);}
struct MqlTick{long time_msc; double bid,ask;};
vector<MqlTick> tickHistory; MqlTick current{}; bool tickError=false;
bool SymbolInfoTick(string,MqlTick &t){t=current;return true;}
int lastError=0;void ResetLastError(){lastError=0;} int GetLastError(){return lastError;}
int CopyTicksRange(string,vector<MqlTick>& out,int,unsigned long from,unsigned long to){out.clear();if(tickError){lastError=1;return -1;}for(auto t:tickHistory)if((unsigned long)t.time_msc>=from && (unsigned long)t.time_msc<=to)out.push_back(t);return int(out.size());}
bool ChartSupported(){return true;}
struct Handle{string name;size_t pos;}; map<int,Handle> handles; map<string,vector<char>> files; int nextHandle=1; bool diskFail=false;
int FileOpen(string name,int flags){if(diskFail)return -1;for(auto &p:handles)if(p.second.name==name)return -1;if(flags&FILE_WRITE){if(!(flags&FILE_READ))files[name].clear();else if(!files.count(name))files[name]={};}else if(!files.count(name))return -1;int h=nextHandle++;handles[h]={name,0};return h;}
void FileClose(int h){handles.erase(h);}
bool FileIsExist(string n,int){return files.count(n);}
bool FileMove(string a,int,string b,int){if(diskFail||!files.count(a))return false;files[b]=files[a];files.erase(a);return true;}
void FileFlush(int){} unsigned long FileSize(int h){return files[handles[h].name].size();} unsigned long FileTell(int h){return handles[h].pos;}
template<class T> void writeVal(int h,T value){auto &x=handles[h];auto &v=files[x.name];if(x.pos+sizeof(T)>v.size())v.resize(x.pos+sizeof(T));memcpy(&v[x.pos],&value,sizeof(T));x.pos+=sizeof(T);}
template<class T> T readVal(int h){auto &x=handles[h];auto &v=files[x.name];T a{};if(x.pos+sizeof(T)>v.size()){lastError=1;return a;}memcpy(&a,&v[x.pos],sizeof(T));x.pos+=sizeof(T);return a;}
void FileWriteInteger(int h,int x,int){writeVal<int>(h,x);} void FileWriteLong(int h,long x){writeVal<long>(h,x);} void FileWriteDouble(int h,double x){writeVal<double>(h,x);}
int FileReadInteger(int h,int){return readVal<int>(h);} long FileReadLong(int h){return readVal<long>(h);} double FileReadDouble(int h){return readVal<double>(h);}
#include "MT_Diary.mqh"
struct P3Plan{int signal=99;bool valid=false,market=false;double entry=0,stop=0,target=0,lot=0;datetime bar=0; bool priced=true,barProxy=false;};
struct Lane{int score=2,gt=1,ct=1,st=1;string regime="MIXED";}; Lane g_p3[3];
P3Plan plans[3]; bool P3MakePlan(int i,P3Plan&p){p=plans[i];return p.valid;}
P3_TREND_CHOICE P3Choice(int){return P3_AUTO;} bool P3Against(int){return true;} int P3Strategy(int){return 30004;}
'''
main=r'''
int main(){int f=0;auto check=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';f++;}};
 long t=1700000000000L;
 P3Observation observed{};P3Plan delayed{1,true,true,100.02,99,101,0.05,1};
 MqlTick start{t,100.4,100.42};
 check(P3DiaryStart(observed,delayed,start) && observed.entry==100.02 && observed.entryQuote==100.42,"delayed market records real start quote separately from plan");
 start={t,101,101.02};check(!P3DiaryStart(observed,delayed,start),"market observation cannot start after target passed");
 delayed={1,true,false,99.5,99,101,0.05,1};start={t,99.3,99.32};
 check(P3DiaryStart(observed,delayed,start) && observed.state==P3_OPEN && observed.entryQuote==99.32,"limit start tick is observed");
 P3DiaryInit();check(g_diaryReady,"initialization");
 plans[0]={1,true,true,100.02,99,101,0.05,1};
 current={t,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.size()==1 && g_diary[0].obs.state==P3_OPEN,"new market signal records once");
 P3DiaryTick();check(g_diary.size()==1,"same signal not repeated");
 current={t+1,101,101.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary[0].obs.state==P3_TARGET && g_diary[0].obs.resolutionMs==t+1 && g_diary[0].obs.exitQuote==101,"observed target");
 check(P3DiarySummary(0,t/1000).find("All S 1 W 1 L 0")!=string::npos,"summary target");
 plans[0].signal=0;current={t+2,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 plans[0]={-1,true,false,100.5,102,99,0.05,2};g_p3[0].score=-2;
 current={t+3,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.size()==2 && g_diary[1].obs.state==P3_PENDING,"second pending signal");
 P3DiaryClose();P3DiaryInit();
 check(g_diaryReady && g_diary.size()==2 && g_diary[0].obs.state==P3_TARGET && g_diary[0].obs.exitQuote==101 && g_diary[0].strategy==30004 && g_diary[0].equity==10000 && g_diary[1].obs.state==P3_UNKNOWN,"restart preserves outcomes and marks gap");
 g_diary[0].strategy=30003;g_diary[0].signalStrategy=30003;check(P3DiarySave(),"save older strategy record");
 P3DiaryClose();P3DiaryInit();
 check(g_diaryReady && g_diary[0].strategy==30003 && g_diary[0].signalStrategy==30003 && g_diary[1].strategy==30004,"old and new strategy records survive restart");
 current={t+4,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.size()==2,"restart does not duplicate signal");
 plans[1]={1,true,false,99,98,101,0.05,3};g_p3[1].score=2;
 current={t+5,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_PENDING,"new pending observation");
 plans[1].signal=0;current={t+6,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_EXPIRED && g_diary.back().obs.resolutionMs==t+6,"pending expires on signal end");
 check(P3DiarySummary(1,t/1000).find("All S 1 W 0 L 0")!=string::npos,"expired not win or loss");
 plans[0].signal=0;current={t+7,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 plans[0]={1,true,true,100.02,99,101,0.05,3};g_p3[0].score=2;
 current={t+8,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_OPEN,"new open observation");
 connected=false;P3DiaryMonitor();connected=true;
 check(g_diary.back().obs.state==P3_UNKNOWN,"disconnect makes active outcome unknown");
 plans[2]={1,true,false,99.9,99,101,0.05,4};g_p3[2].score=2;
 current={t+9,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_PENDING,"same-millisecond test pending");
 current={t+9,99.8,99.9};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_OPEN && g_diary.back().obs.entryQuote==99.9,"entry with shared millisecond");
 current={t+9,101,101.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_TARGET && g_diary.back().obs.exitQuote==101,"target with shared millisecond");
 plans[1]={-1,true,true,100,101,99,0.05,5};g_p3[1].score=-3;
 current={t+10,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_OPEN,"open before tick history error");
 tickError=true;current={t+11,99,99.02};tickHistory.push_back(current);P3DiaryTick();tickError=false;
 check(g_diary.back().obs.state==P3_UNKNOWN,"tick history failure does not invent result");
 plans[1].signal=0;current={t+12,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 plans[1]={1,true,true,100.02,99,101,0.05,6};g_p3[1].score=3;
 current={t+13,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_OPEN,"open before incomplete tick batch");
 tickHistory.push_back({t+14,101,101.02});tickHistory.push_back({t+15,0,0});
 current={t+16,101,101.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_UNKNOWN,"incomplete batch cannot record an optimistic target");
 plans[1]={-1,true,true,100,101,99,0.05,7};g_p3[1].score=-3;
 current={t+17,100,100.02};tickHistory.push_back(current);tickHistory.push_back({t+17,101,101.02});P3DiaryTick();
 check(g_diary.back().obs.state==P3_AWAIT_DATA,"same-millisecond mismatch waits for a real usable quote");
 size_t waitingCount=g_diary.size();
 current={t+18,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.size()==waitingCount && g_diary.back().obs.state==P3_OPEN &&
       g_diary.back().obs.signalMs==t+17 && g_diary.back().obs.planMs==t+18 && g_diary.back().obs.entryMs==t+18 && g_diary.back().signalScore==-3,
       "later quote activates the same signal without a fabricated earlier entry");
 plans[1].signal=0;current={t+19,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 plans[1]={1,false,true,100.02,99,101,0,8};plans[1].priced=false;g_p3[1].score=3;
 current={t+20,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_AWAIT_DATA && P3DiaryDetail(1).find("Entry --")!=string::npos,"missing plan data recorded once without a fabricated price");
 waitingCount=g_diary.size();P3DiaryClose();P3DiaryInit();
 check(g_diaryReady && g_diary.back().obs.state==P3_AWAIT_DATA,"awaiting signal survives restart without invented coverage");
 plans[1].priced=true;plans[1].bar=10;g_p3[1].score=2;g_p3[1].gt=-1;
 current={t+21,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.size()==waitingCount && g_diary.back().obs.state==P3_OPEN &&
       g_diary.back().obs.signalMs==t+20 && g_diary.back().obs.planMs==t+21 &&
       g_diary.back().signalScore==3 && g_diary.back().score==2 && g_diary.back().signalGt==1 && g_diary.back().gt==-1 &&
       g_diary.back().signalBar==8 && g_diary.back().bar==10,
       "missing plan data retried without duplicate, original and later context retained");
 check(P3DiaryDetail(1).find("Delayed plan")!=string::npos,"details identify delayed activation");
 plans[0].signal=0;current={t+22,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 plans[0]={-1,false,false,0,0,0,0,9};plans[0].priced=false;g_p3[0].score=-2;
 current={t+23,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_AWAIT_DATA,"unpriced idea waits");
 plans[0].signal=0;current={t+24,100,100.02};tickHistory.push_back(current);P3DiaryTick();
 check(g_diary.back().obs.state==P3_EXPIRED && g_diary.back().obs.planMs==0,"unpriced idea expires without a fabricated plan");
 check(FileOpen(g_diaryName+".lock",FILE_READ|FILE_WRITE|FILE_BIN|g_diaryFlags)==INVALID_HANDLE,"exclusive writer lock");
 P3DiaryClose();P3DiaryInit();
 check(g_diaryReady && g_diary[2].obs.state==P3_EXPIRED && g_diary[2].obs.resolutionMs==t+6 &&
       g_diary.back().obs.state==P3_EXPIRED && g_diary.back().obs.planMs==0,"priced and unpriced expiry persist");
 check(g_diary[waitingCount-1].obs.planMs==t+21 && g_diary[waitingCount-1].signalScore==3 &&
       g_diary[waitingCount-1].score==2 && g_diary[waitingCount-1].signalBar==8 && g_diary[waitingCount-1].bar==10,
       "delayed plan timestamp and separate contexts persist");
 string name=g_diaryName;P3DiaryClose();
 auto v5=files[name];vector<char> v4(v5.begin(),v5.begin()+24);int version4=4, count2=2;
 memcpy(v4.data()+4,&version4,4);memcpy(v4.data()+8,&count2,4);
 for(size_t off=24;off<24+2*256;off+=256){v4.insert(v4.end(),v5.begin()+off,v5.begin()+off+60);v4.insert(v4.end(),v5.begin()+off+104,v5.begin()+off+112);v4.insert(v4.end(),v5.begin()+off+120,v5.begin()+off+128);v4.insert(v4.end(),v5.begin()+off+136,v5.begin()+off+232);}
 files[name]=v4;P3DiaryInit();
 check(g_diaryReady && g_diary.size()==2 && g_diary[0].obs.planMs==g_diary[0].obs.signalMs && files[name].size()==24+2*256,"v4 records migrate to v5");
 P3DiaryClose();vector<char> v3(v4.begin(),v4.begin()+24);int version3=3;
 memcpy(v3.data()+4,&version3,4);
 for(size_t off=24;off<v4.size();off+=172){v3.insert(v3.end(),v4.begin()+off,v4.begin()+off+56);v3.insert(v3.end(),v4.begin()+off+60,v4.begin()+off+172);}
 files[name]=v3;P3DiaryInit();
 check(g_diaryReady && g_diary[0].obs.state==P3_TARGET && g_diary[0].barProxy==1 && files[name].size()==24+2*256,"v3 migration preserves results with unknown bar provenance");
 P3DiaryClose();files[name][0]^=1;auto before=files[name];P3DiaryInit();
 check(!g_diaryReady && files[name]==before,"corrupt file preserved");P3DiaryClose();
 if(!f)cout<<"Diary runtime file/tick stub checks passed\n";
 return f?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+s+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
