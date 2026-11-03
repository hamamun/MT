// Phase 3 signal-selection and broker-volume decision kernels.
// No orders are submitted or modified here.
#ifndef MT_PHASE3_MQH
#define MT_PHASE3_MQH

#define P3_WAIT 99

enum P3_TREND_CHOICE
{
   P3_AUTO = 0,
   P3_FOLLOW_CT = 1,
   P3_FOLLOW_GT = 2,
   P3_FOLLOW_ST = 3
};

// Values match Phase 2: -1 DOWN, 0 FLAT, 1 UP, 2 CONFLICT,
// 3 MIXED and 99 unavailable. Invalid choices/readings are unavailable.
int P3SelectedTrend(int lane, P3_TREND_CHOICE choice, int gt, int ct, int st)
{
   if(lane < 0 || lane > 2) return(P3_WAIT);
   int selected = P3_WAIT;
   if(choice == P3_AUTO)
      selected = lane == 0 ? ct : (lane == 1 ? st : gt);
   else if(choice == P3_FOLLOW_CT) selected = ct;
   else if(choice == P3_FOLLOW_GT) selected = gt;
   else if(choice == P3_FOLLOW_ST) selected = st;
   if(selected < -1 || (selected > 1 && selected != 2 && selected != 3))
      return(P3_WAIT);
   // CONFLICT and MIXED are ST values only, never CT or GT.
   bool statusChoice = choice == P3_FOLLOW_ST || (choice == P3_AUTO && lane == 1);
   if(!statusChoice && selected > 1) return(P3_WAIT);
   return(selected);
}

// Returns BUY=1, SELL=-1, NONE=0, unavailable=P3_WAIT. The score and
// selected trend must both be available, including in countertrend mode.
int P3Signal(int score, int selectedTrend, bool allowAgainst)
{
   if(score < -3 || score > 3) return(P3_WAIT);
   if(selectedTrend < -1 || selectedTrend > 3) return(P3_WAIT);
   int direction = score >= 2 ? 1 : (score <= -2 ? -1 : 0);
   if(direction == 0) return(0);
   if(allowAgainst || selectedTrend == direction) return(direction);
   return(0);
}

bool P3Positive(double v)
{
   return(MathIsValidNumber(v) && v != EMPTY_VALUE && v > 0.0);
}

// Normalize to the broker's min + N*step grid, not to decimal digits.
// A below-minimum valid request intentionally returns the minimum. Returns
// 0 for unusable inputs, not a fictitious tradeable volume. The max is
// always honored, including when it is not on the volume grid.
double P3Volume(double requested, double minimum, double maximum, double step)
{
   if(!P3Positive(requested) || !P3Positive(minimum) ||
      !P3Positive(maximum) || !P3Positive(step) || maximum < minimum)
      return(0.0);
   if(requested <= minimum) return(minimum);
   double cap = MathMin(requested, maximum);
   double count = MathFloor((cap - minimum) / step + 1e-10);
   if(!MathIsValidNumber(count) || count < 0.0) return(0.0);
   double result = minimum + count * step;
   // Guard floating point rounding without ever crossing the broker maximum.
   if(result > maximum) result -= step;
   if(result > cap && result - cap > step * 1e-9) result -= step;
   if(result < minimum) result = minimum;
   if(result > maximum || !MathIsValidNumber(result)) return(0.0);
   return(result);
}

// perLotLoss is an estimated positive SL loss per full lot in account
// currency, derived by the caller from OrderCalcProfit for a valid broker
// volume. Normal mode risks 0.5% equity per lane. Bypass follows SimpleEA's
// balance ladder. Forced minimum is independent of the minimum fallback.
double P3Lot(double equity, double balance, double perLotLoss, int score,
             bool bypass, bool forceMinimum,
             double minimum, double maximum, double step)
{
   if(!P3Positive(minimum) || !P3Positive(maximum) ||
      !P3Positive(step) || maximum < minimum) return(0.0);
   if(score < -3 || score > 3 || (score > -2 && score < 2)) return(0.0);
   if(forceMinimum) return(minimum);
   double requested = 0.0;
   if(bypass)
   {
      if(!P3Positive(balance)) return(0.0);
      requested = balance / 1000.0 * 0.01;
      if(score == 3 || score == -3) requested *= 1.5;
   }
   else
   {
      if(!P3Positive(equity) || !P3Positive(perLotLoss)) return(0.0);
      requested = equity * 0.005 / perLotLoss;
   }
   return(P3Volume(requested, minimum, maximum, step));
}
#endif
