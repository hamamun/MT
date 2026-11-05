#!/usr/bin/env python3
"""Compile the actual trade diary with in-memory broker/file stubs, not MT5."""
from pathlib import Path
import ast, re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
module=ast.parse((root/'tests/test_auto_runtime.py').read_text())
stubs=next(ast.literal_eval(n.value) for n in module.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='stubs' for t in n.targets))
stubs=stubs.replace('#define FILE_COMMON 8','#define FILE_CSV 128\n#define FILE_ANSI 256\n#define FILE_COMMON 8')
stubs=stubs.replace('#define ACCOUNT_CURRENCY 9','#define ACCOUNT_CURRENCY 9\n#define ACCOUNT_SERVER 60\n#define ACCOUNT_LOGIN 61\n#define ACCOUNT_EQUITY 62\n#define ACCOUNT_BALANCE 63\n#define DEAL_TIME_MSC 64\n#define DEAL_REASON 65\n#define DEAL_PRICE 66\n#define DEAL_PROFIT 67\n#define DEAL_COMMISSION 68\n#define DEAL_SWAP 69\n#define DEAL_FEE 70\n#define DEAL_TYPE 71\n#define DEAL_TYPE_BUY 1\n#define DEAL_TYPE_SELL 2')
stubs=stubs.replace('bool InpMinimumLot=false;','bool InpMinimumLot=false,InpBypassRisk=false;')
stubs=stubs.replace('struct MqlTick{double bid=100,ask=100.02;datetime time=1700000000;};','struct MqlTick{double bid=100,ask=100.02;datetime time=1700000000;long time_msc=1700000000000L;};')
stubs=stubs.replace('datetime bar=1000;};','datetime bar=1000; bool barProxy=false;};')
stubs=stubs.replace('struct Lane{int score=0,volumeState=-1;};','struct Lane{int score=0,volumeState=-1,gt=1,ct=1,st=1;string regime="MIXED";};')
stubs=stubs.replace('struct Deal {unsigned long position=0;int how=0;double vol=0;unsigned long order=0;};','struct Deal {unsigned long position=0;int how=0;double vol=0;unsigned long order=0;long time=0,reason=0;double price=0,profit=0,commission=0,swap=0,fee=0;};')
stubs=stubs.replace('return p==DEAL_POSITION_ID?d.position:p==DEAL_ORDER?d.order:d.how;', 'return p==DEAL_POSITION_ID?d.position:p==DEAL_ORDER?d.order:p==DEAL_ENTRY?d.how:p==DEAL_TIME_MSC?d.time:p==DEAL_TYPE?(d.how==DEAL_ENTRY_IN?DEAL_TYPE_BUY:DEAL_TYPE_SELL):d.reason;')
stubs=stubs.replace('double HistoryDealGetDouble(unsigned long tk,int){return deals[tk-1].vol;}','double HistoryDealGetDouble(unsigned long tk,int p){auto d=deals[tk-1];return p==DEAL_VOLUME?d.vol:p==DEAL_PRICE?d.price:p==DEAL_PROFIT?d.profit:p==DEAL_COMMISSION?d.commission:p==DEAL_SWAP?d.swap:d.fee;}')
stubs=stubs.replace('return p==ORDER_STATE?history[tk].state:history[tk].position;', 'return p==ORDER_STATE?history[tk].state:p==ORDER_MAGIC?history[tk].magic:p==ORDER_TYPE?history[tk].type:history[tk].position;')
extra=r'''
template<class T> int ArraySize(const vector<T>& x){return (int)x.size();}
template<class T> int ArrayResize(vector<T>& x,int n){x.resize(n);return n;}
int FileOpen(string n,int f,int){return FileOpen(n,f);}
template<class... T> void FileWrite(int,T...){ }
double AccountInfoDouble(int){return 10000;}
bool HistoryOrderGetString(ulong id,int,string &x){if(readFailure || !history.count(id))return false;x=history[id].symbol;return true;}
int P3Choice(int){return 0;} bool P3Against(int){return true;} int P3Strategy(int){return 30004;}
'''
kernel=(root/'MT_TradeDiary.mqh').read_text().replace('#include "MT_Phase3.mqh"','')
kernel=re.sub(r'const P5Deal &(\w+)\[\]',r'const vector<P5Deal> &\1',kernel)
runtime=(root/'MT_TradeDiaryRuntime.mqh').read_text().replace('#include "MT_TradeDiary.mqh"','')
runtime=re.sub(r'\b(P5Row|P5Deal) (\w+)\[\];',r'vector<\1> \2;',runtime)
main=r'''
int main(){int fails=0;auto ck=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';fails++;}};
 P5Init();ck(g_p5Ready,"initialized");
 P3Plan plan{1,true,false,99.9,99,101,0.05,1000};g_p3[0].score=2;
 int i=P5Begin(0,plan,current);ck(i==0 && g_p5[0].accepted==0,"intent not accepted");
 P5SendResult(i,100,10009,false);P5Close();P5Init();ck(g_p5Ready && g_p5.size()==1 && g_p5[0].order==100,"restart retains intent and order");
 Order o;o.ticket=100;o.magic=123;o.type=ORDER_TYPE_BUY_LIMIT;o.symbol=_Symbol;o.entry=99.9;o.sl=99;o.tp=101;o.initial=o.lot=.05;orders.push_back(o);
 P5Track(0,1,1,100,0,1000,123);ck(g_p5[0].state==1 && g_p5[0].accepted==1,"live broker order counted");
 ck(P5Summary(0,terminalTime).find("All S 1 W 0 L 0 BE 0")!=string::npos,"accepted order summary");
 orders.clear();o.position=200;o.state=ORDER_STATE_FILLED;o.lot=0;history[100]=o;
 Position p;p.ticket=201;p.id=200;p.magic=123;p.symbol=_Symbol;positions.push_back(p);
 deals={{200,DEAL_ENTRY_IN,.05,100,1700000000001L,1,99.9,0,-.10,0,0}};
 uptime+=6000;P5Track(0,1,1,100,200,1000,123);ck(g_p5[0].state==2,"position open not win");
 positions.clear();deals.push_back({200,DEAL_ENTRY_OUT,.02,300,1700000001001L,2,101,.20,-.02,0,-.01});
 uptime+=6000;P5Track(0,0,0,0,0,0,123);ck(g_p5[0].state==6,"partial closure held");
 deals[0].vol=.02;
 uptime+=6000;P5Track(0,0,0,0,0,0,123);ck(g_p5[0].state==6,"matched subset without full order fill held");
 deals[0].vol=.05;deals.push_back({200,DEAL_ENTRY_OUT,.03,301,1700000002001L,2,101,.30,-.03,-.04,0});
 uptime+=6000;P5Track(0,0,0,0,0,0,123);ck(g_p5[0].state==3 && abs(g_p5[0].net-.30)<1e-9,"complete deals including costs");
 ck(P5Summary(0,terminalTime).find("All S 1 W 1 L 0 BE 0")!=string::npos,"closed net win");
 P5Close();P5Init();ck(g_p5Ready && g_p5[0].state==3 && abs(g_p5[0].net-.30)<1e-9,"completed trade persisted");
 connected=false;deals.clear();uptime+=6000;P5Track(0,0,0,0,0,0,123);ck(g_p5[0].state==3,"offline history not reclassified");connected=true;
 plan.bar=1001;int j=P5Begin(1,plan,current);P5SendResult(j,101,10009,false);
 Order canceled=o;canceled.ticket=101;canceled.position=0;canceled.state=ORDER_STATE_CANCELED;canceled.lot=canceled.initial;history[101]=canceled;
 uptime+=6000;P5Track(1,0,0,0,0,0,123);ck(g_p5[j].state==4 && g_p5[j].accepted==1,"canceled unfilled not win");
 // Late broker history must be rechecked even after an unfilled classification.
 history[101].position=201;history[101].lot=0;deals={{201,DEAL_ENTRY_IN,.05,101,1700000003001L,1,99.9,0,-.10,0,0},{201,DEAL_ENTRY_OUT,.05,302,1700000004001L,2,99,-.50,-.10,0,0}};
 uptime+=6000;P5Track(1,0,0,0,0,0,123);ck(g_p5[j].state==3 && g_p5[j].net<0,"late fill after cancellation reconciled");
 int k=P5Begin(2,plan,current);P5SendResult(k,0,10006,true);ck(g_p5[k].state==5 && !g_p5[k].accepted,"definite rejection not accepted");
 plan.bar=1002;int a=P5Begin(2,plan,current),b=P5Begin(2,plan,current);
 P5Bind(2,1,1,999,0,1002);ck(g_p5[a].order==0 && g_p5[b].order==0,"ambiguous intents cannot bind to a later journal");
 P5Close();files["MT-test_trades.bin"][0]=0;P5Init();ck(!g_p5Ready,"corrupt diary fails closed");P5Close();
 if(!fails)cout<<"Broker-trade diary runtime stub checks passed\n";return fails?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+extra+kernel+runtime+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-Wno-missing-field-initializers','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)

# Exercise the production execution source with the real diary source, rather
# than only the no-op diary callbacks used in the Phase 4 regression suite.
auto=(root/'MT_AutoRuntime.mqh').read_text().replace('#include "MT_AutoPolicy.mqh"','').replace('#include "MT_TradeDiaryRuntime.mqh"','')
auto=re.sub(r'^input ', '', auto, flags=re.M)
integration=r'''
int main(){int f=0;auto ck=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';f++;}};
 P5Init();P4Init();InpAutoTrading=true;
 plans[0]={1,true,false,99.9,99,101,0.05,1000};g_p3[0].score=2;
 P4Process(true);ck(sends==1 && g_p5.size()==1 && g_p5[0].order>0 && g_p5[0].accepted==0,"pre-send snapshot and returned order");
 uptime+=6000;P4Process(false);ck(g_p5[0].state==1 && g_p5[0].accepted==1,"live order reconciled through execution loop");
 InpPlaceStopLoss=false;plans[1]={1,true,false,99.9,99,101,0.05,1000};g_p3[1].score=2;P4Process(true);
 uptime+=6000;P4Process(false);
 ck(sends==2 && orders.size()==2 && g_p5.size()==2 && g_p5[1].state==1 && g_p5[1].planStop==99 && g_p5[1].brokerStop==0,"diary distinguishes planned SL from broker no-SL pending");
 P5Close();plans[2]={1,true,false,99.9,99,101,0.05,1000};g_p3[2].score=2;P4Process(true);
 ck(sends==3 && orders.size()==3,"disabled diary does not block execution");
 P4Close();if(!f)cout<<"Trade diary and execution integration stub checks passed\n";return f?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+extra+kernel+runtime+auto+integration)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-Wno-missing-field-initializers','-I',str(root),str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
