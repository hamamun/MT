#!/usr/bin/env python3
"""Exercise MT's extracted clock and market-state code with MT5 stubs, not MT5 itself."""
import pathlib, subprocess, tempfile
from test_logic import function, prefix

stubs = r'''
#include <cstdarg>
#include <cstdio>
using ulong=unsigned long;
#define MQL_TESTER 1
#define TERMINAL_CONNECTED 2
#define SYMBOL_TRADE_MODE 3
#define SYMBOL_TRADE_MODE_DISABLED 0
#define SESSION_REFRESH_SECONDS 300
#define STALE_SECONDS 1800
string _Symbol="XAUUSDm";
datetime g_clockQuote=0, g_lastObservedQuote=0, g_nextOpen=0;
ulong g_clockMillis=0;
bool g_clockAnchored=false;
datetime g_sessionsDay=0, g_lastSessionScan=0;
enum MARKET_STATE { MARKET_OPEN, MARKET_CLOSED, MARKET_STALE, MARKET_UNKNOWN, MARKET_OFFLINE, MARKET_UNAVAILABLE };
MARKET_STATE g_marketState=MARKET_UNKNOWN;
string g_marketDetail;
struct MqlTick {datetime time;};
datetime quoteTime=0, lastQuote=0, estimated=0; ulong millis=0;
bool connected=true, tester=false, tickAvailable=true; long tradeMode=1;
datetime TimeCurrent(){return lastQuote;}
datetime TimeTradeServer(){return estimated;}
ulong GetTickCount64(){return millis;}
long MQLInfoInteger(int){return tester;}
long TerminalInfoInteger(int){return connected;}
bool SymbolInfoInteger(string,int,long &v){v=tradeMode;return true;}
bool SymbolInfoTick(string,MqlTick &v){v.time=quoteTime;return tickAvailable;}
string StringFormat(const char *fmt,...) {char b[1024]; va_list args; va_start(args,fmt); vsnprintf(b,sizeof(b),fmt,args); va_end(args); return b;}
void ScanSessions(){g_sessionsDay=(lastQuote / 86400)*86400;g_lastSessionScan=lastQuote;}
'''
names=['SyncClock','ServerNow','FormatClock','IsMarketOpen','DaysInMonth','AddDays',
       'NextOpening','WeekdayShort','HumanDelta','UpdateState']
functions='\n'.join(function(x) for x in names)
main=r'''
int main(){
 int failures=0;
 auto check=[&](bool ok,const char *name){if(!ok){cerr<<"FAIL "<<name<<"\n"; failures++;}};
 MqlDateTime d={}; d.year=2026; d.mon=11; d.day=2; d.hour=10;
 datetime now=StructToTime(d);
 estimated=now+500; lastQuote=now-1000; millis=1000;
 check(ServerNow()==estimated,"startup uses MT5 estimate instead of stale quote");
 millis=2000; lastQuote=now; SyncClock(true);
 check(ServerNow()==now,"chart tick broker time anchors clock");
 millis=5200; check(ServerNow()==now+3,"clock advances between ticks");
 lastQuote=now+10; millis=6000;
 check(ServerNow()==now+10,"fresh Market Watch timestamp reanchors");
 millis=9000; check(ServerNow()==now+13,"cached timestamp does not reanchor");
 tester=true; millis=12000; lastQuote=now+20;
 check(ServerNow()==now+20,"tester uses simulated time"); tester=false;
 g_sessionsDay=now-now%86400; g_lastSessionScan=now;
 connected=false; UpdateState(now); check(g_marketState==MARKET_OFFLINE,"offline");
 connected=true; tradeMode=0; UpdateState(now); check(g_marketState==MARKET_UNAVAILABLE,"disabled");
 tradeMode=1; g_hasSessions=false; tickAvailable=false; UpdateState(now);
 check(g_marketState==MARKET_UNKNOWN && g_marketDetail.find("Open at --")!=string::npos,"no table and quote");
 tickAvailable=true; quoteTime=now-10; UpdateState(now);
 check(g_marketState==MARKET_OPEN && g_marketDetail.empty(),"no table fresh quote leaves row 2 empty");
 g_hasSessions=true; g_sessionCount[1]=1; g_sessions[1][0]={12*3600,18*3600};
 UpdateState(now); check(g_marketState==MARKET_CLOSED && g_nextOpen==now+2*3600,"closed next opening");
 check(g_marketDetail.find("MARKET CLOSED - next open Mon")!=string::npos,"closed detail");
 g_sessions[1][0]={0,18*3600}; quoteTime=now-1801; UpdateState(now);
 check(g_marketState==MARKET_STALE,"stale during session");
 quoteTime=now+5; UpdateState(now); check(g_marketState==MARKET_STALE,"future quote not fresh");
 quoteTime=now-5; UpdateState(now); check(g_marketState==MARKET_OPEN && g_marketDetail.empty(),"open fresh quote clears prior status detail");
 if(failures)return 1;
 cout<<"Broker clock and market-state regression checks passed.\n";
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=pathlib.Path(tmp); (p/'test.cpp').write_text(prefix+stubs+functions+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror',str(p/'test.cpp'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
