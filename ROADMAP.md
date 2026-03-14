# Roadmap

## Next Feature: Configurable Cold Bonuses

Goal:
- Let players tune the cold moodle bonuses from the in-game Mods options screen instead of editing Lua files manually.

Recommended first scope:
- Add a master enable/disable toggle for custom cold bonuses.
- Add category-level bonus controls for:
  - Beer
  - White wine
  - Champagne / cider
  - Soda / pop
  - Juice
  - Milk
- Keep values integer-only to match the current balance direction.
- Update both tooltip values and applied mood effects to use the configured settings.

Implementation plan:
1. Add a client-side options file under `Contents/mods/IceColdBeer/42.15/media/lua/client/`.
2. Create a mod options panel with `PZAPI.ModOptions:create("icecoldbeer", "Ice Cold Beer")`.
3. Use tick boxes / combo boxes for integer values rather than freeform text input.
4. Add a small shared helper in the cold-bonus logic that reads configured values first and falls back to current defaults if no option exists.
5. Rebuild the tooltip rows from the configured values so the player sees the exact active bonus.
6. Smoke-test both main-menu and in-game application to confirm values persist and affect live drinking behavior.

Suggested UX:
- Keep the default release balance as the initial preset.
- Prefer category-level controls first, not per-item controls, to keep the menu small.
- If this lands cleanly, a later follow-up can add presets such as `Subtle`, `Default`, and `Strong`.

Research notes:
- Build 42 mods on this machine are already using `PZAPI.ModOptions`.
- Confirmed examples:
  - `consistent-cooking-names`: creates tick-box options with `PZAPI.ModOptions:create(...)`
  - `BanditsWeekOne`: creates combo-box options and reads them later with `PZAPI.ModOptions:getOptions(...):getOption(...):getValue()`
  - `MoreDescriptionForTraits`: shows a practical runtime fallback pattern when options are unavailable
- This makes `PZAPI.ModOptions` the preferred path for Ice Cold Beer rather than older `ModOptions:getInstance(...)` patterns.

Open questions before implementation:
- Whether the first pass should expose raw integer values directly or present named presets plus an advanced section.
- Whether custom values should be purely client-side or mirrored through multiplayer-safe behavior later.
