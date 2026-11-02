//+------------------------------------------------------------------+
//| MT.mq5 - Master Trade                                            |
//|                                                                  |
//| Phase 1: appearance.                                             |
//|                                                                  |
//| A single-line market-state panel drawn with chart objects.       |
//| The panel shows the chart symbol, its broker-published type,     |
//| whether the market is open, and either the server clock (open)   |
//| or the next opening time from the broker's session table         |
//| (closed).                                                        |
//|                                                                  |
//| The panel measures the visible lines and reserves four rows on   |
//| supported charts. Unsupported charts show a two-line notice.     |
//|                                                                  |
//| Appearance follows SimpleEA/SimpleAdvisor.mq5: Consolas 10 pt,   |
//| background C'48,48,48', title 11 pt in clrWhite.                  |
//|                                                                  |
//| This EA does not trade. It only draws the panel.                 |
//+------------------------------------------------------------------+
#property copyright "MT"
#property version   "1.00"
#property description "MT - Master Trade. Phase 1: market state panel."

//---
//  Prefix for every object this EA creates. Keeping it in one place
//  means a rebuild or a deinit can remove exactly this panel and
//  nothing else on the chart.
//---
#define OBJ_PREFIX   "MT_"
#define PANEL_TITLE  "MT V1.00"
#define MAX_SESSIONS 32

// Fixed appearance: MT has no user inputs.
#define PANEL_FONT "Consolas"
#define PANEL_FONT_SIZE 10
#define PANEL_X 12
#define PANEL_Y 24
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
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| One-second heartbeat: the clock must tick even on a quiet market.|
//+------------------------------------------------------------------+
void OnTimer()
{
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
   Measure(PANEL_TITLE, PANEL_FONT_SIZE + 1, titleW, titleH);
   Measure(prefix, PANEL_FONT_SIZE, prefixW, prefixH);
   Measure(state, PANEL_FONT_SIZE, stateW, stateH);
   Measure(suffix, PANEL_FONT_SIZE, suffixW, suffixH);
   Measure(detail == "" ? " " : detail, supported ? PANEL_FONT_SIZE : PANEL_FONT_SIZE + 1, detailW, detailH);
   int pad = 10;
   int headerH = (int)MathMax(MathMax(titleH, prefixH), MathMax(stateH, suffixH));
   int headerW = titleW + prefixW + stateW + suffixW;
   int width = (int)MathMax(headerW, detail == "" ? 0 : detailW) + 2 * pad + 4;
   int rowH = (int)MathMax(headerH, detailH) + 6;
   // Keep the three future rows on supported charts; the SimpleEA-style
   // incompatible notice collapses to a header and one notice line.
   int height = 2 * pad + (supported ? 4 : 2) * rowH;

   MakeRect("bg", PANEL_X, PANEL_Y, width, height, PANEL_BG, clrDimGray);
   int x = PANEL_X + pad;
   int y = PANEL_Y + pad;
   MakeLabel("title", x, y, PANEL_TITLE, PANEL_TITLE_COLOR, PANEL_FONT_SIZE + 1, false);
   x += titleW;
   MakeLabel("prefix", x, y, prefix, clrSilver, PANEL_FONT_SIZE, false);
   x += prefixW;
   MakeLabel("state", x, y, state, stateColor, PANEL_FONT_SIZE, false);
   x += stateW;
   MakeLabel("suffix", x, y, suffix, clrWhite, PANEL_FONT_SIZE, false);
   if(detail != "")
      MakeLabel("detail", PANEL_X + pad, y + rowH, detail,
                supported ? clrSilver : clrTomato,
                supported ? PANEL_FONT_SIZE : PANEL_FONT_SIZE + 1, false);
   else
      ObjectDelete(0, OBJ_PREFIX + "detail");
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
