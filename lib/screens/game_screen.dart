import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/darts_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pub_design.dart';
import '../theme/pub_themes.dart';

/// Darts game screen.
///
/// - Every player side has its OWN score card with a dart tray: it activates
///   and glows on the current player's turn (human or bot).
/// - Every throw — human or bot — flies with a visible animation, a whoosh,
///   a thud, and narration. Bot turns are never silently auto-played.
/// - The engine owns the turn state machine, so the UI can never desync.
class GameScreen extends StatefulWidget {
  final DartsEngine engine;
  final DartsAudio audio;
  final DartsSettings settings;

  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flightCtrl;
  ThrowAnim? _shownAnim;
  bool _paused = false;
  /// Last drag position (widget coords) for drag-to-throw: the dart is
  /// thrown where the finger LIFTS, so players can aim by sliding.
  Offset? _dragPos;

  DartsEngine get _e => widget.engine;
  PubThemeDef get _t => PubThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );
  DartStyleDef get _dartStyle =>
      DartStyles.all[widget.settings.dartStyle.clamp(
          0, DartStyles.all.length - 1)];
  BoardStyleDef get _boardStyle {
    final base = BoardStyles.all[widget.settings.boardStyle
        .clamp(0, BoardStyles.all.length - 1)];
    if (widget.settings.themeId == 'custom') {
      // The theme creator's ring colors repaint the physical board.
      Color c(String k) =>
          Color(widget.settings.customColors[k] ?? 0xFF000000);
      return BoardStyleDef(
        name: base.name,
        ringA: c('ringA'),
        ringB: c('ringB'),
        sectorDark: base.sectorDark,
        sectorLight: base.sectorLight,
        wire: base.wire,
        surround: base.surround,
        numberColor: base.numberColor,
      );
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flightCtrl = AnimationController(vsync: this);
    _e.onEvent = _onEngineEvent;
    _e.addListener(_onEngineChanged);
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flightCtrl.dispose();
    _e.removeListener(_onEngineChanged);
    _e.onEvent = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      if (!_e.over && mounted) {
        setState(() {
          _paused = true;
          _e.setPaused(true);
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  void _onEngineChanged() {
    if (!mounted) return;
    // Drive the flight-animation controller from the engine's ThrowAnim.
    final anim = _e.flight;
    if (anim != null && !identical(anim, _shownAnim)) {
      _shownAnim = anim;
      _flightCtrl.duration = Duration(milliseconds: anim.totalMs);
      _flightCtrl.forward(from: 0);
    } else if (anim == null) {
      _shownAnim = null;
    }
    setState(() {});
    if (_e.over) _onGameOver();
  }

  Future<void> _onEngineEvent(DartsEvent event) async {
    final a = widget.audio;
    switch (event) {
      case DartsEvent.throwLaunched:
        await a.throwWhoosh();
        break;
      case DartsEvent.dartLanded:
        await a.dartThud();
        break;
      case DartsEvent.bust:
        await a.bust();
        break;
      case DartsEvent.cheer180:
        await a.cheer180();
        break;
      case DartsEvent.invalid:
        await a.invalid();
        break;
      case DartsEvent.humanWon:
      case DartsEvent.draw:
        await a.win();
        break;
      case DartsEvent.botWon:
        await a.lose();
        break;
    }
  }

  Future<void> _onGameOver() async {
    final humanWon = !_e.draw && !_e.players[_e.winner].isBot;
    final winnerDarts =
        _e.winner >= 0 ? _e.dartsThrown[_e.winner] : 0;
    await widget.settings.recordGame(humanWon: humanWon, darts: winnerDarts);
    // Ask for a review at a sensible moment: after every 3rd played game,
    // only when the human won or drew.
    if (humanWon && widget.settings.gamesPlayed % 3 == 0) {
      _requestReview();
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        engine: _e,
        humanWon: humanWon,
        audio: widget.audio,
        theme: _t,
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _e.restart();
      widget.audio.startGameMusic();
    } else {
      // App-scoped music: keep playing; menu switches back to menu track.
      Navigator.of(context).pop();
    }
  }

  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {
      // Silent when unavailable — never a fake dialog.
    }
  }

  void _onBoardTap(Offset boardPoint) {
    if (_paused || _e.over) return;
    _e.throwDart(boardPoint);
  }

  /// Convert a widget-space point on the board area to board coords.
  void _throwAtWidgetPoint(Size size, Offset local) {
    final r = size.width / 2 * _boardScale;
    final bp = Offset(
      (local.dx - size.width / 2) / r,
      (local.dy - size.height / 2) / r,
    );
    _onBoardTap(bp);
  }

  void _togglePause() {
    widget.audio.click();
    setState(() {
      _paused = !_paused;
      _e.setPaused(_paused);
      if (_paused) {
        widget.audio.onAppPaused();
      } else {
        widget.audio.onAppResumed();
      }
    });
  }

  void _restart() {
    widget.audio.gameStart();
    _e.restart();
    if (_paused) {
      setState(() {
        _paused = false;
        _e.setPaused(false);
      });
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return PubBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause,
                color: t.accentLight),
            onPressed: _togglePause,
          ),
          title: Text('Darts', style: Pub.display(22, theme: t)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: t.accentLight),
              tooltip: 'Restart',
              onPressed: _restart,
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Per-side score cards with dart trays.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                            child: _PlayerCard(
                                pi: 0, theme: t, dartStyle: _dartStyle)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _PlayerCard(
                                pi: 1, theme: t, dartStyle: _dartStyle)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Narration banner.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _e.banner,
                        key: ValueKey(_e.banner),
                        style: Pub.body(15, theme: t),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_e.checkoutHint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: t.accent.withValues(alpha: 0.25),
                          border: Border.all(color: t.accentLight),
                        ),
                        child: Text(_e.checkoutHint!,
                            style: Pub.label(13, theme: t)),
                      ),
                    ),
                  const SizedBox(height: 6),
                  // The board.
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(builder: (ctx, box) {
                          final size = box.biggest;
                          return GestureDetector(
                            // Tap throws on lift; drag lets players aim by
                            // sliding, throwing where the finger lifts. The
                            // gesture arena guarantees exactly one of the
                            // two fires — a tap never also pan-fires.
                            onTapUp: (d) => _throwAtWidgetPoint(
                                size, d.localPosition),
                            onPanUpdate: (d) =>
                                _dragPos = d.localPosition,
                            onPanEnd: (_) {
                              final p = _dragPos;
                              _dragPos = null;
                              if (p != null) _throwAtWidgetPoint(size, p);
                            },
                            onPanCancel: () => _dragPos = null,
                            child: AnimatedBuilder(
                              animation: _flightCtrl,
                              builder: (_, _) => CustomPaint(
                                size: size,
                                painter: _DartboardPainter(
                                  theme: t,
                                  board: _boardStyle,
                                  dart: _dartStyle,
                                  flightT:
                                      _shownAnim != null ? _flightCtrl.value : -1,
                                  flightTo: _shownAnim?.to,
                                  stuck: _e.stuckDarts,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  // This turn's throw log.
                  SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _e.throwLog
                          .map((s) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(s,
                                    style: Pub.body(13,
                                        theme: t,
                                        color: t.ivory
                                            .withValues(alpha: 0.8))),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              if (_paused) _PauseOverlay(theme: t, onResume: _togglePause),
            ],
          ),
        ),
      ),
    );
  }
}

/// Board scoring area as a fraction of the half-width.
const double _boardScale = 0.84;

// ---------------------------------------------------------------------------
/// Per-side score card: name, big score, dart tray, active glow.
class _PlayerCard extends StatelessWidget {
  final int pi;
  final PubThemeDef theme;
  final DartStyleDef dartStyle;
  const _PlayerCard(
      {required this.pi, required this.theme, required this.dartStyle});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_GameScreenState>()!;
    final e = screen._e;
    final p = e.players[pi];
    final active = !e.over && e.turn == pi;
    final score = e.scoreOf(pi);
    final dartsLeft = active ? e.dartsLeft : 3;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.woodMid, theme.woodDeep],
        ),
        border: Border.all(
          color: active ? theme.accentLight : theme.accent.withValues(alpha: 0.4),
          width: active ? 3 : 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: theme.accentLight.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.color,
                  border: Border.all(color: theme.accentLight, width: 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${p.name}${p.isBot ? ' 🤖' : ''}',
                  style: Pub.label(13, theme: theme),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: Pub.display(30, theme: theme, color: theme.ivory),
          ),
          const SizedBox(height: 4),
          // The dart tray: each side's own darts, depleting as thrown.
          Row(
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Opacity(
                  opacity: i < dartsLeft ? 1.0 : 0.25,
                  child: CustomPaint(
                    size: const Size(14, 22),
                    painter: _MiniDartPainter(dartStyle),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny dart glyph for the dart tray.
class _MiniDartPainter extends CustomPainter {
  final DartStyleDef dart;
  _MiniDartPainter(this.dart);

  @override
  void paint(Canvas canvas, Size size) {
    final tip = Offset(size.width / 2, size.height - 2);
    final dir = const Offset(-0.25, -1) / const Offset(-0.25, -1).distance;
    final end = tip + dir * 18;
    // Shaft.
    canvas.drawLine(
      tip,
      end,
      Paint()
        ..color = dart.barrel
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // Flights.
    final f1 = end + dir * -4;
    final perp = Offset(-dir.dy, dir.dx);
    final path = Path()
      ..moveTo(f1.dx, f1.dy)
      ..lineTo((end + perp * 5).dx, (end + perp * 5).dy)
      ..lineTo((end - perp * 5).dx, (end - perp * 5).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = dart.flight);
    // Tip.
    canvas.drawCircle(tip, 2, Paint()..color = const Color(0xFFB9B2A4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
/// The pub dartboard: wood surround, sisal sectors, wire, stuck + flying darts.
class _DartboardPainter extends CustomPainter {
  final PubThemeDef theme;
  final BoardStyleDef board;
  final DartStyleDef dart;
  final double flightT; // -1 = no flight
  final Offset? flightTo; // board coords
  final List<Offset> stuck; // board coords, this turn

  _DartboardPainter({
    required this.theme,
    required this.board,
    required this.dart,
    required this.flightT,
    required this.flightTo,
    required this.stuck,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final br = r * _boardScale; // scoring radius

    // Wooden surround + drop shadow.
    canvas.drawCircle(
      c + const Offset(0, 8),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [theme.woodMid, theme.woodDark, theme.woodDeep],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
        c, r, Paint()..style = PaintingStyle.stroke..color = theme.accent..strokeWidth = 3);

    // Backing felt ring.
    canvas.drawCircle(c, br * 1.02, Paint()..color = board.surround);

    // Sectors.
    for (int i = 0; i < 20; i++) {
      final a0 = (i / 20) * 2 * pi - pi / 2 - pi / 20;
      final a1 = a0 + 2 * pi / 20;
      final even = i % 2 == 0;
      final single = even ? board.sectorDark : board.sectorLight;
      final ring = even ? board.ringA : board.ringB;
      _wedge(canvas, c, br * 0.16, br * 0.52, a0, a1, single);
      _wedge(canvas, c, br * 0.62, br * 0.84, a0, a1, single);
      _wedge(canvas, c, br * 0.52, br * 0.62, a0, a1, ring);
      _wedge(canvas, c, br * 0.84, br * 0.96, a0, a1, ring);
      // Number labels on the surround.
      final mid = (a0 + a1) / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: '${boardNumbers[i]}',
          style: TextStyle(
            color: board.numberColor,
            fontSize: r * 0.055,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelPos = c + Offset(cos(mid), sin(mid)) * (br + r * 0.055);
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }

    // Wire: ring boundaries + radial separators.
    final wirePaint = Paint()
      ..color = board.wire
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, r * 0.004);
    for (final rr in [0.16, 0.52, 0.62, 0.84, 0.96]) {
      canvas.drawCircle(c, br * rr, wirePaint);
    }
    for (int i = 0; i < 20; i++) {
      final a = (i / 20) * 2 * pi - pi / 2 - pi / 20;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * br * 0.16,
        c + Offset(cos(a), sin(a)) * br * 0.96,
        wirePaint,
      );
    }

    // Bulls.
    canvas.drawCircle(c, br * 0.16, Paint()..color = board.ringB);
    canvas.drawCircle(c, br * 0.07, Paint()..color = board.ringA);
    canvas.drawCircle(c, br * 0.16, wirePaint);
    canvas.drawCircle(c, br * 0.07, wirePaint);

    // Stuck darts (this turn).
    for (final s in stuck) {
      final p = c + Offset(s.dx * br, s.dy * br);
      _drawDart(canvas, p, 1.0);
    }
    // Flying dart.
    if (flightT >= 0 && flightTo != null) {
      final target = c + Offset(flightTo!.dx * br, flightTo!.dy * br);
      final start = Offset(size.width / 2, size.height + r * 0.35);
      final p = Offset(
        start.dx + (target.dx - start.dx) * flightT,
        start.dy +
            (target.dy - start.dy) * flightT -
            sin(flightT * pi) * r * 0.12,
      );
      _drawDart(canvas, p, 0.55 + 0.45 * flightT);
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

  /// A physical dart: tip, metal barrel, stem, flights — angled out of board.
  void _drawDart(Canvas canvas, Offset tip, double s) {
    final dir = const Offset(-0.28, -1) / const Offset(-0.28, -1).distance;
    final barrelEnd = tip + dir * 34 * s;
    final stemEnd = tip + dir * 46 * s;
    // Shadow on the board.
    canvas.drawLine(
      tip + const Offset(3, 3),
      barrelEnd + const Offset(3, 3),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 6 * s
        ..strokeCap = StrokeCap.round,
    );
    // Barrel.
    canvas.drawLine(
      tip,
      barrelEnd,
      Paint()
        ..color = dart.barrel
        ..strokeWidth = 7 * s
        ..strokeCap = StrokeCap.round,
    );
    // Barrel highlight.
    canvas.drawLine(
      tip + const Offset(-1.5, 0),
      barrelEnd + const Offset(-1.5, 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round,
    );
    // Stem.
    canvas.drawLine(
      barrelEnd,
      stemEnd,
      Paint()
        ..color = dart.stem
        ..strokeWidth = 3.5 * s
        ..strokeCap = StrokeCap.round,
    );
    // Flights (two vanes).
    final perp = Offset(-dir.dy, dir.dx);
    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(stemEnd.dx, stemEnd.dy)
        ..lineTo((stemEnd - dir * 14 * s + perp * 11 * s * side).dx,
            (stemEnd - dir * 14 * s + perp * 11 * s * side).dy)
        ..lineTo((stemEnd - dir * 4 * s + perp * 4 * s * side).dx,
            (stemEnd - dir * 4 * s + perp * 4 * s * side).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = dart.flight);
    }
    // Tip point.
    canvas.drawCircle(tip, 3 * s, Paint()..color = const Color(0xFFD8D2C4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final PubThemeDef theme;
  final VoidCallback onResume;
  const _PauseOverlay({required this.theme, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_GameScreenState>()!;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [theme.woodMid, theme.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: theme.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Pub.display(30, theme: theme)),
              const SizedBox(height: 20),
              PubButton(
                  label: 'Resume',
                  width: 200,
                  fontSize: 17,
                  theme: theme,
                  onTap: onResume),
              const SizedBox(height: 10),
              PubButton(
                  label: 'Restart',
                  width: 200,
                  fontSize: 17,
                  theme: theme,
                  onTap: screen._restart),
              const SizedBox(height: 10),
              PubButton(
                  label: 'Quit',
                  width: 200,
                  fontSize: 17,
                  theme: theme,
                  onTap: () {
                    screen.widget.audio.click();
                    Navigator.of(context).pop();
                  }),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _GameOverDialog extends StatelessWidget {
  final DartsEngine engine;
  final bool humanWon;
  final DartsAudio audio;
  final PubThemeDef theme;
  const _GameOverDialog({
    required this.engine,
    required this.humanWon,
    required this.audio,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final w = engine.winner >= 0 ? engine.players[engine.winner] : null;
    final title = engine.draw
        ? "It's a draw!"
        : humanWon
            ? '${w!.name} wins! 🏆'
            : '${w!.name} wins';
    final sub = engine.draw
        ? 'Dead level after ${DartsEngine.countUpRounds} rounds. Rematch?'
        : engine.isCountUp
            ? 'Final: ${engine.totals[0]} – ${engine.totals[1]}'
            : '${w!.name} checked out in ${engine.dartsThrown[engine.winner]} darts.';
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
              colors: [theme.woodMid, theme.woodDeep],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          border: Border.all(color: theme.accent, width: 3),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 8),
                blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: Pub.display(28, theme: theme),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(sub,
                style: Pub.body(15, theme: theme),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            PubButton(
              label: '🔁  Play Again',
              width: 220,
              fontSize: 17,
              theme: theme,
              onTap: () {
                audio.click();
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 10),
            PubButton(
              label: 'Menu',
              width: 220,
              fontSize: 17,
              theme: theme,
              onTap: () {
                audio.click();
                Navigator.of(context).pop(false);
              },
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.share, color: theme.accentLight),
                  tooltip: 'Share',
                  onPressed: () async {
                    audio.click();
                    // ignore: deprecated_member_use
                    await Share.share(
                        'I just played Darts! Think you can beat me? https://play.google.com/store/apps/details?id=com.gameswajiha.darts');
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.star_rate, color: theme.accentLight),
                  tooltip: 'Rate',
                  onPressed: () async {
                    audio.click();
                    final review = InAppReview.instance;
                    try {
                      if (await review.isAvailable()) {
                        await review.requestReview();
                      } else {
                        await review.openStoreListing(appStoreId: null);
                      }
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
