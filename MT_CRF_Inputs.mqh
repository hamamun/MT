#ifndef MT_CRF_INPUTS_MQH
#define MT_CRF_INPUTS_MQH

// CRF controls; forecast calibration otherwise uses the reference defaults.
enum ENUM_MT_CRF_MODE
{
   MT_CRF_MODE_BOTH = 0, // MT + CRF
   MT_CRF_MODE_MT = 1,   // MT only
   MT_CRF_MODE_CRF = 2   // CRF only
};
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
input int InpCrfAutoMinimumSamples = 4;              // CRF auto minimum samples (2-50)
input int InpCrfAutoFollowthroughPct = 15;           // CRF auto minimum follow-through % (1-100)
input bool InpCrfRiskBypass = false;                 // CRF risk bypass
input bool InpCrfCloseProfitableM15 = true;        // Allow CRF to close profitable M15 MT position

bool CRFBuildReady()
{
   return (InpMode==MT_CRF_MODE_BOTH || InpMode==MT_CRF_MODE_MT || InpMode==MT_CRF_MODE_CRF) &&
          InpCrfAutoMinimumSamples>=2 && InpCrfAutoMinimumSamples<=50 &&
          InpCrfAutoFollowthroughPct>=1 && InpCrfAutoFollowthroughPct<=100;
}
#endif
