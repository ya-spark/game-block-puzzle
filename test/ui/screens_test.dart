import 'dart:math';

import 'package:flutter/material.dart';
import 'package:block_puzzle/app.dart';
import 'package:block_puzzle/core/ads/ad_service.dart';
import 'package:block_puzzle/core/purchase/parent_gate_guard.dart';
import 'package:block_puzzle/core/purchase/purchase_service.dart';
import 'package:block_puzzle/core/retention/daily_reward.dart';
import 'package:block_puzzle/core/services.dart';
import 'package:block_puzzle/game/flame/block_puzzle_game.dart';
import 'package:block_puzzle/game/rules/board.dart';
import 'package:block_puzzle/game/rules/game_state.dart';
import 'package:block_puzzle/game/rules/piece.dart';
import 'package:block_puzzle/game/rules/piece_generator.dart';
import 'package:block_puzzle/ui/game_screen.dart';
import 'package:block_puzzle/ui/home_hero.dart';
import 'package:block_puzzle/ui/test_ids.dart';
import 'package:block_puzzle/ui/theme_background.dart';
import 'package:block_puzzle/ui/widgets.dart';
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

/// pumpAndSettle never returns while the Flame game loop is running.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Types the correct answer into the open parent gate and submits.
Future<void> answerGate(WidgetTester tester, Services s) async {
  await tester.enterText(
    find.byKey(TestIds.gateAnswer),
    '${s.parentGate.a * s.parentGate.b}',
  );
  await tester.tap(find.byKey(TestIds.gateSubmit));
  await tester.pumpAndSettle();
}

/// Opens a game on a board where the first placement ends the game; the game over panel is up.
Future<BlockPuzzleGame> pumpGameOver(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rows = List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.');
  final game = BlockPuzzleGame(
    initialState: GameState(
      generator: PieceGenerator(Random(1)),
      board: Board.fromRows(rows),
      tray: [
        PieceCatalog.dot,
        PieceCatalog.byId('bar2_0'),
        PieceCatalog.byId('square2_0'),
      ],
    ),
  );
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(home: GameScreen(game: game)),
    ),
  );
  final bot = PuzzleBot(tester);
  await bot.waitForGame();
  await bot.drag(0, 0, 0);
  await settle(tester);
  return game;
}

void main() {
  testWidgets('coin icon replaces the old icon on home and in the shop', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    expect(find.byType(CoinIcon), findsOneWidget);
    expect(find.byIcon(Icons.monetization_on), findsNothing);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    expect(find.byType(CoinIcon), findsNWidgets(3));
    expect(find.byIcon(Icons.monetization_on), findsNothing);
  });

  testWidgets('shop lists all four products in order', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    final ids = ['remove_ads_all', 'coins_500', 'coins_1500', 'coins_4000'];
    final ys = [
      for (final id in ids)
        tester.getTopLeft(find.byKey(TestIds.shopBuy(id))).dy,
    ];
    expect(ys, [...ys]..sort());
    expect(find.textContaining('continue after a game over'), findsNWidgets(3));
  });

  testWidgets('parent gate: cancel buys nothing; wrong answers lock for 60 s', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1, 12);
    final s = await buildFakeServices(
      parentGate: ParentGateGuard(clock: () => now, random: Random(3)),
    );
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.gateDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gateCancel));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 0);

    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(TestIds.gateDialog), findsOneWidget);
      await tester.enterText(find.byKey(TestIds.gateAnswer), '1');
      await tester.tap(find.byKey(TestIds.gateSubmit));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(TestIds.gateDialog), findsNothing);
    expect(s.profile.data.coins, 0);
    expect(s.parentGate.isLocked, isTrue);

    // Still locked 30 s later: the dialog opens but cannot be answered.
    now = now.add(const Duration(seconds: 30));
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.gateAnswer), findsNothing);
    await tester.tap(find.byKey(TestIds.gateCancel));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 0);

    // After the 60 s the gate works again.
    now = now.add(const Duration(seconds: 31));
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    await answerGate(tester, s);
    expect(s.profile.data.coins, 500);
  });

  test('parent gate guard: factors 6 to 9, wrong then correct', () {
    final g = ParentGateGuard(random: Random(5));
    for (var i = 0; i < 50; i++) {
      g.newQuestion();
      expect(g.a, inInclusiveRange(6, 9));
      expect(g.b, inInclusiveRange(6, 9));
    }
    expect(g.submit('abc'), GateAnswer.wrong);
    expect(g.submit('${g.a * g.b}'), GateAnswer.correct);
  });

  testWidgets('remove ads: continue is granted at once without an ad', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await s.profile.addCoins(200);
    await s.profile.deliverPurchase(
      const PurchaseUpdate('remove_ads_all', PurchaseStatus.purchased),
      s.catalog,
    );
    final game = await pumpGameOver(tester, s);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(ads.rewardedShown, 0);
    expect(find.byKey(TestIds.gameOverContinueCoins), findsNothing);
    expect(s.profile.data.coins, 200);
    expect(game.state.isGameOver, isFalse);
    expect(game.state.revivesUsed, 1);
    expect(game.state.tray, hasLength(3));
  });

  testWidgets('under 50 coins: continue goes straight to the ad', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await s.profile.addCoins(continueCoinCost - 1);
    final game = await pumpGameOver(tester, s);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(find.byKey(TestIds.gameOverContinueAd), findsNothing);
    expect(ads.rewardedShown, 1);
    expect(game.state.revivesUsed, 1);
    expect(s.profile.data.coins, continueCoinCost - 1);
  });

  testWidgets('50 coins or more: choice; coins spend exactly 50', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await s.profile.addCoins(120);
    final game = await pumpGameOver(tester, s);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(find.byKey(TestIds.gameOverContinueAd), findsOneWidget);
    expect(find.byKey(TestIds.gameOverContinueCoins), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameOverContinueCoins));
    await settle(tester);
    expect(ads.rewardedShown, 0);
    expect(s.profile.data.coins, 120 - continueCoinCost);
    expect(game.state.revivesUsed, 1);
    expect(game.state.isGameOver, isFalse);
  });

  testWidgets('50 coins or more: the ad choice costs no coins', (tester) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await s.profile.addCoins(120);
    final game = await pumpGameOver(tester, s);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    await tester.tap(find.byKey(TestIds.gameOverContinueAd));
    await settle(tester);
    expect(ads.rewardedShown, 1);
    expect(s.profile.data.coins, 120);
    expect(game.state.revivesUsed, 1);
  });

  testWidgets('coin continues count against the 3 per run limit', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await s.profile.addCoins(500);
    final game = await pumpGameOver(tester, s);
    game.state.revivesUsed = GameState.maxRevives - 1;
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    await tester.tap(find.byKey(TestIds.gameOverContinueCoins));
    await settle(tester);
    expect(game.state.revivesUsed, GameState.maxRevives);
    expect(s.profile.data.coins, 500 - continueCoinCost);
    expect(game.state.canRevive, isFalse);
  });

  testWidgets('home hero uses the saved theme skin and pauses when covered', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await s.profile.setThemeIndex(3);
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.homeHero), findsOneWidget);
    final hero = tester.state<HomeHeroState>(find.byType(HomeHero));
    expect(hero.theme.id, 'candy');
    expect(hero.running, isTrue);
    await s.profile.setThemeIndex(4);
    await tester.pump();
    expect(hero.theme.id, 'ocean');
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pump(const Duration(milliseconds: 500));
    expect(hero.running, isFalse);
  });

  testWidgets('home background follows the saved theme index', (tester) async {
    final s = await buildFakeServices();
    await s.profile.setThemeIndex(2);
    await pumpApp(tester, s);
    final bg = tester.widget<ThemeBackground>(find.byType(ThemeBackground));
    expect(bg.theme.id, 'wood');
  });

  testWidgets('home shows the main menu', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    for (final k in [
      TestIds.homePlay,
      TestIds.homeDailyReward,
      TestIds.homeChallenges,
      TestIds.homeShop,
      TestIds.homeSettings,
      TestIds.homeCoins,
      TestIds.homeBestScore,
    ]) {
      expect(find.byKey(k), findsOneWidget, reason: '$k');
    }
  });

  testWidgets('daily reward screen: claim adds coins and disables the button', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.ensureVisible(find.byKey(TestIds.homeDailyReward));
    // The home hero ticker never settles, so pump a fixed time.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(TestIds.homeDailyReward));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.dailyDay(6)), findsOneWidget);
    await tester.tap(find.byKey(TestIds.dailyClaim));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, DailyRewardEngine.coinsByDay[0]);
    final btn = tester.widget<FilledButton>(find.byKey(TestIds.dailyClaim));
    expect(btn.onPressed, isNull);
  });

  testWidgets(
    'challenges screen lists three daily challenges and achievements',
    (tester) async {
      final s = await buildFakeServices();
      await pumpApp(tester, s);
      await tester.tap(find.byKey(TestIds.homeChallenges));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(TestIds.challengeTile(i)), findsOneWidget);
      }
      expect(find.byKey(TestIds.achievementTile('first_game')), findsOneWidget);
    },
  );

  testWidgets('shop: buying remove ads marks it owned and disables ads', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.shopBuy('remove_ads_all')));
    await tester.pumpAndSettle();
    await answerGate(tester, s);
    expect(s.profile.data.adsRemoved, isTrue);
    expect(s.ads.adsEnabled, isFalse);
    expect(find.byKey(TestIds.shopBuy('remove_ads_all')), findsNothing);
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    await answerGate(tester, s);
    expect(s.profile.data.coins, 500);
  });

  testWidgets('settings toggles persist to the profile', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsSound));
    await tester.pumpAndSettle();
    expect(s.profile.data.soundOn, isFalse);
    // Play Games is off in the template config, so its row is hidden.
    expect(find.byKey(TestIds.settingsPlayGames), findsNothing);
  });

  testWidgets('sound and hand settings persist and apply', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    expect(s.profile.data.masterVolume, 1.0);
    expect(s.profile.data.ambience, 'morning_birds');
    expect(s.profile.data.voiceOn, isTrue);
    expect(s.profile.data.leftHanded, isFalse);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsVoice));
    await tester.pumpAndSettle();
    expect(s.profile.data.voiceOn, isFalse);
    await tester.tap(find.text('Left'));
    await tester.pumpAndSettle();
    expect(s.profile.data.leftHanded, isTrue);
    await tester.tap(find.byKey(TestIds.settingsAmbience));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heartbeat').last);
    await tester.pumpAndSettle();
    expect(s.profile.data.ambience, 'heartbeat');
    await tester.drag(
      find.byKey(TestIds.settingsVolume),
      const Offset(-1000, 0),
    );
    await tester.pumpAndSettle();
    expect(s.profile.data.masterVolume, 0.0);
    expect(find.byKey(TestIds.settingsHand), findsOneWidget);
  });

  testWidgets('left hand mirrors the back button', (tester) async {
    Future<double> backX(bool left) async {
      final s = await buildFakeServices();
      await s.profile.setLeftHanded(left);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ServicesScope(
          services: s,
          child: const MaterialApp(home: GameScreen()),
        ),
      );
      await tester.pump();
      final x = tester.getCenter(find.byKey(TestIds.gameBack)).dx;
      await tester.pumpWidget(const SizedBox());
      return x;
    }

    final right = await backX(false);
    final left = await backX(true);
    expect(right, lessThan(200));
    expect(left, greaterThan(200));
  });

  testWidgets('game: dragging a tray piece onto the board places it', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await tester.pump();
    final bot = PuzzleBot(tester);
    await bot.waitForGame();
    expect(bot.game.state.score, 0);
    final made = await bot.playMoves(3);
    expect(made, 3);
    expect(bot.game.state.piecesPlaced, 3);
    expect(bot.game.state.score, greaterThan(0));
    expect(
      tester.widget<Text>(find.byKey(TestIds.gameScore)).data,
      '${bot.game.state.score}',
    );
  });

  testWidgets('game: dropping outside the board does not place the piece', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await tester.pump();
    final bot = PuzzleBot(tester);
    await bot.waitForGame();
    final origin = tester.getTopLeft(find.byKey(TestIds.gameWidget));
    final (sx, sy) = bot.game.layout.trayCenter(0);
    await tester.dragFrom(origin + Offset(sx, sy), Offset(-sx + 1, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(bot.game.state.piecesPlaced, 0);
  });

  testWidgets('game over offers a rewarded-ad revive that continues the game', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Checkerboard: every empty cell is isolated, so after the dot nothing fits.
    final rows = List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.');
    final game = BlockPuzzleGame(
      initialState: GameState(
        generator: PieceGenerator(Random(1)),
        board: Board.fromRows(rows),
        tray: [
          PieceCatalog.dot,
          PieceCatalog.byId('bar2_0'),
          PieceCatalog.byId('square2_0'),
        ],
      ),
    );
    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: MaterialApp(home: GameScreen(game: game)),
      ),
    );
    final bot = PuzzleBot(tester);
    await bot.waitForGame();
    expect(await bot.drag(0, 0, 0), isTrue);
    await settle(tester);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.gameOverRevive), findsOneWidget);

    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(ads.rewardedShown, 1);
    expect(game.state.isGameOver, isFalse);
    expect(game.state.revivesUsed, 1);
    expect(game.state.revivesRemaining, 2);
    expect(find.byKey(TestIds.gameOverDialog), findsNothing);
  });

  for (final canContinue in [true, false]) {
    testWidgets(
      'game over: Continue size vs Play again (continue=$canContinue)',
      (tester) async {
        final s = await buildFakeServices();
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final rows = List.generate(
          8,
          (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.',
        );
        final state = GameState(
          generator: PieceGenerator(Random(1)),
          board: Board.fromRows(rows),
          tray: [
            PieceCatalog.dot,
            PieceCatalog.byId('bar2_0'),
            PieceCatalog.byId('square2_0'),
          ],
        );
        if (!canContinue) state.revivesUsed = GameState.maxRevives;
        final game = BlockPuzzleGame(initialState: state);
        await tester.pumpWidget(
          ServicesScope(
            services: s,
            child: MaterialApp(home: GameScreen(game: game)),
          ),
        );
        final bot = PuzzleBot(tester);
        await bot.waitForGame();
        await bot.drag(0, 0, 0);
        await settle(tester);
        expect(find.byKey(TestIds.gameOverRetry), findsOneWidget);
        expect(find.byKey(TestIds.gameOverHome), findsOneWidget);
        final retry = tester.getSize(find.byKey(TestIds.gameOverRetry));
        if (canContinue) {
          expect(find.byKey(TestIds.gameOverRevive), findsOneWidget);
          expect(find.text('$continueLabel · 3 left'), findsOneWidget);
          final cont = tester.getSize(find.byKey(TestIds.gameOverRevive));
          expect(cont.height, greaterThan(retry.height));
          expect(cont.width, greaterThan(retry.width));
        } else {
          expect(find.byKey(TestIds.gameOverRevive), findsNothing);
          expect(
            tester.widget<Text>(find.text('Play again')).style!.fontSize,
            22,
          );
        }
      },
    );
  }

  testWidgets(
    'game over: declined revive ad keeps the dialog and plays again',
    (tester) async {
      final ads = FakeAdService(rewardResult: false);
      final s = await buildFakeServices(ads: ads);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rows = List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.');
      final game = BlockPuzzleGame(
        initialState: GameState(
          generator: PieceGenerator(Random(1)),
          board: Board.fromRows(rows),
          tray: [
            PieceCatalog.dot,
            PieceCatalog.byId('bar2_0'),
            PieceCatalog.byId('square2_0'),
          ],
        ),
      );
      await tester.pumpWidget(
        ServicesScope(
          services: s,
          child: MaterialApp(home: GameScreen(game: game)),
        ),
      );
      final bot = PuzzleBot(tester);
      await bot.waitForGame();
      await bot.drag(0, 0, 0);
      await settle(tester);
      await tester.tap(find.byKey(TestIds.gameOverRevive));
      await settle(tester);
      // Ad failed: dialog is shown again.
      expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
      await tester.tap(find.byKey(TestIds.gameOverRetry));
      await settle(tester);
      expect(game.state.piecesPlaced, 0);
      expect(game.state.isGameOver, isFalse);
      expect(s.profile.data.stats.gamesPlayed, 1);
      expect(ads.rewardedShown, 1);
      expect(AdPlacement.values, contains(AdPlacement.revive));
    },
  );
}
