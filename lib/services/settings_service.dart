import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/pub_themes.dart';

/// Game variants for Darts (RULES.md §1).
enum DartsVariant { v501, v301, countUp }

/// Persisted settings + stats for Darts. Survives app restarts.
///
/// Stores: audio toggles, player names (2 slots), theme/appearance choices
/// (incl. custom theme colors), game-mode setup (opponent, difficulty,
/// variant), Pro unlock state, and lifetime stats.
class DartsSettings extends ChangeNotifier {
  static const _kMusic = 'darts_music_on';
  static const _kSfx = 'darts_sfx_on';
  static const _kVolume = 'darts_volume';
  static const _kOpponentBot = 'darts_opponent_is_bot';
  static const _kDifficulty = 'darts_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kVariant = 'darts_variant'; // 0=501, 1=301, 2=count-up
  static const _kNames = 'darts_player_names'; // legacy unordered StringSet key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so the
  /// old key scrambled name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'darts_player_names_json';
  static const _kTheme = 'darts_theme_id';
  static const _kDartStyle = 'darts_dart_style';
  static const _kBoardStyle = 'darts_board_style';
  static const _kWins = 'darts_wins';
  static const _kGames = 'darts_games_played';
  static const _kBestDarts = 'darts_best_darts'; // fewest darts to check out
  static const _kIsPro = 'darts_is_pro';
  static const _kCustomPrefix = 'darts_custom_';

  static const defaultNames = ['You', 'Rival'];

  /// Encode the 2 player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [for (int i = 0; i < 2; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  bool opponentIsBot = true;
  int difficulty = 1; // medium default
  int variant = 0; // 501 default
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'bullsinn';
  int dartStyle = 0;
  int boardStyle = 0;
  int wins = 0;
  int gamesPlayed = 0;
  int bestDarts = 0; // fewest darts to check out (0 = none yet)
  bool isPro = true; // everything unlocked — no Pro version

  /// Custom theme colors (ARGB ints). Defaults mirror The Bull's Inn.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'woodDark': 0xFF3B2416,
    'woodMid': 0xFF5C3A21,
    'woodDeep': 0xFF241309,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFE8CE7A,
    'accentDark': 0xFF8A6D1A,
    'ivory': 0xFFF5EFE0,
    'felt': 0xFF1E4D3B,
    'ringA': 0xFFC0392B,
    'ringB': 0xFF1E8449,
    'pc0': 0xFFA31621,
    'pc1': 0xFF1D4E9E,
  };

  /// Builds the user-designed custom theme from stored colors.
  PubThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return PubThemeDef(
      id: 'custom',
      name: 'My Creation',
      woodDark: c('woodDark'),
      woodMid: c('woodMid'),
      woodDeep: c('woodDeep'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      ivory: c('ivory'),
      felt: c('felt'),
      playerColors: [c('pc0'), c('pc1')],
      playerColorNames: const ['One', 'Two'],
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    opponentIsBot = p.getBool(_kOpponentBot) ?? true;
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    variant = (p.getInt(_kVariant) ?? 0).clamp(0, 2);
    // Player names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == 2)
          ? [for (int i = 0; i < 2; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'bullsinn';
    dartStyle = (p.getInt(_kDartStyle) ?? 0).clamp(0, DartStyles.all.length - 1);
    boardStyle =
        (p.getInt(_kBoardStyle) ?? 0).clamp(0, BoardStyles.all.length - 1);
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestDarts = p.getInt(_kBestDarts) ?? 0;
    isPro = true; // everything unlocked
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setBool(_kOpponentBot, opponentIsBot);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kVariant, variant);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kDartStyle, dartStyle);
    await p.setInt(_kBoardStyle, boardStyle);
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBestDarts, bestDarts);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  /// Called after load and whenever Pro status could have changed.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    // The custom theme creator is a Pro feature ('custom' is not covered by
    // PubThemes.isProTheme, so it needs an explicit check).
    if (themeId == 'custom' || PubThemes.isProTheme(themeId)) {
      themeId = 'bullsinn';
      changed = true;
    }
    if (DartStyles.isPro(dartStyle)) {
      dartStyle = 0;
      changed = true;
    }
    if (BoardStyles.isPro(boardStyle)) {
      boardStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  /// Full mode setup: opponent human/bot, difficulty 0/1/2, variant 0/1/2.
  Future<void> setSetup({
    required bool opponentIsBot,
    required int difficulty,
    required int variant,
  }) async {
    this.opponentIsBot = opponentIsBot;
    this.difficulty = difficulty.clamp(0, 2);
    // Hard mode is a Pro feature.
    if (!isPro && this.difficulty > 1) this.difficulty = 1;
    this.variant = variant.clamp(0, 2);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    // Pro-only themes (incl. the custom theme creator) require Pro;
    // silently ignore otherwise (UI shows lock).
    if (!isPro && (id == 'custom' || PubThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setDartStyle(int v) async {
    v = v.clamp(0, DartStyles.all.length - 1);
    if (!isPro && DartStyles.isPro(v)) return;
    dartStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setBoardStyle(int v) async {
    v = v.clamp(0, BoardStyles.all.length - 1);
    if (!isPro && BoardStyles.isPro(v)) return;
    boardStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished game. [humanWon] true if a human player won.
  /// [darts] = total darts thrown by the winner (best-checkout stat).
  Future<void> recordGame({required bool humanWon, required int darts}) async {
    gamesPlayed++;
    if (humanWon) {
      wins++;
      if (bestDarts == 0 || darts < bestDarts) bestDarts = darts;
    }
    notifyListeners();
    await _save();
  }
}
