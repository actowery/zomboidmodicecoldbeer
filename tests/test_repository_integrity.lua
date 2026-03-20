local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function readFile(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(err, 2)
    end

    local contents = handle:read("*a")
    handle:close()
    return contents
end

local testCount = 0

local function runTest(name, fn)
    fn()
    io.write("[PASS] " .. name .. "\n")
    testCount = testCount + 1
end

runTest("mod.info and ColdDrinkMoodles version stay in sync", function()
    local modInfo = readFile("Contents/mods/IceColdBeer/42.15/mod.info")
    local moodles = readFile("Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkMoodles.lua")

    local modVersion = modInfo:match("modversion=([^\r\n]+)")
    local luaVersion = moodles:match('VERSION%s*=%s*"([^"]+)"')

    assertTruthy(modVersion ~= nil, "mod.info is missing modversion")
    assertTruthy(luaVersion ~= nil, "ColdDrinkMoodles.lua is missing VERSION")
    assertTruthy(modVersion == luaVersion, "mod.info and Lua VERSION must match")
end)

runTest("tooltip translations are shipped as json only", function()
    local locales = { "EN", "ES", "TR" }

    for _, locale in ipairs(locales) do
        local jsonPath = "Contents/mods/IceColdBeer/42.15/media/lua/shared/Translate/" .. locale .. "/Tooltip.json"
        local legacyTxtPath = "Contents/mods/IceColdBeer/42.15/media/lua/shared/Translate/" .. locale .. "/Tooltip_" .. locale .. ".txt"

        local jsonHandle = io.open(jsonPath, "r")
        assertTruthy(jsonHandle ~= nil, "missing tooltip json for locale " .. locale)
        jsonHandle:close()

        local legacyHandle = io.open(legacyTxtPath, "r")
        assertTruthy(legacyHandle == nil, "legacy tooltip txt should not be shipped for locale " .. locale)
        if legacyHandle then
            legacyHandle:close()
        end
    end
end)

runTest("required mod payload files exist", function()
    local requiredPaths = {
        "Contents/mods/IceColdBeer/42.15/mod.info",
        "Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkConfig.lua",
        "Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkMoodles.lua",
        "Contents/mods/IceColdBeer/42.15/media/lua/client/ColdDrinkOptions.lua",
    }

    for _, path in ipairs(requiredPaths) do
        local handle = io.open(path, "r")
        assertTruthy(handle ~= nil, "missing required file: " .. path)
        handle:close()
    end
end)

io.write(string.format("Repository integrity checks passed (%d checks)\n", testCount))
