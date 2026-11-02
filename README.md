# MT — Master Trade

**Phase 1 — appearance.** A single-line market-state panel for MetaTrader 5, drawn with chart objects. The panel shows the chart symbol, its broker-published type, whether the market is open, and either the server clock (open) or the next opening time from the broker's session table (closed).

The panel reserves **four rows**: row 1 is the header, rows 2–4 are reserved for later phases. The box is sized to the widest of the two states, so it never resizes when the market shuts.

> **Status:** source written against the MQL5 API. It has **not** been compiled in MetaEditor or run against a broker in this environment. Compile it in MetaEditor and test on demo before using it on a live account.

## Files

| File | Purpose |
|---|---|
| `MT.mq5` | The Expert Advisor. Phase 1: panel only, no trading. |
| `MT.md` | The specification this implementation follows. |
| `preview.html` | A browser mockup of the panel for visual inspection. Not part of the EA. |
| `README.md` | This document. |

## Install

1. Open MetaEditor (F4 in MetaTrader 5).
2. Create a new Expert Advisor, or copy `MT.mq5` into `MQL5/Experts/MT/MT.mq5`.
3. Compile `MT.mq5` (F7). The expected output is `MT.ex5`. If the compiler reports errors, check the MQL5 documentation for the exact API version in your MetaEditor build.
4. In MetaTrader 5, open the chart of the symbol you want to inspect.
5. Drag `MT` from the **Navigator → Expert Advisors** panel onto the chart.
6. In the EA properties, the appearance defaults are already the specified ones:
   - Font: `Consolas`
   - Font size: `10`
   - Background: `C'48,48,48'`
   - Title: `MT V1.00`, one point larger (`11`) in `clrWhite`
7. The panel appears at the top-left of the chart. The EA does not need Algo Trading enabled to draw; it places no orders.

## What the panel shows

Open market:

```text
MT V1.00 | XAUUSDm | Metal | OPEN | 2026.11.01 11:57:34
```

Closed market, with a published session table:

```text
MT V1.00 | XAUUSDm | Metal | close | Open at 2026.11.01 11:57:34
```

Closed market, broker publishes no session table:

```text
MT V1.00 | BTCUSDm | Crypto | close | Open at --
```

| Cell | Content |
|---|---|
| `MT V1.00` | Name and version, drawn at 11 pt in `clrWhite`. |
| Symbol | `_Symbol`, the broker's own spelling. |
| Type | `Forex`, `Metal`, `Index`, `Energy`, `Crypto`, `Stock`, or `Other`. |
| State | `OPEN` while the market is open, `close` while it is closed. |
| Last cell | While open: the server date and time, ticking every second. While closed: `Open at` and the next opening time from the broker's session table. If the broker publishes no table: `Open at --`. |

### Appearance

The three appearance values come from `SimpleEA/SimpleAdvisor.mq5`:

| Setting | Value |
|---|---|
| Font | `Consolas` |
| Font size | `10` |
| Background colour | `C'48,48,48'` |
| Title | `MT V1.00`, size `11`, `clrWhite` |

The rest of the line uses `clrWhite` for the symbol and clock, `clrSilver` for the type, `clrLime` for `OPEN`, and `clrTomato` for `close`. The border is `clrDimGray`. All objects are hidden from the object list and non-selectable.

### Size

At 10 pt on a 96 DPI display, the open text is about 448 px and the closed text about 520 px. The box is sized to the wider state plus one trailing character, so it does not move when the market shuts. The height is fixed at four rows of `InpFontSize + 11` pixels (84 px at 10 pt).

The date and time are fixed-width (`yyyy.mm.dd hh:mm:ss`), so the seconds ticking do not shift anything. The state cell is not padded to a fixed width, so the last cell moves by one character (8 px at 10 pt) at the open/close transition; the box itself does not resize.

## Market state and next opening

- The broker's weekly trade-session table is read with `SymbolInfoSessionTrade` for all seven days.
- Session times are server time; the date part of the returned values is ignored, as documented by MQL5.
- The market is **open** when the server clock is inside one of today's sessions, or inside an overnight session that began yesterday.
- The market is **closed** otherwise. The last cell then shows the earliest session start at or after the current server time, searched across the next eight days.
- A `00:00-00:00` session is treated as a full-day session, because some brokers use that pair for a 24-hour market. A zero-length session with any other equal pair is ignored.
- If the broker publishes no table, the state is `close` and the last cell is `Open at --`. The EA does not invent an opening time.
- The clock uses `TimeTradeServer()` and is refreshed by a one-second timer, so it keeps ticking when no ticks arrive. `OnTick` also refreshes it immediately.
- The session table is cached and rescanned when the server day changes or the chart symbol changes.

## Symbol type

The type is a best-effort label, not a trading gate. The classifier tries, in order:

1. Broker metadata: `SYMBOL_SECTOR_NAME`, `SYMBOL_INDUSTRY_NAME`, `SYMBOL_CATEGORY`, `SYMBOL_PATH`, `SYMBOL_DESCRIPTION`.
2. The symbol name, with common broker suffixes (`m`, `.raw`, `.ecn`, `.pro`, `.std`, `.cash`, `.spot`, `.f`, `.z`, `.j`) removed.
3. The symbol calculation mode (`SYMBOL_TRADE_CALC_MODE`) as a fallback.

Examples:

| Symbol | Type | Why |
|---|---|---|
| `XAUUSDm` | `Metal` | `XAU` prefix / precious-metal metadata. |
| `BTCUSDm` | `Crypto` | `BTC` prefix / crypto metadata. |
| `EURUSD` | `Forex` | 6-letter fiat pair / forex calculation mode. |
| `US30` | `Index` | index token / index metadata. |
| `USOIL` | `Energy` | `OIL` token / energy metadata. |
| `AAPL` | `Stock` | stock token / stock metadata. |
| Unknown | `Other` | No rule matched. |

If the broker's metadata is sparse or misleading, the label can be wrong. It is displayed only; it does not block anything.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `InpFont` | `Consolas` | Font face. |
| `InpFontSize` | `10` | Font size in points. The title is one point larger. |
| `InpBgColor` | `C'48,48,48'` | Panel background. |
| `InpTitleColor` | `clrWhite` | Title colour. |
| `InpPanelX` | `12` | Panel X offset in pixels. |
| `InpPanelY` | `24` | Panel Y offset in pixels. |

## Behavior on chart changes

- A symbol change rebuilds the panel for the new symbol, including the type and the session table.
- A timeframe change does not rebuild the panel; the panel does not depend on the timeframe.
- `OnDeinit` removes the panel objects and stops the timer.

## Limitations

- **Not compiled or broker-tested here.** The source is written against the MQL5 API; compile it in MetaEditor and test on demo.
- **Holidays and unscheduled closures** are not known to the EA. The next opening time comes from the regular weekly session table. A holiday closure will still show the regular next session.
- **`00:00-00:00` sessions** are interpreted as full-day sessions. If a broker uses that pair to mean "closed", the panel will report open. Check the broker's symbol specifications if this matters.
- **Server time** is used for both the clock and the session comparison. The panel does not convert to the local time zone.
- **Font metrics** are estimated from the terminal DPI and a monospaced 0.55 em advance. The box is sized to avoid clipping, but the actual rendered width can differ slightly from the estimate.
- **Symbol classification** is best-effort. A broker with no sector/industry metadata and an unusual symbol name may produce `Other`.
- **No trading.** Phase 1 is appearance only. The EA does not place, modify, or close orders.

## Design notes

- The panel is drawn with `OBJ_RECTANGLE_LABEL` and `OBJ_LABEL` chart objects, following the SimpleEA panel approach.
- The width is measured from both the open and closed strings before the background is created. This is what guarantees the box does not resize when the market shuts.
- The clock is a fixed-width string, so the seconds do not move the text.
- The last cell's x is recomputed only when the state changes, because `OPEN` is four characters and `close` is five.
- The panel is hidden (`OBJPROP_HIDDEN`) and non-selectable (`OBJPROP_SELECTABLE`), so it does not clutter the object list or intercept chart interaction.
- The object prefix `MT_` is used for every object, so a rebuild or deinit removes exactly this panel.

## Visual mockup

Open `preview.html` in a browser to see the panel in its open, closed, and no-table states. It is a static mockup for design review; it is not the EA and does not connect to MetaTrader.
