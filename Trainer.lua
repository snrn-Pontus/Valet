-- Train All: a button on the trainer window (and /valet train) that learns
-- every service the trainer lists as available, one at a time, cheapest
-- first, and never spends below your money reserve. Nothing happens until
-- you press it.

local _, ns = ...
local Valet = ns.core
local Money = Valet.Money

local trainerOpen = false
local ticker
local report
local learned, spent = 0, 0
local tried = {} -- [name .. rank] = true: asked for once already this press
local button

-- Cost of a service, and whether learning it takes up a profession slot.
-- That last one is a choice for you, so Train All leaves it.
local function ServiceCost(index)
    local money, _, professionCost = GetTrainerServiceCost(index)
    return money or 0, (professionCost or 0) > 0
end

-- Available services Train All would learn: count, total cost, the
-- cheapest one not yet tried (index, key, cost), and how many are untried.
-- Just-bought services can still show as available for a moment, so only
-- untried ones count as left to learn.
local function Scan()
    local count, total, untried = 0, 0, 0
    local nextIndex, nextKey, nextCost
    for index = 1, GetNumTrainerServices and GetNumTrainerServices() or 0 do
        local name, rank, category = GetTrainerServiceInfo(index)
        if name and category == "available" then
            local cost, newProfession = ServiceCost(index)
            if not newProfession then
                count = count + 1
                total = total + cost
                local key = name .. "\0" .. (rank or "")
                if not tried[key] then
                    untried = untried + 1
                    if not nextCost or cost < nextCost then
                        nextIndex, nextKey, nextCost = index, key, cost
                    end
                end
            end
        end
    end
    return count, total, nextIndex, nextKey, nextCost, untried
end

local function UpdateButton()
    if not button then
        return
    end
    local count, total = Scan()
    button:SetText(count > 0 and string.format("Train all (%d)", count) or "Train all")
    button:SetEnabled(count > 0 and not ticker)
    button.count, button.total = count, total
end

local function Finish()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if report then
        if learned > 0 then
            report:Did("learned %d %s for %s", learned, learned == 1 and "skill" or "skills", Money(spent))
        end
        local _, _, _, _, nextCost, left = Scan()
        if trainerOpen and left > 0 then
            report:Problem("%d left to learn, the cheapest for %s; not enough money above your %s reserve",
                left, Money(nextCost), Money(Valet.MoneyReserve()))
        end
        report:Finish()
        report = nil
    end
    UpdateButton()
end

-- One service per tick, re-read each time: the list and your money change
-- after every purchase.
local function TrainNext()
    if not trainerOpen then
        Finish()
        return
    end
    local _, _, index, key, cost = Scan()
    if not index or GetMoney() - cost < Valet.MoneyReserve() then
        Finish()
        return
    end
    tried[key] = true
    BuyTrainerService(index)
    learned = learned + 1
    spent = spent + cost
end

local function TrainAll()
    if not trainerOpen or ticker or not BuyTrainerService then
        return
    end
    report = Valet.BeginReport("trainer", "Trainer")
    learned, spent = 0, 0
    wipe(tried)
    if Scan() == 0 then
        report:Note("nothing to learn here right now")
        Finish()
        return
    end
    ticker = C_Timer.NewTicker(0.4, TrainNext)
    UpdateButton()
end

local function CreateButton()
    local parent = ClassTrainerFrame
    if button or not parent then
        return
    end
    button = CreateFrame("Button", "ValetTrainAllButton", parent, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    if ClassTrainerTrainButton then
        button:SetPoint("RIGHT", ClassTrainerTrainButton, "LEFT", -4, 0)
    else
        button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 20, 8)
    end
    button:SetScript("OnClick", TrainAll)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Train all", 1, 1, 1)
        GameTooltip:AddLine(string.format("Learns %d %s for %s.", self.count or 0,
            self.count == 1 and "skill" or "skills", Money(self.total or 0)), nil, nil, nil, true)
        GameTooltip:AddLine("Only what the trainer lists as available, cheapest first, and never below your money reserve. A new profession is left to you. Hidden by the trainer's filter means not counted.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function OnTrainerShow()
    trainerOpen = true
    -- The trainer window is loaded on demand and shown by the same event.
    C_Timer.After(0, function()
        CreateButton()
        UpdateButton()
    end)
end

local function OnTrainerUpdate()
    if trainerOpen and not ticker then
        UpdateButton()
    end
end

local function OnTrainerClosed()
    trainerOpen = false
    Finish()
end

Valet.On("TRAINER_SHOW", OnTrainerShow)
Valet.On("TRAINER_UPDATE", OnTrainerUpdate)
Valet.On("TRAINER_CLOSED", OnTrainerClosed)

Valet.AddCommand("train", "", "at a trainer: learn everything available (same as Train all)", function()
    if not trainerOpen then
        Valet.Print("talk to a trainer first.")
        return
    end
    TrainAll()
end)
