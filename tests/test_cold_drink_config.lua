local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s\nexpected: %s\nactual: %s", message or "values differ", tostring(expected), tostring(actual)), 2)
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function assertFalsey(value, message)
    if value then
        error(message or "expected falsey value", 2)
    end
end

local function makeTagArray(values)
    return {
        toArray = function()
            return values
        end,
    }
end

local function makeItem(fullType, tags)
    return {
        getFullType = function()
            return fullType
        end,
        getTags = function()
            return makeTagArray(tags or {})
        end,
    }
end

local function optionWithValue(value)
    return {
        getValue = function()
            return value
        end,
    }
end

local function makeOptions(values)
    return {
        getOption = function(_, optionId)
            if values[optionId] == nil then
                return nil
            end

            return optionWithValue(values[optionId])
        end,
    }
end

local function loadConfig(values, warningBuffer)
    IceColdBeerConfig = nil

    PZAPI = {
        ModOptions = {
            getOptions = function()
                return makeOptions(values or {})
            end,
        },
    }

    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        warningBuffer[#warningBuffer + 1] = table.concat(parts, " ")
    end

    dofile("Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkConfig.lua")

    return IceColdBeerConfig
end

local testCount = 0

local function runTest(name, fn)
    io.write("[PASS] " .. name .. "\n")
    testCount = testCount + 1
    fn()
end

runTest("category option ids are stable", function()
    local warnings = {}
    local Config = loadConfig({}, warnings)

    local ids = Config.getCategoryOptionIds("beer")
    assertEqual(ids.unhappiness, "beer_unhappiness", "beer unhappiness option id should match")
    assertEqual(ids.boredom, "beer_boredom", "beer boredom option id should match")
end)

runTest("default category bonuses are used when no options exist", function()
    local warnings = {}
    local Config = loadConfig({}, warnings)

    local bonus = Config.getCategoryBonus("beer")
    assertEqual(bonus.unhappiness, 3, "default beer unhappiness should be used")
    assertEqual(bonus.boredom, 2, "default beer boredom should be used")
end)

runTest("category bonus values clamp to 0-100 and warn", function()
    local warnings = {}
    local Config = loadConfig({
        beer_unhappiness = 150,
        beer_boredom = -5,
    }, warnings)

    local bonus = Config.getCategoryBonus("beer")
    assertEqual(bonus.unhappiness, 100, "beer unhappiness should clamp to max")
    assertEqual(bonus.boredom, 0, "beer boredom should clamp to min")
    assertTruthy(#warnings >= 2, "out-of-range values should emit warnings")
end)

runTest("custom bonuses fall back on invalid numeric input", function()
    local warnings = {}
    local Config = loadConfig({
        custom_targets_unhappiness = "abc",
        custom_targets_boredom = "17",
    }, warnings)

    local bonus = Config.getCustomBonus()
    assertEqual(bonus.unhappiness, 2, "invalid custom unhappiness should fall back to default")
    assertEqual(bonus.boredom, 17, "valid custom boredom should pass through")
    assertTruthy(#warnings >= 1, "non-numeric custom value should warn")
end)

runTest("custom target parser accepts comma, semicolon, and newline separators", function()
    local warnings = {}
    local Config = loadConfig({
        custom_targets_enabled = true,
        custom_target_ids = " Base.DrinkingGlass, not real ; SomeMod.FancySoda \nBase.BeerCan ",
    }, warnings)

    local parsed, invalid = Config.getParsedCustomTargets()
    assertTruthy(parsed["Base.DrinkingGlass"], "custom target parser should keep valid ids")
    assertTruthy(parsed["SomeMod.FancySoda"], "custom target parser should allow modded ids")
    assertTruthy(parsed["Base.BeerCan"], "custom target parser should allow multiple delimiters")
    assertEqual(invalid[1], "not real", "custom target parser should return invalid tokens")
end)

runTest("custom target bonus lookup returns custom metadata", function()
    local warnings = {}
    local Config = loadConfig({
        custom_targets_enabled = true,
        custom_target_ids = "Base.DrinkingGlass",
        custom_targets_unhappiness = 9,
        custom_targets_boredom = 4,
    }, warnings)

    local bonus, meta = Config.getBonusForItemType("Base.DrinkingGlass")
    assertEqual(bonus.unhappiness, 9, "custom target unhappiness should be used")
    assertEqual(bonus.boredom, 4, "custom target boredom should be used")
    assertEqual(meta.source, "custom", "custom target metadata should identify custom source")
end)

runTest("disabled custom targets never match", function()
    local warnings = {}
    local Config = loadConfig({
        custom_targets_enabled = false,
        custom_target_ids = "Base.DrinkingGlass",
    }, warnings)

    assertFalsey(Config.isCustomTarget("Base.DrinkingGlass"), "disabled custom targets should not match")
end)

runTest("built-in item type lookup uses category-configured values", function()
    local warnings = {}
    local Config = loadConfig({
        beer_unhappiness = 11,
        beer_boredom = 7,
    }, warnings)

    local bonus, meta = Config.getBonusForItemType("Base.BeerCan")
    assertEqual(bonus.unhappiness, 11, "category-configured unhappiness should be used")
    assertEqual(bonus.boredom, 7, "category-configured boredom should be used")
    assertEqual(meta.key, "beer", "category metadata should identify the correct key")
end)

runTest("bounded integer string helper normalizes values", function()
    local warnings = {}
    local Config = loadConfig({}, warnings)

    assertEqual(Config.getBoundedIntegerString("beer_unhappiness", 101, 3), "100", "bounded integer string should clamp high values")
    assertEqual(Config.getBoundedIntegerString("beer_unhappiness", -4, 3), "0", "bounded integer string should clamp low values")
    assertEqual(Config.getBoundedIntegerString("beer_unhappiness", "oops", 3), "3", "bounded integer string should fall back on invalid input")
end)

runTest("bettercold tag with category uses category-configured values", function()
    local warnings = {}
    local Config = loadConfig({
        beer_unhappiness = 12,
        beer_boredom = 8,
    }, warnings)

    local item = makeItem("SomeMod.CustomBeer", {
        "icecoldbeer:bettercold",
        "icecoldbeer:category/beer",
    })

    local bonus, meta = Config.getBonusForItem(item)
    assertEqual(bonus.unhappiness, 12, "tagged beer should use configured beer unhappiness")
    assertEqual(bonus.boredom, 8, "tagged beer should use configured beer boredom")
    assertEqual(meta.source, "tag", "tagged item metadata should identify tag source")
end)

runTest("bettercold tag explicit values override category values", function()
    local warnings = {}
    local Config = loadConfig({
        beer_unhappiness = 12,
        beer_boredom = 8,
    }, warnings)

    local item = makeItem("SomeMod.CustomBeer", {
        "icecoldbeer:bettercold",
        "icecoldbeer:category/beer",
        "icecoldbeer:unhappiness/4",
        "icecoldbeer:boredom/1",
    })

    local bonus = Config.getBonusForItem(item)
    assertEqual(bonus.unhappiness, 4, "explicit tagged unhappiness should override category")
    assertEqual(bonus.boredom, 1, "explicit tagged boredom should override category")
end)

runTest("bettercold tag without category falls back to custom defaults", function()
    local warnings = {}
    local Config = loadConfig({}, warnings)

    local item = makeItem("SomeMod.CustomDrink", {
        "icecoldbeer:bettercold",
    })

    local bonus = Config.getBonusForItem(item)
    assertEqual(bonus.unhappiness, 2, "tagged fallback unhappiness should use custom default")
    assertEqual(bonus.boredom, 1, "tagged fallback boredom should use custom default")
end)

runTest("bettercold tag values clamp to valid range", function()
    local warnings = {}
    local Config = loadConfig({}, warnings)

    local item = makeItem("SomeMod.CustomDrink", {
        "icecoldbeer:bettercold",
        "icecoldbeer:unhappiness/500",
        "icecoldbeer:boredom/-3",
    })

    local bonus = Config.getBonusForItem(item)
    assertEqual(bonus.unhappiness, 100, "tagged unhappiness should clamp high values")
    assertEqual(bonus.boredom, 0, "tagged boredom should clamp low values")
    assertTruthy(#warnings >= 2, "invalid tagged values should warn")
end)

runTest("timing settings use defaults when no options exist", function()
    local warnings = {}
    local Config = loadConfig({}, warnings)

    local timing = Config.getTimingSettings()
    assertEqual(timing.coldContainerDelayMinutes, 15, "default chill delay should be 15 minutes")
    assertEqual(timing.coldLingerMinutes, 120, "default linger should be 120 minutes")
    assertEqual(timing.coldTransferGraceMinutes, 6, "default transfer grace should be 6 minutes")
end)

runTest("timing settings clamp to valid minute range", function()
    local warnings = {}
    local Config = loadConfig({
        cold_container_delay_minutes = -3,
        cold_linger_minutes = 9999,
        cold_transfer_grace_minutes = "abc",
    }, warnings)

    local timing = Config.getTimingSettings()
    assertEqual(timing.coldContainerDelayMinutes, 0, "chill delay should clamp to minimum")
    assertEqual(timing.coldLingerMinutes, 720, "linger should clamp to maximum")
    assertEqual(timing.coldTransferGraceMinutes, 6, "invalid transfer grace should fall back to default")
    assertTruthy(#warnings >= 3, "invalid timing values should emit warnings")
end)

runTest("timing hour conversion reflects configured minute values", function()
    local warnings = {}
    local Config = loadConfig({
        cold_container_delay_minutes = 30,
        cold_linger_minutes = 90,
        cold_transfer_grace_minutes = 12,
    }, warnings)

    local timing = Config.getTimingHours()
    assertEqual(timing.coldContainerDelayHours, 0.5, "30 minutes should convert to 0.5 hours")
    assertEqual(timing.coldLingerHours, 1.5, "90 minutes should convert to 1.5 hours")
    assertEqual(timing.coldTransferGraceHours, 0.2, "12 minutes should convert to 0.2 hours")
end)

io.write(string.format("Ice Cold Beer config tests passed (%d checks)\n", testCount))
