import 'package:flutter/material.dart';

import '../core/services.dart';
import '../game/themes/block_theme.dart';
import 'home_hero.dart';
import 'more_games_screen.dart';
import 'routes.dart';
import 'test_ids.dart';
import 'theme_background.dart';
import 'tip_dialog.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTip());
  }

  bool _tipOpen = false;

  /// True only when Home is the page on top and no run is on screen.
  bool _homeIsOnTop(Services s) =>
      mounted && !s.inRun && (ModalRoute.of(context)?.isCurrent ?? true);

  /// Opens the tip of the day once per day, when the home page is shown and nothing else is on top.
  /// Never queued: when the guard blocks it nothing happens, and the next Home visit tries again.
  Future<void> _maybeShowTip() async {
    if (_tipOpen || !mounted) return;
    final s = ServicesScope.of(context);
    final profile = s.profile;
    if (!_homeIsOnTop(s) || !profile.homeTipPending) return;
    _tipOpen = true;
    try {
      final text = s.tips.tipOfTheDay(profile.today);
      await profile.closeHomeTip(); // counts as shown for today
      // The save is async: a run may have started meanwhile, so check again before opening.
      if (!mounted || !_homeIsOnTop(s)) return;
      await showTipDialog(context, text: text);
    } finally {
      _tipOpen = false;
    }
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
      _maybeShowTip();
    }
  }

  void _open(String route) => Navigator.of(context).pushNamed(route);

  /// Play: with an unfinished game saved, ask Resume or New game first.
  Future<void> _play() async {
    final profile = ServicesScope.of(context).profile;
    if (profile.data.game != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: TestIds.resumeDialog,
          title: const Text('Unfinished game'),
          content: const Text('Resume it, or start a new game?'),
          actions: [
            TextButton(
              key: TestIds.resumeNewGame,
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: const Text('New game'),
            ),
            FilledButton(
              key: TestIds.resumeGame,
              onPressed: () => Navigator.pop(ctx, 'resume'),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'new') await profile.saveGame(null);
    }
    if (mounted) _open(AppRoutes.play);
  }

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
        child: Stack(
          children: [
            SafeArea(
              child: ListenableBuilder(
                listenable: profile,
                builder: (context, _) {
                  final claimable = profile.challenges.any((c) => c.claimable);
                  return LayoutBuilder(
                    builder: (context, box) {
                      final (heroH, gap) = homeLayout(box.maxHeight);
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: gap,
                            children: [
                              HomeHero(height: heroH),
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
                                      leading: const CoinIcon(),
                                      label: '${profile.data.coins}',
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
                              const SizedBox(height: 8),
                              MenuButton(
                                key: TestIds.homePlay,
                                label: 'Play!',
                                icon: Icons.play_circle_fill,
                                primary: true,
                                onPressed: _play,
                              ),
                              HomeGrid(
                                children: [
                                  if (s.config.retention.dailyReward)
                                    MenuButton(
                                      compact: true,
                                      key: TestIds.homeDailyReward,
                                      label: 'Daily reward',
                                      icon: Icons.card_giftcard,
                                      colors: const [
                                        Color(0xFFFF8FB1),
                                        KidColors.coral,
                                      ],
                                      badge: profile.dailyRewardAvailable,
                                      onPressed: () =>
                                          _open(AppRoutes.dailyReward),
                                    ),
                                  if (s.config.retention.dailyChallenges ||
                                      s.config.retention.achievements)
                                    MenuButton(
                                      compact: true,
                                      key: TestIds.homeChallenges,
                                      label: 'Challenges',
                                      icon: Icons.flag_circle,
                                      colors: const [
                                        Color(0xFFB79CFF),
                                        KidColors.grape,
                                      ],
                                      badge: claimable,
                                      onPressed: () =>
                                          _open(AppRoutes.challenges),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      if (s.config.visibleMoreGames.isNotEmpty)
                        HomeIconButton(
                          key: TestIds.homeMoreGames,
                          icon: Icons.apps,
                          label: 'More games',
                          colors: const [Color(0xFF7AD7F0), Color(0xFF3FA7FF)],
                          onPressed: () => openMoreGames(context),
                        ),
                      HomeIconButton(
                        key: TestIds.homeShop,
                        icon: Icons.shopping_basket,
                        label: 'Shop',
                        colors: const [Color(0xFF6BEBB0), Color(0xFF1FB57A)],
                        onPressed: () => _open(AppRoutes.shop),
                      ),
                      HomeIconButton(
                        key: TestIds.homeSettings,
                        icon: Icons.settings,
                        label: 'Settings',
                        colors: const [Color(0xFFB0BEC5), Color(0xFF78909C)],
                        onPressed: () => _open(AppRoutes.settings),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
