-- Restocking: keep a set number of an item (arrows, reagents, food) by
-- buying the difference from any merchant that sells it. The rules are
-- per character: /valet restock <item> <count>.
--
-- Valet only buys what you listed, only for gold (never for tokens or
-- honor), never past your money reserve, never more than your bags hold,
-- and one purchase at a time so the server keeps up.

local _, ns = ...
local Valet = ns.core
local Print, Money = Valet.Print, Valet.Money

ns.restock = {}

local ticker
local report
local onDone
local bought = {}   -- [itemID] = { count, spent } this visit
local startCount = {} -- [itemID] = count carried when the visit started
local finished = {} -- [itemID] = true: nothing more to buy this visit

local function GetItemInfoValue(itemID, position)
    local getter = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getter then
        return nil
    end
    return (select(position, getter(itemID)))
end

local function ItemName(itemID)
    return GetItemInfoValue(itemID, 1) or ("item " .. itemID)
end

local function CountCarried(itemID)
    local counter = (C_Item and C_Item.GetItemCount) or GetItemCount
    return counter and counter(itemID) or 0
end

local function MerchantItemID(index)
    if GetMerchantItemID then
        return GetMerchantItemID(index)
    end
    return Valet.ParseItem(GetMerchantItemLink and GetMerchantItemLink(index))
end

local function FindOnMerchant(itemID)
    for index = 1, GetMerchantNumItems and GetMerchantNumItems() or 0 do
        if MerchantItemID(index) == itemID then
            return index
        end
    end
end

-- How many of the item still fit in your bags: free room in stacks you
-- already carry, plus empty slots in bags that take it (normal bags, or a
-- quiver or other special bag made for it).
local function BagRoom(itemID)
    local stackSize = GetItemInfoValue(itemID, 8) or 1
    local itemFamily = (C_Item and C_Item.GetItemFamily and C_Item.GetItemFamily(itemID))
        or (GetItemFamily and GetItemFamily(itemID)) or 0
    local freeSlots = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    local room = 0
    for bag = 0, Valet.NumBags() do
        local free, bagFamily = 0, 0
        if freeSlots then
            free, bagFamily = freeSlots(bag)
        end
        if (bagFamily or 0) == 0 or bit.band(bagFamily, itemFamily) ~= 0 then
            room = room + (free or 0) * stackSize
            for slot = 1, Valet.GetNumSlots(bag) do
                local slotItem, count = Valet.GetBagSlotItem(bag, slot)
                if slotItem == itemID then
                    room = room + math.max(0, stackSize - count)
                end
            end
        end
    end
    return room
end

local function Bought(itemID, count, cost)
    local entry = bought[itemID] or { 0, 0 }
    entry[1] = entry[1] + count
    entry[2] = entry[2] + cost
    bought[itemID] = entry
end

-- The next purchase as index, count (nil to buy one batch), cost; or nil
-- when nothing is left to buy. Notes why an item is skipped.
local function NextPurchase()
    for itemID, target in pairs(ValetCharDB.restock) do
        if not finished[itemID] then
            local name = ItemName(itemID)
            local have = math.max(CountCarried(itemID), startCount[itemID] + (bought[itemID] and bought[itemID][1] or 0))
            local need = target - have
            local index = need > 0 and FindOnMerchant(itemID)
            if need <= 0 then
                finished[itemID] = true
            elseif not index then
                finished[itemID] = true
                report:Note("did not restock %s: this merchant does not sell it", name)
            else
                local _, _, price, batch, available = GetMerchantItemInfo(index)
                batch = math.max(batch or 1, 1)
                local maxPerPurchase = GetMerchantItemMaxStack and GetMerchantItemMaxStack(index) or 1
                local tokens = GetMerchantItemCostInfo and GetMerchantItemCostInfo(index) or 0
                local room = BagRoom(itemID)
                local count, cost
                if batch > 1 then
                    -- Sold in batches: one batch per purchase, so the count
                    -- can never be misread as batches rather than items.
                    count, cost = batch, price or 0
                else
                    count = math.min(need, math.max(maxPerPurchase, 1), room)
                    if available and available >= 0 then
                        count = math.min(count, available)
                    end
                    cost = (price or 0) * count
                end
                finished[itemID] = true
                if tokens > 0 or not price or price <= 0 then
                    report:Note("did not restock %s: it costs more than gold", name)
                elseif available == 0 then
                    report:Note("did not restock %s: the merchant is sold out", name)
                elseif room < count or count <= 0 then
                    report:Problem("could not restock %s: your bags are full", name)
                elseif GetMoney() - cost < Valet.MoneyReserve() then
                    report:Problem("stopped restocking %s to keep your %s reserve", name, Money(Valet.MoneyReserve()))
                else
                    finished[itemID] = nil
                    Bought(itemID, count, cost)
                    return index, batch > 1 and nil or count
                end
            end
        end
    end
end

local function Finish()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if not report then
        return
    end
    for itemID, entry in pairs(bought) do
        report:Did("bought %d %s for %s", entry[1], ItemName(itemID), Money(entry[2]))
    end
    wipe(bought)
    report = nil
    local done = onDone
    onDone = nil
    if done then
        done()
    end
end

local function BuyNext()
    if not MerchantFrame or not MerchantFrame:IsShown() then
        Finish()
        return
    end
    local index, count = NextPurchase()
    if not index then
        Finish()
        return
    end
    if count then
        BuyMerchantItem(index, count)
    else
        BuyMerchantItem(index)
    end
end

-- Starts restocking for a merchant visit; done() runs once it is over.
function ns.restock.Start(visitReport, done)
    Finish()
    report, onDone = visitReport, done
    wipe(bought)
    wipe(finished)
    wipe(startCount)
    if not next(ValetCharDB.restock) or not GetMerchantNumItems or not BuyMerchantItem then
        Finish()
        return
    end
    for itemID in pairs(ValetCharDB.restock) do
        startCount[itemID] = CountCarried(itemID)
    end
    ticker = C_Timer.NewTicker(0.4, BuyNext)
end

-- The merchant closed: report what was bought so far.
function ns.restock.Stop()
    onDone = nil
    Finish()
end

--------------------------------------------------------------------------------
-- /valet restock
--------------------------------------------------------------------------------

local function HandleRestockCommand(arg)
    local rules = ValetCharDB.restock
    if arg == "" then
        if not next(rules) then
            Print("nothing to restock. /valet restock, shift-click an item into chat, then the number to keep.")
            return
        end
        Print("kept in stock on this character:")
        for itemID, target in pairs(rules) do
            Print("  %d %s (%d now)", target, Valet.ItemLink(itemID), CountCarried(itemID))
        end
        return
    end
    if arg:lower() == "clear" then
        wipe(rules)
        Print("nothing is restocked anymore.")
        return
    end
    local itemID, target
    if arg:find("item:", 1, true) then
        itemID = Valet.ParseItem(arg)
        target = tonumber(arg:match("|r%s*(%d+)%s*$") or arg:match("%]%s*(%d+)%s*$"))
    else
        local id, count = arg:match("^(%d+)%s+(%d+)$")
        itemID, target = tonumber(id), tonumber(count)
    end
    if not itemID or not target then
        Print("usage: /valet restock, shift-click an item into chat, then the number to keep (0 to stop).")
        return
    end
    if target <= 0 then
        rules[itemID] = nil
        Print("no longer restocking %s.", Valet.ItemLink(itemID))
    else
        rules[itemID] = target
        Print("keeping %d %s at merchants that sell it.", target, Valet.ItemLink(itemID))
    end
end

Valet.AddCommand("restock", "<item> <count>", "keep that many in your bags; 0 to stop", HandleRestockCommand)
