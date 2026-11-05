import 'package:flutter/widgets.dart';

/// Stable widget keys for tests and automation. Rule: every interactive widget and key
/// element gets an ID here; tests must find widgets by these keys, never by text or position.
abstract final class TestIds {
  // Home
  static const homePlay = Key('home.play');
  static const homeDailyReward = Key('home.dailyReward');
  static const homeChallenges = Key('home.challenges');
  static const homeShop = Key('home.shop');
  static const homeSettings = Key('home.settings');
  static const homeCoins = Key('home.coins');
  static const homeBestScore = Key('home.bestScore');
  static const homeStreak = Key('home.streak');
  static const homeHero = Key('home.hero');

  // Game
  static const gameWidget = Key('game.widget');
  static const gameScore = Key('game.score');
  static const gameScoreLabel = Key('game.score_label');
  static const gameBest = Key('game.best');
  static const gameBack = Key('game.back');
  static const gameOverDialog = Key('game.over.dialog');
  static const gameOverRevive = Key('game.over.revive');
  static const gameOverRevivesLeft = Key('game.over.revivesLeft');
  static const gameOverRetry = Key('game.over.retry');
  static const gameOverHome = Key('game.over.home');
  static const gameOverShare = Key('game.over.share');
  static const gameBanner = Key('game.banner');
  static const gameStreak = Key('game.streak');
  static const gameCombo = Key('game.combo');
  static const gameRush = Key('game.rush');

  /// Invisible; its Semantics value is the id of the current theme.
  static const gameTheme = Key('game.theme');

  // Daily reward
  static const dailyClaim = Key('daily.claim');
  static const dailyStreak = Key('daily.streak');
  static Key dailyDay(int i) => Key('daily.day.$i');

  // Challenges / achievements
  static Key challengeClaim(String id) => Key('challenge.claim.$id');
  static Key challengeTile(int i) => Key('challenge.tile.$i');
  static Key achievementTile(String id) => Key('achievement.$id');
  static Key achievementShare(String id) => Key('achievement.share.$id');

  // Shop
  static const shopRestore = Key('shop.restore');
  static const shopUnavailable = Key('shop.unavailable');
  static Key shopBuy(String productId) => Key('shop.buy.$productId');

  // Settings
  static const settingsSound = Key('settings.sound');
  static const settingsVibration = Key('settings.vibration');
  static const settingsReminders = Key('settings.reminders');
  static const settingsPrivacy = Key('settings.privacy');
  static const settingsPlayGames = Key('settings.playGames');
  static const settingsVolume = Key('settings.volume');
  static const settingsAmbience = Key('settings.ambience');
  static const settingsVoice = Key('settings.voice');
  static const settingsHand = Key('settings.hand');
  static const settingsTips = Key('settings.tips');
  static const settingsShareApp = Key('settings.shareApp');

  // Tips (this game has no pause screen, so there is no tip.pause)
  static const tipGameOver = Key('tip.gameover');
  static const tipHome = Key('tip.home');
  static const tipHint = Key('tip.hint');
  static const tipClose = Key('tip.close');
  static const tipDontShow = Key('tip.dontShow');
}
