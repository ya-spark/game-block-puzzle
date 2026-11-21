import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:game_block_puzzle/block_puzzle.dart';

import 'ads/ad_service.dart';
import 'analytics/analytics_service.dart';
import 'leaderboard/leaderboard_service.dart';
import 'services.dart';
import 'share/share_service.dart';

/// What the BlockPuzzle game asks of this app, backed by this app's own services (shop, coins, Remove
/// Ads, ads, share, leaderboard, analytics). Provided above the game by `BlockPuzzleServicesScope`.
class BlockPuzzleServicesAdapter implements BlockPuzzleServices {
  BlockPuzzleServicesAdapter(this._s);
  final Services _s;

  @override
  BlockPuzzleConfig get config => _Config(_s);
  @override
  BlockPuzzleProfileStore get profile => _s.profile;
  @override
  BlockPuzzleAds get ads => _Ads(_s.ads);
  @override
  BlockPuzzleLeaderboard get leaderboard => _Leaderboard(_s.leaderboard);
  @override
  BlockPuzzleAnalytics get analytics => _Analytics(_s.analytics);
  @override
  BlockPuzzleShare get share => _Share(_s.share);

  @override
  bool get inRun => _s.inRun;
  @override
  set inRun(bool v) => _s.inRun = v;
}

class _Config implements BlockPuzzleConfig {
  _Config(this._s);
  final Services _s;
  @override
  String get displayName => _s.config.displayName;
  @override
  String get leaderboardHighScore => _s.config.playGames.leaderboardHighScore;
  @override
  bool get streaksEnabled => _s.config.retention.streaks;
}

class _Ads implements BlockPuzzleAds {
  _Ads(this._a);
  final AdService _a;
  @override
  Future<bool> showRewarded(BlockPuzzleAdPlacement placement) =>
      _a.showRewarded(AdPlacement.values.byName(placement.name));
  @override
  Future<void> maybeShowInterstitialAfterGameOver() async {
    await _a.maybeShowInterstitialAfterGameOver();
  }

  @override
  Widget buildBanner() => _a.buildBanner();
}

class _Leaderboard implements BlockPuzzleLeaderboard {
  _Leaderboard(this._l);
  final LeaderboardService _l;
  @override
  Future<void> submitScore(String leaderboardId, int score) =>
      _l.submitScore(leaderboardId, score);
  @override
  Future<void> unlockAchievement(String achievementId) =>
      _l.unlockAchievement(achievementId);
}

class _Analytics implements BlockPuzzleAnalytics {
  _Analytics(this._a);
  final AnalyticsService _a;
  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) =>
      _a.logEvent(name, params);
}

class _Share implements BlockPuzzleShare {
  _Share(this._s);
  final ShareService _s;
  @override
  Future<void> shareScore({required int score, Uint8List? image}) =>
      _s.shareScore(score: score, image: image);
}
