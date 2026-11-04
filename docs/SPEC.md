# Game spec

Status: BACKFILLED on 2026-11-05 from the code and commit history; the game predates the spec stage. This file is the contract for the game and the single source of truth: it lives only here, there is no copy in game-factory. **Whenever the owner gives a behaviour instruction (feel, layout, offsets, rules), change this file in the same commit as the code.** Section 13 holds the exact values.

## 1. Pitch
Block Puzzle is a one-handed 8x8 block-drop puzzle for casual and young players: drag three pieces from a tray onto the board, fill rows and columns to clear them, chase a high score. Kid-friendly (child-directed ads, rating G).

## 2. Core loop
Second to second: drag a piece to the board, see a ghost preview, release to place. Minute to minute: clear lines, build combos, a new tray of three is dealt once all three are used. Session to session: beat the best score, claim the daily reward, daily challenges and achievements.

## 3. Rules and scoring
Pure Dart in `lib/game/rules/`.
- Board 8x8; a placed piece must fit entirely on empty cells. No rotation.
- A full row or column clears (rows and columns can clear together).
- Score per placement: piece size (cells), plus `10 * lines^2 * multiplier` when lines clear.
- Combo multiplier = consecutive placements that cleared lines, `min(streak + 1, 5)`; a placement with no clear resets it.
- Game over when none of the remaining tray pieces fits anywhere.
- Revive: up to 3 per run via a rewarded ad; empties the two fullest rows, deals a fresh tray, resets the combo.
- Best score is saved locally (and to the Play Games leaderboard when enabled).

## 4. Content
Piece catalogue in `lib/game/rules/piece.dart` (weighted). Dealing (`piece_generator.dart`):
- Every dealt piece fits the board whenever any piece fits; a dead piece is only dealt when the board is almost full.
- Difficulty comes from shape size: small pieces are favoured at the start, big ones later; the bias is full at score 500000 (`hardAt`).
- Below score 50000 (`easyUntil`) the three pieces can also all be placed one after another.
- While the board is at most half full, pieces smaller than 3 cells are not dealt.

## 5. Retention
Daily reward cycle, streaks (+ freeze), daily challenges, achievements: all ON (`retention` in `app.config.yaml`).

## 6. Monetization
Banner on the game screen; interstitials paced by `ads` in `app.config.yaml` (min 90 s apart, every 2nd game over, max 6 per session, none in the first 60 s); rewarded ad for revive. IAP in `products.yaml` (remove ads, coin pack). Ads are child-directed with max content rating G. Release AdMob IDs are in `app.config.yaml`; debug uses Google's test IDs.

## 7. Screens
Home, game, game over (overlay), daily reward, challenges and achievements, shop, settings. Every interactive widget has a key in `lib/ui/test_ids.dart`. Screens use named routes so each is deep-linkable.

## 8. Art and audio
Dark teal theme (seed `#2EC4B6`), rounded glossy blocks, kid-friendly colourful menu pages. Narrator voice clips (`assets/voice/`) on clears, combos, new best and game over. Every asset is listed in `assets/LICENSES.md`.

## 9. Play Games
Sign-in, high-score leaderboard and cloud save, off until `play_games.enabled` in `app.config.yaml`.

## 10. Store listing
See `store/google-play/` (listing text, privacy policy, data safety).

## 11. Out of scope
Backend, Firebase, multiplayer, piece rotation, iOS and web builds.

## 12. Acceptance criteria
- Placing a piece on empty cells updates the board and score; an illegal placement is rejected.
- Filling a row or column clears it and awards the line bonus with the combo multiplier.
- A dealt tray always contains a piece that fits while any move exists.
- The game ends when no remaining piece fits; a revive is offered up to 3 times per run.
- A drag follows the finger with the offsets in section 13 and the ghost preview shows where it will snap.
- Debug builds use test ad IDs; release builds do not (CI `ad_safety_check.sh`).

## 13. Behaviour and feel (owner decisions, exact values)
Code: `lib/game/layout.dart` and `lib/game/flame/block_puzzle_game.dart`. `cell` = board cell size.

**Drag and drop**
- Pressing anywhere from 0.25 cell above the tray down to the bottom of the screen, across the full width, picks the tray slot under the press. Thumbs press below the piece, not on it (`traySlotAt`).
- Vertical offset: the dragged piece's bottom edge floats **2.5 cells** above the finger, wherever the press landed (`dragLift = cell * 2.5`).
- Horizontal offset: the press keeps its horizontal distance from the piece centre for the whole drag, so a press left of the piece keeps the piece to the right of the finger and it never jumps (`_grabX`).
- Release snaps the piece's top-left to the nearest board cell (`snapTopLeft`, rounding). A translucent ghost of the piece shows the snap cell when the placement is legal.
- An illegal drop returns the piece to the tray.

**Layout** (portrait)
- Side margin 4% of width; top padding `min(6% of height, 60)`.
- The board sits **1.5 cells below the vertical centre** (`boardDropCells`) so the top rows stay in thumb reach, but never so low that the tray leaves the screen.
- Tray under the board with a 0.5 cell gap; tray pieces are drawn at `min(0.62 cell, slotWidth / 5.5)`; three slots share the board width.
- A free strip of **0.7 cell** (`bottomGapCells`) stays under the tray for thumbs. On short screens the whole board shrinks instead of squeezing it.

**Game over**
- Overlay pinned to the top of the screen, no card, no dimming: outlined white text and glossy pill buttons, so the board stays fully visible.

**Piece dealing feel**
- See section 4 (small pieces first, big later, no tiny pieces on a roomy board).
