#!/usr/bin/env python3
"""Exercise Phase 4 source with in-memory MT5-like broker/file stubs, not MT5."""
from pathlib import Path
import re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'MT_AutoRuntime.mqh').read_text().replace('#include "MT_AutoPolicy.mqh"','')
s=re.sub(r'^input ', '', s,flags=re.M)
stubs=r'''
#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <sstream>
#include <string>
#include <vector>
using namespace std;
using datetime=long; using uint=unsigned int; using ENUM_ORDER_TYPE_FILLING=int;
#define EMPTY_VALUE numeric_limits<double>::max()
#define INVALID_HANDLE -1
#define FILE_READ 1
#define FILE_WRITE 2
#define FILE_BIN 4
#define FILE_COMMON 8
#define FILE_REWRITE 16
#define INT_VALUE 4
#define MQL_TESTER 1
#define MQL_TRADE_ALLOWED 2
#define TERMINAL_CONNECTED 3
#define TERMINAL_TRADE_ALLOWED 4
#define ACCOUNT_TRADE_ALLOWED 5
#define ACCOUNT_TRADE_EXPERT 6
#define ACCOUNT_MARGIN_MODE 7
#define ACCOUNT_MARGIN_MODE_RETAIL_HEDGING 8
#define ACCOUNT_CURRENCY 9
#define SYMBOL_DIGITS 10
#define SYMBOL_FILLING_MODE 11
#define SYMBOL_TRADE_EXEMODE 12
#define SYMBOL_EXPIRATION_MODE 13
#define SYMBOL_CURRENCY_BASE 14
#define SYMBOL_CURRENCY_PROFIT 15
#define SYMBOL_TRADE_CALC_MODE 16
#define SYMBOL_ORDER_MODE 17
#define SYMBOL_ORDER_GTC_MODE 18
#define SYMBOL_ORDER_MARKET 1
#define SYMBOL_ORDER_LIMIT 2
#define SYMBOL_ORDER_SL 16
#define SYMBOL_ORDER_TP 32
#define SYMBOL_ORDERS_GTC 0
#define SYMBOL_ORDERS_DAILY 1
#define SYMBOL_ORDERS_DAILY_EXCLUDING_STOPS 2
#define SYMBOL_CALC_MODE_FOREX 1
#define SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE 2
#define SYMBOL_FILLING_FOK 1
#define SYMBOL_FILLING_IOC 2
#define SYMBOL_TRADE_EXECUTION_MARKET 20
#define SYMBOL_EXPIRATION_GTC 1
#define SYMBOL_EXPIRATION_DAY 2
#define ORDER_FILLING_FOK 1
#define ORDER_FILLING_IOC 2
#define ORDER_FILLING_RETURN 3
#define ORDER_TIME_GTC 1
#define ORDER_TIME_DAY 2
#define TRADE_ACTION_DEAL 1
#define TRADE_ACTION_PENDING 2
#define TRADE_ACTION_REMOVE 3
#define ORDER_TYPE_BUY 1
#define ORDER_TYPE_SELL 2
#define ORDER_TYPE_BUY_LIMIT 3
#define ORDER_TYPE_SELL_LIMIT 4
#define ORDER_STATE_CANCELED 1
#define ORDER_STATE_EXPIRED 2
#define ORDER_STATE_REJECTED 3
#define ORDER_STATE_FILLED 4
#define ORDER_SYMBOL 30
#define ORDER_MAGIC 31
#define ORDER_TYPE 32
#define ORDER_PRICE_OPEN 33
#define ORDER_SL 34
#define ORDER_TP 35
#define ORDER_VOLUME_CURRENT 36
#define ORDER_COMMENT 37
#define ORDER_STATE 38
#define ORDER_POSITION_ID 39
#define ORDER_VOLUME_INITIAL 49
#define POSITION_SYMBOL 40
#define POSITION_MAGIC 41
#define POSITION_IDENTIFIER 42
#define POSITION_TYPE 43
#define POSITION_TYPE_BUY 1
#define POSITION_TYPE_SELL 2
#define POSITION_PRICE_OPEN 44
#define POSITION_SL 45
#define POSITION_TP 46
#define POSITION_VOLUME 47
#define POSITION_COMMENT 48
#define DEAL_POSITION_ID 50
#define DEAL_ENTRY 51
#define DEAL_VOLUME 52
#define DEAL_ENTRY_IN 1
#define DEAL_ENTRY_OUT 2
#define DEAL_ENTRY_OUT_BY 3
#define DEAL_ENTRY_INOUT 4
#define TRADE_RETCODE_REJECT 10006
#define TRADE_RETCODE_REQUOTE 10004
#define TRADE_RETCODE_INVALID 10013
#define TRADE_RETCODE_INVALID_VOLUME 10014
#define TRADE_RETCODE_INVALID_PRICE 10015
#define TRADE_RETCODE_INVALID_STOPS 10016
#define TRADE_RETCODE_TRADE_DISABLED 10017
#define TRADE_RETCODE_MARKET_CLOSED 10018
#define TRADE_RETCODE_NO_MONEY 10019
#define TRADE_RETCODE_PRICE_CHANGED 10020
#define TRADE_RETCODE_PRICE_OFF 10021
#define TRADE_RETCODE_INVALID_EXPIRATION 10022
#define TRADE_RETCODE_INVALID_FILL 10030
#define MARKET_OPEN 0
int g_marketState=MARKET_OPEN; string _Symbol="XAUUSD";
bool connected=true, permission=true, hedging=true, diskFail=false, checkOk=true, calcOk=true, tester=false;
long terminalTime=1700000000; unsigned long uptime=10000;
long TerminalInfoInteger(int p){return p==TERMINAL_CONNECTED?connected:permission;}
long MQLInfoInteger(int p){return p==MQL_TESTER?tester:permission;}
long AccountInfoInteger(int p){if(p==ACCOUNT_MARGIN_MODE)return hedging?ACCOUNT_MARGIN_MODE_RETAIL_HEDGING:0;return permission;}
string accountCurrency="USD"; string AccountInfoString(int){return accountCurrency;}
bool MathIsValidNumber(double x){return isfinite(x);} double MathMin(double a,double b){return min(a,b);} double MathFloor(double x){return floor(x);} double MathAbs(double x){return abs(x);}
int StringLen(string s){return int(s.size());} unsigned short StringGetCharacter(string s,int i){return s[i];}
int StringFind(string s,string part){auto n=s.find(part);return n==string::npos?-1:int(n);}
string DoubleToString(double x,int n){ostringstream o;o<<fixed<<setprecision(n)<<x;return o.str();}
string StringFormat(const char *fmt,...){char b[1024];va_list a;va_start(a,fmt);vsnprintf(b,sizeof(b),fmt,a);va_end(a);return b;}
template<class... T> void Print(T...){ }
template<class... T> void PrintFormat(T...){ }
int lastError=0;void ResetLastError(){lastError=0;}int GetLastError(){return lastError;}
unsigned long GetTickCount64(){return uptime;} datetime TimeCurrent(){return terminalTime;} datetime ServerNow(){return terminalTime;}
struct MqlTick{double bid=100,ask=100.02;datetime time=1700000000;};
MqlTick current{}; vector<string> currencies; map<string,pair<string,string>> pairs; map<string,MqlTick> quotes;
bool SymbolInfoTick(string name,MqlTick &q){if(name==_Symbol){q=current;return true;}if(!quotes.count(name))return false;q=quotes[name];return true;}
int SymbolsTotal(bool){return currencies.size();}string SymbolName(int i,bool){return currencies[i];}
string SymbolInfoString(string s,int p){if(!pairs.count(s))return "";return p==SYMBOL_CURRENCY_BASE?pairs[s].first:pairs[s].second;}
long symbolFill=SYMBOL_FILLING_FOK, symbolExec=SYMBOL_TRADE_EXECUTION_MARKET, expiration=SYMBOL_EXPIRATION_GTC, calcMode=SYMBOL_CALC_MODE_FOREX, orderMode=51, stopLifetime=SYMBOL_ORDERS_GTC;
long SymbolInfoInteger(string,int p){return p==SYMBOL_DIGITS?2:0;}
bool SymbolInfoInteger(string,int p,long &out){out=p==SYMBOL_FILLING_MODE?symbolFill:p==SYMBOL_TRADE_EXEMODE?symbolExec:p==SYMBOL_TRADE_CALC_MODE?calcMode:p==SYMBOL_ORDER_MODE?orderMode:p==SYMBOL_ORDER_GTC_MODE?stopLifetime:expiration;return true;}
bool OrderCalcProfit(int dir,string,double lot,double entry,double exit,double &x){if(!calcOk)return false;x=(dir==ORDER_TYPE_BUY?1:-1)*lot*(exit-entry)*100;return true;}
bool ChartSupported(){return true;}string P3DiaryKey(){return "MT-test";}
struct Handle{string name;size_t pos;}; map<int,Handle> handles;map<string,vector<char>> files;int nextHandle=1;
int FileOpen(string name,int flags){if(diskFail)return -1;for(auto &p:handles)if(p.second.name==name)return -1;if(flags&FILE_WRITE){if(!(flags&FILE_READ))files[name].clear();else if(!files.count(name))files[name]={};}else if(!files.count(name))return -1;int h=nextHandle++;handles[h]={name,0};return h;}
void FileClose(int h){handles.erase(h);}bool FileIsExist(string n,int){return files.count(n);}
bool FileMove(string a,int,string b,int){if(diskFail||!files.count(a))return false;files[b]=files[a];files.erase(a);return true;}
void FileFlush(int){} unsigned long FileSize(int h){return files[handles[h].name].size();}unsigned long FileTell(int h){return handles[h].pos;}
template<class T> void writeVal(int h,T x){auto &a=handles[h];auto &v=files[a.name];if(a.pos+sizeof(T)>v.size())v.resize(a.pos+sizeof(T));memcpy(&v[a.pos],&x,sizeof(T));a.pos+=sizeof(T);}
template<class T> T readVal(int h){auto &a=handles[h];auto &v=files[a.name];T x{};if(a.pos+sizeof(T)>v.size()){lastError=1;return x;}memcpy(&x,&v[a.pos],sizeof(T));a.pos+=sizeof(T);return x;}
void FileWriteInteger(int h,int x,int){writeVal<int>(h,x);}void FileWriteLong(int h,long x){writeVal<long>(h,x);}
int FileReadInteger(int h,int){return readVal<int>(h);}long FileReadLong(int h){return readVal<long>(h);}
#include "MT_AutoPolicy.mqh"
struct P3Plan{int signal=P3_WAIT;bool valid=false,market=false;double entry=0,stop=0,target=0,lot=0;};
struct Lane{int score=0;};Lane g_p3[3];P3Plan plans[3];
bool P3MakePlan(int i,P3Plan &p){p=plans[i];return p.valid;}
bool P3MakePlanAt(int i,const MqlTick &,P3Plan &p){p=plans[i];return p.valid;}
string P3LotText(double x){return DoubleToString(x,2);}
struct Order {unsigned long ticket=0,position=0;long magic=0;int type=0,state=0;double entry=0,sl=0,tp=0,lot=0,initial=0;string symbol,comment;};
struct Position {unsigned long ticket=0,id=0;long magic=0;int type=0;double entry=0,sl=0,tp=0,lot=0;string symbol,comment;};
struct Deal {unsigned long position=0;int how=0;double vol=0;};
vector<Order> orders;vector<Position> positions;map<unsigned long,Order> history;vector<Deal> deals;unsigned long historyPosition=0,historyOrder=0;
int selectedOrder=-1,selectedPosition=-1;
int OrdersTotal(){return orders.size();}int PositionsTotal(){return positions.size();}
unsigned long OrderGetTicket(int i){selectedOrder=i;return orders[i].ticket;}unsigned long PositionGetTicket(int i){selectedPosition=i;return positions[i].ticket;}
bool OrderSelect(unsigned long tk){for(size_t i=0;i<orders.size();i++)if(orders[i].ticket==tk){selectedOrder=i;return true;}return false;}
string OrderGetString(int p){return p==ORDER_SYMBOL?orders[selectedOrder].symbol:orders[selectedOrder].comment;}
long OrderGetInteger(int p){auto &o=orders[selectedOrder];return p==ORDER_MAGIC?o.magic:p==ORDER_TYPE?o.type:p==ORDER_POSITION_ID?o.position:0;}
double OrderGetDouble(int p){auto &o=orders[selectedOrder];return p==ORDER_PRICE_OPEN?o.entry:p==ORDER_SL?o.sl:p==ORDER_TP?o.tp:o.lot;}
string PositionGetString(int p){return p==POSITION_SYMBOL?positions[selectedPosition].symbol:positions[selectedPosition].comment;}
long PositionGetInteger(int p){auto &o=positions[selectedPosition];return p==POSITION_MAGIC?o.magic:p==POSITION_IDENTIFIER?o.id:o.type;}
double PositionGetDouble(int p){auto &o=positions[selectedPosition];return p==POSITION_PRICE_OPEN?o.entry:p==POSITION_SL?o.sl:p==POSITION_TP?o.tp:o.lot;}
bool HistorySelectByPosition(unsigned long id){historyPosition=id;return true;}int HistoryDealsTotal(){return deals.size();}
unsigned long HistoryDealGetTicket(int i){return i+1;}long HistoryDealGetInteger(unsigned long tk,int p){auto &d=deals[tk-1];return p==DEAL_POSITION_ID?d.position:d.how;}
double HistoryDealGetDouble(unsigned long tk,int){return deals[tk-1].vol;}
bool readFailure=false;
bool HistoryDealGetInteger(unsigned long tk,int p,long &x){if(readFailure)return false;x=HistoryDealGetInteger(tk,p);return true;}
bool HistoryDealGetDouble(unsigned long tk,int p,double &x){if(readFailure)return false;x=HistoryDealGetDouble(tk,p);return true;}
bool OrderGetString(int p,string &x){if(readFailure)return false;x=OrderGetString(p);return true;}
bool OrderGetInteger(int p,long &x){if(readFailure)return false;x=OrderGetInteger(p);return true;}
bool OrderGetDouble(int p,double &x){if(readFailure)return false;x=OrderGetDouble(p);return true;}
bool PositionGetString(int p,string &x){if(readFailure)return false;x=PositionGetString(p);return true;}
bool PositionGetInteger(int p,long &x){if(readFailure)return false;x=PositionGetInteger(p);return true;}
bool PositionGetDouble(int p,double &x){if(readFailure)return false;x=PositionGetDouble(p);return true;}
bool HistoryOrderSelect(unsigned long tk){historyOrder=tk;return history.count(tk);}
long HistoryOrderGetInteger(unsigned long tk,int p){return p==ORDER_STATE?history[tk].state:history[tk].position;}
bool HistoryOrderGetInteger(unsigned long tk,int p,long &x){if(readFailure)return false;x=HistoryOrderGetInteger(tk,p);return true;}
bool HistoryOrderGetDouble(unsigned long tk,int p,double &x){if(readFailure)return false;x=p==ORDER_VOLUME_INITIAL?history[tk].initial:history[tk].lot;return true;}
struct MqlTradeRequest{int action=0;string symbol;unsigned long magic=0,order=0;double volume=0,price=0,sl=0,tp=0;int type=0,deviation=0,type_filling=0,type_time=0;string comment;};
struct MqlTradeCheckResult{unsigned retcode=0;};struct MqlTradeResult{unsigned retcode=0;unsigned long order=0,deal=0;};
bool OrderCheck(MqlTradeRequest &,MqlTradeCheckResult &out){out.retcode=checkOk?0:TRADE_RETCODE_NO_MONEY;return checkOk;}
int sendMode=0,sends=0,cancels=0;unsigned long nextTicket=100;MqlTradeRequest lastRequest{};
bool OrderSend(MqlTradeRequest &r,MqlTradeResult &out){
 lastRequest=r;
 if(r.action==TRADE_ACTION_REMOVE){cancels++;if(sendMode==3){out.retcode=10028;return false;}for(size_t i=0;i<orders.size();i++)if(orders[i].ticket==r.order){Order o=orders[i];orders.erase(orders.begin()+i);if(sendMode==4){Position p;p.id=o.ticket+1000;p.ticket=p.id;p.magic=o.magic;p.type=o.type==ORDER_TYPE_BUY_LIMIT?POSITION_TYPE_BUY:POSITION_TYPE_SELL;p.entry=o.entry;p.sl=o.sl;p.tp=o.tp;p.lot=o.lot;p.symbol=o.symbol;p.comment=o.comment;positions.push_back(p);deals.push_back({p.id,DEAL_ENTRY_IN,p.lot});o.position=p.id;o.state=ORDER_STATE_FILLED;history[o.ticket]=o;out.retcode=10036;return false;}o.state=ORDER_STATE_CANCELED;history[o.ticket]=o;out.retcode=10009;return true;}return false;}
 sends++; if(sendMode==1){out.retcode=10012;return false;} if(sendMode==2){out.retcode=TRADE_RETCODE_REJECT;return false;}
 Order o; o.ticket=nextTicket++;o.magic=r.magic;o.type=r.type;o.entry=r.price;o.sl=r.sl;o.tp=r.tp;o.lot=r.volume;o.initial=r.volume;o.symbol=r.symbol;o.comment=r.comment;out.order=o.ticket;out.retcode=10009;
 if(r.action==TRADE_ACTION_PENDING){orders.push_back(o);}else{Position p; p.ticket=o.ticket+1000;p.id=o.ticket+1000;p.magic=o.magic;p.type=r.type==ORDER_TYPE_BUY?POSITION_TYPE_BUY:POSITION_TYPE_SELL;p.entry=o.entry;p.sl=o.sl;p.tp=o.tp;p.lot=o.lot;p.symbol=o.symbol;p.comment=o.comment;positions.push_back(p);o.position=p.id;o.state=ORDER_STATE_FILLED;history[o.ticket]=o;deals.push_back({p.id,DEAL_ENTRY_IN,p.lot});}
 return true;
}
'''
main=r'''
void resetWorld(){
 P4Close(); handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();currencies.clear();quotes.clear();pairs.clear();
 connected=true;permission=true;hedging=true;diskFail=false;checkOk=true;calcOk=true;readFailure=false;tester=false;accountCurrency="USD";
 g_marketState=MARKET_OPEN;uptime=10000;sendMode=0;sends=0;cancels=0;nextTicket=500;expiration=SYMBOL_EXPIRATION_GTC;symbolFill=SYMBOL_FILLING_FOK;symbolExec=SYMBOL_TRADE_EXECUTION_MARKET;calcMode=SYMBOL_CALC_MODE_FOREX;orderMode=51;stopLifetime=SYMBOL_ORDERS_GTC;
 for(int i=0;i<3;i++){plans[i]=P3Plan{};g_p3[i].score=0;}
 InpAutoTrading=false;P4Init();
}
int main(){int f=0;auto check=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';f++;}};
 P4Init();check(g_p4Ready && !InpAutoTrading,"initialization and default off");
 plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;P4Process(true);check(sends==0,"off does not send");
 InpAutoTrading=true;hedging=false;P4Process(true);check(sends==0 && P4Line(0).find("Hedging")!=string::npos,"netting does not send");
 hedging=true;checkOk=false;P4Process(true);check(sends==0 && !g_p4[0].active,"rejected preflight does not journal or send");
 checkOk=true;uptime+=6000;P4Process(true);check(sends==1 && g_p4[0].active && g_p4[0].order==100,"market request journals order");
 P4Process(true);check(g_p4View[0].state==P4_OPEN && sends==1 && P4Line(0).find("BUY OPEN")!=string::npos,"broker-confirmed market position");
 readFailure=true;P4Process(true);check(g_p4View[0].state==P4_UNCERTAIN && sends==1,"broker read failure blocks decisions");readFailure=false;
 plans[1]={-1,true,false,100.5,102,99,0.05};g_p3[1].score=-2;uptime+=6000;P4Process(true);P4Process(true);
 check(sends==2 && g_p4View[1].state==P4_PENDING && P4Line(1).find("distance")!=string::npos,"pending sell limit and distance");
 plans[1].signal=P3_WAIT;P4Process(false);check(cancels==0,"unavailable signal does not cancel");
 plans[1].signal=0;permission=false;P4Process(false);check(g_p4[1].cancel && cancels==0,"cancellation intent persists while permission unavailable");
 plans[1].signal=-1;permission=true;uptime+=6000;P4Process(false);check(cancels==1 && orders.empty(),"sticky cancellation on signal change");
 P4Process(false);check(!g_p4[1].active && positions.size()==1,"broker confirms cancellation without closing position");
 plans[1]={-1,true,false,100.5,102,99,0.05};uptime+=6000;P4Process(true);P4Process(true);check(g_p4View[1].state==P4_PENDING,"same signal can place again after cancellation");
 InpAutoTrading=false;uptime+=6000;P4Process(false);P4Process(false);check(cancels==2 && positions.size()==1 && sends==3,"off cancels limits and preserves open position");
 InpAutoTrading=true;plans[1].signal=0;auto first=positions[0];deals.push_back({first.id,DEAL_ENTRY_OUT,first.lot});positions.clear();uptime+=6000;P4Process(true);
 check(sends==4 && positions.size()==1,"confirmed closure permits re-entry on same signal");
 P4Process(false);check(g_p4View[0].state==P4_OPEN,"re-entry confirmed open");
 plans[2]={1,true,true,100.02,99,101,0.05};g_p3[2].score=3;sendMode=1;uptime+=6000;P4Process(true);
 check(g_p4[2].active && g_p4[2].order==0,"ambiguous result remains journaled");int before=sends;P4Close();P4Init();uptime+=6000;P4Process(true);
 check(sends==before && g_p4View[2].state==P4_UNCERTAIN,"restart never blindly retries ambiguous result");
 check(FileOpen(g_p4File+".lock",FILE_READ|FILE_WRITE|FILE_BIN|g_p4Flags)==INVALID_HANDLE,"single-writer lock");
 accountCurrency="EUR";currencies={"EURUSD"};pairs["EURUSD"]={"EUR","USD"};quotes["EURUSD"]={1.1,1.2,terminalTime};double x=0;
 check(P4ToUSD(10,x)&&abs(x-11)<1e-9 && P4ToUSD(-10,x)&&abs(x+12)<1e-9,"signed direct USD conversion");
 quotes["EURUSD"].time=terminalTime-121;check(!P4ToUSD(10,x),"stale conversion unavailable");
 accountCurrency="JPY";currencies={"USDJPY"};pairs["USDJPY"]={"USD","JPY"};quotes["USDJPY"]={100,101,terminalTime};
 check(P4ToUSD(1010,x)&&abs(x-10)<1e-9 && P4ToUSD(-1000,x)&&abs(x+10)<1e-9,"signed inverse USD conversion");
 calcMode=99;check(!P4ToUSD(100,x),"non-forex prices are not used as conversion rates");calcMode=SYMBOL_CALC_MODE_FOREX;
 P4Close();string name=g_p4File;files[name][0]^=1;auto preserved=files[name];P4Init();check(!g_p4Ready && files[name]==preserved,"corrupt journal preserved");P4Close();
 // Partially filled limit: cancel only its known remainder, preserving the position.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 P4Process(true);P4Process(false);check(orders.size()==1,"partial scenario limit created");
 orders[0].position=900;Position part;part.id=900;part.ticket=901;part.magic=P4Magic(0);part.type=POSITION_TYPE_BUY;part.entry=99.9;part.sl=99;part.tp=101;part.lot=0.02;part.symbol=_Symbol;part.comment="MT4-M5";positions.push_back(part);deals.push_back({900,DEAL_ENTRY_IN,0.02});
 uptime+=6000;P4Process(false);P4Process(false);
 check(orders.empty() && positions.size()==1 && cancels==1 && g_p4View[0].state==P4_OPEN,"partial fill cancels remainder but does not close position");
 // A cancellation request can race a fill; broker-confirmed position must survive.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 P4Process(true);P4Process(false);plans[0].signal=0;sendMode=4;uptime+=6000;P4Process(false);P4Process(false);
 check(orders.empty() && positions.size()==1 && g_p4View[0].state==P4_OPEN,"fill/cancel race retains position");
 auto racePosition=positions[0];deals.push_back({racePosition.id,DEAL_ENTRY_OUT,racePosition.lot});positions.clear();
 deals.push_back({racePosition.id,99,0.01});check(!P4PositionClosed(racePosition.id),"unknown deal entry cannot establish closure");deals.pop_back();
 deals.push_back({racePosition.id,DEAL_ENTRY_INOUT,0.01});check(!P4PositionClosed(racePosition.id),"reversal cannot establish closure");deals.pop_back();
 plans[0].signal=1;readFailure=true;uptime+=6000;int attempts=sends;P4Process(true);
 check(sends==attempts && g_p4View[0].state==P4_UNCERTAIN,"unavailable broker history cannot prove closure");readFailure=false;
 // Partial cancellation without a visible position ID is not proof of no fill.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 P4Process(true);P4Process(false);Order uncertain=orders[0];orders.clear();uncertain.state=ORDER_STATE_CANCELED;uncertain.lot=0.02;uncertain.position=0;history[uncertain.ticket]=uncertain;
 uptime+=6000;int oldSends=sends;P4Process(true);
 check(sends==oldSends && g_p4View[0].state==P4_UNCERTAIN,"partial canceled order without position ID stays held");
 // A same-magic broker object without a journal cannot be safely owned or cancelled.
 resetWorld();Order unknown;unknown.ticket=999;unknown.magic=P4Magic(0);unknown.type=ORDER_TYPE_BUY_LIMIT;unknown.entry=99;unknown.sl=98;unknown.tp=101;unknown.lot=0.01;unknown.symbol=_Symbol;unknown.comment="other";orders.push_back(unknown);
 plans[0]={1,true,false,99,98,101,0.01};g_p3[0].score=2;InpAutoTrading=true;P4Process(true);
 check(g_p4View[0].state==P4_UNTRACKED && sends==0 && cancels==0,"untracked order held");
 InpAutoTrading=false;P4Process(false);check(cancels==0,"untracked order not cancelled when disabled");
 orders.push_back(unknown);P4Process(false);check(g_p4View[0].state==P4_MULTIPLE && cancels==0,"multiple objects require review");
 // No request is sent when its pre-send journal cannot be saved.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;diskFail=true;P4Process(true);
 check(sends==0 && !g_p4Ready,"failed intent persistence prevents sending");diskFail=false;
 // Reject unsupported expiration rather than inventing an expiration policy.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;expiration=0;P4Process(true);
 check(sends==0 && !g_p4[0].active,"unsupported expiration does not place");
 // Distinct M5/M15/M30 slots may coexist on a hedging account.
 resetWorld();InpAutoTrading=true;
 plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 plans[1]={-1,true,true,100,101,99,0.03};g_p3[1].score=-3;
 plans[2]={1,true,true,100.02,99,101,0.04};g_p3[2].score=3;
 P4Process(true);P4Process(false);
 check(sends==3 && orders.size()==1 && positions.size()==2 && P4Magic(0)!=P4Magic(1) && P4Magic(1)!=P4Magic(2),"three independent lanes");
 check(g_p4View[0].state==P4_PENDING && g_p4View[1].state==P4_OPEN && g_p4View[2].state==P4_OPEN,"lane broker state reflected independently");
 // A definite rejection releases the intent; an ambiguous reply never does.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;sendMode=2;P4Process(true);
 check(sends==1 && !g_p4[0].active,"definite rejection releases intent");P4Process(true);check(sends==1,"rejection retry is throttled");
 // A failed cancellation remains pending across restart and is retried later.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 InpAutoTrading=false;sendMode=3;uptime+=6000;P4Process(false);check(cancels==1 && g_p4[0].cancel && orders.size()==1,"failed cancellation remains pending");
 P4Close();P4Init();sendMode=0;P4Process(false);P4Process(false);
 check(cancels==2 && orders.empty() && !g_p4[0].active,"cancellation intent survives restart");
 // Broker-stripped exits on an owned pending order trigger cancellation.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 orders[0].sl=0;uptime+=6000;P4Process(false);check(cancels==1 && orders.empty(),"owned pending order missing SL is cancelled");
 // An open position with missing broker exits is shown for review, not closed.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;P4Process(true);P4Process(false);
 positions[0].tp=0;P4Process(false);check(positions.size()==1 && P4Line(0).find("SL/TP missing: REVIEW")!=string::npos,"missing open-position exit shown without closing it");
 // Hold when the broker would remove protective stops or their lifetime is unknown.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;expiration=SYMBOL_EXPIRATION_DAY;P4Process(true);
 check(sends==0,"day-only symbol without documented stop persistence holds");
 expiration=SYMBOL_EXPIRATION_GTC;stopLifetime=SYMBOL_ORDERS_DAILY;P4Process(true);
 check(sends==0,"symbol that removes stops daily holds");
 stopLifetime=SYMBOL_ORDERS_DAILY_EXCLUDING_STOPS;P4Process(true);
 check(sends==1 && lastRequest.type_time==ORDER_TIME_GTC,"daily order expiry allowed when stops persist");
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;orderMode=SYMBOL_ORDER_MARKET|SYMBOL_ORDER_SL;P4Process(true);
 check(sends==0,"broker must allow both SL and TP");
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;symbolFill=0;P4Process(true);
 check(sends==0 && !g_p4[0].active,"unsupported market fill mode holds");
 // Stale symbol snapshots cannot trigger new orders.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;
 current.time=terminalTime-11;P4Process(true);check(sends==0,"stale quote prevents order");current.time=terminalTime;
 // Tester connectivity is simulated and must not depend on live network state.
 resetWorld();P4Close();tester=true;connected=false;P4Init();InpAutoTrading=true;
 plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;P4Process(true);
 check(sends==1,"tester can run when live terminal is disconnected");
 if(!f) cout<<"Phase 4 broker/runtime stub checks passed\n";
 return f?1:0;
}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+s+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
