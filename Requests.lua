-- Requests (duels, guild invites, charters, group invites) and popups
-- (Bind on Pickup loot, resurrection, summons, releasing in battlegrounds).

local _, ns = ...
local Valet = ns.core
local Report, HidePopup = Valet.Report, Valet.HidePopup

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------

-- Who may invite you without being declined as a stranger.
local INVITE_TRUST = { friends = true, bnet = true, guild = true }

local function OnDuelRequested(name)
    if not ValetDB.declineDuels then
        return
    end
    CancelDuel()
    HidePopup("DUEL_REQUESTED")
    Report("duel", "Duel", "declined a duel from %s", name or "someone")
end

local function OnGuildInvite(inviter, guildName)
    if not ValetDB.declineGuild then
        return
    end
    DeclineGuild()
    HidePopup("GUILD_INVITE")
    Report("guild", "Guild invite", "declined a guild invite from %s (%s)", inviter or "someone", guildName or "?")
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
    Report("charter", "Charter", "closed %s's charter for %s", originator or "someone", title)
end

-- The invite popup declines the invite whenever it hides, unless it was
-- told the invite was accepted; tell it before hiding, now and on the next
-- frame in case it only shows after Valet has answered.
local function HideAcceptedInvite()
    local function Hide()
        local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible("PARTY_INVITE")
        if dialog then
            dialog.inviteAccepted = 1
            dialog:Hide()
        end
    end
    Hide()
    C_Timer.After(0, Hide)
end

-- Trusted players are let in first; only then are strangers turned away.
local function OnPartyInvite(name, ...)
    if not ValetDB.acceptTrustedInvites and not ValetDB.declineStrangers then
        return
    end
    local guid = select(6, ...)
    local trustedAs = Valet.IsTrusted(name, guid, INVITE_TRUST)
    if trustedAs then
        if ValetDB.acceptTrustedInvites and AcceptGroup then
            AcceptGroup()
            HideAcceptedInvite()
            Report("invite", "Group invite", "joined %s's group (%s)", name or "someone", Valet.TRUST_LABELS[trustedAs])
        end
        return
    end
    if not ValetDB.declineStrangers then
        return
    end
    DeclineGroup()
    HidePopup("PARTY_INVITE")
    Report("invite", "Group invite", "declined a group invite from %s, who is not a friend or guildmate", name or "someone")
end

--------------------------------------------------------------------------------
-- Popups
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
    Report("resurrect", "Resurrection", "accepted resurrection from %s", name or "someone")
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
    Report("summon", "Summon", "accepted a summon from %s to %s", summoner or "someone", area or "?")
end

-- In a battleground, releasing is routine: you rise at the graveyard and
-- rejoin. Only there, and never when you could raise yourself (Soulstone,
-- Reincarnation), which is a choice for you.
local function OnPlayerDead()
    if not ValetDB.releaseInBattlegrounds or not RepopMe or not IsInInstance then
        return
    end
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "pvp" then
        return
    end
    if HasSoulstone and HasSoulstone() then
        return
    end
    if C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions then
        local options = C_DeathInfo.GetSelfResurrectOptions()
        if options and #options > 0 then
            return
        end
    end
    -- Once per death, a moment after it: the death popup is up by then,
    -- and a resurrection already on its way has had a chance to arrive.
    C_Timer.After(0.5, function()
        if not UnitIsDead("player") or UnitIsGhost("player") then
            return
        end
        if select(2, IsInInstance()) ~= "pvp" then
            return
        end
        RepopMe()
        HidePopup("DEATH")
        Report("release", "Battleground", "released your spirit")
    end)
end

Valet.On("DUEL_REQUESTED", OnDuelRequested)
Valet.On("GUILD_INVITE_REQUEST", OnGuildInvite)
Valet.On("PETITION_SHOW", OnPetitionShow)
Valet.On("PARTY_INVITE_REQUEST", OnPartyInvite)
Valet.On("LOOT_BIND_CONFIRM", OnLootBindConfirm)
Valet.On("RESURRECT_REQUEST", OnResurrectRequest)
Valet.On("CONFIRM_SUMMON", OnConfirmSummon)
Valet.On("PLAYER_DEAD", OnPlayerDead)
