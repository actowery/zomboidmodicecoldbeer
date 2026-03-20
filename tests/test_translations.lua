local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function collectTooltipKeys(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(err, 2)
    end

    local contents = handle:read("*a")
    handle:close()

    local keys = {}
    for key in contents:gmatch("Tooltip_icb_[A-Za-z]+") do
        keys[key] = true
    end

    return keys
end

local function loadTranslationTable(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(err, 2)
    end

    local contents = handle:read("*a")
    handle:close()

    local translations = {}
    for key, value in contents:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
        translations[key] = value
    end

    assertTruthy(next(translations) ~= nil, path .. " did not contain any translation keys")
    return translations
end

local function assertHasKeys(localeName, translations, requiredKeys)
    for key in pairs(requiredKeys) do
        assertTruthy(
            type(translations[key]) == "string" and translations[key] ~= "",
            string.format("%s is missing translation for %s", localeName, key)
        )
    end
end

local requiredKeys = collectTooltipKeys("Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkMoodles.lua")

local locales = {
    {
        name = "EN",
        path = "Contents/mods/IceColdBeer/42.15/media/lua/shared/Translate/EN/Tooltip.json",
    },
    {
        name = "ES",
        path = "Contents/mods/IceColdBeer/42.15/media/lua/shared/Translate/ES/Tooltip.json",
    },
    {
        name = "TR",
        path = "Contents/mods/IceColdBeer/42.15/media/lua/shared/Translate/TR/Tooltip.json",
    },
}

local testCount = 0

for _, locale in ipairs(locales) do
    local translations = loadTranslationTable(locale.path)
    assertHasKeys(locale.name, translations, requiredKeys)
    io.write("[PASS] " .. locale.name .. " tooltip translations cover current keys\n")
    testCount = testCount + 1
end

io.write(string.format("Ice Cold Beer translation tests passed (%d checks)\n", testCount))
