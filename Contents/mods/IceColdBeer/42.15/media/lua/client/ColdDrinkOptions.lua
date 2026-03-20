require "PZAPI/ModOptions"
require "ColdDrinkConfig"

local Config = IceColdBeerConfig

if not Config or not PZAPI or not PZAPI.ModOptions then
    return
end

if PZAPI.ModOptions.icbRegistered then
    return
end

local originalModOptionsLoad = PZAPI.ModOptions.load
if not PZAPI.ModOptions.icbPatchedLoad then
    PZAPI.ModOptions.load = function(self, ...)
        originalModOptionsLoad(self, ...)

        local loadedOptions = self:getOptions(Config.MOD_OPTIONS_ID)
        if not loadedOptions or not loadedOptions.data then
            return
        end

        for _, option in ipairs(loadedOptions.data) do
            if option.type == "textentry" then
                local fallback = ""
                if option.id then
                    local categoryKey, statKey = option.id:match("^(.-)_(unhappiness)$")
                    if not categoryKey or not statKey then
                        categoryKey, statKey = option.id:match("^(.-)_(boredom)$")
                    end
                    local timingDefaults = Config.DEFAULTS.timing
                    local timingFallbacks = {
                        cold_container_delay_minutes = timingDefaults.cold_container_delay_minutes,
                        cold_linger_minutes = timingDefaults.cold_linger_minutes,
                        cold_transfer_grace_minutes = timingDefaults.cold_transfer_grace_minutes,
                    }

                    if categoryKey and statKey and Config.DEFAULTS.categories[categoryKey] then
                        fallback = Config.DEFAULTS.categories[categoryKey][statKey]
                    elseif option.id == "custom_targets_unhappiness" then
                        fallback = Config.DEFAULTS.custom.unhappiness
                    elseif option.id == "custom_targets_boredom" then
                        fallback = Config.DEFAULTS.custom.boredom
                    elseif timingFallbacks[option.id] ~= nil then
                        fallback = timingFallbacks[option.id]
                    end
                end

                if fallback ~= "" then
                    local timingIds = Config.getTimingOptionIds()
                    local isTimingOption =
                        option.id == timingIds.coldContainerDelayMinutes or
                        option.id == timingIds.coldLingerMinutes or
                        option.id == timingIds.coldTransferGraceMinutes

                    if isTimingOption then
                        option.value = tostring(math.floor(tonumber(Config.getTimingSettings()[({
                            [timingIds.coldContainerDelayMinutes] = "coldContainerDelayMinutes",
                            [timingIds.coldLingerMinutes] = "coldLingerMinutes",
                            [timingIds.coldTransferGraceMinutes] = "coldTransferGraceMinutes",
                        })[option.id]]) or fallback))
                    else
                        option.value = Config.getBoundedIntegerString(option.id, option.value, fallback)
                    end
                else
                    option.value = tostring(option.value or "")
                end
            end
        end
    end
    PZAPI.ModOptions.icbPatchedLoad = true
end

local options = PZAPI.ModOptions:create(Config.MOD_OPTIONS_ID, "Ice Cold Beer")
PZAPI.ModOptions.icbRegistered = true

options:addTitle("Cold Bonus Categories")

local function addIntegerEntry(optionId, title, defaultValue, tooltip)
    options:addTextEntry(
        optionId,
        title,
        tostring(defaultValue),
        tooltip .. " Allowed range: " .. tostring(Config.MIN_BONUS) .. "-" .. tostring(Config.MAX_BONUS) .. "."
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
options:addTitle("Cold Timing")
addIntegerEntry(
    "cold_container_delay_minutes",
    "Fallback Chill Delay (Minutes)",
    Config.DEFAULTS.timing.cold_container_delay_minutes,
    "Integer value. How many in-game minutes a supported drink must stay in powered cold storage before the fallback marks it as chilled."
)
addIntegerEntry(
    "cold_linger_minutes",
    "Cold Sustain (Minutes)",
    Config.DEFAULTS.timing.cold_linger_minutes,
    "Integer value. How many in-game minutes a recently chilled drink can keep its fallback cold sustain after leaving cold storage."
)
addIntegerEntry(
    "cold_transfer_grace_minutes",
    "Cold Transfer Grace (Minutes)",
    Config.DEFAULTS.timing.cold_transfer_grace_minutes,
    "Integer value. How long a drink can stay out of powered cold storage during transfers before its fallback chill progress resets."
)

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
