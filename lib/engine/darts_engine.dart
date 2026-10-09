import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

// ---------------------------------------------------------------------------
// Board geometry (canonical dartboard). Board coords are -1..1, center = bull.
// ---------------------------------------------------------------------------
const boardNumbers = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5
];

/// Score a board point (-1..1 coords). Returns (score, isDouble).
(int, bool) scorePoint(Offset p) {
  final r = p.distance;
  if (r > 1.0) return (0, false);
  if (r < 0.07) return (50, true); // bull counts as a double (RULES §7)
  if (r < 0.16) return (25, false);
  var a = atan2(p.dy, p.dx) + pi / 2 + pi / 20;
  while (a < 0) {
    a += 2 * pi;
  }
  while (a >= 2 * pi) {
    a -= 2 * pi;
  }
  final sector = (a / (2 * pi) * 20).floor() % 20;
  final n = boardNumbers[sector];
  if (r >= 0.52 && r <= 0.62) return (n * 3, false);
  if (r >= 0.84 && r <= 0.96) return (n * 2, true);
  return (n, false);
}

/// Human-readable label for a scored dart.
String dartLabel((int, bool) s, Offset p) {
  if (s.$1 == 0) return 'Miss';
  if (s.$1 == 50) return 'BULLSEYE!';
  if (s.$1 == 25) return 'Outer bull 25';
  final r = p.distance;
  final mult =
      (r >= 0.52 && r <= 0.62) ? 'Treble' : (s.$2 ? 'Double' : 'Single');
  return '$mult ${s.$1}';
}

/// Board coords of a sector's ring center (RULES aim helpers).
Offset sectorSpot(int n, double ringR) {
  final i = boardNumbers.indexOf(n);
  final a = (i / 20) * 2 * pi - pi / 2 - pi / 20;
  return Offset(cos(a), sin(a)) * ringR;
}

Offset trebleSpot(int n) => sectorSpot(n, 0.57);
Offset doubleSpot(int n) => sectorSpot(n, 0.90);

/// One-dart double checkouts, RULES.md §7. Value = number to aim the double
/// at; 25 = bull.
const checkoutDoubles = {
  50: 25, 40: 20, 36: 18, 32: 16, 24: 12, 20: 10,
  16: 8, 12: 6, 8: 4, 4: 2, 2: 1,
};

// ---------------------------------------------------------------------------
// Players / phases
// ---------------------------------------------------------------------------
class DartsPlayer {
  String name;
  final Color color;
  final bool isBot;

  DartsPlayer({required this.name, required this.color, required this.isBot});
}

/// 0 = easy, 1 = medium, 2 = hard (RULES.md §11).
enum BotDifficulty { easy, medium, hard }

/// Turn phases owned entirely by the engine. The UI only renders.
/// [settling] = turn is ending (bust announced / turn complete): input
/// locked, the turn will pass shortly. This is what makes extra taps
/// impossible.
enum DartsPhase { awaitingThrow, flying, settling, over }

/// A dart in flight (visual). The score is resolved when the flight ends;
/// the UI interpolates the dart from below the board to [to].
class ThrowAnim {
  final int pi;
  final Offset to; // board coords -1..1
  final int totalMs;
  final DateTime startedAt = DateTime.now();

  ThrowAnim({required this.pi, required this.to, required this.totalMs});

  double get progress {
    final e = DateTime.now().difference(startedAt).inMilliseconds;
    return (e / totalMs).clamp(0.0, 1.0);
  }
}

// ---------------------------------------------------------------------------
// Engine: deterministic rules, state, bot AI. UI-agnostic.
// ---------------------------------------------------------------------------
class DartsEngine extends ChangeNotifier {
  final List<DartsPlayer> players;
  final BotDifficulty botDifficulty;
  final DartsVariant variant;

  late final int startScore; // 501 or 301 for countdown variants
  static const countUpRounds = 10;

  List<int> remaining = [501, 501]; // countdown variants
  List<int> totals = [0, 0]; // count-up variant
  List<int> roundsDone = [0, 0]; // count-up rounds completed per player
  List<int> dartsThrown = [0, 0]; // lifetime darts per player (stats)

  int turn = 0;
  int dartsLeft = 3;
  int turnStart = 501; // remaining at turn start (bust recovery)
  List<int> turnScores = []; // this turn's dart scores
  List<Offset> stuckDarts = []; // board points stuck this turn
  List<String> throwLog = []; // narration of this turn's throws

  DartsPhase phase = DartsPhase.awaitingThrow;
  ThrowAnim? flight;
  bool over = false;
  int winner = -1; // player index, -1 = none/draw
  bool draw = false;
  int turnCount = 0;
  String banner = '';

  final _rand = Random();
  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;

  static const flightDurationMs = 380;
  static const settleMs = 700;

  /// Test hook: when set, the bot's next aim is replaced with this point.
  /// Consumed after one use.
  @visibleForTesting
  Offset? forcedAim;

  /// Test hooks: simulate a dead phase timer, then run the watchdog.
  @visibleForTesting
  void debugKillTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @visibleForTesting
  void debugRecover() => _recover();

  DartsEngine({
    required this.players,
    this.botDifficulty = BotDifficulty.medium,
    this.variant = DartsVariant.v501,
  }) {
    assert(players.length == 2);
    startScore = variant == DartsVariant.v301 ? 301 : 501;
    remaining = [startScore, startScore];
    turnStart = startScore;
    banner = current.isBot
        ? '${current.name} steps up…'
        : '${current.name}, tap the board to throw!';
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
    _afterPhase();
  }

  DartsPlayer get current => players[turn];
  bool get isCountUp => variant == DartsVariant.countUp;
  bool get awaitingThrow =>
      phase == DartsPhase.awaitingThrow && !over && !paused;

  /// Big score display for a player: remaining (countdown) or total (count-up).
  int scoreOf(int pi) => isCountUp ? totals[pi] : remaining[pi];

  /// Checkout hint for the current player (RULES.md §7), or null.
  String? get checkoutHint {
    if (isCountUp || over) return null;
    final rem = remaining[turn];
    final co = checkoutDoubles[rem];
    if (co == null) return null;
    return co == 25 ? '💡 Checkout: Bull!' : '💡 Checkout: Double $co!';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// This makes stuck states impossible by construction. Respects [paused].
  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    if (phase == DartsPhase.flying && flight != null) {
      _resolveThrow(); // dart in flight with no timer: resolve immediately
    } else if (phase == DartsPhase.awaitingThrow && current.isBot) {
      _botThrow();
    } else if (phase == DartsPhase.settling) {
      _nextTurn();
    }
  }

  // ------------------------------------------------------------- turn flow
  /// Human taps the board. Strict: only in awaitingThrow, only the human's
  /// own turn.
  void throwDart(Offset boardPoint) {
    if (!awaitingThrow || current.isBot) {
      onEvent?.call(DartsEvent.invalid);
      return;
    }
    _launch(boardPoint);
  }

  void _botThrow() {
    if (phase != DartsPhase.awaitingThrow || !current.isBot || over) return;
    final aim = forcedAim ?? _botAim();
    forcedAim = null;
    banner = '${current.name} throws…';
    notifyListeners();
    _launch(aim);
  }

  void _launch(Offset aim) {
    // Clamp to the board disc; wild misses are still legal (score 0).
    final clamped = aim.distance > 1.15
        ? aim / aim.distance * 1.15
        : aim;
    phase = DartsPhase.flying;
    flight = ThrowAnim(pi: turn, to: clamped, totalMs: flightDurationMs);
    onEvent?.call(DartsEvent.throwLaunched);
    notifyListeners();
    _arm(const Duration(milliseconds: flightDurationMs), _resolveThrow);
  }

  void _resolveThrow() {
    if (over || phase != DartsPhase.flying || flight == null) return;
    final pi = turn;
    final point = flight!.to;
    flight = null;
    final s = scorePoint(point);
    final score = s.$1;
    final isDouble = s.$2;
    final label = dartLabel(s, point);

    dartsThrown[pi]++;
    dartsLeft--;
    turnScores.add(score);
    stuckDarts.add(point);
    throwLog.add(label);
    if (throwLog.length > 3) throwLog.removeAt(0);

    onEvent?.call(DartsEvent.dartLanded);
    banner = '${players[pi].name}: $label';

    if (isCountUp) {
      totals[pi] += score;
    } else {
      final after = remaining[pi] - score;
      // RULES.md §7: bust if below 0, exactly 1, or 0 without a double.
      final bust = after < 0 || after == 1 || (after == 0 && !isDouble);
      if (bust) {
        remaining[pi] = turnStart; // whole turn void
        phase = DartsPhase.settling;
        banner = 'BUST! ${players[pi].name} wasted the turn.';
        notifyListeners();
        onEvent?.call(DartsEvent.bust);
        _arm(const Duration(milliseconds: 1300), _nextTurn);
        return;
      }
      remaining[pi] = after;
      if (after == 0) {
        // Double to finish — the leg ends on this dart.
        notifyListeners();
        _finish(pi);
        return;
      }
    }

    // 180 call: a perfect turn.
    if (turnScores.length == 3 &&
        turnScores.fold(0, (a, b) => a + b) == 180) {
      banner = 'ONE HUNDRED AND EIGHTY! 🎯';
      onEvent?.call(DartsEvent.cheer180);
    }

    if (dartsLeft <= 0) {
      // Turn complete — brief settle, then pass. Input stays locked.
      phase = DartsPhase.settling;
      notifyListeners();
      _arm(const Duration(milliseconds: settleMs), _nextTurn);
      return;
    }
    phase = DartsPhase.awaitingThrow;
    notifyListeners();
    _afterPhase();
  }

  void _nextTurn() {
    if (over) return;
    if (isCountUp) {
      roundsDone[turn]++;
      if (roundsDone[0] >= countUpRounds && roundsDone[1] >= countUpRounds) {
        _finishCountUp();
        return;
      }
    }
    turn = (turn + 1) % 2;
    dartsLeft = 3;
    turnScores = [];
    stuckDarts = [];
    throwLog = [];
    turnStart = remaining[turn];
    turnCount++;
    banner = current.isBot
        ? '${current.name} steps up…'
        : '${current.name}, tap the board to throw!';
    phase = DartsPhase.awaitingThrow;
    notifyListeners();
    _afterPhase();
  }

  /// Called whenever we enter awaitingThrow: bots throw themselves.
  void _afterPhase() {
    if (over || phase != DartsPhase.awaitingThrow) return;
    if (current.isBot) {
      _arm(const Duration(milliseconds: 700), _botThrow);
    }
  }

  void _finish(int pi) {
    over = true;
    phase = DartsPhase.over;
    winner = pi;
    banner = '${players[pi].name} checks out! 🏆';
    notifyListeners();
    onEvent?.call(players[pi].isBot ? DartsEvent.botWon : DartsEvent.humanWon);
  }

  void _finishCountUp() {
    over = true;
    phase = DartsPhase.over;
    if (totals[0] == totals[1]) {
      draw = true;
      banner = "It's a draw!";
      notifyListeners();
      onEvent?.call(DartsEvent.draw);
    } else {
      _finish(totals[0] > totals[1] ? 0 : 1);
    }
  }

  void restart() {
    _timer?.cancel();
    paused = false;
    remaining = [startScore, startScore];
    totals = [0, 0];
    roundsDone = [0, 0];
    dartsThrown = [0, 0];
    turn = 0;
    dartsLeft = 3;
    turnStart = startScore;
    turnScores = [];
    stuckDarts = [];
    throwLog = [];
    flight = null;
    over = false;
    winner = -1;
    draw = false;
    turnCount = 0;
    forcedAim = null;
    phase = DartsPhase.awaitingThrow;
    banner = current.isBot
        ? '${current.name} steps up…'
        : '${current.name}, tap the board to throw!';
    notifyListeners();
    _afterPhase();
  }

  /// UI hook for sounds. Set by the screen.
  void Function(DartsEvent event)? onEvent;

  // ---------------------------------------------------------------- bot AI
  double _gauss() =>
      (_rand.nextDouble() + _rand.nextDouble() + _rand.nextDouble()) / 1.5 - 1;

  double get _error => switch (botDifficulty) {
        BotDifficulty.easy => 0.16,
        BotDifficulty.medium => 0.09,
        BotDifficulty.hard => 0.05,
      };

  /// Bot aim (board coords), RULES.md §11.
  Offset _botAim() {
    final err = _error;
    Offset base;
    if (!isCountUp) {
      final rem = remaining[turn];
      final co = checkoutDoubles[rem];
      if (co != null) {
        base = co == 25 ? const Offset(0, 0) : doubleSpot(co);
      } else if (rem <= 60) {
        // No direct checkout: treble 20, error already risks busts at easy.
        base = trebleSpot(20);
      } else {
        base = trebleSpot(20);
      }
    } else {
      base = _rand.nextDouble() < 0.2 ? const Offset(0, 0) : trebleSpot(20);
    }
    if (botDifficulty == BotDifficulty.easy && _rand.nextDouble() < 0.2) {
      // Easy goes rogue sometimes: random sector, playful and beatable.
      base = sectorSpot(
          boardNumbers[_rand.nextInt(20)], 0.4 + _rand.nextDouble() * 0.4);
    }
    return base + Offset(_gauss() * err, _gauss() * err);
  }
}

enum DartsEvent {
  throwLaunched, // whoosh
  dartLanded, // thud
  bust,
  cheer180,
  invalid,
  humanWon,
  botWon,
  draw,
}
