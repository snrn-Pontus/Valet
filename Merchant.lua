-- Merchant: sell greys, then repair.

local _, ns = ...
local Valet = ns.core
local Notify, Money = Valet.Notify, Valet.Money

local ITEM_QUALITY_POOR = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
local ITEM_CLASS_QUEST = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12

local merchantOpen = false
local sellTicker
local soldCount, soldValue = 0, 0
local tried = {} -- [bag * 1000 + slot] = true: sold once already this visit

-- Vendor price, item class. Nil price means the item is not cached yet.
local function GetItemDetails(itemID)
    local getter = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getter then
        return nil
    end
    local _, _, _, _, _, _, _, _, _, _, price, classID = getter(itemID)
    return price, classID
end

local function IsSellable(itemID, quality)
    if quality ~= ITEM_QUALITY_POOR then
        return false
    end
    -- Tally's keep list: greys you chose to keep there are kept here too.
    if TallyDB and type(TallyDB.keep) == "table" and TallyDB.keep[itemID] then
        return false
    end
    local price, classID = GetItemDetails(itemID)
    -- Grey quest starters and anything the vendor will not buy stay.
    return price and price > 0 and classID ~= ITEM_CLASS_QUEST
end

local function NextGrey()
    for bag = 0, Valet.NumBags() do
        for slot = 1, Valet.GetNumSlots(bag) do
            local itemID, count, quality, locked = Valet.GetBagSlotItem(bag, slot)
            if itemID and not locked and not tried[bag * 1000 + slot] and IsSellable(itemID, quality) then
                return bag, slot, itemID, count
            end
        end
    end
end

local function Repair()
    if not ValetDB.repair or not merchantOpen or not CanMerchantRepair or not CanMerchantRepair() then
        return
    end
    local cost, needed = GetRepairAllCost()
    if not needed or not cost or cost <= 0 then
        return
    end
    if ValetDB.guildRepair and CanGuildBankRepair and CanGuildBankRepair() then
        local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()
        -- -1 means no limit; otherwise the guild must cover the whole bill.
        if limit and (limit == -1 or limit >= cost) then
            RepairAllItems(true)
            Notify("Repaired for %s from guild funds.", Money(cost))
            return
        end
    end
    if GetMoney() < cost then
        Notify("Not enough money to repair (%s).", Money(cost))
        return
    end
    RepairAllItems()
    Notify("Repaired for %s.", Money(cost))
end

local function StopSelling()
    if sellTicker then
        sellTicker:Cancel()
        sellTicker = nil
    end
end

local function FinishSelling()
    StopSelling()
    if soldCount > 0 then
        Notify("Sold %d grey %s for %s.", soldCount, soldCount == 1 and "item" or "items", Money(soldValue))
    end
    -- The money from the sale arrives a moment later; repair after it, so
    -- the greys help pay the bill.
    C_Timer.After(soldCount > 0 and 0.5 or 0, Repair)
end

-- One item per tick: selling a whole bag of greys in one frame gets some
-- of the sales dropped by the server.
local function SellNext()
    if not merchantOpen then
        StopSelling()
        return
    end
    local bag, slot, itemID, count = NextGrey()
    if not bag then
        FinishSelling()
        return
    end
    local price = GetItemDetails(itemID) or 0
    -- A slot is tried once per visit, so an item the merchant refuses
    -- cannot keep the ticker going forever.
    tried[bag * 1000 + slot] = true
    Valet.UseBagSlot(bag, slot)
    soldCount = soldCount + 1
    soldValue = soldValue + price * count
end

local function OnMerchantShow()
    merchantOpen = true
    if Valet.Bypassed() then
        return
    end
    soldCount, soldValue = 0, 0
    wipe(tried)
    StopSelling()
    if ValetDB.sellGreys and NextGrey() then
        sellTicker = C_Timer.NewTicker(0.15, SellNext)
    else
        Repair()
    end
end

local function OnMerchantClosed()
    merchantOpen = false
    StopSelling()
end

Valet.On("MERCHANT_SHOW", OnMerchantShow)
Valet.On("MERCHANT_CLOSED", OnMerchantClosed)
