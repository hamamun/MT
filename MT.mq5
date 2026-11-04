//+------------------------------------------------------------------+
//| MT.mq5 - Master Trade                                            |
//|                                                                  |
//| Phases 1-4: readings, plans, diary and optional auto trading.    |
//|                                                                  |
//| A market-state and timeframe panel drawn with chart objects.     |
//| The panel shows the chart symbol, its broker-published type,     |
//| whether the market is open, and either the server clock (open)   |
//| or the next opening time from the broker's session table         |
//| (closed).                                                        |
//|                                                                  |
//| The panel measures its header, three timeframe lanes and any     |
//| market detail. Unsupported charts show a two-line notice.        |
//|                                                                  |
//| Appearance follows SimpleEA/SimpleAdvisor.mq5: Consolas 10 pt,   |
//| background C'48,48,48', title 11 pt in clrWhite.                  |
//|                                                                  |
//| Auto Trading defaults off. Diary outcomes use observed quotes.    |
//+------------------------------------------------------------------+
#property copyright "MT"
#property version   "1.00"
#property description "MT - Master Trade. Plans, observed-price diary and optional auto trading."

//---
//  Prefix for every object this EA creates. Keeping it in one place
//  means a rebuild or a deinit can remove exactly this panel and
//  nothing else on the chart.
//---
#define OBJ_PREFIX   "MT_"
#define PANEL_TITLE  "MT V1.00"
#define MAX_SESSIONS 32

// Fixed appearance; plan and auto-trading inputs are declared in their runtime includes.
#define PANEL_FONT "Consolas"
#define PANEL_FONT_SIZE 10
#define PANEL_X 12
#define PANEL_Y 24
// Keep each chart label below the observed 63-character text limit.
#define LABEL_CHUNK 48
#define HEADER_ROWS 3
#define PANEL_BG C'48,48,48'
#define PANEL_TITLE_COLOR clrWhite
#define STALE_SECONDS 1800
#define SESSION_REFRESH_SECONDS 300

//---
//  One broker session. Times are seconds after server midnight; the
//  date returned by SymbolInfoSessionTrade is ignored, as documented.
//---
struct SessionSlot
{
   int fromSec;   // session start, seconds after 00:00
   int toSec;     // session end, seconds after 00:00
};

//---
//  Refresh the weekly session table periodically and on date changes.
//  The cap is 32 sessions per day.
//---
SessionSlot g_sessions[7][MAX_SESSIONS];
int         g_sessionCount[7];
datetime    g_sessionsDay = 0;
datetime    g_lastSessionScan = 0;
bool        g_hasSessions = false;

string g_symbol = "";
string g_type = "";
datetime g_nextOpen = 0;
bool g_built = false;
// TimeCurrent is broker-generated; elapsed monotonic time fills the gaps.
datetime g_clockQuote = 0;
datetime g_lastObservedQuote = 0;
ulong g_clockMillis = 0;
bool g_clockAnchored = false;

enum MARKET_STATE { MARKET_OPEN, MARKET_CLOSED, MARKET_STALE,
                    MARKET_UNKNOWN, MARKET_OFFLINE, MARKET_UNAVAILABLE };
MARKET_STATE g_marketState = MARKET_UNKNOWN;
string g_marketDetail = "";


// Phase 2: three independent closed-bar lanes; no trading functions.
#define P2_WARMUP 700
#define P2_START_HISTORY 12000
#define P2_MIN_RUNS 20
#define P2_WAIT 99
struct P2Countdown
{
   bool loaded;
   bool valid;
   int label;
   int age;
   int remaining;
   datetime anchor;
};
struct P2Lane
{
   string line;
   datetime lastBar;
   datetime attemptedBar;
   ulong lastAttempt;
   int requested;
   int lastGoodRequest;
   bool retry;
   P2Countdown pt;
   P2Countdown score;
};
P2Lane g_p2[3];

#include "MT_PlanRuntime.mqh"
#include "MT_DiaryRuntime.mqh"
#include "MT_AutoRuntime.mqh"

//+------------------------------------------------------------------+
//| Expert initialization: build the panel and start the 1 s timer.  |
//+------------------------------------------------------------------+
int OnInit()
{
   Rebuild();
   if(!EventSetTimer(1))
   {
      Print("MT: could not start timer: ", GetLastError());
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization: stop the timer and remove the panel.    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   P3DiaryClose();
   P4Close();
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| A tick is a chance to refresh the state immediately. The timer   |
//| keeps the clock moving when no ticks arrive.                     |
//+------------------------------------------------------------------+
void OnTick()
{
   SyncClock(true);
   if(ChartSupported())
   {
      UpdateState(ServerNow());
      P3CaptureQuotes();
      P2Update();
      P3FreezePlans();
      P3DiaryTick();
      UpdateState(ServerNow());
      P4Process(true);
   }
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| One-second heartbeat: the clock must tick even on a quiet market.|
//+------------------------------------------------------------------+
void OnTimer()
{
   P3DiaryMonitor();
   if(ChartSupported()) UpdateState(ServerNow());
   P4Process(false);
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| A symbol change rebuilds the panel for the new chart symbol.     |
//| MT5 normally reinitializes the EA on symbol/timeframe changes.   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      if(_Symbol != g_symbol)
         Rebuild();
   }
}

//+------------------------------------------------------------------+
//| Rebuild everything from the current chart symbol.                |
//+------------------------------------------------------------------+
void Rebuild()
{
   ObjectsDeleteAll(0, OBJ_PREFIX);
   g_built = false;

   g_symbol = _Symbol;
   g_type   = ClassifySymbol(g_symbol);
   P2Reset();
   P3Reset();
   P3ResetSnapshots();
   if(ChartSupported()) { P3DiaryInit(); P4Init(); }
   else { P3DiaryClose(); P4Close(); }

   ScanSessions();
   BuildPanel();

}

//+------------------------------------------------------------------+
//| Broker-anchored clock; see limitations in README.md.               |
//+------------------------------------------------------------------+
// OnTick's TimeCurrent is the chart symbol's broker-stamped tick.
// On a timer it is the last quote of any Market Watch symbol. Never
// re-anchor to the same cached timestamp. In the tester, use simulated
// time instead of elapsed real time.
void SyncClock(bool chartTick)
{
   datetime quote = TimeCurrent();
   if(quote <= 0) return;
   if(chartTick || (g_lastObservedQuote > 0 && quote != g_lastObservedQuote))
   {
      g_clockQuote = quote;
      g_clockMillis = GetTickCount64();
      g_clockAnchored = true;
   }
   g_lastObservedQuote = quote;
}

datetime ServerNow()
{
   if(MQLInfoInteger(MQL_TESTER)) return(TimeCurrent());
   SyncClock(false);
   if(g_clockAnchored)
      return(g_clockQuote + (datetime)((GetTickCount64() - g_clockMillis) / 1000));
   // Before a fresh tick has been observed only MT5's PC-derived
   // estimate is available; it is explicitly described as estimated.
   return(TimeTradeServer());
}

//+------------------------------------------------------------------+
//| Format a server timestamp as yyyy.mm.dd hh:mm:ss. Fixed width.   |
//+------------------------------------------------------------------+
string FormatClock(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return(StringFormat("%04d.%02d.%02d %02d:%02d:%02d",
                       dt.year, dt.mon, dt.day,
                       dt.hour, dt.min, dt.sec));
}

//+------------------------------------------------------------------+
//| Create or update a hidden, non-selectable text label.            |
//+------------------------------------------------------------------+
void MakeLabel(string name, int x, int y, string text, color clr,
               int size, bool rightAnchor)
{
   string full = OBJ_PREFIX + name;
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_LABEL, 0, 0, 0);

   if(size < 6)
      size = 6;

   int anchor = rightAnchor ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER;

   ObjectSetInteger(0, full, OBJPROP_CORNER,     (long)CORNER_LEFT_UPPER);
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, full, OBJPROP_COLOR,      (long)clr);
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE,   size);
   ObjectSetString (0, full, OBJPROP_FONT,       PANEL_FONT);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, full, OBJPROP_BACK,       false);
   ObjectSetInteger(0, full, OBJPROP_ANCHOR,     anchor);
   ObjectSetString (0, full, OBJPROP_TEXT,       text);
}

//+------------------------------------------------------------------+
//| Create or update the panel background rectangle.                 |
//+------------------------------------------------------------------+
void MakeRect(string name, int x, int y, int w, int h, color bg, color border)
{
   string full = OBJ_PREFIX + name;
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_CORNER,      (long)CORNER_LEFT_UPPER);
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, full, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, full, OBJPROP_BGCOLOR,     (long)bg);
   ObjectSetInteger(0, full, OBJPROP_BORDER_TYPE, (long)BORDER_FLAT);
   ObjectSetInteger(0, full, OBJPROP_COLOR,       (long)border);
   ObjectSetInteger(0, full, OBJPROP_WIDTH,       1);
   ObjectSetInteger(0, full, OBJPROP_BACK,        false);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN,      true);
}

//+------------------------------------------------------------------+
//| Scan the broker's weekly trade-session table for the chart       |
//| symbol. The table is in server time; the date part of the        |
//| returned values is ignored, as the MQL5 documentation says.      |
//|                                                                  |
//| A 00:00-00:00 session is treated as a full-day session. Some     |
//| brokers use that pair for a 24-hour market. A zero-length        |
//| session with any other equal pair is ignored.                    |
//+------------------------------------------------------------------+
void ScanSessions()
{
   g_hasSessions = false;
   for(int d = 0; d < 7; d++)
   {
      g_sessionCount[d] = 0;
      uint k = 0;
      datetime from, to;
      while(k < MAX_SESSIONS &&
            SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)d, k, from, to))
      {
         int f = (int)((long)from % 86400);
         int t = (int)((long)to   % 86400);
         if(f == 0 && t == 0)
            t = 86400;                 // 00:00-00:00 => full day
         if(f != t)
         {
            g_sessions[d][g_sessionCount[d]].fromSec = f;
            g_sessions[d][g_sessionCount[d]].toSec   = t;
            g_sessionCount[d]++;
            g_hasSessions = true;
         }
         k++;
      }
   }

   datetime now = ServerNow();
   g_sessionsDay = now - (now % 86400);
   g_lastSessionScan = now;
}

//+------------------------------------------------------------------+
//| True when the server clock is inside one of today's sessions,    |
//| or inside an overnight session that began yesterday.             |
//|                                                                  |
//| With no published table this returns false; the caller handles   |
//| that separately rather than claiming a scheduled closure.        |
//+------------------------------------------------------------------+
bool IsMarketOpen(datetime now)
{
   if(!g_hasSessions)
      return(false);

   MqlDateTime dt;
   TimeToStruct(now, dt);
   int today = dt.day_of_week;
   int sec   = dt.hour * 3600 + dt.min * 60 + dt.sec;

   for(int k = 0; k < g_sessionCount[today]; k++)
   {
      int f = g_sessions[today][k].fromSec;
      int t = g_sessions[today][k].toSec;
      if(f < t)
      {
         if(sec >= f && sec < t)
            return(true);
      }
      else if(f > t)
      {
         if(sec >= f)
            return(true);
      }
   }

   int yesterday = (today + 6) % 7;
   for(int k = 0; k < g_sessionCount[yesterday]; k++)
   {
      int f = g_sessions[yesterday][k].fromSec;
      int t = g_sessions[yesterday][k].toSec;
      if(f > t && sec < t)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Days in a month, with leap years. Used by AddDays so the next    |
//| opening search is correct across month and year boundaries.      |
//+------------------------------------------------------------------+
int DaysInMonth(int mon, int year)
{
   int days[] = {31,28,31,30,31,30,31,31,30,31,30,31};
   if(mon == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0))
      return(29);
   return(days[mon - 1]);
}

//+------------------------------------------------------------------+
//| Add a whole number of calendar days to a server timestamp.       |
//+------------------------------------------------------------------+
datetime AddDays(datetime t, int days)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.day += days;

   while(dt.day > DaysInMonth(dt.mon, dt.year))
   {
      dt.day -= DaysInMonth(dt.mon, dt.year);
      dt.mon++;
      if(dt.mon > 12)
      {
         dt.mon  = 1;
         dt.year++;
      }
   }
   while(dt.day < 1)
   {
      dt.mon--;
      if(dt.mon < 1)
      {
         dt.mon  = 12;
         dt.year--;
      }
      dt.day += DaysInMonth(dt.mon, dt.year);
   }

   return(StructToTime(dt));
}

//+------------------------------------------------------------------+
//| Earliest session start at or after now, in server time.          |
//| Returns 0 when the broker publishes no table or no future        |
//| session is found in the next eight days.                         |
//+------------------------------------------------------------------+
datetime NextOpening(datetime now)
{
   if(!g_hasSessions)
      return(0);

   MqlDateTime dt;
   TimeToStruct(now, dt);
   int today = dt.day_of_week;

   MqlDateTime base = dt;
   base.hour = 0;
   base.min  = 0;
   base.sec  = 0;
   datetime todayStart = StructToTime(base);

   datetime best = 0;
   for(int offset = 0; offset <= 7; offset++)
   {
      int day           = (today + offset) % 7;
      datetime dayStart = AddDays(todayStart, offset);

      for(int k = 0; k < g_sessionCount[day]; k++)
      {
         int f = g_sessions[day][k].fromSec;
         int t = g_sessions[day][k].toSec;
         if(f == t)
            continue;

         datetime candidate = dayStart + (datetime)f;
         if(candidate >= now && (best == 0 || candidate < best))
            best = candidate;
      }
   }

   return(best);
}

//+------------------------------------------------------------------+
//| Refresh the cached state and the next opening time.              |
//+------------------------------------------------------------------+
string WeekdayShort(datetime t)
{
   MqlDateTime dt;
   if(!TimeToStruct(t, dt)) return("?");
   string days[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
   return(days[dt.day_of_week]);
}

string HumanDelta(datetime now, datetime next)
{
   long seconds = (long)(next - now);
   if(seconds < 0) seconds = 0;
   long days = seconds / 86400;
   long hours = (seconds % 86400) / 3600;
   long minutes = (seconds % 3600) / 60;
   if(days > 0) return(StringFormat("%dd %dh %dm", (int)days, (int)hours, (int)minutes));
   if(hours > 0) return(StringFormat("%dh %dm", (int)hours, (int)minutes));
   return(StringFormat("%dm %ds", (int)minutes, (int)(seconds % 60)));
}

void UpdateState(datetime now)
{
   g_nextOpen = 0;
   g_marketDetail = "";
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) && !MQLInfoInteger(MQL_TESTER))
   {
      g_marketState = MARKET_OFFLINE;
      g_marketDetail = "terminal is not connected - no quotes";
      return;
   }
   if(now <= 0)
   {
      g_marketState = MARKET_UNKNOWN;
      g_marketDetail = "server time unavailable";
      return;
   }
   datetime todayStart = now - (now % 86400);
   if(todayStart != g_sessionsDay || now < g_lastSessionScan ||
      now - g_lastSessionScan >= SESSION_REFRESH_SECONDS)
      ScanSessions();

   long tradeMode = 0;
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, tradeMode) &&
      tradeMode == SYMBOL_TRADE_MODE_DISABLED)
   {
      g_marketState = MARKET_UNAVAILABLE;
      g_marketDetail = "the broker has disabled this symbol";
      return;
   }

   MqlTick tick;
   bool hasQuote = SymbolInfoTick(_Symbol, tick) && tick.time > 0;
   long age = hasQuote ? (long)(now - tick.time) : -1;
   bool fresh = hasQuote && age >= 0 && age <= STALE_SECONDS;
   if(g_hasSessions && !IsMarketOpen(now))
   {
      g_marketState = MARKET_CLOSED;
      g_nextOpen = NextOpening(now);
      if(g_nextOpen > 0)
         g_marketDetail = "MARKET CLOSED - next open " + WeekdayShort(g_nextOpen) + " " +
                          FormatClock(g_nextOpen) + " server (in " + HumanDelta(now, g_nextOpen) + ")";
      else
         g_marketDetail = "MARKET CLOSED - no scheduled open found in the published table";
      return;
   }
   if(!fresh)
   {
      g_marketState = g_hasSessions ? MARKET_STALE : MARKET_UNKNOWN;
      if(!hasQuote) g_marketDetail = g_hasSessions ? "no quote available" : "no session table; Open at --; no quote available";
      else if(age < 0) g_marketDetail = g_hasSessions ? "quote time is ahead of estimated server clock" : "no session table; Open at --; quote time ahead of server estimate";
      else g_marketDetail = StringFormat("%s; last quote %d min old",
                                         g_hasSessions ? "session open" : "no session table; Open at --",
                                         (int)(age / 60));
      return;
   }
   // Row 2 is reserved for future content during normal market hours.
   g_marketState = MARKET_OPEN;
}

// TextGetSize uses the same logical point size as chart labels. The
// fallback errs generously if MT5 cannot measure the requested font.
void Measure(const string text, const int size, int &width, int &height)
{
   uint w = 0, h = 0;
   if(TextSetFont(PANEL_FONT, -10 * size, 0) && TextGetSize(text, w, h) && h > 0)
   {
      width = (int)w;
      height = (int)h;
      return;
   }
   int dpi = (int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi < 72) dpi = 96;
   height = (int)MathCeil(size * (double)dpi / 72.0 * 1.5);
   width = StringLen(text) * height;
}

// Measure and draw using the same short segments. A single long OBJ_LABEL
// can be truncated by MetaTrader even if the background is wide enough.
void MeasureLine(const string text, const int size, int &width, int &height)
{
   width = 0;
   height = 0;
   int len = StringLen(text);
   for(int offset = 0; offset < len; offset += LABEL_CHUNK)
   {
      string part = StringSubstr(text, offset, LABEL_CHUNK);
      int w, h;
      Measure(part, size, w, h);
      width += w;
      height = (int)MathMax(height, h);
   }
   if(height == 0)
   {
      int unused;
      Measure(" ", size, unused, height);
   }
}

// An empty string removes all prior segments. Removing surplus segments
// also prevents stale characters after a long value becomes shorter.
void MakeTextLine(string name, int x, int y, string text, color clr, int size, string tooltip="")
{
   int len = StringLen(text);
   int segment = 0;
   for(int offset = 0; offset < len; offset += LABEL_CHUNK)
   {
      string part = StringSubstr(text, offset, LABEL_CHUNK);
      string segmentName = name + "_" + IntegerToString(segment);
      MakeLabel(segmentName, x, y, part, clr, size, false);
      if(tooltip!="") ObjectSetString(0,OBJ_PREFIX+segmentName,OBJPROP_TOOLTIP,tooltip);
      int w, h;
      Measure(part, size, w, h);
      x += w;
      segment++;
   }
   while(true)
   {
      string full = OBJ_PREFIX + name + "_" + IntegerToString(segment);
      if(ObjectFind(0, full) < 0) break;
      ObjectDelete(0, full);
      segment++;
   }
}

bool ChartSupported()
{
   return(_Period == PERIOD_M5 || _Period == PERIOD_M15 || _Period == PERIOD_M30);
}

void BuildPanel()
{
   g_built = true;
   UpdatePanel();
}

void UpdatePanel()
{
   if(!g_built) return;
   datetime now = ServerNow();
   UpdateState(now);
   bool supported = ChartSupported();
   if(supported) P2Update();
   string plans[3], autoLines[3], diaryLines[3], diaryDetails[3];
   string quoteLine = "";
   if(supported)
   {
      for(int i=0;i<3;i++)
      {
         plans[i]=P3PlanLine(i);
         autoLines[i]=P4Line(i);
         diaryLines[i]=P3DiarySummary(i,now);
         diaryDetails[i]=InpShowDetails ? P3DiaryDetail(i) : "";
      }
      MqlTick quote;
      if(SymbolInfoTick(_Symbol,quote) && quote.bid>0 && quote.ask>=quote.bid)
      {
         int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         quoteLine="Bid: "+DoubleToString(quote.bid,dg)+" | Ask: "+DoubleToString(quote.ask,dg);
      }
      else quoteLine="Bid: -- | Ask: --";
   }
   string state = "";
   string last = "";
   color stateColor = clrWhite;
   switch(g_marketState)
   {
      case MARKET_OPEN: state = "OPEN"; stateColor = clrLime;
         last = now > 0 ? FormatClock(now) : "--"; break;
      case MARKET_CLOSED: state = "close"; stateColor = clrTomato;
         last = g_nextOpen > 0 ? "Open at " + FormatClock(g_nextOpen) : "Open at --"; break;
      case MARKET_STALE: state = "OPEN - STALE QUOTE"; stateColor = clrOrange; break;
      case MARKET_OFFLINE: state = "DISCONNECTED"; stateColor = clrTomato; break;
      case MARKET_UNAVAILABLE: state = "TRADING UNAVAILABLE"; stateColor = clrOrange; break;
      default: state = "MARKET STATUS UNKNOWN"; stateColor = clrOrange; break;
   }

   string prefix = " | " + g_symbol + " | " + g_type + " | ";
   string suffix = last == "" ? "" : " | " + last;
   if(!supported)
   {
      string tf = EnumToString((ENUM_TIMEFRAMES)_Period);
      if(StringFind(tf, "PERIOD_") == 0) tf = StringSubstr(tf, 7);
      prefix = " | " + g_symbol + " | " + tf;
      state = "";
      suffix = "";
   }
   string detail = supported ? g_marketDetail : "Incompatible chart. Switch to M5/M15/M30.";
   int titleW, titleH, prefixW, prefixH, stateW, stateH, suffixW, suffixH, detailW, detailH;
   MeasureLine(PANEL_TITLE, PANEL_FONT_SIZE + 1, titleW, titleH);
   MeasureLine(prefix, PANEL_FONT_SIZE, prefixW, prefixH);
   MeasureLine(state, PANEL_FONT_SIZE, stateW, stateH);
   MeasureLine(suffix, PANEL_FONT_SIZE, suffixW, suffixH);
   MeasureLine(detail, supported ? PANEL_FONT_SIZE : PANEL_FONT_SIZE + 1, detailW, detailH);
   int pad = 10;
   int headerH = (int)MathMax(MathMax(titleH, prefixH), MathMax(stateH, suffixH));
   int headerW = titleW + prefixW + stateW + suffixW;
   int width = (int)MathMax(headerW, detail == "" ? 0 : detailW) + 2 * pad + 4;
   int rowH = (int)MathMax(headerH, detailH) + 6;
   if(supported)
   {
      for(int i = 0; i < 3; i++)
      {
         int rw, rh;
         MeasureLine(P2Line(i), PANEL_FONT_SIZE, rw, rh);
         width = (int)MathMax(width, rw + 2 * pad + 4);
         rowH = (int)MathMax(rowH, rh + 6);
         MeasureLine(plans[i], PANEL_FONT_SIZE, rw, rh);
         width = (int)MathMax(width, rw + 2 * pad + 4);
         rowH = (int)MathMax(rowH, rh + 6);
         MeasureLine(autoLines[i],PANEL_FONT_SIZE,rw,rh);
         width=(int)MathMax(width,rw+2*pad+4); rowH=(int)MathMax(rowH,rh+6);
         MeasureLine(diaryLines[i],PANEL_FONT_SIZE,rw,rh);
         width=(int)MathMax(width,rw+2*pad+4); rowH=(int)MathMax(rowH,rh+6);
         if(InpShowDetails)
         {
            MeasureLine(diaryDetails[i],PANEL_FONT_SIZE,rw,rh);
            width=(int)MathMax(width,rw+2*pad+4); rowH=(int)MathMax(rowH,rh+6);
         }
      }
      int qw,qh; MeasureLine(quoteLine,PANEL_FONT_SIZE,qw,qh);
      width=(int)MathMax(width,qw+2*pad+4); rowH=(int)MathMax(rowH,qh+6);
   }
   // Supported charts reserve three header rows, then the three lanes.
   // On a closed or abnormal market row 2 carries the market detail.
   int height = 2 * pad + (supported ? (HEADER_ROWS + 13 + (InpShowDetails ? 3 : 0)) : 2) * rowH;

   MakeRect("bg", PANEL_X, PANEL_Y, width, height, PANEL_BG, clrDimGray);
   int x = PANEL_X + pad;
   int y = PANEL_Y + pad;
   MakeTextLine("title", x, y, PANEL_TITLE, PANEL_TITLE_COLOR, PANEL_FONT_SIZE + 1);
   x += titleW;
   MakeTextLine("prefix", x, y, prefix, clrSilver, PANEL_FONT_SIZE);
   x += prefixW;
   MakeTextLine("state", x, y, state, stateColor, PANEL_FONT_SIZE);
   x += stateW;
   MakeTextLine("suffix", x, y, suffix, clrWhite, PANEL_FONT_SIZE);
   MakeTextLine("detail", PANEL_X + pad, y + rowH, detail,
                supported ? clrSilver : clrTomato,
                supported ? PANEL_FONT_SIZE : PANEL_FONT_SIZE + 1);
   for(int i = 0; i < 3; i++)
   {
      string name = "lane" + IntegerToString(i);
      MakeTextLine(name, PANEL_X + pad, y + rowH * (HEADER_ROWS + i),
                   supported ? P2Line(i) : "", clrSilver, PANEL_FONT_SIZE);
   }
   for(int i=0;i<3;i++)
      MakeTextLine("plan"+IntegerToString(i),PANEL_X+pad,y+rowH*(HEADER_ROWS+3+i),
                   supported?plans[i]:"",clrSilver,PANEL_FONT_SIZE);
   MakeTextLine("quotes",PANEL_X+pad,y+rowH*(HEADER_ROWS+6),supported?quoteLine:"",clrSilver,PANEL_FONT_SIZE);
   for(int i=0;i<3;i++)
   {
      MakeTextLine("auto"+IntegerToString(i),PANEL_X+pad,y+rowH*(HEADER_ROWS+7+i),
                   supported?autoLines[i]:"",clrSilver,PANEL_FONT_SIZE,supported?P4Tooltip(i):"");
      MakeTextLine("diary"+IntegerToString(i),PANEL_X+pad,y+rowH*(HEADER_ROWS+10+i),
                   supported?diaryLines[i]:"",clrSilver,PANEL_FONT_SIZE);
      MakeTextLine("history"+IntegerToString(i),PANEL_X+pad,y+rowH*(HEADER_ROWS+13+i),
                   supported && InpShowDetails?diaryDetails[i]:"",clrSilver,PANEL_FONT_SIZE);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Classification helpers.                                          |
//+------------------------------------------------------------------+
string Upper(const string &text)
{
   string result = text;
   if(!StringToUpper(result))
      return(text);
   return(result);
}

//+------------------------------------------------------------------+
bool InList(const string &text, const string &list[])
{
   for(int i = 0; i < ArraySize(list); i++)
      if(StringFind(text, list[i]) >= 0)
         return(true);
   return(false);
}

//+------------------------------------------------------------------+
bool StartsWithAny(const string &text, const string &list[])
{
   for(int i = 0; i < ArraySize(list); i++)
      if(StringFind(text, list[i]) == 0)
         return(true);
   return(false);
}

//+------------------------------------------------------------------+
bool EqualsAny(const string &text, const string &list[])
{
   for(int i = 0; i < ArraySize(list); i++)
      if(text == list[i])
         return(true);
   return(false);
}

//+------------------------------------------------------------------+
//| Remove a broker suffix such as "m", ".raw", ".ecn" or ".pro" so   |
//| the classification sees the underlying symbol. The display still |
//| uses the broker's own spelling.                                  |
//+------------------------------------------------------------------+
string NormalizeSymbol(const string &symbol)
{
   string s = Upper(symbol);
   string suffixes[] = {".CASH", ".SPOT", ".RAW", ".ECN", ".PRO", ".STD",
                        ".M", ".F", ".Z", ".J"};
   for(int i = 0; i < ArraySize(suffixes); i++)
   {
      int sl = StringLen(suffixes[i]);
      if(StringLen(s) > sl && StringSubstr(s, StringLen(s) - sl) == suffixes[i])
         return(StringSubstr(s, 0, StringLen(s) - sl));
   }
   // Preserve ordinary tickers ending in M/F/Z/J; only strip the common
   // lowercase m suffix from a six-character instrument pair.
   if(StringLen(symbol) == 7 && StringSubstr(symbol, 6, 1) == "m")
      return(StringSubstr(s, 0, 6));
   return(s);
}

//+------------------------------------------------------------------+
//| Best-effort symbol type, in the words the specification uses:    |
//| Forex / Metal / Index / Energy / Crypto / Stock / Other.         |
//|                                                                  |
//| Broker metadata (sector, industry, category, path, description)  |
//| is tried first, then the symbol name, then the calculation mode. |
//| The label is informative; it never blocks anything.              |
//+------------------------------------------------------------------+
string ClassifySymbol(const string &symbol)
{
   string sym      = NormalizeSymbol(symbol);
   string desc     = Upper(SymbolInfoString(symbol, SYMBOL_DESCRIPTION));
   string path     = Upper(SymbolInfoString(symbol, SYMBOL_PATH));
   string sector   = Upper(SymbolInfoString(symbol, SYMBOL_SECTOR_NAME));
   string industry = Upper(SymbolInfoString(symbol, SYMBOL_INDUSTRY_NAME));
   string category = Upper(SymbolInfoString(symbol, SYMBOL_CATEGORY));
   string meta     = sector + " " + industry + " " + category + " " + path + " " + desc;
   int    calcMode = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);

   // Crypto first: a crypto pair can otherwise look like a 6-letter
   // forex pair or a CFD.
   string cryptoKeywords[] = {"CRYPTO", "DIGITAL", "BITCOIN", "ETHEREUM", "CRYPTOCURRENCY"};
   string cryptoPrefixes[] = {"BTC", "ETH", "XRP", "LTC", "BCH", "ADA", "DOT",
                              "SOL", "DOGE", "TRX", "XLM", "LINK", "UNI", "AVAX",
                              "MATIC", "ATOM", "ALGO", "XMR", "ZEC", "DASH", "EOS",
                              "XTZ", "FIL", "AAVE", "SNX", "YFI", "SHIB", "PEPE",
                              "TON", "NEAR", "APT", "ARB", "SUI", "SEI",
                              "TIA", "INJ", "RUNE", "KAS", "IMX", "GRT", "MKR",
                              "CRV", "SUSHI", "1INCH", "ENJ", "MANA", "SAND",
                              "GALA", "THETA", "FTM", "HBAR", "ICP", "ETC",
                              "USDT", "USDC", "DAI", "BUSD", "TUSD", "FDUSD"};
   if(InList(meta, cryptoKeywords) || EqualsAny(sym, cryptoPrefixes) ||
      (StartsWithAny(sym, cryptoPrefixes) &&
       (StringFind(sym, "USD") > 0 || StringFind(sym, "EUR") > 0 || StringFind(sym, "BTC") > 0)))
      return("Crypto");

   // Energy before metal: "Commodities" covers both, and the
   // description or industry separates them.
   string energyKeywords[] = {"ENERGY", "CRUDE", "BRENT", "NATURAL GAS", "OIL", "GAS"};
   string energyTokens[]   = {"OIL", "CRUDE", "BRENT", "WTI", "NATGAS", "NATURALGAS",
                              "XTI", "XBR", "XNG", "USOIL", "UKOIL", "NG", "CL", "HO", "RB"};
   if(InList(meta, energyKeywords) || EqualsAny(sym, energyTokens) ||
      (StartsWithAny(sym, energyTokens) && StringLen(sym) > 3 &&
       (StringFind(sym, "USD") >= 0 || StringFind(sym, "EUR") >= 0)))
      return("Energy");

   string metalKeywords[] = {"PRECIOUS METAL", "METAL", "GOLD", "SILVER", "PLATINUM",
                             "PALLADIUM", "COPPER"};
   string metalPrefixes[] = {"XAU", "XAG", "XPT", "XPD", "XCU", "GOLD", "SILVER",
                             "PLATINUM", "PALLADIUM", "COPPER"};
   if(InList(meta, metalKeywords) || StartsWithAny(sym, metalPrefixes))
      return("Metal");

   string indexKeywords[] = {"INDEX", "INDICES", "DOW", "NASDAQ", "S&P", "FTSE", "NIKKEI"};
   string indexTokens[]   = {"US30", "US500", "NAS100", "NDX", "SPX", "SPX500",
                             "GER40", "DE40", "UK100", "FTSE", "JP225", "NIKKEI",
                             "HK50", "AUS200", "FRA40", "EU50", "VIX", "US2000",
                             "US1000", "DOW", "NASDAQ", "S&P", "DJI", "DJIA"};
   if(InList(meta, indexKeywords) || InList(sym, indexTokens) ||
      calcMode == (int)SYMBOL_CALC_MODE_CFDINDEX)
      return("Index");

   string stockKeywords[] = {"STOCK", "SHARE", "EQUITY", "INC.", "LTD", "CORP",
                             "PLC", "COMPANY"};
   string stockTokens[]   = {"AAPL", "MSFT", "GOOGL", "GOOG", "AMZN", "META",
                             "TSLA", "NVDA", "AMD", "INTC", "JPM", "BAC", "WFC",
                             "GS", "MS", "XOM", "CVX", "JNJ", "PFE", "KO", "PEP",
                             "WMT", "COST", "HD", "LOW", "MCD", "NKE", "SBUX",
                             "DIS", "BA", "CAT", "GE", "GM", "VZ",
                             "TMO", "ABT", "DHR", "WBA", "CVS", "UNH", "HON",
                             "UPS", "FDX", "LMT", "RTX", "NOC", "GD",
                             "A", "C", "D", "E", "F", "G", "H", "I", "J", "K",
                             "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
                             "V", "W", "X", "Y", "Z"};
   if(InList(meta, stockKeywords) || EqualsAny(sym, stockTokens) ||
      calcMode == (int)SYMBOL_CALC_MODE_EXCH_STOCKS ||
      calcMode == (int)SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX)
      return("Stock");

   string forexKeywords[] = {"FOREX", "CURRENCY", "FX"};
   string fiatTokens[]    = {"USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD",
                             "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "TRY", "ZAR",
                             "MXN", "BRL", "CNH", "CNY", "HKD", "SGD", "INR", "KRW",
                             "THB", "IDR", "MYR", "PHP", "VND", "PKR", "BDT", "LKR", "NPR"};
   if(calcMode == (int)SYMBOL_CALC_MODE_FOREX ||
      calcMode == (int)SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)
      return("Forex");

   if(StringLen(sym) == 6 &&
      EqualsAny(StringSubstr(sym, 0, 3), fiatTokens) &&
      EqualsAny(StringSubstr(sym, 3, 3), fiatTokens))
      return("Forex");
   if(InList(meta, forexKeywords))
      return("Forex");

   return("Other");
}
//+------------------------------------------------------------------+


// Phase 2 numerical kernels adapted from SimpleEA commit 3e909f7384c179d5241228f40f40e09ab6ebf4ba.
// Automate normalized regression trend follows commit 4810fcd72098f8cd312880f178f33aa04dac673d.
void P2HighPass3(const double &price[], int period, double &hp[])
{
   int n = ArraySize(price);
   if(ArrayResize(hp, n) != n) return;
   ArrayInitialize(hp, 0.0);
   if(n < 3 || period < 2) return;

   double f  = 1.414 * M_PI / (double)period;
   double a1 = MathExp(-f);
   double c2 = 2.0 * a1 * MathCos(f);
   double c3 = -a1 * a1;
   double c1 = (1.0 + c2 - c3) / 4.0;

   for(int i = 2; i < n; i++)
      hp[i] = c1 * (price[i] - 2.0 * price[i - 1] + price[i - 2])
            + c2 * hp[i - 1]
            + c3 * hp[i - 2];
}

int P2ObservationCycleAt(const double &hp[], int last)
{
   if(last + 1 < 40) return(24);
   int first = (int)MathMax(2, last + 1 - 120);
   int cross[];
   int n = 0;
   for(int k = first + 1; k <= last; k++)
   {
      if((hp[k - 1] <= 0.0 && hp[k] > 0.0) ||
         (hp[k - 1] >= 0.0 && hp[k] < 0.0))
      {
         ArrayResize(cross, n + 1);
         cross[n++] = k;
      }
   }
   if(n < 3) return(24);
   int diffs[];
   ArrayResize(diffs, n - 1);
   for(int j = 0; j < n - 1; j++) diffs[j] = cross[j + 1] - cross[j];
   ArraySort(diffs);
   return((int)MathMax(14, MathMin(36, diffs[(n - 1) / 2] * 2)));
}

int P2StructureVote(const double &close[], const double &high[], const double &low[], int i, int period, double atr)
{
   if(period < 1 || i < period) return(0);

   double move = close[i] - close[i - period];
   double dead = (atr > 0.0) ? 0.25 * atr : 0.0;

   if(MathAbs(move) <= dead) return(0);

   int start = MathMax(1, i - period + 1);
   double lastSwLow = 0.0, prevSwLow = 0.0;
   double lastSwHigh = 0.0, prevSwHigh = 0.0;
   int numSwLows = 0, numSwHighs = 0;

   for(int k = start; k < i; k++)
   {
      if(high[k] >= high[k - 1] && high[k] >= high[k + 1])
      {
         prevSwHigh = lastSwHigh;
         lastSwHigh = high[k];
         numSwHighs++;
      }
      if(low[k] <= low[k - 1] && low[k] <= low[k + 1])
      {
         prevSwLow = lastSwLow;
         lastSwLow = low[k];
         numSwLows++;
      }
   }

   if(move > dead)
   {
      if(numSwLows >= 2 && lastSwLow < prevSwLow)
         return(0); // Lower low invalidates bullish structure
      return(1);
   }
   else if(move < -dead)
   {
      if(numSwHighs >= 2 && lastSwHigh > prevSwHigh)
         return(0); // Higher high invalidates bearish structure
      return(-1);
   }

   return(0);
}

double P2Hurst(const double &close[], int i, int window)
{
   //  The guard used to be "i + 1 < window", which let i == window - 1
   //  through.  That makes start == 0, and the innermost read
   //  p0 = close[start - 1] then reaches close[-1].  With the shipped
   //  numbers (i = last bar of a 700+ pull, window = 256) start is far
   //  from 0 so it never fired, but raising HURST_* or shrinking the
   //  pull turns this into an out-of-bounds read.  Requiring i >= window
   //  keeps start >= 1, so the smallest index ever touched is 0.
   if(i < window || window < 32) return(EMPTY_VALUE);

   int    scales[5] = {1, 2, 4, 8, 16};
   double lx[5], ly[5];
   int    m = 0;
   int    start = i - window + 1;

   for(int s = 0; s < 5; s++)
   {
      int scale = scales[s];
      int k     = window / scale;          // non-overlapping blocks
      if(k < 4) continue;

      double sums[];
      if(ArrayResize(sums, k) != k) return(EMPTY_VALUE);

      for(int b = 0; b < k; b++)
      {
         double sum = 0.0;
         for(int j = 0; j < scale; j++)
         {
            int    idx = start + b * scale + j;
            double p1  = close[idx];
            double p0  = close[idx - 1];
            if(p0 <= 0.0 || p1 <= 0.0) return(EMPTY_VALUE);
            sum += MathLog(p1 / p0);
         }
         sums[b] = sum;
      }

      double mean = 0.0;
      for(int b = 0; b < k; b++) mean += sums[b];
      mean /= (double)k;

      double var = 0.0;
      for(int b = 0; b < k; b++) var += (sums[b] - mean) * (sums[b] - mean);
      var /= (double)(k - 1);

      double sd = MathSqrt(var);
      if(sd <= 0.0) continue;

      lx[m] = MathLog((double)scale);
      ly[m] = MathLog(sd);
      m++;
   }

   if(m < 3) return(EMPTY_VALUE);

   double mx = 0.0, my = 0.0;
   for(int j = 0; j < m; j++) { mx += lx[j]; my += ly[j]; }
   mx /= (double)m;
   my /= (double)m;

   double sxy = 0.0, sxx = 0.0;
   for(int j = 0; j < m; j++)
   {
      sxy += (lx[j] - mx) * (ly[j] - my);
      sxx += (lx[j] - mx) * (lx[j] - mx);
   }
   if(sxx <= 0.0) return(EMPTY_VALUE);

   return(sxy / sxx);
}

// Same zero-crossing median as SimpleEA, updated incrementally for replay.
// The 120-bar window has at most 120 crossings, so a small histogram avoids
// allocating and sorting a new array for every historical bar.
bool P2Cycles(const double &hp[], int &cycles[])
{
   int n = ArraySize(hp);
   int crosses[];
   int counts[121];
   if(ArrayResize(crosses, n) != n) return(false);
   ArrayInitialize(counts, 0);
   int left = 0, right = 0;
   for(int i = 0; i < n; i++)
   {
      if(i > 0 && ((hp[i-1] <= 0.0 && hp[i] > 0.0) || (hp[i-1] >= 0.0 && hp[i] < 0.0)))
      {
         if(right > left) counts[i - crosses[right-1]]++;
         crosses[right++] = i;
      }
      int first = (int)MathMax(2, i + 1 - 120);
      while(left < right && crosses[left] <= first)
      {
         if(left + 1 < right) counts[crosses[left+1] - crosses[left]]--;
         left++;
      }
      cycles[i] = 24;
      int diffs = right - left - 1;
      if(i + 1 < 40 || diffs < 2) continue;
      int target = diffs / 2, sum = 0;
      for(int d = 1; d <= 120; d++)
      {
         sum += counts[d];
         if(sum > target) { cycles[i] = (int)MathMax(14, MathMin(36, d * 2)); break; }
      }
   }
   return(true);
}

int P2Status(int gt, int ct)
{
   if(gt == P2_WAIT || ct == P2_WAIT) return(P2_WAIT);
   if(gt == ct) return(gt);
   if(gt == 0 || ct == 0) return(3); // MIXED
   return(2);                         // CONFLICT
}

string P2StateText(int state)
{
   if(state == 1) return("UP");
   if(state == -1) return("DOWN");
   if(state == 0) return("FLAT");
   if(state == 2) return("CONFLICT");
   if(state == 3) return("MIXED");
   return("WAIT");
}

// The first observed segment is left-censored and must not count as a run.
// The current segment is right-censored, and is excluded from samples.
bool P2Remaining(const int &labels[], int first, int last, int &age, int &remaining)
{
   if(last <= first || labels[last] == P2_WAIT) return(false);
   int current = labels[last];
   int begin = last;
   while(begin > first && labels[begin - 1] == current) begin--;
   if(begin == first || labels[begin - 1] == P2_WAIT) return(false);
   age = last - begin + 1;
   int samples[];
   if(ArrayResize(samples, last - first + 1) != last - first + 1) return(false);
   int count = 0, start = first;
   for(int i = first + 1; i <= begin; i++)
   {
      if(labels[i] == labels[start] && i < begin) continue;
      int len = i - start;
      if(start > first && labels[start] == current && labels[start - 1] != P2_WAIT &&
         labels[i] != P2_WAIT && len >= age)
      {
         samples[count++] = len - age; // includes zero
      }
      start = i;
   }
   if(count < P2_MIN_RUNS) return(false);
   ArrayResize(samples, count);
   ArraySort(samples);
   remaining = (count % 2 != 0) ? samples[count / 2]
               : (int)MathRound((samples[count / 2 - 1] + samples[count / 2]) / 2.0);
   return(true);
}

// Terminal globals preserve anchors across restarts. Include account/server/symbol;
// verify every intervening closed bar before using a stored countdown.
string P2Key(int lane, bool score, string field)
{
   string text = AccountInfoString(ACCOUNT_SERVER) + ":" + _Symbol;
   uint hash = 2166136261;
   for(int i = 0; i < StringLen(text); i++)
      hash = (hash ^ (uint)StringGetCharacter(text, i)) * 16777619;
   return(StringFormat("MT2.%I64d.%u.%d.%s.%s", AccountInfoInteger(ACCOUNT_LOGIN),
                       hash, lane, score ? "S" : "P", field));
}

void P2Save(int lane, bool score, P2Countdown &c)
{
   // Publish the timestamp last; interrupted writes must not create a
   // seemingly complete anchor containing a mixture of two states.
   string stamp = P2Key(lane, score, "t");
   GlobalVariableDel(stamp);
   if(GlobalVariableSet(P2Key(lane, score, "v"), (double)c.label) == 0) return;
   if(GlobalVariableSet(P2Key(lane, score, "a"), (double)c.age) == 0) return;
   if(GlobalVariableSet(P2Key(lane, score, "r"), (double)c.remaining) == 0) return;
   GlobalVariableSet(stamp, (double)c.anchor);
}

void P2Load(int lane, bool score, P2Countdown &c)
{
   if(c.loaded) return;
   c.loaded = true;
   string t = P2Key(lane, score, "t"), v = P2Key(lane, score, "v");
   string a = P2Key(lane, score, "a"), r = P2Key(lane, score, "r");
   if(!GlobalVariableCheck(t) || !GlobalVariableCheck(v) ||
      !GlobalVariableCheck(a) || !GlobalVariableCheck(r)) return;
   c.anchor = (datetime)GlobalVariableGet(t);
   c.label = (int)GlobalVariableGet(v);
   c.age = (int)GlobalVariableGet(a);
   c.remaining = (int)GlobalVariableGet(r);
   c.valid = (c.anchor > 0 && c.age > 0 && c.remaining >= 0);
}

void P2Forget(int lane, bool score, P2Countdown &c)
{
   c.valid = false;
   GlobalVariableDel(P2Key(lane, score, "t"));
   GlobalVariableDel(P2Key(lane, score, "v"));
   GlobalVariableDel(P2Key(lane, score, "a"));
   GlobalVariableDel(P2Key(lane, score, "r"));
}

string P2CountdownText(int lane, bool score, P2Countdown &c, const int &labels[],
                       const MqlRates &rates[], int first, int last)
{
   P2Load(lane, score, c);
   int anchorIndex = -1;
   if(c.valid)
   {
      for(int i = first; i <= last; i++)
         if(rates[i].time == c.anchor) { anchorIndex = i; break; }
      if(anchorIndex >= 0)
      {
         int start = anchorIndex - c.age + 1;
         if(start <= first || labels[start-1] == c.label || labels[start-1] == P2_WAIT)
            anchorIndex = -1;
         else
            for(int i = start; i <= last; i++)
               if(labels[i] != c.label) { anchorIndex = -1; break; }
      }
      if(anchorIndex < 0) P2Forget(lane, score, c);
   }
   if(!c.valid)
   {
      int age = 0, remaining = 0;
      if(!P2Remaining(labels, first, last, age, remaining)) return(score ? "--%L" : "--");
      c.valid = true;
      c.label = labels[last];
      c.age = age;
      c.remaining = remaining;
      c.anchor = rates[last].time;
      anchorIndex = last;
      P2Save(lane, score, c);
   }
   int left = c.remaining - (last - anchorIndex);
   if(score)
   {
      if(left < 0) return("past est.");
      if(left == 0) return("~0%L");
      int percent = (int)MathRound(100.0 * left / (c.age + c.remaining));
      if(percent == 0) return("<1%L");
      return(IntegerToString(percent) + "%L");
   }
   if(left < 0) return("0b+");
   return("~" + IntegerToString(left) + "b");
}

// Automate's 30-bar regression divided by median absolute change over 20.
int P2Global(const double &close[], int i, double tick)
{
   if(i < 29) return(P2_WAIT);
   double changes[20];
   for(int j = 0; j < 20; j++) changes[j] = MathAbs(close[i - j] - close[i - j - 1]);
   ArraySort(changes);
   double med = (changes[9] + changes[10]) * 0.5;
   if(med <= 0.0) med = tick; // Automate's zero-change safeguard
   if(med <= 0.0 || !MathIsValidNumber(med)) return(P2_WAIT);
   double mean = 0.0, num = 0.0, den = 0.0;
   for(int j = 0; j < 30; j++) mean += close[i - 29 + j];
   mean /= 30.0;
   for(int j = 0; j < 30; j++)
   {
      double dx = j - 14.5;
      num += dx * (close[i - 29 + j] - mean);
      den += dx * dx;
   }
   double ratio = num / den / med;
   if(!MathIsValidNumber(ratio)) return(P2_WAIT);
   if(ratio > 0.20) return(1);
   if(ratio < -0.20) return(-1);
   return(0);
}

double P2ATR(const MqlRates &rates[], int i)
{
   double sum = 0.0;
   for(int k = i - 13; k <= i; k++)
   {
      double tr = rates[k].high - rates[k].low;
      tr = MathMax(tr, MathAbs(rates[k].high - rates[k-1].close));
      tr = MathMax(tr, MathAbs(rates[k].low - rates[k-1].close));
      sum += tr;
   }
   return(sum / 14.0);
}

// CopyRates counts shift 0 against the terminal's chart-bar limit. Keep
// the closed-bar request within that limit, but do not impose a smaller
// arbitrary cap when the user has configured deeper terminal history.
int P2HistoryLimit()
{
   long bars = TerminalInfoInteger(TERMINAL_MAXBARS);
   if(bars <= 1) return(1);
   return((int)MathMin(2147483646.0, (double)(bars - 1)));
}

int P2NextHistoryRequest(int current, int limit)
{
   return((int)MathMin((double)limit, (double)current * 2.0));
}

void P2Reset()
{
   for(int i = 0; i < 3; i++)
   {
      g_p2[i].line = "";
      g_p2[i].lastBar = 0;
      g_p2[i].attemptedBar = 0;
      g_p2[i].lastAttempt = 0;
      g_p2[i].requested = (int)MathMin(P2_START_HISTORY, P2HistoryLimit());
      g_p2[i].lastGoodRequest = 0;
      g_p2[i].retry = true;
      g_p2[i].pt.loaded = false; g_p2[i].pt.valid = false;
      g_p2[i].score.loaded = false; g_p2[i].score.valid = false;
   }
}

string P2Line(int lane)
{
   if(g_p2[lane].line != "") return(g_p2[lane].line);
   string tf = lane == 0 ? "M5" : (lane == 1 ? "M15" : "M30");
   return(tf + " | GT: WAIT | CT: WAIT | ST: WAIT | RG: WAIT | PT: -- | SC: WAIT");
}

void P2Evaluate(int lane, ENUM_TIMEFRAMES tf, datetime latest)
{
   P3Invalidate(lane);
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int limit = P2HistoryLimit();
   int baseline = (int)MathMin(P2_START_HISTORY, limit);
   if(g_p2[lane].requested > limit) g_p2[lane].requested = limit;
   if(g_p2[lane].requested < baseline) g_p2[lane].requested = baseline;
   int n = CopyRates(_Symbol, tf, 1, g_p2[lane].requested, rates);
   // If a deeper request is still downloading or fails, keep independently
   // available readings by retrying a smaller previously available range.
   // The deeper request remains pending; this never substitutes an RG value.
   if(n < 2)
   {
      int smaller = g_p2[lane].lastGoodRequest;
      if(smaller < 2) smaller = (int)MathMin(2048, g_p2[lane].requested);
      if(smaller >= 2 && smaller < g_p2[lane].requested)
         n = CopyRates(_Symbol, tf, 1, smaller, rates);
   }
   g_p2[lane].retry = true;
   if(n < 2 || latest <= 0 || rates[n-1].time != latest)
   {
      g_p2[lane].line = "";
      return;
   }
   g_p2[lane].lastGoodRequest = n;
   // Invalid history is never interpreted as a real reading. Retain only the
   // valid suffix so one corrupt old bar does not poison all recent history.
   int firstValid = 0;
   for(int i = 0; i < n; i++)
   {
      if(!MathIsValidNumber(rates[i].close) || !MathIsValidNumber(rates[i].high) ||
         !MathIsValidNumber(rates[i].low) || rates[i].close == EMPTY_VALUE ||
         rates[i].high == EMPTY_VALUE || rates[i].low == EMPTY_VALUE || rates[i].high < rates[i].low ||
         rates[i].close < rates[i].low || rates[i].close > rates[i].high ||
         rates[i].time <= 0 || (i > 0 && rates[i].time <= rates[i-1].time)) firstValid = i + 1;
   }
   if(firstValid > 0)
   {
      int size = n - firstValid;
      if(size < 2) { g_p2[lane].line = ""; return; }
      for(int i = 0; i < size; i++) rates[i] = rates[i + firstValid];
      n = size;
      ArrayResize(rates, n);
   }
   if(n <= P2_WARMUP + 1)
   {
      double partialClose[];
      int partialGT[];
      if(ArrayResize(partialClose, n) != n || ArrayResize(partialGT, n) != n)
      { g_p2[lane].line = ""; return; }
      for(int i = 0; i < n; i++) partialClose[i] = rates[i].close;
      double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick <= 0.0) tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      for(int i = 0; i < n; i++) partialGT[i] = P2Global(partialClose, i, tick);
      int window = lane == 0 ? 1536 : (lane == 1 ? 512 : 256);
      string rg = "WAIT", ptext = "--";
      if(n - 1 >= window)
      {
         double h = P2Hurst(partialClose, n - 1, window);
         if(h != EMPTY_VALUE && MathIsValidNumber(h))
            rg = h > 0.55 ? "STEADY" : (h < 0.45 ? "CHOPPY" : "MIXED");
      }
      if(lane == 2 && n > 30 && partialGT[n-1] != P2_WAIT)
         ptext = P2CountdownText(lane, false, g_p2[lane].pt, partialGT, rates, 29, n-1);
      string tfname = lane == 0 ? "M5" : (lane == 1 ? "M15" : "M30");
      g_p2[lane].line = tfname + " | GT: " + P2StateText(partialGT[n-1]) +
                        " | CT: WAIT | ST: WAIT | RG: " + rg + " | PT: " + ptext + " | SC: WAIT";
      g_p2[lane].lastBar = latest;
      return; // keep retrying for the remaining required history
   }
   double close[], high[], low[], hp40[], trends[], rocs[];
   int cycles[], gt[], ct[], status[], score[], pt[];
   if(ArrayResize(close,n)!=n || ArrayResize(high,n)!=n || ArrayResize(low,n)!=n ||
      ArrayResize(cycles,n)!=n || ArrayResize(trends,n)!=n || ArrayResize(rocs,n)!=n ||
      ArrayResize(gt,n)!=n || ArrayResize(ct,n)!=n || ArrayResize(status,n)!=n ||
      ArrayResize(score,n)!=n || ArrayResize(pt,n)!=n)
   { g_p2[lane].line = ""; return; }
   for(int i = 0; i < n; i++) { close[i] = rates[i].close; high[i] = rates[i].high; low[i] = rates[i].low; }
   P2HighPass3(close, 40, hp40);
   if(ArraySize(hp40) != n || !P2Cycles(hp40, cycles))
   { g_p2[lane].line = ""; return; }
   // A separate pair of causal filters for each possible adaptive period.
   for(int cycle = 14; cycle <= 36; cycle++)
   {
      int l1 = (int)MathRound(cycle * 6.25);
      l1 = (int)MathMax(90, MathMin(225, l1));
      double hp1[], hp2[];
      P2HighPass3(close, l1, hp1);
      P2HighPass3(close, cycle, hp2);
      if(ArraySize(hp1) != n || ArraySize(hp2) != n)
      { g_p2[lane].line = ""; return; }
      for(int i = 1; i < n; i++)
      {
         if(cycles[i] != cycle) continue;
         trends[i] = hp1[i] - hp2[i];
         rocs[i] = cycle / 6.28 * (trends[i] - (hp1[i-1] - hp2[i-1]));
      }
   }
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   for(int i = 0; i < n; i++) gt[i] = P2Global(close, i, tick);
   for(int i = P2_WARMUP; i < n; i++)
   {
      ct[i] = MathIsValidNumber(trends[i]) ?
              (trends[i] > 0.0 ? 1 : (trends[i] < 0.0 ? -1 : 0)) : P2_WAIT;
      status[i] = P2Status(gt[i], ct[i]);
      double atr = P2ATR(rates, i);
      score[i] = P2_WAIT;
      if(ct[i] != P2_WAIT && MathIsValidNumber(atr) && MathIsValidNumber(rocs[i]))
      {
         int v2 = rocs[i] > 0.02 * atr ? 1 : (rocs[i] < -0.02 * atr ? -1 : 0);
         score[i] = ct[i] + v2 + P2StructureVote(close, high, low, i, 20, atr);
      }
      pt[i] = lane == 0 ? ct[i] : (lane == 1 ? status[i] : gt[i]);
   }
   if(lane == 2)
      for(int i = 29; i < P2_WARMUP; i++) pt[i] = gt[i];
   int last = n - 1;
   int window = lane == 0 ? 1536 : (lane == 1 ? 512 : 256);
   string rg = "WAIT";
   if(last >= window)
   {
      double h = P2Hurst(close, last, window);
      if(h != EMPTY_VALUE && MathIsValidNumber(h))
         rg = h > 0.55 ? "STEADY" : (h < 0.45 ? "CHOPPY" : "MIXED");
   }
   string ptext = pt[last] == P2_WAIT ? "--" : P2CountdownText(lane, false, g_p2[lane].pt, pt, rates, lane == 2 ? 29 : P2_WARMUP, last);
   string stext = score[last] == P2_WAIT ? "--%L" : P2CountdownText(lane, true, g_p2[lane].score, score, rates, P2_WARMUP, last);
   string tfname = lane == 0 ? "M5" : (lane == 1 ? "M15" : "M30");
   string scoreText = "WAIT";
   if(score[last] != P2_WAIT)
      scoreText = (score[last] > 0 ? "+" : "") + IntegerToString(score[last]) + "/3 (" + stext + ")";
   g_p2[lane].line = tfname + " | GT: " + P2StateText(gt[last]) + " | CT: " + P2StateText(ct[last]) +
                     " | ST: " + P2StateText(status[last]) + " | RG: " + rg + " | PT: " + ptext +
                     " | SC: " + scoreText;
   g_p2[lane].lastBar = latest;
   P3Remember(lane,gt[last],ct[last],status[last],score[last],rg,latest,rates,score,gt,ct,status);
   // Request deeper history if needed, up to the terminal's own limit.
   // A partial download or failed larger request is retried on later events.
   g_p2[lane].retry = (gt[last] == P2_WAIT || ct[last] == P2_WAIT ||
                       rg == "WAIT" || ptext == "--" || stext == "--%L");
   if(g_p2[lane].retry && n >= g_p2[lane].requested && g_p2[lane].requested < limit)
      g_p2[lane].requested = P2NextHistoryRequest(g_p2[lane].requested, limit);
}

void P2Update()
{
   ENUM_TIMEFRAMES tfs[3] = {PERIOD_M5, PERIOD_M15, PERIOD_M30};
   ulong now = GetTickCount64();
   for(int i = 0; i < 3; i++)
   {
      datetime latest = iTime(_Symbol, tfs[i], 1);
      bool newBar = latest != g_p2[i].lastBar;
      if(!newBar && !g_p2[i].retry) continue;
      ulong retryDelay = g_p2[i].lastBar == 0 ? 10000 :
                         (g_p2[i].requested >= P2HistoryLimit() ? 60000 : 30000);
      if(latest == g_p2[i].attemptedBar && now - g_p2[i].lastAttempt < retryDelay) continue;
      g_p2[i].attemptedBar = latest;
      g_p2[i].lastAttempt = now;
      P2Evaluate(i, tfs[i], latest);
   }
}
