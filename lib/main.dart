import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const DartsApp());

class DartsApp extends StatelessWidget {
  const DartsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.aquaDepth,
      title: 'Darts',
      tagline: '501 down, doubles to finish. Become the bullseye boss!',
      emoji: '🎯',
      slug: 'darts',
      howToPlay:
          '• Tap the dartboard to throw. You get 3 darts per turn.\n• Count down from 501 — hit exactly 0 to win.\n• You MUST finish on a double (or the bull)! 🔴\n• Go below 0, land on 1, or miss the double? BUST — turn wasted!\n• Watch for checkout hints when you get close. 🧠',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => DartsScreen(players: players, callbacks: cb),
    );
  }
}
