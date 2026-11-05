import 'package:flutter/material.dart';

/// Game-over overlay: no card and no scrim, just outlined text and glossy pill buttons floating
/// at the top, so the play field underneath stays fully visible.
class GameOverPanel extends StatelessWidget {
  const GameOverPanel({
    super.key,
    required this.title,
    required this.details,
    required this.buttons,
  });

  final String title;

  /// Score, best, medal... shown under the title.
  final List<Widget> details;
  final List<GameOverButton> buttons;

  /// White text with a dark outline: readable over any background without a panel.
  static List<Shadow> get outline => const [
    Shadow(color: Color(0xE6000000), blurRadius: 0, offset: Offset(-1.5, -1.5)),
    Shadow(color: Color(0xE6000000), blurRadius: 0, offset: Offset(1.5, -1.5)),
    Shadow(color: Color(0xE6000000), blurRadius: 0, offset: Offset(-1.5, 1.5)),
    Shadow(color: Color(0xE6000000), blurRadius: 0, offset: Offset(1.5, 1.5)),
    Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF3A0), Color(0xFFFFB300)],
                  ).createShader(r),
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                      shadows: outline,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    shadows: outline,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: details,
                  ),
                ),
                const SizedBox(height: 10),
                // Large buttons each get their own row, the rest share a wrapped row below.
                for (final b in buttons.where(
                  (b) => b.size == GameOverButtonSize.large,
                ))
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: buttons
                      .where((b) => b.size != GameOverButtonSize.large)
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum GameOverButtonKind { primary, secondary, ghost }

/// [large] is the focus action (font 22, padding 28x16, own row); [compact] is the secondary
/// action (font 15, padding 18x9); [regular] is the default pill.
enum GameOverButtonSize { large, regular, compact }

/// Glossy pill button: gold for the main action, purple-pink for secondary, glass for ghost.
class GameOverButton extends StatelessWidget {
  const GameOverButton({
    super.key,
    this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    this.kind = GameOverButtonKind.secondary,
    this.size = GameOverButtonSize.regular,
  }) : assert(label != null || icon != null);

  /// Null for an icon-only button (then [semanticLabel] names it).
  final String? label;
  final String? semanticLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GameOverButtonKind kind;
  final GameOverButtonSize size;

  @override
  Widget build(BuildContext context) {
    final (colors, fg, border) = switch (kind) {
      GameOverButtonKind.primary => (
        const [Color(0xFFFFE259), Color(0xFFFF8F00)],
        const Color(0xFF3B1F00),
        const Color(0xFFFFF3A0),
      ),
      GameOverButtonKind.secondary => (
        const [Color(0xFF8E54E9), Color(0xFFE94E9B)],
        Colors.white,
        const Color(0xFFFFD6F2),
      ),
      GameOverButtonKind.ghost => (
        const [Color(0x40FFFFFF), Color(0x26FFFFFF)],
        Colors.white,
        const Color(0xCCFFFFFF),
      ),
    };
    final (fontSize, padding) = switch (size) {
      GameOverButtonSize.large => (
        22.0,
        const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      ),
      GameOverButtonSize.regular => (
        16.0,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      ),
      GameOverButtonSize.compact => (
        15.0,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      ),
    };
    final enabled = onPressed != null;
    return Semantics(
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onPressed,
              child: Padding(
                padding: padding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: fontSize + 4, color: fg),
                      if (label != null) const SizedBox(width: 6),
                    ],
                    // Scales down only if the label cannot fit the screen width.
                    if (label != null)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label!,
                            style: TextStyle(
                              color: fg,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              shadows: kind == GameOverButtonKind.ghost
                                  ? GameOverPanel.outline
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
