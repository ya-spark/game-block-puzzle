import 'package:flutter/material.dart';

import 'challenges_screen.dart';
import 'daily_reward_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

/// Named routes. On web each name is the browser URL (`/#/challenges`), so
/// every screen is deep-linkable; on Android they are plain in-app names.
abstract final class AppRoutes {
  static const home = '/';
  static const play = '/play';
  static const dailyReward = '/daily-reward';
  static const challenges = '/challenges';
  static const shop = '/shop';
  static const settings = '/settings';

  static Route<void> onGenerateRoute(RouteSettings settings) {
    final builder = switch (settings.name) {
      play => (BuildContext _) => const GameScreen(),
      dailyReward => (BuildContext _) => const DailyRewardScreen(),
      challenges => (BuildContext _) => const ChallengesScreen(),
      shop => (BuildContext _) => const ShopScreen(),
      AppRoutes.settings => (BuildContext _) => const SettingsScreen(),
      // Home, and any unknown link, lands on the home screen.
      _ => (BuildContext _) => const HomeScreen(),
    };
    return MaterialPageRoute<void>(settings: settings, builder: builder);
  }
}
