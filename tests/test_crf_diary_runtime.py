#!/usr/bin/env python3
"""Run diary and auto regressions against CRF-specific copies plus identity tests."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'tests/test_trade_diary_runtime.py').read_text()
source=source.replace("MT-test_trades.bin", "MT-test_crf_trades.bin")
source=source.replace("root/'MT_TradeDiaryRuntime.mqh'", "root/'MT_CRF_TradeDiaryRuntime.mqh'")
source=source.replace("root/'MT_AutoRuntime.mqh'", "root/'MT_CRF_AutoRuntime.mqh'")
source=source.replace(".replace('#include \"MT_TradeDiaryRuntime.mqh\"','')", ".replace('#include \"MT_CRF_TradeDiaryRuntime.mqh\"','')")
source=source.replace("extra=r'''", "extra=r'''\nbool InpCrfRiskBypass=false;\nbool FileCopy(string a,int,string b,int){if(diskFail||!files.count(a)||files.count(b))return false;files[b]=files[a];return true;}")
source=source.replace("auto=inputs+'\\n'+auto", "auto='using ENUM_TIMEFRAMES=int; const int PERIOD_M15=1; bool CRFNativeLaneBlocked(int){return false;}\\n'+inputs+'\\n'+auto")
extra=r'''
 // CRF and MT requests on the same M15 bar must bind and reconcile only
 // against their own strategy/magic, including on the same timer tick.
 P5Close();handles.clear();files.clear();orders.clear();positions.clear();history.clear();deals.clear();
 uptime=10000;P5Init();P3Plan crfPlan{1,true,true,100,99,102,.05,1000};
 int nativeRow=P5Begin(1,crfPlan,current,true,83);int crfRow=P5BeginCrf(crfPlan,current);
 ck(nativeRow==0 && crfRow==1 && g_p5[crfRow].strategy==30007 && g_p5[crfRow].score==0 && g_p5[crfRow].stopInput==1,"CRF request has own strategy without fake score");
 P5Bind(1,1,1,111,0,1000,true);P5Bind(1,1,1,222,0,1000,false);
 ck(g_p5[crfRow].order==111 && g_p5[nativeRow].order==222,"same-bar identities bind by strategy");
 Order no;no.ticket=222;no.magic=123;no.type=ORDER_TYPE_BUY_LIMIT;no.symbol=_Symbol;no.entry=99.9;no.sl=99;no.tp=101;no.initial=no.lot=.05;
 Order co=no;co.ticket=111;co.magic=456;orders={no,co};
 P5Track(1,1,1,222,0,1000,123,false);P5Track(1,1,1,111,0,1000,456,true);
 ck(g_p5[nativeRow].state==1 && g_p5[crfRow].state==1,"both magics reconcile independently on same poll");
 P5Insights insight;P5BuildInsights(1,insight);ck(insight.context.find("CRF MARKET | Score --")!=string::npos,"CRF diary does not present synthetic score");
 P5Export();bool csvOK=false;for(auto &line:csvLines)if(line.size()>18 && line[17]=="30007" && line[6].empty() && line[7].empty())csvOK=true;
 ck(csvOK,"CRF CSV omits non-existent score and trend");
 P5Close();
 // The CRF ledger is seeded once under the native lock and remains isolated.
 files["MT-test_trades.bin"]=files["MT-test_crf_trades.bin"];files.erase("MT-test_crf_trades.bin");
 auto original=files["MT-test_trades.bin"];P5Init();
 ck(g_p5Ready && g_p5.size()==2 && files["MT-test_trades.bin"]==original,"locked native diary imported once without modifying original");
 P5BeginCrf(crfPlan,current);ck(files["MT-test_trades.bin"]==original && g_p5.size()==3,"CRF records never contaminate original diary");
 P5Close();
'''
marker=' if(!fails)cout<<"Broker-trade diary runtime stub checks passed\\n";'
assert marker in source
source=source.replace(marker,extra+'\n'+marker)
exec(compile(source,str(root/'tests/test_trade_diary_runtime.py'),'exec'),{'__file__':str(root/'tests/test_trade_diary_runtime.py'),'__name__':'__main__'})
