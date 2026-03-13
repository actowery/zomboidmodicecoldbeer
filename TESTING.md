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
