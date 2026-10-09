# DARTS — RULES.md
**Authoritative rules for the Darts game (pub darts edition).** If the implementation conflicts with this document, fix the implementation.

## 1. Objective
- **501 / 301 variants:** count down from the starting score (501 or 301) to **exactly 0**, finishing on a **double** (a double ring, or the bull which counts as a double).
- **Count-Up variant:** each player throws 30 darts total (10 rounds × 3 darts). The highest total score wins. No doubles-out requirement.

## 2. Setup
- 2 players: seat 0 and seat 1. A seat may be a human or a bot.
- 501 variant: both players start at 501. 301 variant: both start at 301.
- Count-Up: both totals start at 0, 10 rounds each.
- Player 1 (seat 0) throws first.

## 3. Turn order
- Players alternate turns. A turn = exactly 3 darts, then the turn passes.
- There are no bonus throws and no roll-overs: every turn is exactly 3 darts,
  except that a bust (see §7) ends the turn immediately.
- In Count-Up, after each player has completed 10 turns the game ends.

## 4. Legal moves
- Tap anywhere on the dartboard to throw a dart at that spot.
- A dart landing on the board scores:
  - Single sector: face value (1–20).
  - Treble ring: 3× face value.
  - Double ring: 2× face value (counts as a double for the finish).
  - Outer bull (green): 25 (not a double).
  - Bullseye (red): 50 (counts as a double for the finish).
- A dart missing the board entirely scores 0 (still consumes a dart).

## 5. Illegal moves
- Tapping while a dart is in flight, while the turn is settling, or after the
  game is over is ignored (input is locked in those phases).
- It is impossible to throw a 4th dart in a turn: after 3 darts the turn
  always advances automatically.

## 6. Captures
- Not applicable to darts. No captures.

## 7. Special rules
- **BUST (countdown variants):** if a dart would take the remaining score
  below 0, to exactly 1, or to exactly 0 WITHOUT a double, the whole turn is
  void: the remaining score resets to what it was at the start of the turn
  and the turn ends immediately.
- **Double to finish:** the winning dart must land in a double ring or the
  bullseye. Any other dart that would reach 0 is a bust.
- **180 call:** a turn totaling 180 (three treble 20s) is celebrated.

## 8. Scoring
- Countdown: remaining = start − (sum of legal dart scores this game).
- Bust resets remaining to the turn-start value.
- Count-Up: total = sum of all dart scores over 10 rounds.

## 9. Winning conditions
- Countdown: first player to reach exactly 0 with a double wins the leg
  immediately — the game ends on that dart.
- Count-Up: after both players complete 10 rounds, the higher total wins.
  Equal totals = a draw.

## 10. Draw conditions
- Only possible in Count-Up (equal totals after 10 rounds each).
- 501/301 always produce a winner (a bust can never be final — someone
  always checks out eventually; the engine guarantees termination).

## 11. AI strategy
- The bot always throws 3 darts per turn with visible flight animation and
  narration — never silently auto-played.
- Targeting:
  - Countdown, remaining > 60: aim treble 20.
  - Countdown, remaining ≤ 60 and a one-dart double checkout exists
    (40/36/32/24/20/16/12/8/4/2 → doubles; 50 → bull): aim that double/bull.
  - Countdown, remaining ≤ 60 without a direct checkout: aim treble 20.
  - Count-Up: aim treble 20 (occasionally bull for variety).
- Difficulty = aim error (gaussian offset):
  - **Easy:** large error (≈0.16 board units), occasionally picks a random sector.
  - **Medium:** moderate error (≈0.09), sensible targets.
  - **Hard:** small error (≈0.05), best targets, minimal noise.

## 12. Edge cases
- Remaining = 1 at turn start: any scoring dart busts (1 − x < 0 for x ≥ 1
  gives < 0 or = 0-without-double). Only a miss (0) keeps the turn alive.
- Remaining = 2: only double 1 wins; anything else busts or misses.
- Dart landing exactly on a wire line: scored by the sector/ring geometry
  the point falls in (first match wins — deterministic).
- Bot seats are driven entirely by engine timers; if a timer ever dies, the
  watchdog recovers the phase (see engine).

## 13. Test cases
- 501: throw treble 20 → remaining 441.
- Bust: remaining 20, throw single 20 then double… covered by: remaining 10,
  throw single 10 → not a double → bust, remaining resets to turn start.
- Checkout: remaining 40, throw double 20 → win immediately.
- Bull finish: remaining 50, bullseye → win; outer bull (25) → bust.
- Count-Up: 10 rounds each, totals compared; tie → draw.
- AI visibility: every bot dart produces a flight animation + narration;
  no turn is ever skipped silently.
- Engine invariants: phase is never stuck — watchdog recovers flying /
  awaitingThrow / settling without a live timer.
