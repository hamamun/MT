# MT — Master Trade

Phase 1, appearance. Taken from `SimpleEA/SimpleAdvisor.mq5` (<https://github.com/hamamun/SimpleEA>).

| Setting | Value | Source |
|---|---|---|
| Font | **Consolas** | line 168 |
| Font size | **10** | line 167 |
| Background colour | **`C'48,48,48'`** | line 169 |

The title is drawn one point larger — **11** — in `clrWhite` (line 170).

MT uses the same three.

## Phase 1 — header, row 1

Open:

```text
 MT V1.00 | XAUUSDm | Metal | OPEN | 2026.11.01 11:57:34
```

**Note — when closed, the last cell shows the next opening time instead of the running clock:**

```text
 MT V1.00 | XAUUSDm | Metal | close | Open at 2026.11.01 11:57:34
```

| Cell | Content |
|---|---|
| `MT V1.00` | name and version |
| Symbol name | the broker's own spelling |
| Symbol type | Forex / Metal / Index / Energy / Crypto / Stock / Other |
| `OPEN` / `close` | market state |
| last cell | while open: server date and time, ticking every second. While closed: `Open at` and the next opening time, from the broker's session table |

56 characters open, 65 closed — **about 448 and 520 px** at 10 pt.

The box is sized to the **widest** of the two states, so it never resizes when the market shuts.
The date and time are fixed width, so nothing shifts as the seconds change.

If the broker publishes no table there is no opening time to count to, and the cell says so
rather than inventing one:

```text
 MT V1.00 | BTCUSDm | Crypto | close | Open at --
```

**Note — the panel reserves space for three more rows below row 1, always, whether or not they are
filled.** Row 1 is the header; rows 2, 3 and 4 come next, each specified in its own step. The box
height is fixed at four rows so the panel never resizes as those rows come and go:

```text
 row 1   header
 row 2   reserved
 row 3   reserved
 row 4   reserved
```

## Phase 1 corrections

These corrections override the fixed-size and closed-state descriptions above:

- No user inputs; retain the specified appearance internally.
- Measure the displayed text and dynamically size the panel width and height. On supported charts, reserve three header rows followed by the three timeframe rows; use a two-line notice panel on unsupported charts.
- Follow Automate's market-state information: show the next scheduled opening and time remaining when closed; distinguish unavailable, disconnected, stale, and unknown states. Do not invent a next opening without a session table.
- On charts other than M5/M15/M30, show SimpleEA's `Incompatible chart. Switch to M5/M15/M30.` notice.
- Use broker-stamped quote time for the chart's symbol when available and describe extrapolated time honestly; MT5 cannot guarantee a perfectly synchronized clock between ticks.

**Phase 1 status: Done.** On supported charts, preserve three header rows: row 1 is the header, row 2 is blank while open and carries closed/abnormal details when needed, and row 3 is reserved. The three Phase 2 timeframe rows follow these header rows; clock guidance is not displayed in row 2.


## Phase 2 — final specification

Phase 2 displays trend detection, regime, score and the agreed approximate reading and score-duration estimates. It does not introduce orders or trading.

For the chart symbol, calculate both readings independently on each supported timeframe (M5, M15 and M30):

- **Global trend:** Automate's normalized regression-slope trend, applied to that timeframe's own closed bars. "Global" means the broader recent trend of that timeframe, not one shared M30 trend or the trend of the entire market.
- **Current trend:** SimpleEA's adaptive Precision Trend reading, applied to that timeframe's own closed bars. It is intended to provide a more responsive perspective; it is not guaranteed to be faster or more accurate in every condition.
- Keep both readings visible even when they disagree. Use closed bars and distinguish missing data from a genuine neutral result.
- Use **ST** (Status) instead of the user-facing word "Vote" for the combined view. The exact agreed rules are specified below; indicator agreement is not a calibrated probability.

Timeframe priorities for future use: M5 gives current trend priority, M15 gives the combined status priority, and M30 gives global trend priority alongside the status. These are intended priorities, not permission to trade or to hide a conflicting reading.

Use standard internal defaults without user inputs, adapting to the symbol's own recent movement where the chosen mechanisms support it. A future diary may record observations and inform bounded automatic configuration; it is not required for Phase 2 trend readings and must not be treated as already validated or implemented.

### Compact display layout (final)

On supported charts the three header rows remain above the M5, M15 and M30 rows. Size the panel to contain all content, and split long text into short chart labels so the score and market details are not truncated. Unsupported charts retain their two-line notice.

Each timeframe row uses **GT** = Global Trend, **CT** = Current Trend, **ST** = Status, **RG** = Regime, **PT** = Prediction Trend and **SC** = Score. ST remains the combined trend status. RG uses SimpleEA's regime mechanism. Show `WAIT` for RG when its required history is unavailable or invalid, and `--` for PT when its estimate is unavailable; do not invent a reading.

Illustrative layout, not validated output:

```text
M5  | GT: UP   | CT: DOWN | ST: CONFLICT | RG: WAIT | PT: --  | SC: -1/3 (--%L)
M15 | GT: UP   | CT: UP   | ST: UP       | RG: WAIT | PT: ~3b | SC: +2/3 (50%L)
M30 | GT: DOWN | CT: DOWN | ST: DOWN     | RG: WAIT | PT: ~0b | SC: -3/3 (past est.)
```

### ST — final combination rules

| GT and CT | ST |
|---|---|
| Both UP | UP |
| Both DOWN | DOWN |
| Both FLAT | FLAT |
| One UP and one DOWN | CONFLICT |
| One directional and one FLAT | MIXED |
| Required reading unavailable | WAIT |

These rules describe agreement, not regime or confidence; CHOPPY belongs to RG. SimpleEA's existing current trend uses the filter's sign, so CT is FLAT only at zero unless a separate meaningful neutral band is subsequently agreed. No such band is finalized here.

### SC — SimpleEA score selected

Use SimpleEA's actual score on each timeframe's closed bars: the sign of the adaptive Precision Trend (CT), the ATR-deadbanded rate of change of that filter, and the ATR-deadbanded recent net move with confirmed swing-structure checks. Each component contributes +1, 0 or -1; SC is their sum from -3 to +3. Preserve SimpleEA's standard internal calculation and parameters, without user inputs. GT, ST, RG and PT are separate context and do not silently alter SC. The components share price data, so SC is not a calibrated probability or a guarantee of trade outcome. Show WAIT if a required component is unavailable.

The user intends SC to become a foundation for future entry, TP, SL and trading decisions. Those trade-plan, execution and risk rules are not yet agreed, and adopting SC does not authorize trading in Phase 2. The separate score-duration estimate and life percentage below must not be confused with PT or presented as an unvalidated probability.

### SC life — final percentage and reset rules

Show the estimated share of the exact signed score's life remaining next to SC, for example `SC: +3/3 (50%L)`. It is a countdown derived from an estimated duration, not the actual fraction of an unknown future lifespan, a probability of score persistence or a probability of a successful trade. It is independent of PT: a CT, ST or GT state can continue while SC changes, and vice versa.

On the first closed-bar change to any different exact signed score, including `+3` to `+2` and to or from zero, begin a new score run and calculate a fresh age-conditioned estimate. On attachment during an existing run use its current age. Reconstruct comparable past runs of the same exact signed score, symbol and timeframe from closed broker history. Use the median remaining duration of at least 20 comparable past runs that reached the current age, including runs ending at that age (zero remaining). Do not treat incomplete runs as complete or use future data; replay the adaptive score causally at each historical point, with sufficient warm-up. The minimum is a safeguard, not proof of accuracy. No AI training or waiting for new live outcomes is required.

At the time an estimate is established, record the current run age `A` in closed bars and estimated remaining bars `R`. The estimated total life is `A + R`. Hold that basis while the score stays unchanged, reduce the remaining count by one on each subsequent closed bar and display `100 × remaining / (A + R)`, rounded to the nearest whole percent. Show `<1%L` if the positive remainder rounds to zero. For example, age 3 with 3 estimated bars remaining gives `50%L`. At the estimated end, show `~0%L`; if the score continues on a subsequent closed bar, show `past est.` until it changes, not a negative value or a claim that the score has ended. If the score itself is unavailable show `SC: WAIT`; if only its duration is unavailable, retain the score and show `--%L`. If sufficient history becomes available mid-run, establish the estimate using the then-current age. Preserve a valid countdown across restart when possible after verifying no score change occurred.

### RG — SimpleEA regime selected

Use SimpleEA's Hurst-based regime mechanism and default labels STEADY, MIXED and CHOPPY, calculated from closed price data. Hurst estimates above 0.55 are STEADY, below 0.45 are CHOPPY, and the interval between them is MIXED. Its standard span is 128 hours of nominal bars: 1,536 M5, 512 M15 or 256 M30 bars, with actual elapsed time affected by gaps and sessions.

Ignore SimpleEA's M5-borrows-M15 behavior entirely. Each timeframe calculates its own RG from its own closed bars, with no borrowing and no substitute calculation. GT and CT likewise remain independent per timeframe. RG is descriptive only; no ADX or additional regime indicators are required, and no entry or trading permission is implied.

MT must actively request and load sufficient history for each symbol and timeframe from the MT5 terminal/broker, including the complete Hurst window and the history needed by GT, CT, SC, PT and score life. Do not rely on the chart already having loaded that history. The expectation is that the terminal typically provides years of history; request the required bars and retry if downloading or synchronization is still in progress. Do not silently shorten the regime window or substitute MIXED, 0.5, another timeframe, or a different calculation when history is incomplete or invalid. Show WAIT for the affected reading until sufficient valid data are actually available. Broker history, terminal settings and downloads may limit availability despite the expectation of deep history; MT must handle this honestly rather than assume a request succeeded.

### PT — final duration direction

PT is an approximate remaining duration of an MT reading, not a promise of a market reversal time. Estimate M5 from CT, M15 from ST, and M30 from GT, in line with their agreed priorities. Each relevant state change (including UP, DOWN, FLAT, MIXED or CONFLICT where that reading supports it) starts a fresh estimate for the new state; unavailable history must not be presented as a real estimate.

Use age-aware historical runs of the same selected label, symbol and timeframe, reconstructed causally from existing closed broker bars; no AI training or accumulation of new live outcomes is required. Use the median remaining duration of at least 20 comparable past runs that reached the current age, including runs ending at that age (zero remaining). This provisional minimum is not a guarantee of reliability. Avoid future-data leakage and do not treat partially observed runs as complete. When the selected state starts, calculate an approximate remaining duration and hold that estimate as the basis for a visible countdown, decreasing by one for each subsequent closed bar while that state remains unchanged. If attached during an existing state, calculate from its current age. When the selected state changes, immediately calculate a fresh estimate for the new state. Include runs that end at the current age, so a zero estimate is possible; do not display an unvalidated probability.

The countdown is an estimate, not a guaranteed deadline or prediction of the next state. At zero, show `~0b`; if the selected state continues past that estimate, show `0b+` until it changes instead of going negative, hiding PT, or claiming the trend has ended. If sufficient valid history is unavailable, show `--`; an estimate may appear when adequate history becomes available. Preserve a valid countdown across restart when possible, verifying historical state changes before restoring it. The event is the first change of the selected reading, including to a non-directional state. The estimate must be validated against historical outcomes; it is not guaranteed to be accurate.

Retain dynamic panel sizing and the Phase 1 market-state details; the final layout must accommodate closed or abnormal states without hiding their information.

**Phase 2 status: Complete.** Trend detection, compact layout, ST rules, per-timeframe SimpleEA RG, SimpleEA SC, PT and the separate score-life percentage and reset rules are implemented. MT requests required history; insufficient or invalid readings are WAIT, unavailable duration estimates are `--`, and no fallback regime is permitted. Phase 2 is informational and does not authorize trading.

**Verification note:** Automated source-level regression tests passed. The user reported a MetaEditor build with zero errors and one warning; the warning has been addressed in the source, but a subsequent MetaEditor compilation has not been confirmed. Live MT5/broker runtime validation has not been confirmed. Completion does not imply that the duration estimates or trading outcomes are validated.

## Phase 3, Part 1 — agreed specification

**Status: initial implementation integrated; verification pending.** Part 1 is an informational plan, not authorization to send orders. The user delegated the detailed entry, SL and single-TP formulas and fallbacks for research, design and testing; initial rules are implemented but are not yet out-of-sample validated. This specification does not change the completed Phase 1/2 implementation.

### Display and signals

Show three independent plans for the chart symbol, one each for M5, M15 and M30, while retaining the Phase 2 readings and dynamically sized panel. Each plan shows `Signal: BUY/SELL/NONE`, entry type and price, lot, SL price and estimated monetary loss, and **one** TP price and estimated monetary gain. Show current Bid and Ask on the panel for eventual autotrading use. The panel layout includes separate plan and diary rows.

Each timeframe has a `Trend to follow` input with four choices: `Auto` (default), `Follow CT`, `Follow GT`, and `Follow ST`. In Auto, the selected reference is M5 CT, M15 ST and M30 GT. The originally agreed aligned BUY rules are:

| Timeframe | Aligned Auto condition |
|---|---|
| M5 | CT UP and SC at least +2 |
| M15 | ST UP and SC at least +2 |
| M30 | GT UP, SC at least +2, and ST not CONFLICT |

SELL reverses UP/DOWN and requires SC at most -2. The user subsequently requested a separate `Allow buy/sell against trend` Boolean for **each** timeframe, default **true**. When false, an opposing selected directional trend must not be accepted; the Auto conditions above describe the aligned case. When true, an opposing selected directional trend must not, by itself, prevent a score-qualified signal: for example, selected GT UP with SC -2 can indicate SELL. Thus the original aligned conditions cannot be treated as an unconditional default veto when the new switch is true. Preserve the score threshold and do not silently replace a SELL with a BUY, or vice versa.

For a score-qualified M30 countertrend signal, the original Auto ST CONFLICT guard cannot be used to veto the signal when the new M30 switch is true; otherwise the switch would not allow that countertrend case. The guard was redundant only in the originally aligned M30 rule with the current score formula. For a valid non-directional selected reading (FLAT, MIXED or CONFLICT), use the score direction when `Allow buy/sell against trend` is true; when false, require a matching directional selected reading and otherwise show NONE. A required unavailable reading is not a valid neutral reading and must be handled as unavailable, not silently converted into FLAT. `NONE` means valid readings but no qualifying direction; missing required readings are not the same as NONE.

### Entry

For a directional signal, score +3/-3 selects market entry only when closed-bar volume is confirmed or unavailable; weak volume selects a limit. A market BUY references the captured post-close Ask and SELL the captured post-close Bid. Score +2/-2 selects a calculated BUY LIMIT/SELL LIMIT. The user requires an entry proposal when a signal exists; absence of a preferred swing alone must not cause plan WAIT or a switch to market. The initial implementation uses a structure-based level with a calculated fallback based on the same timeframe's recent movement; the method remains subject to validation. Entry must account for tick size and broker distance requirements. If essential quote or symbol information is truly unavailable, do not fabricate a usable price; retain the signal and indicate the missing data. Limit entries may not fill and quotes can change.

### SL and single TP

Part 1 uses **one TP only**, not SimpleEA's TP1/TP2/TP3 ladder. Research and define a structure-aware SL and a target based on achievable historical price movement for each timeframe. M5 is intended for comparatively short scalping opportunities; M15/M30 are intended to accommodate longer moves, but arbitrary distances and guaranteed ordering across timeframes are not approved. Avoid blindly copying ATR multipliers, SimpleEA thresholds, or a fixed reward/risk ratio. An initial historical-observation method uses already available closed bars, with no training or wait for live trade outcomes. It still requires out-of-sample tests including costs and limit non-fills; the rules and fallback behavior are not yet validated.

### Lot and risk

Normal sizing targets **0.5% of account equity per plan**, so three simultaneously active plans target approximately 1.5% combined, not 0.5% combined. Round down to a permitted broker volume; if the calculated size is below the symbol's minimum, still advise the broker minimum instead of blocking the signal. Do not show a separate risk-over-budget warning. Broker volume maximum and step also apply. Actual losses may exceed estimates, including through slippage, gaps, costs or the minimum-lot exception.

The user requested `Bypass risk` as a Boolean input, default false, and delegated the necessary bypass sizing calculation to MT, suggesting SimpleEA as a reference. The selected initial internal bypass policy is SimpleEA's balance-based ladder: 0.01 lot per 1,000 account-balance units, multiplied by 1.5 at absolute score 3 before broker-volume normalization. This does not apply the 0.5% SL risk budget; verify symbol, currency and volume handling during development. The user also confirmed `Minimum lot use`, Boolean default false: when true, always advise the broker's symbol minimum, overriding normal or bypass sizing even when the calculated lot is larger. This forced-minimum input is separate from the automatic broker-minimum fallback, which applies in either mode. No separate risk or mode warning is requested; future header input visibility is a separate later task.

### Monetary figures and verification

Estimate entry-to-SL loss and entry-to-TP gain for the calculated lot in the account's actual currency (USD where applicable), using MT5 symbol/contract information, for example `OrderCalcProfit`. Label them estimates; costs, slippage, gaps, conversion changes and execution differences can affect actual outcomes. A plan is informational and does not guarantee broker acceptance or trading profitability.

An initial signal, price-plan and sizing implementation is now connected to `MT.mq5`. The closed-bar target replay and fallback are initial research choices; independent out-of-sample validation and actual MetaEditor/MT5 verification are still outstanding.

### Delegated entry and exit research

The user delegated the design and testing of the entry, SL and single-TP calculations, including fallbacks, to MT, with SimpleEA as an important reference. Develop toward more achievable entries and TP while avoiding unnecessary blockers. Prefer a valid confirmed pullback level for score-2 limit entry and research a fallback from recent closed-bar pullbacks on the same timeframe. For SL, consider a confirmed invalidation level with a spread/tick buffer and a recent-price-movement fallback if structure is unavailable. For the single TP, study comparable historical favorable movement before SL, current opposing structure and costs. These are research directions, not finished formulas: define sparse-history behavior and feasibility safeguards and test out of sample. No training or live outcome accumulation should be required.

### Relationship between trend readings and score

The current score is CT sign plus two separate -1/0/+1 components. Thus CT FLAT allows at most an absolute score of 2; GT FLAT can coexist with an absolute score of 2 or 3. ST FLAT (both GT and CT FLAT) can coexist with an absolute score of 2, not 3. ST MIXED can coexist with 2 or 3 when CT is directional and GT FLAT; if CT is FLAT, the maximum is 2. ST CONFLICT can coexist with 2 or 3, but a qualifying score must have the same direction as CT and therefore oppose GT. These are properties of the current formula, not independent evidence or guaranteed trade outcomes.

## Phase 3, Part 2 — actual-market signal diary

**Status: initial implementation integrated; verification pending.** The user wants a diary collecting MT5 analytical data for possible future self-tuning once sufficiently mature. Part 2 does not place orders or automatically tune parameters. On the panel show today and all-time signal/win/loss counts for each M5, M15 and M30 lane of the current symbol. `Show details` is Boolean, default false, and controls detailed visibility only; recording continues when details are hidden.

### Source and outcomes

The user explicitly rejects virtual trading and wants **actual observed market data**, not fabricated or simulated price paths. Part 1 has no order execution: a diary win or loss therefore means an **observed plan/price outcome**, not profit or loss of a broker-executed trade. Use actual broker quote/tick data after a signal plan is recorded; for limit entry record whether the executable-side entry price was touched, not that an order filled. For market plans record the actual available quote used as the indicative entry. Track the appropriate market side for the symbol and direction, and only record an SL/TP outcome after an observed or reliably reconstructed entry event. Label uncertain, incomplete, unfilled and still-open cases separately; do not silently turn them into wins or losses. Missing ticks, restart and ambiguous ordering must not lead to invented outcomes. Specify recovery and tick-coverage safeguards before implementation.

If actual trading is added later, broker orders, deals, fills, realised P/L, commissions and slippage must be separately identified and reconciled; an observed price touch is not itself a broker execution.

### Counting and display

- Scope the records to the current symbol, broker/account and timeframe, so unrelated symbols and accounts are not pooled. Compare instruments separately before considering broader analysis.
- Today uses the broker-server calendar day. Count signals on the day of the signal, wins and losses on the day of resolution; overnight outcomes may make these daily numbers differ. All-time means since reliable diary collection began, not an invented pre-diary history.
- Record uniquely identified signal ideas, not every tick or panel refresh; freeze the original planned entry/SL/TP and context so later panel updates do not rewrite what was evaluated. The initial rule records a new idea when the direction changes or returns from NONE. A continuing direction is not re-counted. A pending observation expires when its signal changes or becomes NONE; an already entered observation continues to its frozen target or stop.
- Keep awaiting-data, unfilled/pending, open, expired, unavailable and unknown outcomes distinguishable; do not count them as wins or losses. These outcomes are never silently counted as wins or losses.

### Detail data, persistence and future analysis

Record enough context for later analysis, including signal timestamp, timeframe, direction, score and GT/CT/ST/RG, entry type and planned prices, lot, spread and relevant settings, observable entry/exit events, price outcome, time-to-event, costs where actually known, strategy version and data quality. Do not claim fees or actual broker executions for observational records. Store summaries/events rather than an unbounded tick stream by default.

Use durable versioned storage with safe writes and restart recovery. Prevent duplicate records and conflicting writes when multiple charts run; isolate account/symbol and live/tester records. Preserve unreadable, ambiguous or incomplete data rather than overwriting or fabricating a result. `Show details=false` must not stop collection.

The diary is intended to support future per-symbol/timeframe and regime analysis and possible self-tuning after sufficient evidence. Automatic adjustment is a separate later design: research measurement quality and costs, forward/out-of-sample evaluation, evidence requirements, bounded changes and rollback. No specific tuning policy or automatic changes are approved yet. Part 1 signals do not need to wait for diary maturity.

### Implementation progress and remaining verification

The initial implementation now connects the plan and observed-quote diary to the panel and inputs. The limit fallback uses the median recent opposite-direction bar move when no valid pivot is available; the stop uses confirmed structure or a recent-move fallback. The TP uses the median risk-normalized pre-stop excursion of at least 20 completed same-score bar analogues (4/6/8-bar horizons), or recent movement if unavailable, with opposing structure used where compatible with broker constraints. Replay uses closed-bar spread proxies and conservative same-bar ordering, not actual fills. It is applied only when MT5 reports Bid-based bars; Last or unknown bar-price types use the recent-movement fallback and display a Last/unknown proxy label. Current-chart pivots from such bars are technical proxies, not reconstructed Bid history. These policy choices are not out-of-sample validated.

The diary counts one new idea when the signal direction changes or returns from NONE; a continuing signal is not counted repeatedly. If a plan or tick snapshot is unavailable at signal time, the record is AWAIT DATA and may activate later using the current frozen plan and actual observed start quote while the signal direction remains current. A market reference and its later observation start quote are recorded separately; the start tick is also checked for exit and limit touches. Original signal context/time and later plan context/start time are stored separately; no earlier touch is inferred. Awaiting and frozen pending observations expire when the lane signal changes or becomes NONE; already entered observations continue independently. Open and pending observations are marked UNKNOWN after restart (including MT5 input changes), disconnection, detected tick-history gaps or a tick-history endpoint that does not match the sampled quote; outcome tracking uses available actual broker ticks and does not claim broker fills. Live diary storage uses a per-account/server/symbol single-writer lock, versioned binary snapshot and separate tester storage. Version-3 and version-4 records migrate to version 5; version-3 Bid/Last bar provenance remains unknown. `Show details` shows the latest recorded observation per lane.

Automated C++ stub tests exercise plan kernels/runtime, panel and diary kernels/runtime including file corruption and restart. Tree-sitter grammar parsing has passed, but neither is native MQL compilation or live-broker verification. Actual MetaEditor compilation, tick coverage, file locking/persistence behavior, account conversion and out-of-sample strategy performance require confirmation before this phase can be called verified.

## Phase 4 — broker-executed auto trading

**Status: initial implementation integrated; native verification pending.** The `Auto Trading` input defaults to false. When true and broker/MT5 permissions permit, MT uses each timeframe's existing signal, score, plan and lot policy to request a broker market order at ±3 unless closed-bar volume is weak, or a limit order at ±2 or weak-volume ±3, with one broker-side SL and one TP. `OrderCheck` is used before submission. A separate M5/M15/M30 auto section above the diary shows broker-confirmed OPEN or LIMIT, direction, entry, lot, SL/TP and gross estimated amounts in USD. A limit also shows the price distance from BUY Ask or SELL Bid; negative distance means the level has been passed. Amounts are calculated via `OrderCalcProfit` in account currency. USD accounts need no conversion; otherwise a fresh selected direct/inverse Forex pair is used with the appropriate Bid/Ask, or `-- USD` is shown. This is not a commission-inclusive or realized amount.

The user chose one active order/position per timeframe; after broker records confirm a position has closed or a pending order has ended, a replacement in either direction waits for the next own-timeframe bar close and the new plan. Requests are throttled per lane to five seconds, and new entries require a symbol quote no more than ten seconds old by the broker-anchored clock. A change to NONE, WAIT or the opposite direction requests cancellation of that lane's unfilled limit. A same-direction market upgrade also requests cancellation, without an immediate replacement. A new own-timeframe plan may modify a suitable pending entry, SL and TP after broker checks and confirmation. Turning the input off stops new entries and requests cancellation of MT's pending limits, without closing open positions. Cancellation intent remains active until broker confirmation. A partially filled position stays open and its unfilled entry remainder is requested for cancellation. An owned pending order found without SL or TP is requested for cancellation; an open position missing either is flagged for review without automatically closing or modifying it. If MT5/broker permissions or a rejection prevent cancellation, it stays pending rather than being falsely reported cancelled. Removing the EA or using an unsupported chart stops active management, without closing positions or automatically cancelling pending orders.

Following SimpleEA for account mode only, new entries require `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`; netting/exchange accounts are held. No SimpleEA target ladder or alternative sizing policy is imported; the later closed-bar volume rule is documented below. Distinct lane magic numbers and journalled broker order/position IDs identify MT's own objects. Untracked or multiple same-lane objects are held for review; no automatic management of other/manual trades is intended.

The executor uses a versioned pre-send intent journal and account/server/symbol single-writer lock in Common Files, with a separate Strategy Tester sandbox. It checks broker results and current order/position identities, verifies final order state and deal history before re-entry, and retains ambiguous requests rather than blindly retrying. A partially cancelled order without a visible position ID is not treated as unfilled unless order history supports that conclusion. New entries require broker-reported support for the requested order type, SL and TP, and a GTC stop-lifetime mode preserving protective levels across days. DAY-only symbols and daily deletion of protective stops are held rather than assuming protection; pending orders use GTC, though a broker with daily pending-order expiry can still remove them. Unsupported filling modes are held. Market deviation is 10 broker points, and broker rejections, unavailable permissions and missing data remain possible. FileMove durability, broker history synchronization and lock semantics require native testing. Only the instance holding the lock manages that account/symbol; another instance shows the coordinator unavailable until reinitialized. The common-file lock does not coordinate machines that do not share that storage; concurrent copies on separate machines are not supported.

The Phase 3 diary continues to count observed quote touches, not broker deals or actual executed P/L. Phase 4 shows actual broker order/position state but does not claim to have added a broker-deal profit diary or automatic tuning. The source-derived C++ tests include disabled/default, hedging versus netting, three lanes, preflight, cancellation, same-signal re-entry, partial fills, cancellation/fill races, restarts, ambiguous results, untracked objects, file failure, USD conversion, expiry/filling modes and tester connectivity. Tree-sitter parsing and stub tests are not a native compiler or a live broker. MetaEditor compilation, MT5 Strategy Tester/demo behavior, broker-specific order/deal synchronization, locking and persistence, and out-of-sample strategy performance remain unverified.

## Auto-row status and broker reconciliation

Each timeframe's auto row now includes ON/OFF even while an order, position or REVIEW is present. Empty, reconciled lanes show the signal or current preflight blocker; a qualifying plan awaiting a tick is not presented as if an order were sent. Hovering any segment gives a status explanation. Broker check and definite rejection codes remain visible across timer refreshes for the current lane/plan, until a fresh attempt or plan change. Pending cancellation reasons and missing-exit warnings remain visible together. These are status improvements, not confirmation that the broker accepted a request.

When a final historical order reports no position ID, MT checks its entry deals to recover the position ID and then requires the order fill volume and complete matching position entry/exit volume. A live position can likewise be linked by its entry deal. If a saved historical order cannot initially be selected, MT explicitly requests broker history and retries; history lookups are paced per lane. Nonfinal orders, missing tickets, mismatched identities, incomplete or ambiguous history and unconfirmed partial fills continue to hold the lane for REVIEW; no broker record was available here to identify the user's specific REVIEW cause. The implementation and tooltips require native MetaEditor and live/demo broker verification.

## Re-entry on the next timeframe bar

After MT confirms a pending limit has ended, or that an open position has closed, it waits for the next close of that lane's timeframe before placing a new limit or market order in either direction. The new plan must still qualify and pass all broker and live-quote checks. A filled limit remains an open position and is never replaced while open. If a bar closes before broker confirmation, the wait starts from confirmation and requires the next close; a definite unfilled request rejection instead follows the normal retry pacing. The per-lane wait is journalled across restart. An eligible lane displays `Waiting for next closed bar`; another active blocker or an unresolved broker record is shown instead. Manual or other confirmed position closures use the same conservative wait. Existing pending repricing and the three-bar expiry remain in force.

## Closed-bar plan snapshots

Each lane captures the first valid quote observed by the EA on a chart tick after its own latest bar closes and freezes its priced plan until that lane closes another bar. The entry, SL, TP, lot and displayed estimates use closed-bar structure and the captured Bid/Ask and spread, not pure OHLC alone. On attachment/reinitialization or after missed/coalesced ticks, that quote may be later than the broker's first post-close tick; snapshots are not persisted. Late history uses the original captured quote. A priced snapshot with unavailable sizing stays unavailable until the next bar or reinitialization. A same-bar history retry that changes the signal/type holds the incompatible plan, rather than repricing it. Missing quote/history remains unavailable, not invented.

Auto trading and the diary follow live ticks separately. Before placing an order, the EA checks the frozen levels against the live quote and broker stop distance, then runs `OrderCheck`; invalid levels are held without chasing. A market request uses the live Ask/Bid and can fill differently from the reference, with different actual risk. A suitable pending order can be modified to the new lane plan; only broker-confirmed levels are authoritative, and open positions' broker-side exits remain unchanged. The auto rows display confirmed broker state. These changes require native MetaEditor, MT5 tester and demo-broker verification.

## Pending limits — cancel on WAIT

**Implemented; native verification pending.** When a timeframe's signal is WAIT (unavailable or uncertain), MT requests cancellation of that timeframe's owned pending limit, instead of leaving it pending. Keep cancellation intent until broker confirmation, preserve the existing ownership/reconciliation safeguards, and do not close an already open position. If trading or the connection is unavailable, cancellation cannot be assumed successful; retry when possible. Policy/runtime stub tests cover this behavior; MetaEditor and broker testing remain necessary.

## Pending-limit management changes

**Implemented; native verification pending.** These requirements supplement the WAIT cancellation behavior above.

1. **Refresh on a new plan:** When a lane's own bar closes and its new plan is still suitable for an existing pending limit, manage that limit like SimpleEA: consider updating the pending entry, SL and single TP to the lane's new plan rather than automatically leaving the old prices unchanged. Validate against live quotes and broker restrictions; never claim a requested modification succeeded before broker confirmation. If a safe modification cannot be confirmed, handle it conservatively and request cancellation when appropriate. Preserve protection, ownership, persistent intent and reconciliation safeguards, including modification/fill/cancellation races and restart recovery. Keep the actual broker values separate from the displayed plan. Already-open positions and their broker-side exits are not modified by this pending-order rule.
2. **Upgrade from limit to market:** If the same-direction signal strengthens from a limit plan to a market plan, request cancellation of the old limit, as SimpleEA does. Do not immediately replace it: reconcile the broker order/any fill first and allow a new order only on a later fresh close of that lane's own bar, if the signal and all other requirements still qualify. Retain sticky cancellation and partial-fill protections.
3. **Unsuitable spread or plan:** Add SimpleEA-like protection for owned pending limits when current spread or the pending plan becomes unsuitable/HOLD; request cancellation rather than leaving an unsafe entry. Use live quotes for the spread check and closed-bar data for structural plan changes. Define and test the exact suitability checks for MT's one-target plan, symbol constraints and existing risk/lot rules during design; do not copy SimpleEA's three-target ladder or invent an unsupported cost or probability. Preserve cancellation retry and broker confirmation safeguards.

Pending modification cannot change a broker order's volume: the current pending volume can differ from the newly displayed lot. The implementation accounts for that volume using the revised plan lot and MT's existing minimum-lot and bypass settings, and reconciles modification/rejection/fill races without assuming the new levels or volume were accepted. Further native testing must cover each lane, short-lived spread changes, broker freeze/stop restrictions, persistent journal failures, and restart/offline behavior. No change is requested to the management of manual/untracked orders or open positions.

### Expiry research and approved rule

SimpleEA commit `3e909f7384c179d5241228f40f40e09ab6ebf4ba` uses 3 nominal timeframe periods for normal/trend pending setups and 8 for its explicit range-fade/box setup. Its calculation uses elapsed bar timestamps divided by the period, starting from signal birth when available, otherwise placement; it is not necessarily a count of actual closed candles across weekends or market gaps. MT has a Hurst-based regime label, not SimpleEA's distinct range-fade/box strategy, so a direct 3/8 mapping is not justified. A regime label alone is not proof that a pending order has SimpleEA's box-entry thesis.

Published research finds that limit-order execution times depend on price, spread, size, volatility and market conditions; an FX limit-order study also observes cancellation/revision decisions varying with market and order-book conditions. These studies do not establish the best expiry for MT's symbols, broker, strategy or timeframes: https://web.mit.edu/Alo/www/Papers/JFE2002_Pub.pdf and https://mpra.ub.uni-muenchen.de/70291/1/MPRA_paper_70291.pdf . Quote touches in MT's observational diary are not actual fills, and cancel/fill outcomes are competing events, so the diary alone cannot prove an optimal expiry.

**Approved and implemented:** use an initial maximum of 3 actual completed bars of the order's own timeframe after confirmed placement for all MT pending limits; do not apply 8 merely because MT labels a regime CHOPPY. Count bars available in the symbol's actual history rather than dividing wall-clock time by the timeframe; do not reset the age when an order is modified. Persist the birth/age or reconstruct it reliably after restart; uncertain history must not be treated as proof that the age is zero. At the limit, request cancellation and retain intent until broker confirmation. After any pending cancellation, including expiry or an upgrade, any replacement in either direction waits for a subsequent own-timeframe bar close after broker confirmation. The same wait applies after a position closes, including at TP or SL. This supersedes the earlier exception that allowed an opposite signal immediately after expiry. An expiry caps each pending order's age, not the whole signal's life, so repeated placements on a persistent signal are still possible after that waiting period. Broker expiration, market gaps, EA downtime and fill/cancel races must be handled explicitly; an EA-side check cannot guarantee cancellation while offline.

Before treating any expiry as better, compare no expiry, 3 actual bars and alternatives such as 8 actual bars using broker-confirmed fills, cancellations, partial fills, costs, time-to-fill and later outcomes per symbol/timeframe and regime; use out-of-sample/forward demo testing. Avoid optimizing thresholds from the same data or mistaking a historical touch for a broker fill. Do not implement an adaptive or trained expiry without a separately approved design and sufficient reliable evidence. The version-2 auto journal migrates version-1 records; an existing pending limit with unknown birth is cancelled conservatively, while confirmed open positions remain managed. The pending target must exceed current spread; stale quotes cannot establish a spread violation. Broker order volume is not modified, and a new plan requiring a lower lot is cancelled instead of increasing planned risk. An unconfirmed modification is conservatively cancelled; journaled intent and broker reconciliation guard fill/restart races. A reduced order remainder is requested for cancellation even if its partial-fill position is not yet visible. C++ source-derived tests cover these paths; native compilation, live bar history, file persistence and demo-broker execution remain unverified.

## Closed-bar volume confirmation

Both existing recent-movement fallbacks remain unchanged. For each lane, MT compares the latest completed bar's tick volume against 50% of the average of the preceding 20 bars' positive tick volumes, excluding the tested bar, matching SimpleEA's rule. At least 10 positive baseline bars are needed. When the baseline is unavailable, MT retains the ±3 market choice rather than treating missing data as weak; the plan row shows `Volume: --`. It shows `Volume: LOW` for weak volume and `Volume: OK` for confirmed volume. Volume does not change the directional signal. ±2 remains a limit; ±3 becomes a limit if volume is weak and otherwise remains a market plan. The choice is made for each timeframe's own closed bar and interacts with the existing frozen snapshot: a same-bar historical correction that changes the entry style holds the incompatible snapshot instead of repricing it.

Historical TP analogues match the new entry style using each past closed bar's tick volume and preceding history. Missing volume uses the same market default; volume and spread proxies do not prove execution. A pending ±3 weak-volume limit is not a market upgrade. If a later valid plan becomes market, MT requests cancellation and waits for the next own-timeframe close after confirmation. Open positions remain unchanged. Diary records retain actual plan entry type; new records use strategy ID 30004, while older records remain readable. These changes require native compilation, real-tick testing and broker/demo validation.
