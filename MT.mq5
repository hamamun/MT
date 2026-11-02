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
//| The panel reserves four rows: row 1 is the header, rows 2-4 are   |
//| reserved for later phases. The box is sized to the widest of the |
//| open and closed states, so it never resizes when the market      |
//| shuts.                                                           |
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

//---
//  Appearance. The three values from the specification are the
//  defaults; they are inputs so the panel can be tuned without a
//  source edit, but the shipped look is exactly the specified one.
//---
input group "=== Appearance ==="
input string InpFont        = "Consolas";    // Font
input int    InpFontSize    = 10;            // Font size (pt)
input color  InpBgColor     = C'48,48,48';   // Background colour
input color  InpTitleColor  = clrWhite;      // Title colour
input int    InpPanelX      = 12;            // Panel X offset (px)
input int    InpPanelY      = 24;            // Panel Y offset (px)

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
//  The session table is scanned once per server day (and on a symbol
//  change). 32 sessions per day is far above any real broker table.
//---
SessionSlot g_sessions[7][MAX_SESSIONS];
int         g_sessionCount[7];
int         g_sessionsDay = -1;
bool        g_hasSessions = false;

//---
//  Panel geometry and last-drawn state. The geometry is computed from
//  the actual strings, so a long symbol name widens the box instead of
//  clipping the clock.
//---
int      g_panelW    = 0;
int      g_panelH    = 0;
int      g_titleW    = 0;
int      g_symbolX   = 0;
int      g_typeX     = 0;
int      g_stateX    = 0;
int      g_lastX     = 0;
string   g_symbol    = "";
string   g_type      = "";
bool     g_isOpen    = false;
datetime g_nextOpen  = 0;
string   g_lastText  = "";
int      g_lastState = -1;
bool     g_built     = false;

//+------------------------------------------------------------------+
//| Expert initialization: build the panel and start the 1 s timer.  |
//+------------------------------------------------------------------+
int OnInit()
{
   Rebuild();
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
//| A timeframe change does not: the panel does not depend on it.    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_SYMBOL_CHANGED || id == CHARTEVENT_CHART_CHANGE)
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
   EventKillTimer();
   ObjectsDeleteAll(0, OBJ_PREFIX);
   g_built = false;

   g_symbol = _Symbol;
   g_type   = ClassifySymbol(g_symbol);

   ScanSessions();
   UpdateState();
   BuildPanel();

   EventSetTimer(1);
}

//+------------------------------------------------------------------+
//| Current server time, with a local-clock fallback for a terminal  |
//| that has not yet received a server time.                         |
//+------------------------------------------------------------------+
datetime ServerNow()
{
   datetime t = TimeTradeServer();
   if(t <= 0)
      t = TimeCurrent();
   return(t);
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
//| Estimated rendered width of one character, in pixels.            |
//| MetaTrader sizes fonts in points; the terminal reports the DPI,  |
//| so the estimate uses the real value instead of assuming 96.      |
//| A monospaced face needs about 0.55 em per character, rounded up. |
//+------------------------------------------------------------------+
int CharW(int size)
{
   if(size < 6)
      size = 6;
   int dpi = (int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi < 72)
      dpi = 96;
   double em = (double)size * (double)dpi / 72.0;
   return((int)MathCeil(em * 0.55));
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
   ObjectSetString (0, full, OBJPROP_FONT,       InpFont);
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

   MqlDateTime now;
   TimeToStruct(ServerNow(), now);
   g_sessionsDay = now.day_of_week;
}

//+------------------------------------------------------------------+
//| True when the server clock is inside one of today's sessions,    |
//| or inside an overnight session that began yesterday.             |
//|                                                                  |
//| With no published table the market is reported closed: the       |
//| specification prefers "Open at --" to an invented opening time.  |
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
         if(sec >= f || sec < t)
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
void UpdateState()
{
   datetime now = ServerNow();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   if(dt.day_of_week != g_sessionsDay)
      ScanSessions();

   g_isOpen   = IsMarketOpen(now);
   g_nextOpen = 0;
   if(!g_isOpen)
      g_nextOpen = NextOpening(now);
}

//+------------------------------------------------------------------+
//| Draw the panel. The width is measured from both states before    |
//| the background is created, so the box never resizes when the     |
//| market shuts. The height is fixed at four rows.                  |
//+------------------------------------------------------------------+
void BuildPanel()
{
   int x       = InpPanelX;
   int y       = InpPanelY;
   int rowH    = InpFontSize + 11;
   int textY   = y + 7;
   int cw      = CharW(InpFontSize);
   int titleCw = CharW(InpFontSize + 1);
   int sep     = 3 * cw;

   string clock      = FormatClock(ServerNow());
   string openRest   = " | " + g_symbol + " | " + g_type + " | OPEN | " + clock;
   string closedRest = " | " + g_symbol + " | " + g_type + " | close | Open at " + FormatClock(0);

   int openW   = StringLen(PANEL_TITLE) * titleCw + StringLen(openRest) * cw;
   int closedW = StringLen(PANEL_TITLE) * titleCw + StringLen(closedRest) * cw;

   // One trailing character of breathing room on the right. The box is
   // sized to the wider of the two states, so it does not move when the
   // market closes.
   g_panelW = (int)MathMax(openW, closedW) + cw;
   g_panelH = 4 * rowH;

   MakeRect("bg", x, y, g_panelW, g_panelH, InpBgColor, clrDimGray);

   g_titleW  = StringLen(PANEL_TITLE) * titleCw;
   g_symbolX = x + g_titleW + sep;
   g_typeX   = g_symbolX + StringLen(g_symbol) * cw + sep;
   g_stateX  = g_typeX + StringLen(g_type) * cw + sep;

   string stateText = g_isOpen ? "OPEN" : "close";
   g_lastX = g_stateX + StringLen(stateText) * cw + sep;

   string lastText = g_isOpen
                     ? clock
                     : (g_nextOpen > 0 ? "Open at " + FormatClock(g_nextOpen)
                                       : "Open at --");

   MakeLabel("title",  x,         textY, PANEL_TITLE, InpTitleColor, InpFontSize + 1, false);
   MakeLabel("symbol", g_symbolX, textY, g_symbol,    clrWhite,       InpFontSize,     false);
   MakeLabel("type",   g_typeX,   textY, g_type,      clrSilver,      InpFontSize,     false);
   MakeLabel("state",  g_stateX,  textY, stateText,   g_isOpen ? clrLime : clrTomato,
                                                       InpFontSize,     false);
   MakeLabel("last",   g_lastX,   textY, lastText,    clrWhite,       InpFontSize,     false);

   g_lastState = g_isOpen ? 1 : 0;
   g_lastText  = lastText;
   g_built     = true;

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update only what changed. The clock is rewritten once a second;  |
//| the state cell and the last cell's x are rewritten only when the |
//| market opens or closes.                                          |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!g_built)
      return;

   datetime now = ServerNow();
   UpdateState();

   string stateText = g_isOpen ? "OPEN" : "close";
   string lastText  = g_isOpen
                      ? FormatClock(now)
                      : (g_nextOpen > 0 ? "Open at " + FormatClock(g_nextOpen)
                                        : "Open at --");

   bool changed = false;

   if((g_isOpen ? 1 : 0) != g_lastState)
   {
      ObjectSetString (0, OBJ_PREFIX + "state", OBJPROP_TEXT,  stateText);
      ObjectSetInteger(0, OBJ_PREFIX + "state", OBJPROP_COLOR,
                       (long)(g_isOpen ? clrLime : clrTomato));

      int cw  = CharW(InpFontSize);
      int sep = 3 * cw;
      g_lastX = g_stateX + StringLen(stateText) * cw + sep;
      ObjectSetInteger(0, OBJ_PREFIX + "last", OBJPROP_XDISTANCE, g_lastX);

      g_lastState = g_isOpen ? 1 : 0;
      changed = true;
   }

   if(lastText != g_lastText)
   {
      ObjectSetString(0, OBJ_PREFIX + "last", OBJPROP_TEXT, lastText);
      g_lastText = lastText;
      changed = true;
   }

   if(changed)
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
                        ".M", ".F", ".Z", ".J",
                        "CASH", "SPOT", "RAW", "ECN", "PRO", "STD",
                        "M", "F", "Z", "J"};
   bool changed = true;
   while(changed)
   {
      changed = false;
      for(int i = 0; i < ArraySize(suffixes); i++)
      {
         int sl = StringLen(suffixes[i]);
         if(StringLen(s) > sl &&
            StringFind(s, suffixes[i]) == StringLen(s) - sl)
         {
            s = StringSubstr(s, 0, StringLen(s) - sl);
            changed = true;
            break;
         }
      }
   }
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
   if(InList(meta, cryptoKeywords) || StartsWithAny(sym, cryptoPrefixes))
      return("Crypto");

   // Energy before metal: "Commodities" covers both, and the
   // description or industry separates them.
   string energyKeywords[] = {"ENERGY", "CRUDE", "BRENT", "NATURAL GAS", "OIL", "GAS"};
   string energyTokens[]   = {"OIL", "CRUDE", "BRENT", "WTI", "NATGAS", "NATURALGAS",
                              "XTI", "XBR", "XNG", "NG", "CL", "HO", "RB"};
   if(InList(meta, energyKeywords) || InList(sym, energyTokens))
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

   string base3  = StringSubstr(sym, 0, 3);
   string quote3 = StringSubstr(sym, 3, 3);
   if(StringLen(sym) == 6 &&
      InList(base3, fiatTokens) &&
      InList(quote3, fiatTokens))
      return("Forex");
   if(InList(meta, forexKeywords))
      return("Forex");

   return("Other");
}
//+------------------------------------------------------------------+
