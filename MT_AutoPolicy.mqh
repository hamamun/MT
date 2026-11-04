// Phase 4 decision kernel only. This file does not send or cancel orders.
// Broker execution and reconciliation are implemented separately.
#ifndef MT_AUTO_POLICY_MQH
#define MT_AUTO_POLICY_MQH
#include "MT_Phase3.mqh"

enum P4_SLOT_STATE
{
   P4_EMPTY = 0,
   P4_PENDING = 1,
   P4_OPEN = 2,
   P4_PARTIAL = 3,       // a position plus an unfilled entry remainder
   P4_UNCERTAIN = 4,     // broker result/ownership not yet established
   P4_MULTIPLE = 5,      // multiple same-lane orders or positions
   P4_UNTRACKED = 6      // ownership has not been reliably established
};

enum P4_ACTION
{
   P4_NO_ACTION = 0,
   P4_PLACE = 1,
   P4_CANCEL_REMAINDER = 2,
   P4_HOLD = 3
};

// Execution must preserve the requested score-to-order-type mapping, even if
// a caller supplies stale or inconsistent plan data.
bool P4PlanMatchesSignal(int direction, int score, bool market)
{
   if(direction != 1 && direction != -1) return(false);
   if(score != direction * 2 && score != direction * 3) return(false);
   return(market == (score == direction * 3));
}

// This policy is not a broker state machine. The caller must establish the
// slot and ownership from broker records, durably journal intent, validate
// requests, and reconcile results before it is safe to carry out an action.
// A cancellation action is a request to try cancellation, not confirmation
// that an order was cancelled. WAIT separately requests cancellation.
P4_ACTION P4Decide(bool enabled, int signal, P4_SLOT_STATE state,
                   int pendingDirection, bool hedgingAccount,
                   bool placePermission, bool planValid)
{
   if(state < P4_EMPTY || state > P4_UNTRACKED) return(P4_HOLD);
   if(state == P4_UNCERTAIN || state == P4_MULTIPLE || state == P4_UNTRACKED)
      return(P4_HOLD);
   // A partially filled entry is already a position. Cancel its unfilled
   // remainder to prevent additional exposure in this single-slot policy.
   if(state == P4_PARTIAL) return(P4_CANCEL_REMAINDER);
   // An open position retains its broker-side exits when disabled or when
   // the signal changes; no closing or exit modification is requested here.
   if(state == P4_OPEN) return(P4_NO_ACTION);
   if(state == P4_PENDING)
   {
      if(pendingDirection != 1 && pendingDirection != -1) return(P4_HOLD);
      if(!enabled) return(P4_CANCEL_REMAINDER);
      if(signal == P3_WAIT) return(P4_CANCEL_REMAINDER);
      if(signal < -1 || signal > 1) return(P4_HOLD);
      return(signal != pendingDirection ? P4_CANCEL_REMAINDER : P4_NO_ACTION);
   }
   if(!enabled) return(P4_NO_ACTION);
   if(signal == P3_WAIT || signal == 0) return(P4_NO_ACTION);
   if(signal != 1 && signal != -1) return(P4_HOLD);
   // Like SimpleEA, do not place new lane entries on netting/exchange accounts.
   if(!hedgingAccount || !placePermission || !planValid) return(P4_HOLD);
   return(P4_PLACE);
}
#endif
