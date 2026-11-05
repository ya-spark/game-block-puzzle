import 'package:flutter/widgets.dart';

import '../game/themes/block_theme.dart';

/// Full-screen background of the current theme. When the theme changes the new one fades in
/// over the old one (1.5 s); it never blocks input.
class ThemeBackground extends StatefulWidget {
  const ThemeBackground({super.key, required this.theme, required this.child});

  final BlockTheme theme;
  final Widget child;

  @override
  State<ThemeBackground> createState() => _ThemeBackgroundState();
}

class _ThemeBackgroundState extends State<ThemeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: 1,
  );
  late BlockTheme _from = widget.theme;

  @override
  void didUpdateWidget(ThemeBackground old) {
    super.didUpdateWidget(old);
    if (old.theme.id != widget.theme.id) {
      _from = old.theme;
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      child: widget.child,
      builder: (context, child) => CustomPaint(
        painter: _BackgroundPainter(_from, widget.theme, _fade.value),
        child: child,
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.from, this.to, this.t);
  final BlockTheme from;
  final BlockTheme to;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t < 1) from.paintBackground(canvas, size);
    if (t >= 1) {
      to.paintBackground(canvas, size);
    } else {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(255, 255, 255, t),
      );
      to.paintBackground(canvas, size);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.from.id != from.id || old.to.id != to.id || old.t != t;
}
