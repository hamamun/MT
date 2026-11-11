// Broker-confirmed trade diary. Separate from the legacy quote-observation diary.
#ifndef MT_TRADE_DIARY_RUNTIME_MQH
#define MT_TRADE_DIARY_RUNTIME_MQH
#include "MT_TradeDiary.mqh"

// 0=request not yet proven, 1=broker order, 2=open, 3=closed,
// 4=unfilled end, 5=definite rejection, 6=review/incomplete.
struct P5Row
{
   int lane, direction, score, gt, ct, st, regime, volumeState, market, choice, against, bypass, minimum, strategy, barProxy, state, accepted, retcode, exitReason, stopInput, tpPercentInput;
   long order, position, bar, requestMs, entryMs, exitMs;
   double planEntry, planStop, planTarget, lot, bid, ask, equity, balance, entryVolume, exitVolume, entryPrice, exitPrice, profit, commission, swap, fee, net, brokerEntry, brokerStop, brokerTarget;
};
P5Row g_p5[];
// Diagnostics are recomputed from broker history on each poll, not persisted
// in the versioned binary. CSV and details expose the latest reason per row.
string g_p5Reason[];
int g_p5Lock=INVALID_HANDLE, g_p5Flags=0;
bool g_p5Ready=false, g_p5ExportReady=false;
string g_p5File="";
ulong g_p5Poll[4]={0,0,0,0};

bool P5Export()
{
   string dest=g_p5File+".csv", tmp=dest+".tmp";
   int h=FileOpen(tmp,FILE_WRITE|FILE_CSV|FILE_ANSI|g_p5Flags,',');
   if(h==INVALID_HANDLE) return(false);
   ResetLastError();
   FileWrite(h,"server","account","symbol","currency","lane","direction","score","gt","ct","st","regime","volume","market","trend_choice","allow_against","bypass","minimum","strategy","bar_proxy","state","accepted","retcode","exit_reason","order","position","plan_bar","request_ms","entry_ms","exit_ms","plan_entry","plan_sl","plan_tp","lot","bid","ask","equity","balance","entry_volume","exit_volume","entry_price","exit_price","profit","commission","swap","fee","net","broker_entry","broker_sl","broker_tp","stop_placement_input","tp_percent_input","request_spread_price","plan_risk_price","plan_reward_price","plan_reward_risk","entry_slippage_vs_original_plan_price","holding_seconds","review_reason");
   for(int i=0;i<ArraySize(g_p5);i++)
   {
      P5Row r=g_p5[i];
      FileWrite(h,AccountInfoString(ACCOUNT_SERVER),AccountInfoInteger(ACCOUNT_LOGIN),_Symbol,AccountInfoString(ACCOUNT_CURRENCY),
         r.lane,r.direction,r.strategy==30007?"":IntegerToString(r.score),r.strategy==30007?"":IntegerToString(r.gt),r.strategy==30007?"":IntegerToString(r.ct),r.strategy==30007?"":IntegerToString(r.st),r.strategy==30007?"":IntegerToString(r.regime),r.strategy==30007?"":IntegerToString(r.volumeState),r.market,r.strategy==30007?"":IntegerToString(r.choice),r.against,r.bypass,r.minimum,r.strategy,r.barProxy,
         r.state,r.accepted,r.retcode,r.exitReason,r.order,r.position,r.bar,r.requestMs,r.entryMs,r.exitMs,
         r.planEntry,r.planStop,r.planTarget,r.lot,r.bid,r.ask,r.equity,r.balance,r.entryVolume,r.exitVolume,
         r.entryPrice,r.exitPrice,r.profit,r.commission,r.swap,r.fee,r.net,r.brokerEntry,r.brokerStop,r.brokerTarget,
         r.stopInput<0?"":IntegerToString(r.stopInput),(r.stopInput<0 || r.strategy==30007)?"":IntegerToString(r.tpPercentInput),
         DoubleToString(r.ask-r.bid,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         DoubleToString(MathAbs(r.planEntry-r.planStop),(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         DoubleToString(MathAbs(r.planTarget-r.planEntry),(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         MathAbs(r.planEntry-r.planStop)>0?DoubleToString(MathAbs(r.planTarget-r.planEntry)/MathAbs(r.planEntry-r.planStop),4):"",
         r.state==3?DoubleToString(r.direction*(r.entryPrice-r.planEntry),(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)):"",
         r.state==3 && r.exitMs>=r.entryMs?DoubleToString((double)(r.exitMs-r.entryMs)/1000.0,3):"",
         (r.state==0 || r.state==6)?(i<ArraySize(g_p5Reason) && g_p5Reason[i]!=""?g_p5Reason[i]:"Awaiting broker reconciliation"):"");
   }
   FileFlush(h); bool ok=(GetLastError()==0); FileClose(h);
   return(ok && FileMove(tmp,g_p5Flags,dest,g_p5Flags|FILE_REWRITE));
}

bool P5Save()
{
   if(g_p5Lock==INVALID_HANDLE) return(false);
   string tmp=g_p5File+".tmp";
   int h=FileOpen(tmp,FILE_WRITE|FILE_BIN|g_p5Flags);
   if(h==INVALID_HANDLE) return(false);
   ResetLastError();
   FileWriteInteger(h,1297368117,INT_VALUE); FileWriteInteger(h,2,INT_VALUE);
   int count=ArraySize(g_p5); FileWriteInteger(h,count,INT_VALUE);
   for(int i=0;i<count;i++)
   {
      P5Row r=g_p5[i];
      FileWriteInteger(h,r.lane,INT_VALUE);
      FileWriteInteger(h,r.direction,INT_VALUE);
      FileWriteInteger(h,r.score,INT_VALUE);
      FileWriteInteger(h,r.gt,INT_VALUE);
      FileWriteInteger(h,r.ct,INT_VALUE);
      FileWriteInteger(h,r.st,INT_VALUE);
      FileWriteInteger(h,r.regime,INT_VALUE);
      FileWriteInteger(h,r.volumeState,INT_VALUE);
      FileWriteInteger(h,r.market,INT_VALUE);
      FileWriteInteger(h,r.choice,INT_VALUE);
      FileWriteInteger(h,r.against,INT_VALUE);
      FileWriteInteger(h,r.bypass,INT_VALUE);
      FileWriteInteger(h,r.minimum,INT_VALUE);
      FileWriteInteger(h,r.strategy,INT_VALUE);
      FileWriteInteger(h,r.barProxy,INT_VALUE);
      FileWriteInteger(h,r.state,INT_VALUE);
      FileWriteInteger(h,r.accepted,INT_VALUE);
      FileWriteInteger(h,r.retcode,INT_VALUE);
      FileWriteInteger(h,r.exitReason,INT_VALUE);
      FileWriteLong(h,r.order);
      FileWriteLong(h,r.position);
      FileWriteLong(h,r.bar);
      FileWriteLong(h,r.requestMs);
      FileWriteLong(h,r.entryMs);
      FileWriteLong(h,r.exitMs);
      FileWriteDouble(h,r.planEntry);
      FileWriteDouble(h,r.planStop);
      FileWriteDouble(h,r.planTarget);
      FileWriteDouble(h,r.lot);
      FileWriteDouble(h,r.bid);
      FileWriteDouble(h,r.ask);
      FileWriteDouble(h,r.equity);
      FileWriteDouble(h,r.balance);
      FileWriteDouble(h,r.entryVolume);
      FileWriteDouble(h,r.exitVolume);
      FileWriteDouble(h,r.entryPrice);
      FileWriteDouble(h,r.exitPrice);
      FileWriteDouble(h,r.profit);
      FileWriteDouble(h,r.commission);
      FileWriteDouble(h,r.swap);
      FileWriteDouble(h,r.fee);
      FileWriteDouble(h,r.net);
      FileWriteDouble(h,r.brokerEntry);
      FileWriteDouble(h,r.brokerStop);
      FileWriteDouble(h,r.brokerTarget);
      FileWriteInteger(h,r.stopInput,INT_VALUE); FileWriteInteger(h,r.tpPercentInput,INT_VALUE);
   }
   FileFlush(h); bool ok=(GetLastError()==0 && FileSize(h)==(ulong)(12+(long)count*292));
   FileClose(h);
   if(!ok || !FileMove(tmp,g_p5Flags,g_p5File,g_p5Flags|FILE_REWRITE)) return(false);
   g_p5ExportReady=P5Export();
   if(!g_p5ExportReady) Print("MT trade diary: CSV export unavailable; binary diary retained");
   return(true);
}

bool P5Load()
{
   ArrayResize(g_p5,0);
   if(!FileIsExist(g_p5File,g_p5Flags)) return(true);
   int h=FileOpen(g_p5File,FILE_READ|FILE_BIN|g_p5Flags);
   if(h==INVALID_HANDLE || FileSize(h)<12) { if(h!=INVALID_HANDLE) FileClose(h); return(false); }
   int magic=FileReadInteger(h,INT_VALUE), version=FileReadInteger(h,INT_VALUE), count=FileReadInteger(h,INT_VALUE);
   if(magic!=1297368117 || (version!=1 && version!=2) || count<0 || count>1000000 || FileSize(h)!=(ulong)(12+(long)count*(version==1?284:292)))
   { FileClose(h); return(false); }
   if(ArrayResize(g_p5,count)!=count) { FileClose(h); return(false); }
   ResetLastError();
   for(int i=0;i<count;i++)
   {
      P5Row r;
      r.lane=FileReadInteger(h,INT_VALUE);
      r.direction=FileReadInteger(h,INT_VALUE);
      r.score=FileReadInteger(h,INT_VALUE);
      r.gt=FileReadInteger(h,INT_VALUE);
      r.ct=FileReadInteger(h,INT_VALUE);
      r.st=FileReadInteger(h,INT_VALUE);
      r.regime=FileReadInteger(h,INT_VALUE);
      r.volumeState=FileReadInteger(h,INT_VALUE);
      r.market=FileReadInteger(h,INT_VALUE);
      r.choice=FileReadInteger(h,INT_VALUE);
      r.against=FileReadInteger(h,INT_VALUE);
      r.bypass=FileReadInteger(h,INT_VALUE);
      r.minimum=FileReadInteger(h,INT_VALUE);
      r.strategy=FileReadInteger(h,INT_VALUE);
      r.barProxy=FileReadInteger(h,INT_VALUE);
      r.state=FileReadInteger(h,INT_VALUE);
      r.accepted=FileReadInteger(h,INT_VALUE);
      r.retcode=FileReadInteger(h,INT_VALUE);
      r.exitReason=FileReadInteger(h,INT_VALUE);
      r.order=FileReadLong(h);
      r.position=FileReadLong(h);
      r.bar=FileReadLong(h);
      r.requestMs=FileReadLong(h);
      r.entryMs=FileReadLong(h);
      r.exitMs=FileReadLong(h);
      r.planEntry=FileReadDouble(h);
      r.planStop=FileReadDouble(h);
      r.planTarget=FileReadDouble(h);
      r.lot=FileReadDouble(h);
      r.bid=FileReadDouble(h);
      r.ask=FileReadDouble(h);
      r.equity=FileReadDouble(h);
      r.balance=FileReadDouble(h);
      r.entryVolume=FileReadDouble(h);
      r.exitVolume=FileReadDouble(h);
      r.entryPrice=FileReadDouble(h);
      r.exitPrice=FileReadDouble(h);
      r.profit=FileReadDouble(h);
      r.commission=FileReadDouble(h);
      r.swap=FileReadDouble(h);
      r.fee=FileReadDouble(h);
      r.net=FileReadDouble(h);
      r.brokerEntry=FileReadDouble(h);
      r.brokerStop=FileReadDouble(h);
      r.brokerTarget=FileReadDouble(h);
      r.stopInput=-1; r.tpPercentInput=0;
      if(version>=2) { r.stopInput=FileReadInteger(h,INT_VALUE); r.tpPercentInput=FileReadInteger(h,INT_VALUE); }
      if((r.stopInput < -1 || r.stopInput > 1) || r.lane<0 || r.lane>2 || (r.direction!=1 && r.direction!=-1) || r.score < -3 || r.score > 3 ||
         r.state<0 || r.state>6 || (r.accepted!=0 && r.accepted!=1) || r.order<0 || r.position<0 ||
         r.bar<=0 || r.requestMs<=0 || r.entryMs<0 || r.exitMs<0 || r.strategy<=0 ||
         !P3Positive(r.planEntry) || !P3Positive(r.planStop) || !P3Positive(r.planTarget) || !P3Positive(r.lot) ||
         !P3Positive(r.bid) || !P3Positive(r.ask) || r.ask<r.bid ||
         !MathIsValidNumber(r.equity) || !MathIsValidNumber(r.balance) ||
         !MathIsValidNumber(r.entryVolume) || !MathIsValidNumber(r.exitVolume) ||
         !MathIsValidNumber(r.entryPrice) || !MathIsValidNumber(r.exitPrice) ||
         !P5Money(r.profit) || !P5Money(r.commission) || !P5Money(r.swap) || !P5Money(r.fee) || !P5Money(r.net) ||
         !MathIsValidNumber(r.brokerEntry) || !MathIsValidNumber(r.brokerStop) || !MathIsValidNumber(r.brokerTarget) ||
         (r.state==3 && (r.accepted!=1 || r.order<=0 || r.position<=0 || r.entryMs<=0 || r.exitMs<=0 ||
                         !P3Positive(r.entryVolume) || !P3Positive(r.exitVolume) || !P3Positive(r.entryPrice) || !P3Positive(r.exitPrice))))
      { FileClose(h); ArrayResize(g_p5,0); return(false); }
      g_p5[i]=r;
   }
   bool ok=(GetLastError()==0 && FileTell(h)==FileSize(h)); FileClose(h); return(ok);
}

void P5Close()
{
   if(g_p5Lock!=INVALID_HANDLE) FileClose(g_p5Lock);
   g_p5Lock=INVALID_HANDLE; g_p5Ready=false; g_p5ExportReady=false;
}
void P5Init()
{
   P5Close();
   for(int i=0;i<4;i++) g_p5Poll[i]=0;
   g_p5Flags=MQLInfoInteger(MQL_TESTER)?0:FILE_COMMON;
   // Keep CRF rows out of the original MT diary: original MT reconciles every
   // M15 row with native magic and cannot safely interpret strategy 30007.
   // Seed this separate ledger once from the locked native diary, preserving
   // history and any pre-existing MT position's existing record.
   string original=P3DiaryKey()+"_trades.bin";
   g_p5File=P3DiaryKey()+"_crf_trades.bin";
   g_p5Lock=FileOpen(g_p5File+".lock",FILE_READ|FILE_WRITE|FILE_BIN|g_p5Flags);
   if(g_p5Lock==INVALID_HANDLE) { Print("MT CRF trade diary: locked or unavailable"); return; }
   if(!FileIsExist(g_p5File,g_p5Flags) && FileIsExist(original,g_p5Flags))
   {
      int nativeLock=FileOpen(original+".lock",FILE_READ|FILE_WRITE|FILE_BIN|g_p5Flags);
      if(nativeLock==INVALID_HANDLE) { Print("MT CRF trade diary: native diary locked; import suspended"); return; }
      bool copied=FileCopy(original,g_p5Flags,g_p5File,g_p5Flags);
      FileClose(nativeLock);
      if(!copied) { Print("MT CRF trade diary: native diary import failed"); return; }
   }
   if(!P5Load()) { Print("MT trade diary: unreadable; preserving file"); return; }
   ArrayResize(g_p5Reason,0);
   int count=ArraySize(g_p5);
   if(ArrayResize(g_p5Reason,count)!=count) { Print("MT trade diary: diagnostic allocation failed"); return; }
   for(int i=0;i<count;i++) g_p5Reason[i]="";
   g_p5Ready=true;
   if(!P5Save()) { g_p5Ready=false; Print("MT trade diary: save failed"); }
}

// Save the request context before sending; its existence is NOT a fill or S.
// Diary failures do not block safety management or alter trade permissions.
int P5Begin(int lane, const P3Plan &plan, const MqlTick &quote, bool stopInput, int tpPercentInput)
{
   if(!g_p5Ready || lane<0 || lane>2 || quote.time_msc<=0) return(-1);
   int n=ArraySize(g_p5);
   if(ArrayResize(g_p5Reason,n+1)!=n+1 || ArrayResize(g_p5,n+1)!=n+1) { g_p5Ready=false; return(-1); }
   g_p5Reason[n]="Awaiting broker reconciliation";
   P5Row r={};
   r.lane=lane; r.direction=plan.signal; r.score=g_p3[lane].score;
   r.gt=g_p3[lane].gt; r.ct=g_p3[lane].ct; r.st=g_p3[lane].st;
   r.regime=g_p3[lane].regime=="STEADY"?1:(g_p3[lane].regime=="CHOPPY"?2:(g_p3[lane].regime=="MIXED"?0:99));
   r.volumeState=g_p3[lane].volumeState; r.market=plan.market?1:0;
   r.choice=(int)P3Choice(lane); r.against=P3Against(lane)?1:0;
   r.bypass=InpBypassRisk?1:0; r.minimum=InpMinimumLot?1:0; r.strategy=P3Strategy(lane); r.barProxy=plan.barProxy?1:0;
   r.stopInput=stopInput?1:0; r.tpPercentInput=tpPercentInput;
   r.state=0; r.accepted=0; r.exitReason=-1; r.bar=(long)plan.bar; r.requestMs=quote.time_msc;
   r.planEntry=plan.entry; r.planStop=plan.stop; r.planTarget=plan.target; r.lot=plan.lot;
   r.bid=quote.bid; r.ask=quote.ask; r.equity=AccountInfoDouble(ACCOUNT_EQUITY); r.balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(!MathIsValidNumber(r.equity)) r.equity=0; if(!MathIsValidNumber(r.balance)) r.balance=0;
   g_p5[n]=r;
   if(!P5Save()) { g_p5Ready=false; Print("MT trade diary: request record not saved; trading remains independent"); return(-1); }
   return(n);
}
// CRF has no MT score or trend context. Zero is an internal neutral sentinel;
// CRF CSV and details display those fields as unavailable, never as a signal.
int P5BeginCrf(const P3Plan &plan, const MqlTick &quote)
{
   if(!g_p5Ready || quote.time_msc<=0 || !plan.valid ||
      (plan.signal!=1 && plan.signal!=-1) || !P3Positive(plan.lot)) return -1;
   int n=ArraySize(g_p5);
   if(ArrayResize(g_p5Reason,n+1)!=n+1 || ArrayResize(g_p5,n+1)!=n+1) { g_p5Ready=false; return -1; }
   g_p5Reason[n]="Awaiting broker reconciliation";
   P5Row r={};
   r.lane=1; r.direction=plan.signal; r.score=0; r.gt=99; r.ct=99; r.st=99;
   r.regime=99; r.volumeState=-1; r.market=1; r.choice=-1; r.against=0;
   r.bypass=InpBypassRisk?1:0; r.minimum=InpMinimumLot?1:0;
   r.strategy=30007; r.barProxy=plan.barProxy?1:0; r.stopInput=1; r.tpPercentInput=0;
   r.state=0; r.accepted=0; r.exitReason=-1; r.bar=(long)plan.bar; r.requestMs=quote.time_msc;
   r.planEntry=plan.entry; r.planStop=plan.stop; r.planTarget=plan.target; r.lot=plan.lot;
   r.bid=quote.bid; r.ask=quote.ask; r.equity=AccountInfoDouble(ACCOUNT_EQUITY); r.balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(!MathIsValidNumber(r.equity)) r.equity=0; if(!MathIsValidNumber(r.balance)) r.balance=0;
   g_p5[n]=r;
   if(!P5Save()) { g_p5Ready=false; Print("MT CRF diary: request record not saved"); return -1; }
   return n;
}
void P5SendResult(int row, ulong order, uint retcode, bool rejected)
{
   if(!g_p5Ready || row<0 || row>=ArraySize(g_p5)) return;
   if(order>0) g_p5[row].order=(long)order;
   g_p5[row].retcode=(int)retcode;
   if(rejected && order==0) g_p5[row].state=5;
   if(!P5Save()) { g_p5Ready=false; Print("MT trade diary: result save failed"); }
}

// Bind an unresolved, matching pre-send record to the execution journal.
// Never manufacture a record for a position that predates this diary.
void P5Bind(int lane, int active, int dir, ulong order, ulong position, datetime planBar, bool crf=false)
{
   if(!g_p5Ready || !active) return;
   int match=-1;
   for(int i=ArraySize(g_p5)-1;i>=0;i--)
   {
      P5Row r=g_p5[i];
      if(r.lane!=lane || (r.strategy==30007)!=crf || r.state==3 || r.state==4 || r.state==5 || r.direction!=dir) continue;
      if((r.order>0 && order>0 && (ulong)r.order==order) ||
         (r.order==0 && r.position==0 && r.bar==(long)planBar))
      { if(match>=0) return; match=i; }
   }
   if(match<0) return;
   if(g_p5[match].order>0 && order>0 && (ulong)g_p5[match].order!=order) return;
   if(g_p5[match].position>0 && position>0 && (ulong)g_p5[match].position!=position) return;
   bool changed=false;
   if(g_p5[match].order==0 && order>0) { g_p5[match].order=(long)order; changed=true; }
   if(g_p5[match].position==0 && position>0) { g_p5[match].position=(long)position; changed=true; }
   if(changed && !P5Save()) { g_p5Ready=false; Print("MT trade diary: identity save failed"); }
}

bool P5Changed(const P5Row &a, const P5Row &b)
{
   return(a.order!=b.order || a.position!=b.position || a.state!=b.state || a.accepted!=b.accepted ||
          a.entryMs!=b.entryMs || a.exitMs!=b.exitMs || a.exitReason!=b.exitReason ||
          a.entryVolume!=b.entryVolume || a.exitVolume!=b.exitVolume || a.entryPrice!=b.entryPrice || a.exitPrice!=b.exitPrice ||
          a.profit!=b.profit || a.commission!=b.commission || a.swap!=b.swap || a.fee!=b.fee || a.net!=b.net ||
          a.brokerEntry!=b.brokerEntry || a.brokerStop!=b.brokerStop || a.brokerTarget!=b.brokerTarget);
}

// Successful reads and matching identity are mandatory. Failure is unknown,
// never proof that an order/position does not exist.
bool P5PositionPresent(ulong id, long magic, bool &present)
{
   present=false;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      long identifier=0, objectMagic=0; string symbol="";
      if(ticket==0 || !PositionGetInteger(POSITION_IDENTIFIER,identifier) ||
         !PositionGetInteger(POSITION_MAGIC,objectMagic) || !PositionGetString(POSITION_SYMBOL,symbol)) return(false);
      if((ulong)identifier==id)
      {
         if(symbol!=_Symbol || objectMagic!=magic || present) return(false);
         present=true;
      }
   }
   return(true);
}

bool P5DiscoverPosition(ulong order, datetime from, ulong &position)
{
   datetime now=TimeCurrent();
   if(order==0 || now<=0 || from<=0 || !HistorySelect(from,now+60)) return(false);
   ulong found=0;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong ticket=HistoryDealGetTicket(i); long dealOrder=0, entry=0, pos=0;
      if(ticket==0 || !HistoryDealGetInteger(ticket,DEAL_ORDER,dealOrder)) return(false);
      if((ulong)dealOrder!=order) continue;
      if(!HistoryDealGetInteger(ticket,DEAL_ENTRY,entry) || !HistoryDealGetInteger(ticket,DEAL_POSITION_ID,pos)) return(false);
      if(entry!=DEAL_ENTRY_IN || pos<=0 || (found>0 && found!=(ulong)pos)) return(false);
      found=(ulong)pos;
   }
   if(found==0) return(false);
   position=found; return(true);
}

// Evaluate only deals belonging to the confirmed position. Failed property
// reads, partial exits and ambiguous identities remain REVIEW, not W/L.
bool P5GatherClosed(P5Row &row, bool positionOpen, bool pending, string &diagnostic)
{
   if(row.position<=0 || row.order<=0) { diagnostic="Order or position ID unavailable"; return(false); }
   if(!HistorySelectByPosition((ulong)row.position)) { diagnostic="Position deal history unavailable"; return(false); }
   P5Deal deals[]; int count=HistoryDealsTotal();
   long lastExit=0; int reason=-1;
   for(int i=0;i<count;i++)
   {
      ulong ticket=HistoryDealGetTicket(i); long pos=0, order=0, kind=0, type=0, time=0, why=0;
      double volume=0, price=0, profit=0, commission=0, swap=0, fee=0;
      if(ticket==0 || !HistoryDealGetInteger(ticket,DEAL_POSITION_ID,pos) ||
         !HistoryDealGetInteger(ticket,DEAL_ORDER,order) || !HistoryDealGetInteger(ticket,DEAL_ENTRY,kind) ||
         !HistoryDealGetInteger(ticket,DEAL_TYPE,type) ||
         !HistoryDealGetInteger(ticket,DEAL_TIME_MSC,time) || !HistoryDealGetInteger(ticket,DEAL_REASON,why) ||
         !HistoryDealGetDouble(ticket,DEAL_VOLUME,volume) || !HistoryDealGetDouble(ticket,DEAL_PRICE,price) ||
         !HistoryDealGetDouble(ticket,DEAL_PROFIT,profit) || !HistoryDealGetDouble(ticket,DEAL_COMMISSION,commission) ||
         !HistoryDealGetDouble(ticket,DEAL_SWAP,swap) || !HistoryDealGetDouble(ticket,DEAL_FEE,fee))
      { diagnostic="Deal properties unavailable"; return(false); }
      if((ulong)pos!=(ulong)row.position || order<=0) { diagnostic="Deal position or order ID invalid"; return(false); }
      int mapped=kind==DEAL_ENTRY_IN?1:((kind==DEAL_ENTRY_OUT || kind==DEAL_ENTRY_OUT_BY)?2:0);
      if(mapped==0 || (type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) ||
         ((type==DEAL_TYPE_BUY?1:-1)!=(mapped==1?row.direction:-row.direction)))
      { diagnostic="Unsupported deal entry type or direction"; return(false); }
      int n=ArraySize(deals); if(ArrayResize(deals,n+1)!=n+1) { diagnostic="Deal collection allocation failed"; return(false); }
      deals[n].ticket=ticket; deals[n].position=(ulong)pos; deals[n].order=(ulong)order;
      deals[n].entry=mapped; deals[n].timeMs=time; deals[n].volume=volume; deals[n].price=price;
      deals[n].profit=profit; deals[n].commission=commission; deals[n].swap=swap; deals[n].fee=fee;
      if(mapped==2 && time>lastExit) { lastExit=time; reason=(int)why; }
   }
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   P5TradeResult result;
   if(!P5ClosedTrade(deals,(ulong)row.position,(ulong)row.order,step,positionOpen,pending,result,diagnostic)) return(false);
   row.entryVolume=result.entryVolume; row.exitVolume=result.exitVolume;
   row.entryPrice=result.entryPrice; row.exitPrice=result.exitPrice;
   row.entryMs=result.entryMs; row.exitMs=result.exitMs; row.exitReason=reason;
   row.profit=result.profit; row.commission=result.commission; row.swap=result.swap; row.fee=result.fee; row.net=result.net;
   row.state=3; row.accepted=1; return(true);
}

void P5Reconcile(P5Row &r, long magic, string &diagnostic)
{
   diagnostic="";
   if(r.order<=0) { diagnostic="Order ticket unavailable"; return; }
   if(MQLInfoInteger(MQL_TESTER)==0 && !TerminalInfoInteger(TERMINAL_CONNECTED))
   { diagnostic="Terminal disconnected"; return; }
   ulong order=(ulong)r.order;
   bool liveOrder=OrderSelect(order), historyFinal=false;
   long state=0, position=0; double initial=0, remaining=0;
   if(liveOrder)
   {
      string symbol=""; long objectMagic=0, type=0; double entry=0, stop=0, target=0;
      if(!OrderGetString(ORDER_SYMBOL,symbol) || !OrderGetInteger(ORDER_MAGIC,objectMagic) ||
         !OrderGetInteger(ORDER_TYPE,type) || symbol!=_Symbol || objectMagic!=magic ||
         (type!=ORDER_TYPE_BUY_LIMIT && type!=ORDER_TYPE_SELL_LIMIT && type!=ORDER_TYPE_BUY && type!=ORDER_TYPE_SELL) ||
         ((type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY ? 1 : -1)!=r.direction) ||
         !OrderGetDouble(ORDER_PRICE_OPEN,entry) || !OrderGetDouble(ORDER_SL,stop) || !OrderGetDouble(ORDER_TP,target) ||
         !OrderGetInteger(ORDER_POSITION_ID,position) || position<0) { r.state=6; diagnostic="Live order identity or properties unavailable"; return; }
      if(r.position>0 && position>0 && r.position!=position) { r.state=6; diagnostic="Order and saved position IDs differ"; return; }
      if(position>0) r.position=position;
      r.brokerEntry=entry; r.brokerStop=stop; r.brokerTarget=target; r.accepted=1; r.state=1;
   }
   else
   {
      datetime now=TimeCurrent();
      datetime from=(datetime)MathMax(1,r.requestMs/1000-86400);
      if(now<=0 || !HistorySelect(from,now+60) || !HistoryOrderSelect(order))
      { if(r.state!=3) r.state=6; diagnostic="Entry order history unavailable"; return; }
      string symbol=""; long objectMagic=0, type=0;
      if(!HistoryOrderGetString(order,ORDER_SYMBOL,symbol) || !HistoryOrderGetInteger(order,ORDER_MAGIC,objectMagic) ||
         symbol!=_Symbol || objectMagic!=magic || !HistoryOrderGetInteger(order,ORDER_TYPE,type) ||
         (type!=ORDER_TYPE_BUY_LIMIT && type!=ORDER_TYPE_SELL_LIMIT && type!=ORDER_TYPE_BUY && type!=ORDER_TYPE_SELL) ||
         ((type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY ? 1 : -1)!=r.direction) ||
         !HistoryOrderGetInteger(order,ORDER_STATE,state) ||
         !HistoryOrderGetInteger(order,ORDER_POSITION_ID,position) || position<0 ||
         !HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL,initial) || !P3Positive(initial))
      { if(r.state!=3) r.state=6; diagnostic="Order identity, state or initial volume unavailable"; return; }
      historyFinal=(state==ORDER_STATE_FILLED || state==ORDER_STATE_CANCELED || state==ORDER_STATE_EXPIRED || state==ORDER_STATE_REJECTED);
      if(!historyFinal) { if(r.state!=3) r.state=6; diagnostic="Entry order not final"; return; }
      // FILLED means the original volume was filled. Some brokers expose an
      // unavailable or stale remaining-volume field on a historical order.
      if(state!=ORDER_STATE_FILLED &&
         (!HistoryOrderGetDouble(order,ORDER_VOLUME_CURRENT,remaining) ||
          !MathIsValidNumber(remaining) || remaining<0 || remaining>initial+1e-8))
      { if(r.state!=3) r.state=6; diagnostic="Remaining order volume unavailable"; return; }
      if(r.position>0 && position>0 && r.position!=position) { r.state=6; diagnostic="Order and saved position IDs differ"; return; }
      if(position>0) r.position=position;
      double value=0;
      if(HistoryOrderGetDouble(order,ORDER_PRICE_OPEN,value) && P3Positive(value)) r.brokerEntry=value;
      if(HistoryOrderGetDouble(order,ORDER_SL,value) && MathIsValidNumber(value) && value>=0) r.brokerStop=value;
      if(HistoryOrderGetDouble(order,ORDER_TP,value) && MathIsValidNumber(value) && value>=0) r.brokerTarget=value;
      if(state!=ORDER_STATE_REJECTED) r.accepted=1;
   }
   if(r.position==0)
   {
      ulong pos=0; if(P5DiscoverPosition(order,(datetime)MathMax(1,r.requestMs/1000-86400),pos)) r.position=(long)pos;
   }
   if(r.position>0)
   {
      bool present=false;
      if(!P5PositionPresent((ulong)r.position,magic,present)) { r.state=6; diagnostic="Position scan or identity unavailable"; return; }
      if(present) { r.state=2; r.accepted=1; return; }
      // A final order and full matching deal history must independently prove
      // closure; a vanished position or successful request alone is not proof.
      P5Row evaluated=r;
      double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      double filled=state==ORDER_STATE_FILLED?initial:initial-remaining;
      if(!historyFinal) { r.state=6; diagnostic="Entry order still active"; }
      else if(!P3Positive(step)) { r.state=6; diagnostic="Broker volume step unavailable"; }
      else if(!P3Positive(filled)) { r.state=6; diagnostic="Order fill volume unavailable or inconsistent"; }
      else if(!P5GatherClosed(evaluated,false,liveOrder,diagnostic)) r.state=6;
      else if(MathAbs(evaluated.entryVolume-filled)>step*1e-7)
      { r.state=6; diagnostic="Entry deals do not match confirmed order fill volume"; }
      else r=evaluated;
      return;
   }
   if(!liveOrder && historyFinal)
   {
      // A partial entry without a visible position identifier is unknown.
      if(MathAbs(initial-remaining)>1e-8 || state==ORDER_STATE_FILLED)
      { r.state=6; diagnostic="Filled order position ID unavailable"; return; }
      r.state=(state==ORDER_STATE_REJECTED)?5:4;
   }
}

// Called both before and after broker reconciliation. No dependence on
// trading enablement; a disabled EA can still reconcile its history.
void P5Track(int lane, int active, int direction, ulong order, ulong position, datetime planBar, long magic, bool crf=false)
{
   if(!g_p5Ready || lane<0 || lane>2) return;
   P5Bind(lane,active,direction,order,position,planBar,crf);
   if(!g_p5Ready) return;
   int total=ArraySize(g_p5);
   if(ArraySize(g_p5Reason)!=total && ArrayResize(g_p5Reason,total)!=total) return;
   int pollSlot=crf?3:lane;
   ulong now=GetTickCount64();
   if(g_p5Poll[pollSlot]!=0 && now-g_p5Poll[pollSlot]<5000) return;
   g_p5Poll[pollSlot]=now; bool changed=false, reasonChanged=false;
   for(int i=0;i<ArraySize(g_p5);i++)
   {
      if(g_p5[i].lane!=lane || (g_p5[i].strategy==30007)!=crf || g_p5[i].state==5) continue;
      // Refresh recent completed deals for broker cost/history corrections.
      if(g_p5[i].state==3 && TimeCurrent()>0 && g_p5[i].exitMs/1000 < (long)TimeCurrent()-86400) continue;
      if(g_p5[i].state==4 && TimeCurrent()>0 && g_p5[i].requestMs/1000 < (long)TimeCurrent()-86400) continue;
      P5Row before=g_p5[i], after=before; string diagnostic="";
      P5Reconcile(after,magic,diagnostic);
      if(after.state!=0 && after.state!=6) diagnostic="";
      if(diagnostic!=g_p5Reason[i]) { g_p5Reason[i]=diagnostic; reasonChanged=true; }
      if(P5Changed(before,after)) { g_p5[i]=after; changed=true; }
   }
   if(changed && !P5Save()) { g_p5Ready=false; Print("MT trade diary: reconciliation save failed"); }
   else if(!changed && reasonChanged)
   {
      g_p5ExportReady=P5Export();
      if(!g_p5ExportReady) Print("MT trade diary: CSV export unavailable; binary diary retained");
   }
}

// lane -1 totals every lane of this symbol, for the panel's single header line.
string P5Summary(int lane, datetime now)
{
   string tf=lane<0?"*":(lane==0?"M5":(lane==1?"M15":"M30"));
   if(!g_p5Ready) return(tf+" | Trade diary: unavailable");
   if(now<=0) return(tf+" | Trade diary: clock unavailable");
   MqlDateTime dt; TimeToStruct(now,dt); dt.hour=0; dt.min=0; dt.sec=0;
   long start=(long)StructToTime(dt)*1000, end=start+86400000;
   int s=0,w=0,l=0,be=0,ds=0,dw=0,dl=0,dbe=0;
   for(int i=0;i<ArraySize(g_p5);i++)
   {
      P5Row r=g_p5[i]; if(!r.accepted || (lane>=0 && r.lane!=lane)) continue;
      s++; if(r.requestMs>=start && r.requestMs<end) ds++;
      if(r.state!=3) continue;
      bool today=r.exitMs>=start && r.exitMs<end;
      if(r.net>0) { w++; if(today) dw++; }
      else if(r.net<0) { l++; if(today) dl++; }
      else { be++; if(today) dbe++; }
   }
   return(StringFormat("%s | Trades Today S %d W %d L %d BE %d | All S %d W %d L %d BE %d",tf,ds,dw,dl,dbe,s,w,l,be));
}
// Read-only analysis of reconciled broker trades. Recent means latest exit time,
// not array order; open, partial and review rows are never counted as results.
struct P5Insights
{
   string totals, score, direction, style, recent, exits, context;
};
string P5Rate(int wins, int closed)
{
   return(closed>0?DoubleToString(100.0*wins/closed,1)+"%":"--");
}
void P5BuildInsights(int lane, P5Insights &out)
{
   out.totals=""; out.score=""; out.direction=""; out.style=""; out.recent=""; out.exits=""; out.context="";
   if(!g_p5Ready || lane<0 || lane>2) return;
   int n=0,w=0,l=0,be=0,scoreN[2]={0,0},scoreW[2]={0,0},scoreL[2]={0,0};
   int dirN[2]={0,0},dirW[2]={0,0},styleN[2]={0,0},styleW[2]={0,0};
   double net=0,cost=0; P5Row recent[30]; P5Row latest={}; int nr=0; bool hasLatest=false;
   for(int i=0;i<ArraySize(g_p5);i++)
   {
      P5Row r=g_p5[i];
      if(r.lane!=lane) continue;
      latest=r; hasLatest=true; // last recorded request, matching P5Detail
      if(!r.accepted || r.state!=3) continue;
      n++; if(r.net>0) w++; else if(r.net<0) l++; else be++;
      net+=r.net; cost+=r.commission+r.swap+r.fee;
      int sc=(int)MathAbs(r.score)-2;
      if(sc>=0 && sc<2) { scoreN[sc]++; if(r.net>0) scoreW[sc]++; else if(r.net<0) scoreL[sc]++; }
      int dir=r.direction>0?0:1, style=r.market?0:1;
      dirN[dir]++; styleN[style]++; if(r.net>0) { dirW[dir]++; styleW[style]++; }
      int at=0; while(at<nr && recent[at].exitMs>=r.exitMs) at++;
      if(at<30)
      {
         int last=(int)MathMin(nr,29);
         for(int k=last;k>at;k--) recent[k]=recent[k-1];
         recent[at]=r; if(nr<30) nr++;
      }
   }
   string currency=AccountInfoString(ACCOUNT_CURRENCY);
   out.totals=StringFormat("All closed %d W %d L %d BE %d Win ",n,w,l,be)+P5Rate(w,n)+
              " Net "+(n>0?DoubleToString(net,2)+" "+currency:"--")+
              " Costs "+(n>0?DoubleToString(cost,2)+" "+currency:"--");
   out.score=StringFormat("Score 2/3: %d closed W %d L %d | 3/3: %d closed W %d L %d",
                          scoreN[0],scoreW[0],scoreL[0],scoreN[1],scoreW[1],scoreL[1]);
   out.direction=StringFormat("BUY: %d closed Win ",dirN[0])+P5Rate(dirW[0],dirN[0])+
                 StringFormat(" | SELL: %d closed Win ",dirN[1])+P5Rate(dirW[1],dirN[1]);
   out.style=StringFormat("Market: %d closed Win ",styleN[0])+P5Rate(styleW[0],styleN[0])+
             StringFormat(" | Limit: %d closed Win ",styleN[1])+P5Rate(styleW[1],styleN[1]);
   int rw=0,rl=0,rb=0,tp=0,sl=0,other=0,unknown=0; double rn=0;
   for(int i=0;i<nr;i++)
   {
      P5Row r=recent[i]; rn+=r.net;
      if(r.net>0) rw++; else if(r.net<0) rl++; else rb++;
      if(r.exitReason==DEAL_REASON_TP) tp++; else if(r.exitReason==DEAL_REASON_SL) sl++;
      else if(r.exitReason<0) unknown++; else other++;
   }
   out.recent=StringFormat("Last %d closed: W %d L %d BE %d Win ",nr,rw,rl,rb)+P5Rate(rw,nr)+
              " Net "+(nr>0?DoubleToString(rn,2)+" "+currency:"--");
   out.exits=StringFormat("Last %d final exits: TP %d SL %d Other %d Unknown %d",nr,tp,sl,other,unknown);
   if(hasLatest)
   {
      string regime=latest.regime==1?"STEADY":(latest.regime==2?"CHOPPY":(latest.regime==0?"MIXED":"--"));
      string stop=latest.stopInput<0?"--":(latest.stopInput==1?"ON":"OFF");
      string percent=latest.stopInput<0?"--":IntegerToString(latest.tpPercentInput)+"%";
      if(latest.strategy==30007)
      {
         out.context=StringFormat("Last request: %s CRF MARKET | Score -- | SL ON | Spread ",latest.direction>0?"BUY":"SELL")+
                     DoubleToString(latest.ask-latest.bid,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
         return;
      }
      out.context=StringFormat("Last request: %s %s Score %d RG ",latest.direction>0?"BUY":"SELL",
                               latest.market?"MARKET":"LIMIT",latest.score)+regime+" Spread "+
                  DoubleToString(latest.ask-latest.bid,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS))+
                  " SL input "+stop+" TP input "+percent;
   }
   else out.context="Last request: none";
}
string P5Detail(int lane)
{
   string tf=lane==0?"M5":(lane==1?"M15":"M30");
   if(!g_p5Ready) return(tf+" | Trade details unavailable");
   int pending=0, opened=0, review=0, ended=0;
   for(int i=0;i<ArraySize(g_p5);i++) if(g_p5[i].lane==lane)
   { if(g_p5[i].state==1) pending++; else if(g_p5[i].state==2) opened++; else if(g_p5[i].state==0 || g_p5[i].state==6) review++; else if(g_p5[i].state==4) ended++; }
   string base=StringFormat("%s | Pending %d | Open %d | Review %d | Unfilled %d",tf,pending,opened,review,ended);
   // Include the most recent unresolved row; CSV contains every reason.
   for(int i=ArraySize(g_p5)-1;i>=0;i--) if(g_p5[i].lane==lane && (g_p5[i].state==0 || g_p5[i].state==6))
   {
      string why=(i<ArraySize(g_p5Reason) && g_p5Reason[i]!="")?g_p5Reason[i]:"Awaiting broker reconciliation";
      base+=" | Diagnosis order "+StringFormat("%I64d",g_p5[i].order)+": "+why;
      break;
   }
   for(int i=ArraySize(g_p5)-1;i>=0;i--) if(g_p5[i].lane==lane)
   {
      P5Row r=g_p5[i];
      string state=r.state==3?"CLOSED":(r.state==2?"OPEN":(r.state==1?"PENDING":(r.state==4?"UNFILLED":(r.state==5?"REJECTED":"REVIEW"))));
      string net=r.state==3?DoubleToString(r.net,2)+" "+AccountInfoString(ACCOUNT_CURRENCY):"--";
      return(base+" | Last: "+(r.direction>0?"BUY":"SELL")+" "+state+" | Net: "+net+(g_p5ExportReady?"":" | CSV unavailable"));
   }
   return(base+" | No recorded trades"+(g_p5ExportReady?"":" | CSV unavailable"));
}
#endif
