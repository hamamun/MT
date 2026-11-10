#!/usr/bin/env python3
"""Compile the actual trade diary with in-memory broker/file stubs, not MT5."""
from pathlib import Path
import ast, os, re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
sanitizer=['-fsanitize=undefined','-fno-sanitize-recover=undefined'] if os.getenv('MT_TEST_SANITIZERS')=='1' else []
module=ast.parse((root/'tests/test_auto_runtime.py').read_text())
stubs=next(ast.literal_eval(n.value) for n in module.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='stubs' for t in n.targets))
stubs=stubs.replace('#define FILE_COMMON 8','#define FILE_CSV 128\n#define FILE_ANSI 256\n#define FILE_COMMON 8')
stubs=stubs.replace('#define ACCOUNT_CURRENCY 9','#define ACCOUNT_CURRENCY 9\n#define ACCOUNT_SERVER 60\n#define ACCOUNT_LOGIN 61\n#define ACCOUNT_BALANCE 63\n#define DEAL_TIME_MSC 64\n#define DEAL_REASON 65\n#define DEAL_PRICE 66\n#define DEAL_PROFIT 67\n#define DEAL_COMMISSION 68\n#define DEAL_SWAP 69\n#define DEAL_FEE 70\n#define DEAL_TYPE 71\n#define DEAL_REASON_TP 2\n#define DEAL_REASON_SL 3\n#define DEAL_TYPE_BUY 1\n#define DEAL_TYPE_SELL 2')
stubs=stubs.replace('struct MqlTick{double bid=100,ask=100.02;datetime time=1700000000;};','struct MqlTick{double bid=100,ask=100.02;datetime time=1700000000;long time_msc=1700000000000L;};')
stubs=stubs.replace('datetime bar=1000;};','datetime bar=1000; bool barProxy=false;};')
stubs=stubs.replace('struct Lane{int score=0,volumeState=-1;};','struct Lane{int score=0,volumeState=-1,gt=1,ct=1,st=1;string regime="MIXED";};')
stubs=stubs.replace('struct Deal {unsigned long position=0;int how=0;double vol=0;unsigned long order=0;};','struct Deal {unsigned long position=0;int how=0;double vol=0;unsigned long order=0;long time=0,reason=0;double price=0,profit=0,commission=0,swap=0,fee=0;};')
stubs=stubs.replace('return p==DEAL_POSITION_ID?d.position:p==DEAL_ORDER?d.order:d.how;', 'return p==DEAL_POSITION_ID?d.position:p==DEAL_ORDER?d.order:p==DEAL_ENTRY?d.how:p==DEAL_TIME_MSC?d.time:p==DEAL_TYPE?(d.how==DEAL_ENTRY_IN?DEAL_TYPE_BUY:DEAL_TYPE_SELL):d.reason;')
stubs=stubs.replace('double HistoryDealGetDouble(unsigned long tk,int){return deals[tk-1].vol;}','double HistoryDealGetDouble(unsigned long tk,int p){auto d=deals[tk-1];return p==DEAL_VOLUME?d.vol:p==DEAL_PRICE?d.price:p==DEAL_PROFIT?d.profit:p==DEAL_COMMISSION?d.commission:p==DEAL_SWAP?d.swap:d.fee;}')
stubs=stubs.replace('bool HistoryOrderGetDouble(unsigned long tk,int p,double &x){if(readFailure)return false;', 'bool missingRemaining=false; bool HistoryOrderGetDouble(unsigned long tk,int p,double &x){if(readFailure || (missingRemaining && p==ORDER_VOLUME_CURRENT))return false;')
stubs=stubs.replace('return p==ORDER_STATE?history[tk].state:history[tk].position;', 'return p==ORDER_STATE?history[tk].state:p==ORDER_MAGIC?history[tk].magic:p==ORDER_TYPE?history[tk].type:history[tk].position;')
extra=r'''
string IntegerToString(int x){return to_string(x);}
template<class T> int ArraySize(const vector<T>& x){return (int)x.size();}
template<class T> int ArrayResize(vector<T>& x,int n){x.resize(n);return n;}
int FileOpen(string n,int f,int){return FileOpen(n,f);}
vector<vector<string>> csvLines;
template<class T> string csvVal(const T& x){ostringstream s;s<<x;return s.str();}
template<class... T> void FileWrite(int,T... values){csvLines.push_back({csvVal(values)...});}
bool HistoryOrderGetString(ulong id,int,string &x){if(readFailure || !history.count(id))return false;x=history[id].symbol;return true;}
int P3TPPercentInput(int){return 85;} int P3Choice(int){return 0;} bool P3Against(int){return true;} int P3Strategy(int){return 30004;}
'''
kernel=(root/'MT_TradeDiary.mqh').read_text().replace('#include "MT_Phase3.mqh"','')
kernel=re.sub(r'const P5Deal &(\w+)\[\]',r'const vector<P5Deal> &\1',kernel)
runtime=(root/'MT_TradeDiaryRuntime.mqh').read_text().replace('#include "MT_TradeDiary.mqh"','')
runtime=re.sub(r'\b(P5Row|P5Deal|string) (\w+)\[\];',r'vector<\1> \2;',runtime)
main=r'''
int main(){int fails=0;auto ck=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';fails++;}};
 P5Init();ck(g_p5Ready,"initialized");
 P3Plan plan{1,true,false,99.9,99,101,0.05,1000};g_p3[0].score=2;
 int i=P5Begin(0,plan,current,true,85);ck(i==0 && g_p5[0].accepted==0,"intent not accepted");
 P5SendResult(i,100,10009,false);P5Close();P5Init();ck(g_p5Ready && g_p5.size()==1 && g_p5[0].order==100,"restart retains intent and order");
 Order o;o.ticket=100;o.magic=123;o.type=ORDER_TYPE_BUY_LIMIT;o.symbol=_Symbol;o.entry=99.9;o.sl=99;o.tp=101;o.initial=o.lot=.05;orders.push_back(o);
 P5Track(0,1,1,100,0,1000,123);ck(g_p5[0].state==1 && g_p5[0].accepted==1,"live broker order counted");
 ck(P5Summary(0,terminalTime).find("All S 1 W 0 L 0 BE 0")!=string::npos,"accepted order summary");
 orders.clear();o.position=200;o.state=ORDER_STATE_FILLED;o.lot=0;history[100]=o;
 Position p;p.ticket=201;p.id=200;p.magic=123;p.symbol=_Symbol;positions.push_back(p);
 deals={{200,DEAL_ENTRY_IN,.05,100,1700000000001L,1,99.9,0,-.10,0,0}};
 uptime+=6000;P5Track(0,1,1,100,200,1000,123);ck(g_p5[0].state==2,"position open not win");
 positions.clear();deals.push_back({200,DEAL_ENTRY_OUT,.02,300,1700000001001L,2,101,.20,-.02,0,-.01});
 uptime+=6000;P5Track(0,0,0,0,0,0,123);ck(g_p5[0].state==6 && g_p5Reason[0]=="Entry and exit volumes incomplete or different","partial closure held with reason");
 ck(P5Detail(0).find("Entry and exit volumes incomplete or different")!=string::npos,"details show review reason");
 connected=false;csvLines.clear();uptime+=6000;P5Track(0,0,0,0,0,0,123);
 ck(g_p5[0].state==6 && g_p5Reason[0]=="Terminal disconnected" && csvLines.size()==2 && csvLines[1].back()=="Terminal disconnected","reason-only changes automatically refresh CSV");
 connected=true;uptime+=6000;P5Track(0,0,0,0,0,0,123);
 csvLines.clear();P5Export();ck(csvLines[0].back()=="review_reason" && csvLines[1].back()==g_p5Reason[0],"CSV shows per-row review reason");
 P5Close();P5Init();uptime+=6000;P5Track(0,0,0,0,0,0,123);
 ck(g_p5[0].state==6 && g_p5Reason[0]=="Entry and exit volumes incomplete or different","review reason recomputed after restart");
 deals[0].vol=.02;
 uptime+=6000;P5Track(0,0,0,0,0,0,123);ck(g_p5[0].state==6,"matched subset without full order fill held");
 deals[0].vol=.05;deals.push_back({200,DEAL_ENTRY_OUT,.03,301,1700000002001L,2,101,.30,-.03,-.04,0});
 // Recover a previously saved REVIEW even if FILLED remaining is stale/unavailable.
 history[100].lot=.05;missingRemaining=true;P5Close();P5Init();
 uptime+=6000;P5Track(0,0,0,0,0,0,123);ck(g_p5[0].state==3 && abs(g_p5[0].net-.30)<1e-9 && g_p5Reason[0]=="","old review recovers from complete deals when filled remaining unavailable");
 missingRemaining=false;uptime+=6000;P5Track(0,0,0,0,0,0,123);
 ck(g_p5[0].state==3,"stale filled remaining does not undo verified closure");
 ck(P5Summary(0,terminalTime).find("All S 1 W 1 L 0 BE 0")!=string::npos,"closed net win");
 csvLines.clear();P5Export();ck(csvLines[1].back()=="","resolved row clears reason in CSV");
 P5Close();P5Init();ck(g_p5Ready && g_p5[0].state==3 && abs(g_p5[0].net-.30)<1e-9 && g_p5[0].stopInput==1 && g_p5[0].tpPercentInput==85,"completed trade and input snapshot persisted");
 {csvLines.clear();ck(P5Export(),"CSV export works");auto head=csvLines[0],row=csvLines[1];
  auto field=[&](string key){for(size_t i=0;i<head.size();i++)if(head[i]==key)return row[i];return string("missing");};
  ck(field("stop_placement_input")=="1" && field("tp_percent_input")=="85" && field("request_spread_price")=="0.02" && field("plan_reward_risk")=="1.2222" && field("holding_seconds")=="2.000","CSV includes real request context and derived analysis fields");}
 // A v1 ledger is read without inventing the newly recorded inputs, then migrated atomically.
 P5Close(); {auto &f=files["MT-test_trades.bin"];int version=1;memcpy(f.data()+4,&version,4);f.resize(12+284);}
 P5Init();ck(g_p5Ready && g_p5[0].stopInput==-1 && g_p5[0].state==3 && files["MT-test_trades.bin"].size()==12+292,"version 1 migration preserves results with unknown input context");
 csvLines.clear();P5Export();ck(csvLines.size()==2 && csvLines[1][find(csvLines[0].begin(),csvLines[0].end(),"stop_placement_input")-csvLines[0].begin()]=="" && csvLines[1][find(csvLines[0].begin(),csvLines[0].end(),"tp_percent_input")-csvLines[0].begin()]=="","legacy CSV inputs are blank, not invented");
 connected=false;deals.clear();uptime+=6000;P5Track(0,0,0,0,0,0,123);ck(g_p5[0].state==3,"offline history not reclassified");connected=true;
 plan.bar=1001;int j=P5Begin(1,plan,current,false,70);P5SendResult(j,101,10009,false);
 Order canceled=o;canceled.ticket=101;canceled.position=0;canceled.state=ORDER_STATE_CANCELED;canceled.lot=canceled.initial;history[101]=canceled;
 uptime+=6000;P5Track(1,0,0,0,0,0,123);ck(g_p5[j].state==4 && g_p5[j].accepted==1,"canceled unfilled not win");
 // Late broker history must be rechecked even after an unfilled classification.
 history[101].position=201;history[101].lot=0;deals={{201,DEAL_ENTRY_IN,.05,101,1700000003001L,1,99.9,0,-.10,0,0},{201,DEAL_ENTRY_OUT,.05,302,1700000004001L,2,99,-.50,-.10,0,0}};
 missingRemaining=true;uptime+=6000;P5Track(1,0,0,0,0,0,123);
 ck(g_p5[j].state==6 && g_p5Reason[j]=="Remaining order volume unavailable","canceled fill needs remaining volume");
 missingRemaining=false;history[101].lot=.03;uptime+=6000;P5Track(1,0,0,0,0,0,123);
 ck(g_p5[j].state==6 && g_p5Reason[j]=="Entry deals do not match confirmed order fill volume","canceled order fill mismatch held");
 history[101].lot=0;uptime+=6000;P5Track(1,0,0,0,0,0,123);ck(g_p5[j].state==3 && g_p5[j].net<0,"late fill after cancellation reconciled");
 plan.bar=1003;int part=P5Begin(1,plan,current,true,85);P5SendResult(part,102,10009,false);
 Order partial=o;partial.ticket=102;partial.position=202;partial.state=ORDER_STATE_CANCELED;partial.lot=.03;history[102]=partial;
 deals={{202,DEAL_ENTRY_IN,.02,102,1700000003001L,1,99.9,0,-.1,0,0},{202,DEAL_ENTRY_OUT,.02,303,1700000004001L,2,101,.5,-.1,0,0}};
 uptime+=6000;P5Track(1,0,0,0,0,0,123);ck(g_p5[part].state==3 && g_p5[part].net>0,"canceled partial closure matches actual filled volume");
 int k=P5Begin(2,plan,current,true,85);P5SendResult(k,0,10006,true);ck(g_p5[k].state==5 && !g_p5[k].accepted,"definite rejection not accepted");
 plan.bar=1002;int a=P5Begin(2,plan,current,true,85),b=P5Begin(2,plan,current,true,85);
 P5Bind(2,1,1,999,0,1002);ck(g_p5[a].order==0 && g_p5[b].order==0,"ambiguous intents cannot bind to a later journal");
 // Analytics must select last 30 by broker exit time, not insertion order.
 auto saved=g_p5;g_p5.clear();
 for(int n=34;n>=0;n--){P5Row r={};r.lane=0;r.accepted=1;r.state=3;r.direction=n%2?1:-1;r.score=n%2?2:-3;r.market=n%2;
  r.net=n<5?100:-1;r.commission=-.1;r.exitMs=100+n;r.requestMs=200+n;r.exitReason=n%2?DEAL_REASON_TP:DEAL_REASON_SL;r.ask=100.02;r.bid=100;r.stopInput=-1;g_p5.push_back(r);}
 P5Row unresolved={};unresolved.lane=0;unresolved.state=6;unresolved.net=999;unresolved.requestMs=1000;unresolved.direction=1;unresolved.stopInput=0;unresolved.tpPercentInput=85;g_p5.push_back(unresolved);
 P5Insights a1;P5BuildInsights(0,a1);
 ck(a1.totals.find("All closed 35 W 5 L 30 BE 0 Win 14.3% Net 470.00 USD Costs -3.50 USD")!=string::npos,"only fully reconciled trades in all-time analysis");
 ck(a1.recent.find("Last 30 closed: W 0 L 30 BE 0 Win 0.0% Net -30.00 USD")!=string::npos,"recent 30 ordered by exit time");
 ck(a1.exits.find("TP 15 SL 15 Other 0 Unknown 0")!=string::npos && a1.score.find("2/3: 17 closed")!=string::npos && a1.direction.find("BUY: 17 closed")!=string::npos,"final exit, score and directional breakdowns");
 ck(a1.context.find("SL input OFF TP input 85%")!=string::npos,"latest request context includes input snapshots even if unresolved");
 P5Insights empty;P5BuildInsights(2,empty);ck(empty.totals.find("Win -- Net -- Costs --")!=string::npos && empty.context=="Last request: none","empty lane does not invent win rate or cash");
 g_p5.clear();P5Row beRow={};beRow.lane=0;beRow.accepted=1;beRow.state=3;beRow.direction=1;beRow.score=2;beRow.net=0;beRow.exitMs=100;g_p5.push_back(beRow);
 P5Row winRow=beRow;winRow.net=1;winRow.exitMs=101;g_p5.push_back(winRow);P5BuildInsights(0,a1);
 ck(a1.totals.find("W 1 L 0 BE 1 Win 50.0%")!=string::npos,"break-even included in closed win-rate denominator");
 g_p5=saved;P5Close();
 // Convert every v2 row to v1 to verify multi-record migration and alignment.
 {auto v2=files["MT-test_trades.bin"];int count=0,version=1;memcpy(&count,v2.data()+8,4);vector<char> v1(v2.begin(),v2.begin()+12);memcpy(v1.data()+4,&version,4);
  for(int i=0;i<count;i++)v1.insert(v1.end(),v2.begin()+12+i*292,v2.begin()+12+i*292+284);
  files["MT-test_trades.bin"]=v1;P5Init();ck(g_p5Ready && int(g_p5.size())==count,"multi-row version 1 migration");
  for(auto &r:g_p5)ck(r.stopInput==-1,"every migrated input snapshot is unknown");P5Close();}
files["MT-test_trades.bin"][0]=0;auto preserved=files["MT-test_trades.bin"];P5Init();ck(!g_p5Ready && files["MT-test_trades.bin"]==preserved,"corrupt diary fails closed and is preserved");P5Close();
 if(!fails)cout<<"Broker-trade diary runtime stub checks passed\n";return fails?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+extra+kernel+runtime+main)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-Wno-missing-field-initializers','-I',str(root)] + sanitizer + [str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)

# Exercise the production execution source with the real diary source, rather
# than only the no-op diary callbacks used in the Phase 4 regression suite.
auto=(root/'MT_AutoRuntime.mqh').read_text().replace('#include "MT_AutoPolicy.mqh"','').replace('#include "MT_TradeDiaryRuntime.mqh"','')
# The production inputs live in the plan runtime, which is stubbed here.
input_names=('InpAutoTrading','InpPlaceStopLoss','InpAllowAutoM5','InpAllowAutoM15','InpAllowAutoM30','InpUseAutoSchedule','InpAutoStartTime','InpAutoEndTime')
inputs='\n'.join(line for line in (root/'MT_PlanRuntime.mqh').read_text().splitlines()
                 if line.startswith('input ') and any(re.search(r'\b'+n+r'\b',line) for n in input_names))
auto=inputs+'\n'+auto
auto=re.sub(r'^input ', '', auto, flags=re.M)
integration=r'''
int main(){int f=0;auto ck=[&](bool b,const char*s){if(!b){cerr<<"FAIL "<<s<<'\n';f++;}};
 InpUseAutoSchedule=false;InpPlaceStopLoss=true;P5Init();P4Init();InpAutoTrading=true;
 plans[0]={1,true,false,99.9,99,101,0.05,1000};g_p3[0].score=2;
 P4Process(true);ck(sends==1 && g_p5.size()==1 && g_p5[0].order>0 && g_p5[0].accepted==0,"pre-send snapshot and returned order");
 uptime+=6000;P4Process(false);ck(g_p5[0].state==1 && g_p5[0].accepted==1,"live order reconciled through execution loop");
 InpPlaceStopLoss=false;plans[1]={1,true,false,99.9,99,101,0.05,1000};g_p3[1].score=2;P4Process(true);
 uptime+=6000;P4Process(false);
 ck(sends==2 && orders.size()==2 && g_p5.size()==2 && g_p5[1].state==1 && g_p5[1].planStop==99 && g_p5[1].brokerStop==0 && g_p5[1].stopInput==0 && g_p5[1].tpPercentInput==85,"diary distinguishes planned SL from broker no-SL pending");
 P5Close();plans[2]={1,true,false,99.9,99,101,0.05,1000};g_p3[2].score=2;P4Process(true);
 ck(sends==3 && orders.size()==3,"disabled diary does not block execution");
 P4Close();P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 for(int i=0;i<3;i++){plans[i]=P3Plan{};g_p3[i].score=0;g_p3[i].volumeState=-1;}
 equity=1000;current={100.79,100.80,terminalTime};sends=0;uptime=10000;InpPlaceStopLoss=true;P5Init();P4Init();
 plans[0]={1,true,true,100.0,99.0,102.0,0.05,1000};g_p3[0].score=3;P4Process(true);
 ck(sends==1 && g_p5.size()==1 && MathAbs(lastRequest.volume-0.02)<1e-8 && MathAbs(g_p5[0].lot-0.02)<1e-8 && g_p5[0].planEntry==100.0 && plans[0].lot==0.05,"real diary records reduced market request lot and frozen plan prices");
 P4Close();P5Close();if(!f)cout<<"Trade diary and execution integration stub checks passed\n";return f?1:0;}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'x.cpp').write_text(stubs+extra+kernel+runtime+auto+integration)
 subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-Wno-missing-field-initializers','-I',str(root)] + sanitizer + [str(p/'x.cpp'),'-o',str(p/'x')],check=True)
 subprocess.run([str(p/'x')],check=True)
