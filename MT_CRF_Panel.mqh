#ifndef MT_CRF_PANEL_MQH
#define MT_CRF_PANEL_MQH

// Presentation only. The trading/diary runtimes remain the source of data.
#define UI_PREFIX "MT_"
// Optional diary-details window. A distinct prefix keeps it a separate chart
// window: the main panel can be cleared without touching it and vice versa.
#define UI_DETAILS_PREFIX "MTD_"
#define UI_FONT "Consolas"
#define UI_SIZE 10
// Gutter between MARKET READINGS columns. Kept small so the eight columns
// (TF GT CT ST RG PT SC SG) stay compact in one aligned row.
#define UI_READ_PAD 10
// Extra gutter each column may take when the panel is wider than the row needs.
#define UI_READ_SPREAD 6
// Narrowest readings column block and auto-execution column in the two-column body.
#define UI_READ_MIN_W 380
#define UI_AUTO_MIN_W 300
// Vertical gap between the stacked TRADING PLANS rows.
#define UI_PLAN_GAP 4
#define UI_X 12
#define UI_Y 24
#define UI_BG C'17,24,39'
#define UI_SURFACE C'27,37,54'
#define UI_BORDER C'53,67,87'
#define UI_MUTED C'157,171,190'
#define UI_BADGE C'48,63,83'
#define UI_GREEN C'22,76,64'
#define UI_RED C'91,40,48'
#define UI_AMBER C'96,70,28'
#define UI_TITLE C'94,205,233'

// The numerical Phase 2 engine passes readings here; formatting stays in the panel.
string g_uiReadings[3]={"","",""};
string P2StateText(int state)
{
   if(state==1) return("UP");
   if(state==-1) return("DOWN");
   if(state==0) return("FLAT");
   if(state==2) return("CONFLICT");
   if(state==3) return("MIXED");
   return("WAIT");
}
string UIFormatCountdown(bool score, bool available, int left, int total)
{
   if(!available) return(score?"--%L":"--");
   if(score)
   {
      if(left<0) return("past est.");
      if(left==0) return("~0%L");
      int percent=(int)MathRound(100.0*left/total);
      if(percent==0) return("<1%L");
      return(IntegerToString(percent)+"%L");
   }
   if(left<0) return("0b+");
   return("~"+IntegerToString(left)+"b");
}
void UIClearReading(int lane) { g_uiReadings[lane]=""; }
void UISetReadings(int lane, int gt, int ct, int st, const string rg,
                   const string prediction, int score, const string scoreLife)
{
   string tf=lane==0?"M5":(lane==1?"M15":"M30"), scoreText="WAIT";
   if(score!=P2_WAIT) scoreText=(score>0?"+":"")+IntegerToString(score)+"/3 ("+scoreLife+")";
   g_uiReadings[lane]=tf+" | GT: "+P2StateText(gt)+" | CT: "+P2StateText(ct)+
                      " | ST: "+P2StateText(st)+" | RG: "+rg+" | PT: "+prediction+" | SC: "+scoreText;
}
string P2Line(int lane)
{
   if(g_uiReadings[lane]!="") return(g_uiReadings[lane]);
   string tf=lane==0?"M5":(lane==1?"M15":"M30");
   return(tf+" | GT: WAIT | CT: WAIT | ST: WAIT | RG: WAIT | PT: -- | SC: WAIT");
}

bool g_uiBuilt=false, g_uiSupported=false, g_uiClosed=false;
int g_uiAutoParts[3]={0,0,0}, g_uiPlanNotes[3]={0,0,0}, g_uiPlanDistances[3]={0,0,0};
int g_uiReadingNotes[3]={0,0,0}, g_uiDiaryNotes[3]={0,0,0};
bool g_uiDetailsShown=false; int g_uiDetailsW=0, g_uiDetailsPage=0, g_uiDetailsPages=1, g_uiDetailsLines=0;
// Lane diary detail handed from the runtime to the separate window.
string g_uiDetailText[3]={"","",""}, g_uiDetailTF[3]={"M5","M15","M30"};
bool g_uiDetailOK[3]={false,false,false};
string g_uiDetailExtra[3][8];
int g_uiCashRows[3][2]={{0,0},{0,0},{0,0}}, g_uiPlanValues[3][4];
int g_uiMarketNotes=0, g_uiTimerNotes=0;

void UIResetCounts()
{
   for(int i=0;i<3;i++) { g_uiAutoParts[i]=0; g_uiPlanNotes[i]=0; g_uiPlanDistances[i]=0; g_uiReadingNotes[i]=0; g_uiDiaryNotes[i]=0; g_uiCashRows[i][0]=0; g_uiCashRows[i][1]=0; for(int c=0;c<4;c++) g_uiPlanValues[i][c]=0; }
   g_uiMarketNotes=0; g_uiTimerNotes=0;
   // The diary window is a separate window: a panel reset (market close,
   // supported/unsupported change) does not clear its content or its place.
}
// MT5 draws trade-history markers and trade levels above foreground labels.
// With the user's permission hide them across this chart while the panel is
// active; restore only settings we changed and only if still in that state.
bool g_uiTradesManaged=false, g_uiRestoreHistory=false, g_uiRestoreLevels=false;
void UIHideChartTrades()
{
   if(g_uiTradesManaged) return;
   g_uiTradesManaged=true; long prior=0;
   if(!ChartGetInteger(0,CHART_SHOW_TRADE_HISTORY,0,prior))
      Print("MT panel: cannot read chart trade-history visibility");
   else if(prior!=0)
   {
      g_uiRestoreHistory=ChartSetInteger(0,CHART_SHOW_TRADE_HISTORY,false);
      if(!g_uiRestoreHistory) Print("MT panel: cannot hide chart trade history");
   }
   if(!ChartGetInteger(0,CHART_SHOW_TRADE_LEVELS,0,prior))
      Print("MT panel: cannot read chart trade-level visibility");
   else if(prior!=0)
   {
      g_uiRestoreLevels=ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,false);
      if(!g_uiRestoreLevels) Print("MT panel: cannot hide chart trade levels");
   }
}
void UIRestoreChartTrades()
{
   long current=0;
   if(g_uiRestoreHistory && ChartGetInteger(0,CHART_SHOW_TRADE_HISTORY,0,current) && current==0)
      if(!ChartSetInteger(0,CHART_SHOW_TRADE_HISTORY,true)) Print("MT panel: cannot restore chart trade history");
   if(g_uiRestoreLevels && ChartGetInteger(0,CHART_SHOW_TRADE_LEVELS,0,current) && current==0)
      if(!ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,true)) Print("MT panel: cannot restore chart trade levels");
   g_uiRestoreHistory=false; g_uiRestoreLevels=false; g_uiTradesManaged=false;
}
void PanelRemove()
{
   UIRestoreChartTrades();
   // MT_ is the established panel prefix, including objects from older layouts.
   ObjectsDeleteAll(0,UI_PREFIX); ObjectsDeleteAll(0,UI_DETAILS_PREFIX);
   g_uiBuilt=false; g_uiSupported=false; g_uiClosed=false; UIResetCounts();
   ChartRedraw();
}
void UIMeasure(const string text, int size, int &width, int &height)
{
   uint w=0,h=0;
   if(TextSetFont(UI_FONT,-10*size,0) && TextGetSize(text,w,h) && h>0)
   { width=(int)w; height=(int)h; return; }
   int dpi=(int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi<72) dpi=96;
   height=(int)MathCeil(size*(double)dpi/72.0*1.5);
   width=StringLen(text)*height;
}
// Each individual chart label stays below MT5's observed text limit.
void UIText(const string name, int x, int y, const string text, color ink, int size, const string tip="", const string prefix=UI_PREFIX)
{
   int segment=0;
   for(int offset=0;offset<StringLen(text);offset+=48)
   {
      string part=StringSubstr(text,offset,48), obj=prefix+name+"_"+IntegerToString(segment);
      if(ObjectFind(0,obj)<0) ObjectCreate(0,obj,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,obj,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,obj,OBJPROP_COLOR,ink); ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,size);
      ObjectSetString(0,obj,OBJPROP_FONT,UI_FONT); ObjectSetString(0,obj,OBJPROP_TEXT,part);
      ObjectSetString(0,obj,OBJPROP_TOOLTIP,tip);
      ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,obj,OBJPROP_BACK,false); ObjectSetInteger(0,obj,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      int w,h; UIMeasure(part,size,w,h); x+=w; segment++;
   }
   while(ObjectFind(0,prefix+name+"_"+IntegerToString(segment))>=0)
   { ObjectDelete(0,prefix+name+"_"+IntegerToString(segment)); segment++; }
}
void UIBox(const string name, int x, int y, int w, int h, color fill, color border, const string prefix=UI_PREFIX)
{
   string obj=prefix+name;
   if(ObjectFind(0,obj)<0) ObjectCreate(0,obj,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,obj,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,obj,OBJPROP_XSIZE,(int)MathMax(1,w)); ObjectSetInteger(0,obj,OBJPROP_YSIZE,(int)MathMax(1,h));
   ObjectSetInteger(0,obj,OBJPROP_BGCOLOR,fill); ObjectSetInteger(0,obj,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,obj,OBJPROP_COLOR,border); ObjectSetInteger(0,obj,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,obj,OBJPROP_BACK,false); ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);
}
int UIWidth(const string text, int size=UI_SIZE)
{
   int width=0;
   for(int offset=0;offset<StringLen(text);offset+=48)
   { int w,h; UIMeasure(StringSubstr(text,offset,48),size,w,h); width+=w; }
   return(width);
}
void UIGrowStep(const string text, int size, int &step)
{
   for(int offset=0;offset<StringLen(text);offset+=48)
   {
      int w,h; UIMeasure(StringSubstr(text,offset,48),size,w,h);
      step=(int)MathMax(step,h+6);
   }
}
string UIPart(const string line, int index)
{
   int start=0;
   for(int i=0;i<index;i++)
   {
      int p=StringFind(line," | ",start);
      if(p<0) return("");
      start=p+3;
   }
   int end=StringFind(line," | ",start);
   return(end<0?StringSubstr(line,start):StringSubstr(line,start,end-start));
}
int UIPartCount(const string line)
{
   if(line=="") return(0);
   int n=1,start=0;
   while(true)
   {
      int p=StringFind(line," | ",start);
      if(p<0) break;
      start=p+3; n++;
   }
   return(n);
}
string UIAfter(const string text, const string prefix)
{
   return(StringFind(text,prefix)==0?StringSubstr(text,StringLen(prefix)):"");
}
string UIWord(const string text, int index)
{
   int start=0;
   for(int i=0;i<index;i++)
   {
      int p=StringFind(text," ",start); if(p<0) return(""); start=p+1;
   }
   int end=StringFind(text," ",start);
   return(end<0?StringSubstr(text,start):StringSubstr(text,start,end-start));
}
string UIOnOff(bool value) { return(value?"ON":"OFF"); }
string UITrend(P3_TREND_CHOICE value)
{
   if(value==P3_AUTO) return("AUTO");
   if(value==P3_FOLLOW_CT) return("CT");
   if(value==P3_FOLLOW_GT) return("GT");
   if(value==P3_FOLLOW_ST) return("ST");
   return("--");
}
string UITP(int lane)
{
   int v=P3TPPercentInput(lane);
   return(v>=1 && v<=100?IntegerToString(v)+"%":"INVALID");
}
color UIChipFill(const string value)
{
   if(value=="ON" || value=="UP" || value=="BUY" || value=="OPEN" ||
      (StringLen(value)>=3 && StringSubstr(value,StringLen(value)-3)==" ON")) return(UI_GREEN);
   if(value=="DOWN" || value=="SELL") return(UI_RED);
   if(value=="WAIT" || value=="CONFLICT" || value=="INVALID" || value=="PAUSED") return(UI_AMBER);
   return(UI_BADGE);
}
color UIValueColor(const string value)
{
   if(value=="UP" || value=="BUY" || (StringFind(value,"/3")>=0 && StringSubstr(value,0,1)=="+")) return(clrLime);
   if(value=="DOWN" || value=="SELL" || (StringFind(value,"/3")>=0 && StringSubstr(value,0,1)=="-")) return(clrTomato);
   if(StringFind(value,"P/L +")==0) return(clrLime);
   if(StringFind(value,"P/L -")==0 && StringFind(value,"P/L --")!=0) return(clrTomato);
   if(StringFind(value,"SL --")==0 || StringFind(value,"Pending SL --")==0) return(clrOrange);
   if(value=="WAIT" || value=="CONFLICT" || StringFind(value,"NO SL")>=0 ||
      StringFind(value,"REVIEW")>=0 || StringFind(value,"unavailable")>=0 || StringFind(value,"PAUSED")>=0) return(clrOrange);
   return(clrSilver);
}
// Maximal pixel-fitting fragment; prefer a word boundary, but never drop text.
int UIFit(const string text, int start, int width, int size=UI_SIZE)
{
   int left=StringLen(text)-start, lo=1, hi=(int)MathMin(512,left), fit=0;
   // Font measurements are expensive on MT5 ticks; use a bounded search.
   while(lo<=hi)
   {
      int mid=(lo+hi)/2;
      if(UIWidth(StringSubstr(text,start,mid),size)<=width) { fit=mid; lo=mid+1; }
      else hi=mid-1;
   }
   if(fit<1) return(1);
   if(fit<left)
      for(int i=fit-1;i>=0;i--) if(StringSubstr(text,start+i,1)==" ") return(i+1);
   return(fit);
}
int UIWrappedRows(const string text, int width, int size=UI_SIZE)
{
   int n=0;
   for(int pos=0;pos<StringLen(text);) { pos+=UIFit(text,pos,width,size); n++; }
   return(n);
}
void UIWrapped(const string name, int x, int y, const string text, int width, int step, color ink, const string tip, int &previous, int size=UI_SIZE, const string prefix=UI_PREFIX)
{
   int row=0;
   for(int pos=0;pos<StringLen(text);)
   {
      int n=UIFit(text,pos,width,size);
      UIText(name+IntegerToString(row),x,y+row*step,StringSubstr(text,pos,n),ink,size,tip,prefix);
      pos+=n; row++;
   }
   for(int i=row;i<previous;i++) UIText(name+IntegerToString(i),x,y,"",ink,size,"",prefix);
   previous=row;
}

struct UIPlan
{
   bool recognized;
   string tf,signal,style,volume,entry,lot,sl,slCash,tp,tpCash,notes;
};
void UIAppend(string &out, const string part)
{
   if(out!="") out+=" | ";
   out+=part;
}
void UILevel(const string text, string &level, string &cash)
{
   int p=StringFind(text," (");
   if(p<0) { level=text; cash=""; }
   else { level=StringSubstr(text,0,p); cash=StringSubstr(text,p+1); }
}
void UIReadPlan(const string line, const string tf, UIPlan &p)
{
   p.tf=tf; p.signal=""; p.style=""; p.volume=""; p.entry=""; p.lot="";
   p.sl=""; p.slCash=""; p.tp=""; p.tpCash=""; p.notes="";
   p.recognized=(UIPart(line,0)==tf && StringFind(UIPart(line,1),"Signal: ")==0);
   if(!p.recognized) { p.notes=line; return; }
   p.signal=UIAfter(UIPart(line,1),"Signal: ");
   for(int i=2;i<UIPartCount(line);i++)
   {
      string t=UIPart(line,i);
      if(StringFind(t,"Volume: ")==0 && p.volume=="") p.volume=UIAfter(t,"Volume: ");
      else if(StringFind(t,"MARKET Entry: ")==0 && p.entry=="") { p.style="MARKET"; p.entry=UIAfter(t,"MARKET Entry: "); }
      else if(StringFind(t,"LIMIT Entry: ")==0 && p.entry=="") { p.style="LIMIT"; p.entry=UIAfter(t,"LIMIT Entry: "); }
      else if(StringFind(t,"Entry: ")==0 && p.entry=="") p.entry=UIAfter(t,"Entry: ");
      else if(StringFind(t,"Lot: ")==0 && p.lot=="") p.lot=UIAfter(t,"Lot: ");
      else if(StringFind(t,"SL: ")==0 && p.sl=="") UILevel(UIAfter(t,"SL: "),p.sl,p.slCash);
      else if(StringFind(t,"TP: ")==0 && p.tp=="") UILevel(UIAfter(t,"TP: "),p.tp,p.tpCash);
      else UIAppend(p.notes,t);
   }
}
bool UIReadingField(const string line, const string key, string &value)
{
   string marker=" | "+key+": "; int p=StringFind(line,marker);
   value=""; if(p<0) return(false); p+=StringLen(marker);
   int end=StringFind(line," | ",p);
   value=end<0?StringSubstr(line,p):StringSubstr(line,p,end-p);
   return(value!="");
}
bool UIReadingsValid(const string line, const string tf)
{
   string a,b,c,d,e,f;
   if(!UIReadingField(line,"GT",a) || !UIReadingField(line,"CT",b) || !UIReadingField(line,"ST",c) ||
      !UIReadingField(line,"RG",d) || !UIReadingField(line,"PT",e) || !UIReadingField(line,"SC",f)) return(false);
   return(line==tf+" | GT: "+a+" | CT: "+b+" | ST: "+c+" | RG: "+d+" | PT: "+e+" | SC: "+f);
}
// SG - the lane's own signal, taken from its plan line so the readings table
// shows exactly what TRADING PLANS shows. BUY/SELL/NONE/WAIT are passed through;
// a plan line that cannot be read gives "--", never an invented direction.
string UISignal(const string planLine, const string tf)
{
   UIPlan p; UIReadPlan(planLine,tf,p);
   if(!p.recognized) return("--");
   if(StringFind(p.signal," (CRF)")>0) return(p.signal);
   if(p.signal=="BUY" || p.signal=="SELL" || p.signal=="NONE" || p.signal=="WAIT") return(p.signal);
   return(p.signal==""?"--":p.signal);
}
// One cell of the MARKET READINGS row. SG is the lane's plan signal; the other
// columns come from the lane's own reading line and stay empty when it cannot
// be read (the full text is shown underneath instead).
string UISignalCell(const string readingLine, const string planLine,
                    const string tf, const string col, int column, bool readingOK)
{
   if(column==0) return(tf);
   if(column==7) return(UISignal(planLine,tf));
   string value="";
   if(!readingOK) return("");
   UIReadingField(readingLine,col,value);
   return(value);
}

color UISignalColor(const string value)
{
   if(value=="BUY") return(clrLime);
   if(value=="SELL") return(clrTomato);
   if(value=="WAIT" || value=="--") return(clrOrange);
   return(clrSilver);
}

bool UIStats(const string line, const string tf, string &today, string &all)
{
   string prefix=tf+" | Trades Today ", marker=" | All ";
   today=""; all="";
   if(StringFind(line,prefix)!=0) return(false);
   int end=StringFind(line,marker,StringLen(prefix)); if(end<0) return(false);
   today=StringSubstr(line,StringLen(prefix),end-StringLen(prefix)); all=StringSubstr(line,end+StringLen(marker));
   string ts=UIWord(today,1),tw=UIWord(today,3),tl=UIWord(today,5),tb=UIWord(today,7);
   string as=UIWord(all,1),aw=UIWord(all,3),al=UIWord(all,5),ab=UIWord(all,7);
   return(ts!="" && tw!="" && tl!="" && tb!="" && as!="" && aw!="" && al!="" && ab!="" &&
          today=="S "+ts+" W "+tw+" L "+tl+" BE "+tb && all=="S "+as+" W "+aw+" L "+al+" BE "+ab);
}
// Keep break-even in the diary; the compact header shows only S/W/L.
string UIHeaderStats(const string today, const string all)
{
   return("T S "+UIWord(today,1)+" W "+UIWord(today,3)+" L "+UIWord(today,5)+
          "   |   A S "+UIWord(all,1)+" W "+UIWord(all,3)+" L "+UIWord(all,5));
}
bool UIAutoTrade(const string line, string &direction, string &style)
{
   int index=UIPart(line,2)=="TIMER PAUSED"?3:2;
   string token=UIPart(line,index);
   direction=UIWord(token,0); style=UIWord(token,1);
   return((direction=="BUY" || direction=="SELL") && (style=="OPEN" || style=="LIMIT") && token==direction+" "+style);
}
// Price distance, not points/pips or a profit estimate. Negative means the
// current exit-side quote has already passed the target; unavailable/stale
// quotes and missing targets are deliberately shown as --.
string UITPDistance(const string direction, const string targetText, bool fresh, const MqlTick &quote, int digits)
{
   if(!fresh || (direction!="BUY" && direction!="SELL") || targetText=="") return("--");
   bool digit=false,dot=false;
   for(int i=0;i<StringLen(targetText);i++)
   {
      int ch=StringGetCharacter(targetText,i);
      if(ch>=48 && ch<=57) { digit=true; continue; }
      if(ch==46 && !dot) { dot=true; continue; }
      return("--");
   }
   if(!digit) return("--");
   double target=StringToDouble(targetText);
   if(!MathIsValidNumber(target) || target<=0.0) return("--");
   double distance=direction=="BUY"?target-quote.bid:quote.ask-target;
   return(DoubleToString(distance,digits));
}
string UIAutoTarget(const string line)
{
   for(int i=0;i<UIPartCount(line);i++)
   {
      string part=UIPart(line,i);
      if(StringFind(part,"TP ")==0) return(UIWord(UIAfter(part,"TP "),0));
   }
   return("");
}

// Keep the broker entry and lot beside the trade badges whenever the row
// can fit them. Very long broker fields can still wrap without losing text.
int UIAutoFirstWidth(const string line, int lead)
{
   string direction="",style="";
   if(!UIAutoTrade(line,direction,style)) return(0);
   int width=lead+UIWidth(direction)+UIWidth(style)+24+8;
   for(int i=2;i<UIPartCount(line);i++)
   {
      string part=UIPart(line,i);
      if(StringFind(part,"Entry ")==0 || StringFind(part,"Lot ")==0)
         width+=UIWidth(StringSubstr(part,0,48))+10;
   }
   return(width);
}

// Place broker tokens across a row, wrapping as needed without abbreviating notes.
int UIAutoFlow(const string line, int lane, int x, int y, int width, int lead, int step, bool draw, const string tip, const string quote)
{
   string tf=UIPart(line,0),mode=UIPart(line,1);
   bool normal=(tf==(lane==0?"M5":(lane==1?"M15":"M30")) && (mode=="Auto: ON" || mode=="Auto: OFF"));
   string direction="",style="";
   bool trade=normal && UIAutoTrade(line,direction,style);
   int extra=trade?UIWidth(direction)+UIWidth(style)+24:0;
   int count=normal?UIPartCount(line):1, first=normal?2:0, row=0, cursor=normal?lead+extra:8, part=0;
   int tradeIndex=UIPart(line,2)=="TIMER PAUSED"?3:2;
   for(int pass=0;pass<(trade?2:1);pass++) for(int t=first;t<count;t++)
   {
      if(trade && t==tradeIndex) continue;
      string item=normal?UIPart(line,t):line;
      if(item=="") continue;
      bool core=StringFind(item,"Entry ")==0 || StringFind(item,"Lot ")==0;
      if(trade && ((pass==0 && !core) || (pass==1 && core))) continue;
      if(trade && StringFind(item,"TP distance (price): ")==0 && quote!="")
      {
         if(cursor>8) row++;
         if(draw)
         {
            UIText("autoText"+IntegerToString(lane)+"_"+IntegerToString(part),x+8,y+row*step,item,clrSilver,UI_SIZE,tip);
            UIText("autoQuote"+IntegerToString(lane),x+width-8-UIWidth(quote),y+row*step,quote,clrWhite,UI_SIZE,
                   tip+"\nCurrent entry-side quote: Ask for BUY, Bid for SELL. TP distance uses BUY Bid or SELL Ask.");
         }
         part++; cursor=width; continue;
      }
      for(int pos=0;pos<StringLen(item);)
      {
         int available=width-cursor-8;
         int probe=(int)MathMin(48,StringLen(item)-pos);
         // Start a fresh row before splitting a field; then split long notes only if needed.
         if(cursor>8 && UIWidth(StringSubstr(item,pos,probe))>available)
         { row++; cursor=8; continue; }
         int n=UIFit(item,pos,(int)MathMax(1,available));
         string frag=StringSubstr(item,pos,n);
         if(draw) UIText("autoText"+IntegerToString(lane)+"_"+IntegerToString(part),x+cursor,y+row*step,frag,UIValueColor(item),UI_SIZE,tip);
         part++; pos+=n; cursor+=UIWidth(frag)+10;
         if(pos<StringLen(item)) { row++; cursor=8; }
      }
   }
   if(draw)
   {
      for(int k=part;k<g_uiAutoParts[lane];k++) UIText("autoText"+IntegerToString(lane)+"_"+IntegerToString(k),x,y,"",clrSilver,UI_SIZE);
      g_uiAutoParts[lane]=part;
      if(!trade || quote=="") UIText("autoQuote"+IntegerToString(lane),x,y,"",clrWhite,UI_SIZE);
   }
   return(row+1);
}

//+------------------------------------------------------------------+
//  OPTIONAL DIARY-DETAILS WINDOW
//
//  "Show diary details" opens a second chart window instead of adding
//  rows to TRADE STATISTICS. It sits to the right of the main panel,
//  uses the same slate style and the same helpers, but its own object
//  prefix, so either window can be redrawn or removed on its own.
//
//  State, latest record, warnings and analysis are wrapped to the chart.
//  A height-limited viewport uses previous/next buttons when needed; no
//  information is dropped. If the side column cannot be made readable, the
//  viewport overlays the chart until the details input is switched off.
//------------------------------------------------------------------+
#define DETAILS_TITLE "DIARY DETAILS"
#define DETAILS_MIN_W 200   // comfortable single-line width for the window
#define DETAILS_PANEL_FLOOR 560 // narrowest the main panel is packed to
#define DETAILS_PAD 10

int g_uiCrfNotes=0;

struct UIDetail
{
   string tf,state,last,net,warning;
   bool ok;
};

// Read one P5Detail line. The four count fields are kept exactly as the diary
// reported them (values are never recomputed or invented), together with the
// latest record, its net and any warning. Anything unrecognised is preserved
// verbatim instead of being dropped.
void UIReadDetail(const string line, const string tf, UIDetail &d)
{
   d.tf=tf; d.state=""; d.last=""; d.net=""; d.warning=""; d.ok=false;
   if(line=="") return;
   if(UIPart(line,0)!=tf) { d.warning=line; return; }
   string counts[4]; int seen=0;
   string labels[4]={"Pending ","Open ","Review ","Unfilled "};
   for(int i=1;i<UIPartCount(line);i++)
   {
      string t=UIPart(line,i); int hit=-1;
      for(int k=0;k<4;k++) if(StringFind(t,labels[k])==0 && UIWord(UIAfter(t,labels[k]),0)!="") hit=k;
      if(hit>=0 && seen<4) { counts[seen++]=t; continue; }
      if(StringFind(t,"Last: ")==0) d.last=UIAfter(t,"Last: ");
      else if(StringFind(t,"Net: ")==0) d.net=UIAfter(t,"Net: ");
      else if(StringFind(t,"No recorded trades")==0) d.last=t;
      else if(t=="CSV unavailable") d.warning=(d.warning==""?"CSV export unavailable":d.warning+" | CSV export unavailable");
      else d.warning=(d.warning==""?t:d.warning+" | "+t);
   }
   if(seen<4) { d.state=""; d.last=""; d.net=""; d.warning=line; return; }
   for(int k=0;k<4;k++) d.state+=(k>0?" | ":"")+counts[k];
   d.ok=true;
}

void DetailsRemove()
{
   ObjectsDeleteAll(0,UI_DETAILS_PREFIX);
   g_uiDetailsShown=false; g_uiDetailsW=0; g_uiDetailsPage=0; g_uiDetailsPages=1; g_uiDetailsLines=0;
}

// Chart buttons only change the diary viewport; they do not affect trading.
bool UIHandleDetailsClick(const string name)
{
   if(!g_uiDetailsShown || !(InpShowDetails || InpMode==MT_CRF_MODE_CRF)) return(false);
   if(name==(string)UI_DETAILS_PREFIX+"prev") g_uiDetailsPage=(int)MathMax(0,g_uiDetailsPage-1);
   else if(name==(string)UI_DETAILS_PREFIX+"next") g_uiDetailsPage=(int)MathMin(g_uiDetailsPages-1,g_uiDetailsPage+1);
   else return(false);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   return(true);
}

// Width the window needs for its longest single field, before any wrapping.
int UIDetailsNaturalWidth()
{
   int natural=DETAILS_MIN_W;
   for(int i=0;i<3;i++)
   {
      UIDetail d;
      UIReadDetail(g_uiDetailText[i],g_uiDetailTF[i],d);
      for(int j=0;j<8;j++) natural=(int)MathMax(natural,2*DETAILS_PAD+UIWidth(g_uiDetailExtra[i][j])+2);
      natural=(int)MathMax(natural,DETAILS_PAD+UIWidth(d.state)+DETAILS_PAD+2);
      natural=(int)MathMax(natural,DETAILS_PAD+UIWidth("Last ")+8+UIWidth(d.last)+DETAILS_PAD+2);
      natural=(int)MathMax(natural,DETAILS_PAD+UIWidth("Net ")+8+UIWidth(d.net)+DETAILS_PAD+2);
      natural=(int)MathMax(natural,DETAILS_PAD+UIWidth(d.warning)+DETAILS_PAD+2);
   }
   return(natural);
}

// Emit only whole visible text rows, preserving every character across pages.
void UIDetailEmit(const string text, color ink, const string tip, int width, int rowH,
                  int x, int y, int first, int capacity, bool draw, int &row, int &visible)
{
   for(int pos=0;pos<StringLen(text);)
   {
      int count=UIFit(text,pos,width);
      if(draw && row>=first && row<first+capacity)
      {
         UIText("line"+IntegerToString(visible),x,y+visible*rowH,StringSubstr(text,pos,count),ink,UI_SIZE,tip,UI_DETAILS_PREFIX);
         visible++;
      }
      pos+=count; row++;
   }
}
int UIDetailCompose(UIDetail &d[], int inner, int rowH, int x, int y, int first, int capacity, bool draw, int &visible)
{
   int row=0; visible=0;
   string tip="Broker diary: only fully reconciled trades are results. Win rate includes break-even in the denominator; costs are linked deal commission, swap and fee. Final exits use the last deal reason.";
   for(int i=0;i<3;i++)
   {
      string title=d[i].tf;
      if(d[i].state!="") title+=" | "+d[i].state;
      if(d[i].last!="") title+=" | Last "+d[i].last;
      if(d[i].net!="") title+=" | Net "+d[i].net;
      UIDetailEmit(title,UI_TITLE,tip,inner,rowH,x,y,first,capacity,draw,row,visible);
      if(d[i].warning!="") UIDetailEmit(d[i].tf+"  "+d[i].warning,clrOrange,"Diary warning: no information has been assumed.",inner,rowH,x,y,first,capacity,draw,row,visible);
      for(int j=0;j<8;j++)
         if(g_uiDetailExtra[i][j]!="") UIDetailEmit(d[i].tf+"  "+g_uiDetailExtra[i][j],j==0 && !g_uiDetailOK[i]?clrOrange:clrSilver,
                                                       tip,inner,rowH,x,y,first,capacity,draw,row,visible);
   }
   if(InpMode!=MT_CRF_MODE_MT)
   {
      string crf[]; CRFDashboardRows(crf);
      for(int i=0;i<ArraySize(crf);i++)
         UIDetailEmit(crf[i],i==0?UI_TITLE:clrSilver,"Closed M15 forecast; historical estimates are not broker execution results.",inner,rowH,x,y,first,capacity,draw,row,visible);
   }
   return(row);
}
void UIDetailsButton(const string name, int x, int y, int w, int h, const string text, const string tip)
{
   string obj=(string)UI_DETAILS_PREFIX+name;
   if(ObjectFind(0,obj)<0) ObjectCreate(0,obj,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,obj,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,obj,OBJPROP_XSIZE,w); ObjectSetInteger(0,obj,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,obj,OBJPROP_COLOR,clrWhite); ObjectSetInteger(0,obj,OBJPROP_BGCOLOR,UI_BADGE);
   ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,UI_SIZE); ObjectSetString(0,obj,OBJPROP_FONT,UI_FONT);
   ObjectSetString(0,obj,OBJPROP_TEXT,text); ObjectSetString(0,obj,OBJPROP_TOOLTIP,tip);
   ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);
}
void UpdateDetailsWindow(int panelX, int panelW, int gap, int step, int top)
{
   if(!(InpShowDetails || InpMode==MT_CRF_MODE_CRF) || !g_uiSupported)
   {
      if(g_uiDetailsShown) DetailsRemove();
      return;
   }
   if(step<=0) return;
   int probe=0,rowPix=0; UIMeasure("Mg",UI_SIZE,probe,rowPix);
   int rowH=rowPix+4;
   int chartW=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int chartH=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   int x=panelX+panelW+gap, natural=UIDetailsNaturalWidth();
   int room=chartW-x-UI_X;
   // If there is no readable side column, overlay the chart instead of
   // drawing the diary outside it. Hiding the input restores the main panel.
   if(chartW>0 && room<DETAILS_MIN_W) { x=UI_X; room=chartW-2*UI_X; }
   int width=chartW>0?(int)MathMax(1,MathMin(natural,room)):natural;
   int inner=(int)MathMax(1,width-2*DETAILS_PAD);
   if(chartH>0 && chartH-top<3*rowH+2*DETAILS_PAD) top=UI_Y;
   int available=chartH>0?(int)MathMax(1,chartH-top-UI_X):1000000;
   UIDetail d[3];
   for(int i=0;i<3;i++)
   {
      UIReadDetail(g_uiDetailText[i],g_uiDetailTF[i],d[i]);
      if(g_uiDetailText[i]=="") d[i].warning="Trade diary unavailable";
   }
   int visible=0,total=UIDetailCompose(d,inner,rowH,0,0,0,0,false,visible);
   int headerH=rowH+6, contentRoom=available-headerH-2*DETAILS_PAD;
   bool paged=total*rowH>contentRoom;
   if(paged) contentRoom-=rowH+4;
   int capacity=(int)MathMax(1,contentRoom/rowH);
   g_uiDetailsPages=(int)MathMax(1,(total+capacity-1)/capacity);
   g_uiDetailsPage=(int)MathMin(g_uiDetailsPage,g_uiDetailsPages-1);
   int first=g_uiDetailsPage*capacity;
   int displayed=(int)MathMin(capacity,total-first);
   int height=headerH+(paged?rowH+4:0)+displayed*rowH+2*DETAILS_PAD;
   g_uiDetailsW=width;
   UIBox("bg",x,top,width,height,UI_BG,UI_BORDER,UI_DETAILS_PREFIX);
   UIBox("title",x+1,top+1,width-2,rowH+4,UI_SURFACE,UI_BORDER,UI_DETAILS_PREFIX);
   UIText("titleText",x+DETAILS_PAD,top+4,DETAILS_TITLE,UI_TITLE,UI_SIZE,"Broker diary details.",UI_DETAILS_PREFIX);
   UIText("symbol",x+width-DETAILS_PAD-UIWidth(g_symbol),top+4,g_symbol,clrSilver,UI_SIZE,"",UI_DETAILS_PREFIX);
   int contentY=top+headerH+DETAILS_PAD;
   if(paged)
   {
      UIDetailsButton("prev",x+DETAILS_PAD,contentY,28,rowH,"<","Previous diary page");
      UIDetailsButton("next",x+DETAILS_PAD+34,contentY,28,rowH,">","Next diary page");
      UIText("page",x+DETAILS_PAD+72,contentY,"Page "+IntegerToString(g_uiDetailsPage+1)+" / "+IntegerToString(g_uiDetailsPages),clrSilver,UI_SIZE,
             "Use the arrows to see every diary row.",UI_DETAILS_PREFIX);
      contentY+=rowH+4;
   }
   else
   {
      ObjectDelete(0,(string)UI_DETAILS_PREFIX+"prev"); ObjectDelete(0,(string)UI_DETAILS_PREFIX+"next");
      UIText("page",0,0,"",clrSilver,UI_SIZE,"",UI_DETAILS_PREFIX);
   }
   UIDetailCompose(d,inner,rowH,x+DETAILS_PAD,contentY,first,capacity,true,visible);
   for(int i=visible;i<g_uiDetailsLines;i++) UIText("line"+IntegerToString(i),0,0,"",clrSilver,UI_SIZE,"",UI_DETAILS_PREFIX);
   g_uiDetailsLines=visible; g_uiDetailsShown=true;
}

// Refresh independently of market status: broker reconciliation can still
// change the diary while the main display is collapsed.
void UIRefreshDetails(datetime now)
{
   string tf[3]={"M5","M15","M30"};
   for(int i=0;i<3;i++)
   {
      string today="",all="",summary=P5Summary(i,now);
      g_uiDetailTF[i]=tf[i]; g_uiDetailOK[i]=UIStats(summary,tf[i],today,all);
      g_uiDetailText[i]=P5Detail(i);
      g_uiDetailExtra[i][0]=g_uiDetailOK[i]?"Today "+today+" | All "+all:summary;
      P5Insights insights; P5BuildInsights(i,insights);
      g_uiDetailExtra[i][1]=insights.totals; g_uiDetailExtra[i][2]=insights.score;
      g_uiDetailExtra[i][3]=insights.direction; g_uiDetailExtra[i][4]=insights.style;
      g_uiDetailExtra[i][5]=insights.recent; g_uiDetailExtra[i][6]=insights.exits;
      g_uiDetailExtra[i][7]=insights.context;
   }
}

void UpdatePanel()
{
   if(!g_uiBuilt) return;
   datetime now=ServerNow(); UpdateState(now);
   bool supported=ChartSupported(), closed=supported && g_marketState==MARKET_CLOSED;
   if(supported!=g_uiSupported || closed!=g_uiClosed)
   {
      ObjectsDeleteAll(0,UI_PREFIX); UIResetCounts(); g_uiSupported=supported; g_uiClosed=closed;
   }
   int pad=10,gap=8,x=UI_X+pad,y=UI_Y+pad,w,h;
   UIMeasure("Mg",UI_SIZE,w,h); int step=h+6;
   UIMeasure("Mg",UI_SIZE+2,w,h); step=(int)MathMax(step,h+6);
   if(!supported)
   {
      UIRestoreChartTrades();
      string tf=EnumToString((ENUM_TIMEFRAMES)_Period);
      if(StringFind(tf,"PERIOD_")==0) tf=StringSubstr(tf,7);
      string title="MT V1.00 | "+g_symbol+" | "+tf;
      string notice="Incompatible chart. Switch to M5/M15/M30.";
      int width=(int)MathMax(UIWidth(title),UIWidth(notice))+2*pad+4;
      UIBox("bg",UI_X,UI_Y,width,2*pad+2*step,UI_BG,UI_BORDER);
      UIText("unsupportedTitle",x,y,title,UI_TITLE,UI_SIZE+1);
      UIText("unsupportedNotice",x,y+step,notice,clrTomato,UI_SIZE+1);
      DetailsRemove();
      ChartRedraw(); return;
   }
   UIHideChartTrades();
   // The market-closed layout only changes presentation: continue the same
   // readings refresh so the timer/tick and broker-management paths are intact.
   P2Update();
   string timer=P4ScheduleText(),timerValue=UIAfter(timer,"Timer: ");
   if(timerValue=="") timerValue=timer;
   string timerState=StringFind(timerValue,"CLOCK UNAVAILABLE")==0?"CLOCK UNAVAILABLE":UIWord(timerValue,0);
   string timerLabel="Timer: "+timerState;
   bool timerDetail=(timerValue!=timerState);
   string timerTip=timer+". The timer uses the PC/VPS local clock and gates new entries, not open positions.";
   if(closed)
   {
      string detail=g_marketDetail;
      if(detail=="") detail=g_nextOpen>0?"MARKET CLOSED - next open "+FormatClock(g_nextOpen):"MARKET CLOSED - next open --";
      int brandW=UIWidth("MT V1.00")+10,symbolW=UIWidth(g_symbol,UI_SIZE+2)+8;
      int typeW=UIWidth(g_type)+10,stateW=UIWidth("close")+10;
      // The header keeps the symbol-wide statistics line while the market is
      // closed; the body is collapsed, not the account's record.
      string closedStats="";
      string statToday="",statAll="";
      if(UIStats(P5Summary(-1,now),"*",statToday,statAll)) closedStats=UIHeaderStats(statToday,statAll);
      else closedStats="Trade statistics unavailable";
      int headerW=brandW+symbolW+typeW+stateW+UIWidth(closedStats)+UIWidth(timerLabel)+46;
      int chartW=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
      // An open diary window keeps its column: the collapsed header wraps its
      // notice inside the room that is left, so the two never overlap.
      int available=(int)MathMax(headerW,chartW-2*UI_X-2*pad);
      int width=(int)MathMax(headerW,MathMin(UIWidth(detail),available));
      UIGrowStep(g_symbol,UI_SIZE+2,step); UIGrowStep(detail,UI_SIZE,step);
      bool fits=UIWidth(detail)<=width;
      int rows=fits?1:UIWrappedRows(detail,width);
      UIBox("bg",UI_X,UI_Y,width+2*pad,2*pad+(rows+1)*step+6,UI_BG,UI_BORDER);
      UIBox("brand",x,y-2,brandW,step,UI_BADGE,UI_BORDER);
      UIBox("type",x+brandW+symbolW,y-2,typeW,step,UI_BADGE,UI_BORDER);
      UIBox("marketState",x+brandW+symbolW+typeW+5,y-2,stateW,step,UIChipFill("close"),UI_BORDER);
      UIText("brandText",x+5,y,"MT V1.00",UI_TITLE,UI_SIZE);
      UIText("symbol",x+brandW+4,y,g_symbol,clrWhite,UI_SIZE+2);
      UIText("typeText",x+brandW+symbolW+5,y,g_type,clrSilver,UI_SIZE);
      UIText("stateText",x+brandW+symbolW+typeW+10,y,"close",clrTomato,UI_SIZE);
      int closedStatsX=x+brandW+symbolW+typeW+stateW+14;
      UIBox("stats",closedStatsX,y-2,UIWidth(closedStats)+12,step,UI_SURFACE,UI_BORDER);
      UIText("statsText",closedStatsX+6,y,closedStats,UI_MUTED,UI_SIZE,
             "Broker-confirmed trade diary for this symbol and account: today then all time.");
      int closedTimerX=closedStatsX+UIWidth(closedStats)+20;
      UIBox("timerBadge",closedTimerX,y-2,UIWidth(timerLabel)+12,step,UI_SURFACE,UI_BORDER);
      UIText("timerStatus",closedTimerX+6,y,timerLabel,clrWhite,UI_SIZE,timerTip);
      UIText("closedDetail",x,y+step+6,fits?detail:"",clrSilver,UI_SIZE,"Broker session times are in server time.");
      UIWrapped("marketDetail",x,y+step+6,fits?"":detail,width,step,clrSilver,"Broker session times are in server time.",g_uiMarketNotes);
      // The diary window is a separate window: it stays visible with its own
      // content while the main panel is collapsed. The collapsed header keeps
      // its full-width notice, so the window moves under it instead of
      // overlapping it - and returns to the panel's right side on reopening.
      if((InpShowDetails || InpMode==MT_CRF_MODE_CRF))
      {
         UIRefreshDetails(now);
         int requested=g_uiDetailsShown?g_uiDetailsW:UIDetailsNaturalWidth();
         int wx=(int)MathMax(UI_X,chartW-UI_X-requested);
         int wy=UI_Y+2*pad+(rows+1)*step+6+gap;
         UpdateDetailsWindow(wx,0,0,step,wy);
      }
      else if(g_uiDetailsShown) DetailsRemove();
      ChartRedraw(); return;
   }
   string tf[3]={"M5","M15","M30"}, readings[3],planText[3],autos[3],diaries[3];
   bool readingOK[3]; UIPlan plan[3];
   for(int i=0;i<3;i++)
   {
      readings[i]=(i==1 && CRFDisplayM15())?CRFReadingLine():P2Line(i);
      readingOK[i]=UIReadingsValid(readings[i],tf[i]);
      planText[i]=(i==1 && CRFDisplayM15())?CRFPlanLine():P3PlanLine(i);
      UIReadPlan(planText[i],tf[i],plan[i]); autos[i]=(i==1 && CRFDisplayM15())?CRFAutoLine():P4Line(i);
      diaries[i]=P5Summary(i,now);
   }
   // TRADE STATISTICS are now one symbol-wide line in the header: today and
   // all-time across every lane. Per-lane counts live in the diary window.
   string statsLine="",statsToday="",statsAll="";
   bool statsReady=UIStats(P5Summary(-1,now),"*",statsToday,statsAll);
   if(statsReady) statsLine=UIHeaderStats(statsToday,statsAll);
   else           statsLine="Trade statistics unavailable";
   // The window's own width is known before the panel is sized, so the panel
   // yields only the room the window actually needs.
   int detailsW=0;
   if((InpShowDetails || InpMode==MT_CRF_MODE_CRF))
   {
      UIRefreshDetails(now);
      detailsW=UIDetailsNaturalWidth();
   }
   string state="",clock=""; color stateInk=clrWhite;
   switch(g_marketState)
   {
      case MARKET_OPEN: state="OPEN"; stateInk=clrLime; clock=now>0?FormatClock(now):"--"; break;
      case MARKET_CLOSED: state="close"; stateInk=clrTomato; clock=g_nextOpen>0?"Open at "+FormatClock(g_nextOpen):"Open at --"; break;
      case MARKET_STALE: state="OPEN - STALE QUOTE"; stateInk=clrOrange; break;
      case MARKET_OFFLINE: state="DISCONNECTED"; stateInk=clrTomato; break;
      case MARKET_UNAVAILABLE: state="TRADING UNAVAILABLE"; stateInk=clrOrange; break;
      default: state="MARKET STATUS UNKNOWN"; stateInk=clrOrange; break;
   }
   string bid="--",ask="--"; MqlTick q;
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   bool haveQuote=SymbolInfoTick(_Symbol,q) && q.bid>0 && q.ask>=q.bid;
   bool freshQuote=haveQuote && g_marketState==MARKET_OPEN && P4FreshQuote(q);
   if(freshQuote) { bid=DoubleToString(q.bid,digits); ask=DoubleToString(q.ask,digits); }
   string planDistance[3],autoQuote[3]; bool compactPlan[3];
   for(int i=0;i<3;i++)
   {
      compactPlan[i]=plan[i].signal=="NONE" && plan[i].entry=="" && plan[i].notes=="" && plan[i].volume=="" && plan[i].style=="";
      planDistance[i]=(plan[i].signal=="BUY" || plan[i].signal=="SELL")?
                      "TP distance (price): "+UITPDistance(plan[i].signal,plan[i].tp,freshQuote,q,digits):"";
      autoQuote[i]="";
      string direction="",style="";
      string mode=UIPart(autos[i],1);
      if(UIPart(autos[i],0)==tf[i] && (mode=="Auto: ON" || mode=="Auto: OFF") && UIAutoTrade(autos[i],direction,style))
      {
         autos[i]+=" | TP distance (price): "+UITPDistance(direction,UIAutoTarget(autos[i]),freshQuote,q,digits);
         autoQuote[i]=(direction=="BUY"?"Ask: ":"Bid: ")+(freshQuote?(direction=="BUY"?ask:bid):"--");
      }
   }
   string groups[8]={"Auto Trading","SL Placement","Bypass Risk","Minimum Lot","Input mode","TP %","Trend to Follow","Allow Against Trend"};
   int start[8]={0,1,2,3,13,4,7,10}, count[8]={1,1,1,1,1,3,3,3};
   string values[14];
   values[0]=UIOnOff(InpAutoTrading); values[1]=UIOnOff(InpPlaceStopLoss);
   values[2]=UIOnOff(InpBypassRisk); values[3]=UIOnOff(InpMinimumLot); values[13]=CRFModeText();
   for(int i=0;i<3;i++) { values[4+i]=tf[i]+" "+UITP(i); values[7+i]=tf[i]+" "+UITrend(P3Choice(i)); values[10+i]=tf[i]+" "+UIOnOff(P3Against(i)); }
   // Height must cover the actual displayed glyphs, not just an example string.
   UIGrowStep(g_symbol,UI_SIZE+2,step); UIGrowStep(g_type,UI_SIZE,step);
   UIGrowStep(state,UI_SIZE,step); UIGrowStep(clock,UI_SIZE,step);
   UIGrowStep(bid,UI_SIZE,step); UIGrowStep(ask,UI_SIZE,step);
   UIGrowStep(g_marketDetail,UI_SIZE,step); UIGrowStep(timer,UI_SIZE,step);
   for(int i=0;i<3;i++)
   {
      UIGrowStep(readings[i],UI_SIZE,step); UIGrowStep(planText[i],UI_SIZE,step);
      UIGrowStep(autos[i],UI_SIZE,step); UIGrowStep(diaries[i],UI_SIZE,step);
   }
   // Use the largest readable setting font that fits the available chart width.
   // If even the smallest size does not fit, the panel expands as before.
   int chartW=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   // With the diary window open it gets its own column on the right, so the
   // panel packs its own content into the rest of the chart instead of over it.
   int panelMax=chartW;
   if((InpShowDetails || InpMode==MT_CRF_MODE_CRF) && chartW>0)
      panelMax=(int)MathMax(DETAILS_PANEL_FLOOR+2*pad,chartW-gap-detailsW-UI_X);
   int settingSize=11,groupW[8],badgeW[14],settingsRow[8],rowOf[8],rowGroups[8],settingRows=2;
   int settingGap=18,settingLabelPad=8,settingBadgePad=12,settingChipGap=4;
   for(int pass=0;pass<4;pass++)
   {
      settingSize=pass<3?11-pass:9;
      settingGap=pass==3?12:18; settingLabelPad=pass==3?4:8;
      settingBadgePad=pass==3?8:12; settingChipGap=pass==3?2:4;
      settingsRow[0]=4*settingGap; settingsRow[1]=2*settingGap;
      for(int g=0;g<8;g++)
      {
         groupW[g]=UIWidth(groups[g],settingSize)+settingLabelPad;
         for(int j=0;j<count[g];j++)
         {
            int k=start[g]+j; badgeW[k]=UIWidth(values[k],settingSize)+settingBadgePad;
            groupW[g]+=badgeW[k]+(j>0?settingChipGap:0);
         }
         settingsRow[g<5?0:1]+=groupW[g];
      }
      if((int)MathMax(settingsRow[0],settingsRow[1])+20<=panelMax-2*UI_X-2*pad || pass==3) break;
   }
   // Preserve the requested two-row grouping where it fits. On tighter charts,
   // wrap whole setting groups rather than overlapping or hiding their values.
   int settingBudget=(int)MathMax(1,panelMax-2*UI_X-2*pad-20);
   for(int r=0;r<8;r++) { settingsRow[r]=0; rowGroups[r]=0; }
   int row=0;
   for(int g=0;g<8;g++)
   {
      if((g==5 || (rowGroups[row]>0 && settingsRow[row]+settingGap+groupW[g]>settingBudget)) && rowGroups[row]>0) row++;
      rowOf[g]=row;
      if(rowGroups[row]>0) settingsRow[row]+=settingGap;
      settingsRow[row]+=groupW[g]; rowGroups[row]++;
   }
   settingRows=row+1;
   int settingsWidth=0;
   for(int r=0;r<settingRows;r++) settingsWidth=(int)MathMax(settingsWidth,settingsRow[r]);
   for(int g=0;g<8;g++) UIGrowStep(groups[g],settingSize,step);
   for(int i=0;i<14;i++) UIGrowStep(values[i],settingSize,step);
   // The three plan rows are stacked in one column, so they share one set of
   // column widths: the widest Entry/Lot/SL/TP across the lanes. SL and TP
   // amounts stay beside their price; if that does not fit the stacked row,
   // they move under it rather than being shortened or dropped.
   int planCol[3][4],planTotal=0;
   bool inlineCash=true; int planSize=UI_SIZE,moneySize=UI_SIZE-1;
   string planHead[4]={"Entry","Lot","SL","TP"};
   for(int c=0;c<4;c++) planCol[0][c]=UIWidth(planHead[c],planSize)+8;
   for(int i=0;i<3;i++)
   {
      string data[4];
      data[0]=plan[i].entry; data[1]=plan[i].lot; data[2]=plan[i].sl; data[3]=plan[i].tp;
      for(int c=0;c<4;c++)
      {
         if(data[c]=="") continue;
         int content=UIWidth(data[c],planSize);
         string cash=c==2?plan[i].slCash:(c==3?plan[i].tpCash:"");
         if(cash!="") content+=4+UIWidth(cash,moneySize);
         planCol[0][c]=(int)MathMax(planCol[0][c],content+8);
      }
   }
   planTotal=planCol[0][0]+planCol[0][1]+planCol[0][2]+planCol[0][3];
   int tfW=UIWidth("M30")+16;
   int autoLead=tfW+UIWidth("Auto")+UIWidth("OFF")+30;
   // The header line carries brand, symbol, type, state, the statistics line,
   // the clock; quotes now sit beside the Auto Execution section title.
   int leftHead=UIWidth("MT V1.00")+UIWidth(g_symbol,UI_SIZE+2)+UIWidth(g_type)+UIWidth(state)+70;
   int autoTitleMin=(int)MathMax(UI_AUTO_MIN_W,UIWidth("AUTO EXECUTION")+UIWidth("Bid: "+bid)+UIWidth("Ask: "+ask)+42);
   int autoMin=autoTitleMin;
   for(int i=0;i<3;i++)
   {
      autoMin=(int)MathMax(autoMin,UIAutoFirstWidth(autos[i],autoLead));
      if(autoQuote[i]!="")
         for(int t=0;t<UIPartCount(autos[i]);t++)
         {
            string part=UIPart(autos[i],t);
            if(StringFind(part,"TP distance (price): ")==0)
               autoMin=(int)MathMax(autoMin,UIWidth(part)+UIWidth(autoQuote[i])+24);
         }
   }
   int minW=(int)MathMax(leftHead+UIWidth(statsLine)+UIWidth(timerLabel)+UIWidth(clock)+55,
                         settingsWidth+20);
   minW=(int)MathMax(minW,UI_READ_MIN_W+gap+autoMin);
   int inner=minW;
   int panelWidth=inner+2*pad;
   // TF GT CT ST RG PT SC SG - SG sits at the right of SC. Columns are only as
   // wide as their own header and values plus a small gutter, so the row stays
   // compact instead of spreading the readings across the panel.
   int readW[8]; string cols[8]={"TF","GT","CT","ST","RG","PT","SC","SG"}; int sum=0;
   for(int c=0;c<8;c++)
   {
      int pad=UI_READ_PAD;
      readW[c]=UIWidth(cols[c])+pad;
      for(int i=0;i<3;i++)
      {
         if(c>0 && c<7 && !readingOK[i]) continue;
         string val=(c==0?tf[i]:(c==7?UISignal(planText[i],tf[i]):""));
         if(c>0 && c<7) UIReadingField(readings[i],cols[c],val);
         readW[c]=(int)MathMax(readW[c],UIWidth(val)+pad);
      }
      sum+=readW[c];
   }
   int leftMin=sum+10;
   if(leftMin+gap+autoMin>inner) { inner=leftMin+gap+autoMin; panelWidth=inner+2*pad; }
   // With the diary window open the two must fit side by side: the panel gives
   // up width for it rather than growing, down to a readable floor. Its height
   // and its trade-statistics footprint are unaffected either way.
   if((InpShowDetails || InpMode==MT_CRF_MODE_CRF) && chartW>0 && panelMax<chartW)
   {
      int budget=(int)MathMax(DETAILS_PANEL_FLOOR,panelMax-2*pad);
      if(inner>budget)
      {
         inner=budget; panelWidth=inner+2*pad;
      }
   }
   // Leftover width stays as a margin to the right of SG: a little extra gutter
   // is fine, but the columns are not stretched across the panel.
   // Keep any extra reading gutters from consuming the space needed by the
   // first broker row and the two quote badges.
   int headerMin=leftHead+UIWidth(statsLine)+UIWidth(timerLabel)+UIWidth(clock)+55;
   if(inner<(int)MathMax(leftMin+gap+autoMin,headerMin)) { inner=(int)MathMax(leftMin+gap+autoMin,headerMin); panelWidth=inner+2*pad; }
   int spare=inner-leftMin-gap-autoMin;
   int extra=spare>0?(int)MathMin(UI_READ_SPREAD,spare/8):0;
   for(int c=0;c<8;c++) readW[c]+=extra;
   // The readings box hugs its own columns; the spare width stays outside it.
   int readRowW=10;
   for(int c=0;c<8;c++) readRowW+=readW[c];
   readRowW=(int)MathMax(readRowW,leftMin);
   // TRADING PLANS are one stacked row per lane, exactly as wide as the
   // readings table above them. Empty NONE rows collapse to a single line.
   int marketRows=UIWrappedRows(g_marketDetail,inner),timerRows=timerDetail?UIWrappedRows(timer,inner-20):0;
   // Plans share the readings width. If inline fields do not fit, divide the
   // available width into four columns and wrap values and cash within them.
   int leftW=readRowW, autoW=inner-leftW-gap;
   int autoX=x+leftW+gap;
   inlineCash=(planTotal+18<=leftW);
   if(!inlineCash)
   {
      planSize=UI_SIZE-1; moneySize=UI_SIZE-2;
      int usable=(int)MathMax(4,leftW-18);
      for(int c=0;c<4;c++) planCol[0][c]=usable/4+(c<usable%4?1:0);
   }
   for(int c=0;c<4;c++) for(int i=1;i<3;i++) planCol[i][c]=planCol[0][c];
   int valueRows[3],cashRows[3];
   for(int i=0;i<3;i++)
   {
      valueRows[i]=1; cashRows[i]=0;
      if(!inlineCash && plan[i].entry!="")
      {
         string data[4]; data[0]=plan[i].entry; data[1]=plan[i].lot; data[2]=plan[i].sl; data[3]=plan[i].tp;
         for(int c=0;c<4;c++) valueRows[i]=(int)MathMax(valueRows[i],UIWrappedRows(data[c],planCol[i][c]-8,planSize));
         cashRows[i]=(int)MathMax(UIWrappedRows(plan[i].slCash,planCol[i][2]-8,moneySize),
                                  UIWrappedRows(plan[i].tpCash,planCol[i][3]-8,moneySize));
      }
   }
   int readRows[3],readTotal=0,planNoteRows[3],distanceRows[3],autoRows[3],autoTotal=0;
   for(int i=0;i<3;i++)
   {
      if(InpMode==MT_CRF_MODE_CRF && i!=1) { readRows[i]=0; planNoteRows[i]=0; distanceRows[i]=0; autoRows[i]=0; continue; }
      readRows[i]=readingOK[i]?1:(int)MathMax(1,UIWrappedRows(readings[i],leftW-20)); readTotal+=readRows[i];
      planNoteRows[i]=compactPlan[i]?0:UIWrappedRows(plan[i].notes,leftW-20);
      distanceRows[i]=compactPlan[i]?0:UIWrappedRows(planDistance[i],leftW-20);
      autoRows[i]=UIAutoFlow(autos[i],i,0,0,autoW,autoLead,step,false,"",autoQuote[i]); autoTotal+=autoRows[i]*step+4;
   }
   string crfLine=InpMode==MT_CRF_MODE_MT?"":"CRF: "+CRFHeaderStatus()+CRFChartHistoryStatus();
   int crfRows=UIWrappedRows(crfLine,inner);
   int headerH=step+6,timerY=y+headerH,crfY=timerY+timerRows*step,marketY=crfY+crfRows*step,settingsY=marketY+marketRows*step+gap;
   int settingsH=(1+settingRows)*step+10,readTitleY=settingsY+settingsH+gap,readHeaderY=readTitleY+step;
   int readY=readHeaderY+step;
   // One stacked plan row per lane; its header line carries the signal chips.
   int cardH[3],planTotalH=0;
   for(int i=0;i<3;i++)
   {
      if(InpMode==MT_CRF_MODE_CRF && i!=1) { cardH[i]=0; continue; }
      // A NONE row is one line; an unpriced plan adds its warning; a full plan
      // adds the field headings/values plus only the note lines it really has.
      if(compactPlan[i]) cardH[i]=step+10;
      else if(plan[i].entry=="") cardH[i]=(1+planNoteRows[i]+distanceRows[i])*step+10;
      else cardH[i]=(2+valueRows[i]+cashRows[i]+planNoteRows[i]+distanceRows[i])*step+10;
      planTotalH+=cardH[i]+UI_PLAN_GAP;
   }
   int planTitleY=readY+readTotal*step+gap,cardsY=planTitleY+step;
   int leftBottom=cardsY+planTotalH;
   int autoTitleY=readTitleY;
   int autoBottom=autoTitleY+step+autoTotal+pad;
   int bodyBottom=(int)MathMax(leftBottom,autoBottom);
   int panelHeight=bodyBottom-UI_Y+pad;

   // Every background is created before any text and reused on each refresh.
   UIBox("bg",UI_X,UI_Y,panelWidth,panelHeight,UI_BG,UI_BORDER);
   UIBox("settings",x,settingsY,inner,settingsH,UI_SURFACE,UI_BORDER);
   UIBox("readings",x,readHeaderY-2,readRowW,(1+readTotal)*step+4,UI_SURFACE,UI_BORDER);
   int bx=x,brandW=UIWidth("MT V1.00")+10,symbolW=UIWidth(g_symbol,UI_SIZE+2)+8,typeW=UIWidth(g_type)+10,stateW=UIWidth(state)+10;
   UIBox("brand",bx,y-2,brandW,step,UI_BADGE,UI_BORDER);
   UIBox("type",bx+brandW+symbolW,y-2,typeW,step,UI_BADGE,UI_BORDER);
   UIBox("marketState",bx+brandW+symbolW+typeW+5,y-2,stateW,step,UIChipFill(state),UI_BORDER);
   // Symbol-wide trade statistics remain on the header line.
   int statsX=bx+brandW+symbolW+typeW+stateW+14;
   int statsW=UIWidth(statsLine)+12;
   UIBox("stats",statsX,y-2,statsW,step,UI_SURFACE,UI_BORDER);
   int timerX=statsX+statsW+8;
   UIBox("timerBadge",timerX,y-2,UIWidth(timerLabel)+12,step,UI_SURFACE,UI_BORDER);
   int quoteX=autoX+UIWidth("AUTO EXECUTION")+12;
   UIBox("bidBox",quoteX,autoTitleY-2,UIWidth("Bid: "+bid)+10,step,UI_SURFACE,UI_BORDER);
   UIBox("askBox",quoteX+UIWidth("Bid: "+bid)+16,autoTitleY-2,UIWidth("Ask: "+ask)+10,step,UI_SURFACE,UI_BORDER);
   int settingX[8],badgeX[14],sx=x+10,positionInRow=0;
   for(int g=0;g<8;g++)
   {
      int r=rowOf[g];
      if(g==0 || r!=rowOf[g-1]) { sx=x+10; positionInRow=0; }
      int gapCount=rowGroups[r]-1;
      int extra=inner-20-settingsRow[r];
      settingX[g]=sx; int cy=settingsY+step+4+r*step;
      int chipX=sx+UIWidth(groups[g],settingSize)+settingLabelPad;
      for(int j=0;j<count[g];j++)
      {
         int k=start[g]+j; badgeX[k]=chipX;
         UIBox("settingBadge"+IntegerToString(k),chipX,cy-2,badgeW[k],step,UIChipFill(values[k]),UI_BORDER);
         chipX+=badgeW[k]+settingChipGap;
      }
      sx+=groupW[g];
      if(positionInRow<gapCount)
      {
         int between=settingGap+extra/gapCount+(positionInRow<extra%gapCount?1:0);
         UIBox("settingDivider"+IntegerToString(g),sx+between/2,cy,1,step-4,UI_BORDER,UI_BORDER);
         sx+=between;
      }
      else ObjectDelete(0,(string)UI_PREFIX+"settingDivider"+IntegerToString(g));
      positionInRow++;
   }
   // Remove objects from the previous nine-group layout after an EA upgrade.
   for(int g=8;g<9;g++) { UIText("settingKey"+IntegerToString(g),0,0,"",clrSilver,settingSize); ObjectDelete(0,(string)UI_PREFIX+"settingDivider"+IntegerToString(g)); }
   for(int k=14;k<15;k++) { UIText("settingValue"+IntegerToString(k),0,0,"",clrWhite,settingSize); ObjectDelete(0,(string)UI_PREFIX+"settingBadge"+IntegerToString(k)); }
   int rx=x+10;
   for(int c=0;c<8;c++)
   {
      int yy=readY;
      for(int i=0;i<3;i++)
      {
         if(InpMode==MT_CRF_MODE_CRF && i!=1) continue;
         string v=UISignalCell(readings[i],planText[i],tf[i],cols[c],c,readingOK[i]);
         UIBox("readingBadge"+IntegerToString(i)+"_"+IntegerToString(c),rx,yy-2,UIWidth(v)+8,step,
               c<5 && v!=""?UIChipFill(v):UI_SURFACE,UI_SURFACE);
         yy+=readRows[i]*step;
      }
      rx+=readW[c];
   }
   // TRADING PLANS: one row per lane, stacked, each exactly as wide as the
   // readings table. The header line carries TF + signal + style + volume; an
   // active plan adds Entry/Lot/SL/TP and any notes underneath.
   int cardX[3],cardY[3];
   int stackedY=cardsY;
   for(int i=0;i<3;i++)
   {
      if(InpMode==MT_CRF_MODE_CRF && i!=1) continue;
      string n=IntegerToString(i); cardX[i]=x; cardY[i]=stackedY;
      UIBox("plan"+n,cardX[i],cardY[i],leftW,cardH[i],UI_SURFACE,UI_BORDER);
      UIBox("planTF"+n,cardX[i]+6,cardY[i]+4,tfW-6,step,UI_BADGE,UI_BORDER);
      int sigX=cardX[i]+tfW+6,sigW=UIWidth(plan[i].signal)+10,styleW=UIWidth(plan[i].style)+10;
      UIBox("planSignal"+n,sigX,cardY[i]+4,sigW,step,
            plan[i].signal=="NONE" || plan[i].signal=="WAIT"?UI_SURFACE:UIChipFill(plan[i].signal),UI_SURFACE);
      UIBox("planStyle"+n,sigX+sigW+2,cardY[i]+4,styleW,step,plan[i].style==""?UI_SURFACE:UI_BADGE,UI_SURFACE);
      UIBox("planVolume"+n,sigX+sigW+styleW+4,cardY[i]+4,UIWidth("VOL "+plan[i].volume)+10,step,
            plan[i].volume==""?UI_SURFACE:UI_BADGE,UI_SURFACE);
      stackedY+=cardH[i]+UI_PLAN_GAP;
   }
   // AUTO EXECUTION column: one box per lane, starting level with the readings.
   int autoY=readHeaderY-2;
   for(int i=0;i<3;i++)
   {
      if(InpMode==MT_CRF_MODE_CRF && i!=1) continue;
      string n=IntegerToString(i),mode=UIAfter(UIPart(autos[i],1),"Auto: ");
      UIBox("autoRow"+n,autoX,autoY,autoW,autoRows[i]*step+4,UI_SURFACE,UI_BORDER);
      UIBox("autoTF"+n,autoX+5,autoY+2,tfW-5,step,UI_BADGE,UI_BORDER);
      UIBox("autoMode"+n,autoX+tfW+UIWidth("Auto")+10,autoY+2,UIWidth("OFF")+10,step,UIChipFill(mode),UI_BORDER);
      string direction="",style=""; bool trade=UIAutoTrade(autos[i],direction,style);
      int tradeW=UIWidth(direction)+10;
      UIBox("autoTrade"+n,autoX+autoLead,autoY+2,tradeW,step,trade?UIChipFill(direction):UI_SURFACE,UI_SURFACE);
      UIBox("autoStyle"+n,autoX+autoLead+tradeW+2,autoY+2,UIWidth(style)+10,step,trade?UI_BADGE:UI_SURFACE,UI_SURFACE);
      autoY+=autoRows[i]*step+4;
   }

   UIText("brandText",bx+5,y,"MT V1.00",UI_TITLE,UI_SIZE);
   UIText("symbol",bx+brandW+4,y,g_symbol,clrWhite,UI_SIZE+2);
   UIText("typeText",bx+brandW+symbolW+5,y,g_type,clrSilver,UI_SIZE);
   UIText("stateText",bx+brandW+symbolW+typeW+10,y,state,stateInk,UI_SIZE);
   UIText("statsText",statsX+6,y,statsLine,UI_MUTED,UI_SIZE,
          "Broker-confirmed trade diary for this symbol and account: T today, A all time. S accepted orders; W/L reconciled wins/losses. Break-even is recorded separately in the diary.");
   UIText("timerStatus",timerX+6,y,timerLabel,clrWhite,UI_SIZE,timerTip);
   UIText("bidText",quoteX+5,autoTitleY,"Bid: "+bid,clrWhite,UI_SIZE);
   UIText("askText",quoteX+UIWidth("Bid: "+bid)+21,autoTitleY,"Ask: "+ask,clrWhite,UI_SIZE);
   UIText("clock",x+inner-UIWidth(clock),y,clock,clrWhite,UI_SIZE);
   UIWrapped("timerDetail",x,timerY,timerDetail?timer:"",inner,step,clrSilver,timerTip,g_uiTimerNotes);
   UIWrapped("crfStatus",x,crfY,crfLine,inner,step,clrSilver,"CRF uses closed M15 bars and broker-confirmed execution.",g_uiCrfNotes);
   UIWrapped("marketDetail",x,marketY,g_marketDetail,inner,step,clrSilver,"",g_uiMarketNotes);
   UIText("settingsTitle",x+10,settingsY+3,"SETTINGS",UI_MUTED,UI_SIZE);
   string settingsTip="Input settings only. SL Placement OFF sends new orders without a broker stop loss. Other trading and broker rules still apply.";
   string trendTip="Trend to Follow selects the reference; Allow Against Trend controls alignment, not whether a timeframe is enabled. TP % is each lane's historical percentile (1-100); INVALID uses original TP logic for that lane.";
   for(int g=0;g<8;g++)
   {
      int cy=settingsY+step+4+rowOf[g]*step; string tip=g<4?settingsTip:trendTip;
      UIText("settingKey"+IntegerToString(g),settingX[g],cy,groups[g],clrSilver,settingSize,tip);
      for(int j=0;j<count[g];j++) { int k=start[g]+j; UIText("settingValue"+IntegerToString(k),badgeX[k]+settingBadgePad/2,cy,values[k],clrWhite,settingSize,tip); }
   }
   UIText("readTitle",x,readTitleY,"MARKET READINGS",UI_MUTED,UI_SIZE);
   UIText("planTitle",x,planTitleY,"TRADING PLANS",UI_MUTED,UI_SIZE);
   UIText("autoTitle",autoX,autoTitleY,"AUTO EXECUTION",UI_MUTED,UI_SIZE);
   rx=x+14;
   for(int c=0;c<8;c++)
   {
      UIText("col"+IntegerToString(c),rx,readHeaderY,cols[c],UI_MUTED,UI_SIZE,
             c==7?"SG is this lane's own signal - the same value as its TRADING PLANS card.":"");
      int yy=readY;
      for(int i=0;i<3;i++)
      {
         if(InpMode==MT_CRF_MODE_CRF && i!=1) continue;
         string v=UISignalCell(readings[i],planText[i],tf[i],cols[c],c,readingOK[i]);
         UIText("reading"+IntegerToString(i)+"_"+IntegerToString(c),rx,yy,v,
                c==7?UISignalColor(v):UIValueColor(v),UI_SIZE);
         yy+=readRows[i]*step;
      }
      rx+=readW[c];
   }
   int yy=readY;
   string planTip="Frozen trading plan, not necessarily the broker order. SL and TP amounts are estimates in account currency. If SL placement is off, the planned SL is a sizing reference, not a protective stop. TP distance is in price units from the current BUY Bid or SELL Ask; negative means the target was passed. A pending plan is not a fill.";
   for(int i=0;i<3;i++)
   {
      if(InpMode==MT_CRF_MODE_CRF && i!=1) continue;
      string n=IntegerToString(i);
      UIWrapped("readFallback"+n+"_",x+10,yy,readingOK[i]?"":readings[i],leftW-20,step,clrSilver,"",g_uiReadingNotes[i]); yy+=readRows[i]*step;
      int rowY=cardY[i];
      UIText("planTFText"+n,cardX[i]+10,rowY+6,plan[i].recognized?tf[i]:"",clrWhite,UI_SIZE,planTip);
      int sigX=cardX[i]+tfW+11;
      UIText("planSignalText"+n,sigX,rowY+6,plan[i].signal,UIValueColor(plan[i].signal),UI_SIZE,planTip);
      int styleX=cardX[i]+tfW+6+UIWidth(plan[i].signal)+12;
      UIText("planStyleText"+n,styleX+5,rowY+6,plan[i].style,clrWhite,UI_SIZE,planTip);
      UIText("planVolumeText"+n,styleX+UIWidth(plan[i].style)+17,rowY+6,
             plan[i].volume==""?"":"VOL "+plan[i].volume,clrSilver,UI_SIZE,planTip);
      string data[4];
      data[0]=plan[i].entry; data[1]=plan[i].lot; data[2]=plan[i].sl; data[3]=plan[i].tp;
      int colX=cardX[i]+9;
      for(int c=0;c<4;c++)
      {
         string id=n+"_"+IntegerToString(c);
         UIText("planHeading"+id,colX,rowY+step+9,plan[i].entry==""?"":planHead[c],UI_MUTED,planSize,planTip);
         UIText("planValue"+id,colX,rowY+2*step+9,inlineCash?data[c]:"",clrWhite,planSize,planTip);
         UIWrapped("planValueRows"+id+"_",colX,rowY+2*step+9,inlineCash?"":data[c],planCol[i][c]-8,step,clrWhite,planTip,g_uiPlanValues[i][c],planSize);
         if(c==2 || c==3)
         {
            string money=c==2?plan[i].slCash:plan[i].tpCash;
            UIText("planMoney"+id,colX+UIWidth(data[c],planSize)+4,rowY+2*step+9,inlineCash?money:"",c==2?clrTomato:clrLime,moneySize,planTip);
            UIWrapped("planMoneyRows"+id+"_",colX,rowY+(2+valueRows[i])*step+9,inlineCash?"":money,planCol[i][c]-8,step,c==2?clrTomato:clrLime,planTip,g_uiCashRows[i][c-2],moneySize);
         }
         colX+=planCol[i][c];
      }
      int detailY=rowY+(plan[i].entry==""?1:2+valueRows[i]+cashRows[i])*step+9;
      UIWrapped("planNote"+n+"_",cardX[i]+10,detailY,plan[i].notes,leftW-20,step,clrOrange,planTip,g_uiPlanNotes[i]);
      int distanceY=detailY+planNoteRows[i]*step;
      UIWrapped("planDistance"+n+"_",cardX[i]+10,distanceY,planDistance[i],leftW-20,step,clrSilver,planTip,g_uiPlanDistances[i]);
      UIText("planQuote"+n,0,0,"",clrWhite,UI_SIZE);
   }
   autoY=readHeaderY;
   for(int i=0;i<3;i++)
   {
      if(InpMode==MT_CRF_MODE_CRF && i!=1) continue;
      string n=IntegerToString(i),tip=(i==1 && CRFDisplayM15()?"CRF M15: "+g_crfStatus:P4Tooltip(i)),mode=UIPart(autos[i],1);
      bool normal=(UIPart(autos[i],0)==tf[i] && (mode=="Auto: ON" || mode=="Auto: OFF"));
      if(StringFind(autos[i]," | TP distance (price): ")>=0) tip+=" TP distance is from the current BUY Bid or SELL Ask to the broker TP, in price units; negative means passed. A pending order is not a fill.";
      UIText("autoTFText"+n,autoX+9,autoY,normal?tf[i]:"",clrWhite,UI_SIZE,tip);
      UIText("autoKey"+n,autoX+tfW+2,autoY,normal?"Auto":"",clrSilver,UI_SIZE,tip);
      UIText("autoModeText"+n,autoX+tfW+UIWidth("Auto")+15,autoY,normal?UIAfter(mode,"Auto: "):"",clrWhite,UI_SIZE,tip);
      string direction="",style=""; bool trade=normal && UIAutoTrade(autos[i],direction,style);
      UIText("autoTradeText"+n,autoX+autoLead+5,autoY,trade?direction:"",UIValueColor(direction),UI_SIZE,tip);
      UIText("autoStyleText"+n,autoX+autoLead+UIWidth(direction)+17,autoY,trade?style:"",clrWhite,UI_SIZE,tip);
      UIAutoFlow(autos[i],i,autoX,autoY,autoW,autoLead,step,true,tip,autoQuote[i]);
      autoY+=autoRows[i]*step+4;
   }
   // The old per-timeframe TRADE STATISTICS grid is gone: the header line
   // carries the symbol-wide totals and per-lane numbers are in the window.
   for(int i=0;i<3;i++) UIWrapped("diaryFallback"+IntegerToString(i)+"_",autoX,autoTitleY,"",autoW,step,clrSilver,"",g_uiDiaryNotes[i]);
   UpdateDetailsWindow(UI_X,panelWidth,gap,step,UI_Y);
   ChartRedraw();
}
void BuildPanel() { g_uiBuilt=true; UpdatePanel(); }
#endif
