import 'dart:math';

import 'board.dart';
import 'piece.dart';

/// Deals pieces. Guarantees every dealt tray has at least one piece that fits when any move
/// is still possible, so a game never ends by a bad deal alone. Seedable for tests.
class PieceGenerator {
  PieceGenerator([Random? random]) : _rng = random ?? Random();

  final Random _rng;

  Piece _pickWeighted([List<({Piece piece, int weight})>? from]) {
    final list = from ?? PieceCatalog.weighted;
    final total = list.fold<int>(0, (s, w) => s + w.weight);
    var roll = _rng.nextInt(total);
    for (final w in list) {
      roll -= w.weight;
      if (roll < 0) return w.piece;
    }
    return list.last.piece;
  }

  /// Score below which every dealt tray can be played out completely.
  static const int easyUntil = 1000;

  /// Score below which every dealt piece fits the board on its own.
  static const int mediumUntil = 3000;

  /// Three pieces for [board]. Difficulty grows with [score]:
  /// - below [easyUntil]: all pieces can be placed one after another (some order, no dead piece);
  /// - below [mediumUntil]: every piece fits the board on its own, but not necessarily all together;
  /// - above: at least one piece fits, so the player can be forced to play around a dead piece.
  /// Each tier falls back to the next easier one if no such tray turns up in 50 tries.
  List<Piece> dealTray(Board board, {int count = 3, int score = 0}) {
    // Pieces that fit the board on their own, so the stricter tiers draw from them directly
    // instead of hoping three random pieces all fit a crowded board.
    final fitting = [
      for (final w in PieceCatalog.weighted)
        if (board.canPlaceAnywhere(w.piece)) w,
    ];
    final tiers =
        <(List<({Piece piece, int weight})>?, bool Function(List<Piece>))>[
          if (score < easyUntil && fitting.isNotEmpty)
            (fitting, (t) => _playableInSequence(board, t)),
          if (score < mediumUntil && fitting.isNotEmpty) (fitting, (_) => true),
          (null, (t) => t.any(board.canPlaceAnywhere)),
        ];
    for (final (pool, accept) in tiers) {
      for (var attempt = 0; attempt < 50; attempt++) {
        final tray = [for (var i = 0; i < count; i++) _pickWeighted(pool)];
        if (accept(tray)) return tray;
      }
    }
    // Board nearly full: fall back to the smallest piece so the player is not dealt a dead hand.
    return [
      for (var i = 0; i < count; i++)
        i == 0 && board.canPlaceAnywhere(PieceCatalog.dot)
            ? PieceCatalog.dot
            : _pickWeighted(),
    ];
  }

  /// True when all of [pieces] can be placed one after another in some order, counting the
  /// lines cleared along the way.
  bool _playableInSequence(Board board, List<Piece> pieces) {
    if (pieces.isEmpty) return true;
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      final rest = [...pieces.sublist(0, i), ...pieces.sublist(i + 1)];
      for (var r = 0; r < board.size; r++) {
        for (var c = 0; c < board.size; c++) {
          if (!board.canPlace(piece, r, c)) continue;
          if (_playableInSequence(board.place(piece, r, c).board, rest)) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
