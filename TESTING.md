# Testing

This mod uses a lightweight smoke-test approach instead of full automation.

## Quick smoke test

1. Start the game with `Ice Cold Beer [B42]` enabled.
2. Confirm the mod menu shows the expected `modversion`.
3. Spawn or find a supported drink:
   - beer
   - white wine
   - champagne
   - cider
   - soda
   - juice
   - milk
4. Hover the drink at room temperature.
5. Confirm the tooltip shows `Better cold.` for supported items.
6. Put the drink in a working fridge and wait for it to chill.
7. Hover it again and confirm the tooltip now shows:
   - `Temperature: Cold`
   - `Cold Unhappiness Bonus`
   - `Cold Boredom Bonus`
8. Drink it while chilled and verify boredom/unhappiness improve.
9. Freeze it if possible and confirm the cold bonus no longer applies.

## Optional debug mode

You can enable simple console logging by editing:

`Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkMoodles.lua`

Change:

```lua
DEBUG = false,
```

to:

```lua
DEBUG = true,
```

With debug enabled, the console will log:
- when a supported drink tooltip is evaluated
- the detected heat value
- whether the item is considered frozen
- exact boredom and unhappiness bonus amounts
- boredom and unhappiness values before and after drinking

## Config options smoke test

1. Open the in-game Mods options screen and find `Ice Cold Beer`.
2. Change one built-in drink category slider and apply the change.
3. Hover a chilled drink from that category and confirm the tooltip bonus updates to the new value.
4. Drink that chilled item and confirm the mood effect uses the new configured value.
5. Enable `Custom Item IDs`.
6. Enter a comma-separated list such as `Base.BeerCan`.
7. Change the custom boredom and unhappiness sliders, apply, and confirm that target uses the custom values.
8. Enter an invalid value such as `not a real item` and confirm the mod does not error or affect unrelated items.
