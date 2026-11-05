# Asset licenses

Every file under `assets/` (other than this file) MUST be listed here by its relative path with
its source and license. `scripts/check_asset_licenses.sh` fails CI otherwise.

| File | Source | License | Notes |
|------|--------|---------|-------|
| assets/voice/awesome.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/better_than_the_best.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/careful.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/combo.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/excellent.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/fantastic.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/game_over.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/game_over_02.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/get_ready.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/go.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/great.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/incredible.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/nice.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/unbelievable.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/unstoppable.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/well_done.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/well_done_02.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/voice/you_did_it.mp3 | AI-generated narration (voice "david") | project-owned (confirm TTS provider's commercial terms) | own-made, ya-spark |
| assets/ambience/morning_birds.mp3 | Pixabay Sound Effects (pixabay.com/sound-effects), author nickype, Pixabay file id 146832; converted to mono 64 kbps MP3 with a crossfaded loop point | Pixabay Content License (royalty-free, commercial use allowed; confirmed by owner) | not wired into the game yet; page URL not recorded |

Format for an asset row: `| assets/sfx/pop.ogg | https://example.org/pop | CC0-1.0 | by Jane Doe |`

## App icon

The launcher icon (`android/app/src/main/res/mipmap-*/ic_launcher*.png`) and the Play Store icon
(`store/google-play/icon_512.png`) were drawn for this game from simple shapes (original artwork,
no third-party assets). They are not under `assets/`, so the check script does not list them.
