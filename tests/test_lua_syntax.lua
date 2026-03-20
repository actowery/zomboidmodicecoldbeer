local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function getLuaFiles()
    local handle = io.popen('git ls-files "*.lua"')
    assertTruthy(handle ~= nil, "failed to enumerate tracked Lua files")

    local files = {}
    for file in handle:lines() do
        files[#files + 1] = file
    end
    handle:close()

    return files
end

local files = getLuaFiles()
assertTruthy(#files > 0, "expected at least one tracked Lua file")

local checked = 0

for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    assertTruthy(chunk ~= nil, "Lua syntax error in " .. path .. "\n" .. tostring(err))
    checked = checked + 1
    io.write("[PASS] syntax " .. path .. "\n")
end

io.write(string.format("Lua syntax checks passed (%d files)\n", checked))
