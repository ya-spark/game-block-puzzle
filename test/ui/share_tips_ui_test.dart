import 'dart:math';

import 'package:block_puzzle/app.dart';
import 'package:block_puzzle/core/services.dart';
import 'package:block_puzzle/core/share/share_service.dart';
import 'package:block_puzzle/game/flame/block_puzzle_game.dart';
import 'package:block_puzzle/game/rules/board.dart';
import 'package:block_puzzle/game/rules/game_state.dart';
import 'package:block_puzzle/game/rules/piece.dart';
import 'package:block_puzzle/game/rules/piece_generator.dart';
import 'package:block_puzzle/game/themes/block_theme.dart';
import 'package:block_puzzle/ui/game_screen.dart';
import 'package:block_puzzle/ui/share_card.dart';
import 'package:block_puzzle/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import '../helpers/puzzle_bot.dart';

Future<void> pumpApp(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Checkerboard: every empty cell is isolated, so after the dot nothing fits.
GameState deadEndState() => GameState(
  generator: PieceGenerator(Random(1)),
  board: Board.fromRows(
    List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.'),
  ),
  tray: [
    PieceCatalog.dot,
    PieceCatalog.byId('bar2_0'),
    PieceCatalog.byId('square2_0'),
  ],
);

Future<BlockPuzzleGame> pumpGame(
  WidgetTester tester,
  Services s,
  GameState state,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final game = BlockPuzzleGame(initialState: state);
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(home: GameScreen(game: game)),
    ),
  );
  await PuzzleBot(tester).waitForGame();
  return game;
}

void main() {
  testWidgets('share card renders to a non-empty PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: ShareCard(
            data: ShareCardData(
              gameName: 'Block Puzzle',
              headline: 'Score',
              big: '42',
              best: 99,
              theme: BlockTheme.cakes,
            ),
          ),
        ),
      ),
    );
    final bytes = await tester.runAsync(
      () => boundaryToPng(
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary,
      ),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('settings.shareApp is hidden while the link flag is off', (
    tester,
  ) async {
    final s = await buildFakeServices();
    expect(s.config.share.appLinkEnabled, isFalse);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await settle(tester);
    expect(
      find.byKey(TestIds.settingsShareApp, skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(TestIds.settingsTips, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('game over share button shares the score text', (tester) async {
    final share = FakeShareService();
    final s = await buildFakeServices(share: share);
    await s.profile.setSound(false);
    await pumpGame(tester, s, deadEndState());
    expect(await PuzzleBot(tester).drag(0, 0, 0), isTrue);
    await settle(tester);
    expect(find.byKey(TestIds.gameOverShare), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameOverShare));
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && share.sent.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(share.sent, hasLength(1));
    expect(share.sent.single.text, startsWith('I scored '));
  });

  testWidgets('home tip shows once per day and closing keeps it hidden', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
    await s.profile.onAppOpened();
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsNothing);
    now = DateTime.utc(2026, 11, 6, 10);
    await s.profile.onAppOpened();
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
  });

  testWidgets('ticking the checkbox turns tips off; the settings switch '
      'brings them back', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipDontShow));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(s.profile.tipsEnabled, isFalse);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.hintDue('gem'), isFalse);
    expect(s.profile.homeTipPending, isFalse);

    await tester.tap(find.byKey(TestIds.homeSettings));
    await settle(tester);
    final sw = find.byKey(TestIds.settingsTips);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(s.profile.tipsEnabled, isTrue);
    expect(s.profile.hintDue('gem'), isTrue);
  });

  testWidgets('game over tip shows on every 2nd game over', (tester) async {
    final s = await buildFakeServices(tips: true);
    await s.profile.setSound(false);
    // Hints must not cover anything here.
    for (final id in ['gem', 'boom', 'gold', 'rush']) {
      await s.profile.markHintSeen(id);
    }
    final game = await pumpGame(tester, s, deadEndState());
    final bot = PuzzleBot(tester);
    expect(await bot.drag(0, 0, 0), isTrue);
    await settle(tester);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.tipGameOver), findsNothing);

    await tester.tap(find.byKey(TestIds.gameOverRetry));
    await settle(tester);
    game.state = deadEndState();
    expect(await bot.drag(0, 0, 0), isTrue);
    await settle(tester);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.tipGameOver), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(find.byKey(TestIds.tipGameOver), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);

    await tester.tap(find.byKey(TestIds.gameOverRetry));
    await settle(tester);
    game.state = deadEndState();
    expect(await bot.drag(0, 0, 0), isTrue);
    await settle(tester);
    expect(find.byKey(TestIds.tipGameOver), findsNothing);
  });

  testWidgets('one-time hint shows once, for 4 s', (tester) async {
    final s = await buildFakeServices(tips: true);
    await s.profile.setSound(false);
    final state = GameState(
      generator: PieceGenerator(Random(1)),
      board: Board.empty(),
      tray: [
        PieceCatalog.dot.withKind(0, CellKind.gem),
        PieceCatalog.byId('bar2_0'),
        PieceCatalog.byId('square2_0'),
      ],
    );
    await pumpGame(tester, s, state);
    final bot = PuzzleBot(tester);
    expect(find.byKey(TestIds.tipHint), findsNothing);
    expect(await bot.drag(1, 0, 0), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(TestIds.tipHint), findsOneWidget);
    expect(s.profile.hintDue('gem'), isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byKey(TestIds.tipHint), findsNothing);
    // Never again.
    expect(await bot.drag(2, 3, 3), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(TestIds.tipHint), findsNothing);
  });
}
