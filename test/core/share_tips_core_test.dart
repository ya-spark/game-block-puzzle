import 'dart:io';
import 'dart:math';

import 'package:block_puzzle/core/config/app_config.dart';
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
    test('without a link no link is added and Share app is a no-op', () async {
      final f = FakeShareService();
      await f.shareScore(score: 42);
      await f.shareAchievement(title: 'Sky High');
      await f.shareApp();
      expect(f.hasLink, isFalse);
      expect(f.sent.map((e) => e.text), [
        'This is my high score in Block Puzzle: 42. Can you beat it?',
        'I unlocked "Sky High" in Block Puzzle! Can you beat it?',
      ]);
    });

    test('with a link it follows the message on a new line', () async {
      final f = FakeShareService(link: 'https://example.com/x');
      await f.shareScore(score: 7);
      await f.shareAchievement(title: 'Sky High');
      await f.shareApp();
      const link = '\nhttps://example.com/x';
      expect(f.sent.map((e) => e.text), [
        'This is my high score in Block Puzzle: 7. Can you beat it?$link',
        'I unlocked "Sky High" in Block Puzzle! Can you beat it?$link',
        'Try Block Puzzle! Can you beat my score?$link',
      ]);
    });
  });

  group('share link config', () {
    AppConfig load(String shareYaml) {
      final base = File('app.config.yaml').readAsStringSync();
      final cut = base.indexOf('\nshare:');
      final end = base.indexOf('\n# Retention');
      return AppConfig.fromYamlString(
        '${base.substring(0, cut)}\n$shareYaml\n${base.substring(end)}',
      );
    }

    test('the shipped default is internal_test with the test URL', () {
      final c = AppConfig.fromYamlString(
        File('app.config.yaml').readAsStringSync(),
      );
      expect(c.share.linkMode, ShareLinkMode.internalTest);
      expect(
        c.shareLink,
        'https://play.google.com/apps/internaltest/4699568684837272672',
      );
    });

    test('store uses the Play Store page of the package', () {
      final c = load('share:\n  link_mode: store');
      expect(
        c.shareLink,
        'https://play.google.com/store/apps/details?id=${c.packageName}',
      );
    });

    test('off, and internal_test with an empty URL, give no link', () {
      expect(load('share:\n  link_mode: off').shareLink, isNull);
      expect(
        load('share:\n  link_mode: internal_test\n  internal_test_url: ""')
            .shareLink,
        isNull,
      );
      expect(load('share:\n  link_mode: internal_test').shareLink, isNull);
    });

    test('a missing mode defaults to internal_test', () {
      final c = load('share:\n  internal_test_url: "https://x.y/z"');
      expect(c.share.linkMode, ShareLinkMode.internalTest);
      expect(c.shareLink, 'https://x.y/z');
    });
  });
}
