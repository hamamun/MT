#ifndef MT_CRF_PRESENTATION_MQH
#define MT_CRF_PRESENTATION_MQH

string CRFModeText()
{
   if(InpMode==MT_CRF_MODE_MT) return "MT only";
   if(InpMode==MT_CRF_MODE_CRF) return "CRF only";
   return "MT + CRF";
}
int CRFPriceDigits()
{
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return digits>=0 && digits<=10?digits:5;
}
string CRFPriceText(double value)
{
   return P3Positive(value)?DoubleToString(value,CRFPriceDigits()):"--";
}
string CRFPatternText(int variant)
{
   if(variant==11) return "Bullish engulfing";
   if(variant==12) return "Bearish engulfing";
   if(variant==21) return "Hammer";
   if(variant==22) return "Inverted hammer";
   if(variant==23) return "Hanging man";
   if(variant==24) return "Shooting star";
   if(variant==31) return "Morning star";
   if(variant==32) return "Evening star";
   if(variant==33) return "Morning doji star";
   if(variant==34) return "Evening doji star";
   return "--";
}
string CRFQualityText(int reason)
{
   if(reason==2) return "Low sample count";
   if(reason==3) return "Below follow-through filter";
   if(reason==4) return "Below reward/risk filter";
   if(reason==5) return "Meets selected filters";
   return "No historical estimate";
}
string CRFResultText(int result)
{
   if(result==1) return "TP estimate reached";
   if(result==2) return "Stop loss touched";
   if(result==3) return "Opposite confirmed reversal";
   if(result==4) return "Duration limit reached; no extension";
   if(result==5) return "Replaced by newer signal";
   if(result==6) return "No historical estimate";
   return "--";
}
string CRFEventText(int event)
{
   if(event==1) return "Candidate appeared";
   if(event==2) return "Forecast confirmed";
   if(event==3) return "Candidate expired; no confirmation";
   if(event==4) return "Forecast closed";
   if(event==5) return "Confirmed reversal; no estimate";
   if(event==6) return "Nearby pattern ignored";
   return "--";
}
string CRFSide(int dir) { return dir>0?"BUY":(dir<0?"SELL":"--"); }

bool CRFDisplayM15()
{
   if(InpMode==MT_CRF_MODE_MT) return false;
   if(InpMode==MT_CRF_MODE_CRF) return true;
   if(g_p4[3].active!=0 || g_crfTakeover!=0 || g_crfCloseKind!=0) return true;
   if(!g_crfObserverAvailable || !g_crfForecastCurrent) return false;
   return g_crfObserver.forecast.pending.direction!=0 || g_crfObserver.forecast.active_direction!=0;
}
string CRFReadingLine()
{
   string pt="--";
   if(g_crfObserverAvailable && g_crfForecastCurrent && g_crfObserver.forecast.active_direction!=0)
      pt="~"+IntegerToString(g_crfObserver.forecast.remaining)+"b";
   return "M15 | GT: -- | CT: -- | ST: -- | RG: -- | PT: "+pt+" | SC: --";
}
string CRFPlanLine()
{
   if(!g_crfObserverAvailable || !g_crfForecastCurrent) return "M15 | Signal: WAIT | CRF forecast unavailable";
   CRFForecastState f=g_crfObserver.forecast;
   if(f.active_direction==0)
   {
      if(f.pending.direction!=0)
         return "M15 | Signal: "+CRFSide(f.pending.direction)+"? (CRF) | "+CRFPatternText(f.pending.variant)+
                " | Candidate waiting for confirmation";
      return "M15 | Signal: NONE | CRF watching M15";
   }
   string s="M15 | Signal: "+CRFSide(f.active_direction)+" (CRF) | MARKET Entry: "+CRFPriceText(f.last_entry);
   MqlTick q; P3Plan plan; string lot="--";
   if(SymbolInfoTick(_Symbol,q) && CRFMakeRequestPlan(f,q,plan)) lot=P3LotText(plan.lot);
   s+=" | Lot: "+lot+" | SL: "+CRFPriceText(f.active_stop)+" | TP: "+CRFPriceText(f.active_target);
   s+=" | Pattern: "+CRFPatternText(f.last_signal.variant)+" | "+CRFQualityText(f.last_estimate.reason)+
      " | "+IntegerToString(f.last_estimate.samples)+" samples | Move "+DoubleToString(f.last_estimate.move_atr,2)+" ATR | Duration "+DoubleToString(f.last_estimate.duration,1)+" bars | Expires in "+IntegerToString(f.remaining)+" bars | Auto "+(InpAutoTrading && P4LaneEnabled(1)?"ON":"OFF");
   if(!P3HasBidBars()) s+=" | Bars: Last/unknown proxy";
   return s;
}
string CRFHeaderStatus()
{
   if(!g_crfObserverAvailable || !g_crfForecastCurrent) return g_crfStatus;
   CRFForecastState f=g_crfObserver.forecast;
   if(f.active_direction!=0)
   {
      string text=CRFSide(f.active_direction)+" confirmed / expires in "+IntegerToString(f.remaining)+" bars / Auto "+(InpAutoTrading && P4LaneEnabled(1)?"ON":"OFF");
      if(g_p4[3].order>0) text+=" / order #"+StringFormat("%I64u",g_p4[3].order);
      return text+" / "+g_crfStatus;
   }
   if(f.pending.direction!=0)
      return CRFSide(f.pending.direction)+" candidate / waiting confirmation ("+IntegerToString(2-f.pending_elapsed)+" bars left)";
   return g_crfStatus;
}
string CRFAutoLine()
{
   string head=(string)"M15 | Auto: "+(InpAutoTrading && P4LaneEnabled(1)?"ON":"OFF");
   if(!g_p4Ready) return head+" | coordinator unavailable";
   P4View v=g_p4View[3];
   if(v.state==P4_OPEN || v.state==P4_PARTIAL || v.state==P4_PENDING)
   {
      string line=P4Line(3), prefix="CRF | Auto: OFF";
      if(StringFind(line,prefix)==0) line=head+StringSubstr(line,StringLen(prefix));
      else line=head+" | CRF broker state: REVIEW";
      int shift=iBarShift(_Symbol,PERIOD_M15,g_crfOrderSignalBar,true);
      string expiry=shift>=1?IntegerToString((int)MathMax(0,g_crfOrderDuration-(shift-1)))+" bars":"--";
      return line+" | CRF strategy 30007 | order #"+StringFormat("%I64u",g_p4[3].order)+" | Expires in "+expiry+" | "+g_crfStatus;
   }
   return head+" | CRF | "+g_crfStatus;
}

void CRFDashboardRows(string &rows[])
{
   ArrayResize(rows,15);
   for(int i=0;i<15;i++) rows[i]="";
   if(!g_crfObserverAvailable)
   {
      rows[0]="CONFIRMED REVERSAL FORECAST | --";
      rows[1]=(string)"Status | "+g_crfStatus;
      for(int i=2;i<15;i++) rows[i]="--";
      return;
   }
   CRFForecastState f=g_crfObserver.forecast;
   bool active=f.active_direction!=0, pending=f.pending.direction!=0, hasLast=f.last_signal.direction!=0;
   string side=active?CRFSide(f.active_direction):(pending?CRFSide(f.pending.direction)+"?":(hasLast?CRFSide(f.last_signal.direction)+" (last)":"--"));
   rows[0]="CONFIRMED REVERSAL FORECAST | "+side;
   rows[1]=(string)"Status | "+(!g_crfForecastCurrent?"M15 history unavailable":(active?"Confirmed reversal active":"Waiting for new confirmed reversal"));
   rows[2]=(active?"Pattern | ":"Last pattern | ")+CRFPatternText(f.last_signal.variant);
   rows[3]="Pending candidate | "+(pending?CRFSide(f.pending.direction)+" "+CRFPatternText(f.pending.variant)+" ("+IntegerToString(2-f.pending_elapsed)+" bars left)":"--");
   rows[4]="Data through | "+(f.last_bar>0?TimeToString((datetime)f.last_bar,TIME_DATE|TIME_MINUTES):"--")+" | M15 bar count "+IntegerToString(Bars(_Symbol,PERIOD_M15));
   rows[5]=(active?"Entry / trigger | ":"Last entry | ")+(hasLast?CRFPriceText(f.last_entry):"--");
   rows[6]=(active?"Stop loss | ":"Last SL | ")+(hasLast?CRFPriceText(f.last_signal.stop):"--");
   rows[7]=(active?"TP estimate | ":"Last TP | ")+(f.last_estimate.available?CRFPriceText(f.last_estimate.target):"--");
   rows[8]=(active?"Expected move | ":"Last expected move | ")+(f.last_estimate.available?"+"+DoubleToString(f.last_estimate.move_atr,2)+" ATR":"--");
   rows[9]=(active?"Expected duration | ":"Last duration | ")+(f.last_estimate.available?DoubleToString(f.last_estimate.duration,1)+" bars ("+IntegerToString(f.last_estimate.duration_low)+"-"+IntegerToString(f.last_estimate.duration_high)+")":"--");
   rows[10]=(active?"Estimate quality | ":"Last estimate quality | ")+CRFQualityText(f.last_estimate.reason);
   rows[11]="Historical follow-through / samples | "+(hasLast?DoubleToString(f.last_estimate.confidence,0)+"% | "+IntegerToString(f.last_estimate.samples)+" samples":"--");
   rows[12]="Forecast expires in | "+(active?IntegerToString(f.remaining)+" bars":"--");
   rows[13]=(string)"No-signal reason | "+(!g_crfForecastCurrent?"M15 history unavailable":(pending?"Candidate awaiting confirmation":(active?"--":"Waiting for new confirmed reversal")));
   string update=f.last_event==4?CRFResultText(f.last_result):CRFEventText(f.last_event);
   int age=f.last_event_bar>0?iBarShift(_Symbol,PERIOD_M15,(datetime)f.last_event_bar,true):-1;
   if(age==1) update+=" | this bar"; else if(age>1) update+=" | "+IntegerToString(age-1)+" bars ago";
   rows[14]="Last result / update | "+update;
}

void CRFRemoveObjects() { ObjectsDeleteAll(0,"MTCRF_"); }
// Finite, per-signal segments never connect unrelated forecasts.
bool CRFSetLevel(const string name, const long signalBar, const datetime through,
                 const double price, const color ink)
{
   if(signalBar<=0 || through<=(datetime)signalBar || !CRFValidPrice(price)) return false;
   string id="MTCRF_"+name+"_"+StringFormat("%I64d",signalBar);
   if(ObjectFind(0,id)<0 && !ObjectCreate(0,id,OBJ_TREND,0,(datetime)signalBar,price,through,price)) return false;
   return ObjectMove(0,id,0,(datetime)signalBar,price) && ObjectMove(0,id,1,through,price) &&
          ObjectSetInteger(0,id,OBJPROP_RAY_RIGHT,false) && ObjectSetInteger(0,id,OBJPROP_COLOR,ink) &&
          ObjectSetInteger(0,id,OBJPROP_STYLE,STYLE_SOLID) && ObjectSetInteger(0,id,OBJPROP_WIDTH,1) &&
          ObjectSetInteger(0,id,OBJPROP_SELECTABLE,false) && ObjectSetInteger(0,id,OBJPROP_HIDDEN,true);
}
bool CRFSetMarker(const long bar, const bool candidate, const int direction, const double price)
{
   if(bar<=0 || (direction!=1 && direction!=-1) || !CRFValidPrice(price)) return false;
   string id="MTCRF_marker_"+StringFormat("%I64d",bar)+(candidate?"_candidate":"_confirmed");
   if(ObjectFind(0,id)<0 && !ObjectCreate(0,id,OBJ_ARROW,0,(datetime)bar,price)) return false;
   return ObjectMove(0,id,0,(datetime)bar,price) && ObjectSetInteger(0,id,OBJPROP_ARROWCODE,159) &&
          ObjectSetInteger(0,id,OBJPROP_COLOR,candidate?clrYellow:(direction>0?clrLimeGreen:clrRed)) &&
          ObjectSetInteger(0,id,OBJPROP_WIDTH,candidate?1:2) &&
          ObjectSetInteger(0,id,OBJPROP_SELECTABLE,false) && ObjectSetInteger(0,id,OBJPROP_HIDDEN,true);
}
#endif
