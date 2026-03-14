# Roadmap

## Current Status

Implemented on the current development branch:
- In-game Build 42 mod options with separate boredom and unhappiness integer entry fields for built-in drink groups
- Advanced custom item-id support for modded drinks
- Safe fallback to default shipped values when options are unavailable

## Next Improvements

### 1. Better Mod Compatibility For Added Drinks
- Improve out-of-the-box support for mods that add chillable drinks, especially beers, sodas, juices, and milk-like items.
- Use Pomp's items and Vanilla Foods Expanded as reference compatibility targets, but keep the implementation general instead of hard-coding only those two mods.
- Possible approaches:
  - expand the built-in allowlist with known popular mod drink IDs
  - add smarter heuristics for drinkable fluid containers that look like cold drinks
  - add optional compatibility tables keyed by mod ID so support can stay organized

### 2. Better Validation Feedback
- Surface invalid custom item IDs more clearly instead of only ignoring them silently.
- Possible options:
  - log invalid entries to `console.txt`
  - show a short warning note in the options UI
  - add a debug-only validation dump

### 3. Friendlier Presets
- Add optional presets such as `Subtle`, `Default`, and `Strong`.
- Keep the current per-category sliders for advanced users.

### 4. Better Custom Target UX
- Consider splitting custom item IDs into multiple smaller fields or a dedicated advanced panel if the single text entry becomes awkward.
- Explore whether a future pass should allow per-custom-target values instead of one shared custom bonus pair.

### 5. Multiplayer Behavior Review
- Confirm whether client-side option differences need any extra handling in multiplayer contexts.
- If needed, define a server-authoritative or host-authoritative config story later.

## Research Notes

Local Build 42 references on this machine confirm that `PZAPI.ModOptions` is the preferred implementation path:
- `consistent-cooking-names`: simple tick-box usage
- `BanditsWeekOne`: combo-box creation plus runtime reads through `PZAPI.ModOptions:getOptions(...):getOption(...):getValue()`
- Base game `media/lua/client/PZAPI/ModOptions.lua`: supports `addTextEntry`, `addTickBox`, `addComboBox`, `addSlider`, and related option types
