import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pub_design.dart';
import '../theme/pub_themes.dart';
import 'menu_screen.dart';

/// Launch splash (single screen, two beats):
/// 1. Company moment — the official WAJIHA winged-W mark fades in.
/// 2. Game splash — game logo + name, animated loading line, credits.
class SplashScreen extends StatefulWidget {
  final DartsAudio audio;
  final DartsSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _loader;
  late final AnimationController _company;
  bool _showGame = false;

  @override
  void initState() {
    super.initState();
    _company = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Beat 1: company moment — the official WAJIHA mark fades in.
    _company.forward();
    await Future.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;
    // Beat 2: game splash — logo + name + animated loading line + credits.
    setState(() => _showGame = true);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1750));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _company.dispose();
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = PubThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B08),
      body: _showGame
          ? _GameSplash(theme: theme, loader: _loader)
          : _CompanyMoment(theme: theme, fade: _company),
    );
  }
}

/// Company moment: the official WAJIHA winged-W mark, fading in. Beat 1 of
/// the single splash — no separate screen, no skip needed (1250 ms).
class _CompanyMoment extends StatelessWidget {
  final PubThemeDef theme;
  final AnimationController fade;
  const _CompanyMoment({required this.theme, required this.fade});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0908),
      child: Center(
        child: FadeTransition(
          opacity: fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/wajiha_logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text('WAJIHA', style: Pub.display(26, theme: theme)),
              const SizedBox(height: 4),
              Text(
                'INDIE GAMES',
                style: Pub.label(12, theme: theme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final PubThemeDef theme;
  final AnimationController loader;
  const _GameSplash({required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return PubBackdrop(
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/darts_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Darts', style: Pub.display(52, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'PUB DARTS EDITION',
              style: Pub.label(13, theme: theme),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                theme.accentLight,
                                theme.accent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1 ? 'Chalking the board…' : 'Ready!',
                      style: Pub.body(13,
                          theme: theme,
                          color: theme.ivory.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Pub.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
