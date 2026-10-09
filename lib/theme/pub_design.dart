import 'package:flutter/material.dart';
import 'pub_themes.dart';

/// Pub Darts — the design system for Darts.
/// Warm pub-darts-night: dark woods, brass/copper, warm lamplight, felt.
/// No neon, no cyberpunk, no generic Material look.
///
/// All widgets accept an optional [PubThemeDef]; they default to the
/// Bull's Inn theme so existing call sites keep working.
class Pub {
  static const displayFont = 'serif';

  static TextStyle display(double size, {Color? color, PubThemeDef? theme}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE8CE7A),
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Color(0xFF1A0F08), offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, PubThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.ivory ?? const Color(0xFFF5EFE0),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, PubThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE8CE7A),
        letterSpacing: 0.8,
      );

  static ThemeData theme([PubThemeDef? t]) {
    t ??= PubThemes.byId('bullsinn');
    final lightTheme = t.id == 'porcelain';
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.woodDark,
      colorScheme: ColorScheme(
        brightness: lightTheme ? Brightness.light : Brightness.dark,
        primary: t.accent,
        onPrimary: t.woodDeep,
        secondary: t.accentLight,
        onSecondary: t.woodDeep,
        surface: t.woodMid,
        onSurface: t.ivory,
        error: t.playerColors[0],
        onError: t.ivory,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.woodMid),
    );
  }
}

/// Wood-paneled wall with a warm lamplight glow, theme-aware.
class PubBackdrop extends StatelessWidget {
  final Widget child;
  final PubThemeDef? theme;
  const PubBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PubThemes.byId('bullsinn');
    return Container(
      decoration: BoxDecoration(color: t.woodDark),
      child: CustomPaint(
        painter: _WoodPanelPainter(t),
        child: child,
      ),
    );
  }
}

class _WoodPanelPainter extends CustomPainter {
  final PubThemeDef t;
  _WoodPanelPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final glow = RadialGradient(
      center: const Alignment(0, -0.35),
      radius: 1.2,
      colors: [
        t.woodMid.withValues(alpha: 0.55),
        t.woodDark.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.5),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = glow.createShader(Offset.zero & size),
    );
    // Vertical wood panels.
    final panel = Paint()..color = t.woodDeep.withValues(alpha: 0.18);
    final count = (size.width / 90).ceil().clamp(4, 12);
    for (int i = 0; i <= count; i++) {
      final x = size.width * i / count;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        panel..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky wooden button with brass trim — looks physically pressable.
class PubButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final PubThemeDef? theme;

  const PubButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 19,
    this.theme,
  });

  @override
  State<PubButton> createState() => _PubButtonState();
}

class _PubButtonState extends State<PubButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? PubThemes.byId('bullsinn');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [t.woodMid, t.woodDark, t.woodDeep]
                : [
                    t.woodDeep.withValues(alpha: 0.7),
                    t.woodDeep.withValues(alpha: 0.5)
                  ],
          ),
          border: Border.all(color: t.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: t.accentLight.withValues(alpha: _pressed ? 0.05 : 0.22),
              offset: const Offset(0, -2),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Pub.display(widget.fontSize,
              theme: t,
              color: enabled
                  ? t.ivory
                  : t.ivory.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

/// An engraved brass plaque for titles.
class PubPlaque extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PubThemeDef? theme;
  const PubPlaque(
      {super.key, required this.title, this.subtitle, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PubThemes.byId('bullsinn');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.woodDeep, t.woodDark],
        ),
        border: Border.all(color: t.accent, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 6),
              blurRadius: 12),
          BoxShadow(
              color: t.accentLight.withValues(alpha: 0.7),
              offset: const Offset(0, -1),
              blurRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Pub.display(30, theme: t), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Pub.body(14,
                    theme: t, color: t.ivory.withValues(alpha: 0.75)),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A brass lever toggle for settings.
class PubToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final PubThemeDef? theme;
  const PubToggle(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PubThemes.byId('bullsinn');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? t.accentDark : t.woodDeep,
          border: Border.all(color: t.accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accentLight, t.accent, t.accentDark],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A wooden-bead volume slider on a brass rail.
class PubBeadSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final PubThemeDef? theme;
  const PubBeadSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PubThemes.byId('bullsinn');
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.woodDeep,
        thumbShape: _BeadThumb(t),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  final PubThemeDef t;
  const _BeadThumb(this.t);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(
        center + const Offset(0, 2),
        12,
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [t.accentLight, t.accent, t.accentDark],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

/// Small helper: a labeled settings row.
class SettingRow extends StatelessWidget {
  final String label;
  final Widget control;
  final PubThemeDef? theme;
  const SettingRow(
      {super.key, required this.label, required this.control, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PubThemes.byId('bullsinn');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: t.woodDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Pub.body(16, theme: t))),
          control,
        ],
      ),
    );
  }
}
