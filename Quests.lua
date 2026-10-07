-- Quest givers and gossip: accept quests, turn in finished ones, accept
-- quests shared by people you trust, and click through gossip that has
-- only one way forward.
--
-- Valet never chooses for you: a quest with several rewards to pick from,
-- a turn-in that costs money and a gossip window with more than one option
-- all stay open for you. Holding Shift as you talk to the NPC leaves the
-- whole conversation to you.

local _, ns = ...
local Valet = ns.core

-- Who may share a quest that Valet accepts for you. Anyone in your group
-- can share, so trusting the group means trusting a pick-up group too;
-- that part is its own setting.
local function ShareTrust()
    return { group = ValetDB.shareTrustGroup, friends = true, bnet = true, guild = true }
end

-- One conversation can step through several windows (gossip, then quest
-- details, then gossip again); past this many automatic steps Valet stops,
-- whatever the NPC keeps showing.
local MAX_STEPS = 25

--------------------------------------------------------------------------------
-- The conversation
--------------------------------------------------------------------------------

-- Lasts from the first gossip or quest window of an NPC until its windows
-- have been closed for a moment; switching from gossip to a quest closes
-- one window and opens the next, which is still the same conversation.
local talk
local endGeneration = 0

local function NpcUnit()
    if UnitExists("questnpc") then
        return "questnpc"
    elseif UnitExists("npc") then
        return "npc"
    end
end

local function BeginTalk()
    endGeneration = endGeneration + 1
    local unit = NpcUnit()
    local guid = unit and UnitGUID(unit)
    if talk and talk.guid == guid then
        return talk
    end
    if talk then
        talk.report:Finish()
    end
    talk = {
        guid = guid,
        name = unit and UnitName(unit) or "the quest giver",
        bypassed = Valet.Bypassed(),
        steps = 0,
        tried = {}, -- [what .. title] = true: done once already this conversation
        turningIn = nil, -- { questID, title }: a reward asked for, not yet confirmed
        report = Valet.BeginReport("quest", "Quests"),
    }
    if talk.bypassed then
        talk.report:Note("left %s alone because Shift was held", talk.name)
    end
    return talk
end

local function EndTalkSoon()
    endGeneration = endGeneration + 1
    local generation = endGeneration
    C_Timer.After(1, function()
        if generation == endGeneration and talk then
            talk.report:Finish()
            talk = nil
        end
    end)
end

-- Whether Valet may take one more step, once per kind of step and title.
local function MayStep(what, title)
    if talk.bypassed or talk.steps >= MAX_STEPS then
        return false
    end
    local key = what .. ":" .. (title or "?")
    if talk.tried[key] then
        return false
    end
    talk.tried[key] = true
    talk.steps = talk.steps + 1
    return true
end

--------------------------------------------------------------------------------
-- Quest windows
--------------------------------------------------------------------------------

local function QuestTitle()
    return GetTitleText and GetTitleText() or "a quest"
end

-- The player sharing the quest shown, or nil when an NPC, object or item
-- offers it.
local function Sharer()
    local unit = NpcUnit()
    -- A quest from an item you carry can show you as its giver.
    if unit and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
        local name, realm = UnitName(unit)
        if realm and realm ~= "" then
            name = name .. "-" .. realm
        end
        return name, UnitGUID(unit)
    end
end

-- Whether the quest log has no room for another quest, in which case
-- accepting would fail. Clients have either the C_QuestLog or the older
-- global API.
local function QuestLogFull()
    local numQuests, maxQuests
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        numQuests = select(2, C_QuestLog.GetNumQuestLogEntries())
    elseif GetNumQuestLogEntries then
        numQuests = select(2, GetNumQuestLogEntries())
    end
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept()
    else
        maxQuests = MAX_QUESTS
    end
    return numQuests and maxQuests and numQuests >= maxQuests or false
end

local function OnQuestDetail()
    BeginTalk()
    if talk.bypassed then
        return
    end
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        return -- already accepted by the game itself
    end
    local title = QuestTitle()
    local sharer, sharerGUID = Sharer()
    if sharer then
        if not ValetDB.acceptSharedQuests then
            return
        end
        local trustedAs = Valet.IsTrusted(sharer, sharerGUID, ShareTrust())
        if not trustedAs then
            talk.report:Note("left %s, shared by %s, who is not someone you know", title, sharer)
            return
        end
        if QuestLogFull() then
            talk.report:Problem("could not accept %s: your quest log is full", title)
        elseif MayStep("accept", title) then
            AcceptQuest()
            talk.report:Did("accepted %s from %s (%s)", title, sharer, Valet.TRUST_LABELS[trustedAs])
        end
        return
    end
    if not ValetDB.questAccept then
        return
    end
    if QuestLogFull() then
        talk.report:Problem("could not accept %s: your quest log is full", title)
    elseif MayStep("accept", title) then
        AcceptQuest()
        talk.report:Did("accepted %s", title)
    end
end

-- The GUID of the group member with this name, which some trust checks
-- (Battle.net friends) need. The name may carry a realm.
local function GroupMemberGUID(name)
    if not name then
        return nil
    end
    local prefix, count = "party", GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
    if IsInRaid and IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers and GetNumGroupMembers() or 0
    end
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and (UnitName(unit) == name or GetUnitName and GetUnitName(unit, true) == name) then
            return UnitGUID(unit)
        end
    end
end

-- An escort or event quest a group member starts asks everyone nearby.
local function OnQuestAcceptConfirm(name, title)
    if not ValetDB.acceptSharedQuests or not ConfirmAcceptQuest then
        return
    end
    -- With the quest log full the game shows a different popup, and
    -- accepting would fail anyway.
    if QuestLogFull() then
        return
    end
    local trustedAs = Valet.IsTrusted(name, GroupMemberGUID(name), ShareTrust())
    if not trustedAs then
        return
    end
    ConfirmAcceptQuest()
    Valet.HidePopup("QUEST_ACCEPT")
    Valet.Report("quest", "Quests", "joined %s's quest %s (%s)", name or "someone", title or "?",
        Valet.TRUST_LABELS[trustedAs])
end

-- Hand in the items: only when the quest is ready and costs nothing.
local function OnQuestProgress()
    BeginTalk()
    if not ValetDB.questTurnIn or not IsQuestCompletable or not IsQuestCompletable() then
        return
    end
    local title = QuestTitle()
    local cost = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
    if cost > 0 then
        talk.report:Note("left %s: it costs %s to turn in", title, Valet.Money(cost))
        return
    end
    if MayStep("progress", title) then
        CompleteQuest()
    end
end

-- Take the reward: none to choose, or exactly one if that is allowed.
-- Several to choose from always stay for you.
local function OnQuestComplete()
    BeginTalk()
    if not ValetDB.questTurnIn or not GetQuestReward then
        return
    end
    local title = QuestTitle()
    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if choices > 1 then
        talk.report:Note("left %s: choose a reward yourself", title)
        return
    end
    if choices == 1 and not ValetDB.questSingleReward then
        talk.report:Note("left %s: take its reward yourself", title)
        return
    end
    if MayStep("complete", title) then
        -- Reported once the game confirms it: with no room for the reward,
        -- the quest stays open.
        talk.turningIn = { questID = GetQuestID and GetQuestID() or 0, title = title }
        GetQuestReward(choices)
    end
end

local function OnQuestTurnedIn(questID)
    local pending = talk and talk.turningIn
    if pending and (pending.questID == 0 or pending.questID == questID) then
        talk.turningIn = nil
        talk.report:Did("turned in %s", pending.title)
    end
end

-- An NPC with several quests and no gossip lists them in the quest window.
local function OnQuestGreeting()
    BeginTalk()
    if ValetDB.questTurnIn and GetNumActiveQuests and GetActiveTitle then
        for i = 1, GetNumActiveQuests() do
            local title, isComplete = GetActiveTitle(i)
            -- Some clients return only the title here.
            if isComplete == nil and GetActiveQuestID and C_QuestLog and C_QuestLog.IsComplete then
                local questID = GetActiveQuestID(i)
                isComplete = questID and C_QuestLog.IsComplete(questID)
            end
            if isComplete and MayStep("turn in", title) then
                SelectActiveQuest(i)
                return
            end
        end
    end
    if ValetDB.questAccept and GetNumAvailableQuests and GetAvailableTitle then
        for i = 1, GetNumAvailableQuests() do
            local title = GetAvailableTitle(i)
            local isTrivial = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
            if not isTrivial and MayStep("pick", title) then
                SelectAvailableQuest(i)
                return
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Gossip
--------------------------------------------------------------------------------

-- Gossip option icons Valet may click when they are the only option: the
-- plain chat bubble ("Continue", "Tell me more") and the services you came
-- for anyway (bank, battlemaster, guild charter, tabard, flight master,
-- trainer, vendor). Never the innkeeper's "make this inn your home", the
-- spirit healer or a talent reset; unknown icons are never clicked.
local GOSSIP_ICONS = {
    [132050] = true, -- banker
    [132051] = true, -- battlemaster
    [132053] = true, -- gossip
    [132055] = true, -- petition
    [132056] = true, -- tabard
    [132057] = true, -- taxi
    [132058] = true, -- trainer
    [132060] = true, -- vendor
}
local GOSSIP_ICON_NAMES = { "banker", "battlemaster", "gossipgossip", "petition", "tabard", "taxi", "trainer", "vendor" }

local function SafeGossipIcon(icon)
    if type(icon) == "number" then
        return GOSSIP_ICONS[icon] or false
    end
    if type(icon) == "string" then
        local lower = icon:lower()
        for _, name in ipairs(GOSSIP_ICON_NAMES) do
            if lower:find(name, 1, true) then
                return true
            end
        end
    end
    return false
end

-- An innkeeper offers two things: "make this inn your home" and "let me
-- browse your goods". The home is never picked, so the goods are the one way
-- forward; Valet opens the shop as it would for a lone vendor option.
local BINDER_ICON, VENDOR_ICON = 132052, 132060

local function IconIs(icon, id, name)
    if type(icon) == "number" then
        return icon == id
    end
    return type(icon) == "string" and icon:lower():find(name, 1, true) ~= nil
end

local function InnkeeperGoods(options)
    if #options ~= 2 then
        return
    end
    for i, option in ipairs(options) do
        local other = options[3 - i]
        if IconIs(option.icon, VENDOR_ICON, "vendor") and IconIs(other.icon, BINDER_ICON, "binder") then
            return option
        end
    end
end

local function OnGossipShow()
    BeginTalk()
    local gossip = C_GossipInfo
    if not gossip or talk.bypassed then
        return
    end
    local active = gossip.GetActiveQuests and gossip.GetActiveQuests() or {}
    local available = gossip.GetAvailableQuests and gossip.GetAvailableQuests() or {}

    if ValetDB.questTurnIn and gossip.SelectActiveQuest then
        for _, quest in ipairs(active) do
            if quest.isComplete and MayStep("turn in", quest.title) then
                gossip.SelectActiveQuest(quest.questID)
                return
            end
        end
    end
    if ValetDB.questAccept and gossip.SelectAvailableQuest then
        for _, quest in ipairs(available) do
            if not quest.isTrivial and MayStep("pick", quest.title) then
                gossip.SelectAvailableQuest(quest.questID)
                return
            end
        end
    end

    -- Gossip: only when nothing else is on offer, and not in dungeons and
    -- raids, where a lone option can start an event or a boss.
    if not ValetDB.skipGossip or #active > 0 or #available > 0 or not gossip.GetOptions or not gossip.SelectOption then
        return
    end
    local _, instanceType = IsInInstance()
    if instanceType == "party" or instanceType == "raid" then
        return
    end
    local options = gossip.GetOptions() or {}
    local option = #options == 1 and options[1] or InnkeeperGoods(options)
    if not option then
        if #options > 1 then
            talk.report:Note("left %s's gossip: %d options to choose from", talk.name, #options)
        end
        return
    end
    -- The game picks some lone options by itself; leave those to it.
    if option.selectOptionWhenOnlyOption or not SafeGossipIcon(option.icon) then
        return
    end
    -- Keyed by the NPC's text too: a chain of "Continue" pages is several
    -- steps, the same page shown again is not.
    local text = gossip.GetText and gossip.GetText() or ""
    if option.gossipOptionID and MayStep("gossip", text .. "|" .. (option.name or "")) then
        gossip.SelectOption(option.gossipOptionID)
        talk.report:Note("picked \"%s\" at %s", option.name or "?", talk.name)
    end
end

Valet.On("QUEST_DETAIL", OnQuestDetail)
Valet.On("QUEST_ACCEPT_CONFIRM", OnQuestAcceptConfirm)
Valet.On("QUEST_PROGRESS", OnQuestProgress)
Valet.On("QUEST_COMPLETE", OnQuestComplete)
Valet.On("QUEST_TURNED_IN", OnQuestTurnedIn)
Valet.On("QUEST_GREETING", OnQuestGreeting)
Valet.On("GOSSIP_SHOW", OnGossipShow)
Valet.On("QUEST_FINISHED", EndTalkSoon)
Valet.On("GOSSIP_CLOSED", EndTalkSoon)
