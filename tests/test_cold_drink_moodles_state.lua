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
        getOptions = function()
            return {
                getOption = function()
                    return nil
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

    worldHours = 20.6
    local secondState = Hooks.getColdState(item, { mutate = true })
    assertTruthy(secondState.cold, "item should become cold after enough fridge time")
    assertEqual(secondState.source, "container", "container fallback should report container source")
end)

runTest("leaving cold storage and re-entering resets the timer", function()
    local parentA = makeParent({ x = 10, y = 10, z = 0, objectIndex = 1, name = "FridgeA" })
    local parentB = makeParent({ x = 11, y = 10, z = 0, objectIndex = 2, name = "FridgeB" })
    local containerA = makeContainer({ type = "fridge", powered = true, parent = parentA })
    local containerB = makeContainer({ type = "fridge", powered = true, parent = parentB })
    local item = makeItem({ heat = 1.0, container = containerA, modData = {} })

    worldHours = 30
    Hooks.getColdState(item, { mutate = true })

    worldHours = 30.6
    Hooks.getColdState(item, { mutate = true })
    assertTruthy(Hooks.getColdState(item, { mutate = false }).cold, "item should be cold in first fridge")

    item._container = nil
    local removedState = Hooks.getColdState(item, { mutate = true })
    assertTruthy(removedState.cold, "recently removed item should still use lingering cold")

    worldHours = 31.7
    Hooks.getColdState(item, { mutate = true })

    item._container = containerB
    local readdedState = Hooks.getColdState(item, { mutate = true })
    assertFalsey(readdedState.cold, "re-entering cold storage after linger expires should restart chilling")
    assertTruthy(readdedState.chilling, "re-entered item should restart chilling state")
end)

runTest("container sourced linger survives pickup briefly even without heat change", function()
    worldHours = 40
    local item = makeItem({
        heat = 1.0,
        container = nil,
        modData = {
            icbLastColdHour = 39.5,
            icbLastColdSource = "container",
        },
    })

    local state = Hooks.getColdState(item, { mutate = false })
    assertTruthy(state.cold, "recent container-derived cold should linger after pickup")
end)

runTest("heat sourced linger still requires reduced heat", function()
    worldHours = 50
    local item = makeItem({
        heat = 1.0,
        container = nil,
        modData = {
            icbLastColdHour = 49.5,
            icbLastColdSource = "heat",
        },
    })

    local state = Hooks.getColdState(item, { mutate = false })
    assertFalsey(state.cold, "heat-derived linger should fail when heat has fully normalized")
end)

io.write(string.format("Ice Cold Beer moodle-state tests passed (%d checks)\n", testCount))
