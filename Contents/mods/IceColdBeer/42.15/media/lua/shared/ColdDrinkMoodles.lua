require "TimedActions/ISDrinkFromBottle"

local ICB = {
    COLD_THRESHOLD = -0.1,
    TARGETS = {
        ["Base.BeerBottle"] = { unhappiness = 2.0, boredom = 1.0 },
        ["Base.BeerCan"] = { unhappiness = 2.0, boredom = 1.0 },
        ["Base.BeerImported"] = { unhappiness = 2.0, boredom = 1.0 },
        ["Base.Wine"] = { unhappiness = 4.0, boredom = 2.0 },
        ["Base.WineOpen"] = { unhappiness = 4.0, boredom = 2.0 },
    },
}

local originalDrink = ISDrinkFromBottle.drink

local function getConsumeRatio(item, beforeAmount)
    if not item or not item.getFluidContainer then
        return 0
    end

    local container = item:getFluidContainer()
    if not container then
        return 0
    end

    local capacity = container:getCapacity()
    if not capacity or capacity <= 0 then
        return 0
    end

    local consumed = beforeAmount - container:getAmount()
    if consumed <= 0 then
        return 0
    end

    return consumed / capacity
end

local function getRemainingRatio(item)
    if not item or not item.getFluidContainer then
        return 0
    end

    local container = item:getFluidContainer()
    if not container then
        return 0
    end

    local capacity = container:getCapacity()
    if not capacity or capacity <= 0 then
        return 0
    end

    return container:getAmount() / capacity
end

local function isFrozen(item)
    if not item then
        return false
    end

    local ok, result = pcall(function()
        return item:isFrozen()
    end)

    return ok and result or false
end

local function isColdEnough(item)
    return item and item:getInvHeat() < ICB.COLD_THRESHOLD and not isFrozen(item)
end

local function getScaledBonus(item)
    local bonus = item and ICB.TARGETS[item:getFullType()]
    if not bonus then
        return nil
    end

    local ratio = math.max(0, math.min(1, getRemainingRatio(item)))

    return {
        unhappiness = bonus.unhappiness * ratio,
        boredom = bonus.boredom * ratio,
    }
end

local function applyMoodBonus(character, item, ratio)
    if not character or not item or ratio <= 0 then
        return
    end

    local bonus = item and ICB.TARGETS[item:getFullType()]
    if not bonus or not isColdEnough(item) then
        return
    end

    local stats = character:getStats()
    if not stats then
        return
    end

    if bonus.unhappiness and bonus.unhappiness > 0 then
        stats:remove(CharacterStat.UNHAPPINESS, bonus.unhappiness * ratio)
    end

    if bonus.boredom and bonus.boredom > 0 then
        stats:remove(CharacterStat.BOREDOM, bonus.boredom * ratio)
    end
end

function ISDrinkFromBottle:drink(food, percentage)
    local beforeAmount = nil

    if food and food.getFluidContainer and food:getFluidContainer() then
        beforeAmount = food:getFluidContainer():getAmount()
    end

    originalDrink(self, food, percentage)

    if beforeAmount then
        applyMoodBonus(self.character, food, getConsumeRatio(food, beforeAmount))
    end
end

if not isServer() then
    require "ISUI/ISToolTipInv"
    require "Entity/ISUI/Controls/ISItemSlot"

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

    local function appendColdDrinkTooltip(tooltip, item)
        if not item or not isColdEnough(item) then
            return
        end

        local scaledBonus = getScaledBonus(item)
        if not scaledBonus then
            return
        end

        local layout = tooltip:beginLayout()
        local labelColor = { r = 1, g = 1, b = 1, a = 1 }
        local coldColor = { r = 0.5, g = 0.8, b = 1, a = 1 }
        local bonusColor = { r = 0.7, g = 1, b = 0.7, a = 1 }

        addTooltipLine(layout, tr("Tooltip_icb_Temperature", "Temperature"), tr("Tooltip_icb_Cold", "Cold"), labelColor, coldColor)
        addTooltipLine(layout, tr("Tooltip_icb_ColdUnhappinessBonus", "Cold Unhappiness Bonus"), "-" .. formatBonus(scaledBonus.unhappiness), labelColor, bonusColor)
        addTooltipLine(layout, tr("Tooltip_icb_ColdBoredomBonus", "Cold Boredom Bonus"), "-" .. formatBonus(scaledBonus.boredom), labelColor, bonusColor)

        tooltip:endLayout(layout)
    end

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
end
