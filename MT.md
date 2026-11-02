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
- Measure the displayed text and dynamically size the panel width and height. Reserve four rows on supported charts; use a two-line notice panel on unsupported charts.
- Follow Automate's market-state information: show the next scheduled opening and time remaining when closed; distinguish unavailable, disconnected, stale, and unknown states. Do not invent a next opening without a session table.
- On charts other than M5/M15/M30, show SimpleEA's `Incompatible chart. Switch to M5/M15/M30.` notice.
- Use broker-stamped quote time for the chart's symbol when available and describe extrapolated time honestly; MT5 cannot guarantee a perfectly synchronized clock between ticks.

**Phase 1 status: Done.** Phase 1 reserved row 2 for future items. Phase 2 uses the space for timeframe readings; clock guidance is not displayed there.


## Phase 2 — final specification

Phase 2 displays trend detection, regime, score and the agreed approximate reading and score-duration estimates. It does not introduce orders or trading.

For the chart symbol, calculate both readings independently on each supported timeframe (M5, M15 and M30):

- **Global trend:** Automate's normalized regression-slope trend, applied to that timeframe's own closed bars. "Global" means the broader recent trend of that timeframe, not one shared M30 trend or the trend of the entire market.
- **Current trend:** SimpleEA's adaptive Precision Trend reading, applied to that timeframe's own closed bars. It is intended to provide a more responsive perspective; it is not guaranteed to be faster or more accurate in every condition.
- Keep both readings visible even when they disagree. Use closed bars and distinguish missing data from a genuine neutral result.
- Use **ST** (Status) instead of the user-facing word "Vote" for the combined view. The exact agreed rules are specified below; indicator agreement is not a calibrated probability.

Timeframe priorities for future use: M5 gives current trend priority, M15 gives the combined status priority, and M30 gives global trend priority alongside the status. These are intended priorities, not permission to trade or to hide a conflicting reading.

Use standard internal defaults without user inputs, adapting to the symbol's own recent movement where the chosen mechanisms support it. A future diary may record observations and inform bounded automatic configuration; it is not required for Phase 2 trend readings and must not be treated as already validated or implemented.

### Compact display layout (agreed)

Each timeframe row uses **GT** = Global Trend, **CT** = Current Trend, **ST** = Status, **RG** = Regime, **PT** = Prediction Trend and **SC** = Score. ST remains the combined trend status. RG will use SimpleEA's regime mechanism. Show `WAIT` for RG when its required history is unavailable or invalid, and `--` for PT when its estimate is unavailable; do not invent a reading.

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

**Phase 2 status: Implemented; MT5 compilation and runtime validation pending.** Trend detection, compact layout, ST rules, per-timeframe SimpleEA RG, SimpleEA SC, PT and the separate score-life percentage and reset rules are agreed. MT must request required history; insufficient or invalid readings are WAIT, unavailable duration estimates are `--`, and no fallback regime is permitted. Phase 2 is informational and does not authorize trading. Automated source-level regression tests have been run, but they do not replace MetaEditor compilation or MT5 testing.
