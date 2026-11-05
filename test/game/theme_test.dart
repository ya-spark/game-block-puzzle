import 'dart:math';
import 'dart:ui';

import 'package:block_puzzle/core/save/save_data.dart';
import 'package:block_puzzle/game/flame/block_puzzle_game.dart';
import 'package:block_puzzle/game/rules/board.dart';
import 'package:block_puzzle/game/rules/game_state.dart';
import 'package:block_puzzle/game/rules/piece.dart';
import 'package:block_puzzle/game/rules/piece_generator.dart';
import 'package:block_puzzle/game/rules/theme_rotation.dart';
import 'package:block_puzzle/game/themes/block_theme.dart';
import 'package:block_puzzle/ui/game_screen.dart';
import 'package:block_puzzle/ui/test_ids.dart';
import 'package:block_puzzle/core/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import '../helpers/puzzle_bot.dart';

void main() {
  group('theme rotation', () {
    test('changes at 10, 20, 30 lines and wraps after the last', () {
      String at(int lines) => ThemeRotation.idFor(0, lines);
      expect(at(0), 'gems');
      expect(at(9), 'gems');
      expect(at(10), 'cakes');
      expect(at(19), 'cakes');
      expect(at(20), 'wood');
      expect(at(30), 'candy');
      expect(at(40), 'ocean');
      expect(at(50), 'space');
      expect(at(60), 'gems');
      expect(at(70), 'cakes');
    });

    test('a game continues from the saved index', () {
      expect(ThemeRotation.idFor(5, 0), 'space');
      expect(ThemeRotation.idFor(5, 10), 'gems');
      expect(ThemeRotation.idFor(2, 25), 'ocean');
    });

    test('themes are in table order and match the painters', () {
      expect([for (final t in BlockTheme.all) t.id], ThemeRotation.ids);
      expect(ThemeRotation.themeEveryLines, 10);
    });

    test('rotation index is saved in the profile data', () {
      final d = const SaveData().copyWith(themeIndex: 3);
      expect(SaveData.fromJson(d.toJson()).themeIndex, 3);
      expect(SaveData.fromJson(const {}).themeIndex, 0);
    });

    test('a new game continues the rotation', () {
      final game = BlockPuzzleGame(
        themeStart: 1,
        generator: PieceGenerator(Random(1)),
      );
      expect(game.theme.id, 'cakes');
      game.state.linesClearedTotal = 20;
      expect(game.theme.id, 'candy');
      game.view = PuzzleView();
      game.restart();
      expect(game.themeStart, 3);
      expect(game.theme.id, 'candy');
    });
  });

  group('colours', () {
    test('dealt pieces get seeded colours from all 8 indexes', () {
      final a = PieceGenerator(Random(5));
      final b = PieceGenerator(Random(5));
      final seen = <int>{};
      for (var i = 0; i < 60; i++) {
        final ta = a.dealTray(Board.empty());
        final tb = b.dealTray(Board.empty());
        expect(
          [for (final p in ta) p.colorIndex],
          [for (final p in tb) p.colorIndex],
        );
        seen.addAll(ta.map((p) => p.colorIndex));
      }
      expect(seen, {0, 1, 2, 3, 4, 5, 6, 7});
    });

    test('every theme has 8 distinct colours', () {
      for (final t in BlockTheme.all) {
        expect(t.palette.toSet().length, Piece.colorCount, reason: t.id);
      }
    });
  });

  group('skins', () {
    for (final t in BlockTheme.all) {
      test('${t.id} paints all 8 colour indexes and its background', () {
        final cache = ThemeTileCache();
        final rec = PictureRecorder();
        final canvas = Canvas(rec);
        for (var i = 0; i < Piece.colorCount; i++) {
          t.paintCell(canvas, Rect.fromLTWH(i * 40.0, 0, 40, 40), i);
          cache.draw(canvas, t, i, Rect.fromLTWH(i * 40.0, 50, 40, 40));
        }
        t.paintBackground(canvas, const Size(300, 600));
        rec.endRecording().dispose();
        cache.dispose();
      });
    }
  });

  testWidgets('game.theme changes after the 10th cleared line', (tester) async {
    final s = await buildFakeServices();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Row 0 is full but one cell; the dot completes it.
    final rows = ['#######.', ...List.filled(7, '........')];
    final state = GameState(
      generator: PieceGenerator(Random(1)),
      board: Board.fromRows(rows),
      tray: [
        PieceCatalog.dot,
        PieceCatalog.byId('square2_0'),
        PieceCatalog.byId('bar2_0'),
      ],
    )..linesClearedTotal = 9;
    final game = BlockPuzzleGame(initialState: state);
    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: MaterialApp(home: GameScreen(game: game)),
      ),
    );
    final bot = PuzzleBot(tester);
    await bot.waitForGame();

    String themeId() => tester
        .widget<Semantics>(find.byKey(TestIds.gameTheme))
        .properties
        .value!;
    expect(themeId(), 'gems');
    expect(await bot.drag(0, 0, 7), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.linesClearedTotal, 10);
    expect(themeId(), 'cakes');
    expect(s.profile.data.themeIndex, 1);
    // The cross-fade runs and finishes without blocking anything.
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
