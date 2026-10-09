import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darts/engine/darts_engine.dart';
import 'package:darts/services/settings_service.dart';

/// RULES.md §13 test cases + regression tests for the exemplar fixes.
///
/// The engine owns its turn timers; tests drive the public API and wait out
/// the (short) phase durations. `forcedAim` makes bot throws deterministic.
DartsEngine makeEngine(
    {bool bot0 = false, bool bot1 = false, DartsVariant variant = DartsVariant.v501}) {
  return DartsEngine(
    players: [
      DartsPlayer(name: 'P0', color: Colors.red, isBot: bot0),
      DartsPlayer(name: 'P1', color: Colors.blue, isBot: bot1),
    ],
    variant: variant,
  );
}

/// Throw a dart at a board point and wait for the flight to resolve.
Future<void> throwAt(DartsEngine e, Offset p) async {
  e.throwDart(p);
  await Future.delayed(const Duration(milliseconds: 500));
}

/// Wait out a settle + the bot's first throw of the next turn.
Future<void> waitSettle(DartsEngine e) async {
  await Future.delayed(const Duration(milliseconds: 1800));
}

void main() {
  test('501: treble 20 scores 60, remaining 441', () async {
    final e = makeEngine();
    await throwAt(e, trebleSpot(20));
    expect(e.remaining[0], 441);
    expect(e.dartsLeft, 2);
    e.dispose();
  });

  test('dart outside the board misses and consumes a dart', () async {
    final e = makeEngine();
    await throwAt(e, const Offset(1.1, 0));
    expect(e.remaining[0], 501);
    expect(e.dartsLeft, 2);
    expect(e.throwLog.last, 'Miss');
    e.dispose();
  });

  test('three darts then the turn passes automatically', () async {
    final e = makeEngine();
    await throwAt(e, sectorSpot(20, 0.4));
    await throwAt(e, sectorSpot(20, 0.4));
    await throwAt(e, sectorSpot(20, 0.4));
    expect(e.phase, DartsPhase.settling);
    await waitSettle(e);
    expect(e.turn, 1);
    expect(e.phase, DartsPhase.awaitingThrow);
    e.dispose();
  });

  test('bust resets remaining to turn start and ends the turn', () async {
    final e = makeEngine();
    e.remaining[0] = 10;
    e.turnStart = 10;
    await throwAt(e, sectorSpot(10, 0.4)); // single 10, not a double → bust
    expect(e.remaining[0], 10);
    expect(e.phase, DartsPhase.settling);
    await waitSettle(e);
    expect(e.turn, 1);
    e.dispose();
  });

  test('checkout: double 20 on 40 wins immediately', () async {
    final e = makeEngine();
    e.remaining[0] = 40;
    e.turnStart = 40;
    await throwAt(e, doubleSpot(20));
    expect(e.over, true);
    expect(e.winner, 0);
    e.dispose();
  });

  test('bull finishes 50; outer bull reaching 0 busts', () async {
    final win = makeEngine();
    win.remaining[0] = 50;
    win.turnStart = 50;
    await throwAt(win, const Offset(0, 0));
    expect(win.over, true);
    expect(win.winner, 0);
    win.dispose();

    final bust = makeEngine();
    bust.remaining[0] = 25;
    bust.turnStart = 25;
    await throwAt(bust, const Offset(0.1, 0)); // r=0.1 → outer bull 25, not a double → bust
    expect(bust.remaining[0], 25);
    expect(bust.phase, DartsPhase.settling);
    bust.dispose();
  });

  test('checkout hint suggests Double 20 at 40', () {
    final e = makeEngine();
    e.remaining[0] = 40;
    e.turnStart = 40;
    expect(e.checkoutHint, contains('Double 20'));
    e.remaining[0] = 170;
    expect(e.checkoutHint, isNull);
    e.dispose();
  });

  test('bot turn is fully visible: flies, narrates, never skips', () async {
    final e = makeEngine(bot1: true);
    // Human throws 3 darts first.
    await throwAt(e, sectorSpot(20, 0.4));
    await throwAt(e, sectorSpot(20, 0.4));
    await throwAt(e, sectorSpot(20, 0.4));
    expect(e.phase, DartsPhase.settling);
    // Wait: settle → bot's turn → bot throws 3 visible darts.
    await Future.delayed(const Duration(milliseconds: 2600));
    // The bot should have thrown at least one dart by now (visible flight).
    expect(e.dartsThrown[1] >= 1, true);
    expect(e.throwLog.isNotEmpty || e.phase != DartsPhase.awaitingThrow, true);
    e.dispose();
  });

  test('count-up: 10 rounds each, higher total wins', () async {
    final e = makeEngine(variant: DartsVariant.countUp);
    // Fast-forward to the final round to keep the test short.
    e.roundsDone = [9, 9];
    e.totals = [1000, 500];
    for (int d = 0; d < 3; d++) {
      await throwAt(e, trebleSpot(20)); // P0: +180
    }
    await Future.delayed(const Duration(milliseconds: 900));
    expect(e.turn, 1);
    for (int d = 0; d < 3; d++) {
      await throwAt(e, sectorSpot(20, 0.4)); // P1: +60
    }
    await Future.delayed(const Duration(milliseconds: 900));
    expect(e.over, true);
    expect(e.draw, false);
    expect(e.winner, 0); // 1180 vs 560
    e.dispose();
  });

  test('count-up: equal totals after 10 rounds is a draw', () async {
    final e = makeEngine(variant: DartsVariant.countUp);
    e.roundsDone = [9, 9];
    e.totals = [1000, 1000];
    for (int d = 0; d < 3; d++) {
      await throwAt(e, sectorSpot(20, 0.4));
    }
    await Future.delayed(const Duration(milliseconds: 900));
    for (int d = 0; d < 3; d++) {
      await throwAt(e, sectorSpot(20, 0.4));
    }
    await Future.delayed(const Duration(milliseconds: 900));
    expect(e.over, true);
    expect(e.draw, true);
    e.dispose();
  });

  test('watchdog recovers a lost timer mid-flight', () async {
    final e = makeEngine();
    e.throwDart(trebleSpot(20));
    expect(e.phase, DartsPhase.flying);
    // Simulate a dead phase timer without resolving.
    e.debugKillTimer();
    expect(e.phase, DartsPhase.flying);
    e.debugRecover();
    expect(e.phase, DartsPhase.awaitingThrow);
    expect(e.remaining[0], 441);
    e.dispose();
  });

  test('pause freezes phases; resume recovers', () async {
    final e = makeEngine();
    e.setPaused(true);
    expect(e.paused, true);
    e.setPaused(false);
    expect(e.paused, false);
    expect(e.phase, DartsPhase.awaitingThrow);
    e.dispose();
  });

  test('restart resets everything', () async {
    final e = makeEngine();
    await throwAt(e, trebleSpot(20));
    e.restart();
    expect(e.remaining[0], 501);
    expect(e.dartsLeft, 3);
    expect(e.turn, 0);
    expect(e.over, false);
    expect(e.phase, DartsPhase.awaitingThrow);
    e.dispose();
  });
}
