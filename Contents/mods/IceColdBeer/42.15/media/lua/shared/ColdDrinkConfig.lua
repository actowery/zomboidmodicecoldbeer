IceColdBeerConfig = IceColdBeerConfig or {}

local Config = IceColdBeerConfig

Config.MOD_OPTIONS_ID = "icecoldbeer"

Config.DEFAULTS = {
    categories = {
        beer = { label = "Beer", unhappiness = 3, boredom = 2 },
        white_wine = { label = "White Wine", unhappiness = 5, boredom = 3 },
        champagne = { label = "Champagne", unhappiness = 4, boredom = 2 },
        cider = { label = "Cider", unhappiness = 3, boredom = 2 },
        soda = { label = "Soda / Pop (Cans)", unhappiness = 2, boredom = 1 },
        bottled_soda = { label = "Soda / Pop (Bottles)", unhappiness = 3, boredom = 1 },
        juice = { label = "Juice", unhappiness = 2, boredom = 1 },
        milk = { label = "Milk", unhappiness = 2, boredom = 1 },
        personal_milk = { label = "Personal Milk", unhappiness = 1, boredom = 1 },
        chocolate_milk = { label = "Chocolate Milk", unhappiness = 2, boredom = 1 },
    },
    custom = {
        enabled = false,
        ids = "",
        unhappiness = 2,
        boredom = 1,
    },
}

Config.ITEM_CATEGORIES = {
    ["Base.BeerBottle"] = "beer",
    ["Base.BeerCan"] = "beer",
    ["Base.BeerImported"] = "beer",
    ["Base.Wine"] = "white_wine",
    ["Base.WineOpen"] = "white_wine",
    ["Base.WineBox"] = "white_wine",
    ["Base.Champagne"] = "champagne",
    ["Base.Cider"] = "cider",
    ["Base.Pop"] = "soda",
    ["Base.Pop2"] = "soda",
    ["Base.Pop3"] = "soda",
    ["Base.PopBottle"] = "bottled_soda",
    ["Base.PopBottleRare"] = "bottled_soda",
    ["Base.SodaCan"] = "soda",
    ["Base.JuiceBox"] = "juice",
    ["Base.JuiceBoxApple"] = "juice",
    ["Base.JuiceBoxFruitpunch"] = "juice",
    ["Base.JuiceBoxOrange"] = "juice",
    ["Base.JuiceCranberry"] = "juice",
    ["Base.JuiceFruitpunch"] = "juice",
    ["Base.JuiceGrape"] = "juice",
    ["Base.JuiceLemon"] = "juice",
    ["Base.JuiceOrange"] = "juice",
    ["Base.JuiceTomato"] = "juice",
    ["Base.Milk"] = "milk",
    ["Base.MilkBottle"] = "milk",
    ["Base.Milk_Personalsized"] = "personal_milk",
    ["Base.MilkChocolate_Personalsized"] = "chocolate_milk",
}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function clampInteger(value, fallback, minValue, maxValue)
    local number = tonumber(value)
    if not number then
        return fallback
    end

    number = math.floor(number + 0.5)
    if minValue and number < minValue then
        return minValue
    end
    if maxValue and number > maxValue then
        return maxValue
    end

    return number
end

local function getOptions()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.getOptions then
        return PZAPI.ModOptions:getOptions(Config.MOD_OPTIONS_ID)
    end

    return nil
end

local function getOptionValue(options, optionId)
    if not options or not optionId then
        return nil
    end

    local option = options:getOption(optionId)
    if option and option.getValue then
        return option:getValue()
    end

    return nil
end

function Config.getOptions()
    return getOptions()
end

function Config.getCategoryOptionIds(categoryKey)
    return {
        unhappiness = categoryKey .. "_unhappiness",
        boredom = categoryKey .. "_boredom",
    }
end

function Config.getCategoryBonus(categoryKey)
    local defaults = Config.DEFAULTS.categories[categoryKey]
    if not defaults then
        return nil
    end

    local options = getOptions()
    local optionIds = Config.getCategoryOptionIds(categoryKey)

    return {
        unhappiness = clampInteger(getOptionValue(options, optionIds.unhappiness), defaults.unhappiness, 0, 20),
        boredom = clampInteger(getOptionValue(options, optionIds.boredom), defaults.boredom, 0, 20),
    }
end

function Config.getCustomTargetsEnabled()
    local options = getOptions()
    local value = getOptionValue(options, "custom_targets_enabled")
    if value == nil then
        return Config.DEFAULTS.custom.enabled
    end

    return value == true
end

function Config.getCustomTargetIdsRaw()
    local options = getOptions()
    local value = getOptionValue(options, "custom_target_ids")
    if type(value) ~= "string" then
        return Config.DEFAULTS.custom.ids
    end

    return value
end

function Config.getCustomBonus()
    local options = getOptions()

    return {
        unhappiness = clampInteger(getOptionValue(options, "custom_targets_unhappiness"), Config.DEFAULTS.custom.unhappiness, 0, 20),
        boredom = clampInteger(getOptionValue(options, "custom_targets_boredom"), Config.DEFAULTS.custom.boredom, 0, 20),
    }
end

function Config.getParsedCustomTargets()
    local raw = Config.getCustomTargetIdsRaw()
    if Config._customTargetCacheRaw == raw and Config._customTargetCache then
        return Config._customTargetCache, Config._customTargetInvalid or {}
    end

    local targets = {}
    local invalid = {}

    for token in tostring(raw):gmatch("[^,\r\n;]+") do
        local fullType = trim(token)
        if fullType ~= "" then
            if fullType:match("^[A-Za-z0-9_%-]+%.[A-Za-z0-9_%-]+$") then
                targets[fullType] = true
            else
                table.insert(invalid, fullType)
            end
        end
    end

    Config._customTargetCacheRaw = raw
    Config._customTargetCache = targets
    Config._customTargetInvalid = invalid

    return targets, invalid
end

function Config.isCustomTarget(fullType)
    if not Config.getCustomTargetsEnabled() or type(fullType) ~= "string" or fullType == "" then
        return false
    end

    local targets = Config.getParsedCustomTargets()
    return targets[fullType] == true
end

function Config.getBonusForItemType(fullType)
    if type(fullType) ~= "string" or fullType == "" then
        return nil
    end

    local categoryKey = Config.ITEM_CATEGORIES[fullType]
    if categoryKey then
        local bonus = Config.getCategoryBonus(categoryKey)
        if bonus then
            return bonus, { source = "category", key = categoryKey }
        end
    end

    if Config.isCustomTarget(fullType) then
        return Config.getCustomBonus(), { source = "custom", key = fullType }
    end

    return nil
end
