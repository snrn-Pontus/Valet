-- Merchant: sell greys and the items on your sell list, then repair.

local _, ns = ...
local Valet = ns.core
local Print, Money = Valet.Print, Valet.Money

local ITEM_QUALITY_POOR = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
local ITEM_CLASS_QUEST = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12

local merchantOpen = false
local report -- this visit's report
local sellTicker
local soldGreys, soldListed, soldValue = 0, 0, 0
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

-- "grey" or "listed" when the item goes, nil when it stays.
local function SellReason(itemID, quality)
    local listed = ValetCharDB.sell[itemID]
    if not listed and (quality ~= ITEM_QUALITY_POOR or not ValetDB.sellGreys) then
        return nil
    end
    -- Tally's keep list wins over everything: what you keep there stays.
    if TallyDB and type(TallyDB.keep) == "table" and TallyDB.keep[itemID] then
        return nil
    end
    local price, classID = GetItemDetails(itemID)
    -- Anything the vendor will not buy stays, and so do grey quest starters.
    if not price or price <= 0 then
        return nil
    end
    if listed then
        return "listed"
    end
    return classID ~= ITEM_CLASS_QUEST and "grey" or nil
end

local function NextSale()
    for bag = 0, Valet.NumBags() do
        for slot = 1, Valet.GetNumSlots(bag) do
            local itemID, count, quality, locked = Valet.GetBagSlotItem(bag, slot)
            if itemID and not locked and not tried[bag * 1000 + slot] then
                local reason = SellReason(itemID, quality)
                if reason then
                    return bag, slot, itemID, count, reason
                end
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
            report:Did("repaired for %s from guild funds", Money(cost))
            return
        end
    end
    if GetMoney() < cost then
        report:Problem("not enough money to repair (%s)", Money(cost))
        return
    end
    RepairAllItems()
    report:Did("repaired for %s", Money(cost))
end

-- The chores after selling, in order, then the visit's summary.
local function AfterSelling()
    if not merchantOpen then
        return
    end
    Repair()
    report:Finish()
end

local function StopSelling()
    if sellTicker then
        sellTicker:Cancel()
        sellTicker = nil
    end
end

local function Items(count, kind)
    return string.format("%d %s%s", count, kind, count == 1 and " item" or " items")
end

local function ReportSales()
    if soldGreys + soldListed == 0 then
        return
    end
    local what
    if soldListed == 0 then
        what = Items(soldGreys, "grey")
    elseif soldGreys == 0 then
        what = Items(soldListed, "listed")
    else
        what = Items(soldGreys, "grey") .. " and " .. Items(soldListed, "listed")
    end
    report:Did("sold %s for %s", what, Money(soldValue))
    soldGreys, soldListed, soldValue = 0, 0, 0
end

local function FinishSelling()
    StopSelling()
    local sold = soldGreys + soldListed > 0
    ReportSales()
    -- The money from the sale arrives a moment later; repair after it, so
    -- the greys help pay the bill.
    C_Timer.After(sold and 0.5 or 0, AfterSelling)
end

-- One item per tick: selling a whole bag of greys in one frame gets some
-- of the sales dropped by the server.
local function SellNext()
    if not merchantOpen then
        StopSelling()
        return
    end
    local bag, slot, itemID, count, reason = NextSale()
    if not bag then
        FinishSelling()
        return
    end
    local price = GetItemDetails(itemID) or 0
    -- A slot is tried once per visit, so an item the merchant refuses
    -- cannot keep the ticker going forever.
    tried[bag * 1000 + slot] = true
    Valet.UseBagSlot(bag, slot)
    if reason == "listed" then
        soldListed = soldListed + 1
    else
        soldGreys = soldGreys + 1
    end
    soldValue = soldValue + price * count
end

local function OnMerchantShow()
    merchantOpen = true
    report = Valet.BeginReport("merchant", "Merchant")
    soldGreys, soldListed, soldValue = 0, 0, 0
    wipe(tried)
    StopSelling()
    if Valet.Bypassed() then
        report:Note("left the merchant alone because Shift was held")
        return
    end
    if NextSale() then
        sellTicker = C_Timer.NewTicker(0.15, SellNext)
    else
        AfterSelling()
    end
end

-- Closing early still reports what was sold before it.
local function OnMerchantClosed()
    merchantOpen = false
    StopSelling()
    if report then
        ReportSales()
        report:Finish()
    end
end

--------------------------------------------------------------------------------
-- The sell list
--------------------------------------------------------------------------------

local function HandleSellCommand(arg)
    local list = ValetCharDB.sell
    if arg == "" then
        if not next(list) then
            Print("your sell list is empty. /valet sell, then shift-click an item into chat, to add one.")
            return
        end
        Print("always sold at a merchant on this character:")
        for itemID in pairs(list) do
            Print("  %s", Valet.ItemLink(itemID))
        end
        return
    end
    if arg:lower() == "clear" then
        wipe(list)
        Print("your sell list is empty now.")
        return
    end
    local itemID = Valet.ParseItem(arg)
    if not itemID then
        Print("shift-click an item into chat after /valet sell, or give its item ID.")
        return
    end
    list[itemID] = not list[itemID] or nil
    if list[itemID] then
        local kept = TallyDB and type(TallyDB.keep) == "table" and TallyDB.keep[itemID]
        Print("%s is sold at every merchant now%s.", Valet.ItemLink(itemID),
            kept and ", once you take it off Tally's keep list" or "")
    else
        Print("%s is no longer on your sell list.", Valet.ItemLink(itemID))
    end
end

Valet.AddCommand("sell", "<item>", "always sell an item; again to stop", HandleSellCommand)
Valet.AddCommand("selllist", "", "list the items you always sell", function()
    HandleSellCommand("")
end)

Valet.On("MERCHANT_SHOW", OnMerchantShow)
Valet.On("MERCHANT_CLOSED", OnMerchantClosed)
