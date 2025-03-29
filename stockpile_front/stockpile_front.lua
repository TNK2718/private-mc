-- Desc: A front-end for the stockpile server
local storageUnit = "all"
local portUnit = "port"

-- Rednet init
rednet.open("back")
local serverID = rednet.lookup("stockpile")
if not serverID then
    print("Stockpile server not found.")
    return
end

-- Get port inventories
local adjacentsNames = {
    "front",
    "back",
    "left",
    "right",
    "top",
    "bottom"
}
local port_invs = {}
for _, p in ipairs(peripheral.getNames()) do
    if peripheral.hasType(p, "inventory") then
        -- Don't count adjacent inventories as storage
        local isAdjacent = false
        for _, name in ipairs(adjacentsNames) do
            if p == name then
                isAdjacent = true
                break
            end
        end

        if not isAdjacent and p:find("minecraft:chest") then
            table.insert(port_invs, p)
        end
    end
end

function sendCommand(command)
    print("Sending command: " .. command)
    rednet.send(serverID, command, "stockpile")
    local senderID, message, protocol = rednet.receive("stockpile", 5)
    if message then
        print("Got response:")
        if type(message) == "table" then
            print(textutils.serialize(message))
        else
            print(message)
        end
    else
        print("No response.")
    end
    return message
end

-- portUnit init
local command_set = "unit.set('" .. portUnit .. "', " .. textutils.serialize(port_invs) .. ")"
sendCommand(command_set)

local command_is_io = "unit.is_io('" .. portUnit .. "', true)"
sendCommand(command_is_io)

-- Get unit data
local command_get = "unit.get()"
rednet.send(serverID, command_get, "stockpile")
local senderID, unitData, protocol = rednet.receive("stockpile", 5)
if not unitData then
    print("unit.get() no response.")
    rednet.close("back")
    return
end
if type(unitData) ~= "table" then
    unitData = textutils.unserialize(unitData)
end

local storage_invs = unitData[1][storageUnit]
if not storage_invs or type(storage_invs) ~= "table" then
    print("'" .. storageUnit .. "' does not exist in the unit data.")
    print(textutils.serialize(unitData))
    rednet.close("back")
    return
end

-- Basalt init
local backColor = colors.black
local textColor = colors.green
local fieldBackColor = colors.gray
local buttonColor = colors.gray

local basalt = require("basalt")
local frame = basalt.createFrame():setBackground(backColor):setForeground(textColor)

-- UI
local searchInput = frame:addInput()
    :setWidth(20)
    :setX(2)
    :setY(2)
    :setPlaceholder("Search item...")
    :setBackground(fieldBackColor)
    :setForeground(textColor)
    :setPlaceholderColor(colors.white)

local nbtSearchInput = frame:addInput()
    :setWidth(20)
    :setX(23)
    :setY(2)
    :setPlaceholder("Search NBT...")
    :setBackground(fieldBackColor)
    :setForeground(textColor)
    :setPlaceholderColor(colors.white)

local searchButton = frame:addButton()
    :setHeight(3)
    :setText("Search")
    :setX(44)
    :setY(1)
    :setBackground(buttonColor)
    :setForeground(textColor)

local clearButton = frame:addButton()
    :setHeight(3)
    :setText("Clear")
    :setX(56)
    :setY(1)
    :setBackground(buttonColor)
    :setForeground(textColor)

-- Paging buttons
local prevPageButton = frame:addButton()
    :setText("<--")
    :setWidth(6)
    :setX(38)
    :setY(29)
    :setBackground(buttonColor)
    :setForeground(textColor)

local nextPageButton = frame:addButton()
    :setText("-->")
    :setWidth(6)
    :setX(45)
    :setY(29)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local withdrawButton = frame:addButton()
    :setText("Withdraw")
    :setX(52)
    :setY(29)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local withdrawAllButton = frame:addButton()
    :setText("Withdraw All")
    :setWidth(14)
    :setX(65)
    :setY(29)
    :setBackground(buttonColor)
    :setForeground(textColor)

local depositButton = frame:addButton()
    :setText("Deposit")
    :setX(68)
    :setY(25)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
-- Filters
local ingotsFilterButton = frame:addButton()
    :setHeight(1)
    :setText("Diamonds")
    :setWidth(16)
    :setX(2)
    :setY(5)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local toolsFilterButton = frame:addButton()
    :setHeight(1)
    :setText("Tools")
    :setWidth(16)
    :setX(19)
    :setY(5)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local skillbooksFilterButton = frame:addButton()
    :setHeight(1)
    :setText("Skillbooks")
    :setWidth(16)
    :setX(36)
    :setY(5)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local mapsFilterButton = frame:addButton()
    :setHeight(1)
    :setText("Maps")
    :setWidth(14)
    :setX(53)
    :setY(5)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local statSoulFilterButton = frame:addButton()
    :setHeight(1)
    :setText("StatSouls")
    :setWidth(16)
    :setX(68)
    :setY(5)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local soulslikeFilterButton = frame:addButton()
    :setHeight(1)
    :setText("Soulslike")
    :setWidth(16)
    :setX(68)
    :setY(7)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local runesFilterButton = frame:addButton()
    :setHeight(1)
    :setText("Runes")
    :setWidth(14)
    :setX(68)
    :setY(9)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
local gemsFilterButton = frame:addButton()
    :setHeight(1)
    :setText("Gems")
    :setWidth(16)
    :setX(68)
    :setY(1)
    :setBackground(buttonColor)
    :setForeground(textColor)
    
-- Item list
local itemList = frame:addList()
    :setWidth(35)
    :setHeight(27)
    :setX(2)
    :setY(7)
    :setBackground(backColor)
    :setForeground(textColor)

-- Item detail
local detailList = frame:addList()
    :setWidth(30)
    :setHeight(20)
    :setX(38)
    :setY(8)
    :setBackground(backColor)
    :setForeground(textColor)

function escape_lua_pattern(s)
    -- Escape targets: ( ) . % + - * ? [ ] ^ $
    return s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- APIs
function scan(invs)
    local command_scan = "scan(" .. textutils.serialize(invs) .. ")"
    rednet.send(serverID, command_scan, "stockpile")

    local senderID, scanResponse, protocol2 = rednet.receive("stockpile", 5)
    if scanResponse then
    else
        print("No response.")
    end

    return scanResponse[1]
end

function moveItem(itemName, from_invs, to_invs, qty, nbt_regex_filter)
    local item_name_str = itemName and "'" .. itemName .. "'" or "nil"
    item_name_str = escape_lua_pattern(item_name_str)
    local qty_str = qty and tostring(qty) or "nil"
    local nbt_regex_filter = nbt_regex_filter or ""
    local command_move = "move_item(" .. textutils.serialize(from_invs) .. ", " ..
                                    textutils.serialize(to_invs) .. ", " ..
                                    item_name_str .. ", " .. qty_str .. ", '" .. nbt_regex_filter .. "')"
    rednet.send(serverID, command_move, "stockpile")

    local senderID, moveResponse, protocol2 = rednet.receive("stockpile", 5)
    if moveResponse then
        io.output("latest_log.txt"):write(textutils.serialize(moveResponse)):close()
    else
        print("No response.")
  end
end

function getContent()
    local command_get = "get_content()"
    rednet.send(serverID, command_get, "stockpile")

    local senderID, contentData, protocol2 = rednet.receive("stockpile", 5)
    if contentData then
        -- io.output("latest_log.txt"):write(textutils.serialize(contentData)):close()
    else
        print("No response.")
    end

    return contentData[1]
end

function search()
    local command_search = "search('" .. escape_lua_pattern(searchInput:getText()) .. "', '" .. escape_lua_pattern(nbtSearchInput:getText()) .. "')"
    rednet.send(serverID, command_search, "stockpile")

    local senderID, searchResponse, protocol2 = rednet.receive("stockpile", 5)
    if searchResponse then
    else
        print("No response.")
    end

    return searchResponse[1]
end

-- Paging state
local allItems = {}
local currentPage = 1
local itemsPerPage = 27

local function returnWithdrawnItems()
    moveItem(nil, port_invs, storage_invs, nil, "")
end

local function updatePage()
    itemList:clear()
    local startIndex = (currentPage - 1) * itemsPerPage + 1
    local endIndex = math.min(#allItems, currentPage * itemsPerPage)
    for i = startIndex, endIndex do
        local itemName = allItems[i]["itemName"]
        local itemNum = allItems[i]["itemNum"]
        itemList:addItem("#" .. i .. ": " .. itemName .. " (" .. itemNum .. ")")
    end
    detailList:clear()
end

local function updateItemList(skipReturn)
    if not skipReturn then
        returnWithdrawnItems()
    end
    scan(storage_invs)

    allItems = {}
    local contents = getContent()["item_index"]
    if not contents then
        print("No items found.")
        return
    end
    local items = search()
    local count = 0
    for itemName, itemNum in pairs(items) do
        count = count + 1
        local content = contents[itemName]
        content["itemName"] = itemName
        content["itemNum"] = itemNum
        table.insert(allItems, content)
    end

    currentPage = 1
    updatePage()
end

itemList:onSelect(function()
    detailList:clear()
    local selectedItem = itemList:getSelectedItem()
    if selectedItem then
        local index = tonumber(selectedItem.text:match("#(%d+):"))
        if index then
            detailList:addItem("Display Name: " .. allItems[index]["nbt"]["displayName"])
            detailList:addItem("Item Name: " .. allItems[index]["itemName"])
            detailList:addItem("Item Count: " .. allItems[index]["total"])
            -- nbts
            local nbt = allItems[index]["nbt"]
            if nbt["tags"] then
                for key, _ in pairs(nbt["tags"]) do
                    detailList:addItem(key)
                end
            else
                detailList:addItem("No item found.")
            end
        else
            detailList:addItem("Invalid selection.")
        end
    else
        detailList:addItem("No item selected.")
    end
end)

-- onClick Events
searchButton:onClick(function()
    updateItemList(true) -- Skip return process
end)

clearButton:onClick(function()
    searchInput:setText("")
    nbtSearchInput:setText("")
    updateItemList(true) -- Skip return process
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
        local index = tonumber(selected.text:match("#(%d+):"))
        if index then
            local itemName = allItems[index]["itemName"]
            local count = allItems[index]["total"]
            count = math.min(count, 64 * 54)  -- Limit to 64 * 54 items per transfer
            moveItem(itemName, storage_invs, port_invs, count, "")

            updateItemList(true) -- Skip return process
            detailList:clear()
        else
            basalt.LOGGER.warn("Could not determine index from selected item")
        end
    else
        basalt.LOGGER.warn("No item selected")
    end
end)

withdrawAllButton:onClick(function()
    -- local startIndex = (currentPage - 1) * itemsPerPage + 1
    -- local endIndex = math.min(#allItems, currentPage * itemsPerPage)

    for i = 1, #allItems do
        local itemName = allItems[i]["itemName"]
        local count = allItems[i]["itemNum"]
        count = math.min(count, allItems[i]["stack_size"])  -- Limit to 1 stack per transfer
        moveItem(itemName, storage_invs, port_invs, count, "")
    end

    updateItemList(true) -- Skip return process
    detailList:clear()
end)

depositButton:onClick(function()
    updateItemList(false) -- Return process
end)

ingotsFilterButton:onClick(function()
    searchInput:setText("")
    nbtSearchInput:setText("material")
    updateItemList(true) -- Skip return process
end)

toolsFilterButton:onClick(function()
    searchInput:setText("")
    nbtSearchInput:setText("tool")
    updateItemList(true) -- Skip return process
end)

skillbooksFilterButton:onClick(function()
    searchInput:setText("skillbook")
    nbtSearchInput:setText("")
    updateItemList(true) -- Skip return process
end)

mapsFilterButton:onClick(function()
    searchInput:setText("dungeon_map")
    nbtSearchInput:setText("")
    updateItemList(true) -- Skip return process
end)

statSoulFilterButton:onClick(function()
    searchInput:setText("stat_soul")
    nbtSearchInput:setText("")
    updateItemList(true) -- Skip return process
end)

soulslikeFilterButton:onClick(function()
    searchInput:setText("slu:")
    nbtSearchInput:setText("")
    updateItemList(true) -- Skip return process
end)

runesFilterButton:onClick(function()
    searchInput:setText("mmorpg:runes")
    nbtSearchInput:setText("")
    updateItemList(true) -- Skip return process)
end)

gemsFilterButton:onClick(function()
    searchInput:setText("mmorpg:gems")
    nbtSearchInput:setText("")
    updateItemList(true) -- Skip return process
end)

returnWithdrawnItems()
-- Start the UI
basalt.run()
-- Close rednet when exiting
rednet.close("back")