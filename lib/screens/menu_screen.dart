import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/darts_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/pub_design.dart';
import '../theme/pub_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu — pub darts edition.
/// Logo, PLAY, mode setup (variant / opponent / difficulty), appearance
/// picker (themes + dart styles + board styles), player renaming, tip jar,
/// settings.
class MenuScreen extends StatefulWidget {
  final DartsAudio audio;
  final DartsSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  DartsSettings get _s => widget.settings;
  PubThemeDef get _t =>
      PubThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Pub.body(15, theme: _t)),
        backgroundColor: _t.woodDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _play() {
    widget.audio.gameStart();
    final colors = _t.playerColors;
    final players = [
      DartsPlayer(
          name: _s.playerNames[0], color: colors[0], isBot: false),
      DartsPlayer(
          name: _s.playerNames[1],
          color: colors[1],
          isBot: _s.opponentIsBot),
    ];
    final engine = DartsEngine(
      players: players,
      botDifficulty: BotDifficulty.values[_s.difficulty],
      variant: DartsVariant.values[_s.variant],
    );
    // App-scoped music: keep playing across screens. GameScreen switches
    // to the game track on entry; we switch back to menu music on return.
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return PubBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo plaque.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        Image.asset('assets/darts_logo.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Darts', style: Pub.display(46, theme: t)),
                  Text(
                    'PUB DARTS EDITION',
                    style: Pub.label(12, theme: t),
                  ),
                  const SizedBox(height: 22),
                  PubButton(
                      label: '🎯  Play', onTap: _play, theme: t, width: 260),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: widget.audio,
                          settings: _s,
                          store: _store,
                        ),
                      ));
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.accentDark,
                        ]),
                        border: Border.all(
                            color: t.accentLight, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _s.isPro ? '✦  PRO ACTIVE' : '✦  Get PRO',
                        style: Pub.label(17, theme: t, color: t.woodDeep),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ModeCard(theme: t),
                  const SizedBox(height: 14),
                  _AppearanceCard(theme: t),
                  const SizedBox(height: 14),
                  _NamesCard(theme: t),
                  const SizedBox(height: 14),
                  _SupportCard(theme: t, store: _store),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () async {
                          widget.audio.click();
                          // ignore: deprecated_member_use
                          await Share.share(
                              'Play Darts with me! https://play.google.com/store/apps/details?id=com.gameswajiha.darts');
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          await _requestReview();
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 26),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.gamesPlayed > 0)
                    Text(
                      'Wins: ${_s.wins}   •   Games: ${_s.gamesPlayed}${_s.bestDarts > 0 ? '   •   Best: ${_s.bestDarts} darts' : ''}',
                      style: Pub.label(12, theme: t),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Pub.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, PubThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Pub.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Tap the dartboard to throw. You get 3 darts per turn.',
                  '• Count down from 501 (or 301) — hit exactly 0 to win.',
                  '• You MUST finish on a double (or the bullseye)!',
                  '• Go below 0, land on 1, or miss the double? BUST — turn wasted!',
                  '• Count-Up: 10 rounds of 3 darts, highest total wins.',
                  '• Watch for checkout hints when you get close.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Pub.body(14, theme: t)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: PubButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final PubThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.woodMid, theme.woodDeep],
              ),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Pub.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Mode setup: variant (501/301/Count-Up), opponent human/bot, difficulty.
class _ModeCard extends StatelessWidget {
  final PubThemeDef theme;
  const _ModeCard({required this.theme});

  static const difficulties = ['Easy', 'Medium', 'Hard'];
  static const variants = ['501', '301', 'Count-Up'];

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Game Mode',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Game:', style: Pub.body(15, theme: theme)),
              const SizedBox(width: 12),
              for (int v = 0; v < 3; v++)
                _Chip(
                  theme: theme,
                  label: variants[v],
                  selected: s.variant == v,
                  onTap: () {
                    audio.click();
                    s.setSetup(
                        opponentIsBot: s.opponentIsBot,
                        difficulty: s.difficulty,
                        variant: v);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Opponent:', style: Pub.body(15, theme: theme)),
              const SizedBox(width: 12),
              _Chip(
                theme: theme,
                label: '🧍 Human',
                selected: !s.opponentIsBot,
                onTap: () {
                  audio.click();
                  s.setSetup(
                      opponentIsBot: false,
                      difficulty: s.difficulty,
                      variant: s.variant);
                },
              ),
              _Chip(
                theme: theme,
                label: '🤖 Bot',
                selected: s.opponentIsBot,
                onTap: () {
                  audio.click();
                  s.setSetup(
                      opponentIsBot: true,
                      difficulty: s.difficulty,
                      variant: s.variant);
                },
              ),
            ],
          ),
          if (s.opponentIsBot) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Bot mode:', style: Pub.body(15, theme: theme)),
                const SizedBox(width: 12),
                for (int d = 0; d < 3; d++)
                  _Chip(
                    theme: theme,
                    label: '${d == 2 && !s.isPro ? '🔒 ' : ''}${difficulties[d]}',
                    selected: s.difficulty == d,
                    onTap: () async {
                      audio.click();
                      if (d == 2 && !s.isPro) {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProScreen(
                            audio: audio,
                            settings: s,
                            store: screen._store,
                          ),
                        ));
                        return;
                      }
                      s.setSetup(
                          opponentIsBot: s.opponentIsBot,
                          difficulty: d,
                          variant: s.variant);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Appearance picker: themes + custom creator, dart styles, board styles.
class _AppearanceCard extends StatelessWidget {
  final PubThemeDef theme;
  const _AppearanceCard({required this.theme});

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isPro = s.isPro;
    return _Card(
      theme: theme,
      title: 'Pub Style',
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final th in PubThemes.all)
                _ThemeTile(
                  theme: theme,
                  th: th,
                  selected: s.themeId == th.id,
                  locked: PubThemes.isProTheme(th.id) && !isPro,
                  onTap: () {
                    audio.click();
                    if (PubThemes.isProTheme(th.id) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setTheme(th.id);
                  },
                ),
              // Custom theme tile (PRO).
              _ThemeTile(
                theme: theme,
                th: s.customTheme,
                selected: s.themeId == 'custom',
                locked: !isPro,
                custom: true,
                onTap: () {
                  audio.click();
                  if (!isPro) {
                    _goPro(context, screen);
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${PubThemes.all.length - PubThemes.freeThemeIds.length} more themes in PRO',
                style: Pub.label(12, theme: theme),
              ),
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Dart style:', style: Pub.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < DartStyles.all.length; i++)
                _Chip(
                  theme: theme,
                  label:
                      '${DartStyles.isPro(i) && !isPro ? '🔒 ' : ''}${DartStyles.all[i].name}',
                  selected: s.dartStyle == i,
                  onTap: () {
                    audio.click();
                    if (DartStyles.isPro(i) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setDartStyle(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Board style:', style: Pub.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < BoardStyles.all.length; i++)
                _Chip(
                  theme: theme,
                  label:
                      '${BoardStyles.isPro(i) && !isPro ? '🔒 ' : ''}${BoardStyles.all[i].name}',
                  selected: s.boardStyle == i,
                  onTap: () {
                    audio.click();
                    if (BoardStyles.isPro(i) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setBoardStyle(i);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final PubThemeDef theme;
  final PubThemeDef th;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.theme,
    required this.th,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: th.woodDeep.withValues(alpha: 0.7),
              border: Border.all(
                color: selected
                    ? th.accentLight
                    : th.accent.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in th.playerColors)
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border:
                              Border.all(color: th.accentLight, width: 1),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  custom ? '🎨 My Creation' : th.name,
                  style: Pub.label(10, theme: th),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 96,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child:
                  Icon(Icons.lock, color: theme.accentLight, size: 22),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Rename the two player seats.
class _NamesCard extends StatelessWidget {
  final PubThemeDef theme;
  const _NamesCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return _Card(
      theme: theme,
      title: 'Player Names',
      child: Column(
        children: [
          for (int i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.playerColors[i],
                      border:
                          Border.all(color: theme.accentLight, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NameField(
                      theme: theme,
                      index: i,
                      initial: s.playerNames[i],
                      onDone: (v) => s.setPlayerName(i, v),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Names show on score cards, banners and the winner plaque.',
            style: Pub.body(12,
                theme: theme, color: theme.ivory.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final PubThemeDef theme;
  final int index;
  final String initial;
  final ValueChanged<String> onDone;
  const _NameField(
      {required this.theme,
      required this.index,
      required this.initial,
      required this.onDone});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.3),
        border:
            Border.all(color: widget.theme.accent.withValues(alpha: 0.5)),
      ),
      child: Focus(
        // Commit the name when the field loses focus (tap elsewhere).
        onFocusChange: (focused) {
          if (!focused) widget.onDone(_c.text);
        },
        child: TextField(
          controller: _c,
          style: Pub.body(15, theme: widget.theme),
          maxLength: 14,
          decoration: InputDecoration(
            counterText: '',
            border: InputBorder.none,
            hintText: 'Player ${widget.index + 1}',
            hintStyle: Pub.body(14,
                theme: widget.theme,
                color: widget.theme.ivory.withValues(alpha: 0.4)),
          ),
          // Save on EVERY keystroke — names live in the order-preserving
          // JSON key, so mid-edit crashes can never scramble slots.
          onChanged: widget.onDone,
          onSubmitted: widget.onDone,
          onEditingComplete: () => widget.onDone(_c.text),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Tip jar (IAP).
class _SupportCard extends StatelessWidget {
  final PubThemeDef theme;
  final StoreService store;
  const _SupportCard({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Support Wajiha',
      child: Column(
        children: [
          Text(
            'Darts is 100% free. If it made you smile, a small tip keeps the pub open!',
            style: Pub.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final tips = [
              store.coffeeProduct,
              store.chocolateProduct,
            ].whereType<ProductDetails>().toList();
            if (!store.storeReady) {
              return Text(
                store.error ?? 'Loading…',
                style: Pub.body(13,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              );
            }
            if (tips.isEmpty) {
              return Text('Tips coming soon.',
                  style: Pub.body(13,
                      theme: theme,
                      color: theme.ivory.withValues(alpha: 0.6)));
            }
            return Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _Chip(
                    theme: theme,
                    label: p.id == StoreService.chocolateId
                        ? '🍫 ${p.price}'
                        : '☕ ${p.price}',
                    selected: false,
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final PubThemeDef theme;
  final String title;
  final Widget child;
  const _Card(
      {required this.theme, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.woodMid.withValues(alpha: 0.85),
            theme.woodDeep.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: Pub.display(20, theme: theme)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final PubThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Pub.label(13,
              theme: theme, color: selected ? theme.woodDeep : theme.ivory),
        ),
      ),
    );
  }
}
