-- Requests (duels, guild invites, charters, group invites) and popups
-- (Bind on Pickup loot, resurrection, summons).

local _, ns = ...
local Valet = ns.core
local Notify, HidePopup = Valet.Notify, Valet.HidePopup

--------------------------------------------------------------------------------
-- Requests
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

Valet.On("DUEL_REQUESTED", OnDuelRequested)
Valet.On("GUILD_INVITE_REQUEST", OnGuildInvite)
Valet.On("PETITION_SHOW", OnPetitionShow)
Valet.On("PARTY_INVITE_REQUEST", OnPartyInvite)
Valet.On("LOOT_BIND_CONFIRM", OnLootBindConfirm)
Valet.On("RESURRECT_REQUEST", OnResurrectRequest)
Valet.On("CONFIRM_SUMMON", OnConfirmSummon)
