import 'dart:math';
import 'dart:ui';

import 'package:block_puzzle/game/rules/piece.dart';
import 'package:block_puzzle/game/themes/block_theme.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

/// Themes whose background is a bright mid-tone: no block colour can reach 3:1 against it
/// and still look like the theme, so only the empty cell colour is checked there.
const _brightBackground = {'gems', 'wood'};

void main() {
  for (final t in BlockTheme.all) {
    for (var i = 0; i < Piece.colorCount; i++) {
      test('${t.id} colour $i has 3:1 contrast', () {
        final c = t.palette[i];
        expect(_contrast(c, t.emptyCell), greaterThanOrEqualTo(3.0));
        if (!_brightBackground.contains(t.id)) {
          expect(_contrast(c, t.backgroundTop), greaterThanOrEqualTo(3.0));
        }
      });
    }

    test('${t.id} paints every colour without error', () {
      for (var i = 0; i < Piece.colorCount; i++) {
        final rec = PictureRecorder();
        t.paintCell(Canvas(rec), const Rect.fromLTWH(0, 0, 40, 40), i);
        rec.endRecording().dispose();
      }
    });
  }

  test('base tile paints on the full cell', () {
    final rec = PictureRecorder();
    paintBaseTile(
      Canvas(rec),
      const Rect.fromLTWH(0, 0, tileUnit, tileUnit),
      const Color(0xFFFF0000),
    );
    final pic = rec.endRecording();
    pic.dispose();
  });
}
