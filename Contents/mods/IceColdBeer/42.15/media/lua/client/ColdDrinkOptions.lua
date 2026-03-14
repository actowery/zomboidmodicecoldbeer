require "PZAPI/ModOptions"
require "ColdDrinkConfig"

local Config = IceColdBeerConfig

if not Config or not PZAPI or not PZAPI.ModOptions then
    return
end

if PZAPI.ModOptions:getOptions(Config.MOD_OPTIONS_ID) then
    return
end

local options = PZAPI.ModOptions:create(Config.MOD_OPTIONS_ID, "Ice Cold Beer")

options:addTitle("Cold Bonus Categories")

local function addIntegerEntry(optionId, title, defaultValue, tooltip)
    options:addTextEntry(
        optionId,
        title,
        tostring(defaultValue),
        tooltip
    )
end

local function addCategoryOptions(categoryKey, title)
    local defaults = Config.DEFAULTS.categories[categoryKey]
    local optionIds = Config.getCategoryOptionIds(categoryKey)

    addIntegerEntry(
        optionIds.unhappiness,
        title .. " Unhappiness",
        defaults.unhappiness,
        "Integer value. How much unhappiness a fully chilled " .. title:lower() .. " drink removes."
    )

    addIntegerEntry(
        optionIds.boredom,
        title .. " Boredom",
        defaults.boredom,
        "Integer value. How much boredom a fully chilled " .. title:lower() .. " drink removes."
    )
end

addCategoryOptions("beer", "Beer")
addCategoryOptions("white_wine", "White Wine")
addCategoryOptions("champagne", "Champagne")
addCategoryOptions("cider", "Cider")
addCategoryOptions("soda", "Soda / Pop (Cans)")
addCategoryOptions("bottled_soda", "Soda / Pop (Bottles)")
addCategoryOptions("juice", "Juice")
addCategoryOptions("milk", "Milk")
addCategoryOptions("personal_milk", "Personal Milk")
addCategoryOptions("chocolate_milk", "Chocolate Milk")

options:addSeparator()
options:addTitle("Custom Drink Targets")
options:addTickBox(
    "custom_targets_enabled",
    "Enable Custom Item IDs",
    Config.DEFAULTS.custom.enabled,
    "Allow extra modded drinks to receive a cold bonus when their full item IDs are listed below."
)
options:addTextEntry(
    "custom_target_ids",
    "Custom Item IDs",
    Config.DEFAULTS.custom.ids,
    "Comma-separated full item IDs such as Base.BeerCan or SomeMod.FancySoda."
)
addIntegerEntry(
    "custom_targets_unhappiness",
    "Custom Target Unhappiness",
    tostring(Config.DEFAULTS.custom.unhappiness),
    "Integer value. How much unhappiness a fully chilled custom target drink removes."
)
addIntegerEntry(
    "custom_targets_boredom",
    "Custom Target Boredom",
    tostring(Config.DEFAULTS.custom.boredom),
    "Integer value. How much boredom a fully chilled custom target drink removes."
)
