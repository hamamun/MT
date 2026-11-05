// Price-plan calculations. Uses closed bars only; the historical replay is
// a bar-level research approximation, not actual execution or tick history.
#ifndef MT_PLAN_MQH
#define MT_PLAN_MQH
#include "MT_Phase3.mqh"

struct P3Geometry
{
   double entry;
   double stop;
   double barrier;
   double fallbackMove;
};

double P3Down(double p, double tick)
{
   return(MathFloor(p / tick + 1e-9) * tick);
}

double P3Up(double p, double tick)
{
   return(MathCeil(p / tick - 1e-9) * tick);
}

// Median positive within-bar directional moves in a recent causal window.
// This also supplies a fallback when no confirmed structure is available.
double P3RecentMove(const MqlRates &rates[], int last, int dir, double tick)
{
   double moves[];
   int first = (int)MathMax(0, last - 39);
   for(int k = first; k <= last; k++)
   {
      double move = dir > 0 ? rates[k].high - rates[k].open : rates[k].open - rates[k].low;
      if(!MathIsValidNumber(move) || move <= 0.0) continue;
      int n = ArraySize(moves);
      if(ArrayResize(moves, n + 1) != n + 1) return(0.0);
      moves[n] = move;
   }
   int n = ArraySize(moves);
   if(n == 0) return(tick);
   ArraySort(moves);
   return(MathMax(tick, moves[n / 2]));
}

// Compare the completed bar's tick volume with the preceding 20 bars,
// excluding the tested bar. Match SimpleEA's 50% threshold and unavailable
// behavior: fewer than ten positive baseline bars means no volume evidence.
int P3VolumeState(const MqlRates &rates[], int last)
{
   if(last < 20 || last >= ArraySize(rates)) return(-1);
   double sum=0.0;
   int valid=0;
   for(int k=last-20; k<last; k++)
      if(rates[k].tick_volume>0) { sum+=(double)rates[k].tick_volume; valid++; }
   if(valid<10 || sum<=0.0 || rates[last].tick_volume<0) return(-1);
   return((double)rates[last].tick_volume >= 0.5*sum/valid ? 1 : 0);
}

bool P3GeometryAt(const MqlRates &rates[], int last, int lane, int dir, bool market,
                  double bid, double ask, double tick, double minDistance, P3Geometry &out)
{
   out.entry = 0.0; out.stop = 0.0; out.barrier = 0.0; out.fallbackMove = 0.0;
   if(last < 3 || last >= ArraySize(rates) || lane < 0 || lane > 2 ||
      (dir != 1 && dir != -1) || !P3Positive(bid) || !P3Positive(ask) ||
      ask < bid || !P3Positive(tick) || !MathIsValidNumber(minDistance) || minDistance < 0.0)
      return(false);
   int validFirst = (int)MathMax(0, last - 73);
   for(int k = validFirst; k <= last; k++)
      if(!P3Positive(rates[k].open) || !P3Positive(rates[k].high) || !P3Positive(rates[k].low) ||
         rates[k].high < rates[k].low || rates[k].open < rates[k].low || rates[k].open > rates[k].high) return(false);
   int window = lane == 0 ? 36 : (lane == 1 ? 48 : 72);
   int first = (int)MathMax(1, last - window + 1);
   double spread = ask - bid;
   double offset = MathMax(tick, minDistance);
   double entry = market ? (dir > 0 ? ask : bid) : 0.0;
   // Pick the nearest closed, confirmed pivot on the correct side.
   if(!market)
   {
      for(int k = first; k < last; k++)
      {
         if(dir > 0 && rates[k].low < rates[k-1].low && rates[k].low <= rates[k+1].low)
         {
            double p = P3Down(rates[k].low, tick);
            if(p > 0.0 && p <= ask-offset && (entry <= 0.0 || p > entry)) entry = p;
         }
         if(dir < 0 && rates[k].high > rates[k-1].high && rates[k].high >= rates[k+1].high)
         {
            double p = P3Up(rates[k].high + spread, tick);
            if(p >= bid+offset && (entry <= 0.0 || p < entry)) entry = p;
         }
      }
      if(entry <= 0.0)
      {
         // Recent pullback magnitude rather than a fixed ATR multiple.
         double pullback = P3RecentMove(rates, last, -dir, tick);
         if(!P3Positive(pullback)) return(false);
         double dist = MathMax(offset, pullback);
         entry = dir > 0 ? P3Down(ask-dist, tick) : P3Up(bid+dist, tick);
      }
   }
   if(!P3Positive(entry)) return(false);
   out.entry = entry;
   double support = 0.0;
   for(int k = first; k < last; k++)
   {
      if(dir > 0 && rates[k].low < rates[k-1].low && rates[k].low <= rates[k+1].low && rates[k].low < entry)
         if(support <= 0.0 || rates[k].low > support) support = rates[k].low;
      if(dir < 0 && rates[k].high > rates[k-1].high && rates[k].high >= rates[k+1].high && rates[k].high + spread > entry)
         if(support <= 0.0 || rates[k].high + spread < support) support = rates[k].high + spread;
   }
   double buffer = MathMax(tick, spread);
   double move = P3RecentMove(rates, last, dir, tick);
   if(!P3Positive(move)) return(false);
   double stop = 0.0;
   if(dir > 0)
   {
      stop = support > 0.0 ? support - buffer : entry - MathMax(move, buffer);
      double base = market ? bid : entry;
      stop = P3Down(MathMin(stop, base - offset), tick);
   }
   else
   {
      stop = support > 0.0 ? support + buffer : entry + MathMax(move, buffer);
      double base = market ? ask : entry;
      stop = P3Up(MathMax(stop, base + offset), tick);
   }
   if(!P3Positive(stop) || (dir > 0 && stop >= entry) || (dir < 0 && stop <= entry)) return(false);
   out.stop = stop;
   // Nearest confirmed opposing pivot, expressed on the exit quote side.
   double barrier = 0.0;
   for(int k = first; k < last; k++)
   {
      if(dir > 0 && rates[k].high > rates[k-1].high && rates[k].high >= rates[k+1].high)
      {
         double p = P3Down(rates[k].high, tick);
         if(p > entry && (barrier <= 0.0 || p < barrier)) barrier = p;
      }
      if(dir < 0 && rates[k].low < rates[k-1].low && rates[k].low <= rates[k+1].low)
      {
         double p = P3Up(rates[k].low + spread, tick);
         if(p < entry && p > 0.0 && (barrier <= 0.0 || p > barrier)) barrier = p;
      }
   }
   out.entry = entry; out.stop = stop; out.barrier = barrier; out.fallbackMove = move;
   return(true);
}

// Replay completed matching-score analogues, using only bars available at
// each hypothetical decision. Stops win ambiguous same-bar order and a limit
// touch is not a broker fill. Spread from closed-bar metadata is a proxy.
// Each sample is favorable excursion in units of that analogue's risk.
double P3ObservedTargetR(const MqlRates &rates[], const int &scores[], const int &gts[],
                         const int &cts[], const int &statuses[], int n, int lane,
                         int score, P3_TREND_CHOICE choice, bool allowAgainst,
                         double tick, double point, double minDistance,
                         double spreadFallback, int &samples)
{
   samples = 0;
   int horizon = lane == 0 ? 4 : (lane == 1 ? 6 : 8);
   int dir = score > 0 ? 1 : -1;
   bool market = P3MarketStyle(score,P3VolumeState(rates,n-1));
   double values[];
   int earliest = (int)MathMax(700, n - 6000);
   int nextAllowed = n;
   for(int t = n - horizon - 1; t >= earliest; t--)
   {
      if(t + horizon >= nextAllowed || scores[t] != score ||
         P3MarketStyle(scores[t],P3VolumeState(rates,t)) != market) continue;
      int selected=P3SelectedTrend(lane,choice,gts[t],cts[t],statuses[t]);
      if(P3Signal(scores[t],selected,allowAgainst)!=dir) continue;
      double spread = rates[t].spread > 0 ? rates[t].spread * point : spreadFallback;
      double bid = rates[t].close, ask = bid + spread;
      P3Geometry geo;
      if(!P3GeometryAt(rates, t, lane, dir, market, bid, ask, tick, minDistance, geo)) continue;
      double risk = dir * (geo.entry - geo.stop);
      if(risk <= 0.0) continue;
      bool touched = market;
      double favorable = 0.0;
      for(int k = t + 1; k <= t + horizon; k++)
      {
         double sp = rates[k].spread > 0 ? rates[k].spread * point : spreadFallback;
         bool entryBar = false;
         if(!touched)
         {
            touched = dir > 0 ? rates[k].low + sp <= geo.entry : rates[k].high >= geo.entry;
            if(!touched) continue;
            entryBar = true;
         }
         bool stopped = dir > 0 ? rates[k].low <= geo.stop : rates[k].high + sp >= geo.stop;
         if(stopped) break;
         if(entryBar) continue;
         double travel = dir > 0 ? rates[k].high - geo.entry : geo.entry - (rates[k].low + sp);
         favorable = MathMax(favorable, travel);
      }
      if(!touched) continue;
      int count = ArraySize(values);
      if(ArrayResize(values, count + 1) != count + 1) return(0.0);
      values[count] = MathMax(0.0, favorable / risk);
      nextAllowed = t;
   }
   samples = ArraySize(values);
   if(samples == 0) return( 0.0 );
   ArraySort(values);
   return(values[samples / 2]);
}

#endif
