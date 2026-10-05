-- Valet takes care of the small chores nobody wants to click through: it
-- sells grey items and repairs your gear at a merchant, turns away duel
-- requests, guild invites and guild charters, and can confirm a few routine
-- popups. Everything is a switch on the settings page (Settings.lua); there
-- is nothing to do after that.

local ADDON_NAME, ns = ...

local Valet = {}
ns.core = Valet

local function Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    print("|cff7fd8ffValet|r: " .. msg)
end

-- Reports what Valet did on its own, unless the chat messages are turned off.
local function Notify(fmt, ...)
    if ValetDB.chat then
        Print(fmt, ...)
    end
end

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------

local DEFAULTS = {
    sellGreys = true,         -- sell grey items at a merchant
    repair = true,            -- repair all gear at a merchant that can
    guildRepair = false,      -- pay repairs from the guild bank when allowed
    declineDuels = true,      -- decline duel requests
    declineGuild = true,      -- decline guild invites
    declineCharters = true,   -- close guild charters others offer to sign
    declineStrangers = false, -- decline group invites from non-friends
    confirmLoot = true,       -- confirm Bind on Pickup loot when solo
    acceptRes = false,        -- accept resurrection from players not in combat
    acceptSummon = false,     -- accept summons out of combat
    chat = true,              -- say in chat what was done
}

local function InitSavedVariables()
    ValetDB = ValetDB or {}
    for key, value in pairs(DEFAULTS) do
        if ValetDB[key] == nil then
            ValetDB[key] = value
        end
    end
end

function Valet.Set(key, value)
    ValetDB[key] = value
    if ns.settings and ns.settings.Refresh then
        ns.settings.Refresh()
    end
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Money(copper)
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    return string.format("%dg %ds %dc", copper / 10000, (copper / 100) % 100, copper % 100)
end

-- Blizzard shows its popup from the same event Valet answers. Its handler
-- normally runs first, but hiding again on the next frame covers the case
-- where it does not, so no popup is left behind for something already done.
local function HidePopup(...)
    if not StaticPopup_Hide then
        return
    end
    local names = { ... }
    for _, name in ipairs(names) do
        StaticPopup_Hide(name)
    end
    C_Timer.After(0, function()
        for _, name in ipairs(names) do
            StaticPopup_Hide(name)
        end
    end)
end

local function NumBags()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

local function GetNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

-- Returns itemID, stack count, quality and locked.
local function GetBagSlotItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return info.itemID, info.stackCount or 1, info.quality, info.isLocked
        end
        return nil
    end
    if GetContainerItemInfo then
        local _, count, locked, quality, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)
        return itemID, count or 1, quality, locked
    end
    return nil
end

local function UseBagSlot(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then
        UseContainerItem(bag, slot)
    end
end

--------------------------------------------------------------------------------
-- Merchant: sell greys, then repair
--------------------------------------------------------------------------------

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
    for bag = 0, NumBags() do
        for slot = 1, GetNumSlots(bag) do
            local itemID, count, quality, locked = GetBagSlotItem(bag, slot)
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
    UseBagSlot(bag, slot)
    soldCount = soldCount + 1
    soldValue = soldValue + price * count
end

local function OnMerchantShow()
    merchantOpen = true
    if IsShiftKeyDown() then
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

--------------------------------------------------------------------------------
-- Requests: duels, guild invites, charters, group invites
--------------------------------------------------------------------------------

local function IsFriend(name, guid)
    if guid and C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then
        return true
    end
    if guid and C_BattleNet and C_BattleNet.GetAccountInfoByGUID and C_BattleNet.GetAccountInfoByGUID(guid) then
        return true
    end
    if name and C_FriendList and C_FriendList.GetFriendInfo and C_FriendList.GetFriendInfo(name) then
        return true
    end
    return false
end

local function IsGuildmate(name, guid)
    if not IsInGuild() then
        return false
    end
    if guid and IsGuildMember and IsGuildMember(guid) then
        return true
    end
    if not name or not GetNumGuildMembers then
        return false
    end
    local shortName = Ambiguate and Ambiguate(name, "none") or name
    for i = 1, GetNumGuildMembers() do
        local member = GetGuildRosterInfo(i)
        if member and (member == name or (Ambiguate and Ambiguate(member, "none") == shortName)) then
            return true
        end
    end
    return false
end

local function OnDuelRequested(name)
    if not ValetDB.declineDuels then
        return
    end
    CancelDuel()
    HidePopup("DUEL_REQUESTED")
    Notify("Declined a duel from %s.", name or "someone")
end

local function OnGuildInvite(inviter, guildName)
    if not ValetDB.declineGuild then
        return
    end
    DeclineGuild()
    HidePopup("GUILD_INVITE")
    Notify("Declined a guild invite from %s (%s).", inviter or "someone", guildName or "?")
end

-- PETITION_SHOW also fires for your own charter and at the guild registrar;
-- only charters someone else wants signed are closed.
local function OnPetitionShow()
    if not ValetDB.declineCharters or not GetPetitionInfo then
        return
    end
    local _, title, _, _, originator, isOriginator = GetPetitionInfo()
    if not title or isOriginator then
        return
    end
    ClosePetition()
    Notify("Closed %s's charter for %s.", originator or "someone", title)
end

local function OnPartyInvite(name, ...)
    if not ValetDB.declineStrangers then
        return
    end
    local guid = select(6, ...)
    if IsFriend(name, guid) or IsGuildmate(name, guid) then
        return
    end
    DeclineGroup()
    HidePopup("PARTY_INVITE")
    Notify("Declined a group invite from %s, who is not a friend or guildmate.", name or "someone")
end

--------------------------------------------------------------------------------
-- Popups: Bind on Pickup loot, resurrection, summons
--------------------------------------------------------------------------------

-- Solo, a Bind on Pickup item can only go to you, so the warning has no
-- choice in it. In a group it stays: picking it up keeps it from others.
local function OnLootBindConfirm(slot)
    if not ValetDB.confirmLoot or IsInGroup() then
        return
    end
    ConfirmLootSlot(slot)
    HidePopup("LOOT_BIND")
end

local function OnResurrectRequest(name)
    if not ValetDB.acceptRes then
        return
    end
    -- A healer in combat may be about to die too; leave the choice to you.
    if name and UnitExists(name) and UnitAffectingCombat(name) then
        return
    end
    AcceptResurrect()
    HidePopup("RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER")
    Notify("Accepted resurrection from %s.", name or "someone")
end

local function OnConfirmSummon()
    if not ValetDB.acceptSummon or not C_SummonInfo or UnitAffectingCombat("player") then
        return
    end
    if PlayerCanTeleport and not PlayerCanTeleport() then
        return
    end
    local summoner = C_SummonInfo.GetSummonConfirmSummoner and C_SummonInfo.GetSummonConfirmSummoner()
    local area = C_SummonInfo.GetSummonConfirmAreaName and C_SummonInfo.GetSummonConfirmAreaName()
    C_SummonInfo.ConfirmSummon()
    HidePopup("CONFIRM_SUMMON", "CONFIRM_SUMMON_SCENARIO", "CONFIRM_SUMMON_STARTING_AREA")
    Notify("Accepted a summon from %s to %s.", summoner or "someone", area or "?")
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local function PrintHelp()
    Print("commands:")
    Print("  /valet          open the settings")
    Print("  /valet status   list what is turned on")
    Print("  /valet help     this list")
end

local STATUS = {
    { "sellGreys", "Sell grey items" },
    { "repair", "Repair gear" },
    { "guildRepair", "Use guild funds for repairs" },
    { "declineDuels", "Decline duels" },
    { "declineGuild", "Decline guild invites" },
    { "declineCharters", "Close guild charters" },
    { "declineStrangers", "Decline group invites from strangers" },
    { "confirmLoot", "Confirm Bind on Pickup loot when solo" },
    { "acceptRes", "Accept resurrection" },
    { "acceptSummon", "Accept summons" },
    { "chat", "Chat messages" },
}

local function PrintStatus()
    for _, entry in ipairs(STATUS) do
        Print("%s: %s", entry[2], ValetDB[entry[1]] and "|cff40ff40on|r" or "|cff808080off|r")
    end
end

SLASH_VALET1 = "/valet"
SlashCmdList.VALET = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "status" then
        PrintStatus()
    elseif msg == "help" then
        PrintHelp()
    elseif ns.settings and ns.settings.Open then
        ns.settings.Open()
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local HANDLERS = {
    MERCHANT_SHOW = OnMerchantShow,
    MERCHANT_CLOSED = OnMerchantClosed,
    DUEL_REQUESTED = OnDuelRequested,
    GUILD_INVITE_REQUEST = OnGuildInvite,
    PETITION_SHOW = OnPetitionShow,
    PARTY_INVITE_REQUEST = OnPartyInvite,
    LOOT_BIND_CONFIRM = OnLootBindConfirm,
    RESURRECT_REQUEST = OnResurrectRequest,
    CONFIRM_SUMMON = OnConfirmSummon,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
-- Not every client has every event; a missing one just leaves that chore off.
for event in pairs(HANDLERS) do
    pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            InitSavedVariables()
        end
    elseif event == "PLAYER_LOGIN" then
        if ns.settings and ns.settings.Register then
            ns.settings.Register()
        end
    elseif ValetDB and HANDLERS[event] then
        HANDLERS[event](...)
    end
end)
