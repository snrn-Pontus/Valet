-- Presets: three starting points that flip a set of switches at once.
--
-- A preset is not a layer on top of your settings: applying one just sets
-- the switches it names, shows you which ones change first, and leaves
-- every switch free to change afterwards. Each preset names every switch
-- it touches, on or off, so a chore added later is never turned on by an
-- old preset unless it is added here on purpose. Preferences that are not
-- chores (chat, guild repairs, money reserve, whose mail to take, stranger
-- invites, deleting letters, taking a quest's only reward) are never
-- touched.

local _, ns = ...
local Valet = ns.core
local Print = Valet.Print

local CONSERVATIVE = {
    sellGreys = true,
    repair = true,
    declineDuels = true,
    declineGuild = true,
    declineCharters = true,
    confirmLoot = true,
    mailMoney = false,
    mailItems = false,
    questAccept = false,
    questTurnIn = false,
    skipGossip = false,
    acceptTrustedInvites = false,
    acceptSharedQuests = false,
    acceptRes = false,
    acceptSummon = false,
    releaseInBattlegrounds = false,
    skipSeenCinematics = false,
}

local function Extend(base, changes)
    local preset = {}
    for key, value in pairs(base) do
        preset[key] = value
    end
    for key, value in pairs(changes) do
        preset[key] = value
    end
    return preset
end

local CONVENIENT = Extend(CONSERVATIVE, {
    mailMoney = true,
    mailItems = true,
    questAccept = true,
    questTurnIn = true,
    skipGossip = true,
})

local HANDS_OFF = Extend(CONVENIENT, {
    acceptTrustedInvites = true,
    acceptSharedQuests = true,
    acceptRes = true,
    acceptSummon = true,
    releaseInBattlegrounds = true,
    skipSeenCinematics = true,
})

ns.presets = {
    {
        id = "conservative",
        name = "Conservative",
        text = "Sell greys, repair, and turn away duels, guild invites, charters and the Bind on Pickup popup. Nothing else.",
        values = CONSERVATIVE,
    },
    {
        id = "convenient",
        name = "Convenient",
        text = "Conservative, plus emptying the mail, accepting and turning in quests, and skipping one-option gossip.",
        values = CONVENIENT,
    },
    {
        id = "handsoff",
        name = "Hands off",
        text = "Convenient, plus invites and shared quests from people you know, resurrections, summons, releasing in battlegrounds and skipping cinematics you have seen.",
        values = HANDS_OFF,
    },
}

function ns.presets.Find(id)
    id = (id or ""):lower():gsub("[%s%-]", "")
    for _, preset in ipairs(ns.presets) do
        if preset.id == id then
            return preset
        end
    end
end

-- The switch names a preset would turn on and off, in settings order.
function ns.presets.Changes(preset)
    local on, off = {}, {}
    for _, entry in ipairs(Valet.SWITCHES) do
        local key, name = entry[1], entry[2]
        local value = preset.values[key]
        if value ~= nil and (ValetDB[key] and true or false) ~= value then
            table.insert(value and on or off, name)
        end
    end
    return on, off
end

function ns.presets.Describe(preset)
    local on, off = ns.presets.Changes(preset)
    if #on == 0 and #off == 0 then
        return nil
    end
    local lines = {}
    if #on > 0 then
        lines[#lines + 1] = "Turns on: " .. table.concat(on, ", ") .. "."
    end
    if #off > 0 then
        lines[#lines + 1] = "Turns off: " .. table.concat(off, ", ") .. "."
    end
    return table.concat(lines, "\n")
end

function ns.presets.Apply(preset)
    for key, value in pairs(preset.values) do
        ValetDB[key] = value
    end
    if ns.settings and ns.settings.Refresh then
        ns.settings.Refresh()
    end
    Print("applied the %s preset. Every setting can still be changed on its own.", preset.name)
end

--------------------------------------------------------------------------------
-- /valet preset
--------------------------------------------------------------------------------

local function HandlePresetCommand(arg)
    local name, apply = arg, false
    if arg:lower():match("%s+apply%s*$") then
        name, apply = arg:sub(1, #arg - #arg:match("%s+%S+%s*$")), true
    end
    local preset = ns.presets.Find(name)
    if not preset then
        Print("presets (/valet preset <name> shows what it changes):")
        for _, entry in ipairs(ns.presets) do
            Print("  %s: %s", entry.id, entry.text)
        end
        return
    end
    local changes = ns.presets.Describe(preset)
    if not changes then
        Print("your settings already match %s.", preset.name)
        return
    end
    if apply then
        ns.presets.Apply(preset)
        return
    end
    Print("%s would change:", preset.name)
    for line in changes:gmatch("[^\n]+") do
        Print("  %s", line)
    end
    Print("/valet preset %s apply to apply it.", preset.id)
end

Valet.AddCommand("preset", "<name> [apply]", "show what a preset changes, or apply it", HandlePresetCommand)
