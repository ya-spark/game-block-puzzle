import 'package:block_puzzle/app.dart';
import 'package:block_puzzle/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

Future<void> _pumpHome(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final s = await buildFakeServices();
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

void _expectFits(WidgetTester tester, Size size) {
  expect(tester.takeException(), isNull);
  final view = Offset.zero & size;
  for (final k in [
    TestIds.homePlay,
    TestIds.homeDailyReward,
    TestIds.homeChallenges,
    TestIds.homeShop,
    TestIds.homeSettings,
  ]) {
    final r = tester.getRect(find.byKey(k));
    expect(
      view.contains(r.topLeft) && view.contains(r.bottomRight),
      isTrue,
      reason: '$k $r is outside $view',
    );
  }
  // Home layout v2: Play 240 x 60, Daily reward and Challenges 116 x 52 side by side, 8 dp apart.
  final play = tester.getRect(find.byKey(TestIds.homePlay));
  final daily = tester.getRect(find.byKey(TestIds.homeDailyReward));
  final challenges = tester.getRect(find.byKey(TestIds.homeChallenges));
  void expectSize(Rect r, double w, double h) {
    expect(r.width, closeTo(w, 0.5));
    expect(r.height, closeTo(h, 0.5));
  }

  expectSize(play, 240, 60);
  expectSize(daily, 116, 52);
  expectSize(challenges, 116, 52);
  expect(challenges.left - daily.right, closeTo(8, 0.5));
  expect(daily.top, challenges.top);
  expect(play.overlaps(daily) || play.overlaps(challenges), isFalse);
  // The Shop and Settings icons: inside the view, 48 dp tap targets, clear of every button.
  for (final k in [TestIds.homeShop, TestIds.homeSettings]) {
    final r = tester.getRect(find.byKey(k));
    expect(view.contains(r.topLeft) && view.contains(r.bottomRight), isTrue);
    expect(r.width >= 48 && r.height >= 48, isTrue);
    for (final o in [play, daily, challenges]) {
      expect(r.overlaps(o), isFalse, reason: '$k $r overlaps $o');
    }
  }
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  expect(scroll.position.maxScrollExtent, 0);
}

void main() {
  // Block Puzzle has no banner on Home, so 360 x 640 is the tightest case.
  for (final size in const [Size(360, 640), Size(400, 800)]) {
    testWidgets('home fits without scrolling at $size', (tester) async {
      await _pumpHome(tester, size);
      _expectFits(tester, size);
    });
  }

  testWidgets('home has no overflow at text scale 1.5', (tester) async {
    await _pumpHome(tester, const Size(360, 640), textScale: 1.5);
    expect(tester.takeException(), isNull);
  });
}
