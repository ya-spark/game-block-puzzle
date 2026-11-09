import 'package:flutter_test/flutter_test.dart';
import 'package:block_puzzle/ui/test_ids.dart';

import '../helpers/fake_services.dart';
import 'screens_test.dart' show pumpApp;

Future<void> _pump(WidgetTester tester) async {
  // The game loop and the Home hero never settle: pump fixed durations.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('Play goes straight to the game when nothing is saved', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await _pump(tester);
    expect(find.byKey(TestIds.resumeDialog), findsNothing);
    expect(find.byKey(TestIds.gameWidget), findsOneWidget);
  });

  testWidgets('Play asks Resume or New game when a game is saved', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await s.profile.saveGame({'unfinished': true});
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await _pump(tester);
    expect(find.byKey(TestIds.resumeDialog), findsOneWidget);
    expect(find.byKey(TestIds.gameWidget), findsNothing);
    // New game drops the save and opens the game.
    await tester.tap(find.byKey(TestIds.resumeNewGame));
    await _pump(tester);
    expect(s.profile.data.game, isNull);
    expect(find.byKey(TestIds.gameWidget), findsOneWidget);
  });

  testWidgets('Resume opens the game; dismissing the question stays on Home', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await s.profile.saveGame({'unfinished': true});
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await _pump(tester);
    await tester.tapAt(const Offset(2, 2)); // outside the dialog
    await _pump(tester);
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
    expect(s.profile.data.game, isNotNull);
    await tester.tap(find.byKey(TestIds.homePlay));
    await _pump(tester);
    await tester.tap(find.byKey(TestIds.resumeGame));
    await _pump(tester);
    expect(find.byKey(TestIds.gameWidget), findsOneWidget);
  });
}
