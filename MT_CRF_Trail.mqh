#ifndef MT_CRF_TRAIL_MQH
#define MT_CRF_TRAIL_MQH

// Separate CRF-side journal leaves the original MT journal format untouched.
// A close intent is written before sending and held until broker reconciliation.
struct TRState
{
   ulong position, closeTicket;
   datetime candleActivation;
   double peak, closeVolume;
   int pullActive, closing;
};
TRState g_trail[4];
ulong g_trailSessionPosition[4];
datetime g_trailSessionBar[4];
string g_trailNote[4];

bool TRValid(const TRState &s)
{
   if(s.candleActivation<0 || !MathIsValidNumber(s.peak) || s.peak<0 ||
      !MathIsValidNumber(s.closeVolume) || s.peak==EMPTY_VALUE || s.closeVolume==EMPTY_VALUE || s.closeVolume<0 ||
      (s.pullActive!=0 && s.pullActive!=1) || (s.closing!=0 && s.closing!=1)) return false;
   if(s.position==0) return s.closeTicket==0 && s.candleActivation==0 && s.peak==0 &&
                            s.closeVolume==0 && s.pullActive==0 && s.closing==0;
   if(s.pullActive==1 && s.peak<=0) return false;
   return s.closing==0 ? (s.closeTicket==0 && s.closeVolume==0) :
                         (s.closeTicket>0 && P3Positive(s.closeVolume));
}
bool TRSave()
{
   if(g_p4Lock==INVALID_HANDLE) return false;
   for(int i=0;i<4;i++) if(!TRValid(g_trail[i])) return false;
   string dest=g_p4File+".trail",tmp=dest+".tmp";
   int h=FileOpen(tmp,FILE_WRITE|FILE_BIN|g_p4Flags); if(h==INVALID_HANDLE) return false;
   ResetLastError(); FileWriteInteger(h,1297368148,INT_VALUE); FileWriteInteger(h,1,INT_VALUE);
   for(int i=0;i<4;i++)
   {
      FileWriteLong(h,(long)g_trail[i].position); FileWriteLong(h,(long)g_trail[i].candleActivation);
      FileWriteDouble(h,g_trail[i].peak); FileWriteInteger(h,g_trail[i].pullActive,INT_VALUE);
      FileWriteInteger(h,g_trail[i].closing,INT_VALUE); FileWriteLong(h,(long)g_trail[i].closeTicket);
      FileWriteDouble(h,g_trail[i].closeVolume);
   }
   FileFlush(h); bool ok=GetLastError()==0 && FileSize(h)==200; FileClose(h);
   return ok && FileMove(tmp,g_p4Flags,dest,g_p4Flags|FILE_REWRITE);
}
bool TRPersist()
{
   if(TRSave()) return true;
   g_p4Ready=false; Print("MT CRF trail journal unavailable; actions suspended"); return false;
}
bool TRInit()
{
   for(int i=0;i<4;i++) { ZeroMemory(g_trail[i]); g_trailSessionPosition[i]=0; g_trailSessionBar[i]=0; g_trailNote[i]=""; }
   if(!g_p4Ready) return false;
   string file=g_p4File+".trail";
   if(!FileIsExist(file,g_p4Flags)) return TRPersist();
   int h=FileOpen(file,FILE_READ|FILE_BIN|g_p4Flags); if(h==INVALID_HANDLE) { g_p4Ready=false; return false; }
   if(FileSize(h)!=200) { FileClose(h); g_p4Ready=false; return false; }
   ResetLastError(); int magic=FileReadInteger(h,INT_VALUE),version=FileReadInteger(h,INT_VALUE);
   bool valid=magic==1297368148 && version==1;
   for(int i=0;i<4;i++)
   {
      long position=FileReadLong(h),activation=FileReadLong(h);
      g_trail[i].peak=FileReadDouble(h); g_trail[i].pullActive=FileReadInteger(h,INT_VALUE);
      g_trail[i].closing=FileReadInteger(h,INT_VALUE); long ticket=FileReadLong(h);
      g_trail[i].closeVolume=FileReadDouble(h);
      if(position<0 || activation<0 || ticket<0) valid=false;
      g_trail[i].position=(ulong)position; g_trail[i].candleActivation=(datetime)activation; g_trail[i].closeTicket=(ulong)ticket;
      if(!TRValid(g_trail[i])) valid=false;
   }
   valid=valid && GetLastError()==0 && FileTell(h)==FileSize(h); FileClose(h);
   if(!valid) { g_p4Ready=false; Print("MT CRF trail journal unreadable; preserving file"); }
   return valid;
}
bool TRNativeBusy(int lane) { return lane>=0 && lane<3 && g_trail[lane].closing!=0; }

// P4Refresh must already have established one owned position with linked
// journal identity. Re-read ticket/properties, not the presentation cache.
bool TRSelect(int lane, ulong &ticket, long &opened, double &profit)
{
   ticket=0; opened=0; profit=0;
   P4View v=g_p4View[lane];
   if(v.state!=P4_OPEN || g_p4[lane].active==0 ||
      g_p4[lane].position==0 || g_p4[lane].position!=v.position) return false;
   int found=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); string symbol=""; long magic=0,id=0,type=0;
      if(t==0 || !PositionGetString(POSITION_SYMBOL,symbol) || !PositionGetInteger(POSITION_MAGIC,magic)) return false;
      if(symbol!=_Symbol || magic!=P4Magic(lane)) continue;
      if(!PositionGetInteger(POSITION_IDENTIFIER,id) || (ulong)id!=v.position ||
         !PositionGetInteger(POSITION_TYPE,type) || (type!=POSITION_TYPE_BUY && type!=POSITION_TYPE_SELL) ||
         (type==POSITION_TYPE_BUY?1:-1)!=v.direction) return false;
      ticket=t; found++;
   }
   if(found!=1 || !PositionSelectByTicket(ticket)) return false;
   double entry=0,tp=0,volume=0;
   return PositionGetInteger(POSITION_TIME,opened) && opened>0 &&
          PositionGetDouble(POSITION_PRICE_OPEN,entry) && entry==v.entry && P3Positive(entry) &&
          PositionGetDouble(POSITION_TP,tp) && tp==v.tp && P3Positive(tp) &&
          PositionGetDouble(POSITION_VOLUME,volume) && volume==v.lot && P3Positive(volume) &&
          PositionGetDouble(POSITION_PROFIT,profit) && MathIsValidNumber(profit) && profit!=EMPTY_VALUE;
}

bool TRCloseNative(int lane, ulong ticket, const MqlTick &q)
{
   if(!InpMtTrailStop || !InpAutoTrading || !g_p4Ready || !P4CanTrade() || g_marketState!=MARKET_OPEN ||
      AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING ||
      !P4FreshQuote(q) || g_trail[lane].closing || (lane==1 && (g_crfCloseKind!=0 || g_crfTpPosition!=0))) return false;
   ulong current=0; long opened=0; double profit=0;
   if(!TRSelect(lane,current,opened,profit) || current!=ticket || profit<=0 || q.time<opened) return false;
   P4View v=g_p4View[lane]; ENUM_ORDER_TYPE_FILLING fill; if(!P4FillMode(true,fill)) return false;
   ulong now=GetTickCount64(); if(g_p4Attempt[lane]!=0 && now-g_p4Attempt[lane]<5000) return false;
   MqlTradeRequest request={}; MqlTradeCheckResult check={}; MqlTradeResult result={};
   request.action=TRADE_ACTION_DEAL; request.position=ticket; request.symbol=_Symbol; request.magic=(ulong)P4Magic(lane);
   request.type=v.direction>0?ORDER_TYPE_SELL:ORDER_TYPE_BUY; request.volume=v.lot;
   request.price=v.direction>0?q.bid:q.ask; request.deviation=10; request.type_filling=fill; request.comment="MT4 trail exit";
   g_p4Attempt[lane]=now;
   if(!OrderCheck(request,check) || check.retcode!=0) return false;
   MqlTick latest; ulong again=0; long openedAgain=0; double finalProfit=0;
   P4Refresh(lane);
   if(!g_p4Ready || !TRSelect(lane,again,openedAgain,finalProfit) || again!=ticket ||
      g_p4View[lane].position!=v.position || g_p4View[lane].lot!=v.lot || finalProfit<=0 ||
      !SymbolInfoTick(_Symbol,latest) || !P4FreshQuote(latest) || latest.bid!=q.bid || latest.ask!=q.ask ||
      !InpAutoTrading || !InpMtTrailStop || !P4CanTrade() ||
      AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING ||
      (lane==1 && (g_crfCloseKind!=0 || g_crfTpPosition!=0))) return false;
   g_trail[lane].closing=1; g_trail[lane].closeTicket=ticket; g_trail[lane].closeVolume=v.lot;
   if(!TRPersist()) return false;
   bool sent=OrderSend(request,result);
   if(result.order==0 && result.deal==0 && P4DefiniteReject(result.retcode))
   { g_trail[lane].closing=0; g_trail[lane].closeTicket=0; g_trail[lane].closeVolume=0; if(!TRPersist()) return false; }
   if(!sent) PrintFormat("MT trail close result %u error %d; reconcile broker state",result.retcode,GetLastError());
   return true;
}

void TRStep(int lane)
{
   if(!g_p4Ready) return;
   TRState s=g_trail[lane]; P4View v=g_p4View[lane];
   if(s.closing)
   {
      if(P4PositionClosed(s.position))
      { ZeroMemory(g_trail[lane]); g_trailSessionPosition[lane]=0; if(!TRPersist()) return; }
      else { g_trailNote[lane]="Trailstop close awaiting broker"; return; }
   }
   if(v.state!=P4_OPEN || g_p4[lane].position==0 || v.position!=g_p4[lane].position)
   {
      if(g_trail[lane].position!=0 && P4PositionClosed(g_trail[lane].position))
      { ZeroMemory(g_trail[lane]); g_trailSessionPosition[lane]=0; TRPersist(); }
      g_trailNote[lane]=""; return;
   }
   if(lane==1 && (g_crfCloseKind!=0 || g_crfTpPosition!=0)) { g_trailNote[lane]="Trailstop waiting broker action"; return; }
   if(lane==3 && g_crfCloseKind!=0) { g_trailNote[lane]="Trailstop waiting broker action"; return; }
   if(lane==3 && InpMode==MT_CRF_MODE_MT) { g_trailNote[lane]="CRF disabled: REVIEW"; return; }
   bool enabled=lane==3?InpCrfTrailStop:InpMtTrailStop;
   if(!enabled) { g_trailNote[lane]="Trailstop OFF"; return; }
   if(g_trail[lane].position!=0 && g_trail[lane].position!=v.position)
   {
      if(!P4PositionClosed(g_trail[lane].position)) { g_trailNote[lane]="Trailstop position mismatch: REVIEW"; return; }
      ZeroMemory(g_trail[lane]); g_trailSessionPosition[lane]=0; if(!TRPersist()) return;
   }
   ulong ticket=0; long opened=0; double profit=0;
   if(!TRSelect(lane,ticket,opened,profit)) { g_trailNote[lane]="Trailstop data unavailable"; return; }
   ENUM_TIMEFRAMES tf=P4Timeframe(lane);
   int shift=iBarShift(_Symbol,tf,(datetime)opened,false);
   datetime fillBar=shift>=0?iTime(_Symbol,tf,shift):0, currentBar=iTime(_Symbol,tf,0), latest=iTime(_Symbol,tf,1);
   if(shift<0 || fillBar<=0 || fillBar>(datetime)opened || currentBar<=0 || latest<=0 ||
      (shift>0 && iTime(_Symbol,tf,shift-1)<=(datetime)opened))
   { g_trailNote[lane]="Trailstop history unavailable"; return; }
   if(g_trailSessionPosition[lane]!=v.position) { g_trailSessionPosition[lane]=v.position; g_trailSessionBar[lane]=latest; }
   MqlTick q; bool quote=SymbolInfoTick(_Symbol,q) && P4FreshQuote(q) && q.time>=opened;
   double gain=quote?v.direction*((v.direction>0?q.bid:q.ask)-v.entry):0;
   double distance=v.direction*(v.tp-v.entry);
   bool changed=false;
   if(g_trail[lane].position==0) { g_trail[lane].position=v.position; changed=true; }
   if(quote && distance>0 && gain>=0.5*distance && gain>0 && !g_trail[lane].pullActive)
   { g_trail[lane].pullActive=1; g_trail[lane].peak=gain; changed=true; }
   if(quote && g_trail[lane].pullActive && gain>g_trail[lane].peak)
   { g_trail[lane].peak=gain; changed=true; }
   if(lane!=3 && g_trail[lane].candleActivation==0)
   {
      datetime activated=shift>=2?iTime(_Symbol,tf,shift-1):0;
      if(activated==0 && quote && distance>0 && gain>=0.5*distance) activated=currentBar;
      if(activated>0) { g_trail[lane].candleActivation=activated; changed=true; }
   }
   if(changed && !TRPersist()) return;
   bool active=(lane==3?g_crfTrailActivationBar>0:g_trail[lane].candleActivation>0) || g_trail[lane].pullActive!=0;
   g_trailNote[lane]=active?"Trailstop active":"Trailstop waiting";
   if(quote && g_trail[lane].pullActive && gain<=g_trail[lane].peak*(1.0-InpTrailPullbackPct/100.0) && profit>0)
   {
      if(lane==3)
      {
         CRFExposure ex;
         if(CRFScanExposure(_Symbol,P4Magic(1),P4Magic(3),P4Connected(),ex) &&
            ex.kind==CRF_EXPOSURE_CRF_OPEN && ex.position_id==v.position && CRFRequestPositionClose(2,ex,q,true))
            g_trailNote[lane]="Trailstop close requested";
      }
      else if(TRCloseNative(lane,ticket,q)) g_trailNote[lane]="Trailstop close requested";
      return;
   }
   if(lane==3 || g_trail[lane].candleActivation==0 || latest<=g_trailSessionBar[lane]) return;
   if(g_trail[lane].candleActivation<fillBar || iBarShift(_Symbol,tf,g_trail[lane].candleActivation,true)<0)
   { g_trailNote[lane]="Trailstop activation unavailable: REVIEW"; return; }
   MqlRates bars[];
   if(!ArraySetAsSeries(bars,false) || CopyRates(_Symbol,tf,1,3,bars)!=3 || ArraySize(bars)!=3 ||
      bars[0].time!=iTime(_Symbol,tf,3) || bars[1].time!=iTime(_Symbol,tf,2) || bars[2].time!=latest ||
      iTime(_Symbol,tf,1)!=latest || bars[0].time<=0 || bars[1].time<=bars[0].time || bars[2].time<=bars[1].time ||
      !P3Positive(bars[0].close) || !P3Positive(bars[1].open) || !P3Positive(bars[1].close) ||
      !P3Positive(bars[2].open) || !P3Positive(bars[2].close))
   { g_trailNote[lane]="Trailstop candle history unavailable"; return; }
   if(bars[0].time<g_trail[lane].candleActivation) { g_trailSessionBar[lane]=latest; return; }
   bool pattern=v.direction>0?(bars[1].open<=bars[0].close && bars[1].close<bars[1].open && bars[2].open<=bars[1].close && bars[2].close<bars[2].open):
                               (bars[1].open>=bars[0].close && bars[1].close>bars[1].open && bars[2].open>=bars[1].close && bars[2].close>bars[2].open);
   if(!pattern || profit<=0) { g_trailSessionBar[lane]=latest; return; }
   if(!quote || !InpAutoTrading) return;
   g_trailSessionBar[lane]=latest;
   if(TRCloseNative(lane,ticket,q)) g_trailNote[lane]="Trailstop close requested";
}
void TRProcess()
{
   if(!g_p4Ready) return;
   for(int lane=0;lane<4 && g_p4Ready;lane++) TRStep(lane);
}
#endif
