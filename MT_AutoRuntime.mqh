// Phase 4: broker-confirmed execution of the existing informational plans.
#ifndef MT_AUTO_RUNTIME_MQH
#define MT_AUTO_RUNTIME_MQH
#include "MT_AutoPolicy.mqh"

input bool InpAutoTrading=false; // Auto Trading

struct P4Journal
{
   int active, direction, cancel;
   ulong order, position;
};
struct P4View
{
   P4_SLOT_STATE state;
   int direction;
   ulong order, position;
   double entry, sl, tp, lot;
   string note;
};
P4Journal g_p4[3];
P4View g_p4View[3];
ulong g_p4Attempt[3];
int g_p4Lock=INVALID_HANDLE, g_p4Flags=0;
string g_p4File="";
bool g_p4Ready=false;

string P4TF(int lane) { return(lane==0?"M5":(lane==1?"M15":"M30")); }

// The same account/server/symbol/lane always uses the same 64-bit magic.
// Symbol and journal identity are also checked before managing broker orders.
long P4Magic(int lane)
{
   string key=P3DiaryKey();
   ulong h=1469598103934665603;
   for(int i=0;i<StringLen(key);i++) h=(h^(ulong)StringGetCharacter(key,i))*1099511628211;
   return((long)(4000000000000000+(h%100000000000000)*3+(ulong)lane));
}

void P4Clear(int lane)
{
   g_p4[lane].active=0; g_p4[lane].direction=0; g_p4[lane].cancel=0;
   g_p4[lane].order=0; g_p4[lane].position=0;
}

bool P4Save()
{
   if(g_p4Lock==INVALID_HANDLE) return(false);
   string tmp=g_p4File+".tmp";
   int h=FileOpen(tmp,FILE_WRITE|FILE_BIN|g_p4Flags);
   if(h==INVALID_HANDLE) return(false);
   ResetLastError();
   FileWriteInteger(h,1297368116,INT_VALUE); FileWriteInteger(h,1,INT_VALUE);
   for(int i=0;i<3;i++)
   {
      FileWriteInteger(h,g_p4[i].active,INT_VALUE);
      FileWriteInteger(h,g_p4[i].direction,INT_VALUE);
      FileWriteInteger(h,g_p4[i].cancel,INT_VALUE);
      FileWriteLong(h,(long)g_p4[i].order); FileWriteLong(h,(long)g_p4[i].position);
   }
   FileFlush(h);
   bool ok=(GetLastError()==0 && FileSize(h)==92);
   FileClose(h);
   if(!ok) return(false);
   return(FileMove(tmp,g_p4Flags,g_p4File,g_p4Flags|FILE_REWRITE));
}

bool P4Load()
{
   for(int i=0;i<3;i++) P4Clear(i);
   if(!FileIsExist(g_p4File,g_p4Flags)) return(true);
   int h=FileOpen(g_p4File,FILE_READ|FILE_BIN|g_p4Flags);
   if(h==INVALID_HANDLE) return(false);
   if(FileSize(h)!=92 || FileReadInteger(h,INT_VALUE)!=1297368116 || FileReadInteger(h,INT_VALUE)!=1)
   { FileClose(h); return(false); }
   for(int i=0;i<3;i++)
   {
      g_p4[i].active=FileReadInteger(h,INT_VALUE);
      g_p4[i].direction=FileReadInteger(h,INT_VALUE);
      g_p4[i].cancel=FileReadInteger(h,INT_VALUE);
      long order=FileReadLong(h), position=FileReadLong(h);
      if((g_p4[i].active!=0 && g_p4[i].active!=1) ||
         (g_p4[i].cancel!=0 && g_p4[i].cancel!=1) || order<0 || position<0 ||
         (g_p4[i].active==1 && g_p4[i].direction!=1 && g_p4[i].direction!=-1) ||
         (g_p4[i].active==0 && (g_p4[i].direction!=0 || g_p4[i].cancel!=0 || order!=0 || position!=0)))
      { FileClose(h); return(false); }
      g_p4[i].order=(ulong)order; g_p4[i].position=(ulong)position;
   }
   bool ok=(FileTell(h)==FileSize(h)); FileClose(h); return(ok);
}

void P4Close()
{
   if(g_p4Lock!=INVALID_HANDLE) FileClose(g_p4Lock);
   g_p4Lock=INVALID_HANDLE; g_p4Ready=false;
}

void P4Init()
{
   P4Close();
   for(int i=0;i<3;i++) { P4Clear(i); g_p4Attempt[i]=0; g_p4View[i].note="Starting"; }
   g_p4Flags=MQLInfoInteger(MQL_TESTER)!=0?0:FILE_COMMON;
   g_p4File=P3DiaryKey()+"_autotrade.bin";
   g_p4Lock=FileOpen(g_p4File+".lock",FILE_READ|FILE_WRITE|FILE_BIN|g_p4Flags);
   if(g_p4Lock==INVALID_HANDLE) { Print("MT auto trading: coordinator locked/unavailable"); return; }
   if(!P4Load()) { Print("MT auto trading: unreadable journal; preserving it"); return; }
   g_p4Ready=true;
   if(!P4Save()) { g_p4Ready=false; Print("MT auto trading: journal save failed"); }
}

bool P4Persist()
{
   if(P4Save()) return(true);
   g_p4Ready=false;
   Print("MT auto trading: journal save failed; new actions suspended");
   return(false);
}

bool P4Connected()
{
   return(MQLInfoInteger(MQL_TESTER)!=0 || TerminalInfoInteger(TERMINAL_CONNECTED)!=0);
}

bool P4CanTrade()
{
   return(P4Connected() && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0 &&
          MQLInfoInteger(MQL_TRADE_ALLOWED)!=0 && AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0 &&
          AccountInfoInteger(ACCOUNT_TRADE_EXPERT)!=0);
}

// Execution requires a recent broker quote, independent of the more lenient
// panel market-state threshold. Do not place from a cached/stale snapshot.
bool P4FreshQuote(const MqlTick &quote)
{
   datetime now=ServerNow();
   return(now>0 && quote.time>0 && quote.time<=now+1 && now-quote.time<=10 &&
          P3Positive(quote.bid) && P3Positive(quote.ask) && quote.ask>=quote.bid);
}

// A missing live position is not proof of closure. Reconcile actual deals.
bool P4PositionClosed(ulong id)
{
   if(id==0 || !P4Connected() || !HistorySelectByPosition(id)) return(false);
   double in=0.0,out=0.0;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong ticket=HistoryDealGetTicket(i);
      long dealPosition=0, how=0; double volume=0;
      if(ticket==0 || !HistoryDealGetInteger(ticket,DEAL_POSITION_ID,dealPosition)) return(false);
      if((ulong)dealPosition!=id) continue;
      if(!HistoryDealGetInteger(ticket,DEAL_ENTRY,how) || !HistoryDealGetDouble(ticket,DEAL_VOLUME,volume) ||
         !MathIsValidNumber(volume) || volume<0.0) return(false);
      if(volume==0.0) continue;
      if(how==DEAL_ENTRY_IN) in+=volume;
      else if(how==DEAL_ENTRY_OUT || how==DEAL_ENTRY_OUT_BY) out+=volume;
      else return(false); // reversal or unrecognized deal type: cannot prove closure
   }
   return(in>0.0 && MathAbs(out-in)<=1e-8);
}

bool P4JournalEnded(int lane)
{
   P4Journal s=g_p4[lane];
   if(s.order==0) return(s.position>0 && P4PositionClosed(s.position));
   if(!P4Connected() || !HistoryOrderSelect(s.order)) return(false);
   long state=0, position=0;
   if(!HistoryOrderGetInteger(s.order,ORDER_STATE,state) ||
      !HistoryOrderGetInteger(s.order,ORDER_POSITION_ID,position) || position<0) return(false);
   if(state!=ORDER_STATE_CANCELED && state!=ORDER_STATE_EXPIRED &&
      state!=ORDER_STATE_REJECTED && state!=ORDER_STATE_FILLED) return(false);
   ulong id=(ulong)position;
   if(s.position>0 && id!=s.position) return(false);
   if(id>0) return(P4PositionClosed(id));
   if(s.position!=0 || state==ORDER_STATE_FILLED) return(false);
   // A cancelled/expired order may have been partially filled before its
   // position ID becomes visible. Only clear a demonstrably unfilled order.
   double initial=0, remaining=0;
   if(!HistoryOrderGetDouble(s.order,ORDER_VOLUME_INITIAL,initial) ||
      !HistoryOrderGetDouble(s.order,ORDER_VOLUME_CURRENT,remaining) ||
      !P3Positive(initial) || !MathIsValidNumber(remaining) || remaining<0.0) return(false);
   return(MathAbs(initial-remaining)<=1e-8);
}

bool P4Linked(ulong order, ulong position)
{
   if(order==0 || position==0) return(false);
   long id=0;
   if(OrderSelect(order) && OrderGetInteger(ORDER_POSITION_ID,id) && id>0 && (ulong)id==position) return(true);
   if(HistoryOrderSelect(order) && HistoryOrderGetInteger(order,ORDER_POSITION_ID,id) && id>0 && (ulong)id==position) return(true);
   return(false);
}

// Read the broker's current objects; never use a submitted request as proof of a fill.
void P4Refresh(int lane)
{
   P4View v; v.state=P4_EMPTY; v.direction=0; v.order=0; v.position=0;
   v.entry=0; v.sl=0; v.tp=0; v.lot=0; v.note="";
   if(!P4Connected())
   { v.state=P4_UNCERTAIN; v.note="Disconnected"; g_p4View[lane]=v; return; }
   int positions=0,orders=0; ulong positionId=0,orderTicket=0; int posDir=0,orderDir=0;
   double posEntry=0,posSL=0,posTP=0,posLot=0,ordEntry=0,ordSL=0,ordTP=0,ordLot=0;
   string posComment="",ordComment="";
   bool orderPending=false;
   long magic=P4Magic(lane);
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong tk=PositionGetTicket(i);
      string symbol=""; long objectMagic=0, id=0, type=0;
      if(tk==0 || !PositionGetString(POSITION_SYMBOL,symbol) || !PositionGetInteger(POSITION_MAGIC,objectMagic))
      { v.state=P4_UNCERTAIN; v.note="Position scan unavailable"; g_p4View[lane]=v; return; }
      if(symbol!=_Symbol || objectMagic!=magic) continue;
      if(!PositionGetInteger(POSITION_IDENTIFIER,id) || id<=0 || !PositionGetInteger(POSITION_TYPE,type) ||
         (type!=POSITION_TYPE_BUY && type!=POSITION_TYPE_SELL) ||
         !PositionGetDouble(POSITION_PRICE_OPEN,posEntry) || !PositionGetDouble(POSITION_SL,posSL) ||
         !PositionGetDouble(POSITION_TP,posTP) || !PositionGetDouble(POSITION_VOLUME,posLot) ||
         !PositionGetString(POSITION_COMMENT,posComment) || !P3Positive(posEntry) || !P3Positive(posLot) ||
         !MathIsValidNumber(posSL) || posSL<0.0 || !MathIsValidNumber(posTP) || posTP<0.0)
      { v.state=P4_UNCERTAIN; v.note="Position data unavailable"; g_p4View[lane]=v; return; }
      positions++; positionId=(ulong)id; posDir=type==POSITION_TYPE_BUY?1:-1;
   }
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong tk=OrderGetTicket(i);
      string symbol=""; long objectMagic=0, type=0;
      if(tk==0 || !OrderGetString(ORDER_SYMBOL,symbol) || !OrderGetInteger(ORDER_MAGIC,objectMagic))
      { v.state=P4_UNCERTAIN; v.note="Order scan unavailable"; g_p4View[lane]=v; return; }
      if(symbol!=_Symbol || objectMagic!=magic) continue;
      if(!OrderGetInteger(ORDER_TYPE,type) || !OrderGetDouble(ORDER_PRICE_OPEN,ordEntry) ||
         !OrderGetDouble(ORDER_SL,ordSL) || !OrderGetDouble(ORDER_TP,ordTP) ||
         !OrderGetDouble(ORDER_VOLUME_CURRENT,ordLot) || !OrderGetString(ORDER_COMMENT,ordComment) ||
         !P3Positive(ordEntry) || !P3Positive(ordLot) || !MathIsValidNumber(ordSL) || ordSL<0.0 ||
         !MathIsValidNumber(ordTP) || ordTP<0.0)
      { v.state=P4_UNCERTAIN; v.note="Order data unavailable"; g_p4View[lane]=v; return; }
      if(type!=ORDER_TYPE_BUY_LIMIT && type!=ORDER_TYPE_SELL_LIMIT && type!=ORDER_TYPE_BUY && type!=ORDER_TYPE_SELL)
      { orders+=2; continue; }
      orders++; orderTicket=tk;
      orderPending=(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_SELL_LIMIT);
      orderDir=(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY)?1:-1;
   }
   if(positions>1 || orders>1)
   { v.state=P4_MULTIPLE; v.note="MULTIPLE: REVIEW"; g_p4View[lane]=v; return; }
   if(g_p4[lane].active==0 && (positions>0 || orders>0))
   { v.state=P4_UNTRACKED; v.note="Untracked broker object: REVIEW"; g_p4View[lane]=v; return; }
   if(positions>0 && (positionId==0 || posDir!=g_p4[lane].direction ||
      (g_p4[lane].position!=0 && g_p4[lane].position!=positionId)))
   { v.state=P4_UNCERTAIN; v.note="Position identity: REVIEW"; g_p4View[lane]=v; return; }
   if(orders>0 && (orderDir!=g_p4[lane].direction ||
      (g_p4[lane].order!=0 && g_p4[lane].order!=orderTicket)))
   { v.state=P4_UNCERTAIN; v.note="Order identity: REVIEW"; g_p4View[lane]=v; return; }
   // After a crash before receipt, only adopt an identifiable MT-tagged object.
   if(g_p4[lane].active!=0 && g_p4[lane].order==0 && g_p4[lane].position==0 &&
      ((positions>0 && StringFind(posComment,"MT4-")!=0) ||
       (orders>0 && StringFind(ordComment,"MT4-")!=0)))
   { v.state=P4_UNCERTAIN; v.note="Unconfirmed intent: REVIEW"; g_p4View[lane]=v; return; }
   if(positions>0 && g_p4[lane].order>0 && g_p4[lane].position==0 &&
      !P4Linked(g_p4[lane].order,positionId))
   { v.state=P4_UNCERTAIN; v.note="Waiting for broker identity"; g_p4View[lane]=v; return; }
   if(positions>0 && orders>0 && !P4Linked(orderTicket,positionId))
   { v.state=P4_UNCERTAIN; v.note="Partial-fill identity: REVIEW"; g_p4View[lane]=v; return; }
   bool changed=false;
   if(orders>0 && g_p4[lane].order==0) { g_p4[lane].order=orderTicket; changed=true; }
   if(positions>0 && g_p4[lane].position==0) { g_p4[lane].position=positionId; changed=true; }
   // Never knowingly leave an owned pending entry without both planned exits.
   if(orders>0 && orderPending && (ordSL<=0.0 || ordTP<=0.0) && g_p4[lane].cancel==0)
   { g_p4[lane].cancel=1; changed=true; }
   if(changed && !P4Persist()) { v.state=P4_UNCERTAIN; v.note="Journal unavailable"; g_p4View[lane]=v; return; }
   if(orders>0 && !orderPending)
   { v.state=P4_UNCERTAIN; v.note="Market request in flight"; g_p4View[lane]=v; return; }
   if(positions>0)
   {
      v.state=orders>0?P4_PARTIAL:P4_OPEN; v.direction=posDir; v.position=positionId; v.order=orderTicket;
      v.entry=posEntry; v.sl=posSL; v.tp=posTP; v.lot=posLot;
      if(posSL<=0.0 || posTP<=0.0) v.note="SL/TP missing: REVIEW";
      if(orders>0) { if(v.note!="") v.note+="; "; v.note+="Entry remainder pending"; }
   }
   else if(orders>0)
   {
      v.state=P4_PENDING; v.direction=orderDir; v.order=orderTicket;
      v.entry=ordEntry; v.sl=ordSL; v.tp=ordTP; v.lot=ordLot;
   }
   else if(g_p4[lane].active!=0)
   {
      if(P4JournalEnded(lane))
      {
         P4Clear(lane);
         if(!P4Persist()) { v.state=P4_UNCERTAIN; v.note="Journal unavailable"; }
      }
      else { v.state=P4_UNCERTAIN; v.note="Await broker confirmation / REVIEW"; }
   }
   g_p4View[lane]=v;
}

bool P4DefiniteReject(uint code)
{
   return(code==TRADE_RETCODE_REJECT || code==TRADE_RETCODE_REQUOTE ||
          code==TRADE_RETCODE_INVALID || code==TRADE_RETCODE_INVALID_VOLUME ||
          code==TRADE_RETCODE_INVALID_PRICE || code==TRADE_RETCODE_INVALID_STOPS ||
          code==TRADE_RETCODE_TRADE_DISABLED || code==TRADE_RETCODE_MARKET_CLOSED ||
          code==TRADE_RETCODE_NO_MONEY || code==TRADE_RETCODE_PRICE_CHANGED ||
          code==TRADE_RETCODE_PRICE_OFF || code==TRADE_RETCODE_INVALID_EXPIRATION ||
          code==TRADE_RETCODE_INVALID_FILL);
}

bool P4FillMode(bool market, ENUM_ORDER_TYPE_FILLING &fill)
{
   if(!market) { fill=ORDER_FILLING_RETURN; return(true); }
   long modes=0, execution=0;
   if(!SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE,modes) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE,execution)) return(false);
   if((modes & SYMBOL_FILLING_FOK)!=0) { fill=ORDER_FILLING_FOK; return(true); }
   if((modes & SYMBOL_FILLING_IOC)!=0) { fill=ORDER_FILLING_IOC; return(true); }
   if(execution!=SYMBOL_TRADE_EXECUTION_MARKET) { fill=ORDER_FILLING_RETURN; return(true); }
   return(false);
}

void P4Cancel(int lane, ulong ticket)
{
   if(ticket==0 || !P4CanTrade() || !OrderSelect(ticket) || g_p4[lane].order!=ticket) return;
   string symbol=""; long magic=0, type=0;
   if(!OrderGetString(ORDER_SYMBOL,symbol) || !OrderGetInteger(ORDER_MAGIC,magic) ||
      !OrderGetInteger(ORDER_TYPE,type) || symbol!=_Symbol || magic!=P4Magic(lane) ||
      (type!=ORDER_TYPE_BUY_LIMIT && type!=ORDER_TYPE_SELL_LIMIT)) return;
   ulong now=GetTickCount64();
   if(g_p4Attempt[lane]!=0 && now-g_p4Attempt[lane]<5000) return;
   if(g_p4[lane].cancel==0) { g_p4[lane].cancel=1; if(!P4Persist()) return; }
   MqlTradeRequest request={}; MqlTradeResult result={};
   request.action=TRADE_ACTION_REMOVE; request.order=ticket; request.symbol=_Symbol;
   request.magic=(ulong)P4Magic(lane);
   g_p4Attempt[lane]=now;
   bool sent=OrderSend(request,result);
   g_p4View[lane].note=StringFormat("Cancellation requested (%u)",result.retcode);
   if(!sent) PrintFormat("MT %s cancellation request failed: retcode %u error %d",P4TF(lane),result.retcode,GetLastError());
}

// Do not open a position where the broker reports that its SL/TP will be
// removed at the end of the day. DAY-only symbols do not provide a documented
// GTC protective-stop lifetime, so their entries are held instead of assuming.
bool P4ProtectionAllowed(bool market)
{
   long orderMode=0, expiration=0, stopLifetime=0;
   if(!SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE,orderMode) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE,expiration) ||
      (expiration & SYMBOL_EXPIRATION_GTC)==0 ||
      !SymbolInfoInteger(_Symbol,SYMBOL_ORDER_GTC_MODE,stopLifetime)) return(false);
   long required=(market?SYMBOL_ORDER_MARKET:SYMBOL_ORDER_LIMIT)|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
   return((orderMode & required)==required &&
          (stopLifetime==SYMBOL_ORDERS_GTC || stopLifetime==SYMBOL_ORDERS_DAILY_EXCLUDING_STOPS));
}

// Validate frozen levels against the live executable quote; never chase or
// reprice a plan. OrderCheck remains the broker's final preflight.
bool P4LiveLevels(const MqlTick &quote, const P3Plan &plan)
{
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   long stops=0;
   if(!SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL,stops) || !P3Positive(point) || stops<0 || !P3Positive(quote.bid) ||
      !P3Positive(quote.ask) || quote.ask<quote.bid || !P3Positive(plan.entry) ||
      !P3Positive(plan.stop) || !P3Positive(plan.target)) return(false);
   // Allow only numerical noise at the minimum-distance boundary.
   double minimum=MathMax(0.0,(double)stops*point-point*1e-7);
   if(plan.signal>0)
   {
      if(plan.stop>=plan.entry || plan.target<=plan.entry) return(false);
      if(plan.market) return(plan.stop<quote.bid && plan.target>quote.bid &&
                             plan.stop<quote.ask && plan.target>quote.ask &&
                             quote.bid-plan.stop>=minimum && plan.target-quote.bid>=minimum);
      return(plan.entry<quote.ask && quote.ask-plan.entry>=minimum &&
             plan.entry-plan.stop>=minimum && plan.target-plan.entry>=minimum);
   }
   if(plan.signal<0)
   {
      if(plan.stop<=plan.entry || plan.target>=plan.entry) return(false);
      if(plan.market) return(plan.stop>quote.ask && plan.target<quote.ask &&
                             plan.stop>quote.bid && plan.target<quote.bid &&
                             plan.stop-quote.ask>=minimum && quote.ask-plan.target>=minimum);
      return(plan.entry>quote.bid && plan.entry-quote.bid>=minimum &&
             plan.stop-plan.entry>=minimum && plan.entry-plan.target>=minimum);
   }
   return(false);
}

void P4Place(int lane, const MqlTick &quote, const P3Plan &plan)
{
   ulong now=GetTickCount64();
   if(g_p4Attempt[lane]!=0 && now-g_p4Attempt[lane]<5000) return;
   if(!P4PlanMatchesSignal(plan.signal,g_p3[lane].score,plan.market) || !plan.valid ||
      !P4CanTrade() || g_marketState!=MARKET_OPEN || !P4FreshQuote(quote)) return;
   if(!P4LiveLevels(quote,plan)) { g_p4View[lane].note="Frozen plan invalid at live quote"; return; }
   if(!P4ProtectionAllowed(plan.market)) { g_p4View[lane].note="SL/TP lifetime or order mode unavailable"; return; }
   ENUM_ORDER_TYPE_FILLING fill;
   if(!P4FillMode(plan.market,fill)) { g_p4View[lane].note="Filling mode unavailable"; return; }
   MqlTradeRequest request={}; MqlTradeCheckResult check={}; MqlTradeResult result={};
   request.action=plan.market?TRADE_ACTION_DEAL:TRADE_ACTION_PENDING;
   request.symbol=_Symbol; request.magic=(ulong)P4Magic(lane); request.volume=plan.lot;
   request.type=plan.market?(plan.signal>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL):
                            (plan.signal>0?ORDER_TYPE_BUY_LIMIT:ORDER_TYPE_SELL_LIMIT);
   request.price=plan.market?(plan.signal>0?quote.ask:quote.bid):plan.entry;
   request.sl=plan.stop; request.tp=plan.target; request.deviation=10;
   request.type_filling=fill; request.type_time=ORDER_TIME_GTC; request.comment="MT4-"+P4TF(lane);
   g_p4Attempt[lane]=now;
   ResetLastError();
   if(!OrderCheck(request,check) || check.retcode!=0)
   { g_p4View[lane].note=StringFormat("Order check: %u",check.retcode); return; }
   // Persist intent before send. Uncertain results never trigger a blind resend.
   g_p4[lane].active=1; g_p4[lane].direction=plan.signal; g_p4[lane].cancel=0;
   g_p4[lane].order=0; g_p4[lane].position=0;
   if(!P4Persist()) return;
   ResetLastError();
   bool sent=OrderSend(request,result);
   if(result.order>0) g_p4[lane].order=result.order;
   else if(P4DefiniteReject(result.retcode)) P4Clear(lane);
   if(!P4Persist()) return;
   if(!sent || P4DefiniteReject(result.retcode))
      PrintFormat("MT %s order result %u error %d",P4TF(lane),result.retcode,GetLastError());
   g_p4View[lane].state=P4_UNCERTAIN;
   g_p4View[lane].note=StringFormat("Order result %u; awaiting broker",result.retcode);
}

// Called on a symbol tick for new entries and on the timer for cancellation/
// reconciliation. It never modifies or closes an open position.
void P4Process(bool allowEntry)
{
   if(!ChartSupported() || !g_p4Ready) return;
   for(int lane=0;lane<3;lane++)
   {
      P4Refresh(lane);
      if(!g_p4Ready) return;
      P3Plan plan; P3MakePlan(lane,plan);
      bool hedging=AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
      P4_ACTION action=P4Decide(InpAutoTrading,plan.signal,g_p4View[lane].state,
                                g_p4View[lane].direction,hedging,P4CanTrade(),plan.valid);
      // A prior cancellation request remains in force even if the signal changes again.
      if(g_p4[lane].cancel!=0 && g_p4View[lane].state==P4_PENDING) action=P4_CANCEL_REMAINDER;
      if(action==P4_CANCEL_REMAINDER)
      {
         if(g_p4[lane].cancel==0) { g_p4[lane].cancel=1; if(!P4Persist()) return; }
         g_p4View[lane].note="Cancellation pending";
         P4Cancel(lane,g_p4View[lane].order);
      }
      else if(action==P4_PLACE && allowEntry)
      {
         MqlTick quote;
         if(SymbolInfoTick(_Symbol,quote) && P4FreshQuote(quote))
         {
            if(plan.valid && P4PlanMatchesSignal(plan.signal,g_p3[lane].score,plan.market)) P4Place(lane,quote,plan);
         }
         else g_p4View[lane].note="Fresh quote unavailable";
      }
      else if(action==P4_HOLD && g_p4View[lane].state==P4_EMPTY && InpAutoTrading)
         g_p4View[lane].note=hedging?"Plan or trading permission unavailable":"Hedging account required";
   }
}

// Convert gross account-currency estimates to USD using a fresh selected
// direct currency pair; no rate or synthetic USD amount is fabricated.
bool P4ToUSD(double amount, double &usd)
{
   string currency=AccountInfoString(ACCOUNT_CURRENCY);
   if(currency=="USD") { usd=amount; return(true); }
   datetime now=ServerNow();
   if(now<=0 || currency=="") return(false);
   int total=SymbolsTotal(true);
   for(int i=0;i<total;i++)
   {
      string symbol=SymbolName(i,true);
      long calculation=0;
      if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE,calculation) ||
         (calculation!=SYMBOL_CALC_MODE_FOREX && calculation!=SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)) continue;
      string base=SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE), quoteCurrency=SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);
      bool direct=base==currency && quoteCurrency=="USD";
      bool inverse=base=="USD" && quoteCurrency==currency;
      if(!direct && !inverse) continue;
      MqlTick q;
      if(!SymbolInfoTick(symbol,q) || !P3Positive(q.bid) || !P3Positive(q.ask) || q.ask<q.bid ||
         q.time<=0 || q.time>now+1 || now-q.time>120) continue;
      usd=direct ? amount*(amount>=0?q.bid:q.ask) : amount/(amount>=0?q.ask:q.bid);
      return(MathIsValidNumber(usd));
   }
   return(false);
}

string P4Money(int direction, double lot, double entry, double exitPrice)
{
   if(!P3Positive(lot) || !P3Positive(entry) || !P3Positive(exitPrice)) return("-- USD");
   double amount=0,usd=0;
   if(!OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,lot,entry,exitPrice,amount) ||
      !MathIsValidNumber(amount) || !P4ToUSD(amount,usd)) return("-- USD");
   return((usd>0?"+":"")+DoubleToString(usd,2)+" USD");
}

string P4Line(int lane)
{
   string tf=P4TF(lane);
   if(!g_p4Ready) return(tf+" | Auto: coordinator unavailable");
   P4View v=g_p4View[lane];
   if(v.state!=P4_PENDING && v.state!=P4_OPEN && v.state!=P4_PARTIAL)
   {
      if(v.note!="") return(tf+" | Auto: "+v.note);
      return(tf+(InpAutoTrading?" | Auto: no active order":" | Auto: OFF"));
   }
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   string s=tf+" | "+(v.direction>0?"BUY ":"SELL ")+(v.state==P4_PENDING?"LIMIT":"OPEN")+
            " | Entry "+DoubleToString(v.entry,digits);
   if(v.state==P4_PENDING)
   {
      MqlTick q;
      if(g_marketState==MARKET_OPEN && SymbolInfoTick(_Symbol,q) && P4FreshQuote(q))
      {
         double distance=v.direction>0?q.ask-v.entry:v.entry-q.bid;
         s+=" (distance "+DoubleToString(distance,digits)+")";
      }
      else s+=" (distance --)";
   }
   s+=" | Lot "+P3LotText(v.lot)+" | SL "+(v.sl>0?DoubleToString(v.sl,digits):"--")+
      " ("+P4Money(v.direction,v.lot,v.entry,v.sl)+") | TP "+(v.tp>0?DoubleToString(v.tp,digits):"--")+
      " ("+P4Money(v.direction,v.lot,v.entry,v.tp)+")";
   if(v.note!="") s+=" | "+v.note;
   return(s);
}
#endif
