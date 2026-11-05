import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads/ad_service.dart';
import '../core/audio/audio_service.dart';
import '../core/profile/profile_store.dart';
import '../core/services.dart';
import '../game/flame/block_puzzle_game.dart';
import '../game/rules/game_state.dart';
import '../game/rules/piece.dart';
import 'game_over_panel.dart';
import 'share_card.dart';
import 'test_ids.dart';
import 'theme_background.dart';
import 'tip_card.dart';

/// Player-facing name of the rewarded-ad second chance on the game over screen (rename it here only).
const String continueLabel = 'Continue';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game});

  /// Injectable for tests (seeded generator).
  final BlockPuzzleGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  BlockPuzzleGame? _game;
  bool _recorded = false;
  bool _dialogOpen = false;
  final AudioService _audio = AudioService();
  bool _warned = false;
  ProfileStore? _profile;

  /// Game overs shown this session; a tip appears on every 2nd one.
  int _gameOvers = 0;

  /// One-time hint on screen (id and text), hidden after [_hintDuration].
  String? _hintId;
  String? _hintText;
  Timer? _hintTimer;
  static const _hintDuration = Duration(seconds: 4);
  static const _hints = {
    'gem': 'A gem! Clear its line to earn bonus points and a coin.',
    'boom': 'A Boom block! Clear its line to empty the 3x3 area around it.',
    'gold': 'A golden block! Clear its line to start Gold Rush.',
    'rush': 'Gold Rush! Your points are doubled for the next moves.',
  };

  /// Shows the one-time hint [id] if tips are on, it was never shown, and none is showing.
  void _maybeHint(Services s, String id) {
    if (_hintId != null || !mounted || !s.profile.hintDue(id)) return;
    s.profile.markHintSeen(id);
    _hintTimer?.cancel();
    setState(() {
      _hintId = id;
      _hintText = _hints[id];
    });
    _hintTimer = Timer(_hintDuration, _hideHint);
  }

  void _hideHint() {
    _hintTimer?.cancel();
    if (!mounted) return;
    setState(() => _hintId = null);
  }

  /// Hints for special blocks that just appeared in the tray, and for a running Gold Rush.
  void _checkHints(Services s, BlockPuzzleGame game) {
    if (game.state.rushLeft > 0) _maybeHint(s, 'rush');
    for (final p in game.state.tray.whereType<Piece>()) {
      for (var i = 0; i < p.cells.length; i++) {
        switch (p.kindAt(i)) {
          case CellKind.gem:
            _maybeHint(s, 'gem');
          case CellKind.boom:
            _maybeHint(s, 'boom');
          case CellKind.gold:
            _maybeHint(s, 'gold');
          case CellKind.normal:
            break;
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _profile?.removeListener(_applyAudio);
    _audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _audio.startAmbience();
    } else {
      _audio.pauseAmbience();
    }
  }

  /// Pushes the saved sound settings to the audio service (applied immediately).
  void _applyAudio() {
    final d = _profile!.data;
    _audio.apply(
      sound: d.soundOn,
      volume: d.masterVolume,
      ambience: d.ambience,
      voice: d.voiceOn,
    );
  }

  BlockPuzzleGame _ensureGame(Services s) {
    final existing = _game;
    if (existing != null) return existing;
    final game =
        widget.game ??
        BlockPuzzleGame(
          bestScore: s.profile.data.bestScore,
          themeStart: s.profile.data.themeIndex,
        );
    _profile = s.profile..addListener(_applyAudio);
    game.onPlaced = (o) {
      // Remember the rotation so a new game (or a new launch) continues it.
      s.profile.setThemeIndex(game.themeIndex);
      if (!o.gameOver) {
        _praise(o);
        _warnIfCrowded(game);
      }
      if (o.gems > 0) s.profile.addCoins(o.gems); // 1 coin per gem
      if (s.profile.data.vibrationOn && o.linesCleared > 0) {
        HapticFeedback.mediumImpact();
      }
    };
    game.onChanged = () {
      if (!mounted) return;
      _checkHints(s, game);
      setState(() {});
    };
    game.onGameOver = () {
      _gameOvers++;
      if (game.state.score > s.profile.data.bestScore) {
        _audio.voice('better_than_the_best');
      } else {
        _audio.voice('game_over', variants: 2);
      }
      _showGameOver(s);
    };
    _applyAudio();
    _audio.startAmbience();
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
    final tip = s.profile.tipsEnabled && _gameOvers.isEven
        ? s.tips.next()
        : null;
    var tipClosed = false;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => GameOverPanel(
          key: TestIds.gameOverDialog,
          title: 'Game over',
          details: [
            Text(
              'Score ${game.state.score}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            Text('Best ${game.state.bestScore}'),
            if (game.state.canRevive)
              Text(
                'Continues left: ${game.state.revivesRemaining}',
                key: TestIds.gameOverRevivesLeft,
              ),
            if (tip != null && !tipClosed && s.profile.tipsEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TipCard(
                  key: TestIds.tipGameOver,
                  text: tip,
                  onClose: () => setDialog(() => tipClosed = true),
                ),
              ),
          ],
          buttons: [
            if (game.state.canRevive)
              GameOverButton(
                key: TestIds.gameOverRevive,
                kind: GameOverButtonKind.primary,
                size: GameOverButtonSize.large,
                icon: Icons.smart_display,
                label: '$continueLabel · ${game.state.revivesRemaining} left',
                onPressed: () => Navigator.pop(ctx, 'revive'),
              ),
            GameOverButton(
              key: TestIds.gameOverRetry,
              kind: game.state.canRevive
                  ? GameOverButtonKind.secondary
                  : GameOverButtonKind.primary,
              size: game.state.canRevive
                  ? GameOverButtonSize.compact
                  : GameOverButtonSize.large,
              icon: Icons.replay,
              label: 'Play again',
              onPressed: () => Navigator.pop(ctx, 'retry'),
            ),
            GameOverButton(
              key: TestIds.gameOverHome,
              kind: GameOverButtonKind.ghost,
              icon: Icons.home,
              label: 'Home',
              onPressed: () => Navigator.pop(ctx, 'home'),
            ),
            GameOverButton(
              key: TestIds.gameOverShare,
              kind: GameOverButtonKind.ghost,
              size: GameOverButtonSize.compact,
              icon: Icons.share,
              semanticLabel: 'Share',
              onPressed: () async {
                final png = await captureShareCard(
                  ctx,
                  ShareCardData(
                    gameName: s.config.displayName,
                    headline: 'Score',
                    big: '${game.state.score}',
                    best: game.state.bestScore,
                    theme: game.theme,
                  ),
                );
                await s.share.shareScore(score: game.state.score, image: png);
              },
            ),
          ],
        ),
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
      body: ThemeBackground(
        theme: game.theme,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Invisible; the current theme id is its Semantics value (tests, bot).
                  Semantics(
                    key: TestIds.gameTheme,
                    identifier: 'game.theme',
                    value: game.theme.id,
                    child: const SizedBox.shrink(),
                  ),
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
                          textDirection: s.profile.data.leftHanded
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          children: [
                            IconButton.filledTonal(
                              key: TestIds.gameBack,
                              icon: Icon(
                                s.profile.data.leftHanded
                                    ? Icons.chevron_right
                                    : Icons.chevron_left,
                              ),
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
                    rushLeft: game.state.rushLeft,
                    showStreak: s.config.retention.streaks,
                  ),
                  Expanded(
                    child: GameWidget<BlockPuzzleGame>(
                      key: TestIds.gameWidget,
                      game: game,
                    ),
                  ),
                  KeyedSubtree(
                    key: TestIds.gameBanner,
                    child: s.ads.buildBanner(),
                  ),
                ],
              ),
            ),
            if (_hintId != null && s.profile.tipsEnabled)
              Positioned(
                bottom: 70,
                left: 16,
                right: 16,
                child: Center(
                  child: TipCard(
                    key: TestIds.tipHint,
                    text: _hintText ?? '',
                    onClose: _hideHint,
                  ),
                ),
              ),
          ],
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
    required this.rushLeft,
    required this.showStreak,
  });
  final int streak;
  final int combo;
  final int rushLeft;
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
      // Always present: Semantics value = placements left (0 when off).
      Semantics(
        key: TestIds.gameRush,
        identifier: 'game.rush',
        value: '$rushLeft',
        child: rushLeft <= 0
            ? const SizedBox.shrink()
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x33FFC928),
                  border: Border.all(color: const Color(0xFFFFC928)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'GOLD RUSH x2 · $rushLeft',
                  style: const TextStyle(
                    color: Color(0xFFFFE08A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
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
