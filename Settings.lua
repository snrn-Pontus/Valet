local _, ns = ...
local Valet = ns.core

-- Settings > AddOns > Valet.
--
-- Forever hangs when the Settings window is closed with the controller after
-- the gamepad cursor (SmartNavigation) has picked up addon-created controls,
-- and Blizzard's vertical-layout settings list triggers that on its own. So,
-- as in the other SNRN addons, this page is a canvas built once at login from
-- plain widgets and never announced to the cursor.

ns.settings = {}
local controls = {}
local registered = false
local panel

local function PanelVisible()
    return panel and panel:IsVisible()
end

local function AttachTooltip(control, title, text)
    control:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then
            GameTooltip:AddLine(text, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreateCheckbox(parent, key, labelText, tooltip, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 4, y)
    check:SetSize(26, 26)
    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.label:SetText(labelText)
    check:SetScript("OnClick", function(self)
        Valet.Set(key, self:GetChecked() and true or false)
    end)
    if tooltip then
        AttachTooltip(check, labelText, tooltip)
    end
    check.Refresh = function()
        check:SetChecked(ValetDB[key] and true or false)
    end
    controls[#controls + 1] = check
    return y - 30
end

-- A row of radio buttons for a setting with a few named values.
-- choices: { { value, label, tooltip }, ... }
local function CreateChoice(parent, key, labelText, choices, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 10, y - 5)
    label:SetText(labelText)
    local x = 10 + label:GetStringWidth() + 14
    local buttons = {}
    for _, choice in ipairs(choices) do
        local value = choice[1]
        local radio = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", x, y - 4)
        radio.label = radio:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        radio.label:SetPoint("LEFT", radio, "RIGHT", 2, 0)
        radio.label:SetText(choice[2])
        radio:SetHitRectInsets(0, -(radio.label:GetStringWidth() + 4), 0, 0)
        radio:SetScript("OnClick", function()
            Valet.Set(key, value)
        end)
        if choice[3] then
            AttachTooltip(radio, choice[2], choice[3])
        end
        buttons[#buttons + 1] = radio
        x = x + 16 + radio.label:GetStringWidth() + 18
    end
    controls[#controls + 1] = {
        Refresh = function()
            for i, radio in ipairs(buttons) do
                radio:SetChecked(ValetDB[key] == choices[i][1])
            end
        end,
    }
    return y - 30
end

-- A label and a small box for a whole number, saved when you press Enter
-- or leave the box.
local function CreateNumberInput(parent, key, labelText, suffix, tooltip, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 10, y - 6)
    label:SetText(labelText)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetPoint("LEFT", label, "RIGHT", 12, 0)
    box:SetSize(70, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(7)
    local unit = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    unit:SetPoint("LEFT", box, "RIGHT", 6, 0)
    unit:SetText(suffix)
    local function Save(self)
        Valet.Set(key, tonumber(self:GetText()) or 0)
        self:ClearFocus()
    end
    box:SetScript("OnEnterPressed", Save)
    box:SetScript("OnEditFocusLost", function(self)
        Valet.Set(key, tonumber(self:GetText()) or 0)
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(ValetDB[key] or 0))
        self:ClearFocus()
    end)
    if tooltip then
        AttachTooltip(box, labelText, tooltip)
    end
    controls[#controls + 1] = {
        Refresh = function()
            if not box:HasFocus() then
                box:SetText(tostring(ValetDB[key] or 0))
            end
        end,
    }
    return y - 32
end

-- A line of small print under a group of settings.
local function CreateNote(parent, text, y)
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 10, y - 2)
    note:SetWidth(530)
    note:SetJustifyH("LEFT")
    note:SetText(text)
    return y - (note:GetStringHeight() + 10)
end

local function CreateHeader(parent, text, y)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetPoint("TOPLEFT", 6, y)
    divider:SetSize(540, 1)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 6, y - 10)
    header:SetText(text)
    return y - 32
end

-- Asks before a preset changes anything, listing exactly what changes.
StaticPopupDialogs["VALET_APPLY_PRESET"] = {
    text = "Apply the %s preset?\n\n%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, preset)
        ns.presets.Apply(preset)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function CreatePresetRow(parent, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 10, y - 6)
    label:SetText("Start from a preset:")
    local previous
    for _, preset in ipairs(ns.presets) do
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(110, 22)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        else
            button:SetPoint("LEFT", label, "RIGHT", 12, 0)
        end
        button:SetText(preset.name)
        button:SetScript("OnClick", function()
            local changes = ns.presets.Describe(preset)
            if not changes then
                Valet.Print("your settings already match %s.", preset.name)
                return
            end
            StaticPopup_Show("VALET_APPLY_PRESET", preset.name, changes, preset)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(preset.name, 1, 1, 1)
            GameTooltip:AddLine(preset.text, nil, nil, nil, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns.presets.Describe(preset) or "Your settings already match it.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        previous = button
    end
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 10, y - 32)
    note:SetWidth(530)
    note:SetJustifyH("LEFT")
    note:SetText("A preset only flips the switches below, after showing which ones change. Every switch stays yours to change afterwards.")
    return y - 32 - (note:GetStringHeight() + 12)
end

function ns.settings.Refresh()
    if not PanelVisible() then
        return
    end
    for _, control in ipairs(controls) do
        control.Refresh()
    end
end

function ns.settings.Register()
    if registered or not Settings or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
        return
    end
    registered = true

    -- Hidden until the Settings window displays it, so OnShow always fires.
    panel = CreateFrame("Frame")
    panel.name = "Valet"
    panel:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(560, 1)
    scrollFrame:SetScrollChild(content)

    local y = -6
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 6, y)
    title:SetText("Valet")
    y = y - 26

    local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 6, y)
    note:SetWidth(540)
    note:SetJustifyH("LEFT")
    note:SetText("Small chores done for you. Set them once here and forget about them. Hold Shift as a merchant, mailbox or other interaction opens and Valet leaves that visit to you; nothing is changed here. With a controller, use the mouse on this page: the gamepad cursor cannot enter it without freezing Forever when Settings is closed.")
    y = y - (note:GetStringHeight() + 12)

    y = CreatePresetRow(content, y)

    y = CreateHeader(content, "At a merchant", y)
    y = CreateCheckbox(content, "sellGreys", "Sell grey items", "Sells every grey item in your bags when you talk to a merchant. Grey quest items, items the merchant will not buy and greys on Tally's keep list stay. Sold items can be bought back from the merchant's Buyback tab.", y)
    y = CreateCheckbox(content, "repair", "Repair all gear", "Repairs everything you wear and carry at a merchant that can repair, after the greys are sold so their money helps pay.", y)
    y = CreateCheckbox(content, "guildRepair", "Use guild funds for repairs", "Pays repairs from the guild bank when your rank allows it and the guild can cover the whole bill. Otherwise your own money is used.", y)

    y = CreateNumberInput(content, "moneyReserve", "Never spend below", "gold", "Restocking and Train All stop before your money would drop below this. Repairs are not limited by it.", y)
    y = CreateNote(content, "To sell other items too, type /valet sell and shift-click the item into chat. The list is per character; /valet selllist shows it, and the same command again takes an item off.", y)
    y = CreateNote(content, "To keep an item in stock, type /valet restock, shift-click the item into chat and add how many to keep, like 800 for arrows. Any merchant that sells it tops you up, after selling and repairing. Per character; /valet restock alone lists the rules, a count of 0 removes one.", y)

    y = CreateHeader(content, "At a trainer", y)
    y = CreateNote(content, "A Train all button on the trainer window learns every available skill, cheapest first, without going below the money above. Nothing is learned until you press it; with a controller, /valet train does the same.", y)

    y = CreateHeader(content, "At a mailbox", y)
    y = CreateCheckbox(content, "mailMoney", "Take gold from the mail", "Takes the gold from every letter when you open a mailbox: auction sales, refunds and money from other players. Cash on delivery mail and mail from a Game Master are left alone.", y)
    y = CreateCheckbox(content, "mailItems", "Take items from the mail", "Takes the attached items too, until your bags are full: won auctions, expired auctions and items from other players. Cash on delivery mail and mail from a Game Master are left alone.", y)
    y = CreateCheckbox(content, "mailDelete", "Delete the letters it empties", "Deletes a letter once Valet has taken everything from it, if it has no text to read. Letters with text, letters you could only return and letters Valet did not empty stay. Auction house mail disappears on its own anyway.", y)
    y = CreateChoice(content, "mailFrom", "Take from:", {
        { "all", "Everyone", "Takes from every letter except cash on delivery and Game Master mail." },
        { "trusted", "Auction house and friends", "Only auction house mail and letters from friends, Battle.net friends and guildmates. Other players' letters stay as they are." },
        { "auction", "Auction house only", "Only auction house mail: sales, won and expired auctions, outbid refunds." },
    }, y)

    y = CreateHeader(content, "Quests and gossip", y)
    y = CreateCheckbox(content, "questAccept", "Accept quests", "Accepts a quest as soon as an NPC, an object or an item offers it, and picks the quests an NPC offers one by one. Grey (trivial) quests in an NPC's list are left out.", y)
    y = CreateCheckbox(content, "questTurnIn", "Turn in finished quests", "Hands in a finished quest and takes its reward when there is none to choose. A quest with several rewards to choose from, or one that costs money to turn in, waits for you.", y)
    y = CreateCheckbox(content, "questSingleReward", "Take a quest's only reward", "When a quest has exactly one reward, turning it in takes that reward too. Off: such quests wait for you like those with several rewards.", y)
    y = CreateCheckbox(content, "skipGossip", "Skip gossip with only one option", "Clicks through an NPC's gossip when there is a single option and no quests: Continue pages, and the flight master, vendor, trainer or banker you came for. Never with two or more options, never the innkeeper's home, a spirit healer or a talent reset, and never in dungeons or raids.", y)

    y = CreateHeader(content, "Requests", y)
    y = CreateCheckbox(content, "declineDuels", "Decline duel requests", "Declines every duel request as soon as it arrives.", y)
    y = CreateCheckbox(content, "declineGuild", "Decline guild invites", "Declines every guild invite as soon as it arrives.", y)
    y = CreateCheckbox(content, "declineCharters", "Close guild charters", "Closes a guild or arena charter someone offers you to sign. Your own charter still opens.", y)
    y = CreateCheckbox(content, "acceptTrustedInvites", "Accept group invites from friends and guildmates", "Joins the group right away when a friend, a Battle.net friend or a guildmate invites you. Anyone else still gets the normal popup.", y)
    y = CreateCheckbox(content, "acceptSharedQuests", "Accept quests shared by people you know", "Accepts a quest shared by a group member, friend, Battle.net friend or guildmate, including escort quests they start. Quests shared by anyone else get the normal window.", y)
    y = CreateCheckbox(content, "declineStrangers", "Decline group invites from strangers", "Declines a group invite unless it comes from a friend, a Battle.net friend or a guildmate.", y)

    y = CreateHeader(content, "Popups", y)
    y = CreateCheckbox(content, "confirmLoot", "Confirm Bind on Pickup loot when solo", "Picks up Bind on Pickup loot without asking when you are not in a group, where it can only go to you anyway. In a group you are still asked.", y)
    y = CreateCheckbox(content, "acceptRes", "Accept resurrection", "Accepts a resurrection right away, unless the player casting it is in combat.", y)
    y = CreateCheckbox(content, "acceptSummon", "Accept summons", "Accepts a summon right away when you are out of combat.", y)
    y = CreateCheckbox(content, "releaseInBattlegrounds", "Release in battlegrounds", "Releases your spirit right after you die in a battleground, so you are back at the graveyard and in the fight sooner. Never outside battlegrounds, and never when you could raise yourself with a Soulstone or Reincarnation.", y)

    y = CreateHeader(content, "Cinematics", y)
    y = CreateCheckbox(content, "skipSeenCinematics", "Skip cinematics you have seen", "Stops a cinematic or movie that already played on any of your characters, like the race intro of your next character. One Valet has not seen always plays; hold Shift as it starts to watch it anyway. Valet only remembers what plays while it is installed.", y)

    y = CreateHeader(content, "Chat", y)
    y = CreateChoice(content, "notify", "Say in chat:", {
        { "verbose", "Everything", "Every action as it happens, and every chore Valet left alone and why." },
        { "summary", "Summaries", "One line per merchant or mailbox visit and per request, once it is over. Problems that need you show at once." },
        { "errors", "Problems only", "Only what needs you, like a repair you cannot afford or bags too full for the mail." },
        { "silent", "Nothing", "Nothing at all, not even problems. /valet last still shows what Valet did." },
    }, y)

    content:SetHeight(-y + 10)

    -- Deliberately not announced to the gamepad cursor (SmartNavigation):
    -- the controls exist from login and are only reparented into the
    -- Settings window, so the cursor never picks them up on its own.
    panel:SetScript("OnShow", ns.settings.Refresh)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.settings.category = category
end

function ns.settings.Open()
    if not registered then
        ns.settings.Register()
    end
    if ns.settings.category and Settings and type(Settings.OpenToCategory) == "function" then
        Settings.OpenToCategory(ns.settings.category:GetID())
    end
end
