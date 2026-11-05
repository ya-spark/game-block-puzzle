import 'dart:math';

import 'board.dart';
import 'piece.dart';

/// Deals pieces. Every dealt piece fits the board on its own whenever any piece does, so a
/// game never ends by a bad deal alone. Seedable for tests.
class PieceGenerator {
  PieceGenerator([Random? random]) : _rng = random ?? Random();

  final Random _rng;

  /// The random source (also used to prepare the start board of a new game).
  Random get random => _rng;

  /// Soft preference for 4-cell pieces: weight 3 against 1 for every other shape.
  static const int fourCellWeight = 3;

  /// Lines cleared below which every deal is kind (all three pieces playable one after
  /// another, and one of them clears a line).
  static const int kindUntilLines = 20;

  /// Lines cleared from which the deal is plain (each piece only has to fit on its own).
  /// Between [kindUntilLines] and this, half of the deals (random) are kind.
  static const int plainFromLines = 60;

  /// Attempts at a kind deal before the guarantee is relaxed.
  static const int kindAttempts = 50;

  /// While at most this share of the board is filled there is plenty of room, so pieces
  /// smaller than [minRoomySize] cells are not dealt.
  static const double roomyFilledShare = 0.5;
  static const int minRoomySize = 3;

  Piece _pickWeighted(List<({Piece piece, int weight})> list) {
    final total = list.fold<int>(0, (s, w) => s + w.weight);
    var roll = _rng.nextInt(total);
    for (final w in list) {
      roll -= w.weight;
      if (roll < 0) return w.piece;
    }
    return list.last.piece;
  }

  static int _weightOf(Piece p) => p.size == 4 ? fourCellWeight : 1;

  /// Three pieces for [board]. Every piece fits the board on its own whenever any piece does.
  ///
  /// Difficulty rises with [linesCleared] (this game's total) through how kind the deal is:
  /// below [kindUntilLines] the three pieces can all be played one after another and at least
  /// one clears a line (tried [kindAttempts] times, then relaxed); up to [plainFromLines]
  /// half of the deals are kind; after that the deal is plain.
  List<Piece> dealTray(Board board, {int count = 3, int linesCleared = 0}) {
    final roomy =
        board.filledCount <= board.size * board.size * roomyFilledShare;
    final fitting = [
      for (final w in PieceCatalog.weighted)
        if ((!roomy || w.piece.size >= minRoomySize) &&
            board.canPlaceAnywhere(w.piece))
          w,
    ];
    if (fitting.isNotEmpty) {
      final pool = [
        for (final w in fitting) (piece: w.piece, weight: _weightOf(w.piece)),
      ];
      List<Piece> draw() => [
        for (var i = 0; i < count; i++) _pickWeighted(pool),
      ];
      final kind =
          linesCleared < kindUntilLines ||
          (linesCleared < plainFromLines && _rng.nextBool());
      if (kind) {
        for (var attempt = 0; attempt < kindAttempts; attempt++) {
          final tray = draw();
          if (_clearsALine(board, tray) && _playableInSequence(board, tray)) {
            return tray;
          }
        }
        for (var attempt = 0; attempt < kindAttempts; attempt++) {
          final tray = draw();
          if (_playableInSequence(board, tray)) return tray;
        }
      }
      return draw();
    }
    // Board nearly full: fall back to the smallest piece so the player is not dealt a dead hand.
    return [
      for (var i = 0; i < count; i++)
        i == 0 && board.canPlaceAnywhere(PieceCatalog.dot)
            ? PieceCatalog.dot
            : _pickWeighted(PieceCatalog.weighted),
    ];
  }

  /// True when some piece of [pieces] clears a line at some position on [board].
  bool _clearsALine(Board board, List<Piece> pieces) {
    for (final piece in pieces) {
      for (var r = 0; r < board.size; r++) {
        for (var c = 0; c < board.size; c++) {
          if (board.canPlace(piece, r, c) &&
              board.place(piece, r, c).linesCleared > 0) {
            return true;
          }
        }
      }
    }
    return false;
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
