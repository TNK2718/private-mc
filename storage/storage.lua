local basalt = require("basalt")
local frame = basalt.createFrame()

-- Peripherals
local chestSide = "back"
local chest = peripheral.wrap("back")
if not chest then
    error("Chest peripheral not found!")
end
local targetSide = "left"

-- UI
local searchInput = frame:addInput()
    :setWidth(20)
    :setX(2)
    :setY(2)
    :setPlaceholder("Search item...")

local searchButton = frame:addButton()
    :setHeight(3)
    :setText("Search")
    :setX(23)
    :setY(1)

-- Item list
local itemList = frame:addList()
    :setWidth(35)
    :setHeight(20)
    :setX(2)
    :setY(8)

-- Item detail
local detailList = frame:addList()
    :setWidth(30)
    :setHeight(20)
    :setX(38)
    :setY(8)

-- Paging buttons
local prevPageButton = frame:addButton()
    :setText("<--")
    :setWidth(6)
    :setX(2)
    :setY(29)

local nextPageButton = frame:addButton()
    :setText("-->")
    :setWidth(6)
    :setX(9)
    :setY(29)

local withdrawButton = frame:addButton()
    :setText("Withdraw")
    :setX(16)
    :setY(29)

local withdrawAllButton = frame:addButton()
    :setText("Withdraw All")
    :setWidth(14)
    :setX(35)
    :setY(29)

-- Filters
local ingotsFilterButton = frame:addButton()
    :setText("Diamond: OFF")
    :setWidth(16)
    :setX(2)
    :setY(5)

local toolsFilterButton = frame:addButton()
    :setText("Tool: OFF")
    :setWidth(16)
    :setX(19)
    :setY(5)

local skillbooksFilterButton = frame:addButton()
    :setText("Skillbook: OFF")
    :setWidth(16)
    :setX(36)
    :setY(5)

local mapsFilterButton = frame:addButton()
    :setText("Maps: OFF")
    :setWidth(14)
    :setX(53)
    :setY(5)

local statSoulFilterButton = frame:addButton()
    :setText("StatSoul: OFF")
    :setWidth(16)
    :setX(68)
    :setY(5)

local soulslikeFilterButton = frame:addButton()
    :setText("Soulslike: OFF")
    :setWidth(16)
    :setX(36)
    :setY(1)

local runesFilterButton = frame:addButton()
    :setText("Runes: OFF")
    :setWidth(14)
    :setX(53)
    :setY(1)

local gemsFilterButton = frame:addButton()
    :setText("Gems: OFF")
    :setWidth(16)
    :setX(68)
    :setY(1)

-- Paging state
local allItems = {}
local currentPage = 1
local itemsPerPage = 20

local function returnWithdrawnItems()
    local targetInv = peripheral.wrap(targetSide)
    if targetInv then
        for slot, item in pairs(targetInv.list() or {}) do
            if item and item.count > 0 then
                targetInv.pushItems("back", slot, item.count)
            end
        end
    else
        basalt.LOGGER.warn("Target inventory not found!")
    end
end

local function getItemDetail(item, slot)
    if not item then
        return {"No details available"}
    end
    local details = {
        "Slot: " .. slot,
        "Name: " .. item.name,
        "Count: " .. item.count,
    }
    local detailData = chest.getItemDetail(slot)
    if detailData and detailData.tags then
        for key, value in pairs(detailData.tags) do
            if value then
                table.insert(details, key)
            end
        end
    end
    return details
end

local function updatePage()
    itemList:clear()
    local startIndex = (currentPage - 1) * itemsPerPage + 1
    local endIndex = math.min(#allItems, currentPage * itemsPerPage)
    for i = startIndex, endIndex do
        itemList:addItem(allItems[i])
    end
    detailList:clear()
end

local function searchTag(data, query)
    if data.tags then
        for key, value in pairs(data.tags) do
            if value and key:lower():find(query) then
                return true
            end
        end
    end
    return false
end

local function updateItemList(skipReturn)
    if not skipReturn then
        returnWithdrawnItems()
    end
    local query = searchInput:getText():lower()
    allItems = {}
    local items = chest.list() or {}
    for slot, item in pairs(items) do
        local nameLower = item.name:lower()
        local pass = true
        if query ~= "" then
            pass = pass and (string.find(nameLower, query) ~= nil)
        end
        if ingotsFilterActive then
            local detailData = chest.getItemDetail(slot)
            filterPass = (string.find(nameLower, "ingot") ~= nil) or (string.find(nameLower, "minecraft:diamond") ~= nil) or (string.find(nameLower, "minecraft:netherite") ~= nil) or (string.find(nameLower, "emerald") ~= nil)
            filterPass = filterPass or (string.find(nameLower, "minecraft:blaze") ~= nil) or (string.find(nameLower, "minecraft:redstone") ~= nil) or (string.find(nameLower, "pearl") ~= nil) or (string.find(nameLower, "saddle") ~= nil)
            filterPass = filterPass or (string.find(nameLower, "minecraft:lapis") ~= nil) or (string.find(nameLower, "home_pearl") ~= nil) or (string.find(nameLower, "smithing_template") ~= nil)
            filterPass = filterPass or (string.find(nameLower, "wanderlite") ~= nil) or (string.find(nameLower, "totem_of_undying") ~= nil) or searchTag(detailData, "forge:raw_materials")
            pass = pass and filterPass
        end
        if toolsFilterActive then
            local detailData = chest.getItemDetail(slot)
            filterPass = (string.find(nameLower, "weapon") ~= nil) or (string.find(nameLower, "bow") ~= nil) or (string.find(nameLower, "crossbow") ~= nil) or searchTag(detailData, "minecraft:tools") or searchTag(detailData, "armor")
            pass = pass and filterPass
        end
        if skillbooksFilterActive then
            -- local detailData = chest.getItemDetail(slot)
            filterPass = (string.find(nameLower, "epicfight:skillbook") ~= nil)
            pass = pass and filterPass
        end
        if mapsFilterActive then
            -- local detailData = chest.getItemDetail(slot)
            filterPass = (string.find(nameLower, "mmorpg:maps") ~= nil) or (string.find(nameLower, "uber_fragment") ~= nil) or (string.find(nameLower, "harvest_map") ~= nil) or (string.find(nameLower, "obelisk_map") ~= nil) or (string.find(nameLower, "coin/phophecy") ~= nil)
            pass = pass and filterPass
        end
        if statSoulFilterActive then
            -- local detailData = chest.getItemDetail(slot)
            filterPass = (string.find(nameLower, "stat_soul") ~= nil)
            pass = pass and filterPass
        end
        if soulslikeFilterActive then
            -- local detailData = chest.getItemDetail(slot)
            filterPass = (string.find(nameLower, "slu:") ~= nil)
            pass = pass and filterPass
        end
        if runesFilterActive then
            -- local detailData = chest.getItemDetail(slot)
            filterPass = (string.find(nameLower, "mmorpg:runes") ~= nil)
            pass = pass and filterPass
        end
        if gemsFilterActive then
            -- local detailData = chest.getItemDetail(slot)
            filterPass = (string.find(nameLower, "mmorpg:skill_gems") ~= nil)
            pass = pass and filterPass
        end

        if pass then
            local displayText = "S" .. slot .. ": " .. item.name
            table.insert(allItems, displayText)
        end
    end
    currentPage = 1
    updatePage()
end

itemList:onSelect(function(index)
    detailList:clear()
    local selectedItem = itemList:getSelectedItem()
    if selectedItem then
        local slot = tonumber(selectedItem.text:match("S(%d+):"))
        if slot then
            local itemData = chest.list()[slot]
            if itemData then
                local details = getItemDetail(itemData, slot)
                for _, line in ipairs(details) do
                    detailList:addItem(line)
                end
            else
                detailList:addItem("No item found.")
            end
        else
            detailList:addItem("Invalid selection.")
        end
    end
end)

-- onClick Events
searchButton:onClick(function()
    updateItemList()
end)

prevPageButton:onClick(function()
    if currentPage > 1 then
        currentPage = currentPage - 1
        updatePage()
    end
end)

nextPageButton:onClick(function()
    local maxPage = math.ceil(#allItems / itemsPerPage)
    if currentPage < maxPage then
        currentPage = currentPage + 1
        updatePage()
    end
end)

withdrawButton:onClick(function()
    local selected = itemList:getSelectedItem()
    if selected then
        local slot = tonumber(selected.text:match("S(%d+):"))
        if slot then
            local itemData = chest.list()[slot]
            if itemData then
                local count = itemData.count
                local transferred = chest.pushItems(targetSide, slot, count)
                if transferred > 0 then
                    basalt.LOGGER.info("Withdrew " .. transferred .. " items from slot " .. slot)
                    updateItemList(true)  -- Skip return process
                    detailList:clear()
                else
                    basalt.LOGGER.warn("Failed to withdraw items from slot " .. slot)
                end
            else
                basalt.LOGGER.warn("No item found in slot " .. slot)
            end
        else
            basalt.LOGGER.warn("Could not determine slot from selected item")
        end
    else
        basalt.LOGGER.warn("No item selected")
    end
end)

withdrawAllButton:onClick(function()
    local startIndex = (currentPage - 1) * itemsPerPage + 1
    local endIndex = math.min(#allItems, currentPage * itemsPerPage)
    local items = chest.list() or {}
    local anyWithdrawn = false
    for i = startIndex, endIndex do
        local displayText = allItems[i]
        local slot = tonumber(displayText:match("S(%d+):"))
        if slot then
            local itemData = items[slot]
            if itemData then
                local count = itemData.count
                local transferred = chest.pushItems(targetSide, slot, count)
                if transferred > 0 then
                    basalt.LOGGER.info("Withdrew " .. transferred .. " items from slot " .. slot)
                    anyWithdrawn = true
                else
                    basalt.LOGGER.warn("Failed to withdraw items from slot " .. slot)
                end
            end
        end
    end
    if anyWithdrawn then
        updateItemList(true) -- Skip return process
        detailList:clear()
    else
        basalt.LOGGER.warn("No items withdrawn")
    end
end)

ingotsFilterButton:onClick(function()
    ingotsFilterActive = not ingotsFilterActive
    if ingotsFilterActive then
        ingotsFilterButton:setText("Diamond: ON")
    else
        ingotsFilterButton:setText("Diamond: OFF")
    end
    updateItemList()
end)

toolsFilterButton:onClick(function()
    toolsFilterActive = not toolsFilterActive
    if toolsFilterActive then
        toolsFilterButton:setText("Tool: ON")
    else
        toolsFilterButton:setText("Tool: OFF")
    end
    updateItemList()
end)

skillbooksFilterButton:onClick(function()
    skillbooksFilterActive = not skillbooksFilterActive
    if skillbooksFilterActive then
        skillbooksFilterButton:setText("Skillbook: ON")
    else
        skillbooksFilterButton:setText("Skillbook: OFF")
    end
    updateItemList()
end)

mapsFilterButton:onClick(function()
    mapsFilterActive = not mapsFilterActive
    if mapsFilterActive then
        mapsFilterButton:setText("Maps: ON")
    else
        mapsFilterButton:setText("Maps: OFF")
    end
    updateItemList()
end)

statSoulFilterButton:onClick(function()
    statSoulFilterActive = not statSoulFilterActive
    if statSoulFilterActive then
        statSoulFilterButton:setText("StatSoul: ON")
    else
        statSoulFilterButton:setText("StatSoul: OFF")
    end
    updateItemList()
end)

soulslikeFilterButton:onClick(function()
    soulslikeFilterActive = not soulslikeFilterActive
    if soulslikeFilterActive then
        soulslikeFilterButton:setText("Soulslike: ON")
    else
        soulslikeFilterButton:setText("Soulslike: OFF")
    end
    updateItemList()
end)

runesFilterButton:onClick(function()
    runesFilterActive = not runesFilterActive
    if runesFilterActive then
        runesFilterButton:setText("Runes: ON")
    else
        runesFilterButton:setText("Runes: OFF")
    end
    updateItemList()
end)

gemsFilterButton:onClick(function()
    gemsFilterActive = not gemsFilterActive
    if gemsFilterActive then
        gemsFilterButton:setText("Gems: ON")
    else
        gemsFilterButton:setText("Gems: OFF")
    end
    updateItemList()
end)

basalt.run()
