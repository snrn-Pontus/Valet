-- Mailbox: take the gold and items.

local _, ns = ...
local Valet = ns.core
local Notify, Money = Valet.Notify, Valet.Money

local mailOpen = false
local mailPending = false -- the inbox is not loaded yet when MAIL_SHOW fires
local mailTicker
local startMoney = 0
local takenItems = 0
local itemRequests = {} -- [key] = { index, attachment, name, count } not yet gone
local mailTried = {}    -- [key] = time: asked for, the inbox has not caught up yet
local mailAttempts = {} -- [key] = count: given up after MAIL_ATTEMPTS

local MAIL_RETRY = 2    -- seconds before asking for the same gold or item again
local MAIL_ATTEMPTS = 3 -- a unique item you already carry is refused for good

-- "take" the first time and after MAIL_RETRY, "wait" in between, "skip"
-- once the server has refused it MAIL_ATTEMPTS times.
local function MailRequestState(key, now)
    if mailTried[key] and now - mailTried[key] < MAIL_RETRY then
        return "wait"
    end
    if (mailAttempts[key] or 0) >= MAIL_ATTEMPTS then
        return "skip"
    end
    return "take"
end

local function MarkMailRequest(key, now)
    mailTried[key] = now
    mailAttempts[key] = (mailAttempts[key] or 0) + 1
end

-- An item counts as taken once its attachment slot no longer holds it.
local function ConfirmItemRequests()
    for key, request in pairs(itemRequests) do
        if GetInboxItem(request[1], request[2]) ~= request[3] then
            takenItems = takenItems + request[4]
            itemRequests[key] = nil
        end
    end
end

-- Returns what to take next: "money", index; "item", index, attachment;
-- "wait" while the server still answers an earlier request; "full" when
-- items are left but the bags are; or nil when done. Cash on delivery mail
-- and mail from a Game Master are left alone.
local function NextMailAction()
    ConfirmItemRequests()
    local now = GetTime()
    local waiting, full = false, false
    local maxAttachments = ATTACHMENTS_MAX_RECEIVE or 16
    for index = GetInboxNumItems(), 1, -1 do
        local _, _, _, _, money, cod, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(index)
        if not isGM and (cod or 0) == 0 then
            if ValetDB.mailMoney and money and money > 0 then
                local key = "m" .. index
                local state = MailRequestState(key, now)
                if state == "wait" then
                    waiting = true
                elseif state == "take" then
                    MarkMailRequest(key, now)
                    return "money", index
                end
            end
            if ValetDB.mailItems and itemCount and itemCount > 0 then
                for attachment = 1, maxAttachments do
                    local name, _, _, count = GetInboxItem(index, attachment)
                    if name then
                        local key = "i" .. index .. "." .. attachment
                        local state = MailRequestState(key, now)
                        if state == "wait" then
                            waiting = true
                        elseif state == "take" then
                            if Valet.FreeBagSlots() == 0 then
                                full = true
                            else
                                MarkMailRequest(key, now)
                                itemRequests[key] = { index, attachment, name, count or 1 }
                                return "item", index, attachment
                            end
                        end
                    end
                end
            end
        end
    end
    if waiting then
        return "wait"
    end
    return full and "full" or nil
end

local function StopMail()
    if mailTicker then
        mailTicker:Cancel()
        mailTicker = nil
    end
end

local function FinishMail(bagsFull)
    StopMail()
    -- Gold from what actually arrived, items from what left the inbox.
    local takenMoney = GetMoney() - startMoney
    local parts = {}
    if takenMoney > 0 then
        parts[#parts + 1] = Money(takenMoney)
    end
    if takenItems > 0 then
        parts[#parts + 1] = string.format("%d %s", takenItems, takenItems == 1 and "item" or "items")
    end
    if #parts > 0 then
        Notify("Took %s from the mail.", table.concat(parts, " and "))
    end
    if bagsFull then
        Notify("Your bags are full; the rest of the items are still in the mail.")
    end
end

-- One request per tick, like selling: the inbox only changes once the
-- server has answered, and asking too fast gets requests dropped.
local function MailNext()
    if not mailOpen then
        StopMail()
        return
    end
    local action, index, attachment = NextMailAction()
    if action == "money" then
        TakeInboxMoney(index)
    elseif action == "item" then
        TakeInboxItem(index, attachment)
    elseif action ~= "wait" then
        FinishMail(action == "full")
    end
end

local function StartMail()
    startMoney = GetMoney()
    takenItems = 0
    wipe(itemRequests)
    wipe(mailTried)
    wipe(mailAttempts)
    StopMail()
    mailTicker = C_Timer.NewTicker(0.3, MailNext)
end

local function OnMailShow()
    mailOpen = true
    mailPending = (ValetDB.mailMoney or ValetDB.mailItems) and not IsShiftKeyDown()
end

local function OnMailInboxUpdate()
    if mailOpen and mailPending then
        mailPending = false
        StartMail()
    end
end

local function OnMailClosed()
    mailOpen = false
    mailPending = false
    StopMail()
end

Valet.On("MAIL_SHOW", OnMailShow)
Valet.On("MAIL_INBOX_UPDATE", OnMailInboxUpdate)
Valet.On("MAIL_CLOSED", OnMailClosed)
