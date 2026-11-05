import 'package:flutter/material.dart';

import '../core/services.dart';
import '../game/themes/block_theme.dart';
import 'home_hero.dart';
import 'routes.dart';
import 'test_ids.dart';
import 'theme_background.dart';
import 'tip_card.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ServicesScope.of(context).profile.onAppOpened();
    }
  }

  void _open(String route) => Navigator.of(context).pushNamed(route);

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, child) => ThemeBackground(
          theme: BlockTheme.byIndex(profile.data.themeIndex),
          child: child!,
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profile,
            builder: (context, _) {
              final claimable = profile.challenges.any((c) => c.claimable);
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 14,
                    children: [
                      const HomeHero(),
                      Text(
                        s.config.displayName,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(
                                  color: Color(0xAA000000),
                                  offset: Offset(0, 3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          KeyedSubtree(
                            key: TestIds.homeCoins,
                            child: StatChip(
                              icon: Icons.monetization_on,
                              label: '${profile.data.coins}',
                              color: Colors.amber,
                            ),
                          ),
                          KeyedSubtree(
                            key: TestIds.homeBestScore,
                            child: StatChip(
                              icon: Icons.emoji_events,
                              label: 'Best ${profile.data.bestScore}',
                            ),
                          ),
                          if (s.config.retention.streaks)
                            KeyedSubtree(
                              key: TestIds.homeStreak,
                              child: StatChip(
                                icon: Icons.local_fire_department,
                                label: '${profile.displayStreak}',
                                color: Colors.deepOrange,
                              ),
                            ),
                        ],
                      ),
                      if (profile.homeTipPending)
                        TipCard(
                          key: TestIds.tipHome,
                          title: 'Tip of the day',
                          text: s.tips.tipOfTheDay(profile.today),
                          onClose: profile.closeHomeTip,
                        ),
                      const SizedBox(height: 8),
                      MenuButton(
                        key: TestIds.homePlay,
                        label: 'Play!',
                        icon: Icons.play_circle_fill,
                        primary: true,
                        onPressed: () => _open(AppRoutes.play),
                      ),
                      if (s.config.retention.dailyReward)
                        MenuButton(
                          key: TestIds.homeDailyReward,
                          label: 'Daily reward',
                          icon: Icons.card_giftcard,
                          colors: const [Color(0xFFFF8FB1), KidColors.coral],
                          badge: profile.dailyRewardAvailable,
                          onPressed: () => _open(AppRoutes.dailyReward),
                        ),
                      if (s.config.retention.dailyChallenges ||
                          s.config.retention.achievements)
                        MenuButton(
                          key: TestIds.homeChallenges,
                          label: 'Challenges',
                          icon: Icons.flag_circle,
                          colors: const [Color(0xFFB79CFF), KidColors.grape],
                          badge: claimable,
                          onPressed: () => _open(AppRoutes.challenges),
                        ),
                      MenuButton(
                        key: TestIds.homeShop,
                        label: 'Shop',
                        icon: Icons.shopping_basket,
                        colors: const [Color(0xFF6BEBB0), Color(0xFF1FB57A)],
                        onPressed: () => _open(AppRoutes.shop),
                      ),
                      MenuButton(
                        key: TestIds.homeSettings,
                        label: 'Settings',
                        icon: Icons.settings,
                        colors: const [Color(0xFFB0BEC5), Color(0xFF78909C)],
                        onPressed: () => _open(AppRoutes.settings),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
