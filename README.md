# Ice Cold Beer [B42]

A lightweight Project Zomboid Build 42 mod that makes certain drinks feel better when they are actually chilled.

![Ice Cold Beer poster](Contents/mods/IceColdBeer/42.15/poster.png)

Steam Workshop:
https://steamcommunity.com/sharedfiles/filedetails/?id=3684324175

Supported cold-bonus drinks:
- Beer
- White wine and wine cartons
- Champagne
- Cider
- Soda and pop
- Juice
- Milk

What it does:
- Adds a small boredom and unhappiness reduction when a supported drink is cold but not frozen
- Shows a vanilla-style `Better cold.` tooltip note when a supported drink is not chilled enough yet
- Shows extra cold-bonus tooltip rows once the drink is properly chilled
- Includes English, Spanish, and Turkish tooltip translations

Project layout:
- Workshop-style root: `Contents/mods/IceColdBeer`
- Build-specific mod payload: `Contents/mods/IceColdBeer/42.15`
- Required shared folder: `Contents/mods/IceColdBeer/common`

Local testing:
- Active local mod path: `C:\Users\AT\Zomboid\mods\IceColdBeerLocal\42.15`
- After editing files here, sync the updated contents into that local mod folder before testing in-game
- See `TESTING.md` for a quick smoke-test checklist and optional debug logging

Notes:
- This project follows the current Build 42 packaging guidance of using versioned mod folders and a `common` folder.
- Current release version is `modversion=1.0.6` in `mod.info`.
- Known issue: on the current Build 42 UI, the extra cold bonus tooltip values can appear slightly misaligned even though the tooltip logic and mood effects work correctly.
- No open-source license has been added yet. All rights remain with the author unless you choose a license later.
- This is an unofficial fan-made mod and is not affiliated with The Indie Stone.
