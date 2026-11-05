import 'dart:math';

import 'package:block_puzzle/core/share/share_service.dart';
import 'package:block_puzzle/core/tips/tip_service.dart';
import 'package:block_puzzle/game/tips.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tips', () {
    test('every tip is non-empty, at most 80 characters and unique', () {
      expect(gameTips.length, greaterThanOrEqualTo(15));
      for (final t in gameTips) {
        expect(t.trim(), isNotEmpty);
        expect(t.length, lessThanOrEqualTo(80), reason: t);
      }
      expect(gameTips.toSet().length, gameTips.length);
    });

    test('the same tip never appears twice in a row', () {
      for (var seed = 0; seed < 20; seed++) {
        final svc = TipService(random: Random(seed));
        String? last;
        for (var i = 0; i < gameTips.length * 6; i++) {
          final t = svc.next();
          expect(t, isNot(last), reason: 'seed $seed, draw $i');
          last = t;
        }
      }
    });

    test('a bag deals every tip once before repeating', () {
      final svc = TipService(random: Random(3));
      final bag = {for (var i = 0; i < gameTips.length; i++) svc.next()};
      expect(bag.length, gameTips.length);
    });

    test('tip of the day is stable per day and changes by day', () {
      final svc = TipService();
      expect(svc.tipOfTheDay(100), svc.tipOfTheDay(100));
      expect(svc.tipOfTheDay(100), isNot(svc.tipOfTheDay(101)));
    });
  });

  group('share texts', () {
    test(
      'without the link flag no link is added and Share app is a no-op',
      () async {
        final f = FakeShareService();
        await f.shareScore(score: 42);
        await f.shareAchievement(title: 'Sky High');
        await f.shareApp();
        expect(f.sent.map((e) => e.text), [
          'I scored 42 in Block Puzzle! Can you beat it?',
          'I unlocked "Sky High" in Block Puzzle!',
        ]);
      },
    );

    test('with the link flag the store link is appended', () async {
      final f = FakeShareService(
        appLinkEnabled: true,
        storeLink: 'https://play.google.com/store/apps/details?id=x.y',
      );
      await f.shareScore(score: 7);
      await f.shareAchievement(title: 'Sky High');
      await f.shareApp();
      const link = ' https://play.google.com/store/apps/details?id=x.y';
      expect(f.sent.map((e) => e.text), [
        'I scored 7 in Block Puzzle! Can you beat it?$link',
        'I unlocked "Sky High" in Block Puzzle!$link',
        'Try Block Puzzle!$link',
      ]);
    });
  });
}
