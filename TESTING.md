# Testing

This mod uses a lightweight smoke-test approach instead of full automation.

## Automated checks

- Basic unit tests live in `tests/test_cold_drink_config.lua`
- GitHub Actions runs that test file on pushes and pull requests
- The automated coverage is intentionally small and focused on config parsing, validation, and bonus lookup logic
- Manual in-game testing is still the primary release gate for UI hooks and timed-action behavior

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

## Test item spawn script

Paste this into the in-game Lua console to add one of each built-in supported drink to your inventory:

```lua
local player = getPlayer()
if player then
    local inv = player:getInventory()
    local items = {
        "Base.BeerBottle",
        "Base.BeerCan",
        "Base.BeerImported",
        "Base.Wine",
        "Base.WineOpen",
        "Base.WineBox",
        "Base.Champagne",
        "Base.Cider",
        "Base.Pop",
        "Base.Pop2",
        "Base.Pop3",
        "Base.PopBottle",
        "Base.PopBottleRare",
        "Base.SodaCan",
        "Base.JuiceBox",
        "Base.JuiceBoxApple",
        "Base.JuiceBoxFruitpunch",
        "Base.JuiceBoxOrange",
        "Base.JuiceCranberry",
        "Base.JuiceFruitpunch",
        "Base.JuiceGrape",
        "Base.JuiceLemon",
        "Base.JuiceOrange",
        "Base.JuiceTomato",
        "Base.Milk",
        "Base.MilkBottle",
        "Base.Milk_Personalsized",
        "Base.MilkChocolate_Personalsized",
    }

    for _, fullType in ipairs(items) do
        inv:AddItem(fullType)
    end

    player:Say("Spawned Ice Cold Beer test drinks.")
end
```

## Config options smoke test

1. Open the in-game Mods options screen and find `Ice Cold Beer`.
2. Change one built-in drink category value and apply the change.
3. Hover a chilled drink from that category and confirm the tooltip bonus updates to the new value.
4. Drink that chilled item and confirm the mood effect uses the new configured value.
5. Enable `Custom Item IDs`.
6. Enter a comma-separated list such as `Base.BeerCan`.
7. Change the custom boredom and unhappiness values, apply, and confirm that target uses the custom values.
8. Enter an invalid value such as `not a real item` and confirm the mod does not error or affect unrelated items.

## Release checklist

1. Confirm the game is loading the intended build by checking `modversion` in the Mods menu.
2. Verify the mod options page appears and loads without client boot issues.
3. Change one built-in category value, apply it, and confirm both tooltip and drink effect use the new value.
4. Test one chilled supported drink and confirm the cold bonus applies.
5. Test one room-temperature supported drink and confirm the cold bonus does not apply.
6. Test one custom item ID target and confirm it uses the custom configured values.
7. Enter at least one invalid or out-of-range text-entry value and confirm it is clamped safely.
8. Check `console.txt` for any new `IceColdBeer`, Lua, or tooltip-related errors.
9. Set `DEBUG = false` in the release build before uploading.
10. Sync the exact tested files into the actual folder the game or Workshop uploader is using.
