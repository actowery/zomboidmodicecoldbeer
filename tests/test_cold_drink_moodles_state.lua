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

local testCount = 0

local function runTest(name, fn)
    fn()
    io.write("[PASS] " .. name .. "\n")
    testCount = testCount + 1
end

local worldHours = 0

local function makeContainer(def)
    local container = {
        _type = def.type,
        _powered = def.powered,
        _parent = def.parent,
        _containingItem = def.containingItem,
    }

    function container:getType()
        return self._type
    end

    function container:isPowered()
        return self._powered
    end

    function container:getParent()
        return self._parent
    end

    function container:getContainingItem()
        return self._containingItem
    end

    return container
end

local function makeParent(def)
    local parent = {
        _x = def.x,
        _y = def.y,
        _z = def.z,
        _objectIndex = def.objectIndex,
        _name = def.name,
    }

    function parent:getX()
        return self._x
    end

    function parent:getY()
        return self._y
    end

    function parent:getZ()
        return self._z
    end

    function parent:getObjectIndex()
        return self._objectIndex
    end

    function parent:getName()
        return self._name
    end

    return parent
end

local function makeContainingItem(def)
    local item = {
        _id = def.id,
        _fullType = def.fullType,
    }

    function item:getID()
        return self._id
    end

    function item:getFullType()
        return self._fullType
    end

    return item
end

local function makeItem(def)
    local item = {
        _heat = def.heat or 1.0,
        _container = def.container,
        _modData = def.modData or {},
        _frozen = def.frozen or false,
        _fullType = def.fullType or "Base.Pop2",
    }

    function item:getHeat()
        return self._heat
    end

    function item:getItemHeat()
        return self._heat
    end

    function item:getInvHeat()
        return self._heat
    end

    function item:getContainer()
        return self._container
    end

    function item:getModData()
        return self._modData
    end

    function item:isFrozen()
        return self._frozen
    end

    function item:getFullType()
        return self._fullType
    end

    return item
end

IceColdBeerConfig = nil
IceColdBeerTestHooks = {}
require = function()
    return nil
end

PZAPI = {
    ModOptions = {
        _values = {},
        getOptions = function()
            local values = PZAPI.ModOptions._values or {}
            return {
                getOption = function(_, optionId)
                    if values[optionId] == nil then
                        return nil
                    end

                    return {
                        getValue = function()
                            return values[optionId]
                        end,
                    }
                end,
            }
        end,
    },
}

ISDrinkFromBottle = {
    drink = function() end,
    start = function() end,
    stop = function() end,
}

ISDrinkFluidAction = {
    start = function() end,
    updateEat = function() end,
    stop = function() end,
    perform = function() end,
}

Events = {
    OnGameBoot = { Add = function() end },
    OnContainerUpdate = { Add = function() end },
    EveryOneMinute = { Add = function() end },
}

getGameTime = function()
    return {
        getWorldAgeHours = function()
            return worldHours
        end,
    }
end

getText = function(key)
    return key
end

isServer = function()
    return false
end

dofile("Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkConfig.lua")
dofile("Contents/mods/IceColdBeer/42.15/media/lua/shared/ColdDrinkMoodles.lua")

local Hooks = IceColdBeerTestHooks

runTest("cold container type matches exact types and keywords", function()
    assertTruthy(Hooks.isColdContainerType("fridge"), "exact fridge type should match")
    assertTruthy(Hooks.isColdContainerType("displayCooler"), "cooler keyword should match")
    assertTruthy(Hooks.isColdContainerType("Appliance_Refrigeration"), "refriger keyword should match")
    assertFalsey(Hooks.isColdContainerType("counter"), "non-cold container should not match")
end)

runTest("read only cold evaluation does not stamp tracking state", function()
    worldHours = 10
    local parent = makeParent({ x = 1, y = 2, z = 0, objectIndex = 3, name = "Fridge" })
    local container = makeContainer({ type = "fridge", powered = true, parent = parent })
    local item = makeItem({ heat = 1.0, container = container, modData = {} })

    local state = Hooks.getColdState(item, { mutate = false })
    assertFalsey(state.cold, "freshly seen item should not be cold yet")
    assertTruthy(state.chilling, "freshly seen item should be chilling")
    assertEqual(item:getModData().icbColdContainerStartHour, nil, "read-only evaluation should not write a start hour")
    assertEqual(item:getModData().icbColdContainerSignature, nil, "read-only evaluation should not write a signature")
end)

runTest("container fallback becomes cold after delay and stores tracking state", function()
    local parent = makeParent({ x = 5, y = 6, z = 0, objectIndex = 7, name = "Fridge" })
    local container = makeContainer({ type = "fridge", powered = true, parent = parent })
    local item = makeItem({ heat = 1.0, container = container, modData = {} })

    worldHours = 20
    local firstState = Hooks.getColdState(item, { mutate = true })
    assertFalsey(firstState.cold, "initial tracked state should not be cold")
    assertTruthy(firstState.chilling, "initial tracked state should be chilling")

    worldHours = 20.3
    local secondState = Hooks.getColdState(item, { mutate = true })
    assertTruthy(secondState.cold, "item should become cold after enough fridge time")
    assertEqual(secondState.source, "container", "container fallback should report container source")
end)

runTest("moving between fridge and freezer in the same appliance keeps chill progress", function()
    local parent = makeParent({ x = 8, y = 9, z = 0, objectIndex = 4, name = "ComboFridge" })
    local containerFridge = makeContainer({ type = "fridge", powered = true, parent = parent })
    local containerFreezer = makeContainer({ type = "freezer", powered = true, parent = parent })
    local item = makeItem({ heat = 1.0, container = containerFridge, modData = {} })

    worldHours = 25
    Hooks.getColdState(item, { mutate = true })

    worldHours = 25.3
    item._container = containerFreezer
    local transferredState = Hooks.getColdState(item, { mutate = true })

    assertFalsey(transferredState.chilling, "same-appliance transfer should not restart chilling")
    assertTruthy(transferredState.cold, "same-appliance transfer should preserve chill progress")
    assertEqual(transferredState.source, "container", "same-appliance transfer should keep container cold source")
end)

runTest("moving between different powered cold appliances within transfer grace keeps chill progress", function()
    local parentA = makeParent({ x = 12, y = 10, z = 0, objectIndex = 1, name = "FridgeA" })
    local parentB = makeParent({ x = 13, y = 10, z = 0, objectIndex = 2, name = "FridgeB" })
    local containerA = makeContainer({ type = "fridge", powered = true, parent = parentA })
    local containerB = makeContainer({ type = "fridge", powered = true, parent = parentB })
    local item = makeItem({ heat = 1.0, container = containerA, modData = {} })

    worldHours = 28
    Hooks.getColdState(item, { mutate = true })

    worldHours = 28.3
    item._container = containerB
    local transferredState = Hooks.getColdState(item, { mutate = true })

    assertFalsey(transferredState.chilling, "cross-appliance cold transfer within grace should not restart chilling")
    assertTruthy(transferredState.cold, "cross-appliance cold transfer within grace should preserve chill progress")
    assertEqual(transferredState.source, "container", "cross-appliance cold transfer should keep container cold source")
end)

runTest("leaving cold storage and re-entering resets the timer", function()
    local parentA = makeParent({ x = 10, y = 10, z = 0, objectIndex = 1, name = "FridgeA" })
    local parentB = makeParent({ x = 11, y = 10, z = 0, objectIndex = 2, name = "FridgeB" })
    local containerA = makeContainer({ type = "fridge", powered = true, parent = parentA })
    local containerB = makeContainer({ type = "fridge", powered = true, parent = parentB })
    local item = makeItem({ heat = 1.0, container = containerA, modData = {} })

    worldHours = 30
    Hooks.getColdState(item, { mutate = true })

    worldHours = 30.3
    Hooks.getColdState(item, { mutate = true })
    assertTruthy(Hooks.getColdState(item, { mutate = false }).cold, "item should be cold in first fridge")

    item._container = nil
    local removedState = Hooks.getColdState(item, { mutate = true })
    assertTruthy(removedState.cold, "recently removed item should still use lingering cold")

    worldHours = 32.5
    Hooks.getColdState(item, { mutate = true })

    item._container = containerB
    local readdedState = Hooks.getColdState(item, { mutate = true })
    assertFalsey(readdedState.cold, "re-entering cold storage after linger expires should restart chilling")
    assertTruthy(readdedState.chilling, "re-entered item should restart chilling state")
end)

runTest("moving to a different powered cold appliance after transfer grace restarts chilling", function()
    local parentA = makeParent({ x = 14, y = 10, z = 0, objectIndex = 1, name = "FridgeA" })
    local parentB = makeParent({ x = 15, y = 10, z = 0, objectIndex = 2, name = "FridgeB" })
    local containerA = makeContainer({ type = "fridge", powered = true, parent = parentA })
    local containerB = makeContainer({ type = "fridge", powered = true, parent = parentB })
    local item = makeItem({ heat = 1.0, container = containerA, modData = {} })

    worldHours = 35
    Hooks.getColdState(item, { mutate = true })

    worldHours = 35.3
    Hooks.getColdState(item, { mutate = true })
    assertTruthy(Hooks.getColdState(item, { mutate = false }).cold, "item should be cold before leaving first fridge")

    item._container = nil
    worldHours = 37.5
    Hooks.getColdState(item, { mutate = true })

    item._container = containerB
    local movedState = Hooks.getColdState(item, { mutate = true })

    assertFalsey(movedState.cold, "transfer after grace should restart chilling")
    assertTruthy(movedState.chilling, "transfer after grace should restart chilling state")
end)

runTest("container sourced linger survives pickup briefly even without heat change", function()
    worldHours = 40
    local item = makeItem({
        heat = 1.0,
        container = nil,
        modData = {
            icbLastColdHour = 38.5,
            icbLastColdSource = "container",
        },
    })

    local state = Hooks.getColdState(item, { mutate = false })
    assertTruthy(state.cold, "recent container-derived cold should linger after pickup")
end)

runTest("container sourced linger expires after tuned sustain window", function()
    worldHours = 50
    local item = makeItem({
        heat = 1.0,
        container = nil,
        modData = {
            icbLastColdHour = 47.9,
            icbLastColdSource = "container",
        },
    })

    local state = Hooks.getColdState(item, { mutate = false })
    assertFalsey(state.cold, "container-derived linger should expire once sustain window passes")
end)

runTest("heat sourced linger still requires reduced heat", function()
    worldHours = 60
    local item = makeItem({
        heat = 1.0,
        container = nil,
        modData = {
            icbLastColdHour = 59.5,
            icbLastColdSource = "heat",
        },
    })

    local state = Hooks.getColdState(item, { mutate = false })
    assertFalsey(state.cold, "heat-derived linger should fail when heat has fully normalized")
end)

runTest("configured timing options affect chill delay and linger behavior", function()
    PZAPI.ModOptions._values = {
        cold_container_delay_minutes = 30,
        cold_linger_minutes = 30,
        cold_transfer_grace_minutes = 3,
    }

    local parent = makeParent({ x = 20, y = 20, z = 0, objectIndex = 5, name = "Fridge" })
    local container = makeContainer({ type = "fridge", powered = true, parent = parent })
    local item = makeItem({ heat = 1.0, container = container, modData = {} })

    worldHours = 70
    local initialState = Hooks.getColdState(item, { mutate = true })
    assertTruthy(initialState.chilling, "configured delay should begin in chilling state")

    worldHours = 70.3
    local preDelayState = Hooks.getColdState(item, { mutate = true })
    assertFalsey(preDelayState.cold, "30-minute configured delay should not be cold after 18 minutes")
    assertTruthy(preDelayState.chilling, "30-minute configured delay should still be chilling after 18 minutes")

    worldHours = 70.6
    local postDelayState = Hooks.getColdState(item, { mutate = true })
    assertTruthy(postDelayState.cold, "30-minute configured delay should be cold after 36 minutes")

    item._container = nil
    worldHours = 71.0
    local lingerState = Hooks.getColdState(item, { mutate = false })
    assertTruthy(lingerState.cold, "30-minute linger should still be active after 24 minutes out of cold storage")

    worldHours = 71.2
    local expiredState = Hooks.getColdState(item, { mutate = false })
    assertFalsey(expiredState.cold, "30-minute linger should expire after 72 minutes total elapsed")

    PZAPI.ModOptions._values = {}
end)

io.write(string.format("Ice Cold Beer moodle-state tests passed (%d checks)\n", testCount))
