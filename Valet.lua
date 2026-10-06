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

local function Format(fmt, ...)
    return select("#", ...) > 0 and string.format(fmt, ...) or fmt
end

local function Capitalize(text)
    return (text:gsub("^%l", string.upper))
end

--------------------------------------------------------------------------------
-- Reports and chat
--------------------------------------------------------------------------------

-- Every chore tells what it did through a report: one per visit (a
-- merchant, a mailbox) or one per request (a duel, an invite). How much of
-- it reaches chat depends on ValetDB.notify:
--   verbose  every action and every skip, as it happens
--   summary  one line per visit once it is over (the default)
--   errors   only problems that need you, like bags too full for the mail
--   silent   nothing at all
-- Whatever the mode, the latest report of each kind is kept for /valet last
-- until you log out.

local reports = {} -- [kind] = the latest report of that kind with anything in it

local Report = {}
Report.__index = Report

function Valet.BeginReport(kind, title)
    return setmetatable({ kind = kind, title = title, done = {}, notes = {}, problems = {} }, Report)
end

function Report:Add(list, text)
    table.insert(list, text)
    self.time = GetTime()
    reports[self.kind] = self
end

-- Something Valet did, as a lowercase phrase: "sold 3 grey items for 12s".
function Report:Did(fmt, ...)
    local text = Format(fmt, ...)
    self:Add(self.done, text)
    if ValetDB.notify == "verbose" then
        Print("%s.", Capitalize(text))
    end
end

-- Something Valet left alone and why. Only verbose chat shows it.
function Report:Note(fmt, ...)
    local text = Format(fmt, ...)
    self:Add(self.notes, text)
    if ValetDB.notify == "verbose" then
        Print("%s.", Capitalize(text))
    end
end

-- Something that needs you. Shown at once unless chat is silent.
function Report:Problem(fmt, ...)
    local text = Format(fmt, ...)
    self:Add(self.problems, text)
    if ValetDB.notify ~= "silent" then
        Print("|cffff9040%s.|r", Capitalize(text))
    end
end

-- The visit is over: summary mode prints what was done as one line.
function Report:Finish()
    if self.finished then
        return
    end
    self.finished = true
    if ValetDB.notify == "summary" and #self.done > 0 then
        Print("%s.", Capitalize(table.concat(self.done, ", ")))
    end
end

-- A one-off report: one thing done, finished at once.
function Valet.Report(kind, title, fmt, ...)
    local report = Valet.BeginReport(kind, title)
    report:Did(fmt, ...)
    report:Finish()
    return report
end

local function Ago(seconds)
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        return string.format("%d min ago", seconds / 60)
    end
    return string.format("%d h ago", seconds / 3600)
end

local function PrintLast()
    local list = {}
    for _, report in pairs(reports) do
        list[#list + 1] = report
    end
    if #list == 0 then
        Print("nothing done yet this session.")
        return
    end
    table.sort(list, function(a, b)
        return a.time > b.time
    end)
    local now = GetTime()
    for _, report in ipairs(list) do
        local parts = {}
        for _, text in ipairs(report.done) do
            parts[#parts + 1] = text
        end
        for _, text in ipairs(report.notes) do
            parts[#parts + 1] = "|cffa0a0a0" .. text .. "|r"
        end
        for _, text in ipairs(report.problems) do
            parts[#parts + 1] = "|cffff9040" .. text .. "|r"
        end
        Print("%s, %s: %s.", report.title, Ago(now - report.time), table.concat(parts, ", "))
    end
end

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------

local DEFAULTS = {
    sellGreys = true,         -- sell grey items at a merchant
    repair = true,            -- repair all gear at a merchant that can
    guildRepair = false,      -- pay repairs from the guild bank when allowed
    moneyReserve = 0,         -- gold restocking and Train All never spend into
    questAccept = false,      -- accept quests from NPCs
    questTurnIn = false,      -- turn in finished quests with no reward to choose
    questSingleReward = true, -- ...and those with exactly one reward
    skipGossip = false,       -- pick the only gossip option
    acceptSharedQuests = false, -- accept quests shared by trusted players
    declineDuels = true,      -- decline duel requests
    declineGuild = true,      -- decline guild invites
    declineCharters = true,   -- close guild charters others offer to sign
    declineStrangers = false, -- decline group invites from non-friends
    acceptTrustedInvites = false, -- accept group invites from friends and guildmates
    confirmLoot = true,       -- confirm Bind on Pickup loot when solo
    acceptRes = false,        -- accept resurrection from players not in combat
    acceptSummon = false,     -- accept summons out of combat
    releaseInBattlegrounds = false, -- release your spirit after dying in a battleground
    skipSeenCinematics = false, -- skip cinematics and movies seen before
    mailMoney = true,         -- take the gold from mail at a mailbox
    mailItems = false,        -- take the items from mail at a mailbox
    mailFrom = "all",         -- whose mail to take from: "all", "trusted" or "auction"
    mailDelete = false,       -- delete the letters Valet emptied, if nothing is left to read
    notify = "summary",       -- chat: "verbose", "summary", "errors" or "silent"
}

local function InitSavedVariables()
    -- Per character: lists of items, which differ from one character to the next.
    ValetCharDB = ValetCharDB or {}
    ValetCharDB.sell = ValetCharDB.sell or {} -- [itemID] = true: always sold at a merchant
    ValetCharDB.restock = ValetCharDB.restock or {} -- [itemID] = count to keep in the bags

    ValetDB = ValetDB or {}
    -- 0.1.0 had a single chat switch; off meant keep chat quiet.
    if ValetDB.chat ~= nil then
        if ValetDB.notify == nil and not ValetDB.chat then
            ValetDB.notify = "errors"
        end
        ValetDB.chat = nil
    end
    for key, value in pairs(DEFAULTS) do
        if ValetDB[key] == nil then
            ValetDB[key] = value
        end
    end
    -- Movies (by ID) and cinematics (by where they start) seen on any
    -- character, so only those can ever be skipped.
    ValetDB.seen = ValetDB.seen or {}
    ValetDB.seen.movies = ValetDB.seen.movies or {}
    ValetDB.seen.cinematics = ValetDB.seen.cinematics or {}
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

-- The item ID in a chat link ("|Hitem:2589:...") or a bare number.
function Valet.ParseItem(text)
    return tonumber((text or ""):match("item:(%d+)") or (text or ""):match("^%s*(%d+)%s*$"))
end

-- The item's link for chat, or its ID while the client has not cached it.
function Valet.ItemLink(itemID)
    local getter = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getter then
        return "item:" .. itemID
    end
    local _, link = getter(itemID)
    return link or ("item:" .. itemID)
end

-- Copper Valet never spends on its own: restocking and Train All stop
-- before your money would drop below it. Set in gold on the settings page.
function Valet.MoneyReserve()
    return math.floor((tonumber(ValetDB.moneyReserve) or 0) * 10000)
end

--------------------------------------------------------------------------------
-- Shift bypass
--------------------------------------------------------------------------------

-- One rule for every chore that acts on an interaction (merchant, mailbox,
-- quest giver, gossip): hold Shift as it opens and Valet leaves that visit
-- alone. Chores ask once, when the visit starts, and remember the answer
-- until it ends; nothing is saved.
function Valet.Bypassed()
    return IsShiftKeyDown and IsShiftKeyDown() and true or false
end

--------------------------------------------------------------------------------
-- Trusted players
--------------------------------------------------------------------------------

-- The one place Valet decides whether a player is someone you know. Each
-- chore names the sources it trusts:
--   Valet.IsTrusted(name, guid, { friends = true, guild = true })
-- Sources: friends (WoW friends), bnet (Battle.net friends), guild
-- (guildmates), group (your current party or raid). A source whose API is
-- missing or errors counts as not trusting anyone, and a player nobody
-- vouches for is never trusted.

local function SameName(a, b)
    if not a or not b then
        return false
    end
    if a == b then
        return true
    end
    if Ambiguate then
        return Ambiguate(a, "none") == Ambiguate(b, "none")
    end
    return false
end

local TRUST_CHECKS = {
    friends = function(name, guid)
        if not C_FriendList then
            return false
        end
        if guid and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then
            return true
        end
        return name and C_FriendList.GetFriendInfo and C_FriendList.GetFriendInfo(name) and true or false
    end,
    bnet = function(_, guid)
        return guid and C_BattleNet and C_BattleNet.GetAccountInfoByGUID
            and C_BattleNet.GetAccountInfoByGUID(guid) and true or false
    end,
    guild = function(name, guid)
        if not IsInGuild or not IsInGuild() then
            return false
        end
        if guid and IsGuildMember and IsGuildMember(guid) then
            return true
        end
        if not name or not GetNumGuildMembers or not GetGuildRosterInfo then
            return false
        end
        for i = 1, GetNumGuildMembers() do
            if SameName(GetGuildRosterInfo(i), name) then
                return true
            end
        end
        return false
    end,
    group = function(name, guid)
        if not IsInGroup or not IsInGroup() then
            return false
        end
        local prefix = IsInRaid and IsInRaid() and "raid" or "party"
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, count do
            local unit = prefix .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                if guid and UnitGUID(unit) == guid then
                    return true
                end
                local unitName, realm = UnitName(unit)
                if realm and realm ~= "" then
                    unitName = unitName .. "-" .. realm
                end
                if SameName(unitName, name) then
                    return true
                end
            end
        end
        return false
    end,
}

Valet.TRUST_LABELS = {
    friends = "friend",
    bnet = "Battle.net friend",
    guild = "guildmate",
    group = "group member",
}

-- The source the player is trusted through (a key of TRUST_LABELS), or nil.
function Valet.IsTrusted(name, guid, sources)
    if not name and not guid then
        return nil
    end
    for source, wanted in pairs(sources) do
        local check = wanted and TRUST_CHECKS[source]
        if check then
            local ok, trusted = pcall(check, name, guid)
            if ok and trusted then
                return source
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

-- Chores add their own commands with Valet.AddCommand; they are listed by
-- /valet help in the order they were added.
local commands = {} -- [name] = handler
local commandHelp = {} -- { "  /valet name args   what it does", ... }

function Valet.AddCommand(name, usage, help, handler)
    commands[name] = handler
    local left = "/valet " .. name .. (usage ~= "" and (" " .. usage) or "")
    commandHelp[#commandHelp + 1] = string.format("  %-24s %s", left, help)
end

local STATUS = {
    { "sellGreys", "Sell grey items" },
    { "repair", "Repair gear" },
    { "guildRepair", "Use guild funds for repairs" },
    { "mailMoney", "Take gold from the mail" },
    { "mailItems", "Take items from the mail" },
    { "mailDelete", "Delete emptied letters" },
    { "questAccept", "Accept quests" },
    { "questTurnIn", "Turn in finished quests" },
    { "questSingleReward", "Take a quest's only reward" },
    { "skipGossip", "Skip gossip with one option" },
    { "acceptSharedQuests", "Accept quests shared by people you know" },
    { "declineDuels", "Decline duels" },
    { "declineGuild", "Decline guild invites" },
    { "declineCharters", "Close guild charters" },
    { "declineStrangers", "Decline group invites from strangers" },
    { "acceptTrustedInvites", "Accept group invites from friends and guildmates" },
    { "confirmLoot", "Confirm Bind on Pickup loot when solo" },
    { "acceptRes", "Accept resurrection" },
    { "acceptSummon", "Accept summons" },
    { "releaseInBattlegrounds", "Release in battlegrounds" },
    { "skipSeenCinematics", "Skip cinematics you have seen" },
}

local function PrintStatus()
    for _, entry in ipairs(STATUS) do
        Print("%s: %s", entry[2], ValetDB[entry[1]] and "|cff40ff40on|r" or "|cff808080off|r")
    end
    Print("Money reserve: %s", Valet.Money(Valet.MoneyReserve()))
    Print("Mail from: %s", ValetDB.mailFrom)
    Print("Chat: %s", ValetDB.notify)
end

Valet.AddCommand("status", "", "list what is turned on", PrintStatus)
Valet.AddCommand("last", "", "what Valet did lately, and what it left alone", PrintLast)

local function PrintHelp()
    Print("commands:")
    Print("  %-24s %s", "/valet", "open the settings")
    for _, line in ipairs(commandHelp) do
        Print(line)
    end
    Print("  %-24s %s", "/valet help", "this list")
end

SLASH_VALET1 = "/valet"
SlashCmdList.VALET = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()
    if commands[command] then
        commands[command](rest)
    elseif command == "" then
        if ns.settings and ns.settings.Open then
            ns.settings.Open()
        end
    else
        PrintHelp()
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
