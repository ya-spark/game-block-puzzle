# Asset licenses

Every file under `assets/` (other than this file) MUST be listed here by its relative path with
its source and license. `scripts/check_asset_licenses.sh` fails CI otherwise.

| File | Source | License | Notes |
|------|--------|---------|-------|
| _none_ | | | The template draws everything in code; no binary assets are bundled. |

Format for an asset row: `| assets/sfx/pop.ogg | https://example.org/pop | CC0-1.0 | by Jane Doe |`

## App icon

The launcher icon (`android/app/src/main/res/mipmap-*/ic_launcher*.png`) and the Play Store icon
(`store/google-play/icon_512.png`) were drawn for this game from simple shapes (original artwork,
no third-party assets). They are not under `assets/`, so the check script does not list them.
