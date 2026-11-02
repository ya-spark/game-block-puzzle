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

  /// Score below which a dealt tray can also be played out completely, one piece after another.
  static const int easyUntil = 1000;

  /// Score at which the shape bias towards big pieces is at its maximum.
  static const int hardAt = 5000;

  /// Three pieces for [board]. Every piece fits the board on its own whenever any piece does,
  /// at every score: a dead piece is only dealt when the board is almost full.
  ///
  /// Difficulty grows with [score] through the shapes: small pieces are favoured at the start,
  /// big awkward ones later. Below [easyUntil] the three pieces can also all be placed one
  /// after another (tried 50 times, then relaxed).
  List<Piece> dealTray(Board board, {int count = 3, int score = 0}) {
    final fitting = [
      for (final w in PieceCatalog.weighted)
        if (board.canPlaceAnywhere(w.piece)) w,
    ];
    if (fitting.isNotEmpty) {
      // size^bias: -0.5 at score 0 (small pieces more likely) up to +2 at [hardAt].
      final bias = -0.5 + 2.5 * min(1.0, score / hardAt);
      final pool = [
        for (final w in fitting)
          (
            piece: w.piece,
            weight: max(1, (w.weight * pow(w.piece.size, bias)).round()),
          ),
      ];
      if (score < easyUntil) {
        for (var attempt = 0; attempt < 50; attempt++) {
          final tray = [for (var i = 0; i < count; i++) _pickWeighted(pool)];
          if (_playableInSequence(board, tray)) return tray;
        }
      }
      return [for (var i = 0; i < count; i++) _pickWeighted(pool)];
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
