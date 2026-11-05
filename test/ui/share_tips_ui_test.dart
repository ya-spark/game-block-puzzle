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
  await tester.pump(const Duration(milliseconds: 400)); // tip dialog route
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

  testWidgets('settings.shareApp is hidden without a share link', (
    tester,
  ) async {
    final s = await buildFakeServices(); // fake share has no link
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

  testWidgets('settings.shareApp shares the link when there is one', (
    tester,
  ) async {
    final share = FakeShareService(link: 'https://example.com/test');
    final s = await buildFakeServices(share: share);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await settle(tester);
    final item = find.byKey(TestIds.settingsShareApp, skipOffstage: false);
    await tester.scrollUntilVisible(item, 100);
    await tester.tap(item);
    await tester.pump();
    expect(share.sent.single.text, endsWith('\nhttps://example.com/test'));
  });

  testWidgets('game over share button shares the score text', (tester) async {
    final share = FakeShareService(link: 'https://example.com/test');
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
    expect(
      share.sent.single.text,
      startsWith('This is my high score in Block Puzzle: '),
    );
    expect(share.sent.single.text, endsWith('\nhttps://example.com/test'));
  });

  testWidgets('game over panel: layout order, view board and no tips', (
    tester,
  ) async {
    final s = await buildFakeServices(tips: true);
    await s.profile.closeHomeTip(); // today's home tip already shown
    await s.profile.setSound(false);
    await pumpGame(tester, s, deadEndState());
    expect(await PuzzleBot(tester).drag(0, 0, 0), isTrue);
    await settle(tester);
    expect(find.byKey(TestIds.gameOverPanel), findsOneWidget);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(find.byKey(TestIds.tipClose), findsNothing);

    // Share top left, Play again and Home side by side, Continue last.
    final panel = tester.getRect(find.byKey(TestIds.gameOverPanel));
    final share = tester.getRect(find.byKey(TestIds.gameOverShare));
    final again = tester.getRect(find.byKey(TestIds.gameOverRetry));
    final home = tester.getRect(find.byKey(TestIds.gameOverHome));
    final cont = tester.getRect(find.byKey(TestIds.gameOverRevive));
    expect(share.left - panel.left, lessThan(30));
    expect(share.bottom, lessThanOrEqualTo(again.top));
    expect((again.center.dy - home.center.dy).abs(), lessThan(2));
    expect(again.right, lessThan(home.left));
    expect(cont.top, greaterThanOrEqualTo(again.bottom));

    // Eye button hides the panel; a tap anywhere brings it back.
    await tester.tap(find.byKey(TestIds.gameOverView));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(TestIds.gameOverPanel),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      0,
    );
    expect(find.byKey(TestIds.gameOverView), findsOneWidget);
    await tester.tapAt(const Offset(200, 600));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(TestIds.gameOverPanel),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      1,
    );
  });

  testWidgets('home tip dialog shows once per day', (tester) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await settle(tester);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
    // Not again the same day.
    await s.profile.onAppOpened();
    await settle(tester);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    // Next day: back on a new home page / resume.
    now = DateTime.utc(2026, 11, 6, 10);
    await s.profile.onAppOpened();
    expect(s.profile.homeTipPending, isTrue);
    await tester.pumpWidget(const SizedBox()); // a fresh home page
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
  });

  testWidgets('home tip dialog never shows when tips are off', (tester) async {
    final s = await buildFakeServices(); // tips off
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsNothing);
  });

  testWidgets('ticking the checkbox turns tips off; the settings switch '
      'brings them back', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipDontShow));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.tipClose));
    await settle(tester);
    expect(s.profile.tipsEnabled, isFalse);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.homeTipPending, isFalse);

    await tester.tap(find.byKey(TestIds.homeSettings));
    await settle(tester);
    final sw = find.byKey(TestIds.settingsTips);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(s.profile.tipsEnabled, isTrue);
  });
}
