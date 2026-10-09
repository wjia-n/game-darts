import 'package:flutter_test/flutter_test.dart';
import 'package:darts/services/settings_service.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Player names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// names came back in arbitrary order and renames appeared "not saved".
/// Names are now stored as one order-preserving JSON string. These tests
/// cover the encode/decode round-trip without needing platform channels.
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Bot Bob'];
    final decoded = DartsSettings.decodePlayerNames(
        DartsSettings.encodePlayerNames(names));
    expect(decoded, names);
  });

  test('decode falls back to defaults on corrupt input', () {
    expect(DartsSettings.decodePlayerNames(null),
        DartsSettings.defaultNames);
    expect(DartsSettings.decodePlayerNames('not json'),
        DartsSettings.defaultNames);
    expect(DartsSettings.decodePlayerNames('["a"]'),
        DartsSettings.defaultNames);
  });

  test('blank names fall back to slot defaults', () {
    final decoded = DartsSettings.decodePlayerNames('["", "Zara"]');
    expect(decoded, ['You', 'Zara']);
  });
}
