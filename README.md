# MT — Master Trade

`MT.mq5` is a MetaTrader 5 Expert Advisor implementing the Phase 1 market panel and Phase 2 trend and score readings. It displays information only and never places or manages orders. Copy it into `MQL5/Experts`, compile with MetaEditor, and attach it to a chart. **There are no inputs.**

## Panel

The default appearance remains Consolas 10 pt on `C'48,48,48'`, with the title in white at 11 pt. The EA measures the displayed text using MT5 font metrics and sizes the box to its current content, including the detail/notice line; a conservative DPI-based estimate is used if text measurement fails. Supported charts reserve three header rows followed by the three timeframe lanes. Row 1 contains the header; row 2 is blank when open and shows market details when closed or abnormal; row 3 remains reserved. Width and height are measured to cover all displayed content. Long lines are drawn as multiple short labels to avoid text truncation.

- M5, M15 and M30: the header shows the broker's symbol, its best-effort asset class and market state. While open it shows server time in the header and the three timeframe lanes below the three-row header area; row 2 is blank, with no clock-estimation guidance. When closed it shows `Open at` and the next regular session, plus an Automate-style `MARKET CLOSED - next open ... server (in ...)` detail.
- Other timeframes: the header identifies the symbol and timeframe and the two-line panel shows SimpleEA's `Incompatible chart. Switch to M5/M15/M30.` notice.
- The weekly broker trade-session table is refreshed every five minutes. Sessions may cross midnight. If it is unavailable, a fresh quote can indicate an open market; without a fresh quote the state is unknown and `Open at --` is shown rather than an invented opening time. Disconnection, broker-disabled symbols, and stale quotes are distinguished from a scheduled close.

The next opening is a **regular weekly schedule**, not a guarantee: holidays, broker halts, and changed schedules can invalidate it. `00:00–00:00` is treated as a 24-hour session. Classification uses broker metadata and name heuristics and can be wrong; it does not affect trading.

## Phase 2 readings

Each lane is calculated independently for the chart symbol on the **closed bars** of M5, M15 or M30:

- **GT**: Automate's 30-bar regression slope normalized by the median absolute change of 20 bars; UP/DOWN outside ±0.20, otherwise FLAT.
- **CT**: SimpleEA's adaptive Precision Trend filter sign. Its adaptive short cycle is 14–36 (24 when there are too few crossings); the long period is approximately 6.25 times the short, clamped to 90–225. CT is FLAT at exactly zero.
- **ST**: matching directions give UP or DOWN, two FLATs give FLAT, opposed directions give CONFLICT, and one FLAT with a direction gives MIXED. An unavailable component gives WAIT.
- **RG**: SimpleEA's Hurst estimator on that lane's own data, never a borrowed timeframe. It uses 1,536/512/256 bars for M5/M15/M30, plus the preceding close. Above 0.55 is STEADY, below 0.45 CHOPPY, otherwise MIXED. Invalid data or insufficient history gives WAIT, not a substituted 0.5.
- **SC**: SimpleEA's three votes: CT direction, its ATR-deadbanded rate of change, and 20-bar net movement with confirmed swing checks and an ATR deadband. It ranges from -3/3 to +3/3. GT, ST, RG and PT do not change the score.

**PT** estimates the remaining life of the selected label: M5 CT, M15 ST and M30 GT. **%L** beside SC independently estimates the share of the exact signed score's estimated life remaining. Each uses the median remaining length of at least 20 fully observed past runs of the same label that reached the current age, including zero remaining. A run beginning before the replay window is not counted. Historical score and adaptive periods are reconstructed causally, without training or waiting for new trades. Estimates can be inaccurate or biased by changes in market conditions or the available historical window.

The countdown basis is held when a state starts or the EA attaches mid-state. A positive life fraction that rounds below one percent is shown as `<1%L`, never as an expired zero. Each subsequent closed bar reduces the remaining count. PT shows `~0b` at its estimate and `0b+` afterward; score life shows `~0%L` and then `past est.`. Each first label change resets the respective countdown, including `+3` to `+2`. Terminal global variables preserve a valid basis across restarts where possible; MT verifies the observed label and age across the intervening bars before restoring it. `--`/`--%L` means that duration is unavailable, not zero. **Neither PT nor %L is a trade-success probability or a guarantee of a change.**

MT requests closed history directly from the terminal, retries synchronization and progressively increases the request when estimates lack samples, up to the **terminal's configured maximum bars per timeframe** (excluding the forming bar). The broker's history, synchronization, terminal settings, invalid data and available memory can limit what is available. If a deeper `CopyRates` request fails, the EA retries the deeper request and can retain independently supported readings from a smaller available range; it never substitutes a regime value. With short history, already supported GT or RG may display while CT/SC still show WAIT. The filter uses a 700-bar warm-up and the finite historical replay can differ slightly from SimpleEA's live rolling pull because recursive filter initialization is not identical. Large history requests and calculations can take time, memory and CPU and may briefly block MT5; data are refreshed on new bars and incomplete history is retried. There are no user inputs and no Phase 2 order, entry, TP or SL logic.

## Server clock

MT5 has one trade-server time for the account, not a separate clock per symbol. In `OnTick`, `TimeCurrent()` is the server-stamped time of the chart symbol's handled quote. Outside `OnTick`, it is the most recent quote time for **any** Market Watch symbol. The panel anchors to new broker timestamps and advances between them using a monotonic counter. This avoids the previous reliance on `TimeTradeServer()`, which MetaTrader calculates from the PC's clock settings. After startup and before a new quote is observed, `TimeTradeServer()` is the only running estimate available. In Strategy Tester, simulated `TimeCurrent()` is used instead of real elapsed time.

A timestamp in a quote has second precision and may be delayed in transit; extrapolation between quotes and over long closures can drift, and a server clock or timezone change can occur without a new quote. **Perfect synchronization cannot be guaranteed by MT5's APIs.** The clock is estimated between quotes. Compare it with Market Watch's server time on a live connection, and check the PC clock if the panel starts before any fresh quote.

## Tests and limitations

Run `python3 tests/test_logic.py`, `python3 tests/test_clock.py`, `python3 tests/test_panel.py`, and `python3 tests/test_phase2.py` with Python 3 and `g++`. These execute functions extracted from the MQL source against C++ stubs, not the MetaTrader runtime. Compile and test in MetaEditor/MT5, including all score text, the reserved header rows, font metrics at the actual screen DPI, chart changes, history synchronization, Phase 2 readings, restart persistence, and live and closed broker sessions; no MT5 compiler or broker is available in this environment.
