# MT_CRF.md — Build specification

> **Status: implemented for MT5 testing; native verification pending.** `MT_CRF.mq5` is separate from the unchanged original MT EA. MetaEditor compilation, the MT5 Strategy Tester, broker behavior, chart rendering and comparison with the actual Indie runtime have not been verified in this environment.
>
> **Revision: 2026-11-02.** The forecast, fixed-M15 feed, isolated execution and diary adapters, takeover/reconciliation, panel and chart objects are wired into the separate EA. Source-derived C++ stub tests and the synthetic Python-emulated Indie fixture are not substitutes for native MT5 or Indie tests.
>
> **Recovery and isolation:** CRF saves its forecast and execution intents separately under the shared account/server/symbol execution lock. The existing native M15 journal is reserved before a CRF send, so the unchanged original MT engine holds the lane in REVIEW rather than treating it as free if it is started while a CRF order remains unresolved. The separate CRF trade diary is seeded once from the locked original diary, then diverges; CRF strategy 30007 rows do not alter the original MT diary. After the seed, later trades in one diary are not automatically copied into the other.
>
> **Known operational limits:** unclaimed forecast signals found on restart, bootstrap signals and old catch-up confirmations are display-only; uncertain requests require broker reconciliation instead of blind retries. The loader requires an available M15 anchor. Initial bootstrap, large offline catch-up and chart replay use bounded M15 slabs, without the old 100,000-bar full-copy limit; MT5's own chart-bar availability and max-bars limit still apply. A rolling cache stores the needed recent M15 bars in the account/server/symbol-scoped local MT5 file area; it is an optional cache, not a trade journal or a source of broker authority. Candidate/confirmation markers and finite forecast segments are rebuilt from the available closed M15 history after attachment or restart. Replay is sliced after broker management and catches up if new M15 bars arrive during rebuilding; while it runs the panel reports the rebuild. If history or chart objects are unavailable, or the replay disagrees with the saved forecast, partial chart objects are cleared and reconstruction retries rather than presenting them as complete. The master Auto Trading switch blocks both new orders and software-close requests; with it off, an existing CRF position retains broker SL/TP but a software expiry waits until trading is enabled. All costs and ownership must be verified before the optional native-M15 close.

---

## 1. Source functionality to port: `confirmed_reversal_forecast`

This is the **first** thing the build must reproduce. Use this file as the forecast reference, with the explicit signed-direction correction below; verify parity against actual Indie outputs where possible. Do not use the original `reversal_forecast.indie` and not the newer `reversal_continuation_forecast.indie`.

| Item | Value |
|---|---|
| Source file | `confirmed_reversal_forecast.indie` |
| Repo / commit | `hamamun/Predictor`, `main` @ `9056bd0` |
| Size | 1568 lines, 88007 bytes |
| SHA256 | `c9bee5bf0154a9eb49e9957a9c6879072ef5b187feabaadb7494c9bf19b4a1ee` |
| Indicator title | `Confirmed Reversal Forecast (Historical Analogs)` |
| Timeframe | **Fixed `PERIOD_M15` closed bars**; reuses MT's existing M15 lane. The EA may be attached to **M5, M15 or M30** — CRF still reads M15 bars. Attaching to M15 is recommended for clarity only, **not required**. No other HTF |
| Plots | 6 (`@plot.` decorators / 6 returned plots) |

### 1.1 Candle patterns — 3 families / 10 named forms

Port only these:

1. **Engulfing**
   - `Bullish engulfing`
   - `Bearish engulfing`
2. **Hammer family** (direction decided by prior trend + swing location)
   - `Hammer`
   - `Inverted hammer`
   - `Hanging man`
   - `Shooting star`
   - `Hammer family` (generic label when the variant is not resolved)
3. **Stars**
   - `Morning star`
   - `Evening star`
   - `Morning doji star`
   - `Evening doji star`

Rules:

- **A Doji alone never gives direction.**
- Do **not** add Piercing Line / Dark Cloud Cover, Tweezer, Kicker, Abandoned Baby, Marubozu, Three White Soldiers / Black Crows, Inside / Outside, Spinning Top, standalone Dragonfly / Gravestone Doji, or any other family.
- Keep the reference detection/context filters and closed-candle confirmation unchanged; the separate auto follow-through threshold is configurable as described below.

### 1.2 Context filters and inputs

Fixed internal values in the Indie source:

| Fixed rule | Value |
|---|---|
| `minimum_trend_atr` | `1.0` |
| `swing_tolerance_atr` | `1.0` |
| `confirmation_bars` | `2` |
| Cooldown | `swing_length + confirmation_bars`, per direction, set **only when a candidate starts** |
| `context_length` | `max(atr_length, trend_length, volume_length, swing_length) + 3` |
| `can_calculate` | `bar_count > context_length + 2` |

Internal CRF calibration defaults (the same reference defaults and validation ranges; they are deliberately not exposed as technical user inputs):

| Indie param | Default | Min | Max | MQL5 input |
|---|---:|---:|---:|---|
| `history_bars` | 600 | 100 | 2000 | `InpCrfHistoryBars` |
| `max_horizon` | 24 | 4 | 100 | `InpCrfMaxHorizon` |
| `atr_length` | 14 | 2 | 100 | `InpCrfAtrLength` |
| `trend_length` | 12 | 2 | 100 | `InpCrfTrendLength` |
| `volume_length` | 20 | 2 | 200 | `InpCrfVolumeLength` |
| `swing_length` | 20 | 3 | 200 | `InpCrfSwingLength` |
| `minimum_analogs` | 6 | 2 | 50 | `InpCrfMinimumAnalogs` |
| `minimum_followthrough_pct` | 55 | 1 | 99 | `InpCrfMinFollowthroughPct` |
| `minimum_reward_risk` | 1.2 | 0.5 | 5.0 (step 0.1) | `InpCrfMinRewardRisk` |

**MT-specific CRF inputs (not from Indie):**

```mql5
input int InpCrfAutoFollowthroughPct = 15; // CRF auto minimum follow-through % (1-100)
input bool InpCrfRiskBypass = false; // CRF reward/risk and sizing bypass
input bool InpCrfCloseProfitableM15 = true; // Allow CRF to close profitable M15 MT position
```

Default is **true**. No second input for a manual minimum profit; the cost buffer is computed internally (Section 2.4). Both this input and `InpMode` live in `MT_CRF_Inputs.mqh`.

Context logic to keep:

- Prior move must be at least `1.0 ATR` over `trend_length`.
- Bullish setup must sit near a `swing_length` swing low; bearish near a swing high, within `1.0 ATR`.
- Volume ratio uses `volume_length` preceding bars as baseline.
- One raw candidate per swing via the direction-specific cooldown; nearby raw patterns are merged/ignored; an opposite-direction candidate remains possible.

### 1.3 Raw candidate → confirmed signal

This is the false-reversal fix. Keep it exactly.

1. A raw candle makes a **candidate**, not a signal.
2. Candidate stores: direction, break level, stop level, pattern, variant, ATR, volume ratio, trend, swing-location feature, marker level, elapsed = 0.
3. Confirmation is a **close-break** on a later **closed** candle:
   - BUY: `close[1] > pending_break`
   - SELL: `close[1] < pending_break`
4. Up to `confirmation_bars = 2` closed bars are allowed.
5. If not confirmed in time → `Candidate expired; no confirmation`.
6. While a candidate is pending, new nearby raw patterns are ignored (`Nearby pattern ignored`).
7. Confirmation entry = `self.close[1]` (the closed candle's close).
8. A genuinely new confirmed reversal while a forecast is active **replaces** it; an opposite one is `Opposite confirmed reversal`.

### 1.4 Historical analog estimate

Use the **same confirmed-reversal definition** for historical selection. Do **not** reuse MT's `P3ObservedTargetR()` percentile favorable-excursion replay for CRF.

Keep:

- Scan range: `history_start = max_horizon + confirmation_bars + 3`, `history_end = history_bars`.
- Same pattern families, same context filters, same two-bar confirmation rule.
- Similarity features: ATR, volume ratio, prior trend, swing location.
- Similarity threshold `>= 2.0`; analogs spaced at least `max_horizon` bars apart.
- Historical target: `hist_entry + direction * hist_risk * minimum_reward_risk`.
- Record the first stop/target outcome (stop wins a same-bar tie), but do not end the episode at either price. Continue measuring favorable movement and duration until an opposite confirmed reversal or the `max_horizon` cap, as in the source.
- Weighted outputs: expected move in ATR, expected duration, follow-through confidence %, analog count, estimate quality.
- Duration range: weighted mean ± `max(1, MathSqrt(variance) * 0.75)`, rounded as in the source, with lower bound `>= 1`, `duration_high > duration_low` where possible, and upper bound capped by `max_horizon`. At the horizon boundary the two bounds may coincide after the final cap, as in the source.
- **`duration_high` is the hard expiry** → `Forecast expires in`. The typical `Expected duration` number is **not** a deadline. No extension.

Estimate gates:

| Gate | Meaning |
|---|---|
| `estimate_available` | `analog_count >= 2` and valid weighted move / duration / entry / stop |
| `forecast_ready` | `analog_count >= minimum_analogs` AND `confidence >= minimum_followthrough_pct` AND `expected_move_atr >= risk_in_atr * minimum_reward_risk` |
| `Estimate quality` | `Meets selected filters`, `Low sample count`, `Below follow-through filter`, `Below reward/risk filter`, or `No historical estimate` |

**Auto-trading-only gate:** `InpCrfAutoFollowthroughPct` defaults to **15%** and accepts integers **1–100**; invalid input fails initialization. It is independent of the reference indicator's fixed 55% quality classification and does not change detection, analog calculation, chart history or the forecast journal parameters. Auto trading requires an available active forecast, at least six analogs, confidence at or above the selected auto threshold, and, unless `InpCrfRiskBypass=true`, forecast reward/risk of at least 1.2; the separate live-entry reward/risk is also required unless CRF risk bypass is on. Broker and safety checks remain in force. Thus a forecast may show `Below follow-through filter` under the 55% reference while passing the 15% auto threshold. The header shows the selected auto threshold and CRF risk bypass status; the plan and dashboard distinguish reference quality from auto-filter PASS/BLOCKED. A blocked forecast reports the failed auto filter and an unavailable lot. Changing inputs reinitializes the EA; unclaimed pre-restart signals are not replayed as orders.

### 1.5 Active forecast and close events

Monitor only on a **new closed candle**. Stop wins a same-bar stop/target tie.

| Result code | `Last result / update` text | Meaning |
|---:|---|---|
| 1 | `TP estimate reached` | Closed-bar high/low reached TP estimate |
| 2 | `Stop loss touched` | Closed-bar high/low reached stop |
| 3 | `Opposite confirmed reversal` | Fresh opposite confirmed reversal replaces forecast |
| 4 | `Duration limit reached; no extension` | Hard expiry (`remaining <= 0`) |
| 5 | `Replaced by newer signal` | Fresh same-direction confirmed reversal |
| 6 | `No historical estimate` | Confirmation happened but no usable estimate |

| Event code | `Last result / update` fallback text |
|---:|---|
| 1 | `Candidate appeared` |
| 2 | `Forecast confirmed` |
| 3 | `Candidate expired; no confirmation` |
| 4 | `Forecast closed` |
| 5 | `Confirmed reversal; no estimate` |
| 6 | `Nearby pattern ignored` |

Rules:

- One active forecast, one entry, one SL, one TP.
- Old TP is **erased**, never extended or updated.
- Never two TPs. No staged TP, rolling target, indefinite extension, rewriting a closed result, or turning a closed/missed forecast into a win.
- `Data through` = `Last closed candle | chart bar count N`.
- `Last result / update` follows the newest event/result and shows `| this bar` or `| N bars ago`.

### 1.6 Dashboard — 15 rows

Header + 14 rows, left-aligned below the indicator header. In MT: the key fields are mirrored into the **M15 readings/plan/auto rows**; the full 15-row table is available in the separate details window in `CRF only` and `MT + CRF` when `CRF Details` is enabled (default off).

| # | Row | Idle label in confirmed variant |
|---:|---|---|
| 1 | `CONFIRMED REVERSAL FORECAST` + `BUY` / `SELL` / `BUY?` / `SELL?` / `BUY (last)` / `SELL (last)` / `--` | header |
| 2 | `Status` | `Waiting for new confirmed reversal` |
| 3 | `Pattern` | `Last pattern` |
| 4 | `Pending candidate` | `Pending candidate` |
| 5 | `Data through` | `Data through` |
| 6 | `Entry / trigger` | `Last entry` |
| 7 | `Stop loss` | `Last SL` |
| 8 | `TP estimate` | `Last TP` |
| 9 | `Expected move` | `Last expected move` |
| 10 | `Expected duration` | `Last duration` |
| 11 | `Estimate quality` | `Last estimate quality` |
| 12 | `Historical follow-through / samples` | same |
| 13 | `Forecast expires in` | same |
| 14 | `No-signal reason` | same |
| 15 | `Last result / update` | same |

**Important:** `confirmed_reversal_forecast.indie` **retains** `Last entry` / `Last SL` / `Last TP` / `Last duration` / etc. when idle (`historical_view = True`). Keep that behaviour. The PR #8 third file's "blank all level rows when idle" behaviour is **not** ported here.

### 1.7 Plots → MT chart objects

Port the 6 Indie outputs as MT5 chart objects with prefix `MTCRF_`, cleaned up on `OnDeinit` / Mode change:

| Indie plot | MT object |
|---|---|
| Yellow `Reversal candidate (unconfirmed)` marker below bar | small yellow dot / arrow, `offset=-1` |
| Green `Confirmed bullish reversal` marker below | green dot |
| Red `Confirmed bearish reversal` marker above | red dot |
| Aqua `Forecast entry` steps | horizontal aqua line |
| Red `Forecast stop loss` steps | horizontal red line |
| Yellow `Forecast TP estimate` steps | horizontal yellow line |

Step lines must break (not connect) between unrelated forecasts, using separate finite per-signal segments. Rebuild historical objects from available closed M15 data after attachment and restart; process missed bars in chronological order without turning historical confirmations into trades. Indie calculates on the following bar with marker `offset=-1`, so the marker belongs on the M15 candle just processed, not one candle earlier.

### 1.8 Hardening to carry over

- `MathIsValidNumber()` everywhere instead of Python `isnan()`.
- Guarded state-to-int conversions (`0` fallback for invalid/NaN state).
- Finite `price_digits` fallback `5` when `SYMBOL_DIGITS` is unusable.
- Guarded target/move formatting; no `nan` text on the panel.
- Dynamic freshness: `Data through`, `No-signal reason`, `Last result / update` bars ago.
- Sanitize corrupted persisted state on load.

### 1.9 Source-fidelity checklist (audit)

This checklist records the intended mapping of **`confirmed_reversal_forecast.indie`**, not a claim of verified runtime parity. Source checked: `c9bee5bf0154a9eb49e9957a9c6879072ef5b187feabaadb7494c9bf19b4a1ee`, 1568 lines / 88007 bytes.

| Source construct | Spec section | Status |
|---|---|---|
| 3 families / 10 named forms, Doji alone no direction | 1.1 | ✅ exact list, exclusions kept |
| 9 `@param` inputs + defaults/ranges | 1.2 | ✅ exact |
| `minimum_trend_atr=1.0`, `swing_tolerance_atr=1.0`, `confirmation_bars=2`, cooldown `swing_length+2` | 1.2 | ✅ exact |
| prior-trend + swing-location context, volume baseline | 1.2 | ✅ exact |
| raw candidate → close-break within 2 closed bars → expiry / merge / cooldown | 1.3 | ✅ exact |
| same-rule historical analogs, similarity `>=2.0`, spacing `>= max_horizon`, weighted move/duration/follow-through/samples | 1.4 | ✅ exact |
| duration range = weighted mean ± max(1, root(variance)*0.75), round, clamp `>=1`, cap `max_horizon`, **upper range = hard expiry** | 1.4 / 6 | ✅ same formula; MQL5 `MathSqrt` replaces Indie manual Newton root |
| `estimate_available` / `forecast_ready` / 5 quality labels | 1.4 | ✅ exact |
| 6 result codes + 6 event codes, stop wins same-bar tie, no extension | 1.5 | ✅ exact |
| 15-row dashboard, retained `Last ...` idle labels | 1.6 | ✅ exact |
| 6 plots → `MTCRF_*` objects | 1.7 | ✅ exact drawing set |
| NaN / guarded-int / finite `price_digits` / freshness hardening | 1.8 | ✅ exact |

**What is intentionally different:** Signed directions are preserved explicitly as `-1`, `0` or `+1`; do not copy `int(direction + 0.5)` for negative values. Indie conversion behavior has not been verified and the user reports their indicator works, so compare BUY and SELL against actual Indie results before claiming parity. Sections 2–7 are MT5 adaptations (MQL5 state instead of `MutSeriesF`, `CopyRates` instead of `self.close[1]`, broker orders instead of display-only, `30007` diary). Apart from that explicit signed-direction handling, they are not intended to change the forecast logic above. `InpCrfCloseProfitableM15` (Section 2.4) is an **auto-trading-only** rule about an existing MT position; it does not change candle detection, confirmation, analogs, TP/SL/duration or close events.

---

## 2. Mode input (new decision)

This supersedes the earlier "no input / fully automatic" discussion. The mode input is:

```mql5
enum ENUM_MT_CRF_MODE
{
   MT_CRF_MODE_BOTH = 0,   // MT + CRF (default)
   MT_CRF_MODE_MT   = 1,   // MT only
   MT_CRF_MODE_CRF  = 2    // CRF only
};
input ENUM_MT_CRF_MODE InpMode = MT_CRF_MODE_BOTH; // Mode
```

Put it in `MT_CRF_Inputs.mqh`, together with the auto follow-through threshold, CRF risk bypass, and `InpCrfCloseProfitableM15` (Section 2.4, default `true`). Declare the display-only `InpCrfDetails` input after the shared MT inputs in `MT_CRF.mq5`, so `CRF Details` is last in the Inputs tab. Do **not** rename or reorder existing MT inputs.

MT's existing `InpAutoTrading` (default `false`) remains the **real-money master switch**. CRF never sends an order when it is `false`, in any Mode. CRF can still scan and display.

### 2.1 Mode behaviour

| Mode | CRF background scan | MT lanes | New MT orders | CRF orders | Panel |
|---|---|---|---|---|---|
| `MT only` | **Off** | Full, unchanged | Yes, existing rules | **No** | Current MT panel plus the mode badge; no CRF text/objects |
| `MT + CRF` **(default)** | Always, on **M15** closed bars | M5/M30 normal; M15 switches to CRF during takeover | **Only M15 MT entries paused** during CRF takeover; M5/M30 continue; M15 resumes after CRF end + next M15 bar + reconciliation | Yes, in the **existing M15 auto row**, when `InpAutoTrading=true`, `InpAllowAutoM15=true` and the selected auto-trading filters pass | Current MT panel + **2 small header lines**; M15 readings/plan/auto rows show CRF while active |
| `CRF only` | Always, on **M15** closed bars | M5/M30 hidden; M15 row is CRF only | **No MT orders at all** | Yes, in the **existing M15 auto row**, when `InpAutoTrading=true`, `InpAllowAutoM15=true` and the selected auto-trading filters pass | MT header/settings kept; only the M15-shaped readings/plan/auto rows remain, all CRF; optional 15-row dashboard in the separate details window |

**CRF inputs:** `InpCrfAutoFollowthroughPct` (default 15, range 1–100), `InpCrfRiskBypass` (default `false`), `InpCrfCloseProfitableM15` (default `true`), and `InpCrfDetails` / `CRF Details` (default `false`) — see Sections 1.4, 2.4 and 5.3.

### 2.2 Meaning of "MT + CRF"

This is a **temporary M15-lane takeover**, not a 4th trading line and not two robots on M15:

1. MT keeps calculating and showing M5/M15/M30 readings and plans.
2. CRF scans quietly behind on **M15 closed bars** in all modes except `MT only`.
3. On a confirmed CRF forecast that passes the selected auto-trading filters, CRF takes **the existing M15 lane**:
   - request cancellation of the **M15 MT pending limit** only (broker-confirmed, can race a fill);
   - **block new MT M15 entries** until the M15 slot is free; M5/M30 keep their normal rules;
   - if an MT M15 position is already open, apply **Section 2.4**: with `InpCrfCloseProfitableM15=true` and net profit above the internal cost buffer, close it after broker checks; otherwise show `Waiting for closing` and wait;
   - never open a second M15 position; wait for broker-confirmed close + next M15 bar before the CRF order.
4. Only **one CRF position** is opened, displayed in the **M15 auto row** (internally still `MT4-CRF` / `30007`).
5. After CRF ends and the broker confirms no CRF position remains, the M15 lane waits for its next closed bar + reconciliation, then returns to normal MT.
6. CRF immediately goes back to watching behind until the next call.

This keeps MT's existing one-position-per-timeframe design: M5, M30 and (CRF-on-)M15, never four slots.

### 2.3 Mode switch / restart

- Changing `InpMode` reinitializes the EA (MT already does this for input changes).
- Changing `InpMode` itself never closes existing MT open positions. A CRF takeover may close an MT M15 position only under Section 2.4.
- Existing MT pending limits follow MT's existing cancellation rules. During a CRF takeover only the **M15** pending limit is requested for cancellation; M5/M30 pending limits are left alone.
- CRF candidate / forecast / order-link state is persisted in the same per-account/server/symbol journal style as `P4Save()` / `P4Load()`, with a tester sandbox.
- On restart, reconcile with the broker before resuming; do not blindly trust in-memory state.
- `MT only` must not call any CRF scan, draw any `MTCRF_` object, or write any CRF journal row.

### 2.4 New input: allow CRF to close a profitable M15 MT position

This is the **only** extra CRF input besides `InpMode`:

```mql5
input bool InpCrfCloseProfitableM15 = true; // Allow CRF to close profitable M15 MT position
```

Default **true**. You pasted an example line ending in `false`, but your instruction says **default true**; this spec uses **true**. No second input for a manual minimum profit.

When `InpMode = MT + CRF`, a confirmed CRF forecast that passes the selected auto-trading filters finds an **already-open MT-native M15 position** (magic `P4Magic(1)`, comment `MT4-M15`, strategy `30004` / `30006`):

| `InpCrfCloseProfitableM15` | Behaviour |
|---|---|
| `false` | Current safe rule: **never close** the MT position. Leave its broker SL/TP. CRF waits for the M15 slot to free naturally. |
| `true` **(default)** | Compute current profit plus swap and attributable, already-booked position-linked deal commissions and fees, then compare against a conservative remaining-close cost buffer. Reconcile history by `POSITION_IDENTIFIER`; if complete and reliable attribution/costs cannot be established, use REVIEW and do not close. |

`closeCostBuffer` reserves expected remaining exit costs plus one tick of adverse slippage, with spread conservatively covered using `OrderCalcProfit` and the current quote. Booked commission and fees are already included in net and must not be subtracted twice. Do not assume future commission is zero when it cannot be established reliably; REVIEW rather than close. It is **not** a user input.

With `true`:

- **`net > closeCostBuffer`** → request a **market close** of that MT M15 position only if the active CRF forecast also passes the live-entry checks below (including reward/risk unless CRF risk bypass is on). Requires `InpAutoTrading=true`, `InpAllowAutoM15=true`, market open, fresh quote, `OrderCheck`, filling mode and hedging account for the later CRF entry. Wait for `P4PositionClosed()` broker confirmation + next **M15** closed bar; then recheck the still-active forecast and live-entry conditions before any CRF order. Never two M15 positions.
- **`net <= closeCostBuffer`** (negative, zero, or too small after costs) → **do not close**. M15 auto row and 2nd-row `CRF:` line show `Waiting for closing`. Re-check on every new M15 closed bar while the CRF forecast is still alive. If it later becomes `net > closeCostBuffer`, close and open CRF. If CRF hard expiry arrives first, the forecast expires with `Duration limit reached; no extension`; no trade, no extension, no forced close.
- **Ambiguous close / partial close / multiple M15 objects / unavailable history** → `REVIEW`, no CRF order.
- The closed MT trade keeps its `30004` / `30006` diary result. The new CRF trade is `30007`. Do not rewrite the MT result.

**Live-entry reward/risk check:** The historical estimate quality remains based on the confirmation-bar forecast. Separately, before requesting a profitable native M15 takeover close and again immediately before any CRF market order, check the current fresh executable price (Ask for BUY, Bid for SELL) against the original CRF stop and target rounded to the broker tick. Unless `InpCrfRiskBypass` is true, `reward / risk` must still be at least `InpCrfMinRewardRisk` (1.2). The original SL/TP are not moved to improve this ratio. Invalid levels, stale quotes or unsuitable spread also block the action. When the ratio is too low, the status reports `Below live R/R filter`; the EA may recheck while the original forecast remains active. The shared `Bypass Risk` and `Minimum Lot use` do not bypass this check; only CRF Risk Bypass does. CRF risk bypass never bypasses valid SL/TP levels, spread, fresh quotes, broker checks or profitable-takeover cost verification. Actual fills, slippage and costs can differ from the pre-request quote and are not guaranteed by the price-distance ratio.

M5/M30 positions and pending limits are **never** touched by this rule. `CRF only` must reconcile any pre-existing MT positions or pending orders after a mode change or restart; it never closes an MT position under this input and must not enter while the M15 slot is occupied or ambiguous. `MT only` ignores it. `InpAutoTrading=false` blocks the close even when this input is `true`.

---

## 3. What stays unchanged in MT

Do not edit the behaviour of:

- `MT.mq5` Phase 1 header, clock, market state, session table, symbol classification.
- `P2Update()` / `P2Evaluate()` → GT, CT, ST, RG, PT, SC, SG for M5/M15/M30.
- `P3Signal()`, `P3SelectedTrend()`, `P3MarketStyle()`, `P3VolumeState()`.
- `P3GeometryAt()`, `P3ObservedTargetR()`, `P3MakePlanAt()`, `P3MakePlan()`, `P3PlanLine()`.
- `P3Lot()` / `P3Volume()` / 0.5% equity sizing / `Bypass Risk` / `Minimum Lot use`.
- `P4Decide()`, `P4Refresh()`, `P4Place()`, `P4Modify()`, `P4Cancel()`, pending 3-bar expiry, cooldown.
- `MT_Panel.mqh` existing objects, `MT_TradeDiaryRuntime.mqh` schema, strategy IDs `30004` / `30006`.
- `InpAutoTrading`, `InpPlaceStopLoss`, `InpUseAutoSchedule` (09:15–17:00 local), `InpAutoStartTime`, `InpAutoEndTime`, `InpAllowAutoM5/M15/M30`.
- `InpAllowAutoM15` gates both native MT M15 and CRF new entries. When off, CRF does not initiate a takeover or close an MT position for takeover; an already-open CRF position remains managed, including its broker SL/TP and software expiry (subject to the master switch). A disabled signal is not replayed as a new entry when re-enabled. `InpAllowAutoM5/M30` keep working normally.
- CRF respects the shared `Bypass Risk` and the separate `InpCrfRiskBypass`. If either is on, CRF uses the balance ladder (`balance / 1000 * 0.01`) without an MT-score multiplier; if both are off, it sizes from 0.5% equity and the live CRF stop. `Minimum Lot use` takes precedence, and broker volume limits and rounding always apply (including the below-minimum fallback). Only CRF Risk Bypass also bypasses CRF's original-forecast and live-entry 1.2 reward/risk thresholds. It does not bypass follow-through, the six-sample minimum, mandatory broker SL/TP, spread, `OrderCheck`, or cost checks for closing an MT position. It never changes native MT lot sizing or the reference forecast calculations.
- The separate CRF trade diary preserves both flags in the existing binary bypass field (bit 0 = shared bypass; bit 1 = CRF risk bypass) and exports them separately as `bypass` and `crf_risk_bypass`; old rows retain bit 1 clear. Native MT's original diary format is unchanged.
- **One approved exception:** with `InpCrfCloseProfitableM15=true`, CRF may close an MT-native M15 position (Section 2.4). `P4Decide()` for M5/M30 and all other open-position handling stay unchanged.
- All 14 existing test files must still pass.

Only **add** new files plus the smallest possible dispatcher/gate edits.

---

## 4. CRF auto-trading rules

CRF uses MT's safety layer; it does **not** build a second order engine.

### 4.1 Permission chain (all must pass)

1. `InpMode != MT_CRF_MODE_MT`
2. `InpAutoTrading == true`
3. `P4CanTrade()` / hedging account / terminal+EA trade permission
4. `P4ScheduleOpen()` (daily timer) and `P4ScheduleBarReady()`
5. `g_marketState == MARKET_OPEN`
6. `P4FreshQuote()` (broker-anchored, <= 10 s)
7. Spread / `SYMBOL_TRADE_STOPS_LEVEL` / tick-size checks
8. `OrderCheck()` before send
9. CRF auto filters pass: minimum analogs and selected follow-through threshold. Forecast and live-entry reward/risk also pass unless `InpCrfRiskBypass=true`. Valid levels and other broker checks remain mandatory.
10. No existing CRF position, no ambiguous broker state, and the **M15 slot is available** — either free, or an MT M15 position that Section 2.4 allows CRF to close (broker-confirmed first)

### 4.2 Order identity

| Item | Value |
|---|---|
| Comment | `MT4-CRF` (starts with `MT4-`, so `P4Refresh()` ownership check still recognises it) |
| Magic | New dedicated CRF magic, separate from `P4Magic(0..2)` |
| Diary strategy ID | **`30007`** (new; do not change `30004` / `30006`) |
| Broker SL | **Always ON** for CRF orders, even if `InpPlaceStopLoss=false` (that input applies only to MT-native lanes) |
| Broker TP | **Always ON**, exactly one, from CRF |
| Order type | Market at current quote (see 4.3) |
| One position | Strictly one CRF position at a time, displayed in the **existing M15 auto row** (no 4th row) |
| Display slot | Existing **M15** `MARKET READINGS` / `TRADING PLANS` / `AUTO EXECUTION` rows |
| M15 slot rule | Section 2.4: close profitable MT M15 position when `InpCrfCloseProfitableM15=true`; otherwise wait |

### 4.3 Entry price and slippage

- CRF `plan.entry` = **last closed candle close** (`rates[n-1].close`), used for SL/TP geometry.
- Actual market request price = current **Ask for BUY / Bid for SELL**, not the closed close.
- Keep CRF SL/TP as **absolute prices**; do not recompute them from the fill.
- Lot sizing uses `OrderCalcProfit()` with the **actual request price** and CRF stop.
- Record `entry_slippage_vs_original_plan_price` (MT diary already has this column).
- Do **not** place a limit at the closed close; confirmation is a close-break and a limit may never fill.

### 4.4 No fake score

`P4PlanMatchesSignal()` requires `score == ±2 / ±3`. CRF has no MT score. **Do not fabricate one.** Add a separate `CRFPlace()` path that reuses:

`OrderCheck`, `P4FreshQuote`, `P4SpreadOK`, `P4RequestLot`, `P4ProtectionAllowed`, `P4FillMode`, `P5Begin`, journal intent, `P4Persist()`, broker reconciliation and `P4View` status — but validates a `CRFPlan` instead of `P3Plan`.

### 4.5 Exits — broker-confirmed, not candle-touch

The Indie dashboard uses closed-bar high/low for `TP estimate reached` / `Stop loss touched`. In the bot, **takeover ends only from broker-confirmed state**:

| CRF event | Bot action |
|---|---|
| Broker TP fills | CRF ends, record `30007` result, M15 row returns to normal MT |
| Broker SL fills | CRF ends, record `30007` result, M15 row returns to normal MT |
| Hard expiry (`Forecast expires in` reaches 0) and position still open | **Request market close**, wait for broker confirmation, then end. No extension. |
| Opposite confirmed reversal | Close old CRF position, cancel any CRF pending, start **fresh CRF forecast** (do not return to MT) |
| Newer same-direction confirmed reversal | Close old CRF position, start **fresh CRF forecast** (do not return to MT) |
| `No historical estimate` / weak quality | No order; CRF keeps watching |
| MT M15 slot not freed before CRF hard expiry | Forecast expires with `Duration limit reached; no extension`; no CRF order, no forced close, M15 row returns to normal MT |

A dashboard price-touch **alone** never ends takeover while a broker position is still open. After any CRF end, wait for broker reconciliation + next **M15** closed bar before the M15 lane resumes normal MT entries; M5/M30 were never paused.

### 4.6 Bar type guard

MT already has `P3HasBidBars()`. If `SYMBOL_CHART_MODE != SYMBOL_CHART_MODE_BID`, CRF historical replay must be labelled `Bars: Last/unknown proxy` (same idea as MT's `barProxy`) or disabled. Do **not** silently treat Last OHLC as historical Bid quotes.

---

## 5. Panel design

Keep MT's top header always (symbol, market state, clock, trade totals, timer, Bid/Ask). Losing broker status during a live auto trade is unsafe.

**No separate CRF strip and no 4th auto row.** CRF reuses the existing **M15** lane rows.

### 5.1 Two small header additions

| Where | What | Modes |
|---|---|---|
| **2nd row, beside the timer detail** (the row directly under the header) | One line: `CRF: <state>`. If timer detail is hidden, the CRF line still appears on that row. | `MT + CRF`, `CRF only` |
| **Settings box, first row, immediately after `Minimum Lot`** | `Input mode: MT + CRF` / `Input mode: MT only` / `Input mode: CRF only`. Display of `InpMode`, not a new click control. | **all three** |

`CRF:` one-line states:

| State | Text |
|---|---|
| Watching | `CRF: watching M15 closed candles / no candidate` |
| Candidate | `CRF: BUY candidate / waiting confirmation (2 bars left)` — **not** "reversal detected" |
| Active | `CRF: BUY confirmed / expires in 19 bars / Auto ON / order #123` |
| Closed | `CRF: TP hit / SL hit / expired → M15 back to MT` |
| New reversal | `CRF: new SELL confirmed / fresh forecast` (not `→ MT`) |
| Waiting for slot | `CRF: BUY confirmed / waiting for M15 slot (MT position negative or below cost buffer)` |

The chart replay warning says `historical CRF drawings unavailable; retrying`: it concerns rebuilding CRF markers/lines, not MT5 broker trade history. The Experts log identifies the failed history operation, including copied/requested slab counts and errors. Repeated identical failures are logged once while retries continue, with another log when the cause changes or reconstruction recovers. If the M15 series is not synchronized, the EA requests history rather than merely waiting for the synchronization flag. Initial forecast reconstruction and large catch-up are sliced and staged; old bootstrap signals remain display-only, and intermediate catch-up events are not exposed to trading. The legacy full-copy helper retains a 100,000-bar guard, but normal observer bootstrap, large catch-up and chart replay do not use it for full-history requests. The live forecast remains fail-closed if current history is unavailable.

The local rolling cache holds at most the configured analog lookback plus context (625 closed bars with default parameters); when new bars arrive, the oldest fall out. It uses an account/server/symbol-scoped filename, a temporary-file replacement and the terminal's live common-files or isolated tester sandbox. Corrupt/missing cache is ignored and rebuilt. The EA still reads the bounded lookback from MT5 for verification, rather than trusting only a new bar and risking stale corrected history. The rolling file does not currently reduce those reads or speed forecast calculations; restart speed instead comes from the separately persisted forecast state. If overlapping cached and terminal bars differ or disappear, the EA blocks the forecast with a REVIEW reason instead of trading on a potentially stale saved state. The cache is optional and cannot authorize entries or replace the durable forecast/execution journals. A missing or corrupt cache cannot detect earlier broker revisions, and revisions outside its retained window (or outside consecutive replay-slab overlaps) may not be detected. A mismatch requires investigation and safe reconciliation of the forecast/execution journals; simply deleting the cache can hide the warning without correcting stale state. Full chart reconstruction remains separate and covers the closed bars currently accessible within MT5's Max bars in charts setting; synchronization and SERIES_FIRSTDATE do not establish that the broker has delivered its entire server-side history. Initial reconstruction and historical drawings may still need to replay a very large available history, although each event is bounded. This display-only replay does not authorize or block entries; the live forecast still requires valid M15 candle history.

For an eligible confirmation with an empty broker slot, the CRF auto row reports the actual failed entry check (including timer, permission, account mode, quote, SL/TP support, M15 cooldown, lot sizing, fill mode, broker `OrderCheck` code/comment, or a changing quote), rather than claiming the slot is occupied. A timer refresh labels the last tick's failure as the **last entry attempt**; it does not run `OrderCheck` or send orders. If no check has run yet, it says it is waiting for a market tick. An unclaimed restart/catch-up signal is identified as display-only or already used. A rejected request is labelled rejected; an ambiguous request remains awaiting broker reconciliation. These messages do not relax any safety or retry rules.

### 5.2 `MT + CRF` — M15 row takeover

| Panel part | Idle / normal | While CRF candidate or active | After CRF ends |
|---|---|---|---|
| `MARKET READINGS` M5 / M30 | normal MT | normal MT | normal MT |
| `MARKET READINGS` **M15** | normal MT `GT/CT/ST/RG/PT/SC/SG` | `GT/CT/ST/RG/SC = --`, `PT = CRF ~Nb`, `SG = BUY (CRF)` / `SELL (CRF)` / `BUY? (CRF)` | back to normal MT |
| `TRADING PLANS` **M15** | normal MT plan | `M15 / Signal: BUY (CRF) / Pattern / MARKET / Entry / Lot / SL / TP / Expected move / Expected duration / Quality / Samples / Expires in N bars / Auto ON/OFF` | back to normal MT plan |
| `AUTO EXECUTION` **M15** | normal MT M15 row | `M15 / Auto: ON/OFF / CRF OPEN / BUY / broker entry / lot / SL / TP / P/L / TP distance / expires in N / order # / 30007` | back to normal MT M15 row |
| `AUTO EXECUTION` M5 / M30 | normal MT | normal MT (not paused) | normal MT |

Do **not** fake CRF values into GT/CT/ST/RG/SC. `SG` must match the M15 plan card, which is exactly MT's existing rule. `PT` carries the CRF `Forecast expires in` count.

When `InpCrfCloseProfitableM15=true` and the MT M15 position is not profitable enough to close, the M15 auto row shows `Waiting for closing | net ... | CRF BUY confirmed (Nb left)` instead of `CRF OPEN`. With the input `false`, it shows `Waiting for M15 slot` and **never** requests a close.

### 5.3 `CRF only`

- Header + settings stay; `Input mode: CRF only`.
- M5 and M30 readings / plans / auto rows are hidden.
- The **M15-shaped** readings / plan / auto rows are permanently CRF (same fields as 5.2).
- The full **15-row `CONFIRMED REVERSAL FORECAST`** dashboard appears in the separate details window only when `CRF Details` is true; it defaults to false. This also applies in `MT + CRF` mode. `Show diary details` independently controls the diary rows: either switch opens the shared details window for its own content, both show both, and both off remove the window. In `MT only`, CRF details never appear. These switches affect display only, not the main panel, forecasts, trading or diary recording.
- No new MT orders in any lane; `InpCrfCloseProfitableM15` has no effect. Reconcile any pre-existing MT M15 position or pending order and wait for the slot to become free.

### 5.4 `MT only`

100% current MT panel. No `CRF:` line, no CRF rows, no `MTCRF_` objects; `Input mode: MT only` is still shown on the settings first row. `InpCrfCloseProfitableM15` is ignored.

CRF trades still use their own `30007` ledger and `MT4-CRF` comment internally, even though they are displayed in the M15 row. Header `T/A` chips keep their current MT meaning.

---

## 6. Indie → MQL5 mapping

| Indie | MQL5 |
|---|---|
| `self.close[1]`, `self.high[1]`, `self.low[1]` | `CopyRates(_Symbol, PERIOD_M15, 1, N, rates)` with `ArraySetAsSeries(rates,false)`; `rates[n-1]` |
| `self.volume[...]` | `rates[].tick_volume` |
| `self.bar_count` | `Bars(_Symbol, PERIOD_M15)` / `iTime(_Symbol, PERIOD_M15, 1)` |
| — (MT-only) | `POSITION_PROFIT` + `POSITION_SWAP` plus position-linked `DEAL_COMMISSION` and `DEAL_FEE`; reconcile history and remaining costs as in Section 2.4 |
| `MutSeriesF` state | global structs + persisted journal (per account/server/symbol, tester sandbox) |
| `isnan(x)` | `!MathIsValidNumber(x)` |
| `int(state + 0.5)` | signed direction preserved explicitly as -1/0/+1; invalid values fail closed; nonnegative codes use guarded conversion |
| `self.info.price_precision` | `(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)`, finite guard, fallback `5` |
| manual Newton root for variance | `MathSqrt(variance)` (spread `max(1, sqrt(variance) * 0.75)`, round and clamp as source) |
| `round(x, price_digits)` | `DoubleToString(x, digits)` / `NormalizeDouble` to tick grid |
| `color.AQUA/RED/YELLOW/GREEN/NAVY` | MT5 `clrAqua` / `clrRed` / `clrYellow` / `clrLimeGreen` / dark slate |
| `Var[Table]` dashboard | `MT_CRF_Panel.mqh` chart objects, updated on `is_last_bar` equivalent |
| `@param.*` | `input` in `MT_CRF_Inputs.mqh` |
| 6 `plot.*` returns | `MTCRF_*` chart objects |
| `self.is_last_bar` | update panel only on the latest bar / `ChartSupported()` check |

CRF is fixed to **`PERIOD_M15`** closed bars and reuses MT's existing M15 lane. `ChartSupported()` still allows the EA on M5/M15/M30, but CRF always calls `CopyRates(_Symbol, PERIOD_M15, 1, N, rates)` and `iTime(_Symbol, PERIOD_M15, 1)`. **The attached chart timeframe is not the CRF timeframe**: on an M5 or M30 chart the M15 lane still exists, so CRF still works. Attaching to an **M15 chart** is recommended for clarity only, not required. `max_horizon=24` = **6h on M15**; `history_bars=600` ≈ 6.25 days of M15 bars. No other HTF.

---

## 7. Proposed files and minimal edits

New files in `hamamun/MT`:

| File | Purpose |
|---|---|
| `MT_CRF.md` | this specification (placed by user) |
| `MT_CRF_Inputs.mqh` | `InpMode` enum + 9 ported `InpCrf*` inputs + `InpCrfCloseProfitableM15` (default `true`) |
| `MT_CRF_Kernels.mqh` | pure functions: patterns, ATR, context, analogs, duration, formatting; no broker calls |
| `MT_CRF_Runtime.mqh` | state structs, new-bar scan, candidate/confirmation/forecast, persistence, `CRFPlan` adapter |
| `MT_CRF_Panel.mqh` | `CRF:` 2nd-row status, `Input mode:` settings badge, M15-row CRF rendering, full 15-row dashboard in details window, `MTCRF_*` objects |
| `MT_CRF_Diary.mqh` | strategy `30007` rows / CRF-specific fields reusing `P5Begin` style |
| `tests/test_crf_kernels.py` | source-derived stub tests for patterns/context/analogs/duration |
| `tests/test_crf_runtime.py` | candidate → confirm → active → close, restart, NaN/corrupt state |
| `tests/test_crf_mode.py` | `MT only` / `MT + CRF` / `CRF only` gating, takeover, resume, `InpCrfCloseProfitableM15` on/off, net-cost buffer, waiting-for-closing, hard-expiry-before-slot-free |

### Isolation requirement (supersedes the former shared-file edit plan)

- Keep `MT.mq5` and all original MT runtime files unchanged. Start `MT_CRF.mq5` as a copy, and use CRF-specific copies of any shared runtime or panel files that need changes. Unmodified shared includes may be read by both EAs.
- The new EA must fail closed when broker state, execution intent, history, journal or ownership cannot be reconciled. Source-derived tests cannot certify the native compiler or a broker.
- `MT only` in the new EA should reproduce existing MT behavior, while the original EA remains independently usable. Test both independently.
- Account for journal, object, magic and cross-instance ownership collisions. Do not run both EAs simultaneously on the same symbol/account unless safe coordination and broker reconciliation are explicitly implemented and tested. Reconcile existing MT/CRF positions and pending orders across mode changes, restarts and removed EAs; do not infer a free slot from the mode.
- In the CRF-specific copies, add the dispatcher, panel, execution and diary adapters described in Sections 2–6; mandatory CRF SL checks must not depend on `InpPlaceStopLoss`. Never fabricate an MT score for CRF.

---

## 8. Tests and verification

Build acceptance order:

1. All **14 existing** MT stub tests still pass unchanged.
2. New CRF stub tests pass: patterns, context, 2-bar confirmation, candidate expiry/merge, analog weights, duration hard expiry, NaN/corrupt state, three Modes, takeover/resume, no duplicate positions, `InpCrfCloseProfitableM15` on/off, net-cost buffer, waiting-for-closing, hard-expiry-before-slot-free.
3. `MT only` produces identical panel, orders, diary and tests to current MT; `InpCrfCloseProfitableM15` has no effect.
4. `InpCrfCloseProfitableM15` default is **`true`**; with `false`, an open MT M15 position is never closed by CRF.
5. `MT + CRF` default: CRF watches M15; when the selected auto-trading filters pass the M15 slot is obtained (close profitable MT position if allowed, else wait), then one CRF order in the M15 row; only M15 MT entries pause, M5/M30 continue; after broker close + next M15 bar the M15 row resumes normal MT.
6. `CRF only`: no MT orders; M15-shaped CRF rows on the main panel; the full 15-row dashboard is available in the details window when `CRF Details` is true. Test both display switches independently in all modes and when the market is closed.
7. No two TPs, no TP extension, no rewriting closed result, no `nan` text.
8. **MetaEditor compile** of both `MT.mq5` and `MT_CRF.mq5` plus their includes (still unverified today).
9. **Strategy Tester** with real spread/commission/slippage.
10. **Demo account**, then only small live.

Remember: `100% | N samples` is historical follow-through, **not** a win rate and not a guarantee. A chart price touch is not a broker fill.

---

## 9. Decisions already made by this spec

- `Mode = MT + CRF (default) / MT only / CRF only`.
- `InpAutoTrading` stays the real-money master switch.
- `MT + CRF` = CRF temporarily takes over the **existing M15 lane**; M5/M30 keep running. No 4th auto row, no separate CRF strip.
- `CRF only` = CRF sole signal, plan and auto source; only the M15-shaped rows remain; optional full dashboard in details window; MT header/settings kept.
- CRF fixed to `PERIOD_M15` **data**, not the chart timeframe; attached chart may be M5/M15/M30, M15 recommended for clarity only; no other HTF.
- Two header additions: `CRF:` one-line status on the 2nd row beside timer (Modes with CRF), and `Input mode: xxx` on the settings first row beside `Minimum Lot` (all Modes).
- Confirmed reversal active → M15 `SG` = `BUY/SELL (CRF)`, `PT` = CRF expiry, GT/CT/ST/RG/SC = `--`; M15 plan shows CRF entry/SL/TP; M15 auto row shows the CRF broker order.
- New input `InpCrfCloseProfitableM15 = true` (**default true**): with a confirmed CRF forecast, CRF may close a net-profitable MT-native M15 position after broker checks; if not profitable enough, show `Waiting for closing`; if `false`, never close.
- Pending M15 MT limit cancelled at takeover; M5/M30 pending limits untouched; an already-open M15 MT position is handled by Section 2.4, never duplicated.
- After CRF ends, M15 returns to normal MT on the next M15 closed bar + reconciliation; CRF keeps watching until the next call.
- Market order at current Ask/Bid; CRF close kept as plan entry; slippage recorded.
- Hard expiry requests a market close of a still-open CRF position while the master switch and broker permissions permit; no extension. When Auto Trading is off, broker SL/TP remain in force and the software close waits.
- Opposite / newer confirmed reversal starts a **fresh CRF forecast**, not a return to MT.
- Confirmed variant's retained `Last ...` idle labels are kept.
- Force broker SL ON for CRF; `InpPlaceStopLoss=false` applies only to MT-native lanes.
- New diary strategy `30007`; existing `30004` / `30006` untouched.

---

## 10. Explicitly NOT in scope

- `reversal_forecast.indie` (original) and `reversal_continuation_forecast.indie` (PR #8 third file).
- Continuation candles, continuation default-ON, aqua continuation marker, single-state blank idle panel.
- Stage 1 / Stage 2 A/B/C, one-live-row design, separate 4th indicator.
- A separate 4th CRF auto-execution row or a compact CRF strip under settings; the M15 lane is reused instead.
- A second `Minimum net profit` input; the close-cost buffer is computed internally, not user-set.
- Staged/rolling TP, TP extension, indefinite extension, updating an old TP, two TPs, rewriting a closed/missed forecast into a win.
- Extra candle-pattern families, any HTF other than the fixed M15 CRF lane, adaptive/trained expiry.
- Editing the two original `.indie` files in `hamamun/Predictor`.
- Changing MT's `30004` / `30006` diary IDs, `P4Decide()` for M5/M30, or M5/M30 3-lane behaviour. The M15 open-position close in Section 2.4 is the one approved exception.
- Live trading before MetaEditor compile, Strategy Tester and demo verification.

---

**Next step:** compile both EAs in MetaEditor, then verify the isolated EA in the MT5 Strategy Tester and on a demo account. Compare live BUY and SELL forecast values and chart placement against the actual Indie indicator before asserting runtime parity.