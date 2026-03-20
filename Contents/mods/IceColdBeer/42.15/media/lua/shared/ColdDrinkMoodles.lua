require "TimedActions/ISDrinkFromBottle"
require "TimedActions/ISDrinkFluidAction"
require "ColdDrinkConfig"

local ICB = {
    COLD_THRESHOLD = 0.85,
    MIN_LINGER_HEAT = 0.95,
    COLD_LINGER_HOURS = 2.0,
    COLD_CONTAINER_DELAY_HOURS = 0.25,
    COLD_TRANSFER_GRACE_HOURS = 0.10,
    MIN_APPLY_RATIO = 0.01,
    VERSION = "1.0.18",
    DEBUG = false,
}

local Config = IceColdBeerConfig

local originalDrink = ISDrinkFromBottle.drink
local originalDrinkStart = ISDrinkFromBottle.start
local originalDrinkStop = ISDrinkFromBottle.stop
local originalFluidDrinkStart = ISDrinkFluidAction.start
local originalFluidUpdateEat = ISDrinkFluidAction.updateEat
local originalFluidStop = ISDrinkFluidAction.stop
local originalFluidPerform = ISDrinkFluidAction.perform

local function debugLog(message)
    if ICB.DEBUG then
        print("[IceColdBeer] " .. tostring(message))
    end
end

debugLog("loaded version=" .. ICB.VERSION .. " debug=" .. tostring(ICB.DEBUG))

local function formatDebugNumber(value)
    return string.format("%.2f", tonumber(value) or 0)
end

local function safeCallMethod(object, methodName)
    if not object then
        return false, nil
    end

    local method = object[methodName]
    if type(method) ~= "function" then
        return false, nil
    end

    return pcall(method, object)
end

local function getConsumeRatio(item, beforeAmount)
    if not item or type(item.getFluidContainer) ~= "function" then
        return 0
    end

    local ok, container = safeCallMethod(item, "getFluidContainer")
    if not ok or not container then
        return 0
    end

    local okCapacity, capacity = safeCallMethod(container, "getCapacity")
    if not okCapacity or not capacity or capacity <= 0 then
        return 0
    end

    local okAmount, amount = safeCallMethod(container, "getAmount")
    if not okAmount or type(amount) ~= "number" then
        return 0
    end

    local consumed = beforeAmount - amount
    if consumed <= 0 then
        return 0
    end

    return consumed / capacity
end

local function getCurrentAmount(item)
    if not item or type(item.getFluidContainer) ~= "function" then
        return nil
    end

    local ok, container = safeCallMethod(item, "getFluidContainer")
    if not ok or not container then
        return nil
    end

    local okAmount, amount = safeCallMethod(container, "getAmount")
    if not okAmount then
        return nil
    end

    return amount
end

local function getRemainingRatio(item)
    if not item or type(item.getFluidContainer) ~= "function" then
        return 0
    end

    local ok, container = safeCallMethod(item, "getFluidContainer")
    if not ok or not container then
        return 0
    end

    local okCapacity, capacity = safeCallMethod(container, "getCapacity")
    if not okCapacity or not capacity or capacity <= 0 then
        return 0
    end

    local okAmount, amount = safeCallMethod(container, "getAmount")
    if not okAmount or type(amount) ~= "number" then
        return 0
    end

    return amount / capacity
end

local function isFrozen(item)
    if not item then
        return false
    end

    local method = item["isFrozen"]
    if type(method) == "function" then
        local ok, result = pcall(method, item)
        return ok and result or false
    end

    if type(method) == "boolean" then
        return method
    end

    return false
end

local function getNormalizedHeat(item)
    if not item then
        return 1.0
    end

    local candidates = {
        "getHeat",
        "getItemHeat",
        "getInvHeat",
    }

    for _, methodName in ipairs(candidates) do
        local method = item[methodName]
        if type(method) == "function" then
            local ok, value = pcall(method, item)
            if ok and type(value) == "number" then
                return value
            end
        elseif type(method) == "number" then
            return method
        end
    end

    return 1.0
end

local function getCurrentWorldHours()
    local gameTime = getGameTime()
    if gameTime and gameTime.getWorldAgeHours then
        return gameTime:getWorldAgeHours()
    end

    return nil
end

local function getTimingHours()
    if Config and type(Config.getTimingHours) == "function" then
        return Config.getTimingHours()
    end

    return {
        coldContainerDelayHours = ICB.COLD_CONTAINER_DELAY_HOURS,
        coldLingerHours = ICB.COLD_LINGER_HOURS,
        coldTransferGraceHours = ICB.COLD_TRANSFER_GRACE_HOURS,
    }
end

local function getItemModData(item)
    if not item then
        return nil
    end

    local method = item["getModData"]
    if type(method) == "function" then
        local ok, result = pcall(method, item)
        if ok and result then
            return result
        end
    end

    return nil
end

local function getColdContainer(item)
    if not item then
        return nil
    end

    local ok, container = safeCallMethod(item, "getContainer")
    if not ok or not container then
        return nil
    end

    return container
end

local function isColdContainerType(containerType)
    if Config and type(Config.isColdContainerType) == "function" then
        return Config.isColdContainerType(containerType)
    end

    return containerType == "fridge" or containerType == "freezer" or containerType == "icecream"
end

local function isInPoweredColdContainer(item)
    local container = getColdContainer(item)
    if not container then
        return false
    end

    local okType, containerType = safeCallMethod(container, "getType")
    if not okType or type(containerType) ~= "string" or not isColdContainerType(containerType) then
        return false
    end

    local okPowered, powered = safeCallMethod(container, "isPowered")
    if okPowered then
        return powered == true
    end

    return true
end

local function getColdContainerSignature(item)
    local container = getColdContainer(item)
    if not container then
        return nil
    end

    local parts = {}

    local okContainingItem, containingItem = safeCallMethod(container, "getContainingItem")
    if okContainingItem and containingItem then
        local okContainingId, containingId = safeCallMethod(containingItem, "getID")
        local okContainingType, containingType = safeCallMethod(containingItem, "getFullType")
        parts[#parts + 1] = "containingId=" .. tostring(containingId or "nil")
        parts[#parts + 1] = "containingType=" .. tostring(containingType or "nil")
    end

    local okParent, parent = safeCallMethod(container, "getParent")
    if okParent and parent then
        local okX, x = safeCallMethod(parent, "getX")
        local okY, y = safeCallMethod(parent, "getY")
        local okZ, z = safeCallMethod(parent, "getZ")
        local okObjectIndex, objectIndex = safeCallMethod(parent, "getObjectIndex")
        local okName, objectName = safeCallMethod(parent, "getName")
        parts[#parts + 1] = "parent=" .. tostring(objectName or parent)
        parts[#parts + 1] = "x=" .. tostring(okX and x or "nil")
        parts[#parts + 1] = "y=" .. tostring(okY and y or "nil")
        parts[#parts + 1] = "z=" .. tostring(okZ and z or "nil")
        parts[#parts + 1] = "obj=" .. tostring(okObjectIndex and objectIndex or "nil")
    end

    return table.concat(parts, "|")
end

local function rememberColdState(item, source)
    local modData = getItemModData(item)
    local now = getCurrentWorldHours()
    if not modData or not now then
        return
    end

    modData.icbLastColdHour = now
    modData.icbLastColdSource = source or "heat"
end

local function clearColdContainerState(item)
    local modData = getItemModData(item)
    if not modData then
        return
    end

    modData.icbColdContainerStartHour = nil
    modData.icbColdContainerSignature = nil
    modData.icbColdContainerLastSeenHour = nil
end

local function getColdContainerElapsedHours(item, options)
    options = options or {}
    local mutate = options.mutate ~= false
    local modData = getItemModData(item)
    local now = getCurrentWorldHours()
    local timing = getTimingHours()
    if not modData or not now then
        return nil
    end

    local startHour = tonumber(modData.icbColdContainerStartHour)
    local lastSeenHour = tonumber(modData.icbColdContainerLastSeenHour)

    if not isInPoweredColdContainer(item) then
        if mutate then
            if not lastSeenHour or (now - lastSeenHour) > timing.coldTransferGraceHours then
                clearColdContainerState(item)
            end
        end
        return nil
    end

    local signature = getColdContainerSignature(item)
    local storedSignature = tostring(modData.icbColdContainerSignature or "")
    local signatureChanged = signature and storedSignature ~= "" and storedSignature ~= signature

    if signatureChanged and startHour then
        if mutate then
            debugLog("cold container signature changed while still refrigerated; preserving chill timer from " .. storedSignature .. " to " .. tostring(signature))
            modData.icbColdContainerSignature = signature
            modData.icbColdContainerLastSeenHour = now
        end

        if now >= startHour then
            return now - startHour
        end

        return 0
    end

    if signatureChanged then
        if mutate then
            debugLog("cold container signature changed; restarting chill timer from " .. storedSignature .. " to " .. tostring(signature))
            modData.icbColdContainerSignature = signature
            modData.icbColdContainerStartHour = now
            modData.icbColdContainerLastSeenHour = now
        end
        return 0
    end

    if not startHour then
        if mutate then
            modData.icbColdContainerStartHour = now
            modData.icbColdContainerSignature = signature
            modData.icbColdContainerLastSeenHour = now
        end
        return 0
    end

    if now < startHour then
        if mutate then
            modData.icbColdContainerStartHour = now
            modData.icbColdContainerSignature = signature
            modData.icbColdContainerLastSeenHour = now
        end
        return 0
    end

    if mutate then
        modData.icbColdContainerLastSeenHour = now
    end

    return now - startHour
end

local function getColdContainerFallbackState(item, options)
    local elapsedHours = getColdContainerElapsedHours(item, options)
    local timing = getTimingHours()
    if elapsedHours == nil then
        return {
            active = false,
            cold = false,
            chilling = false,
            elapsedHours = nil,
            remainingHours = nil,
        }
    end

    return {
        active = true,
        cold = elapsedHours >= timing.coldContainerDelayHours,
        chilling = elapsedHours < timing.coldContainerDelayHours,
        elapsedHours = elapsedHours,
        remainingHours = math.max(0, timing.coldContainerDelayHours - elapsedHours),
    }
end

local function setDrinkSnapshot(item)
    local modData = getItemModData(item)
    if not modData then
        return
    end

    modData.icbDrinkSnapshotRatio = getRemainingRatio(item)
    modData.icbDrinkInProgress = true
end

local function clearDrinkSnapshot(item)
    local modData = getItemModData(item)
    if not modData then
        return
    end

    modData.icbDrinkSnapshotRatio = nil
    modData.icbDrinkInProgress = nil
end

local function getBonusDefinition(item)
    if not item or not Config or not Config.getBonusForItem then
        return nil
    end

    local ok, bonus = pcall(Config.getBonusForItem, item)
    if not ok then
        return nil
    end
    if not bonus then
        return nil
    end

    return bonus
end

local function isColdEnoughRaw(item)
    return item and getNormalizedHeat(item) < ICB.COLD_THRESHOLD and not isFrozen(item)
end

local function isWithinColdLinger(item)
    local modData = getItemModData(item)
    local now = getCurrentWorldHours()
    local timing = getTimingHours()
    if not modData or not now then
        return false
    end

    local lastColdHour = tonumber(modData.icbLastColdHour)
    if not lastColdHour then
        return false
    end

    if (now - lastColdHour) > timing.coldLingerHours then
        return false
    end

    local currentHeat = getNormalizedHeat(item)
    if currentHeat < ICB.MIN_LINGER_HEAT then
        return true
    end

    return modData.icbLastColdSource == "container"
end

local function getColdState(item, options)
    options = options or {}
    local mutate = options.mutate ~= false

    if not item or isFrozen(item) then
        if mutate then
            clearColdContainerState(item)
        end
        return { cold = false, source = nil, chilling = false }
    end

    if isColdEnoughRaw(item) then
        if mutate then
            clearColdContainerState(item)
            rememberColdState(item, "heat")
        end
        return { cold = true, source = "heat", chilling = false }
    end

    local containerState = getColdContainerFallbackState(item, { mutate = mutate })
    if containerState.cold then
        if mutate then
            rememberColdState(item, "container")
        end
        return {
            cold = true,
            source = "container",
            chilling = false,
            elapsedHours = containerState.elapsedHours,
            remainingHours = containerState.remainingHours,
        }
    end

    if isWithinColdLinger(item) then
        return { cold = true, source = "linger", chilling = false }
    end

    return {
        cold = false,
        source = nil,
        chilling = containerState.chilling,
        elapsedHours = containerState.elapsedHours,
        remainingHours = containerState.remainingHours,
    }
end

local function isColdEnough(item, options)
    return getColdState(item, options).cold
end

local function prefersCold(item)
    if not item then
        return false
    end

    local bonus = getBonusDefinition(item)
    if not bonus then
        return false
    end

    local ok, ratio = pcall(getRemainingRatio, item)
    return ok and type(ratio) == "number" and ratio > 0
end

local function getScaledBonus(item)
    local bonus = getBonusDefinition(item)
    if not bonus then
        return nil
    end

    local ratio = getRemainingRatio(item)
    local modData = getItemModData(item)
    if modData and modData.icbDrinkInProgress and type(modData.icbDrinkSnapshotRatio) == "number" then
        ratio = modData.icbDrinkSnapshotRatio
    end

    ratio = math.max(0, math.min(1, ratio or 0))

    return {
        unhappiness = bonus.unhappiness * ratio,
        boredom = bonus.boredom * ratio,
    }
end

local function applyMoodBonus(character, item, ratio, options)
    if not character or not item or ratio <= 0 then
        debugLog("skip applyMoodBonus: missing character/item or empty ratio")
        return
    end

    if ratio < ICB.MIN_APPLY_RATIO then
        return
    end

    options = options or {}
    local bonus = getBonusDefinition(item)
    local coldAtUse = options.forceCold == true or isColdEnough(item)
    if not bonus or not coldAtUse then
        if item then
            debugLog("skip applyMoodBonus: " .. item:getFullType() .. " cold=" .. tostring(coldAtUse) .. " ratio=" .. tostring(ratio))
        end
        return
    end

    local stats = character:getStats()
    if not stats then
        debugLog("skip applyMoodBonus: missing stats")
        return
    end

    local appliedUnhappiness = 0
    local appliedBoredom = 0
    local beforeUnhappiness = stats:get(CharacterStat.UNHAPPINESS)
    local beforeBoredom = stats:get(CharacterStat.BOREDOM)

    if bonus.unhappiness and bonus.unhappiness > 0 then
        appliedUnhappiness = bonus.unhappiness * ratio
        stats:remove(CharacterStat.UNHAPPINESS, appliedUnhappiness)
    end

    if bonus.boredom and bonus.boredom > 0 then
        appliedBoredom = bonus.boredom * ratio
        stats:remove(CharacterStat.BOREDOM, appliedBoredom)
    end

    local afterUnhappiness = stats:get(CharacterStat.UNHAPPINESS)
    local afterBoredom = stats:get(CharacterStat.BOREDOM)

    if options.summary then
        options.summary.totalUnhappiness = (options.summary.totalUnhappiness or 0) + appliedUnhappiness
        options.summary.totalBoredom = (options.summary.totalBoredom or 0) + appliedBoredom
        options.summary.totalRatio = (options.summary.totalRatio or 0) + ratio
        options.summary.appliedSteps = (options.summary.appliedSteps or 0) + 1
        options.summary.lastUnhappiness = afterUnhappiness
        options.summary.lastBoredom = afterBoredom
    else
        debugLog(
            "applied bonus " .. item:getFullType() ..
            " ratio=" .. formatDebugNumber(ratio) ..
            " heat=" .. formatDebugNumber(options.heatOverride or getNormalizedHeat(item)) ..
            " frozen=" .. tostring(isFrozen(item)) ..
            " unhappinessBonus=" .. formatDebugNumber(appliedUnhappiness) ..
            " boredomBonus=" .. formatDebugNumber(appliedBoredom) ..
            " unhappiness=" .. formatDebugNumber(beforeUnhappiness) .. "->" .. formatDebugNumber(afterUnhappiness) ..
            " boredom=" .. formatDebugNumber(beforeBoredom) .. "->" .. formatDebugNumber(afterBoredom)
        )
    end
end

local function logActionState(prefix, item, extra)
    if not ICB.DEBUG then
        return
    end

    local coldState = getColdState(item, { mutate = false })
    local itemType = item and item:getFullType() or "nil"
    local amount = getCurrentAmount(item)
    local message = prefix ..
        " item=" .. itemType ..
        " amount=" .. formatDebugNumber(amount) ..
        " heat=" .. formatDebugNumber(getNormalizedHeat(item)) ..
        " cold=" .. tostring(coldState.cold) ..
        " source=" .. tostring(coldState.source) ..
        " chilling=" .. tostring(coldState.chilling) ..
        " frozen=" .. tostring(isFrozen(item))

    if extra and extra ~= "" then
        message = message .. " " .. extra
    end

    debugLog(message)
end

function ISDrinkFromBottle:start()
    setDrinkSnapshot(self.item)
    logActionState("ISDrinkFromBottle.start", self.item)
    originalDrinkStart(self)
end

function ISDrinkFromBottle:stop()
    clearDrinkSnapshot(self.item)
    originalDrinkStop(self)
end

function ISDrinkFromBottle:drink(food, percentage)
    local coldAtStart = isColdEnough(food)
    local heatAtStart = getNormalizedHeat(food)
    logActionState(
        "ISDrinkFromBottle.drink.before",
        food,
        "percentage=" .. formatDebugNumber(percentage) ..
        " coldAtStart=" .. tostring(coldAtStart)
    )
    local beforeAmount = nil

    if food and food.getFluidContainer and food:getFluidContainer() then
        beforeAmount = food:getFluidContainer():getAmount()
    end

    originalDrink(self, food, percentage)

    if beforeAmount then
        local ratio = getConsumeRatio(food, beforeAmount)
        logActionState(
            "ISDrinkFromBottle.drink.after",
            food,
            "consumedRatio=" .. formatDebugNumber(ratio) ..
            " coldAtStart=" .. tostring(coldAtStart)
        )
        applyMoodBonus(self.character, food, ratio, { forceCold = coldAtStart, heatOverride = heatAtStart })
    end
end

function ISDrinkFluidAction:start()
    self.icbColdAtStart = isColdEnough(self.item)
    self.icbHeatAtStart = getNormalizedHeat(self.item)
    self.icbAppliedConsumedRatio = 0
    self.icbPendingRatio = 0
    setDrinkSnapshot(self.item)
    self.icbSummary = {
        beforeUnhappiness = self.character and self.character:getStats() and self.character:getStats():get(CharacterStat.UNHAPPINESS) or 0,
        beforeBoredom = self.character and self.character:getStats() and self.character:getStats():get(CharacterStat.BOREDOM) or 0,
        totalUnhappiness = 0,
        totalBoredom = 0,
        totalRatio = 0,
        appliedSteps = 0,
    }
    logActionState(
        "ISDrinkFluidAction.start",
        self.item,
        "targetConsumedRatio=" .. formatDebugNumber(self.targetConsumedRatio) ..
        " coldAtStart=" .. tostring(self.icbColdAtStart)
    )
    originalFluidDrinkStart(self)
end

function ISDrinkFluidAction:stop()
    clearDrinkSnapshot(self.item)
    originalFluidStop(self)
end

local function flushPendingFluidBonus(action, force)
    if not action then
        return
    end

    local pendingRatio = action.icbPendingRatio or 0
    if pendingRatio <= 0 then
        return
    end

    if not force and pendingRatio < ICB.MIN_APPLY_RATIO then
        return
    end

    action.icbPendingRatio = 0
    applyMoodBonus(
        action.character,
        action.item,
        pendingRatio,
        { forceCold = action.icbColdAtStart, heatOverride = action.icbHeatAtStart, summary = action.icbSummary }
    )
end

function ISDrinkFluidAction:updateEat(delta)
    local beforeRatio = self.consumedRatio or 0

    originalFluidUpdateEat(self, delta)

    local afterRatio = self.consumedRatio or 0
    local deltaRatio = math.max(0, afterRatio - beforeRatio)

    if deltaRatio > 0 then
        self.icbAppliedConsumedRatio = (self.icbAppliedConsumedRatio or 0) + deltaRatio
        self.icbPendingRatio = (self.icbPendingRatio or 0) + deltaRatio
        flushPendingFluidBonus(self, false)
    end
end

function ISDrinkFluidAction:perform()
    flushPendingFluidBonus(self, true)
    local summary = self.icbSummary or {}
    local stats = self.character and self.character:getStats()
    local afterUnhappiness = stats and stats:get(CharacterStat.UNHAPPINESS) or summary.lastUnhappiness or 0
    local afterBoredom = stats and stats:get(CharacterStat.BOREDOM) or summary.lastBoredom or 0
    debugLog(
        "ISDrinkFluidAction.perform" ..
        " item=" .. (self.item and self.item:getFullType() or "nil") ..
        " startHeat=" .. formatDebugNumber(self.icbHeatAtStart) ..
        " endHeat=" .. formatDebugNumber(getNormalizedHeat(self.item)) ..
        " coldAtStart=" .. tostring(self.icbColdAtStart) ..
        " consumedRatio=" .. formatDebugNumber(self.consumedRatio or 0) ..
        " appliedConsumedRatio=" .. formatDebugNumber(self.icbAppliedConsumedRatio or 0) ..
        " targetConsumedRatio=" .. formatDebugNumber(self.targetConsumedRatio or 0) ..
        " appliedSteps=" .. tostring(summary.appliedSteps or 0) ..
        " totalUnhappinessBonus=" .. formatDebugNumber(summary.totalUnhappiness or 0) ..
        " totalBoredomBonus=" .. formatDebugNumber(summary.totalBoredom or 0) ..
        " unhappiness=" .. formatDebugNumber(summary.beforeUnhappiness or 0) .. "->" .. formatDebugNumber(afterUnhappiness) ..
        " boredom=" .. formatDebugNumber(summary.beforeBoredom or 0) .. "->" .. formatDebugNumber(afterBoredom)
    )
    clearDrinkSnapshot(self.item)
    originalFluidPerform(self)
end

if IceColdBeerTestHooks then
    IceColdBeerTestHooks.isColdContainerType = isColdContainerType
    IceColdBeerTestHooks.getColdContainerSignature = getColdContainerSignature
    IceColdBeerTestHooks.getColdContainerFallbackState = getColdContainerFallbackState
    IceColdBeerTestHooks.getColdState = getColdState
    IceColdBeerTestHooks.isColdEnough = isColdEnough
end

if not isServer() then
    local function tr(key, fallback)
        local text = getText(key)
        if text == key then
            return fallback
        end

        return text
    end

    local function roundToTenth(value)
        return math.floor(value * 10 + 0.5) / 10
    end

    local function formatBonus(value)
        local rounded = roundToTenth(value)
        if rounded == math.floor(rounded) then
            return tostring(math.floor(rounded))
        end

        return string.format("%.1f", rounded)
    end

    local function addTooltipLine(layout, label, value, labelColor, valueColor)
        local line = layout:addItem()
        line:setLabel(label, labelColor.r, labelColor.g, labelColor.b, labelColor.a)
        line:setValue(value, valueColor.r, valueColor.g, valueColor.b, valueColor.a)
    end

    local function addTooltipNote(layout, text, color)
        local line = layout:addItem()
        line:setLabel(text, color.r, color.g, color.b, color.a)
    end

    local function ensureTooltipWidth(tooltip, rows)
        if not tooltip or not rows or #rows == 0 then
            return
        end

        local font = ISToolTip.GetFont()
        local textManager = getTextManager()
        if not font or not textManager then
            return
        end

        local maxLabelWidth = 0
        local maxValueWidth = 0

        for _, row in ipairs(rows) do
            if row.label then
                maxLabelWidth = math.max(maxLabelWidth, textManager:MeasureStringX(font, row.label))
            end
            if row.value then
                maxValueWidth = math.max(maxValueWidth, textManager:MeasureStringX(font, row.value))
            end
        end

        local requiredWidth = math.ceil(maxLabelWidth + maxValueWidth + 28)
        if requiredWidth > tooltip:getWidth() then
            tooltip:setWidth(requiredWidth)
        end
    end

    local function appendColdDrinkTooltip(tooltip, item)
        if not item or not prefersCold(item) then
            return
        end

        if ICB.DEBUG then
            local coldState = getColdState(item, { mutate = false })
            local debugKey = table.concat({
                item:getFullType(),
                tostring(coldState.cold),
                tostring(coldState.chilling),
                tostring(isFrozen(item)),
                tostring(getNormalizedHeat(item)),
            }, "|")
            if ICB.lastTooltipKey ~= debugKey then
                ICB.lastTooltipKey = debugKey
                debugLog("tooltip " .. debugKey)
            end
        end

        local baseY = math.max(5, tooltip:getHeight() - 5)
        local layout = tooltip:beginLayout()
        local labelColor = { r = 1, g = 1, b = 1, a = 1 }
        local coldColor = { r = 0.5, g = 0.8, b = 1, a = 1 }
        local bonusColor = { r = 0.7, g = 1, b = 0.7, a = 1 }
        local widthRows = {}
        local coldState = getColdState(item, { mutate = false })

        if coldState.cold then
            local scaledBonus = getScaledBonus(item)
            if not scaledBonus then
                return
            end

            local temperatureLabel = tr("Tooltip_item_Temperature", tr("Tooltip_icb_Temperature", "Temperature")) .. ":"
            local temperatureValue = tr("Tooltip_icb_Cold", "Cold")
            local unhappinessLabel = tr("Tooltip_icb_ColdUnhappinessBonus", "Cold Unhappiness Bonus") .. ":"
            local unhappinessValue = "-" .. formatBonus(scaledBonus.unhappiness)
            local boredomLabel = tr("Tooltip_icb_ColdBoredomBonus", "Cold Boredom Bonus") .. ":"
            local boredomValue = "-" .. formatBonus(scaledBonus.boredom)

            table.insert(widthRows, { label = temperatureLabel, value = temperatureValue })
            table.insert(widthRows, { label = unhappinessLabel, value = unhappinessValue })
            table.insert(widthRows, { label = boredomLabel, value = boredomValue })
            ensureTooltipWidth(tooltip, widthRows)

            addTooltipLine(layout, temperatureLabel, temperatureValue, labelColor, coldColor)
            addTooltipLine(layout, unhappinessLabel, unhappinessValue, labelColor, bonusColor)
            addTooltipLine(layout, boredomLabel, boredomValue, labelColor, bonusColor)
        elseif coldState.chilling then
            addTooltipNote(layout, tr("Tooltip_icb_Chilling", "Chilling..."), coldColor)
        else
            addTooltipNote(layout, tr("Tooltip_icb_BetterCold", "Better cold."), coldColor)
        end

        local y = layout:render(5, baseY, tooltip)
        tooltip:setHeight(y + 5)
        tooltip:endLayout(layout)
    end

    local function patchDrinkContextMenu()
        require "ISUI/ISInventoryPaneContextMenu"

        if ICB.drinkContextMenuPatched then
            return
        end

        ISInventoryPaneContextMenu.doDrinkFluidMenu = function(playerObj, fluidContainer, context)
            local item = instanceof(fluidContainer, "IsoWorldInventoryObject") and fluidContainer:getItem() or fluidContainer
            if not item or not item.getFluidContainer then
                return
            end

            local itemFluidContainer = item:getFluidContainer()
            if not itemFluidContainer then
                return
            end

            local customMenuOption = item.getCustomMenuOption and item:getCustomMenuOption() or nil
            local jobType = item.getJobType and item:getJobType() or nil
            local jobDelta = item.getJobDelta and item:getJobDelta() or 0

            if jobDelta > 0 and (jobType == getText("ContextMenu_Drink") or (customMenuOption and jobType == customMenuOption)) then
                return
            end

            local openingRecipe = item:getOpeningRecipe()
            if not item:isSealed() then
                openingRecipe = nil
            end
            if openingRecipe and getScriptManager():getCraftRecipe(openingRecipe) then
                openingRecipe = getScriptManager():getCraftRecipe(openingRecipe)
            else
                openingRecipe = nil
            end
            if openingRecipe then
                local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
                local logic = HandcraftLogic.new(playerObj, nil, nil)

                logic:setContainers(containers)
                logic:setRecipeFromContextClick(openingRecipe, item)
                if not logic:canPerformCurrentRecipe() then
                    openingRecipe = nil
                end
            end

            local cmd = customMenuOption or getText("ContextMenu_Drink")
            if openingRecipe then
                cmd = customMenuOption or getText("ContextMenu_OpenAndDrink")
            end

            local eatOption = context:addOption(cmd, fluidContainer, nil)
            eatOption.itemForTexture = item

            if not itemFluidContainer:canPlayerEmpty() and not openingRecipe then
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                eatOption.notAvailable = true
                tooltip.description = getText("Tooltip_item_sealed")
                eatOption.toolTip = tooltip
            elseif playerObj:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) >= 3 and itemFluidContainer:getProperties():getHungerChange() ~= 0 then
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                eatOption.notAvailable = true
                tooltip.description = getText("Tooltip_CantEatMore")
                eatOption.toolTip = tooltip
            elseif itemFluidContainer:getCapacity() > 3.0 then
                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                eatOption.notAvailable = true
                tooltip.description = getText("Tooltip_CantDrinkFrom")
                eatOption.toolTip = tooltip
            else
                local subMenuEat = context:getNew(context)
                context:addSubMenu(eatOption, subMenuEat)
                subMenuEat:addOption(getText("ContextMenu_Eat_All"), fluidContainer, ISInventoryPaneContextMenu.onDrinkFluid, 1, playerObj, openingRecipe, item)

                local capacity = itemFluidContainer:getCapacity()
                local amount = itemFluidContainer:getAmount()
                local baseThirst = amount / capacity
                if baseThirst >= 0.5 then
                    subMenuEat:addOption(getText("ContextMenu_Eat_Half"), fluidContainer, ISInventoryPaneContextMenu.onDrinkFluid, 0.5, playerObj, openingRecipe, item)
                end
                if baseThirst >= 0.25 then
                    subMenuEat:addOption(getText("ContextMenu_Eat_Quarter"), fluidContainer, ISInventoryPaneContextMenu.onDrinkFluid, 0.25, playerObj, openingRecipe, item)
                end
            end
        end

        ICB.drinkContextMenuPatched = true
        debugLog("drink context menu patched version=" .. ICB.VERSION)
    end

    local function forEachContainerItem(container, callback, visitedContainers)
        if not container or not callback then
            return
        end

        visitedContainers = visitedContainers or {}
        if visitedContainers[container] then
            return
        end
        visitedContainers[container] = true

        local okItems, items = safeCallMethod(container, "getItems")
        if not okItems or not items then
            return
        end

        local size = items:size()
        for i = 0, size - 1 do
            local item = items:get(i)
            callback(item)

            if item and item.IsInventoryContainer and item:IsInventoryContainer() and item.getInventory then
                local okInventory, nestedInventory = safeCallMethod(item, "getInventory")
                if okInventory and nestedInventory then
                    forEachContainerItem(nestedInventory, callback, visitedContainers)
                end
            end
        end
    end

    local function refreshTrackedItem(item)
        if not item or not prefersCold(item) then
            return
        end

        getColdState(item, { mutate = true })
    end

    local function refreshKnownColdTracking()
        local visitedContainers = {}

        local playerObj = getPlayer()
        if playerObj and playerObj.getInventory then
            local okInventory, inventory = safeCallMethod(playerObj, "getInventory")
            if okInventory and inventory then
                forEachContainerItem(inventory, refreshTrackedItem, visitedContainers)
            end
        end

        local playerNum = playerObj and playerObj:getPlayerNum() or 0
        local inventoryPage = getPlayerInventory and getPlayerInventory(playerNum) or nil
        local lootPage = getPlayerLoot and getPlayerLoot(playerNum) or nil
        local pages = { inventoryPage, lootPage }

        for _, page in ipairs(pages) do
            if page and page.backpacks then
                for _, button in ipairs(page.backpacks) do
                    if button and button.inventory then
                        forEachContainerItem(button.inventory, refreshTrackedItem, visitedContainers)
                    end
                end
            elseif page and page.inventoryPane and page.inventoryPane.inventory then
                forEachContainerItem(page.inventoryPane.inventory, refreshTrackedItem, visitedContainers)
            end
        end
    end

    local function installTooltipHooks()
        if ICB.tooltipsInstalled then
            return
        end

        require "ISUI/ISToolTipInv"
        require "Entity/ISUI/Controls/ISItemSlot"

        function ISToolTipInv:render()
            if not ISContextMenu.instance or not ISContextMenu.instance.visibleCheck then
                local mx = getMouseX() + 24
                local my = getMouseY() + 24
                if not self.followMouse then
                    mx = self:getX()
                    my = self:getY()
                    if self.anchorBottomLeft then
                        mx = self.anchorBottomLeft.x
                        my = self.anchorBottomLeft.y
                    end
                end

                local PADX = 0

                self.tooltip:setX(mx + PADX)
                self.tooltip:setY(my)

                self.tooltip:setWidth(50)
                self.tooltip:setMeasureOnly(true)
                if self.item then
                    self.item:DoTooltip(self.tooltip)
                    appendColdDrinkTooltip(self.tooltip, self.item)
                end
                self.tooltip:setMeasureOnly(false)

                local myCore = getCore()
                local maxX = myCore:getScreenWidth()
                local maxY = myCore:getScreenHeight()

                local tw = self.tooltip:getWidth()
                local th = self.tooltip:getHeight()

                self.tooltip:setX(math.max(0, math.min(mx + PADX, maxX - tw - 1)))
                if not self.followMouse and self.anchorBottomLeft then
                    self.tooltip:setY(math.max(0, math.min(my - th, maxY - th - 1)))
                else
                    self.tooltip:setY(math.max(0, math.min(my, maxY - th - 1)))
                end

                if self.contextMenu and self.contextMenu.joyfocus then
                    local playerNum = self.contextMenu.player
                    self.tooltip:setX(getPlayerScreenLeft(playerNum) + 60)
                    self.tooltip:setY(getPlayerScreenTop(playerNum) + 60)
                elseif self.contextMenu and self.contextMenu.currentOptionRect then
                    if self.contextMenu.currentOptionRect.height > 32 then
                        self:setY(my + self.contextMenu.currentOptionRect.height)
                    end
                    self:adjustPositionToAvoidOverlap(self.contextMenu.currentOptionRect)
                end

                self:setX(self.tooltip:getX() - PADX)
                self:setY(self.tooltip:getY())
                self:setWidth(tw + PADX)
                self:setHeight(th)

                if self.followMouse and self.contextMenu == nil then
                    self:adjustPositionToAvoidOverlap({ x = mx - 24 * 2, y = my - 24 * 2, width = 24 * 2, height = 24 * 2 })
                end

                self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
                self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
                if self.item then
                    self.item:DoTooltip(self.tooltip)
                    appendColdDrinkTooltip(self.tooltip, self.item)
                end
            end
        end

        local originalDrawTooltip = ISItemSlot.drawTooltip

        ISItemSlot.drawTooltip = function(itemSlot, tooltip)
            originalDrawTooltip(itemSlot, tooltip)

            if itemSlot.resource then
                appendColdDrinkTooltip(tooltip, itemSlot.resource)
            elseif itemSlot.storedItem then
                appendColdDrinkTooltip(tooltip, itemSlot.storedItem)
            end
        end

        ICB.tooltipsInstalled = true
        debugLog("tooltip hooks installed version=" .. ICB.VERSION)
    end

    Events.OnGameBoot.Add(patchDrinkContextMenu)
    Events.OnGameBoot.Add(installTooltipHooks)
    if Events.OnContainerUpdate then
        Events.OnContainerUpdate.Add(refreshKnownColdTracking)
    end
    if Events.EveryOneMinute then
        Events.EveryOneMinute.Add(refreshKnownColdTracking)
    end
end
