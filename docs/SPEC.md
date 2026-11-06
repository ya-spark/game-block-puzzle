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
- Score per placement: piece size (cells), plus `round(10 * lines^2 * combo * stage^stageExponent)` when lines clear.
- Combo = consecutive placements that cleared lines, `min(streak + 1, maxCombo)` with `maxCombo = 8`; a placement with no clear resets it.
- `stage = min(1 + linesClearedTotal ~/ 5, maxStage)` with `maxStage = 13` (`GameState.linesPerStage = 5`) and `stageExponent = 1.25` (`GameState.stageExponent`); stage is 1 until 5 lines are cleared. Stage uses the lines cleared before the placement. Stage is only the scoring multiplier; nothing else is tied to it.
- Measured (seeded greedy bot, `test/game/start_and_score_test.dart`, 20 seeds, games reaching 60 lines): a 60-line game scores about 11,068 on average with `maxCombo = 8`, `maxStage = 13`, `stageExponent = 1.25` (1.0 gave ~6,850, 1.2 gave ~10,029). The test asserts the 10,000-12,000 band.
- Start of a game (not after Continue): a prepared board 70% full (45 of 64 cells, plus or minus 2) with no complete row or column (`lib/game/rules/start_board.dart`, from the game seed). The first tray is three 4-cell pieces, at least two of them Z or J (any rotation or mirror the catalogue defines), the third any 4-cell piece, and no piece (same shape and rotation) more than twice; only the first tray is drawn this way, later trays are unchanged. Each of the three is placeable on the start board and each clears 2 or more lines when placed (1 line is the fallback), in any order, independent of each other (all three use rows, or all use columns).
- Game over when none of the remaining tray pieces fits anywhere.
- Continue (code name "revive"): up to 3 per run, paid by a rewarded ad or by `continueCoinCost = 50` coins (both count against the same limit); empties the two fullest rows, deals a fresh tray, resets the combo.
- Best score is saved locally (and to the Play Games leaderboard when enabled).

## 4. Content
Piece catalogue in `lib/game/rules/piece.dart` (weighted). Dealing (`piece_generator.dart`):
- Catalogue (each with its distinct rotations; weight = base weight per orientation, 4-cell shapes then get the `fourCellWeight` preference): dot 2; bars 2/3/4/5 = 4/4/2/1; squares 2/3 = 4/1; corners 3/5 = 4/1; L 3, J 4 (mirror of L), T 3, S 2, Z 3 (mirror of S); plus (5 cells) 1; diagonals of 2 and 3 cells (cells touch only at corners, not edge-connected) 1 each. The ghost preview and drag snap work per cell, so diagonal pieces behave like any other; special cells can sit on any cell of a piece with at least 2 cells, diagonals included.- Every dealt piece fits the board whenever any piece fits; a dead piece is only dealt when the board is almost full.
- One fixed piece preference for the whole game: 4-cell pieces have weight `fourCellWeight = 3`, every other shape 1. It is soft: a 4-cell piece that fits nowhere is not dealt.
- Difficulty rises through how kind the deal is, by lines cleared in the game: below `kindUntilLines = 20` every deal is kind (all three pieces can be played one after another and at least one clears a line; 50 tries, then the clear-a-line part is dropped, then 50 more tries, then plain). From 20 to `plainFromLines = 60` half of the deals (random) are kind. From 60 the deal is plain (each piece still fits on its own).
- While the board is at most half full, pieces smaller than 3 cells are not dealt.

**Special blocks and Gold Rush** (code: `CellKind` in `piece.dart`, kinds stored next to the colour in `Board`; dealing in `piece_generator.dart`; effects in `Board.place` and `GameState.place`)
- Cell kinds: `normal`, `gem`, `boom` ("Boom block"), `gold` ("golden block"). A kind travels with the piece cell onto the board and is cleared with the cell.
- Dealing: every `specialEveryNthTray = 4`th dealt tray (the prepared start tray is tray 1) has exactly one special cell, on a random piece of at least 2 cells. Kind weights: gem 3, boom 2, gold 1, from the game's seeded generator. The start board and the first tray never have special cells. Every dealt piece still fits and the difficulty rules are unchanged.
- Effects resolve when a line containing the special cell clears:
  - Gem: `gemPoints = 50` added to the line base before the combo and stage multipliers (`(10 * lines^2 + 50 * gems) * combo * stage^1.25`), plus 1 coin (same coin balance as shop and daily reward).
  - Boom block: after the line clear, every filled cell in the 3x3 area around it is emptied (clipped at the edges, no gravity, no chain reaction). Each extra emptied cell scores `blastCellPoints = 5` (flat). Gems emptied by a blast still pay.
  - Golden block: starts Gold Rush.
- Gold Rush: for the next `rushPlacements = 5` placements all points of the placement (cells, line bonus, gem, blast) are doubled (`rushMultiplier = 2`), after the combo and stage multipliers. The placement that clears the golden block is not itself doubled. Another golden block during a rush adds `rushExtend = 5` placements, capped at `rushCap = 15`. A new game starts with no rush.
- Look: each kind is an overlay on top of the current skin in every theme (gem = bright faceted gem, Boom block = friendly star-burst, golden = gold sheen with a star). The blast is a 0.5 s cartoon star burst on each emptied cell (grows and fades, no flashing). During a rush the board has a soft golden shimmer (slow sway, no flashing) and a chip "GOLD RUSH x2 · N" shows the placements left. Test ID `game.rush`: Semantics value = placements left (0 when off).
- The 60-line simulation band above measures a game without special blocks (the test deals none, `PieceGenerator(random, 0)`).

## 5. Retention
Daily reward cycle, streaks (+ freeze), daily challenges, achievements: all ON (`retention` in `app.config.yaml`).

## 6. Monetization
Banner on the game screen; interstitials paced by `ads` in `app.config.yaml` (min 90 s apart, every 2nd game over, max 6 per session, none in the first 60 s); rewarded ad for Continue. IAP in `products.yaml`: `remove_ads_all` (non-consumable, "Remove Ads", removes **all** ads), `coins_500` "Coin Pack", `coins_1500` "Big Coin Pack", `coins_4000` "Coin Chest" (consumable). The retired id `remove_ads` is never sold; a saved `remove_ads` entitlement or restore still counts as owned.
- **Remove Ads removes all ads**: no banner, no interstitial and no rewarded ad; Continue is granted at once (up to 3 per run).
- Shop order: Remove Ads, then coin packs in ascending size; products the store does not return stay hidden, or "Store unavailable". Coin pack text says what coins are for ("Use coins to continue after a game over"); wording never pressures children.
- Coins are drawn with the code-made `CoinIcon` (gold coin, darker rim, inner ring, shine, letters MC; Semantics label "coins"); `Icons.monetization_on` is not used.
- **Parent gate** (`ParentGate` dialog, "Ask a grown-up") before every real-money purchase (not Restore, not spending coins): typed answer to a multiplication with factors 6 to 9, new numbers after each wrong answer; 3 wrong in a row close the dialog and lock purchases for 60 s. Test IDs `gate.dialog`, `gate.answer`, `gate.submit`, `gate.cancel`.
- Ads are child-directed with max content rating G. Release AdMob IDs are in `app.config.yaml`; debug uses Google's test IDs.

## 7. Screens
Home, game, game over (overlay), daily reward, challenges and achievements, shop, settings. Every interactive widget has a key in `lib/ui/test_ids.dart`. Screens use named routes so each is deep-linkable.

**Home scene and background** (`lib/ui/home_hero.dart`, `lib/ui/theme_background.dart`)
- Above the title, a code-drawn band 160 dp tall (no assets, no gestures, test ID `home.hero`) replaces the emoji row: two lanes of 4-cell catalogue pieces (5 per lane, 10 objects) drift, one right to left (22 u/s) and one left to right (15 u/s), with a gentle bob. Pieces use the current theme's block skin (theme at the saved `themeIndex`) and restyle when it changes. About every 6 s a lane completes with a 1 s sparkle (alternating lanes).
- One `CustomPainter`, one ticker; it stops while the home route is covered and while the app is in the background.
- The home background is the current theme's background at the saved `themeIndex`, with the same 1.5 s cross-fade when it changes. The title is white with a dark shadow. Other menu screens keep the plain gradient.

**Sharing** (`lib/core/share/`, `lib/ui/share_card.dart`)
- `ShareService` (`shareScore`, `shareAchievement`, `shareApp`); `SystemShareService` opens the Android share sheet through `share_plus`, imported only in that file and pinned to the exact version `13.3.1` (same as game-wingy; an exact pin so a share plugin update never changes behaviour or permissions unreviewed). `FakeShareService` records the texts in tests. No Facebook or Instagram SDK. The app sends nothing itself; the player starts sharing and picks the target app.
- Share card: a widget drawn in code and rendered to a PNG through a `RepaintBoundary` (360x450 at 3x): game name, big score (or achievement title), best score, and the current look (the current theme's background and one block of each colour in its skin). No player name, no id, no store text.
- Texts (the game name always appears; the link, when there is one, follows on a new line): score `This is my high score in {game}: {score}. Can you beat it?`; achievement `I unlocked "{title}" in {game}! Can you beat it?`; Settings "Share app" `Try {game}! Can you beat my score?` with the same link.
- Config in `app.config.yaml` (replaces `share.app_link_enabled`): `share: link_mode: internal_test | store | off` and `internal_test_url`. `internal_test` (default) uses `internal_test_url` (`https://play.google.com/apps/internaltest/4699568684837272672`); `store` uses `https://play.google.com/store/apps/details?id=<package_name>`; `off` adds no link and hides "Share app". `internal_test` with an empty URL behaves like `off`. The owner switches to `store` when the game is public. Loader: `AppConfig.shareLink` (null = no link).
- Buttons: game over, small ghost Share icon button at the top left of the panel (`game.over.share`); each unlocked achievement has a share icon (`achievement.share.<id>`); Settings "Share app" (`settings.shareApp`) is visible unless the mode is `off` (no link).

**Tips** (`lib/game/tips.dart`, `lib/core/tips/tip_service.dart`, `lib/ui/tip_dialog.dart`)
- 15 tips (at most 80 characters, unique, none mention other games). `TipService` (pure Dart) deals them from a shuffled bag so a tip never repeats back to back, and gives a tip of the day from the day index.
- The only place a tip appears is **one dialog on the home page, once per day**, opened when the home page is first shown that day (`tip.home` is the dialog; saved `tipHomeDay`, set when it opens). It shows the tip of the day, a "Don't show tips again" checkbox (`tip.dontShow`) and Close (`tip.close`). Close alone just closes it; checkbox + Close turns tips off everywhere. It is not shown again the same day, and never when tips are off. The home layout holds no tip card, so the buttons are not pushed down.
- Never a tip in a game or on the game over screen: no game-over tip, no pause tip (no pause screen), no first-time special-block hints.
- Settings "Show tips" switch (`settings.tips`, on by default) is the same saved profile value (`tipsOff`).
- Test fakes turn tips off by default (`buildFakeServices(tips: true)` turns them on).

## 8. Art and audio
Dark teal theme (seed `#2EC4B6`), rounded glossy blocks, kid-friendly colourful menu pages. Narrator voice clips (`assets/voice/`) on clears, combos, new best and game over. Every asset is listed in `assets/LICENSES.md`.

**Sound (exact values)**
- Voice priorities. High: `game_over`, `better_than_the_best`. Normal: `awesome`, `combo`, `excellent`, `fantastic`, `great`, `incredible`, `nice`, `unbelievable`, `unstoppable`, `well_done`, `you_did_it`. Low: `get_ready`, `go`, `careful`.
- A playing clip is never stopped by a new line. A high line waits for the clip and then plays (the newest waiting high line wins). A normal or low line that arrives while a clip plays is played only if the clip ends within 1 s, otherwise dropped.
- Background sound (`assets/ambience/`): loops at volume 0.25 (voice 1.0), 0.1 while a voice clip plays, both scaled by Master volume. Starts when the game screen opens, pauses when the app goes to the background, stops when leaving the game screen, keeps playing under game over. Voice and ambience use `mixWithOthers` (no Android audio focus).
- Settings: **Sound** switch (master mute, on top), **Master volume** slider 0-100 % (default 100 %, test ID `settings.volume`), **Background sound** picker Off / Morning birds (default) / Before sunrise / Heartbeat (`settings.ambience`), **Voice** switch, default on (`settings.voice`). No Effects switch (no effect sounds). All saved in the profile and applied immediately.
- **Hand** choice Right (default) / Left (`settings.hand`), saved in the profile. There is no pause button or side buttons during play; Left only mirrors the back button to the right side (header row reversed). Board, tray, score and game over screen are unchanged.

**Themes** (code: `lib/game/themes/block_theme.dart`, `lib/game/rules/theme_rotation.dart`)
- One theme = background + block skin + 8 colours + empty-cell and grid-line colours, all drawn in code (no assets). The board stores only a colour index per cell; the pure-Dart rules do not know themes. Cell pictures are cached per (theme, colour).

| id | Skin | Background |
|----|------|------------|
| `gems` | glossy gems (the original look) | midnight-teal gradient (the original) |
| `cakes` | cream-iced biscuit cells with sprinkles | chocolate-brown with a soft wafer pattern |
| `wood` | warm wooden tiles with grain lines | forest-green gradient |
| `candy` | glossy gumdrop sweets | pastel pink-sky gradient |
| `ocean` | pearly shell tiles | deep-blue gradient with soft bubbles |
| `space` | round planet tiles with rings and craters | dark purple starfield |

- Colours: 8 per theme (`Piece.colorCount = 8`). Each dealt piece gets a random colour index from the game's seeded generator (not a fixed colour per shape). Every colour index also has its own small mark (dot, ring, bars, diamond, triangle, cross, two dots), so colours stay distinct for colour-blind players.
- Block tile and contrast (look): in every skin except Gems (already a filled tile, unchanged) each cell is first drawn on a base tile (`paintBaseTile` in `lib/game/themes/block_theme.dart`): rounded square filling the whole cell (0.5/64 gap per side = 1 px grid gap, corner radius 16 % of the cell, at most 18 %), filled with the dark shade (lightness -0.3) of the cell's own colour, with a 1.5/64 outline at 45 % black (`0x73000000`) and a 1/64 inner edge on the top and left at 35 % white (`0x59FFFFFF`). The motif (gumdrop, shell, planet, icing, wood face) is drawn on top and is at least 80 % of the tile width (planet disc 83 %). Dragged piece, ghost and tray use the same skin. Every palette colour has a WCAG contrast of at least 3:1 against the theme's empty cell colour and, in Cakes, Candy, Ocean and Space, against `backgroundTop`. Gems and Wood have bright mid-tone backgrounds no on-theme colour can reach 3:1 against, so only the empty cell check applies there. Colour-blind marks stay. Adjusted colours: Candy darkened (raspberry `#C4155A`, orange `#A84F00`, lemon `#7A5B00`, lime `#106A36`, blue `#1565B0`, grape `#6D32C4`, cherry `#BE2424`, mint `#0B6B68`); Cakes chocolate `#D2956A` and cherry `#FF7A8A`; Wood walnut `#B07B40`, cherry wood `#C4724A`, dark `#A07C5A`; Ocean lilac `#D6CAF8` and blue `#A3CEFF`. Test: `test/ui/block_contrast_test.dart`.
- Change rule: no picker, no setting. The theme changes every time 10 more lines are cleared: `ThemeRotation.themeEveryLines = 10`, index `(start + linesClearedTotal ~/ 10) % 6`, in table order, wrapping. This is independent of the scoring stage (every 5 lines).
- The rotation index is saved in the profile (`themeIndex`); a new game starts from the index the last game reached. A new install starts at `gems`.
- Transition: a 1.5 s cross-fade (`PuzzleView.fadeSeconds`) of the background and all cells; no flashing, input is never blocked. Cells on the board, the tray and the ghost preview are redrawn in the new theme at once (they keep their colour index).
- HUD text colour: each theme has `hudText` (and `hudSubtle` for the "SCORE" label) and `backgroundTop` (top colour of its background gradient). The game screen's HUD text drawn on the background (score digits, SCORE label, streak line, combo, GOLD RUSH chip text, best-score number) uses the current theme's colours; text inside dark pills/buttons is unchanged. Dark themes keep white (`hudSubtle` teal-grey `0xFF7FB7BD`); Candy uses dark plum `0xFF5B2A55` / `0xFF6E3A68`. The colours blend during the 1.5 s cross-fade. Rule: contrast of `hudText` and `hudSubtle` against `backgroundTop` is at least 4.5 (WCAG), checked by a test for every theme. Test ID `game.score_label` is the SCORE label.
- Test hook: the invisible `game.theme` test ID carries the current theme id as its Semantics value.

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
- The game ends when no remaining piece fits; a Continue is offered up to 3 times per run.

Game over screen layout:
- Player-facing wording is "Continue" (code and test IDs still say "revive"); the label is the constant `continueLabel` in `lib/ui/game_screen.dart`. Text: `Continue · N left`, details line `Continues left: N`.
- Order top to bottom inside the panel: small ghost Share icon button at the top left; title, score, best score; **Play again** and **Home** side by side; **Continue** last, at the bottom: gold primary, font 22, padding 28x16, hidden when no continue is left.
- Play again: secondary style (regular, 16) while Continue is offered; when Continue is unavailable it takes the large gold style (22, 28x16).
- Continue button: with Remove Ads owned it continues at once (no ad, no coins); with fewer than 50 coins it goes straight to the rewarded ad; with 50 coins or more it opens a small choice "Watch an ad (free)" (`game.over.continue.ad`) and "Use 50 coins" with the coin icon (`game.over.continue.coins`). Spending coins needs no parent gate.
- Test IDs: `game.over.revive` (Continue), `game.over.retry` (Play again), `game.over.home`, `game.over.share`, `game.over.dialog`, plus `game.over.panel` and `game.over.view`.
- No tip is ever shown on the game over screen.
- A drag follows the finger with the offsets in section 13 and the ghost preview shows where it will snap.
- Debug builds use test ad IDs; release builds do not (CI `ad_safety_check.sh`).

## 13. Behaviour and feel (owner decisions, exact values)
Code: `lib/game/layout.dart` and `lib/game/flame/block_puzzle_game.dart`. `cell` = board cell size.

**Home screen fits without scrolling** (owner, 2026-11-06). Code: `lib/ui/home_screen.dart`, `homeLayout` and `HomeGrid` in `lib/ui/widgets.dart`.
- At normal text size the whole Home fits with no scrolling on a 360 x 640 dp window, and on taller ones.
- Order: hero, title, stat chips, **Play** (290 x 76 dp), then a **2 x 2 grid** (290 dp wide, 10 dp gaps) of Daily reward, Challenges, Shop, Settings (compact `MenuButton`, 64 dp tall, icon beside a short label, badges unchanged). A button hidden by `retention` leaves no gap: the grid reflows, and a lone last button spans the row.
- `HomeHero` is 160 dp when there is room and shrinks down to 96 dp when the space is short. Spacing between groups is 14 dp, and 10 dp when space is short (`homeLayout`).
- A `SingleChildScrollView` stays only as a safety net (very small windows, text scale above 1.3).
- Test IDs are unchanged. Tests: `test/ui/home_fit_test.dart`.

**Drag and drop**
- Pressing anywhere from 0.25 cell above the tray down to the bottom of the screen, across the full width, picks the tray slot under the press. Thumbs press below the piece, not on it (`traySlotAt`).
- Vertical offset: the dragged piece's bottom edge floats **2.5 cells** above the finger, wherever the press landed (`dragLift = cell * 2.5`).
- Horizontal offset: the press keeps its horizontal distance from the piece centre for the whole drag, so a press left of the piece keeps the piece to the right of the finger and it never jumps (`_grabX`).
- Release snaps to the nearest **legal** placement, not the nearest cell (`snapToLegalCell` in `lib/game/rules/snap.dart`, pure Dart). With the piece's top-left in unrounded cell units `(fy, fx)` (`PuzzleLayout.topLeftInCells`), candidates are all `(r, c)` with Euclidean distance `<= snapTolerance = 1.0` cell for which `Board.canPlace` is true. The nearest wins; ties go to the candidate that clears more lines, then the smaller row, then the smaller column.
- No legal candidate within 1.0 cell: the drop is a cancel and the piece returns to the tray.
- The ghost preview and the drop call the same function, so the translucent ghost always shows exactly where the piece will land, including on near-misses.

**Layout** (portrait)
- Side margin 4% of width; top padding `min(6% of height, 60)`.
- The board sits **1.5 cells below the vertical centre** (`boardDropCells`) so the top rows stay in thumb reach, but never so low that the tray leaves the screen.
- Tray under the board with a 0.5 cell gap; tray pieces are drawn at `min(0.62 cell, slotWidth / 5.5)`; three slots share the board width.
- A free strip of **0.7 cell** (`bottomGapCells`) stays under the tray for thumbs. On short screens the whole board shrinks instead of squeezing it.

**Game over**
- Overlay pinned to the top of the screen, no dimming of the board. All content sits in a panel (`game.over.panel`): rounded card (radius 24), solid dark surface `#1E1535` at about 90 % opacity (`0xE6`), thin light border (white at 33 %), soft shadow. Text and buttons keep at least 4.5:1 contrast against the panel (white on the dark surface; secondary buttons use `#7B3FD6` to `#B02F78` with white text; gold buttons use dark brown text).
- **Eases in, never abrupt (about 1 s):** (a) the moment the run ends, input is locked, the board freezes and the game over voice line starts; (b) 0.3 s hold while the scene dims to about 40 % black; (c) the panel fades 0 to 100 % and slides up 24 px over 0.7 s (ease-out cubic); (d) the buttons (and the eye button) are tappable only once the panel has settled, at 1 s. `game.over.panel` exists from the first frame of (c). With reduce motion (system animations off) there is a single 0.2 s fade, no hold, no slide. The score shown never changes during the transition.
- **View board:** a small eye button (`game.over.view`) at the top right of the panel. Tapping it fades the panel out in 0.2 s so the whole final board is visible; a tap anywhere, or the eye button (which stays visible), brings the panel back. The board stays visible and still, and nothing else changes while the panel is hidden (scores and rewards are already final).

**HUD text legibility:** on the Gems and Ocean themes the HUD texts (score, SCORE label, streak, combo, gold rush, best) carry a soft dark text shadow (2 px blur, 40 % black, 1 px down) so contrast stays at least 4.5:1 without changing the layout. Other themes have no shadow.

**Piece dealing feel**
- See section 4 (steady 4-cell preference, kindness falls with lines cleared, no tiny pieces on a roomy board).

**Rescaled goals (~3x, after the faster stage step):** achievements `score_1000` "Fifteen Thousand" (15,000) and `score_5000` "High Roller" (75,000), ids kept; daily "Score N points" targets 5,000 / 10,000 / 15,000. Saved best scores are not migrated.
