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
    note:SetText("Small chores done for you. Set them once here and forget about them. Hold Shift while opening a merchant or mailbox to skip its chores for that visit. With a controller, use the mouse on this page: the gamepad cursor cannot enter it without freezing Forever when Settings is closed.")
    y = y - (note:GetStringHeight() + 12)

    y = CreateHeader(content, "At a merchant", y)
    y = CreateCheckbox(content, "sellGreys", "Sell grey items", "Sells every grey item in your bags when you talk to a merchant. Grey quest items, items the merchant will not buy and greys on Tally's keep list stay. Sold items can be bought back from the merchant's Buyback tab.", y)
    y = CreateCheckbox(content, "repair", "Repair all gear", "Repairs everything you wear and carry at a merchant that can repair, after the greys are sold so their money helps pay.", y)
    y = CreateCheckbox(content, "guildRepair", "Use guild funds for repairs", "Pays repairs from the guild bank when your rank allows it and the guild can cover the whole bill. Otherwise your own money is used.", y)

    y = CreateHeader(content, "At a mailbox", y)
    y = CreateCheckbox(content, "mailMoney", "Take gold from the mail", "Takes the gold from every letter when you open a mailbox: auction sales, refunds and money from other players. Cash on delivery mail and mail from a Game Master are left alone.", y)
    y = CreateCheckbox(content, "mailItems", "Take items from the mail", "Takes the attached items too, until your bags are full: won auctions, expired auctions and items from other players. Cash on delivery mail and mail from a Game Master are left alone.", y)

    y = CreateHeader(content, "Requests", y)
    y = CreateCheckbox(content, "declineDuels", "Decline duel requests", "Declines every duel request as soon as it arrives.", y)
    y = CreateCheckbox(content, "declineGuild", "Decline guild invites", "Declines every guild invite as soon as it arrives.", y)
    y = CreateCheckbox(content, "declineCharters", "Close guild charters", "Closes a guild or arena charter someone offers you to sign. Your own charter still opens.", y)
    y = CreateCheckbox(content, "declineStrangers", "Decline group invites from strangers", "Declines a group invite unless it comes from a friend, a Battle.net friend or a guildmate.", y)

    y = CreateHeader(content, "Popups", y)
    y = CreateCheckbox(content, "confirmLoot", "Confirm Bind on Pickup loot when solo", "Picks up Bind on Pickup loot without asking when you are not in a group, where it can only go to you anyway. In a group you are still asked.", y)
    y = CreateCheckbox(content, "acceptRes", "Accept resurrection", "Accepts a resurrection right away, unless the player casting it is in combat.", y)
    y = CreateCheckbox(content, "acceptSummon", "Accept summons", "Accepts a summon right away when you are out of combat.", y)

    y = CreateHeader(content, "Chat", y)
    y = CreateCheckbox(content, "chat", "Say in chat what Valet did", "Prints a line for each sale total, repair, mail collection, declined request and accepted popup.", y)

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
