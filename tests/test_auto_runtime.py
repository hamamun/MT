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
#define SYMBOL_POINT 19
#define SYMBOL_TRADE_STOPS_LEVEL 20
#define SYMBOL_TRADE_TICK_SIZE 21
#define SYMBOL_VOLUME_STEP 22
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
#define TRADE_ACTION_MODIFY 4
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
#define DEAL_ORDER 53
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
bool InpMinimumLot=false;
vector<datetime> laneBars[3]={{700,800,900,1000,1001},{700,800,900,1000,1001},{700,800,900,1000,1001}};
int P3Timeframe(int lane){return lane;}
datetime iTime(string,int tf,int shift){auto &b=laneBars[tf];return b.size()>(size_t)shift?b[b.size()-1-shift]:0;}
int iBarShift(string,int tf,datetime t,bool){auto &b=laneBars[tf];for(int i=0;i<(int)b.size();i++)if(b[i]==t)return (int)b.size()-1-i;return -1;}
bool connected=true, permission=true, hedging=true, diskFail=false, checkOk=true, calcOk=true, tester=false;
long terminalTime=1700000000; unsigned long uptime=10000;
long TerminalInfoInteger(int p){return p==TERMINAL_CONNECTED?connected:permission;}
long MQLInfoInteger(int p){return p==MQL_TESTER?tester:permission;}
long AccountInfoInteger(int p){if(p==ACCOUNT_MARGIN_MODE)return hedging?ACCOUNT_MARGIN_MODE_RETAIL_HEDGING:0;return permission;}
string accountCurrency="USD"; string AccountInfoString(int){return accountCurrency;}
bool MathIsValidNumber(double x){return isfinite(x);} double MathMin(double a,double b){return min(a,b);} double MathMax(double a,double b){return max(a,b);} double MathFloor(double x){return floor(x);} double MathAbs(double x){return abs(x);}
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
long stopPoints=0; bool stopInfo=true;
long symbolFill=SYMBOL_FILLING_FOK, symbolExec=SYMBOL_TRADE_EXECUTION_MARKET, expiration=SYMBOL_EXPIRATION_GTC, calcMode=SYMBOL_CALC_MODE_FOREX, orderMode=51, stopLifetime=SYMBOL_ORDERS_GTC;
long SymbolInfoInteger(string,int p){return p==SYMBOL_DIGITS?2:0;}
double SymbolInfoDouble(string,int){return 0.01;}
bool SymbolInfoInteger(string,int p,long &out){if(p==SYMBOL_TRADE_STOPS_LEVEL){out=stopPoints;return stopInfo;}out=p==SYMBOL_FILLING_MODE?symbolFill:p==SYMBOL_TRADE_EXEMODE?symbolExec:p==SYMBOL_TRADE_CALC_MODE?calcMode:p==SYMBOL_ORDER_MODE?orderMode:p==SYMBOL_ORDER_GTC_MODE?stopLifetime:expiration;return true;}
bool OrderCalcProfit(int dir,string,double lot,double entry,double exit,double &x){if(!calcOk)return false;x=(dir==ORDER_TYPE_BUY?1:-1)*lot*(exit-entry)*100;return true;}
bool ChartSupported(){return true;}string P3DiaryKey(){return "MT-test";}
struct Handle{string name;size_t pos;}; map<int,Handle> handles;map<string,vector<char>> files;int nextHandle=1;
int FileOpen(string name,int flags){if(diskFail)return -1;for(auto &p:handles)if(p.second.name==name)return -1;if(flags&FILE_WRITE){if(!(flags&FILE_READ))files[name].clear();else if(!files.count(name))files[name]={};}else if(!files.count(name))return -1;int h=nextHandle++;handles[h]={name,0};return h;}
void FileClose(int h){handles.erase(h);}bool FileIsExist(string n,int){return files.count(n);}
bool FileMove(string a,int,string b,int){if(diskFail||!files.count(a))return false;files[b]=files[a];files.erase(a);return true;}
void FileFlush(int){} unsigned long FileSize(int h){return files[handles[h].name].size();}unsigned long FileTell(int h){return handles[h].pos;}
template<class T> void writeVal(int h,T x){auto &a=handles[h];auto &v=files[a.name];if(a.pos+sizeof(T)>v.size())v.resize(a.pos+sizeof(T));memcpy(&v[a.pos],&x,sizeof(T));a.pos+=sizeof(T);}
template<class T> T readVal(int h){auto &a=handles[h];auto &v=files[a.name];T x{};if(a.pos+sizeof(T)>v.size()){lastError=1;return x;}memcpy(&x,&v[a.pos],sizeof(T));a.pos+=sizeof(T);return x;}
void FileWriteInteger(int h,int x,int){writeVal<int>(h,x);}void FileWriteLong(int h,long x){writeVal<long>(h,x);}void FileWriteDouble(int h,double x){writeVal<double>(h,x);}
int FileReadInteger(int h,int){return readVal<int>(h);}long FileReadLong(int h){return readVal<long>(h);}double FileReadDouble(int h){return readVal<double>(h);}
#include "MT_AutoPolicy.mqh"
struct P3Plan{int signal=P3_WAIT;bool valid=false,market=false;double entry=0,stop=0,target=0,lot=0;datetime bar=1000;};
struct Lane{int score=0;};Lane g_p3[3];P3Plan plans[3];
bool P3MakePlan(int i,P3Plan &p){p=plans[i];return p.valid;}
bool P3MakePlanAt(int i,const MqlTick &,P3Plan &p){p=plans[i];return p.valid;}
string P3LotText(double x){return DoubleToString(x,2);}
struct Order {unsigned long ticket=0,position=0;long magic=0;int type=0,state=0;double entry=0,sl=0,tp=0,lot=0,initial=0;string symbol,comment;};
struct Position {unsigned long ticket=0,id=0;long magic=0;int type=0;double entry=0,sl=0,tp=0,lot=0;string symbol,comment;};
struct Deal {unsigned long position=0;int how=0;double vol=0;unsigned long order=0;};
vector<Order> orders;vector<Position> positions;map<unsigned long,Order> history;vector<Deal> deals;unsigned long historyPosition=0,historyOrder=0;
int selectedOrder=-1,selectedPosition=-1;
vector<int> selectedDeals;bool historySelectOk=true, positionSelectOk=true, historyRequiresSelect=false, historySelected=false;int historySelectCalls=0;
int OrdersTotal(){return orders.size();}int PositionsTotal(){return positions.size();}
unsigned long OrderGetTicket(int i){selectedOrder=i;return orders[i].ticket;}unsigned long PositionGetTicket(int i){selectedPosition=i;return positions[i].ticket;}
bool OrderSelect(unsigned long tk){for(size_t i=0;i<orders.size();i++)if(orders[i].ticket==tk){selectedOrder=i;return true;}return false;}
string OrderGetString(int p){return p==ORDER_SYMBOL?orders[selectedOrder].symbol:orders[selectedOrder].comment;}
long OrderGetInteger(int p){auto &o=orders[selectedOrder];return p==ORDER_MAGIC?o.magic:p==ORDER_TYPE?o.type:p==ORDER_POSITION_ID?o.position:0;}
double OrderGetDouble(int p){auto &o=orders[selectedOrder];return p==ORDER_PRICE_OPEN?o.entry:p==ORDER_SL?o.sl:p==ORDER_TP?o.tp:p==ORDER_VOLUME_INITIAL?o.initial:o.lot;}
string PositionGetString(int p){return p==POSITION_SYMBOL?positions[selectedPosition].symbol:positions[selectedPosition].comment;}
long PositionGetInteger(int p){auto &o=positions[selectedPosition];return p==POSITION_MAGIC?o.magic:p==POSITION_IDENTIFIER?o.id:o.type;}
double PositionGetDouble(int p){auto &o=positions[selectedPosition];return p==POSITION_PRICE_OPEN?o.entry:p==POSITION_SL?o.sl:p==POSITION_TP?o.tp:o.lot;}
bool HistorySelect(datetime,datetime){historySelectCalls++;if(!historySelectOk)return false;historySelected=true;selectedDeals.clear();for(int i=0;i<(int)deals.size();i++)selectedDeals.push_back(i);return true;}
bool HistorySelectByPosition(unsigned long id){historyPosition=id;if(!positionSelectOk)return false;selectedDeals.clear();for(int i=0;i<(int)deals.size();i++)if(deals[i].position==id)selectedDeals.push_back(i);return true;}int HistoryDealsTotal(){return selectedDeals.size();}
unsigned long HistoryDealGetTicket(int i){return selectedDeals[i]+1;}long HistoryDealGetInteger(unsigned long tk,int p){auto &d=deals[tk-1];return p==DEAL_POSITION_ID?d.position:p==DEAL_ORDER?d.order:d.how;}
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
bool HistoryOrderSelect(unsigned long tk){historyOrder=tk;return history.count(tk) && (!historyRequiresSelect || historySelected);}
long HistoryOrderGetInteger(unsigned long tk,int p){return p==ORDER_STATE?history[tk].state:history[tk].position;}
bool HistoryOrderGetInteger(unsigned long tk,int p,long &x){if(readFailure)return false;x=HistoryOrderGetInteger(tk,p);return true;}
bool HistoryOrderGetDouble(unsigned long tk,int p,double &x){if(readFailure)return false;x=p==ORDER_VOLUME_INITIAL?history[tk].initial:history[tk].lot;return true;}
struct MqlTradeRequest{int action=0;string symbol;unsigned long magic=0,order=0;double volume=0,price=0,sl=0,tp=0;int type=0,deviation=0,type_filling=0,type_time=0;string comment;};
struct MqlTradeCheckResult{unsigned retcode=0;string comment;};struct MqlTradeResult{unsigned retcode=0;unsigned long order=0,deal=0;string comment;};
bool OrderCheck(MqlTradeRequest &,MqlTradeCheckResult &out){out.retcode=checkOk?0:TRADE_RETCODE_NO_MONEY;if(!checkOk)out.comment="Not enough money";return checkOk;}
int sendMode=0,sends=0,cancels=0,modifies=0;unsigned long nextTicket=100;MqlTradeRequest lastRequest{};
bool OrderSend(MqlTradeRequest &r,MqlTradeResult &out){
 lastRequest=r;
 if(r.action==TRADE_ACTION_MODIFY){modifies++;if(sendMode==5){out.retcode=TRADE_RETCODE_REJECT;return false;}if(sendMode==6){out.retcode=10012;return false;}if(sendMode==8){out.retcode=10009;return true;}if(sendMode==7){for(size_t i=0;i<orders.size();i++)if(orders[i].ticket==r.order){Order o=orders[i];orders.erase(orders.begin()+i);Position p;p.id=o.ticket+1000;p.ticket=p.id;p.magic=o.magic;p.type=o.type==ORDER_TYPE_BUY_LIMIT?POSITION_TYPE_BUY:POSITION_TYPE_SELL;p.entry=o.entry;p.sl=o.sl;p.tp=o.tp;p.lot=o.lot;p.symbol=o.symbol;p.comment=o.comment;positions.push_back(p);deals.push_back({p.id,DEAL_ENTRY_IN,p.lot});o.position=p.id;o.state=ORDER_STATE_FILLED;history[o.ticket]=o;}out.retcode=10012;return false;}for(auto &o:orders)if(o.ticket==r.order){o.entry=r.price;o.sl=r.sl;o.tp=r.tp;out.retcode=10009;return true;}return false;}
 if(r.action==TRADE_ACTION_REMOVE){cancels++;if(sendMode==3){out.retcode=10028;return false;}for(size_t i=0;i<orders.size();i++)if(orders[i].ticket==r.order){Order o=orders[i];orders.erase(orders.begin()+i);if(sendMode==4){Position p;p.id=o.ticket+1000;p.ticket=p.id;p.magic=o.magic;p.type=o.type==ORDER_TYPE_BUY_LIMIT?POSITION_TYPE_BUY:POSITION_TYPE_SELL;p.entry=o.entry;p.sl=o.sl;p.tp=o.tp;p.lot=o.lot;p.symbol=o.symbol;p.comment=o.comment;positions.push_back(p);deals.push_back({p.id,DEAL_ENTRY_IN,p.lot});o.position=p.id;o.state=ORDER_STATE_FILLED;history[o.ticket]=o;out.retcode=10036;return false;}o.state=ORDER_STATE_CANCELED;history[o.ticket]=o;out.retcode=10009;return true;}return false;}
 sends++; if(sendMode==1){out.retcode=10012;return false;} if(sendMode==2){out.retcode=TRADE_RETCODE_REJECT;return false;} if(sendMode==9){out.retcode=TRADE_RETCODE_REJECT;out.deal=888;return false;}
 Order o; o.ticket=nextTicket++;o.magic=r.magic;o.type=r.type;o.entry=r.price;o.sl=r.sl;o.tp=r.tp;o.lot=r.volume;o.initial=r.volume;o.symbol=r.symbol;o.comment=r.comment;out.order=o.ticket;out.retcode=10009;
 if(r.action==TRADE_ACTION_PENDING){orders.push_back(o);}else{Position p; p.ticket=o.ticket+1000;p.id=o.ticket+1000;p.magic=o.magic;p.type=r.type==ORDER_TYPE_BUY?POSITION_TYPE_BUY:POSITION_TYPE_SELL;p.entry=o.entry;p.sl=o.sl;p.tp=o.tp;p.lot=o.lot;p.symbol=o.symbol;p.comment=o.comment;positions.push_back(p);o.position=p.id;o.state=ORDER_STATE_FILLED;history[o.ticket]=o;deals.push_back({p.id,DEAL_ENTRY_IN,p.lot});}
 return true;
}
'''
main=r'''
// Reference the pre-status-change price gate to detect accidental trading-rule changes.
bool oldLiveLevels(const MqlTick &quote,const P3Plan &plan){
 double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);long stops=0;
 if(!SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL,stops)||!P3Positive(point)||stops<0||!P3Positive(quote.bid)||!P3Positive(quote.ask)||quote.ask<quote.bid||!P3Positive(plan.entry)||!P3Positive(plan.stop)||!P3Positive(plan.target))return false;
 double minimum=MathMax(0.0,(double)stops*point-point*1e-7);
 if(plan.signal>0){if(plan.stop>=plan.entry||plan.target<=plan.entry)return false;
  if(plan.market)return plan.stop<quote.bid&&plan.target>quote.bid&&plan.stop<quote.ask&&plan.target>quote.ask&&quote.bid-plan.stop>=minimum&&plan.target-quote.bid>=minimum;
  return plan.entry<quote.ask&&quote.ask-plan.entry>=minimum&&plan.entry-plan.stop>=minimum&&plan.target-plan.entry>=minimum;}
 if(plan.signal<0){if(plan.stop<=plan.entry||plan.target>=plan.entry)return false;
  if(plan.market)return plan.stop>quote.ask&&plan.target<quote.ask&&plan.stop>quote.bid&&plan.target<quote.bid&&plan.stop-quote.ask>=minimum&&quote.ask-plan.target>=minimum;
  return plan.entry>quote.bid&&plan.entry-quote.bid>=minimum&&plan.stop-plan.entry>=minimum&&plan.entry-plan.target>=minimum;}
 return false;
}
void resetWorld(){
 P4Close(); handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();currencies.clear();quotes.clear();pairs.clear();
 connected=true;permission=true;hedging=true;diskFail=false;checkOk=true;calcOk=true;readFailure=false;tester=false;accountCurrency="USD";historySelectOk=true;positionSelectOk=true;historyRequiresSelect=false;historySelected=false;historySelectCalls=0;selectedDeals.clear();
 g_marketState=MARKET_OPEN;uptime=10000;sendMode=0;sends=0;cancels=0;modifies=0;InpMinimumLot=false;for(auto &b:laneBars)b={700,800,900,1000,1001};nextTicket=500;expiration=SYMBOL_EXPIRATION_GTC;symbolFill=SYMBOL_FILLING_FOK;symbolExec=SYMBOL_TRADE_EXECUTION_MARKET;calcMode=SYMBOL_CALC_MODE_FOREX;orderMode=51;stopLifetime=SYMBOL_ORDERS_GTC;
 for(int i=0;i<3;i++){plans[i]=P3Plan{};g_p3[i].score=0;}
 InpAutoTrading=false;P4Init();
}
int main(){int f=0;auto check=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';f++;}};
 P4Init();check(g_p4Ready && !InpAutoTrading,"initialization and default off");
 check(P4Line(0).find("Starting")!=string::npos && P4Line(0).find("no active order")==string::npos,"initial state does not invent an empty broker scan");
 double levelValues[]={98,99,100,100.02,101,102};bool equivalent=true;
 for(int d:{-1,1})for(bool market:{false,true})for(long stops:{0,10,100})for(double entry:levelValues)for(double sl:levelValues)for(double tp:levelValues){
   P3Plan p{d,true,market,entry,sl,tp,0.05};stopPoints=stops;
   if(P4LiveLevels(current,p)!=oldLiveLevels(current,p))equivalent=false;
 }
 stopPoints=0;check(equivalent,"price reason refactor preserves original execution gate");
 // An invalid frozen plan is not sent; the same plan may be used once the
 // live quote returns to a valid range, without moving its levels.
 InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;
 current.bid=101.1;current.ask=101.12;P4Process(true);
 check(sends==0 && P4Line(0).find("Market price outside SL/TP")!=string::npos,"passed exit holds order");
 current.bid=100;current.ask=100.02;InpAutoTrading=false;
 // Frozen entry/exit levels are checked against the current executable quote.
 P3Plan buyMarket{1,true,true,100.02,99,101,0.05};
 P3Plan sellMarket{-1,true,true,100,101,99,0.05};
 P3Plan buyLimit{1,true,false,99.5,99,101,0.05};
 P3Plan sellLimit{-1,true,false,100.5,101,99,0.05};
 check(P4LiveLevels(current,buyMarket) && P4LiveLevels(current,sellMarket) && P4LiveLevels(current,buyLimit) && P4LiveLevels(current,sellLimit),"live levels initially valid");
 stopPoints=60;check(!P4LiveLevels(current,buyLimit),"broker distance checked");stopPoints=0;stopInfo=false;check(!P4LiveLevels(current,buyMarket),"missing stop distance held");stopInfo=true;
 MqlTick moved=current;moved.bid=101.1;moved.ask=101.12;
 check(!P4LiveLevels(moved,buyMarket) && !P4LiveLevels(moved,sellLimit),"passed market target or sell limit is held");
 moved.bid=98.9;moved.ask=98.92;
 check(!P4LiveLevels(moved,sellMarket) && !P4LiveLevels(moved,buyLimit),"passed sell target or buy limit is held");
 plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;P4Process(true);check(sends==0,"off does not send");
 InpAutoTrading=true;hedging=false;P4Process(true);check(sends==0 && P4Line(0).find("Hedging")!=string::npos,"netting does not send");
 hedging=true;checkOk=false;P4Process(true);check(sends==0 && !g_p4[0].active,"rejected preflight does not journal or send");
 checkOk=true;uptime+=6000;P4Process(true);check(sends==1 && g_p4[0].active && g_p4[0].order==100,"market request journals order");
 P4Process(true);check(g_p4View[0].state==P4_OPEN && sends==1 && P4Line(0).find("BUY OPEN")!=string::npos,"broker-confirmed market position");
 readFailure=true;P4Process(true);check(g_p4View[0].state==P4_UNCERTAIN && sends==1,"broker read failure blocks decisions");readFailure=false;
 plans[1]={-1,true,false,100.5,102,99,0.05};g_p3[1].score=-2;uptime+=6000;P4Process(true);P4Process(true);
 check(sends==2 && g_p4View[1].state==P4_PENDING && P4Line(1).find("distance")!=string::npos,"pending sell limit and distance");
 plans[1].signal=P3_WAIT;permission=false;P4Process(false);check(g_p4[1].cancel && cancels==0,"WAIT latches cancellation when permission unavailable");
 plans[1].signal=-1;permission=true;uptime+=6000;P4Process(false);check(cancels==1 && orders.empty(),"sticky cancellation on signal change");
 P4Process(false);check(!g_p4[1].active && positions.size()==1,"broker confirms cancellation without closing position");
 plans[1]={-1,true,false,100.5,102,99,0.05};uptime+=6000;P4Process(true);
 check(sends==2 && P4Line(1).find("Waiting for next closed bar")!=string::npos,"same signal waits after cancellation");
 laneBars[1].push_back(1002);plans[1].bar=1001;P4Process(true);P4Process(true);check(g_p4View[1].state==P4_PENDING,"same signal can place after a new own bar");
 InpAutoTrading=false;uptime+=6000;P4Process(false);P4Process(false);check(cancels==2 && positions.size()==1 && sends==3,"off cancels limits and preserves open position");
 InpAutoTrading=true;plans[1].signal=0;auto first=positions[0];deals.push_back({first.id,DEAL_ENTRY_OUT,first.lot});positions.clear();uptime+=6000;P4Process(true);
 check(sends==3 && positions.empty() && P4Line(0).find("Waiting for next closed bar")!=string::npos,"confirmed closure waits before same-signal re-entry");
 laneBars[0].push_back(1002);plans[0].bar=1001;P4Process(true);
 check(sends==4 && positions.size()==1,"next own bar permits re-entry on same signal");
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
 // A reduced pending remainder is canceled even before its position appears.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 orders[0].lot=0.03;uptime+=6000;P4Process(false);check(orders.empty() && cancels==1,"partial remainder is canceled before position synchronization");
 P4Process(false);check(g_p4View[0].state==P4_UNCERTAIN,"missing partial-fill identity holds lane for reconciliation");
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
 resetWorld();Order unknown;unknown.ticket=999;unknown.magic=P4Magic(0);unknown.type=ORDER_TYPE_BUY_LIMIT;unknown.entry=99;unknown.sl=98;unknown.tp=101;unknown.lot=0.01;unknown.initial=0.01;unknown.symbol=_Symbol;unknown.comment="other";orders.push_back(unknown);
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
 // A new own-lane plan changes the broker's pending entry/SL/TP, not volume.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 P4Process(true);P4Process(false);double originalLot=orders[0].lot;datetime birth=g_p4[0].birthBar;
 laneBars[0].push_back(1002);plans[0].bar=1001;plans[0].entry=99.7;plans[0].stop=98.8;plans[0].target=100.8;uptime+=6000;
 P4Process(true);check(modifies==1 && g_p4[0].modifying && orders[0].entry==99.7 && orders[0].lot==originalLot,"pending plan modification sent once without changing volume");
 P4Close();P4Init();P4Process(false);
 check(g_p4View[0].state==P4_PENDING && !g_p4[0].modifying && g_p4View[0].entry==99.7 && g_p4[0].birthBar==birth,"restart confirms broker-modified prices and preserves original age");
 P4Process(false);check(modifies==1,"same bar does not reprice again");
 // Actual pending lot cannot be silently replaced with a lower-risk displayed lot.
 laneBars[0].push_back(1003);plans[0].bar=1002;plans[0].entry=99.6;plans[0].lot=0.02;uptime+=6000;
 P4Process(true);P4Process(false);check(orders.empty() && modifies==1 && cancels==1,"new plan with lower allowed lot cancels instead of increasing risk");
 // Failed or uncertain pending modification latches cancellation, survives restart.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 laneBars[0].push_back(1002);plans[0].bar=1001;plans[0].entry=99.7;plans[0].stop=98.8;sendMode=6;uptime+=6000;P4Process(true);
 check(g_p4[0].cancel && g_p4[0].modifying && orders.size()==1,"uncertain modification requests cancellation without assuming new levels");
 P4Close();P4Init();sendMode=0;uptime+=6000;P4Process(false);P4Process(false);
 check(orders.empty() && !g_p4[0].active,"uncertain modification cancellation survives restart");
 // Accepted-but-unconfirmed modification cannot silently become authoritative.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 laneBars[0].push_back(1002);plans[0].bar=1001;plans[0].entry=99.7;plans[0].stop=98.8;sendMode=8;uptime+=6000;P4Process(true);P4Process(false);
 check(g_p4[0].cancel && orders[0].entry==99.9,"accepted response with old broker levels latches cancellation");
 sendMode=0;uptime+=6000;P4Process(false);P4Process(false);check(orders.empty(),"unconfirmed modification is canceled");
 // If the order fills during modification, retain the broker position and exits.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 laneBars[0].push_back(1002);plans[0].bar=1001;plans[0].entry=99.7;plans[0].stop=98.8;sendMode=7;uptime+=6000;P4Process(true);P4Process(false);
 check(positions.size()==1 && orders.empty() && g_p4View[0].state==P4_OPEN && positions[0].sl==99,"modify/fill race preserves broker-confirmed position and exits");
 // WAIT for an open position never closes or modifies it.
 plans[0].signal=P3_WAIT;P4Process(false);check(positions.size()==1 && cancels==0,"WAIT leaves open position untouched");
 // Three actual own-timeframe bar closes expire the order, even through gaps.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 laneBars[0].push_back(5000);plans[0].bar=1001;uptime+=6000;P4Process(false);check(orders.size()==1,"one actual close, not elapsed time, does not expire");
 laneBars[0].push_back(5001);plans[0].bar=5000;uptime+=6000;P4Process(false);check(orders.size()==1,"two closes do not expire");
 laneBars[0].push_back(5002);plans[0].bar=5001;uptime+=6000;P4Process(true);check(orders.empty() && g_p4[0].cooldown,"third actual close requests cancellation");
 P4Process(true);check(sends==1 && !g_p4[0].active && g_p4[0].cooldown,"confirmed expiry does not immediately replace");
 P4Close();P4Init();P4Process(true);check(sends==1 && g_p4[0].cooldown,"expiry cooldown survives restart");
 laneBars[0].push_back(5003);plans[0].bar=5002;uptime+=6000;P4Process(true);
 check(sends==2 && !g_p4[0].cooldown,"subsequent own-lane close permits repeat");
 // After expiry any replacement, including an opposite signal, waits for a new bar.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 laneBars[0].insert(laneBars[0].end(),{1002,1003,1004});plans[0].bar=1003;uptime+=6000;P4Process(false);P4Process(false);
 check(g_p4[0].cooldown==2 && !g_p4[0].active,"expiry waits for any direction");
 plans[0]={-1,true,true,100,101,99,0.05,1003};g_p3[0].score=-3;uptime+=6000;P4Process(true);
 check(sends==1 && positions.empty() && P4Line(0).find("Waiting for next closed bar")!=string::npos,"opposite signal waits after expiry");
 laneBars[0].push_back(1005);plans[0].bar=1004;uptime+=6000;P4Process(true);
 check(sends==2 && positions.size()==1,"opposite signal can enter after the next own bar");
 // If the birth bar cannot be found, do not silently reset the order age.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 laneBars[0]={3000,3001};plans[0].bar=3000;uptime+=6000;P4Process(false);
 check(orders.empty() && g_p4[0].cooldown,"unknown birth history requests cancellation and cooldown");
 // Upgrading +/-2 to +/-3 cancels and awaits a later own-bar close.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 g_p3[0].score=3;plans[0].market=true;plans[0].entry=100.02;uptime+=6000;P4Process(true);P4Process(true);
 check(orders.empty() && sends==1 && g_p4[0].cooldown,"market upgrade cancels without immediate replacement");
 laneBars[1].push_back(1002);P4Process(true);check(sends==1,"another timeframe cannot release cooldown");
 laneBars[0].push_back(1002);plans[0].bar=1001;uptime+=6000;P4Process(true);check(sends==2 && positions.size()==1,"market upgrade re-enters on subsequent own close");
 // SELL upgrade, expiry coinciding with WAIT, and cancellation retries.
 resetWorld();InpAutoTrading=true;plans[2]={-1,true,false,100.5,102,99,0.05};g_p3[2].score=-2;P4Process(true);P4Process(false);
 plans[2].market=true;plans[2].entry=100;g_p3[2].score=-3;uptime+=6000;P4Process(true);P4Process(true);
 check(orders.empty() && g_p4[2].cooldown && sends==1,"sell upgrade requests cancellation and cooldown");
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 laneBars[0].insert(laneBars[0].end(),{1002,1003,1004});plans[0].bar=1003;plans[0].signal=P3_WAIT;sendMode=3;uptime+=6000;P4Process(false);
 check(g_p4[0].cancel && g_p4[0].cooldown && orders.size()==1,"expiry and WAIT both preserve the cooldown during failed cancel");
 laneBars[0].push_back(1005);plans[0].bar=1004;plans[0].signal=1;sendMode=0;uptime+=6000;P4Process(false);P4Process(true);
 check(orders.empty() && sends==1 && g_p4[0].cooldown,"cooldown begins at broker-confirmed cancellation, not earlier request");
 laneBars[0].push_back(1006);plans[0].bar=1005;uptime+=6000;P4Process(true);check(sends==2,"next bar after confirmed cancellation allows entry");
 // A new limit whose target fails the spread check is not placed.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,99.91,0.05};g_p3[0].score=2;P4Process(true);
 check(sends==0 && P4Line(0).find("spread")!=string::npos,"limit target must clear live spread before placement");
 // A live spread beyond target distance cancels the existing limit.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,100.2,0.05};g_p3[0].score=2;current={100,100.02,terminalTime};P4Process(true);P4Process(false);
 current={100,100.4,terminalTime};uptime+=6000;P4Process(false);check(orders.empty() && cancels==1,"excess spread cancels pending");current={100,100.02,terminalTime};
 // A plan HOLD cancels only the pending, not an existing open position.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 plans[0].valid=false;uptime+=6000;P4Process(false);check(orders.empty() && cancels==1,"unsuitable plan cancels pending");
 // A version-1 pending journal has unknown age: migrate and cancel it,
 // never infer that an already-resting order has just been placed.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 unsigned long oldTicket=g_p4[0].order;P4Close();int legacy=FileOpen(g_p4File,FILE_WRITE|FILE_BIN|g_p4Flags);
 FileWriteInteger(legacy,1297368116,INT_VALUE);FileWriteInteger(legacy,1,INT_VALUE);
 for(int k=0;k<3;k++){FileWriteInteger(legacy,k==0?1:0,INT_VALUE);FileWriteInteger(legacy,k==0?1:0,INT_VALUE);FileWriteInteger(legacy,0,INT_VALUE);FileWriteLong(legacy,k==0?(long)oldTicket:0);FileWriteLong(legacy,0);}FileClose(legacy);
 P4Init();uptime+=6000;P4Process(false);check(orders.empty() && g_p4[0].cooldown,"legacy pending with unknown age is migrated and cancelled");
 // Legacy journals do not cause already-open positions to be closed.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;P4Process(true);P4Process(false);
 unsigned long legacyOrder=g_p4[0].order,legacyPos=g_p4[0].position;P4Close();legacy=FileOpen(g_p4File,FILE_WRITE|FILE_BIN|g_p4Flags);
 FileWriteInteger(legacy,1297368116,INT_VALUE);FileWriteInteger(legacy,1,INT_VALUE);
 for(int k=0;k<3;k++){FileWriteInteger(legacy,k==0?1:0,INT_VALUE);FileWriteInteger(legacy,k==0?1:0,INT_VALUE);FileWriteInteger(legacy,0,INT_VALUE);FileWriteLong(legacy,k==0?(long)legacyOrder:0);FileWriteLong(legacy,k==0?(long)legacyPos:0);}FileClose(legacy);
 P4Init();P4Process(false);check(positions.size()==1 && g_p4View[0].state==P4_OPEN && cancels==0,"legacy open position remains open");
 // OFF never conceals unresolved intent; three rows retain independent state.
 resetWorld();current={100,100.02,terminalTime};
 g_p4[0].active=1;g_p4[0].direction=1; // no ticket is not proof of no trade
 g_p4[1].active=1;g_p4[1].direction=1;g_p4[1].order=700;
 Order h;h.ticket=700;h.state=ORDER_STATE_CANCELED;h.initial=0.05;h.lot=0.05;history[700]=h;
 P4Process(false);
 check(P4Line(0).find("M5 | Auto: OFF | REVIEW: no order ticket")!=string::npos,"off and unresolved intent visible together");
 check(P4Line(1)=="M15 | Auto: OFF" && P4Line(2)=="M30 | Auto: OFF","confirmed empty off rows remain separate");
 check(P4Tooltip(0).find("cannot prove")!=string::npos && P4Tooltip(1).find("OFF")!=string::npos,"review and mode tooltip");
 InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;plans[1].signal=0;plans[2].signal=P3_WAIT;P4Process(true);
 check(sends==0 && P4Line(0).find("ON | REVIEW: no order ticket")!=string::npos,"unidentified intent blocks repeat even while on");
 check(P4Line(1).find("no active order | No qualifying signal")!=string::npos && P4Line(2).find("Signal WAIT")!=string::npos,"empty signals reported per lane");
 // Sticky cancellation retains its original reason over timer refreshes.
 resetWorld();current={100,100.02,terminalTime};InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 plans[0].signal=P3_WAIT;permission=false;P4Process(false);plans[0].signal=1;P4Process(false);
 check(P4Line(0).find("Signal WAIT: cancel pending")!=string::npos && g_p4[0].cancel,"sticky cancellation displays original reason across timer refresh");
 // On restart the cancellation intent persists but its reason was not saved.
 P4Close();P4Init();plans[0].signal=P3_WAIT;P4Process(false);
 check(g_p4[0].cancel && P4Line(0).find("Cancellation pending")!=string::npos && P4Line(0).find("Signal WAIT: cancel pending")==string::npos,"restart does not invent an original cancellation reason");
 // Closed position with zero historical order position ID: require final order,
 // saved position, matching entry deal and fully matching exits.
 resetWorld();g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=701;g_p4[0].position=901;
 h=Order{};h.ticket=701;h.state=ORDER_STATE_FILLED;h.position=0;history[701]=h;
 deals={{901,DEAL_ENTRY_IN,0.05,999},{901,DEAL_ENTRY_OUT,0.05,0}};
 P4Process(false);check(g_p4[0].active && P4Line(0).find("link or closure unconfirmed")!=string::npos,"closed unrelated position cannot clear saved order");
 deals[0].order=701;deals[1].vol=0.02;P4Process(false);
 check(g_p4[0].active && P4Line(0).find("link or closure unconfirmed")!=string::npos,"matching entry without full exit remains held");
 deals[1].vol=0.05;history[701].state=99;P4Process(false);
 check(g_p4[0].active && P4Line(0).find("order not final")!=string::npos,"complete deals cannot override nonfinal order");
 history[701].state=ORDER_STATE_FILLED;P4Process(false);
 check(!g_p4[0].active && P4Line(0)=="M5 | Auto: OFF","linked complete deals and final order reconcile");
 // Other history ambiguities cannot be mistaken for a closed position.
 resetWorld();g_p4[1].active=1;g_p4[1].direction=1;g_p4[1].order=702;g_p4[1].position=902;
 P4Process(false);check(P4Line(1).find("order history unavailable")!=string::npos,"missing history reason");
 h=Order{};h.ticket=702;h.state=ORDER_STATE_FILLED;h.position=903;history[702]=h;P4Process(false);
 check(g_p4[1].active && P4Line(1).find("position ID mismatch")!=string::npos,"mismatched position held");
 history[702].position=902;deals={{902,DEAL_ENTRY_IN,0.05,702},{902,DEAL_ENTRY_OUT,0.02,0}};P4Process(false);
 check(g_p4[1].active && P4Line(1).find("position history incomplete")!=string::npos,"partial exit held");
 // A final filled order can recover an unsaved position ID from its own deals.
 resetWorld();current={100,100.02,terminalTime};
 g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=710;
 g_p4[1].active=1;g_p4[1].direction=-1;g_p4[1].order=711;
 g_p4[2].active=1;g_p4[2].direction=1;g_p4[2].order=712;
 for(unsigned long tk:{710UL,711UL,712UL}){h=Order{};h.ticket=tk;h.state=ORDER_STATE_FILLED;h.position=0;h.initial=(tk==710?0.05:tk==711?0.04:0.03);history[tk]=h;}
 deals={{910,DEAL_ENTRY_IN,0.05,710},{910,DEAL_ENTRY_OUT,0.05,777},
        {911,DEAL_ENTRY_IN,0.04,711},{911,DEAL_ENTRY_OUT,0.02,778},
        {912,DEAL_ENTRY_IN,0.03,712},{912,DEAL_ENTRY_OUT,0.03,779}};
 P4Process(false);
 check(!g_p4[0].active && g_p4[1].active && !g_p4[2].active,"only complete own-order deal histories clear their lanes");
 check(P4Line(0)=="M5 | Auto: OFF" && P4Line(1).find("fill not confirmed closed")!=string::npos && P4Line(2)=="M30 | Auto: OFF","recovered closure and incomplete exit labels stay separate");
 deals[3].vol=0.04;uptime+=5000;P4Process(false);check(!g_p4[1].active,"completed later exit reconciles on retry");
 // Once the old fill is proven closed, the lane waits for a new plan.
 resetWorld();current={100,100.02,terminalTime};InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;
 g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=718;
 h=Order{};h.ticket=718;h.state=ORDER_STATE_FILLED;h.initial=0.05;history[718]=h;
 deals={{918,DEAL_ENTRY_IN,0.05,718},{918,DEAL_ENTRY_OUT,0.05,799}};
 P4Process(true);P4Process(false);check(sends==0 && positions.empty() && P4Line(0).find("Waiting for next closed bar")!=string::npos,"confirmed closed fill waits for a fresh plan");
 laneBars[0].push_back(1002);plans[0].bar=1001;P4Process(true);P4Process(false);
 check(sends==1 && positions.size()==1 && g_p4View[0].state==P4_OPEN,"new own-timeframe plan permits re-entry");
 // A seemingly closed subset of the filled order is not the whole fill.
 resetWorld();g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=719;
 h=Order{};h.ticket=719;h.state=ORDER_STATE_FILLED;h.initial=0.05;history[719]=h;
 deals={{919,DEAL_ENTRY_IN,0.02,719},{919,DEAL_ENTRY_OUT,0.02,799}};P4Process(false);
 check(g_p4[0].active && P4Line(0).find("fill not confirmed closed")!=string::npos,"closed partial history cannot clear a larger filled order");
 deals[0].vol=0.05;deals[1].vol=0.05;uptime+=5000;P4Process(false);check(!g_p4[0].active,"all filled order volume must be accounted for");
 // A partial cancellation can also be reconciled by linked entry and exit deals.
 resetWorld();g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=720;
 h=Order{};h.ticket=720;h.state=ORDER_STATE_CANCELED;h.initial=0.05;h.lot=0.03;history[720]=h;
 deals={{920,DEAL_ENTRY_IN,0.02,720},{920,DEAL_ENTRY_OUT,0.02,799}};
 P4Process(false);check(!g_p4[0].active,"closed partial fill of final cancelled order reconciles");
 // Some brokers zero the remainder of a cancelled partial order; do not
 // assume its incomplete deal history accounts for the whole order.
 resetWorld();g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=720;
 h=Order{};h.ticket=720;h.state=ORDER_STATE_CANCELED;h.initial=0.05;h.lot=0;history[720]=h;
 deals={{920,DEAL_ENTRY_IN,0.02,720},{920,DEAL_ENTRY_OUT,0.02,799}};P4Process(false);
 check(g_p4[0].active && P4Line(0).find("partial fill unconfirmed")!=string::npos,"zeroed remainder cannot prove incomplete partial fill history");
 // No match, unknown/reversed entry or multiple position IDs never clear a journal.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;
 g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=721;h=Order{};h.ticket=721;h.state=ORDER_STATE_FILLED;h.initial=0.05;history[721]=h;
 deals={{921,DEAL_ENTRY_IN,0.05,999},{921,DEAL_ENTRY_OUT,0.05,800}};P4Process(true);
 check(sends==0 && g_p4[0].active && P4Line(0).find("fill not confirmed closed")!=string::npos,"unrelated deals do not identify a fill");
 int calls=historySelectCalls;P4Process(true);check(historySelectCalls==calls && sends==0 && P4Line(0).find("fill not confirmed closed")!=string::npos,"unresolved history search is throttled without changing its label");
 deals={{921,DEAL_ENTRY_IN,0.02,721},{921,DEAL_ENTRY_OUT,0.02,800},{922,DEAL_ENTRY_IN,0.03,721},{922,DEAL_ENTRY_OUT,0.03,801}};uptime+=5000;P4Process(true);
 check(sends==0 && g_p4[0].active && P4Line(0).find("fill not confirmed closed")!=string::npos,"one order linked to multiple position IDs stays held");
 deals={{921,DEAL_ENTRY_INOUT,0.05,721},{921,DEAL_ENTRY_OUT,0.05,800}};uptime+=5000;P4Process(true);
 check(sends==0 && g_p4[0].active,"reversal does not prove a safe entry and closure");
 deals={{921,DEAL_ENTRY_IN,0.05,721},{921,DEAL_ENTRY_OUT,0.05,800}};historySelectOk=false;uptime+=5000;P4Process(true);
 check(sends==0 && g_p4[0].active,"failed history selection cannot release intent");
 historySelectOk=true;positionSelectOk=false;uptime+=5000;P4Process(true);
 check(sends==0 && g_p4[0].active && P4Line(0).find("fill not confirmed closed")!=string::npos,"unavailable position history cannot prove closure");
 positionSelectOk=true;uptime+=5000;P4Process(false);check(!g_p4[0].active,"complete history is retried and reconciles without manual reset");
 // If the terminal needs an explicit history selection, retry the saved ticket.
 resetWorld();g_p4[2].active=1;g_p4[2].direction=1;g_p4[2].order=722;
 h=Order{};h.ticket=722;h.state=ORDER_STATE_CANCELED;h.initial=0.05;h.lot=0.05;history[722]=h;historyRequiresSelect=true;
 P4Process(false);check(!g_p4[2].active && historySelectCalls==1,"explicit history selection recovers saved final order");
 resetWorld();g_p4[2].active=1;g_p4[2].direction=1;g_p4[2].order=723;historyRequiresSelect=true;
 P4Process(false);check(g_p4[2].active && P4Line(2).find("order history unavailable")!=string::npos,"missing saved order stays held after history selection");
 // A live position can be linked by its entry deal when the order ID is zero.
 resetWorld();g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=724;
 h=Order{};h.ticket=724;h.state=ORDER_STATE_FILLED;history[724]=h;
 part=Position{};part.id=924;part.ticket=1924;part.magic=P4Magic(0);part.type=POSITION_TYPE_BUY;part.entry=100;part.sl=99;part.tp=101;part.lot=0.05;part.symbol=_Symbol;part.comment="MT4-M5";positions.push_back(part);
 deals={{924,DEAL_ENTRY_IN,0.05,724}};P4Process(false);
 check(g_p4View[0].state==P4_OPEN && g_p4[0].position==924 && P4Line(0).find("BUY OPEN")!=string::npos,"live position linked by entry deal without order position ID");
 resetWorld();g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=724;h.position=925;history[724]=h;positions.push_back(part);deals={{924,DEAL_ENTRY_IN,0.05,724}};
 P4Process(false);check(g_p4View[0].state==P4_UNCERTAIN && g_p4[0].position==0,"conflicting broker order position ID cannot be overridden by a deal");
 // The current live blocker is visible on timer refresh without an order send.
 resetWorld();current={100,100.02,terminalTime};InpAutoTrading=true;
 plans[0]={1,true,false,100.1,99,101,0.05};g_p3[0].score=2;
 plans[1]={-1,true,false,99.9,101,99,0.05};g_p3[1].score=-2;
 plans[2]={1,true,true,100.02,99,101,0.05};g_p3[2].score=3;P4Process(false);
 g_p4Attempt[2]=uptime;P4Process(false);check(P4Line(2).find("Request retry delay")!=string::npos,"request pacing reason visible");g_p4Attempt[2]=0;P4Process(false);
 check(sends==0 && P4Line(0).find("BUY limit not below Ask")!=string::npos && P4Line(1).find("SELL limit not above Bid")!=string::npos,"invalid limits report exact lane and side");
 check(P4Line(2).find("Ready: waiting for tick")!=string::npos && P4Tooltip(0).find("below the current Ask")!=string::npos,"ready and price tooltips");
 permission=false;P4Process(false);check(P4Line(2).find("Trading permission unavailable")!=string::npos,"permission blocker visible on timer");permission=true;
 current.time=terminalTime-20;P4Process(false);check(P4Line(2).find("Fresh quote unavailable")!=string::npos,"stale quote blocker visible");current.time=terminalTime;
 hedging=false;P4Process(false);check(P4Line(2).find("Hedging account required")!=string::npos,"hedging blocker visible");hedging=true;
 g_marketState=1;P4Process(false);check(P4Line(2).find("Market not open")!=string::npos,"market blocker visible");g_marketState=MARKET_OPEN;
 checkOk=false;P4Process(true);P4Process(false);check(P4Line(2).find("Order check: 10019")!=string::npos && P4Line(2).find("Not enough money")!=string::npos && sends==0,"broker check reason survives timer");
 checkOk=true;uptime+=6000;P4Process(true);P4Process(false);check(sends==1 && P4Line(2).find("BUY OPEN")!=string::npos,"successful retry replaces old check reason");
 InpAutoTrading=false;P4Process(false);check(P4Line(2).find("Auto: OFF | BUY OPEN")!=string::npos,"off retains broker open-position details");
 // Definite broker rejection survives refresh; uncertain outcomes never get released.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;sendMode=2;
 P4Process(true);P4Process(false);check(P4Line(0).find("Order rejected: 10006")!=string::npos && !g_p4[0].active,"definite reject reason survives refresh");
 // Contradictory reject plus a deal ticket is not a definite no-fill.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;sendMode=9;
 P4Process(true);uptime+=6000;P4Process(true);
 check(sends==1 && g_p4[0].active && P4Line(0).find("REVIEW: no order ticket")!=string::npos,"reject with deal evidence cannot clear intent or resend");
 // A rejected pending update reports its actual pre-check and retains it.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 laneBars[0].push_back(1002);plans[0].bar=1001;plans[0].entry=99.7;checkOk=false;sendMode=3;uptime+=6000;P4Process(false);P4Process(false);
 check(P4Line(0).find("Pending modification check: 10019")!=string::npos && P4Line(0).find("Not enough money")!=string::npos && g_p4[0].cancel,"pending modification pre-check reason survives refresh");
 // A missing SL warning survives a partial-fill cancellation request.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 orders[0].position=900;part=Position{};part.id=900;part.ticket=901;part.magic=P4Magic(0);part.type=POSITION_TYPE_BUY;part.entry=99.9;part.sl=0;part.tp=101;part.lot=0.02;part.symbol=_Symbol;part.comment="MT4-M5";positions.push_back(part);deals.push_back({900,DEAL_ENTRY_IN,0.02});
 uptime+=6000;sendMode=3;P4Process(false);
 check(P4Line(0).find("SL/TP missing: REVIEW")!=string::npos && P4Line(0).find("cancel remainder")!=string::npos && P4Tooltip(0).find("SL or TP is missing")!=string::npos,"partial cancellation does not hide missing protection");
 // A cooldown established with missing bar history is initialized when bars return.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;
 g_p4[0].cooldown=2;g_p4[0].waitBar=0;P4Process(true);
 check(g_p4[0].waitBar==1000 && sends==0,"cooldown obtains first available closed bar");
 laneBars[0].push_back(1002);plans[0].bar=1001;uptime+=6000;P4Process(true);
 check(sends==1,"cooldown releases only after later own close");
 // Every emitted auto-status label has an explanation rather than a generic fallback.
 string notes[]={"Starting","Disconnected","Position scan unavailable","Position data unavailable","Order scan unavailable","Order data unavailable",
 "MULTIPLE: REVIEW","Untracked broker object: REVIEW","Position identity: REVIEW","Order identity: REVIEW","Unconfirmed intent: REVIEW",
 "Waiting for broker identity","Partial-fill identity: REVIEW","REVIEW: no order ticket","REVIEW: order history unavailable",
 "REVIEW: order history data unavailable","REVIEW: order not final","REVIEW: position ID mismatch","REVIEW: position history incomplete",
 "REVIEW: link or closure unconfirmed","REVIEW: fill not confirmed closed","REVIEW: order volumes unavailable","REVIEW: partial fill unconfirmed",
 "Journal unavailable","Market request in flight","Position SL/TP missing: REVIEW; Entry remainder pending","Pending target does not clear spread",
 "Pending target does not clear spread; cancel","Partial fill: cancel remainder","Auto OFF: cancel pending","Signal WAIT: cancel pending",
 "No signal: cancel pending","Signal changed: cancel pending","Market upgrade: cancel pending","Pending age unavailable: cancel","Pending expired: cancel",
 "Pending modification check: 10019; cancel","Pending lot differs from allowed: cancel","Pending update: BUY limit not below Ask; cancel",
 "Pending volume step unavailable: cancel","Pending price tick unavailable: cancel","Pending volume/identity uncertain: cancel",
 "Pending plan unsuitable: cancel","Pending modification unconfirmed: cancel","Cancellation pending","Cancellation requested (10009)",
 "Modification requested (10009); awaiting broker","Order result 10009; awaiting broker","Order rejected: 10006","Order check: 10019",
 "Signal WAIT","Signal unavailable","No qualifying signal","Hedging account required","Trading permission unavailable","Market not open",
 "Plan data unavailable","Waiting for next closed bar","Fresh quote unavailable","BUY limit not below Ask","SELL limit not above Bid",
 "Market price outside SL/TP","Plan SL/TP invalid","Broker minimum distance not met","Broker stops or plan data unavailable",
 "SL/TP lifetime or order mode unavailable","Filling mode unavailable","Request retry delay","Ready: waiting for tick"};
 for(auto &note:notes)check(P4Explain(note)!="Check the auto-trading row, broker orders and MT5 Experts log for details.","auto status has a specific tooltip");
 check(P4Explain("Order check: 10019 pending target does not clear spread; Pending modification check: 10019").find("pre-check failed")!=string::npos,"broker comment cannot replace check tooltip with unrelated warning");
 check(P4Explain("Pending modification check: 10019 target does not clear spread").find("pre-check")!=string::npos,"broker modification comment cannot replace check tooltip");
 // Closed positions wait independently for each lane's next bar and plan.
 resetWorld();current={100,100.02,terminalTime};InpAutoTrading=true;
 plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;
 plans[1]={-1,true,true,100,101,99,0.03};g_p3[1].score=-3;
 P4Process(true);P4Process(false);check(sends==2 && positions.size()==2,"two independent positions opened");
 for(auto &pos:positions){deals.push_back({pos.id,DEAL_ENTRY_OUT,pos.lot});}positions.clear();
 plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 P4Process(false);
 check(P4Line(0).find("Waiting for next closed bar")!=string::npos && P4Line(1).find("Waiting for next closed bar")!=string::npos && P4Tooltip(0).find("position closure")!=string::npos,"closed positions show a new-bar wait per timeframe");
 P4Close();P4Init();P4Process(true);check(sends==2 && positions.empty(),"closure wait survives restart for both directions");
 laneBars[0].push_back(1002);plans[0].bar=1001;plans[0].entry=99.7;plans[0].stop=98.8;plans[0].target=100.8;uptime+=6000;P4Process(true);P4Process(false);
 check(sends==3 && orders.size()==1 && lastRequest.action==TRADE_ACTION_PENDING && abs(lastRequest.price-99.7)<1e-9 && abs(lastRequest.tp-100.8)<1e-9,"M5 new-bar limit uses refreshed plan");
 check(P4Line(1).find("Waiting for next closed bar")!=string::npos,"M5 bar does not release M15 wait");
 laneBars[1].push_back(1002);plans[1].bar=1001;plans[1].stop=101.2;plans[1].target=99.2;uptime+=6000;P4Process(true);P4Process(false);
 check(sends==4 && positions.size()==1 && lastRequest.action==TRADE_ACTION_DEAL && lastRequest.type==ORDER_TYPE_SELL && abs(lastRequest.sl-101.2)<1e-9 && abs(lastRequest.tp-99.2)<1e-9,"M15 new-bar market request uses refreshed exits");
 // A filled limit is an open position; do not replace it on later bars.
 // Once it closes, start a fresh wait, independent of its original fill bar.
 resetWorld();current={100,100.02,terminalTime};InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 h=orders[0];orders.clear();h.position=980;h.state=ORDER_STATE_FILLED;history[h.ticket]=h;
 part=Position{};part.id=980;part.ticket=1980;part.magic=P4Magic(0);part.type=POSITION_TYPE_BUY;part.entry=99.9;part.sl=99;part.tp=101;part.lot=0.05;part.symbol=_Symbol;part.comment="MT4-M5";positions.push_back(part);deals={{980,DEAL_ENTRY_IN,0.05,h.ticket}};
 P4Process(false);check(P4Line(0).find("BUY OPEN")!=string::npos,"filled limit becomes an open position");
 laneBars[0].push_back(1002);plans[0].bar=1001;uptime+=6000;P4Process(true);
 check(sends==1 && positions.size()==1,"no replacement while filled position remains open");
 deals.push_back({980,DEAL_ENTRY_OUT,0.05,999});positions.clear();uptime+=6000;P4Process(true);
 check(sends==1 && P4Line(0).find("Waiting for next closed bar")!=string::npos,"closed filled limit waits for the bar after closure confirmation");
 laneBars[0].push_back(1003);plans[0].bar=1002;plans[0].entry=100.5;P4Process(true);
 check(sends==1 && P4Line(0).find("BUY limit not below Ask")!=string::npos,"new bar still reports any live-price blocker");
 laneBars[0].push_back(1004);plans[0].bar=1003;plans[0].entry=99.8;uptime+=6000;P4Process(true);
 check(sends==2 && orders.size()==1,"later valid plan may enter after the wait");
 // A broker-cancelled limit without an explicit MT cancel request also waits.
 resetWorld();current={100,100.02,terminalTime};InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=800;h=Order{};h.ticket=800;h.state=ORDER_STATE_CANCELED;h.initial=0.05;h.lot=0.05;history[800]=h;
 P4Process(true);check(sends==0 && P4Line(0).find("Waiting for next closed bar")!=string::npos,"external broker cancellation waits for next bar");
 // A rejected remainder with a proven partial fill still ended a trade.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;
 g_p4[0].active=1;g_p4[0].direction=1;g_p4[0].order=801;h=Order{};h.ticket=801;h.state=ORDER_STATE_REJECTED;h.initial=0.05;h.lot=0.03;history[801]=h;
 deals={{981,DEAL_ENTRY_IN,0.02,801},{981,DEAL_ENTRY_OUT,0.02,999}};P4Process(true);
 check(!g_p4[0].active && g_p4[0].cooldown==2 && sends==0 && P4Line(0).find("Waiting for next closed bar")!=string::npos,"closed partial fill on rejected remainder waits for next bar");
 // The wait follows confirmation, not a cancellation request or a bar that
 // closed while the broker was still processing that request.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,false,99.9,99,101,0.05};g_p3[0].score=2;P4Process(true);P4Process(false);
 plans[0].signal=0;sendMode=3;uptime+=6000;P4Process(false);
 laneBars[0].push_back(1002);plans[0].bar=1001;plans[0]={-1,true,true,100,101,99,0.05,1001};g_p3[0].score=-3;
 sendMode=0;uptime+=6000;P4Process(false);P4Process(true);
 check(sends==1 && positions.empty() && P4Line(0).find("Waiting for next closed bar")!=string::npos,"a bar before confirmation cannot release cancellation wait");
 laneBars[0].push_back(1003);plans[0].bar=1002;uptime+=6000;P4Process(true);check(sends==2 && positions.size()==1,"new bar after confirmed cancellation permits opposite market plan");
 // Old persisted same-direction-only expiry waits migrate to the new policy.
 resetWorld();g_p4[0].cooldown=1;g_p4[0].waitDirection=1;g_p4[0].waitBar=1000;P4Persist();P4Close();P4Init();
 InpAutoTrading=true;plans[0]={-1,true,true,100,101,99,0.05};g_p3[0].score=-3;P4Process(true);
 check(g_p4[0].cooldown==2 && sends==0 && P4Line(0).find("Waiting for next closed bar")!=string::npos,"legacy expiry wait also blocks opposite direction");
 // An unfilled definitive rejection is not a finished trade and has no bar wait.
 resetWorld();InpAutoTrading=true;plans[0]={1,true,true,100.02,99,101,0.05};g_p3[0].score=3;sendMode=2;P4Process(true);P4Process(false);
 check(g_p4[0].cooldown==0 && P4Line(0).find("Order rejected:")!=string::npos,"unfilled rejection retains the broker reason without a false bar wait");
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
