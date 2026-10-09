import 'package:flutter/material.dart';

/// Theme, dart-style and board-style catalogs for Darts.
///
/// Every theme stays inside the classic pub-darts material world: dark woods,
/// brass/copper, warm lamplight, sisal boards, real physical darts.
/// No neon, no cyberpunk, no generic AI-dashboard looks.
class PubThemeDef {
  final String id;
  final String name;
  final Color woodDark; // backdrop base
  final Color woodMid; // cards / panels
  final Color woodDeep; // deepest shadow
  final Color accent; // brass / copper …
  final Color accentLight;
  final Color accentDark;
  final Color ivory; // text
  final Color felt; // back wall / bar panel
  final List<Color> playerColors; // 2 seats
  final List<String> playerColorNames;

  const PubThemeDef({
    required this.id,
    required this.name,
    required this.woodDark,
    required this.woodMid,
    required this.woodDeep,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.felt,
    required this.playerColors,
    required this.playerColorNames,
  });
}

class PubThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'bullsinn',
    'mahogany',
    'dublinsnug',
    'midnight',
  ];

  static const List<PubThemeDef> all = [
    PubThemeDef(
      id: 'bullsinn',
      name: "The Bull's Inn",
      woodDark: Color(0xFF3B2416),
      woodMid: Color(0xFF5C3A21),
      woodDeep: Color(0xFF241309),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF1E4D3B),
      playerColors: [Color(0xFFA31621), Color(0xFF1D4E9E)],
      playerColorNames: ['Ruby', 'Sapphire'],
    ),
    PubThemeDef(
      id: 'mahogany',
      name: 'Royal Mahogany',
      woodDark: Color(0xFF4A1F14),
      woodMid: Color(0xFF6E2F1C),
      woodDeep: Color(0xFF2B1009),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      felt: Color(0xFF3D1F2E),
      playerColors: [Color(0xFFC0392B), Color(0xFF7D3C98)],
      playerColorNames: ['Garnet', 'Amethyst'],
    ),
    PubThemeDef(
      id: 'dublinsnug',
      name: 'Dublin Snug',
      woodDark: Color(0xFF2E3B22),
      woodMid: Color(0xFF4A5A34),
      woodDeep: Color(0xFF1A2312),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF0F3D2E),
      playerColors: [Color(0xFF1B7A4D), Color(0xFFD99A2B)],
      playerColorNames: ['Emerald', 'Amber'],
    ),
    PubThemeDef(
      id: 'midnight',
      name: 'Midnight Library',
      woodDark: Color(0xFF1C2438),
      woodMid: Color(0xFF2C3A55),
      woodDeep: Color(0xFF101624),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFE8ECF5),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      felt: Color(0xFF1B2A4A),
      playerColors: [Color(0xFFD64545), Color(0xFF4A90D9)],
      playerColorNames: ['Candle', 'Moonstone'],
    ),
    PubThemeDef(
      id: 'fireside',
      name: 'Fireside Hearth',
      woodDark: Color(0xFF5A2A1A),
      woodMid: Color(0xFF7C3F24),
      woodDeep: Color(0xFF381408),
      accent: Color(0xFFE09E5A),
      accentLight: Color(0xFFF5CE8E),
      accentDark: Color(0xFF9A5E24),
      ivory: Color(0xFFF7EFE0),
      felt: Color(0xFF4A2E1F),
      playerColors: [Color(0xFFE67E22), Color(0xFF8E2A20)],
      playerColorNames: ['Ember', 'Hearth'],
    ),
    PubThemeDef(
      id: 'whiskey',
      name: 'Whiskey Lounge',
      woodDark: Color(0xFF3B2416),
      woodMid: Color(0xFF5C3A21),
      woodDeep: Color(0xFF241309),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF4A2E1A),
      playerColors: [Color(0xFFCA8A2B), Color(0xFF6E2C00)],
      playerColorNames: ['Bronze', 'Cocoa'],
    ),
    PubThemeDef(
      id: 'oakhall',
      name: 'Oak Hall',
      woodDark: Color(0xFF7A5A24),
      woodMid: Color(0xFF9A7534),
      woodDeep: Color(0xFF4A3614),
      accent: Color(0xFF8C6A2F),
      accentLight: Color(0xFFD4A94E),
      accentDark: Color(0xFF5F471E),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF4A5A2A),
      playerColors: [Color(0xFF922B21), Color(0xFF1A5276)],
      playerColorNames: ['Oxblood', 'Navy'],
    ),
    PubThemeDef(
      id: 'sailors',
      name: "Sailor's Rest",
      woodDark: Color(0xFF3E3226),
      woodMid: Color(0xFF5D4C36),
      woodDeep: Color(0xFF26201A),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      felt: Color(0xFF274A56),
      playerColors: [Color(0xFF2471A3), Color(0xFFB03A2E)],
      playerColorNames: ['Teal', 'Brick'],
    ),
    PubThemeDef(
      id: 'gentclub',
      name: "Gentleman's Club",
      woodDark: Color(0xFF1A1A1E),
      woodMid: Color(0xFF2A2A30),
      woodDeep: Color(0xFF0C0C0E),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFF0F2F8),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      felt: Color(0xFF2A2A34),
      playerColors: [Color(0xFFE74C3C), Color(0xFFF39C12)],
      playerColorNames: ['Flame', 'Gold'],
    ),
    PubThemeDef(
      id: 'winecellar',
      name: 'Wine Cellar',
      woodDark: Color(0xFF2E1A2E),
      woodMid: Color(0xFF462844),
      woodDeep: Color(0xFF180E18),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF3E1E3E),
      playerColors: [Color(0xFFD4AC0D), Color(0xFF5DADE2)],
      playerColorNames: ['Sauternes', 'Mist'],
    ),
    PubThemeDef(
      id: 'copper',
      name: 'Copper Works',
      woodDark: Color(0xFF33231A),
      woodMid: Color(0xFF4E3626),
      woodDeep: Color(0xFF1E120C),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFF0B46A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF3F2B1F),
      playerColors: [Color(0xFFAF601A), Color(0xFF229954)],
      playerColorNames: ['Caramel', 'Leaf'],
    ),
    PubThemeDef(
      id: 'staghead',
      name: "Stag's Head",
      woodDark: Color(0xFF3F4226),
      woodMid: Color(0xFF5E6238),
      woodDeep: Color(0xFF242614),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      felt: Color(0xFF4A5228),
      playerColors: [Color(0xFF935116), Color(0xFF2E86C1)],
      playerColorNames: ['Umber', 'River'],
    ),
    PubThemeDef(
      id: 'rosenook',
      name: 'Rosewood Nook',
      woodDark: Color(0xFF3F1D24),
      woodMid: Color(0xFF5E2C36),
      woodDeep: Color(0xFF241016),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF4A2430),
      playerColors: [Color(0xFFC0392B), Color(0xFFD4AC0D)],
      playerColorNames: ['Poppy', 'Wheat'],
    ),
    PubThemeDef(
      id: 'porcelain',
      name: 'Porcelain Parlor',
      woodDark: Color(0xFFE8E0D0),
      woodMid: Color(0xFFF2EAD8),
      woodDeep: Color(0xFFCFC2A8),
      accent: Color(0xFF2E5A88),
      accentLight: Color(0xFF5E8AC0),
      accentDark: Color(0xFF1E3A5C),
      ivory: Color(0xFF2A2118),
      felt: Color(0xFFDCE8F0),
      playerColors: [Color(0xFF1D4E9E), Color(0xFF8E44AD)],
      playerColorNames: ['Cobalt', 'Plum'],
    ),
  ];

  static PubThemeDef byId(String id, {PubThemeDef? custom}) {
    if (id == 'custom') {
      return custom ?? all.first;
    }
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}

/// Physical dart styles: barrel metal + flight color. 0-3 = FREE, 4+ = PRO.
class DartStyleDef {
  final String name;
  final Color barrel;
  final Color stem;
  final Color flight;

  const DartStyleDef({
    required this.name,
    required this.barrel,
    required this.stem,
    required this.flight,
  });
}

class DartStyles {
  static const List<DartStyleDef> all = [
    DartStyleDef(
        name: 'Brass Classic',
        barrel: Color(0xFFC9A227),
        stem: Color(0xFF2A2A2A),
        flight: Color(0xFFA31621)),
    DartStyleDef(
        name: 'Steel Tip',
        barrel: Color(0xFFC0C6D4),
        stem: Color(0xFF2A2A2A),
        flight: Color(0xFF1D4E9E)),
    DartStyleDef(
        name: 'Tungsten Pro',
        barrel: Color(0xFF4A4A52),
        stem: Color(0xFF1A1A1E),
        flight: Color(0xFFF5EFE0)),
    DartStyleDef(
        name: 'Copper Ringed',
        barrel: Color(0xFFB87333),
        stem: Color(0xFF3B2416),
        flight: Color(0xFF1B7A4D)),
    DartStyleDef(
        name: 'Walnut Stems',
        barrel: Color(0xFF8A6A42),
        stem: Color(0xFF5C3A21),
        flight: Color(0xFFD99A2B)),
    DartStyleDef(
        name: 'Ivory Flights',
        barrel: Color(0xFFF5EFE0),
        stem: Color(0xFF2A2A2A),
        flight: Color(0xFF8E44AD)),
    DartStyleDef(
        name: 'Emerald Machined',
        barrel: Color(0xFF1B7A4D),
        stem: Color(0xFF0F3D2E),
        flight: Color(0xFFE8CE7A)),
    DartStyleDef(
        name: 'Obsidian Elite',
        barrel: Color(0xFF1A1A1E),
        stem: Color(0xFF1A1A1E),
        flight: Color(0xFFE74C3C)),
    DartStyleDef(
        name: "Sailor's Stripe",
        barrel: Color(0xFF2471A3),
        stem: Color(0xFF16233F),
        flight: Color(0xFFF5EFE0)),
    DartStyleDef(
        name: 'Hearth Ember',
        barrel: Color(0xFF7A2A1A),
        stem: Color(0xFF3B2416),
        flight: Color(0xFFE67E22)),
  ];

  static const freeCount = 4;
  static bool isPro(int index) => index >= freeCount;
}

/// Board accents: the physical look of the sisal board itself.
/// 0-1 = FREE, 2+ = PRO.
class BoardStyleDef {
  final String name;
  final Color ringA; // treble/double ring color A (classic red)
  final Color ringB; // treble/double ring color B (classic green)
  final Color sectorDark; // black sectors
  final Color sectorLight; // cream sectors
  final Color wire; // spider wires
  final Color surround; // number ring / outer surround
  final Color numberColor;

  const BoardStyleDef({
    required this.name,
    required this.ringA,
    required this.ringB,
    required this.sectorDark,
    required this.sectorLight,
    required this.wire,
    required this.surround,
    required this.numberColor,
  });
}

class BoardStyles {
  static const List<BoardStyleDef> all = [
    BoardStyleDef(
      name: 'Pub Standard',
      ringA: Color(0xFFC0392B),
      ringB: Color(0xFF1E8449),
      sectorDark: Color(0xFF1B1B1B),
      sectorLight: Color(0xFFF5EFE0),
      wire: Color(0xFFB9B2A4),
      surround: Color(0xFF101010),
      numberColor: Color(0xFFF5EFE0),
    ),
    BoardStyleDef(
      name: 'County Cream',
      ringA: Color(0xFF2471A3),
      ringB: Color(0xFFC0392B),
      sectorDark: Color(0xFF2A241E),
      sectorLight: Color(0xFFF2EAD8),
      wire: Color(0xFFB9B2A4),
      surround: Color(0xFF241A10),
      numberColor: Color(0xFFE8CE7A),
    ),
    BoardStyleDef(
      name: 'Tournament',
      ringA: Color(0xFF1D4E9E),
      ringB: Color(0xFFD99A2B),
      sectorDark: Color(0xFF1A1A1E),
      sectorLight: Color(0xFFF5F0E0),
      wire: Color(0xFFD0CCC0),
      surround: Color(0xFF0C0C0E),
      numberColor: Color(0xFFF5EFE0),
    ),
    BoardStyleDef(
      name: 'Vintage',
      ringA: Color(0xFF8E3B2A),
      ringB: Color(0xFF3F5E3A),
      sectorDark: Color(0xFF2B2118),
      sectorLight: Color(0xFFE4D3A8),
      wire: Color(0xFF9A8A70),
      surround: Color(0xFF241A12),
      numberColor: Color(0xFFE8CE7A),
    ),
    BoardStyleDef(
      name: 'Emerald Isle',
      ringA: Color(0xFF1B7A4D),
      ringB: Color(0xFFD4AC0D),
      sectorDark: Color(0xFF1B1B1B),
      sectorLight: Color(0xFFF0EDE2),
      wire: Color(0xFFB9B2A4),
      surround: Color(0xFF0F3D2E),
      numberColor: Color(0xFFF5EFE0),
    ),
    BoardStyleDef(
      name: 'Scarlet Oak',
      ringA: Color(0xFF922B21),
      ringB: Color(0xFF1E8449),
      sectorDark: Color(0xFF241109),
      sectorLight: Color(0xFFF2E4CE),
      wire: Color(0xFFB9B2A4),
      surround: Color(0xFF4A1F14),
      numberColor: Color(0xFFF5EFE0),
    ),
    BoardStyleDef(
      name: 'Royal Navy',
      ringA: Color(0xFF1A5276),
      ringB: Color(0xFFC0392B),
      sectorDark: Color(0xFF16233F),
      sectorLight: Color(0xFFE9E4D2),
      wire: Color(0xFFC0C6D4),
      surround: Color(0xFF0C1526),
      numberColor: Color(0xFFF5EFE0),
    ),
    BoardStyleDef(
      name: 'Forest Green',
      ringA: Color(0xFF229954),
      ringB: Color(0xFF922B21),
      sectorDark: Color(0xFF1A2312),
      sectorLight: Color(0xFFEDE2C6),
      wire: Color(0xFFB9B2A4),
      surround: Color(0xFF2E3B22),
      numberColor: Color(0xFFF5EFE0),
    ),
  ];

  static const freeCount = 2;
  static bool isPro(int index) => index >= freeCount;
}
