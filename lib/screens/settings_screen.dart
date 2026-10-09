import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/pub_design.dart';
import '../theme/pub_themes.dart';
import 'pro_screen.dart';

/// Settings — pub drawer metaphor, theme-aware.
class SettingsScreen extends StatefulWidget {
  final DartsAudio audio;
  final DartsSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StoreService _store = StoreService();

  PubThemeDef get _t => PubThemes.byId(widget.settings.themeId,
      custom: widget.settings.customTheme);

  @override
  void initState() {
    super.initState();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
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
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  Future<void> _goPro() async {
    widget.audio.click();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: widget.audio,
        settings: widget.settings,
        store: _store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final audio = widget.audio;
    return PubBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Pub.display(22, theme: t)),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Sound', t),
                SettingRow(
                  theme: t,
                  label: 'Music',
                  control: PubToggle(
                    theme: t,
                    value: s.musicOn,
                    onChanged: (v) async {
                      audio.click();
                      await s.setMusic(v);
                      audio.configure(
                          musicOn: s.musicOn,
                          sfxOn: s.sfxOn,
                          volume: s.volume);
                      if (v) {
                        audio.startMenuMusic();
                      } else {
                        audio.stopMusic();
                      }
                    },
                  ),
                ),
                SettingRow(
                  theme: t,
                  label: 'Sound effects',
                  control: PubToggle(
                    theme: t,
                    value: s.sfxOn,
                    onChanged: (v) async {
                      await s.setSfx(v);
                      audio.configure(
                          musicOn: s.musicOn,
                          sfxOn: s.sfxOn,
                          volume: s.volume);
                      if (v) audio.click();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text('Volume', style: Pub.body(16, theme: t)),
                PubBeadSlider(
                  theme: t,
                  value: s.volume,
                  onChanged: (v) async {
                    await s.setVolume(v);
                    audio.configure(
                        musicOn: s.musicOn,
                        sfxOn: s.sfxOn,
                        volume: s.volume);
                  },
                ),
                const SizedBox(height: 10),
                _SectionTitle('Darts PRO', t),
                SettingRow(
                  theme: t,
                  label: s.isPro ? 'PRO active ✦' : 'Unlock PRO',
                  control: GestureDetector(
                    onTap: _goPro,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: s.isPro
                            ? t.accent.withValues(alpha: 0.85)
                            : Colors.black.withValues(alpha: 0.3),
                        border: Border.all(
                            color: t.accentLight, width: 2),
                      ),
                      child: Text(
                        s.isPro ? '✦ PRO' : 'View',
                        style: Pub.label(13,
                            theme: t,
                            color: s.isPro ? t.woodDeep : t.ivory),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('Appearance', t),
                SettingRow(
                  theme: t,
                  label: 'Theme',
                  control: Text(
                    PubThemes.byId(s.themeId, custom: s.customTheme).name,
                    style: Pub.label(14, theme: t),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final th in PubThemes.all)
                      GestureDetector(
                        onTap: () async {
                          audio.click();
                          final locked = PubThemes.isProTheme(th.id) &&
                              !s.isPro;
                          if (locked) {
                            await _goPro();
                            return;
                          }
                          await s.setTheme(th.id);
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(colors: [
                                  th.woodMid,
                                  th.accent,
                                ]),
                                border: Border.all(
                                  color: s.themeId == th.id
                                      ? th.accentLight
                                      : th.accent.withValues(alpha: 0.3),
                                  width: s.themeId == th.id ? 3 : 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  for (int i = 0; i < 2; i++)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: th.playerColors[i],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (PubThemes.isProTheme(th.id) &&
                                !s.isPro)
                              Container(
                                width: 64,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  color: Colors.black
                                      .withValues(alpha: 0.55),
                                ),
                                child: Icon(Icons.lock,
                                    color: t.accentLight, size: 18),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Dart style', style: Pub.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < DartStyles.all.length; i++)
                      _MiniChip(
                        theme: t,
                        label:
                            '${DartStyles.isPro(i) && !s.isPro ? '🔒 ' : ''}${DartStyles.all[i].name}',
                        selected: s.dartStyle == i,
                        onTap: () async {
                          audio.click();
                          if (DartStyles.isPro(i) && !s.isPro) {
                            await _goPro();
                            return;
                          }
                          await s.setDartStyle(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Board style', style: Pub.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < BoardStyles.all.length; i++)
                      _MiniChip(
                        theme: t,
                        label:
                            '${BoardStyles.isPro(i) && !s.isPro ? '🔒 ' : ''}${BoardStyles.all[i].name}',
                        selected: s.boardStyle == i,
                        onTap: () async {
                          audio.click();
                          if (BoardStyles.isPro(i) && !s.isPro) {
                            await _goPro();
                            return;
                          }
                          await s.setBoardStyle(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionTitle('Support', t),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: t.woodDeep.withValues(alpha: 0.65),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Darts is 100% free. Tips keep the pub open!',
                        style: Pub.body(14, theme: t),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Builder(builder: (_) {
                        final tips = [
                          _store.coffeeProduct,
                          _store.chocolateProduct,
                        ].whereType<ProductDetails>().toList();
                        if (!_store.storeReady) {
                          return Text(
                            _store.error ?? 'Loading…',
                            style: Pub.body(13,
                                theme: t,
                                color:
                                    t.ivory.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                          );
                        }
                        if (tips.isEmpty) {
                          return Text('Tips coming soon.',
                              style: Pub.body(13,
                                  theme: t,
                                  color: t.ivory
                                      .withValues(alpha: 0.6)));
                        }
                        return Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in tips)
                              _MiniChip(
                                theme: t,
                                label: p.id == StoreService.chocolateId
                                    ? '🍫 ${p.price}'
                                    : '☕ ${p.price}',
                                selected: false,
                                onTap: () {
                                  audio.click();
                                  _store.buyTip(p);
                                },
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('About', t),
                Text(
                  'Darts — Pub Darts edition.\nVersion 2.0.0 • Made with ♥ by WAJIHA',
                  style: Pub.body(13,
                      theme: t,
                      color: t.ivory.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final PubThemeDef theme;
  const _SectionTitle(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: Pub.display(19, theme: theme)),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final PubThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MiniChip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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
              theme: theme,
              color: selected ? theme.woodDeep : theme.ivory),
        ),
      ),
    );
  }
}
