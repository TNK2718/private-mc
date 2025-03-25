local basalt = require("basalt")
local frame = basalt.createFrame()

-- 周辺機器の設定（チェスト：left、出庫先：right）
local chest = peripheral.wrap("back")
if not chest then
    error("Chest peripheral not found on left!")
end
local targetSide = "left"

-- UI要素の作成
local searchInput = frame:addInput()
    :setWidth(20)
    :setX(2)
    :setY(2)
    :setPlaceholder("Search item...")

local searchButton = frame:addButton()
    :setText("Search")
    :setX(23)
    :setY(2)

-- 左側：アイテム一覧リスト（1ページあたり10件、横幅40）
local itemList = frame:addList()
    :setWidth(40)
    :setHeight(10)
    :setX(2)
    :setY(4)

-- 右側：詳細情報リスト（横幅30、同じ高さ）
local detailList = frame:addList()
    :setWidth(30)
    :setHeight(10)
    :setX(43)
    :setY(4)

-- ページング用ボタン
local prevPageButton = frame:addButton()
    :setText("Prev")
    :setWidth(6)
    :setX(2)
    :setY(15)

local nextPageButton = frame:addButton()
    :setText("Next")
    :setWidth(6)
    :setX(9)
    :setY(15)

local withdrawButton = frame:addButton()
    :setText("Withdraw Selected")
    :setX(16)
    :setY(15)

-- ページング用の変数
local allItems = {}     -- 検索結果全件（例："S3: iron_ingot"）
local currentPage = 1   -- 現在のページ番号
local itemsPerPage = 10 -- 1ページあたりの表示件数

-- 選択中のアイテムの詳細情報を取得する関数
local function getItemDetail(item, slot)
    if not item then
        return {"No details available"}
    end

    local details = {
        "Slot: " .. slot,
    }

    local tags = chest.getItemDetail(slot).tags
    for key, value in pairs(tags) do
        if value then  -- true の場合のみ追加（必要に応じて）
            table.insert(details, key)
        end
    end
    return details
end

-- 現在のページに合わせて itemList を更新する関数
local function updatePage()
    itemList:clear()
    local startIndex = (currentPage - 1) * itemsPerPage + 1
    local endIndex = math.min(#allItems, currentPage * itemsPerPage)
    for i = startIndex, endIndex do
        itemList:addItem(allItems[i])
    end
    detailList:clear()
end

-- 検索クエリに基づいてチェスト内アイテムを全件取得し、allItems に格納する関数
local function updateItemList()
    local query = searchInput:getText():lower()
    allItems = {}
    local items = chest.list() or {}
    for slot, item in pairs(items) do
        if string.find(item.name:lower(), query) then
            local displayText = "S" .. slot .. ": " .. item.name
            table.insert(allItems, displayText)
        end
    end
    currentPage = 1
    updatePage()
end

-- itemList の選択変化を listen して詳細情報を表示
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

-- 各ボタンの onClick イベント設定
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
                    updateItemList()
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

basalt.run()
