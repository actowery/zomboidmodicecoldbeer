local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function getTrackedFiles()
    local handle = io.popen("git ls-files")
    assertTruthy(handle ~= nil, "failed to enumerate tracked files")

    local files = {}
    for file in handle:lines() do
        files[#files + 1] = file
    end
    handle:close()

    return files
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

local function buildMergeMarker()
    return string.rep("<", 7)
end

local files = getTrackedFiles()
local checked = 0

for _, path in ipairs(files) do
    if path:match("%.lua$") or path:match("%.md$") or path:match("%.txt$") or path:match("%.json$") or path:match("%.yml$") then
        local contents = readFile(path)
        assertTruthy(not contents:find(buildMergeMarker(), 1, true), "merge marker found in " .. path)

        for line in (contents .. "\n"):gmatch("(.-)\n") do
            assertTruthy(not line:find("\t", 1, true), "tab character found in " .. path)
            assertTruthy(not line:find("%s+$"), "trailing whitespace found in " .. path)
        end

        checked = checked + 1
        io.write("[PASS] style " .. path .. "\n")
    end
end

local moodles = readFile("Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkMoodles.lua")
assertTruthy(not moodles:find("DEBUG = true,", 1, true), "source build should not ship with DEBUG = true")

io.write(string.format("Lua style checks passed (%d files)\n", checked))
