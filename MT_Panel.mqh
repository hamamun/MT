#ifndef MT_PANEL_MQH
#define MT_PANEL_MQH

// Presentation only. The trading/diary runtimes remain the source of data.
#define UI_PREFIX "MT_"
#define UI_FONT "Consolas"
#define UI_SIZE 10
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

bool g_uiBuilt=false, g_uiSupported=false;
int g_uiAutoParts[3]={0,0,0}, g_uiPlanNotes[3]={0,0,0};
int g_uiReadingNotes[3]={0,0,0}, g_uiDiaryNotes[3]={0,0,0}, g_uiDetails[3]={0,0,0};
int g_uiCashRows[3][2]={{0,0},{0,0},{0,0}};
int g_uiMarketNotes=0, g_uiTimerNotes=0;

void UIResetCounts()
{
   for(int i=0;i<3;i++) { g_uiAutoParts[i]=0; g_uiPlanNotes[i]=0; g_uiReadingNotes[i]=0; g_uiDiaryNotes[i]=0; g_uiDetails[i]=0; g_uiCashRows[i][0]=0; g_uiCashRows[i][1]=0; }
   g_uiMarketNotes=0; g_uiTimerNotes=0;
}
void PanelRemove()
{
   // MT_ is the established panel prefix, including objects from older layouts.
   ObjectsDeleteAll(0,UI_PREFIX);
   g_uiBuilt=false; g_uiSupported=false; UIResetCounts();
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
void UIText(const string name, int x, int y, const string text, color ink, int size, const string tip="")
{
   int segment=0;
   for(int offset=0;offset<StringLen(text);offset+=48)
   {
      string part=StringSubstr(text,offset,48), obj=UI_PREFIX+name+"_"+IntegerToString(segment);
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
   while(ObjectFind(0,UI_PREFIX+name+"_"+IntegerToString(segment))>=0)
   { ObjectDelete(0,UI_PREFIX+name+"_"+IntegerToString(segment)); segment++; }
}
void UIBox(const string name, int x, int y, int w, int h, color fill, color border)
{
   string obj=UI_PREFIX+name;
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
   if(value=="WAIT" || value=="CONFLICT" || StringFind(value,"NO SL")>=0 ||
      StringFind(value,"REVIEW")>=0 || StringFind(value,"unavailable")>=0 || StringFind(value,"PAUSED")>=0) return(clrOrange);
   return(clrSilver);
}
// Maximal pixel-fitting fragment; prefer a word boundary, but never drop text.
int UIFit(const string text, int start, int width, int size=UI_SIZE)
{
   int left=StringLen(text)-start, lo=1, hi=(int)MathMin(48,left), fit=0;
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
void UIWrapped(const string name, int x, int y, const string text, int width, int step, color ink, const string tip, int &previous, int size=UI_SIZE)
{
   int row=0;
   for(int pos=0;pos<StringLen(text);)
   {
      int n=UIFit(text,pos,width,size);
      UIText(name+IntegerToString(row),x,y+row*step,StringSubstr(text,pos,n),ink,size,tip);
      pos+=n; row++;
   }
   for(int i=row;i<previous;i++) UIText(name+IntegerToString(i),x,y,"",ink,size);
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
bool UIAutoTrade(const string line, string &direction, string &style)
{
   string token=UIPart(line,2);
   direction=UIWord(token,0); style=UIWord(token,1);
   return((direction=="BUY" || direction=="SELL") && (style=="OPEN" || style=="LIMIT") && token==direction+" "+style);
}
// Place broker tokens across a row, wrapping as needed without abbreviating notes.
int UIAutoFlow(const string line, int lane, int x, int y, int width, int lead, int step, bool draw, const string tip)
{
   string tf=UIPart(line,0),mode=UIPart(line,1);
   bool normal=(tf==(lane==0?"M5":(lane==1?"M15":"M30")) && (mode=="Auto: ON" || mode=="Auto: OFF"));
   string direction="",style="";
   bool trade=normal && UIAutoTrade(line,direction,style);
   int extra=trade?UIWidth(direction)+UIWidth(style)+24:0;
   int count=normal?UIPartCount(line):1, first=normal?(trade?3:2):0, row=0, cursor=normal?lead+extra:8, part=0;
   for(int t=first;t<count;t++)
   {
      string item=normal?UIPart(line,t):line;
      if(item=="") continue;
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
   }
   return(row+1);
}

void UpdatePanel()
{
   if(!g_uiBuilt) return;
   datetime now=ServerNow(); UpdateState(now);
   bool supported=ChartSupported();
   if(supported!=g_uiSupported)
   {
      ObjectsDeleteAll(0,UI_PREFIX); UIResetCounts(); g_uiSupported=supported;
   }
   int pad=10,gap=8,x=UI_X+pad,y=UI_Y+pad,w,h;
   UIMeasure("Mg",UI_SIZE,w,h); int step=h+6;
   UIMeasure("Mg",UI_SIZE+2,w,h); step=(int)MathMax(step,h+6);
   if(!supported)
   {
      string tf=EnumToString((ENUM_TIMEFRAMES)_Period);
      if(StringFind(tf,"PERIOD_")==0) tf=StringSubstr(tf,7);
      string title="MT V1.00 | "+g_symbol+" | "+tf;
      string notice="Incompatible chart. Switch to M5/M15/M30.";
      int width=(int)MathMax(UIWidth(title),UIWidth(notice))+2*pad+4;
      UIBox("bg",UI_X,UI_Y,width,2*pad+2*step,UI_BG,UI_BORDER);
      UIText("unsupportedTitle",x,y,title,UI_TITLE,UI_SIZE+1);
      UIText("unsupportedNotice",x,y+step,notice,clrTomato,UI_SIZE+1);
      ChartRedraw(); return;
   }
   P2Update();
   string tf[3]={"M5","M15","M30"}, readings[3],planText[3],autos[3],diaries[3],details[3],today[3],all[3];
   bool readingOK[3],statsOK[3]; UIPlan plan[3];
   for(int i=0;i<3;i++)
   {
      readings[i]=P2Line(i); readingOK[i]=UIReadingsValid(readings[i],tf[i]);
      planText[i]=P3PlanLine(i); UIReadPlan(planText[i],tf[i],plan[i]); autos[i]=P4Line(i);
      diaries[i]=P5Summary(i,now); statsOK[i]=UIStats(diaries[i],tf[i],today[i],all[i]);
      details[i]=InpShowDetails?P5Detail(i):"";
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
   if(SymbolInfoTick(_Symbol,q) && q.bid>0 && q.ask>=q.bid)
   { int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); bid=DoubleToString(q.bid,digits); ask=DoubleToString(q.ask,digits); }
   string groups[9]={"Auto Trading","Allow Against Trend","Minimum Lot","Bypass Risk","SL Placement","Trend to Follow","Diary Details","TP %","Timer"};
   int start[9]={0,1,4,5,6,7,10,11,14}, count[9]={1,3,1,1,1,3,1,3,1};
   string values[15];
   values[0]=UIOnOff(InpAutoTrading);
   for(int i=0;i<3;i++) values[1+i]=tf[i]+" "+UIOnOff(P3Against(i));
   values[4]=UIOnOff(InpMinimumLot); values[5]=UIOnOff(InpBypassRisk); values[6]=UIOnOff(InpPlaceStopLoss);
   for(int i=0;i<3;i++) values[7+i]=tf[i]+" "+UITrend(P3Choice(i));
   values[10]=UIOnOff(InpShowDetails);
   for(int i=0;i<3;i++) values[11+i]=tf[i]+" "+UITP(i);
   string timer=P4ScheduleText(),timerValue=UIAfter(timer,"Timer: ");
   if(timerValue=="") timerValue=timer;
   if(StringFind(timerValue,"CLOCK UNAVAILABLE")==0) values[14]="CLOCK UNAVAILABLE";
   else values[14]=UIWord(timerValue,0);
   bool timerDetail=(timerValue!=values[14]);
   // Height must cover the actual displayed glyphs, not just an example string.
   UIGrowStep(g_symbol,UI_SIZE+2,step); UIGrowStep(g_type,UI_SIZE,step);
   UIGrowStep(state,UI_SIZE,step); UIGrowStep(clock,UI_SIZE,step);
   UIGrowStep(bid,UI_SIZE,step); UIGrowStep(ask,UI_SIZE,step);
   UIGrowStep(g_marketDetail,UI_SIZE,step); UIGrowStep(timer,UI_SIZE,step);
   for(int i=0;i<3;i++)
   {
      UIGrowStep(readings[i],UI_SIZE,step); UIGrowStep(planText[i],UI_SIZE,step);
      UIGrowStep(autos[i],UI_SIZE,step); UIGrowStep(diaries[i],UI_SIZE,step); UIGrowStep(details[i],UI_SIZE,step);
   }
   // Use the largest readable setting font that fits the available chart width.
   // If even the smallest size does not fit, the panel expands as before.
   int chartW=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int settingSize=11,groupW[9],badgeW[15],settingsRow[2];
   int settingGap=18,settingLabelPad=8,settingBadgePad=12,settingChipGap=4;
   for(int pass=0;pass<4;pass++)
   {
      settingSize=pass<3?11-pass:9;
      // Tight charts retain the compact minimum; wider charts get roomier groups.
      settingGap=pass==3?4:18; settingLabelPad=pass==3?4:8;
      settingBadgePad=pass==3?8:12; settingChipGap=pass==3?2:4;
      settingsRow[0]=4*settingGap; settingsRow[1]=3*settingGap;
      for(int g=0;g<9;g++)
      {
         groupW[g]=UIWidth(groups[g],settingSize)+settingLabelPad;
         for(int j=0;j<count[g];j++)
         {
            int k=start[g]+j; badgeW[k]=UIWidth(values[k],settingSize)+settingBadgePad;
            groupW[g]+=badgeW[k]+(j>0?settingChipGap:0);
         }
         settingsRow[g<5?0:1]+=groupW[g];
      }
      if((int)MathMax(settingsRow[0],settingsRow[1])+20<=chartW-2*UI_X-2*pad || pass==3) break;
   }
   for(int g=0;g<9;g++) UIGrowStep(groups[g],settingSize,step);
   for(int i=0;i<15;i++) UIGrowStep(values[i],settingSize,step);
   // Each lane gets only the width its own plan needs. SL/TP cash amounts
   // share the price row, as in the mock, rather than adding extra rows.
   int planCol[3][4],planMin[3],planTotal=0;
   bool inlineCash=true;
   string planHead[4]={"Entry","Lot","SL","TP"};
   // On a narrow chart, put cash under its price instead of forcing the
   // three cards wider than the screen. No amount is shortened or omitted.
   for(int pass=0;pass<2;pass++)
   {
      inlineCash=(pass==0); planTotal=0;
      for(int i=0;i<3;i++)
      {
         string data[4];
         data[0]=plan[i].entry; data[1]=plan[i].lot; data[2]=plan[i].sl; data[3]=plan[i].tp;
         for(int c=0;c<4;c++)
         {
            int content=UIWidth(data[c]);
            string cash=c==2?plan[i].slCash:(c==3?plan[i].tpCash:"");
            if(cash!="")
            {
               int cashWidth=UIWidth(cash,UI_SIZE-2);
               if(inlineCash) content+=4+cashWidth;
            }
            planCol[i][c]=(int)MathMax(UIWidth(planHead[c]),content)+12;
         }
         int head=UIWidth("M30")+16+6+UIWidth(plan[i].signal)+12+UIWidth(plan[i].style)+12+
                  (plan[i].volume==""?0:UIWidth("VOL "+plan[i].volume)+14);
         int fields=plan[i].entry==""?0:planCol[i][0]+planCol[i][1]+planCol[i][2]+planCol[i][3]+8;
         planMin[i]=(int)MathMax(UIWidth("000000000000000000000")+20,(int)MathMax(head,fields));
         planTotal+=planMin[i];
      }
      if(planTotal+2*gap<=chartW-2*UI_X-2*pad || pass==1) break;
   }
   int tfW=UIWidth("M30")+16, statW=UIWidth("000")+8;
   for(int i=0;i<3;i++) if(statsOK[i]) for(int j=0;j<4;j++)
   {
      statW=(int)MathMax(statW,UIWidth(UIWord(today[i],1+j*2))+8);
      statW=(int)MathMax(statW,UIWidth(UIWord(all[i],1+j*2))+8);
   }
   int diaryMin=tfW+8*statW+20;
   int autoLead=tfW+UIWidth("Auto")+UIWidth("OFF")+30;
   int leftHead=UIWidth("MT V1.00")+UIWidth(g_symbol,UI_SIZE+2)+UIWidth(g_type)+UIWidth(state)+60;
   int rightHead=UIWidth("Bid: "+bid)+UIWidth("Ask: "+ask)+UIWidth(clock)+40;
   int minW=(int)MathMax(leftHead+rightHead+gap,(int)MathMax(settingsRow[0],settingsRow[1])+20);
   minW=(int)MathMax(minW,planTotal+2*gap);
   minW=(int)MathMax(minW,diaryMin+autoLead+120+gap);
   int inner=minW;
   int panelWidth=inner+2*pad;
   int diaryW=(int)MathMax(diaryMin,(inner-gap)*38/100),autoW=inner-gap-diaryW;
   statW=(int)MathMax(statW,(diaryW-tfW-20)/8);
   int readW[7]; string cols[7]={"TF","GT","CT","ST","RG","PT","SC"}; int sum=0;
   for(int c=0;c<7;c++)
   {
      readW[c]=UIWidth(cols[c])+14;
      for(int i=0;i<3;i++) if(readingOK[i])
      { string val=""; if(c==0) val=tf[i]; else UIReadingField(readings[i],cols[c],val); readW[c]=(int)MathMax(readW[c],UIWidth(val)+14); }
      sum+=readW[c];
   }
   if(sum>inner-20) { inner=sum+20; panelWidth=inner+2*pad; diaryW=(int)MathMax(diaryMin,(inner-gap)*38/100); autoW=inner-gap-diaryW; statW=(int)MathMax(statW,(diaryW-tfW-20)/8); }
   int spare=inner-20-sum;
   for(int c=0;c<7;c++) readW[c]+=spare/7+(c<spare%7?1:0);
   int cardW[3],planSpare=inner-2*gap-planTotal;
   for(int i=0;i<3;i++) cardW[i]=planMin[i]+planSpare/3+(i<planSpare%3?1:0);
   int marketRows=UIWrappedRows(g_marketDetail,inner),timerRows=timerDetail?UIWrappedRows(timer,inner-20):0;
   int cashExtra=0;
   if(!inlineCash) for(int i=0;i<3;i++)
   {
      cashExtra=(int)MathMax(cashExtra,UIWrappedRows(plan[i].slCash,planCol[i][2]-12,UI_SIZE-2));
      cashExtra=(int)MathMax(cashExtra,UIWrappedRows(plan[i].tpCash,planCol[i][3]-12,UI_SIZE-2));
   }
   int readRows[3],readTotal=0,planNoteRows=0,autoRows[3],autoTotal=0,diaryRows[3],diaryTotal=2,detailTotal=0;
   for(int i=0;i<3;i++)
   {
      readRows[i]=readingOK[i]?1:(int)MathMax(1,UIWrappedRows(readings[i],inner-20)); readTotal+=readRows[i];
      planNoteRows=(int)MathMax(planNoteRows,UIWrappedRows(plan[i].notes,cardW[i]-20));
      autoRows[i]=UIAutoFlow(autos[i],i,0,0,autoW,autoLead,step,false,""); autoTotal+=autoRows[i]*step+4;
      diaryRows[i]=statsOK[i]?1:(int)MathMax(1,UIWrappedRows(diaries[i],diaryW-20)); diaryTotal+=diaryRows[i];
      if(InpShowDetails) detailTotal+=UIWrappedRows(details[i],diaryW-20);
   }
   int headerH=step+6,marketY=y+headerH,settingsY=marketY+marketRows*step+gap;
   int settingsH=(3+timerRows)*step+10,readTitleY=settingsY+settingsH+gap,readHeaderY=readTitleY+step;
   int readY=readHeaderY+step,planTitleY=readY+readTotal*step+gap,cardsY=planTitleY+step;
   int cardH=(3+cashExtra+planNoteRows)*step+12, bottomTitleY=cardsY+cardH+gap,bottomY=bottomTitleY+step;
   int bottomH=(int)MathMax(autoTotal+4,(diaryTotal+detailTotal)*step+12);
   int panelHeight=bottomY-UI_Y+bottomH+pad;

   // Every background is created before any text and reused on each refresh.
   UIBox("bg",UI_X,UI_Y,panelWidth,panelHeight,UI_BG,UI_BORDER);
   UIBox("settings",x,settingsY,inner,settingsH,UI_SURFACE,UI_BORDER);
   UIBox("readings",x,readHeaderY-2,inner,(1+readTotal)*step+4,UI_SURFACE,UI_BORDER);
   int bx=x,brandW=UIWidth("MT V1.00")+10,symbolW=UIWidth(g_symbol,UI_SIZE+2)+8,typeW=UIWidth(g_type)+10,stateW=UIWidth(state)+10;
   UIBox("brand",bx,y-2,brandW,step,UI_BADGE,UI_BORDER);
   UIBox("type",bx+brandW+symbolW,y-2,typeW,step,UI_BADGE,UI_BORDER);
   UIBox("marketState",bx+brandW+symbolW+typeW+5,y-2,stateW,step,UIChipFill(state),UI_BORDER);
   int quoteX=x+inner-rightHead;
   UIBox("bidBox",quoteX,y-2,UIWidth("Bid: "+bid)+10,step,UI_SURFACE,UI_BORDER);
   UIBox("askBox",quoteX+UIWidth("Bid: "+bid)+16,y-2,UIWidth("Ask: "+ask)+10,step,UI_SURFACE,UI_BORDER);
   int settingX[9],badgeX[15],sx=x+10;
   for(int g=0;g<9;g++)
   {
      if(g==5) sx=x+10;
      int row=g<5?0:1, gapCount=row==0?4:3, gapIndex=row==0?g:g-5;
      int extra=inner-20-settingsRow[row];
      settingX[g]=sx; int cy=settingsY+step+4+(row==0?0:step);
      int chipX=sx+UIWidth(groups[g],settingSize)+settingLabelPad;
      for(int j=0;j<count[g];j++)
      {
         int k=start[g]+j; badgeX[k]=chipX;
         UIBox("settingBadge"+IntegerToString(k),chipX,cy-2,badgeW[k],step,UIChipFill(values[k]),UI_BORDER);
         chipX+=badgeW[k]+settingChipGap;
      }
      sx+=groupW[g];
      if(gapIndex<gapCount)
      {
         int between=settingGap+extra/gapCount+(gapIndex<extra%gapCount?1:0);
         UIBox("settingDivider"+IntegerToString(g),sx+between/2,cy,1,step-4,UI_BORDER,UI_BORDER);
         sx+=between;
      }
   }
   int rx=x+10;
   for(int c=0;c<7;c++)
   {
      int yy=readY;
      for(int i=0;i<3;i++)
      {
         string v=""; if(readingOK[i]) { if(c==0) v=tf[i]; else UIReadingField(readings[i],cols[c],v); }
         UIBox("readingBadge"+IntegerToString(i)+"_"+IntegerToString(c),rx,yy-2,UIWidth(v)+8,step,
               c<5 && v!=""?UIChipFill(v):UI_SURFACE,UI_SURFACE);
         yy+=readRows[i]*step;
      }
      rx+=readW[c];
   }
   int cardX[3],nextCardX=x;
   for(int i=0;i<3;i++)
   {
      string n=IntegerToString(i); cardX[i]=nextCardX; nextCardX+=cardW[i]+gap;
      color planBorder=plan[i].signal=="BUY"?UI_GREEN:(plan[i].signal=="SELL"?UI_RED:UI_BORDER);
      UIBox("card"+n,cardX[i],cardsY,cardW[i],cardH,UI_SURFACE,planBorder);
      UIBox("cardTF"+n,cardX[i]+6,cardsY+4,tfW-6,step,UI_BADGE,UI_BORDER);
      int sigX=cardX[i]+tfW+6,sigW=UIWidth(plan[i].signal)+10,styleW=UIWidth(plan[i].style)+10;
      UIBox("cardSignal"+n,sigX,cardsY+4,sigW,step,plan[i].signal=="NONE" || plan[i].signal=="WAIT"?UI_SURFACE:UIChipFill(plan[i].signal),UI_SURFACE);
      UIBox("cardStyle"+n,sigX+sigW+2,cardsY+4,styleW,step,plan[i].style==""?UI_SURFACE:UI_BADGE,UI_SURFACE);
      UIBox("cardVolume"+n,sigX+sigW+styleW+4,cardsY+4,UIWidth("VOL "+plan[i].volume)+10,step,plan[i].volume==""?UI_SURFACE:UI_BADGE,UI_SURFACE);
      int colX=cardX[i]+4;
      for(int c=0;c<4;c++)
      {
         int cw=c==3?cardX[i]+cardW[i]-4-colX:planCol[i][c];
         UIBox("cardCell"+n+"_"+IntegerToString(c),colX,cardsY+step+7,cw,(2+cashExtra)*step,UI_SURFACE,plan[i].entry==""?UI_SURFACE:UI_BORDER);
         colX+=cw;
      }
   }
   UIBox("diary",x+autoW+gap,bottomY,diaryW,bottomH,UI_SURFACE,UI_BORDER);
   int autoY=bottomY+4;
   for(int i=0;i<3;i++)
   {
      string n=IntegerToString(i),mode=UIAfter(UIPart(autos[i],1),"Auto: ");
      UIBox("autoRow"+n,x,autoY,autoW,autoRows[i]*step+4,UI_SURFACE,UI_BORDER);
      UIBox("autoTF"+n,x+5,autoY+2,tfW-5,step,UI_BADGE,UI_BORDER);
      UIBox("autoMode"+n,x+tfW+UIWidth("Auto")+10,autoY+2,UIWidth("OFF")+10,step,UIChipFill(mode),UI_BORDER);
      string direction="",style=""; bool trade=UIAutoTrade(autos[i],direction,style);
      int tradeW=UIWidth(direction)+10;
      UIBox("autoTrade"+n,x+autoLead,autoY+2,tradeW,step,trade?UIChipFill(direction):UI_SURFACE,UI_SURFACE);
      UIBox("autoStyle"+n,x+autoLead+tradeW+2,autoY+2,UIWidth(style)+10,step,trade?UI_BADGE:UI_SURFACE,UI_SURFACE);
      autoY+=autoRows[i]*step+4;
   }
   int dx=x+autoW+gap+10;
   UIBox("today",dx+tfW,bottomY+4,4*statW,step,UI_BADGE,UI_BORDER);
   UIBox("all",dx+tfW+4*statW,bottomY+4,4*statW,step,UI_BADGE,UI_BORDER);

   UIText("brandText",bx+5,y,"MT V1.00",UI_TITLE,UI_SIZE);
   UIText("symbol",bx+brandW+4,y,g_symbol,clrWhite,UI_SIZE+2);
   UIText("typeText",bx+brandW+symbolW+5,y,g_type,clrSilver,UI_SIZE);
   UIText("stateText",bx+brandW+symbolW+typeW+10,y,state,stateInk,UI_SIZE);
   UIText("bidText",quoteX+5,y,"Bid: "+bid,clrWhite,UI_SIZE);
   UIText("askText",quoteX+UIWidth("Bid: "+bid)+21,y,"Ask: "+ask,clrWhite,UI_SIZE);
   UIText("clock",quoteX+UIWidth("Bid: "+bid)+UIWidth("Ask: "+ask)+32,y,clock,clrWhite,UI_SIZE);
   UIWrapped("marketDetail",x,marketY,g_marketDetail,inner,step,clrSilver,"",g_uiMarketNotes);
   UIText("settingsTitle",x+10,settingsY+3,"SETTINGS",UI_MUTED,UI_SIZE);
   string settingsTip="Input settings only. Allow Against Trend controls alignment, not whether a timeframe is enabled. SL Placement OFF sends new orders without a broker stop loss. Other trading and broker rules still apply.";
   string trendTip="Trend to Follow is the selected input. TP % is each lane's historical percentile (1-100); INVALID uses original TP logic for that lane. Diary Details controls display only.";
   string timerTip="The daily timer uses the PC/VPS local clock and gates new entries, not open positions.";
   for(int g=0;g<9;g++)
   {
      int cy=settingsY+step+4+(g<5?0:step); string tip=g<5?settingsTip:(g==8?timerTip:trendTip);
      UIText("settingKey"+IntegerToString(g),settingX[g],cy,groups[g],clrSilver,settingSize,tip);
      for(int j=0;j<count[g];j++) { int k=start[g]+j; UIText("settingValue"+IntegerToString(k),badgeX[k]+settingBadgePad/2,cy,values[k],clrWhite,settingSize,tip); }
   }
   UIWrapped("timerDetail",x+10,settingsY+3*step+4,timerDetail?timer:"",inner-20,step,clrSilver,timerTip,g_uiTimerNotes);
   UIText("readTitle",x,readTitleY,"MARKET READINGS",UI_MUTED,UI_SIZE);
   UIText("planTitle",x,planTitleY,"TRADING PLANS",UI_MUTED,UI_SIZE);
   UIText("autoTitle",x,bottomTitleY,"AUTO EXECUTION",UI_MUTED,UI_SIZE);
   UIText("diaryTitle",x+autoW+gap,bottomTitleY,"TRADE STATISTICS",UI_MUTED,UI_SIZE);
   rx=x+14;
   for(int c=0;c<7;c++)
   {
      UIText("col"+IntegerToString(c),rx,readHeaderY,cols[c],UI_MUTED,UI_SIZE);
      int yy=readY;
      for(int i=0;i<3;i++)
      {
         string v=""; if(readingOK[i]) { if(c==0) v=tf[i]; else UIReadingField(readings[i],cols[c],v); }
         UIText("reading"+IntegerToString(i)+"_"+IntegerToString(c),rx,yy,v,UIValueColor(v),UI_SIZE);
         yy+=readRows[i]*step;
      }
      rx+=readW[c];
   }
   int yy=readY;
   string planTip="Frozen trading plan, not necessarily the broker order. If SL placement is off, the planned SL is a sizing reference, not a protective stop.";
   for(int i=0;i<3;i++)
   {
      string n=IntegerToString(i);
      UIWrapped("readFallback"+n+"_",x+10,yy,readingOK[i]?"":readings[i],inner-20,step,clrSilver,"",g_uiReadingNotes[i]); yy+=readRows[i]*step;
      UIText("cardTFText"+n,cardX[i]+10,cardsY+6,plan[i].recognized?tf[i]:"",clrWhite,UI_SIZE,planTip);
      bool idle=plan[i].signal=="NONE" || plan[i].signal=="WAIT";
      int sigX=cardX[i]+tfW+11;
      if(idle) sigX=cardX[i]+(cardW[i]-UIWidth(plan[i].signal,UI_SIZE+2))/2;
      int sigY=idle?cardsY+(cardH-step)/2:cardsY+6;
      UIText("cardSignalText"+n,sigX,sigY,plan[i].signal,UIValueColor(plan[i].signal),idle?UI_SIZE+2:UI_SIZE,planTip);
      int styleX=cardX[i]+tfW+6+UIWidth(plan[i].signal)+12;
      UIText("cardStyleText"+n,styleX+5,cardsY+6,plan[i].style,clrWhite,UI_SIZE,planTip);
      UIText("cardVolumeText"+n,styleX+UIWidth(plan[i].style)+17,cardsY+6,plan[i].volume==""?"":"VOL "+plan[i].volume,clrSilver,UI_SIZE,planTip);
      string data[4];
      data[0]=plan[i].entry; data[1]=plan[i].lot; data[2]=plan[i].sl; data[3]=plan[i].tp;
      int colX=cardX[i]+9;
      for(int c=0;c<4;c++)
      {
         string id=n+"_"+IntegerToString(c);
         UIText("planHeading"+id,colX,cardsY+step+9,plan[i].entry==""?"":planHead[c],UI_MUTED,UI_SIZE,planTip);
         UIText("planValue"+id,colX,cardsY+2*step+9,data[c],clrWhite,UI_SIZE,planTip);
         if(c==2 || c==3)
         {
            string money=c==2?plan[i].slCash:plan[i].tpCash;
            UIText("planMoney"+id,colX+UIWidth(data[c])+4,cardsY+2*step+9,inlineCash?money:"",c==2?clrTomato:clrLime,UI_SIZE-2,planTip);
            UIWrapped("planMoneyRows"+id+"_",colX,cardsY+3*step+9,inlineCash?"":money,planCol[i][c]-12,step,c==2?clrTomato:clrLime,planTip,g_uiCashRows[i][c-2],UI_SIZE-2);
         }
         colX+=planCol[i][c];
      }
      UIWrapped("planNote"+n+"_",cardX[i]+10,cardsY+(3+cashExtra)*step+9,plan[i].notes,cardW[i]-20,step,clrOrange,planTip,g_uiPlanNotes[i]);
   }
   autoY=bottomY+6;
   for(int i=0;i<3;i++)
   {
      string n=IntegerToString(i),tip=P4Tooltip(i),mode=UIPart(autos[i],1);
      bool normal=(UIPart(autos[i],0)==tf[i] && (mode=="Auto: ON" || mode=="Auto: OFF"));
      UIText("autoTFText"+n,x+9,autoY,normal?tf[i]:"",clrWhite,UI_SIZE,tip);
      UIText("autoKey"+n,x+tfW+2,autoY,normal?"Auto":"",clrSilver,UI_SIZE,tip);
      UIText("autoModeText"+n,x+tfW+UIWidth("Auto")+15,autoY,normal?UIAfter(mode,"Auto: "):"",clrWhite,UI_SIZE,tip);
      string direction="",style=""; bool trade=normal && UIAutoTrade(autos[i],direction,style);
      UIText("autoTradeText"+n,x+autoLead+5,autoY,trade?direction:"",UIValueColor(direction),UI_SIZE,tip);
      UIText("autoStyleText"+n,x+autoLead+UIWidth(direction)+17,autoY,trade?style:"",clrWhite,UI_SIZE,tip);
      UIAutoFlow(autos[i],i,x,autoY,autoW,autoLead,step,true,tip);
      autoY+=autoRows[i]*step+4;
   }
   UIText("statsTFHeader",dx,bottomY+6,"TF",UI_MUTED,UI_SIZE);
   UIText("todayHeader",dx+tfW+5,bottomY+6,"TODAY",UI_MUTED,UI_SIZE);
   UIText("allHeader",dx+tfW+4*statW+5,bottomY+6,"ALL",UI_MUTED,UI_SIZE);
   string statHeads[4]={"S","W","L","BE"};
   for(int j=0;j<4;j++)
   {
      UIText("todayCol"+IntegerToString(j),dx+tfW+j*statW,bottomY+step+6,statHeads[j],UI_MUTED,UI_SIZE);
      UIText("allCol"+IntegerToString(j),dx+tfW+(j+4)*statW,bottomY+step+6,statHeads[j],UI_MUTED,UI_SIZE);
   }
   int statY=bottomY+2*step+6;
   for(int i=0;i<3;i++)
   {
      string n=IntegerToString(i);
      UIText("statsTF"+n,dx,statY,statsOK[i]?tf[i]:"",clrWhite,UI_SIZE);
      for(int j=0;j<4;j++)
      {
         UIText("todayVal"+n+"_"+IntegerToString(j),dx+tfW+j*statW,statY,statsOK[i]?UIWord(today[i],1+j*2):"",clrSilver,UI_SIZE);
         UIText("allVal"+n+"_"+IntegerToString(j),dx+tfW+(j+4)*statW,statY,statsOK[i]?UIWord(all[i],1+j*2):"",clrSilver,UI_SIZE);
      }
      UIWrapped("diaryFallback"+n+"_",dx,statY,statsOK[i]?"":diaries[i],diaryW-20,step,clrSilver,"",g_uiDiaryNotes[i]);
      statY+=diaryRows[i]*step;
   }
   for(int i=0;i<3;i++)
   {
      UIWrapped("diaryDetail"+IntegerToString(i)+"_",dx,statY,InpShowDetails?details[i]:"",diaryW-20,step,clrSilver,"",g_uiDetails[i]);
      if(InpShowDetails) statY+=UIWrappedRows(details[i],diaryW-20)*step;
   }
   ChartRedraw();
}
void BuildPanel() { g_uiBuilt=true; UpdatePanel(); }
#endif
