#ifndef MT_CRF_INPUTS_MQH
#define MT_CRF_INPUTS_MQH

// CRF controls; forecast calibration otherwise uses the reference defaults.
enum ENUM_MT_CRF_MODE
{
   MT_CRF_MODE_BOTH = 0, // MT + CRF
   MT_CRF_MODE_MT = 1,   // MT only
   MT_CRF_MODE_CRF = 2   // CRF only
};
input group "Trading and risk"
input bool InpAutoTrading = true;                    // Auto trading
input bool InpPlaceStopLoss = false;                 // Stop Loss Placement
input bool InpBypassRisk = true;                     // Bypass Risk
input bool InpMinimumLot = false;                    // Minimum Lot use
input group "CRF strategy"
input ENUM_MT_CRF_MODE InpMode = MT_CRF_MODE_BOTH; // Mode
const int InpCrfHistoryBars = 600;                 // Historical lookback bars
const int InpCrfMaxHorizon = 24;                   // Maximum forecast horizon (bars)
const int InpCrfAtrLength = 14;                    // ATR length
const int InpCrfTrendLength = 12;                  // Prior trend length
const int InpCrfVolumeLength = 20;                 // Volume baseline length
const int InpCrfSwingLength = 20;                   // Swing context length
const int InpCrfMinimumAnalogs = 6;                // Reference minimum similar historical setups
const int InpCrfMinFollowthroughPct = 55;          // Reference indicator follow-through percent
const double InpCrfMinRewardRisk = 1.2;            // Minimum forecast reward/risk
input int InpCrfAutoMinimumSamples = 2;              // CRF auto minimum samples (2-50)
input int InpCrfAutoFollowthroughPct = 5;           // CRF auto minimum follow-through % (1-100)
input(name="Reverse confirmation") bool InpCrfReverseConfirmation = false;
input bool InpCrfRiskBypass = true;                 // CRF risk bypass
input bool InpCrfCloseMTInLoss = true;              // Allow CRF close MT position in loss
input group "Trail exits"
input bool InpCrfTrailStop = true;                  // CRF trailstop
input bool InpMtTrailStop = true;                   // MT trailstop
input double InpTrailPullbackPct = 25.0;            // Trail pullback % of best gain (1-100)

bool CRFBuildReady()
{
   return (InpMode==MT_CRF_MODE_BOTH || InpMode==MT_CRF_MODE_MT || InpMode==MT_CRF_MODE_CRF) &&
          InpCrfAutoMinimumSamples>=2 && InpCrfAutoMinimumSamples<=50 &&
          InpCrfAutoFollowthroughPct>=1 && InpCrfAutoFollowthroughPct<=100 &&
          InpTrailPullbackPct>=1.0 && InpTrailPullbackPct<=100.0;
}
#endif
