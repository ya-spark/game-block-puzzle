import 'dart:math';

import 'package:block_puzzle/app.dart';
import 'package:block_puzzle/core/ads/ad_service.dart';
import 'package:block_puzzle/core/purchase/purchase_service.dart';
import 'package:block_puzzle/core/services.dart';
import 'package:block_puzzle/game/flame/block_puzzle_game.dart';
import 'package:block_puzzle/game/rules/board.dart';
import 'package:block_puzzle/game/rules/game_state.dart';
import 'package:block_puzzle/game/rules/piece.dart';
import 'package:block_puzzle/game/rules/piece_generator.dart';
import 'package:block_puzzle/ui/game_screen.dart';
import 'package:block_puzzle/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import '../helpers/puzzle_bot.dart';

Board _board() => Board.fromRows([
  '########',
  '########',
  '########',
  '###.....',
  '........',
  '........',
  '........',
  '.......#',
]);

Future<(BlockPuzzleGame, PuzzleBot)> _pump(
  WidgetTester tester,
  Services s, {
  Size size = const Size(360, 640),
  int placed = 3,
  List<Piece>? tray,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = GameState(
    generator: PieceGenerator(Random(2), 0),
    board: _board(),
    tray: tray ?? [PieceCatalog.dot, PieceCatalog.dot, PieceCatalog.dot],
  )..piecesPlaced = placed;
  final game = BlockPuzzleGame(initialState: state);
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(home: GameScreen(game: game)),
    ),
  );
  final bot = PuzzleBot(tester);
  await bot.waitForGame();
  await tester.pump();
  return (game, bot);
}

/// The Flame game ticks forever, so pumpAndSettle never settles: pump a few frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Offset _cellOnScreen(WidgetTester tester, BlockPuzzleGame g, int r, int c) {
  final origin = tester.getTopLeft(find.byKey(TestIds.gameWidget));
  final (x, y) = g.layout.cellCenter(r, c);
  return origin + Offset(x, y);
}

void main() {
  testWidgets('button row fits at 360 x 640: no overflow, clear of the board', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final (game, _) = await _pump(tester, s);
    expect(tester.takeException(), isNull);
    final origin = tester.getTopLeft(find.byKey(TestIds.gameWidget));
    final boardTop = origin.dy + game.layout.boardTop - 4;
    final view = Offset.zero & const Size(360, 640);
    for (final id in ['blast', 'shuffle', 'undo', 'sweep', 'hammer']) {
      final r = tester.getRect(find.byKey(TestIds.gameItem(id)));
      expect(r.size, const Size(48, 48));
      expect(view.contains(r.topLeft) && view.contains(r.bottomRight), isTrue);
      expect(r.bottom, lessThanOrEqualTo(boardTop + 0.5), reason: id);
      expect(find.byKey(TestIds.gameItemCount(id)), findsOneWidget);
    }
  });

  testWidgets('row is visible from the start of the very first game', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await _pump(tester, s, placed: 0);
    expect(find.byKey(TestIds.gameItemRow), findsOneWidget);
  });

  testWidgets('arming and cancelling Blast and Hammer spends nothing', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final (game, _) = await _pump(tester, s);
    for (final id in ['blast', 'hammer']) {
      await tester.tap(find.byKey(TestIds.gameItem(id)));
      await tester.pump();
      expect(find.byKey(TestIds.gameItemChip), findsOneWidget);
      expect(game.targeting?.name, id);
      // Cancel button.
      await tester.tap(find.byKey(TestIds.gameItemCancel));
      await tester.pump();
      expect(game.targeting, isNull);
      expect(find.byKey(TestIds.gameItemChip), findsNothing);
      // Tapping the button again cancels too.
      await tester.tap(find.byKey(TestIds.gameItem(id)));
      await tester.pump();
      await tester.tap(find.byKey(TestIds.gameItem(id)));
      await tester.pump();
      expect(game.targeting, isNull);
      expect(s.profile.itemCount(id), 1);
    }
    expect(game.state.board.filledCount, _board().filledCount);
  });

  testWidgets('Blast empties the 3x3 once applied and spends one', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final (game, _) = await _pump(tester, s);
    await tester.tap(find.byKey(TestIds.gameItem('blast')));
    await tester.pump();
    // Drags are blocked while targeting: a drag from the tray does nothing.
    final before = game.state.piecesPlaced;
    final (tx, ty) = game.layout.trayCenter(0);
    final origin = tester.getTopLeft(find.byKey(TestIds.gameWidget));
    await tester.dragFrom(origin + Offset(tx, ty), const Offset(0, -200));
    await tester.pump();
    expect(game.state.piecesPlaced, before);

    await tester.tapAt(_cellOnScreen(tester, game, 1, 1));
    await tester.pump();
    expect(game.state.board.filledCount, _board().filledCount - 9);
    expect(s.profile.itemCount('blast'), 0);
    expect(game.targeting, isNull);
    expect(game.state.score, 0);
  });

  testWidgets('Hammer on an empty cell keeps targeting and spends nothing', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final (game, _) = await _pump(tester, s);
    await tester.tap(find.byKey(TestIds.gameItem('hammer')));
    await tester.pump();
    await tester.tapAt(_cellOnScreen(tester, game, 5, 5));
    await tester.pump();
    expect(s.profile.itemCount('hammer'), 1);
    expect(game.targeting?.name, 'hammer');
  });

  testWidgets('Shuffle and Undo apply at once', (tester) async {
    final s = await buildFakeServices();
    final (game, bot) = await _pump(tester, s);
    // Undo is greyed with nothing to take back.
    await tester.tap(find.byKey(TestIds.gameItem('undo')));
    await tester.pump();
    expect(s.profile.itemCount('undo'), 1);
    await bot.drag(0, 4, 4);
    expect(game.state.piecesPlaced, 4);
    await tester.tap(find.byKey(TestIds.gameItem('undo')));
    await tester.pump();
    expect(game.state.piecesPlaced, 3);
    expect(s.profile.itemCount('undo'), 0);
    await tester.tap(find.byKey(TestIds.gameItem('shuffle')));
    await tester.pump();
    expect(s.profile.itemCount('shuffle'), 0);
  });

  testWidgets('empty stock sheet: buy with coins, ad, get coins', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    final (game, _) = await _pump(tester, s);
    await s.profile.useItem('hammer');
    await tester.pump();

    // No coins: buy is disabled with "Not enough coins", Get coins is offered.
    await tester.tap(find.byKey(TestIds.gameItem('hammer')));
    await _settle(tester);
    expect(find.byKey(TestIds.gameItemSheet), findsOneWidget);
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(find.byKey(TestIds.gameItemRefillAd), findsOneWidget);
    expect(find.byKey(TestIds.gameItemRefillShop), findsOneWidget);
    final buy = tester.widget<FilledButton>(
      find.byKey(TestIds.gameItemRefillCoins),
    );
    expect(buy.onPressed, isNull);

    // Watch an ad: +1 and counted against the 3 per game.
    await tester.tap(find.byKey(TestIds.gameItemRefillAd));
    await _settle(tester);
    expect(ads.rewardedShown, 1);
    expect(s.profile.itemCount('hammer'), 1);
    expect(game.state.adRefillsLeft, 2);

    // With coins the sheet offers the price and no Get coins.
    await s.profile.useItem('hammer');
    await s.profile.addCoins(100);
    await tester.tap(find.byKey(TestIds.gameItem('hammer')));
    await _settle(tester);
    expect(find.byKey(TestIds.gameItemRefillShop), findsNothing);
    await tester.tap(find.byKey(TestIds.gameItemRefillCoins));
    await _settle(tester);
    expect(s.profile.data.coins, 75);
    expect(s.profile.itemCount('hammer'), 1);
    expect(ads.rewardedShown, 1);
  });

  testWidgets('Remove Ads: "Get +1 free", no ad call, same cap of 3', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await s.profile.deliverPurchase(
      const PurchaseUpdate('remove_ads_all', PurchaseStatus.purchased),
      s.catalog,
    );
    final (game, _) = await _pump(tester, s);
    await s.profile.useItem('hammer');
    await tester.pump();
    await tester.tap(find.byKey(TestIds.gameItem('hammer')));
    await _settle(tester);
    expect(find.text('Get +1 free (3 left)'), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameItemRefillAd));
    await _settle(tester);
    expect(ads.rewardedShown, 0);
    expect(s.profile.itemCount('hammer'), 1);
    expect(game.state.adRefillsLeft, 2);
  });

  testWidgets('shop: boosts after the coin packs; buy refuses when short', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await tester.pumpWidget(GameApp(services: s));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.homeShop));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(TestIds.shopItemBuy('hammer')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(s.profile.data.coins, 0);
    await tester.tap(find.byKey(TestIds.shopItemBuy('hammer')));
    await _settle(tester);
    expect(s.profile.itemCount('hammer'), 1);
    expect(find.text('Not enough coins.'), findsOneWidget);
    await s.profile.addCoins(25);
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byKey(TestIds.shopItemBuy('hammer')));
    await _settle(tester);
    expect(s.profile.data.coins, 0);
    expect(s.profile.itemCount('hammer'), 2);
    expect(find.text('You have 2'), findsOneWidget);
  });

  testWidgets('the 3x3 and 2x3 / 3x2 pieces render in the tray at 360 x 640', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final (game, _) = await _pump(
      tester,
      s,
      tray: [
        PieceCatalog.byId('square3_0'),
        PieceCatalog.byId('rect23_0'),
        PieceCatalog.byId('rect23_1'),
      ],
    );
    expect(tester.takeException(), isNull);
    final l = game.layout;
    for (var i = 0; i < 3; i++) {
      final p = game.state.tray[i]!;
      final (cx, cy) = l.trayCenter(i);
      final w = p.width * l.trayCellSize, h = p.height * l.trayCellSize;
      expect(w, lessThanOrEqualTo(l.slotWidth), reason: 'slot $i');
      expect(cy - h / 2, greaterThanOrEqualTo(l.trayTop));
      expect(cy + h / 2, lessThanOrEqualTo(l.trayTop + l.trayHeight));
      expect(cx - w / 2, greaterThanOrEqualTo(l.boardLeft));
    }
  });
}
