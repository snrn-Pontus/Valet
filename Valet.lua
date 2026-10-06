-- Valet takes care of the small chores nobody wants to click through: it
-- sells grey items and repairs your gear at a merchant, empties the mail at
-- a mailbox, turns away duel requests, guild invites and guild charters,
-- and can confirm a few routine popups. Everything is a switch on the
-- settings page (Settings.lua); there is nothing to do after that.
--
-- This file holds what the chores share: saved variables, chat output,
-- small helpers, slash commands and event dispatch. Each chore lives in its
-- own file and registers its events here.

local ADDON_NAME, ns = ...

local Valet = {}
ns.core = Valet

function Valet.Print(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    print("|cff7fd8ffValet|r: " .. msg)
end

local Print = Valet.Print

-- Reports what Valet did on its own, unless the chat messages are turned off.
function Valet.Notify(fmt, ...)
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
    mailMoney = true,         -- take the gold from mail at a mailbox
    mailItems = false,        -- take the items from mail at a mailbox
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

function Valet.Money(copper)
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    return string.format("%dg %ds %dc", copper / 10000, (copper / 100) % 100, copper % 100)
end

-- Blizzard shows its popup from the same event Valet answers. Its handler
-- normally runs first, but hiding again on the next frame covers the case
-- where it does not, so no popup is left behind for something already done.
function Valet.HidePopup(...)
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

function Valet.NumBags()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

function Valet.GetNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

-- Returns itemID, stack count, quality and locked.
function Valet.GetBagSlotItem(bag, slot)
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

function Valet.UseBagSlot(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then
        UseContainerItem(bag, slot)
    end
end

-- Free slots in normal bags; quivers and soul bags hold only their kind.
function Valet.FreeBagSlots()
    local free = 0
    local getter = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    if not getter then
        return 0
    end
    for bag = 0, Valet.NumBags() do
        local slots, family = getter(bag)
        if family == 0 then
            free = free + (slots or 0)
        end
    end
    return free
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
    { "mailMoney", "Take gold from the mail" },
    { "mailItems", "Take items from the mail" },
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

local handlers = {} -- [event] = { handler, ... }
local frame = CreateFrame("Frame")

-- Not every client has every event; a missing one just leaves that chore off.
function Valet.On(event, handler)
    if not handlers[event] then
        handlers[event] = {}
        pcall(frame.RegisterEvent, frame, event)
    end
    table.insert(handlers[event], handler)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            InitSavedVariables()
        end
    elseif event == "PLAYER_LOGIN" then
        if ns.settings and ns.settings.Register then
            ns.settings.Register()
        end
    end
    if ValetDB and handlers[event] then
        for _, handler in ipairs(handlers[event]) do
            handler(...)
        end
    end
end)
