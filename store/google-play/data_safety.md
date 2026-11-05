# Data safety form – DRAFT answers (verify against the final build)

| Question | Answer |
|----------|--------|
| Does the app collect or share user data? | Yes (via AdMob SDK) |
| Data collected | Device or other IDs (Advertising ID); Approximate location; App interactions / diagnostics as collected by the AdMob SDK |
| Purpose | Advertising or marketing; Analytics (by AdMob) |
| Shared with third parties | Yes: Google AdMob |
| Is data processed ephemerally? | No |
| Is collection required or optional? | Required for ads (consent requested in EEA/UK) |
| Encrypted in transit? | Yes |
| Can users request deletion? | No account is created; uninstall removes local data |
| Purchases | Handled by Google Play Billing; no payment data received |
| Play Games sign-in (if enabled) | Player ID / saved game data stored by Google Play Games |
| Sharing | Optional. The player starts it and picks the target app in the Android share sheet (`share_plus`); the app sends nothing itself and collects nothing (the share text may carry a link to the game's Play page, set by `share.link_mode`). The share picture holds only the game name, the scores and the current look of the game, no name or id |
| Public contact email | ggprouser@gmail.com |

Also declare in Play Console: **Contains ads = Yes**.
