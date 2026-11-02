import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads/ad_service.dart';
import '../core/audio/audio_service.dart';
import '../core/profile/profile_store.dart';
import '../core/services.dart';
import '../game/flame/block_puzzle_game.dart';
import '../game/rules/game_state.dart';
import 'test_ids.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game});

  /// Injectable for tests (seeded generator).
  final BlockPuzzleGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  BlockPuzzleGame? _game;
  bool _recorded = false;
  bool _dialogOpen = false;
  final AudioService _audio = AudioService();
  bool _warned = false;

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  BlockPuzzleGame _ensureGame(Services s) {
    final existing = _game;
    if (existing != null) return existing;
    final game =
        widget.game ?? BlockPuzzleGame(bestScore: s.profile.data.bestScore);
    game.onPlaced = (o) {
      _audio.enabled = s.profile.data.soundOn;
      if (!o.gameOver) {
        _praise(o);
        _warnIfCrowded(game);
      }
      if (s.profile.data.vibrationOn && o.linesCleared > 0) {
        HapticFeedback.mediumImpact();
      }
    };
    game.onChanged = () => setState(() {});
    game.onGameOver = () {
      _audio.enabled = s.profile.data.soundOn;
      if (game.state.score > s.profile.data.bestScore) {
        _audio.voice('better_than_the_best');
      } else {
        _audio.voice('game_over', variants: 2);
      }
      _showGameOver(s);
    };
    _audio.enabled = s.profile.data.soundOn;
    _audio.voice('go');
    return _game = game;
  }

  /// "Careful" once the board is over 70% full; re-armed when it clears out.
  void _warnIfCrowded(BlockPuzzleGame game) {
    final b = game.state.board;
    final crowded = b.filledCount > b.size * b.size * 0.7;
    if (crowded && !_warned) _audio.voice('careful');
    _warned = crowded;
  }

  /// Narrator line for a placement that cleared lines; [PlaceOutcome.combo] is 1 for none.
  void _praise(PlaceOutcome o) {
    final String? line;
    if (o.linesCleared == 0) {
      line = null;
    } else if (o.linesCleared >= 4) {
      line = 'incredible';
    } else if (o.combo >= 5) {
      line = 'unstoppable';
    } else if (o.combo >= 3) {
      line = 'combo';
    } else if (o.linesCleared == 3) {
      line = 'excellent';
    } else if (o.linesCleared == 2) {
      line = 'great';
    } else if (o.combo >= 2) {
      line = 'nice';
    } else {
      line = null;
    }
    if (line != null) _audio.voice(line);
  }

  Future<void> _finishGame(Services s) async {
    if (_recorded) return;
    _recorded = true;
    final g = _game!.state;
    final unlocked = await s.profile.recordGameFinished(
      GameSummary(
        score: g.score,
        linesCleared: g.linesClearedTotal,
        piecesPlaced: g.piecesPlaced,
        maxCombo: g.maxComboReached,
      ),
    );
    await s.leaderboard.submitScore(
      s.config.playGames.leaderboardHighScore,
      g.score,
    );
    for (final a in unlocked) {
      await s.leaderboard.unlockAchievement(a.id);
    }
    s.analytics.logEvent('game_over', {'score': g.score});
    if (unlocked.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')} '
            '(+${unlocked.fold<int>(0, (n, a) => n + a.reward)} coins)',
          ),
        ),
      );
    }
  }

  Future<void> _showGameOver(Services s) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final game = _game!;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      // No dimming and a dialog pinned to the top, so the final board stays visible.
      barrierColor: Colors.transparent,
      builder: (ctx) => AlertDialog(
        key: TestIds.gameOverDialog,
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        title: const Text('Game over'),
        content: Text(
          'Score ${game.state.score} · Best ${game.state.bestScore}'
          '${game.state.canRevive ? ' · Revives left: ${game.state.revivesRemaining}' : ''}',
          key: TestIds.gameOverRevivesLeft,
        ),
        actions: [
          if (game.state.canRevive)
            FilledButton.icon(
              key: TestIds.gameOverRevive,
              icon: const Icon(Icons.smart_display),
              label: Text(
                'Revive (watch ad) · ${game.state.revivesRemaining} left',
              ),
              onPressed: () => Navigator.pop(ctx, 'revive'),
            ),
          TextButton(
            key: TestIds.gameOverRetry,
            onPressed: () => Navigator.pop(ctx, 'retry'),
            child: const Text('Play again'),
          ),
          TextButton(
            key: TestIds.gameOverHome,
            onPressed: () => Navigator.pop(ctx, 'home'),
            child: const Text('Home'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'revive':
        final earned = await s.ads.showRewarded(AdPlacement.revive);
        if (!mounted) return;
        if (earned && game.revive()) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not available. Try again later.')),
        );
        _showGameOver(s);
      case 'retry':
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (!mounted) return;
        _recorded = false;
        game.restart();
        _warned = false;
        _audio.voice('go');
      default:
        await _finishGame(s);
        if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final game = _ensureGame(s);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.4,
            colors: [Color(0xFF35C2D8), Color(0xFF2C73E0), Color(0xFF4A3FB5)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // One compact header row (back, score, best) plus a one-line streak
              // strip, so the play area below keeps room for the piece tray.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Score is centred on the screen, independent of the side buttons.
                    _ScorePill(score: game.state.score),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          key: TestIds.gameBack,
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x0FFFFFFF),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFC145),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${game.state.bestScore}',
                                key: TestIds.gameBest,
                                style: const TextStyle(
                                  color: Color(0xFFFFC145),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StreakBar(
                streak: s.profile.displayStreak,
                combo: game.state.comboStreak,
                showStreak: s.config.retention.streaks,
              ),
              Expanded(
                child: GameWidget<BlockPuzzleGame>(
                  key: TestIds.gameWidget,
                  game: game,
                ),
              ),
              KeyedSubtree(key: TestIds.gameBanner, child: s.ads.buildBanner()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Score in a glowing outlined pill.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      alignment: Alignment.center,
      padding: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF2EC4B6), width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x18FFFFFF), Color(0x06FFFFFF)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x552EC4B6), blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            key: TestIds.gameScore,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const Text(
            'SCORE',
            style: TextStyle(
              fontSize: 9,
              height: 1,
              letterSpacing: 3,
              color: Color(0xFF7FB7BD),
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak (daily play streak) and current combo.
class _StreakBar extends StatelessWidget {
  const _StreakBar({
    required this.streak,
    required this.combo,
    required this.showStreak,
  });
  final int streak;
  final int combo;
  final bool showStreak;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[
      if (showStreak)
        Row(
          key: TestIds.gameStreak,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 16,
              color: Color(0xFFFF6B5E),
            ),
            const SizedBox(width: 4),
            Text('Day $streak streak'),
          ],
        ),
      if (combo > 0) Text('Combo x$combo', key: TestIds.gameCombo),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFCFE9EC), fontSize: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: parts,
        ),
      ),
    );
  }
}
