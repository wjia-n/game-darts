import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Darts — 501 countdown, doubles to finish.
class DartsScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const DartsScreen({super.key, required this.players, required this.callbacks});

  @override
  State<DartsScreen> createState() => _DartsScreenState();
}

class _DartsScreenState extends State<DartsScreen>
    with SingleTickerProviderStateMixin {
  static const _numbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
  final _rnd = Random();
  late List<int> remaining;
  int turn = 0;
  int dartsThrown = 0; // this turn
  int turnStart = 501;
  List<String> throwLog = [];
  bool flying = false;
  bool over = false;
  Offset? dartSpot; // where dart is stuck (board coords -1..1)

  late AnimationController _flight;
  Offset _to = Offset.zero;

  @override
  void initState() {
    super.initState();
    remaining = List.filled(widget.players.length, 501);
    turnStart = 501;
    _flight = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _resolveThrow();
      });
    widget.callbacks.setActivePlayer(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBot());
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  double _gauss() => (_rnd.nextDouble() + _rnd.nextDouble() + _rnd.nextDouble()) / 1.5 - 1;

  void _maybeBot() {
    if (over || !widget.players[turn].isBot) return;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || over || flying || !widget.players[turn].isBot) return;
      _botThrow();
    });
  }

  /// Bot aims treble 20; aims checkout double when close.
  void _botThrow() {
    final rem = remaining[turn];
    Offset aim; // board coords -1..1
    double err;
    final co = _checkout(rem);
    if (co != null) {
      // aim at the suggested double
      aim = _doubleSpot(co);
      err = 0.055;
    } else if (rem > 60) {
      aim = _trebleSpot(20);
      err = 0.06;
    } else {
      aim = _trebleSpot(20);
      err = 0.05;
    }
    _throwAt(aim + Offset(_gauss() * err, _gauss() * err));
  }

  Offset _sectorCenter(int n, double ringR) {
    final i = _numbers.indexOf(n);
    final a = (i / 20) * 2 * pi - pi / 2 - pi / 20;
    return Offset(cos(a), sin(a)) * ringR;
  }

  Offset _trebleSpot(int n) => _sectorCenter(n, 0.56);
  Offset _doubleSpot(int n) => _sectorCenter(n, 0.90);

  void _onTapBoard(Offset boardPoint) {
    if (over || flying || widget.players[turn].isBot) return;
    _throwAt(boardPoint);
  }

  void _throwAt(Offset boardPoint) {
    setState(() {
      flying = true;
      _to = boardPoint;
      dartSpot = boardPoint; // painter target during flight; stuck after
    });
    Sfx.move();
    _flight.forward(from: 0);
  }

  /// Score a board point (-1..1 coords). Returns (score, isDouble).
  (int, bool) _score(Offset p) {
    final r = p.distance;
    if (r > 1.0) return (0, false);
    if (r < 0.07) return (50, true);
    if (r < 0.16) return (25, false);
    var a = atan2(p.dy, p.dx) + pi / 2 + pi / 20;
    while (a < 0) {
      a += 2 * pi;
    }
    while (a >= 2 * pi) {
      a -= 2 * pi;
    }
    final sector = (a / (2 * pi) * 20).floor() % 20;
    final n = _numbers[sector];
    if (r >= 0.52 && r <= 0.62) return (n * 3, false);
    if (r >= 0.84 && r <= 0.96) return (n * 2, true);
    return (n, false);
  }

  String _label((int, bool) s, Offset p) {
    if (s.$1 == 0) return 'Miss';
    if (s.$1 == 50) return 'BULL! 🔴';
    if (s.$1 == 25) return 'Outer bull 25';
    final r = p.distance;
    final mult = (r >= 0.52 && r <= 0.62) ? 'Treble' : (s.$2 ? 'Double' : 'Single');
    return '$mult ${s.$1}';
  }

  void _resolveThrow() {
    final s = _score(_to);
    final rem = remaining[turn];
    final after = rem - s.$1;
    bool bust = false;
    bool won = false;
    String note;
    if (after < 0 || after == 1 || (after == 0 && !s.$2)) {
      bust = true;
      note = 'BUST! 💥 Turn wasted.';
      Sfx.lose();
    } else if (after == 0) {
      won = true;
      note = _label(s, _to);
      remaining[turn] = 0;
      widget.players[turn].score = 501;
      widget.callbacks.refreshHud();
      Sfx.win();
    } else {
      remaining[turn] = after;
      note = _label(s, _to);
      Sfx.click();
    }
    setState(() {
      flying = false;
      dartSpot = _to;
      dartsThrown++;
      throwLog.add(note);
      if (throwLog.length > 3) throwLog.removeAt(0);
    });

    if (won) {
      _endGame();
      return;
    }
    if (bust) {
      remaining[turn] = turnStart;
      _nextTurn();
      return;
    }
    if (dartsThrown >= 3) {
      _nextTurn();
      return;
    }
    _maybeBot();
  }

  void _nextTurn() {
    setState(() {
      dartsThrown = 0;
      throwLog.clear();
      dartSpot = null;
      turn = (turn + 1) % widget.players.length;
      turnStart = remaining[turn];
    });
    widget.callbacks.setActivePlayer(turn);
    _maybeBot();
  }

  void _endGame() {
    setState(() => over = true);
    final w = widget.players[turn];
    widget.callbacks.finish(
        winner: w,
        headline: '${w.name} checks out! 🏆',
        subline: '501 conquered. The oche bows to you.');
  }

  int? _checkout(int rem) {
    // returns the double number to aim for, for common checkouts
    const table = {
      50: 25, 40: 20, 36: 18, 32: 16, 24: 12, 20: 10, 16: 8, 12: 6, 8: 4, 4: 2, 2: 1,
    };
    if (table.containsKey(rem)) return table[rem];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final current = widget.players[turn];
    final rem = remaining[turn];
    final co = _checkout(rem);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!over)
            TurnBanner(
                player: current,
                action: current.isBot ? ' is stepping up… 🤖' : ', tap the board to throw!'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                    color: t.surface, borderRadius: BorderRadius.circular(16)),
                child: Text('$rem',
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: t.text)),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Row(
                    children: List.generate(
                        3,
                        (i) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text('🎯',
                                  style: TextStyle(
                                      fontSize: 22,
                                      color: i < 3 - dartsThrown
                                          ? null
                                          : Colors.transparent)),
                            )),
                  ),
                  const SizedBox(height: 4),
                  Text('darts left', style: TextStyle(color: t.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
          if (co != null && !over)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '💡 Checkout: ${co == 25 ? 'Bull' : 'Double $co'}!',
                  style: TextStyle(
                      color: t.accent, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(builder: (ctx, box) {
                  final size = box.biggest;
                  final c = Offset(size.width / 2, size.height / 2);
                  final r = size.width / 2;
                  return GestureDetector(
                    onTapDown: (d) {
                      final bp = Offset((d.localPosition.dx - c.dx) / r,
                          (d.localPosition.dy - c.dy) / r);
                      _onTapBoard(bp);
                    },
                    child: CustomPaint(
                      size: size,
                      painter: _BoardPainter(
                        theme: t,
                        flightT: flying ? _flight.value : -1,
                        dartSpot: dartSpot,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: throwLog
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(s,
                            style: TextStyle(color: t.muted, fontSize: 13)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final GameTheme theme;
  final double flightT;
  final Offset? dartSpot;

  _BoardPainter({required this.theme, required this.flightT, required this.dartSpot});

  static const _numbers = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // surround
    canvas.drawCircle(c, r, Paint()..color = theme.surface);
    // sectors
    for (int i = 0; i < 20; i++) {
      final a0 = (i / 20) * 2 * pi - pi / 2 - pi / 20;
      final a1 = a0 + 2 * pi / 20;
      final even = i % 2 == 0;
      final base = even ? const Color(0xFF1B1B1B) : const Color(0xFFF5EFE0);
      // single areas
      _wedge(canvas, c, r * 0.16, r * 0.52, a0, a1, base);
      _wedge(canvas, c, r * 0.62, r * 0.84, a0, a1, base);
      // treble / double rings
      final ring = even ? const Color(0xFFEF5350) : const Color(0xFF43A047);
      _wedge(canvas, c, r * 0.52, r * 0.62, a0, a1, ring);
      _wedge(canvas, c, r * 0.84, r * 0.96, a0, a1, ring);
      // number labels
      final mid = (a0 + a1) / 2;
      final tp = TextPainter(
        text: TextSpan(
            text: '${_numbers[i]}',
            style: TextStyle(
                color: theme.muted, fontSize: 13, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      // number labels (just inside the rim)
      final lp = c + Offset(cos(mid), sin(mid)) * r * 0.80;
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
    // bulls
    canvas.drawCircle(c, r * 0.16, Paint()..color = const Color(0xFF43A047));
    canvas.drawCircle(c, r * 0.07, Paint()..color = const Color(0xFFEF5350));

    // stuck dart
    if (dartSpot != null && flightT < 0) {
      final p = c + Offset(dartSpot!.dx * r, dartSpot!.dy * r);
      _dart(canvas, p, 1.0);
    }
    // flying dart
    if (flightT >= 0 && dartSpot != null) {
      final target = c + Offset(dartSpot!.dx * r, dartSpot!.dy * r);
      final start = Offset(size.width / 2, size.height + 60);
      final p = Offset(
        start.dx + (target.dx - start.dx) * flightT,
        start.dy + (target.dy - start.dy) * flightT - sin(flightT * pi) * 40,
      );
      _dart(canvas, p, 0.6 + 0.4 * flightT);
    }
  }

  void _wedge(Canvas canvas, Offset c, double r0, double r1, double a0,
      double a1, Color color) {
    final path = Path()
      ..moveTo(c.dx + cos(a0) * r0, c.dy + sin(a0) * r0)
      ..arcTo(Rect.fromCircle(center: c, radius: r1), a0, a1 - a0, false)
      ..lineTo(c.dx + cos(a1) * r0, c.dy + sin(a1) * r0)
      ..arcTo(Rect.fromCircle(center: c, radius: r0), a1, a0 - a1, false)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _dart(Canvas canvas, Offset tip, double s) {
    final p = Paint()
      ..color = theme.accent
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tip + Offset(0, 44 * s), tip, p);
    canvas.drawLine(tip + Offset(0, 44 * s), tip + Offset(-9 * s, 34 * s), p);
    canvas.drawLine(tip + Offset(0, 44 * s), tip + Offset(9 * s, 34 * s), p);
    canvas.drawCircle(tip, 3.5 * s, Paint()..color = theme.text);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
