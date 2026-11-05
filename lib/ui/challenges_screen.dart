import 'package:flutter/material.dart';

import '../core/retention/achievements.dart';
import '../core/services.dart';
import '../game/themes/block_theme.dart';
import 'share_card.dart';
import 'test_ids.dart';
import 'widgets.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '\u{1F3C6} Challenges',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
        ),
      ),
      body: Container(
        decoration: KidColors.background,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profile,
            builder: (context, _) {
              final stats = profile.data.stats;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight, 16, 24),
                children: [
                  if (s.config.retention.dailyChallenges) ...[
                    Text(
                      'Daily challenges',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: KidColors.ink,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                    ),
                    for (final (i, c) in profile.challenges.indexed)
                      Container(
                        key: TestIds.challengeTile(i),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: _cardDecoration(
                          c.claimed ? KidColors.mint : KidColors.sun,
                        ),
                        child: Row(
                          children: [
                            Text(
                              c.claimed ? '\u2705' : '\u{1F3AF}',
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.description,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: KidColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      minHeight: 12,
                                      color: KidColors.mint,
                                      backgroundColor: Colors.black12,
                                      value: (c.progress / c.target)
                                          .clamp(0, 1)
                                          .toDouble(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (c.claimed)
                              const Icon(
                                Icons.check_circle,
                                color: KidColors.mint,
                                size: 40,
                              )
                            else
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  key: TestIds.challengeClaim(c.id),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: KidColors.coral,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  onPressed: c.claimable
                                      ? () => profile.claimChallenge(c.id)
                                      : null,
                                  child: Text('\u{1FA99} +${c.reward}'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (s.config.retention.achievements) ...[
                    Text(
                      'Achievements',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: KidColors.ink,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                    ),
                    for (final a in AchievementEngine.all)
                      Container(
                        key: TestIds.achievementTile(a.id),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: _cardDecoration(
                          profile.data.unlockedAchievements.contains(a.id)
                              ? KidColors.sun
                              : KidColors.ocean,
                        ),
                        child: Row(
                          children: [
                            Text(
                              profile.data.unlockedAchievements.contains(a.id)
                                  ? '\u{1F3C5}'
                                  : '\u{1F512}',
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: KidColors.ink,
                                    ),
                                  ),
                                  Text(
                                    '${a.description}  (${a.valueIn(stats).clamp(0, a.target)}/${a.target})',
                                    style: const TextStyle(
                                      color: KidColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (profile.data.unlockedAchievements.contains(
                              a.id,
                            ))
                              Builder(
                                builder: (ctx) => IconButton(
                                  key: TestIds.achievementShare(a.id),
                                  tooltip: 'Share',
                                  icon: const Icon(
                                    Icons.share,
                                    color: KidColors.ink,
                                  ),
                                  onPressed: () async {
                                    final png = await captureShareCard(
                                      ctx,
                                      ShareCardData(
                                        gameName: s.config.displayName,
                                        headline: 'Achievement unlocked',
                                        big: a.title,
                                        best: profile.data.bestScore,
                                        theme: BlockTheme.byIndex(
                                          profile.data.themeIndex,
                                        ),
                                      ),
                                    );
                                    await s.share.shareAchievement(
                                      title: a.title,
                                      image: png,
                                    );
                                  },
                                ),
                              ),
                            Text(
                              '\u{1FA99} +${a.reward}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: KidColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(Color accent) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: accent, width: 4),
  boxShadow: const [
    BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 6),
  ],
);
