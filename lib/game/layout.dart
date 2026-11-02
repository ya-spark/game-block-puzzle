import 'dart:math';

/// Screen geometry for the puzzle view, in plain doubles so it is testable without Flutter.
class PuzzleLayout {
  PuzzleLayout(
    this.width,
    this.height, {
    this.gridSize = 8,
    this.traySlots = 3,
  }) {
    final margin = width * 0.04;
    boardTop = min(height * 0.06, 60);
    // Vertical budget in cells: board, gap, piece tray, and the free strip under the
    // pieces. The strip is where thumbs rest to start a drag, so it is never squeezed out:
    // on short screens the whole board shrinks instead.
    const needed = 8 + 0.5 + 3.2 + bottomGapCells;
    cellSize = min(
      (width - margin * 2) / gridSize,
      (height - boardTop - margin) / (needed - 8 + gridSize),
    );
    boardLeft = (width - cellSize * gridSize) / 2;
    final boardBottom = boardTop + cellSize * gridSize;
    // Tray slots share the area under the board.
    trayTop = boardBottom + cellSize * 0.5;
    trayHeight = max(
      cellSize * (3.2 + bottomGapCells),
      height - trayTop - margin,
    );
    slotWidth = cellSize * gridSize / traySlots;
    // Pieces in the tray are drawn smaller than board cells.
    trayCellSize = min(cellSize * 0.62, slotWidth / 5.5);
  }

  /// Free space kept under the tray pieces, in board cells.
  static const double bottomGapCells = 0.7;

  final double width;
  final double height;
  final int gridSize;
  final int traySlots;

  late final double cellSize;
  late final double boardLeft;
  late final double boardTop;
  late final double trayTop;
  late final double trayHeight;
  late final double slotWidth;
  late final double trayCellSize;

  double get boardSizePx => cellSize * gridSize;

  /// Center of a tray slot.
  (double, double) trayCenter(int slot) => (
    boardLeft + slotWidth * (slot + 0.5),
    trayTop + (trayHeight - cellSize * bottomGapCells) / 2,
  );

  /// Which tray slot a point is in, or null.
  int? traySlotAt(double x, double y) {
    if (y < trayTop || y > trayTop + trayHeight) return null;
    final i = ((x - boardLeft) / slotWidth).floor();
    return (i >= 0 && i < traySlots) ? i : null;
  }

  /// Board cell (row, col) under a point, or null when outside the board.
  (int, int)? cellAt(double x, double y) {
    final c = ((x - boardLeft) / cellSize).floor();
    final r = ((y - boardTop) / cellSize).floor();
    if (r < 0 || c < 0 || r >= gridSize || c >= gridSize) return null;
    return (r, c);
  }

  /// Center of a board cell.
  (double, double) cellCenter(int row, int col) =>
      (boardLeft + cellSize * (col + 0.5), boardTop + cellSize * (row + 0.5));

  /// Finger position that makes a piece of [pieceRows]x[pieceCols] snap with its top-left on
  /// board cell [row],[col], for a drag that started on the piece centre. Used by the test bot.
  (double, double) fingerFor(int pieceRows, int pieceCols, int row, int col) =>
      (
        boardLeft + (col + pieceCols / 2) * cellSize,
        boardTop + (row + pieceRows / 2) * cellSize,
      );

  /// Snaps a dragged piece's top-left (screen px) to the nearest board cell.
  (int, int) snapTopLeft(double x, double y) => (
    ((y - boardTop) / cellSize).round(),
    ((x - boardLeft) / cellSize).round(),
  );
}
