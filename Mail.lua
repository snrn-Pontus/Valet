-- Mailbox: take the gold and items, then optionally delete the letters
-- Valet emptied.

local _, ns = ...
local Valet = ns.core
local Money = Valet.Money

local mailOpen = false
local report -- this visit's report
local mailPending = false -- the inbox is not loaded yet when MAIL_SHOW fires
local mailTicker
local startMoney = 0
local takenItems = 0
local deletedLetters = 0
local letterCount = {}  -- [letterKey] = true: letters taken from, for chat
local taken = {}        -- [letterKey] = true: Valet took something from this letter
local trustCache = {}   -- [sender] = whether trusted, looked up once per visit
local refused = {}      -- [key] = item name: given up on after MAIL_ATTEMPTS
local itemRequests = {} -- [key] = { index, attachment, name, count } not yet gone
local mailTried = {}    -- [key] = time: asked for, the inbox has not caught up yet
local mailAttempts = {} -- [key] = count: given up after MAIL_ATTEMPTS

local MAIL_RETRY = 2    -- seconds before asking for the same gold or item again
local MAIL_ATTEMPTS = 3 -- a unique item you already carry is refused for good

-- Senders "trusted" mode takes from, besides the auction house.
local MAIL_TRUST = { friends = true, bnet = true, guild = true }

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

--------------------------------------------------------------------------------
-- Which letters to touch
--------------------------------------------------------------------------------

-- Subject patterns of the auction house's letters, from the client's own
-- strings: "Auction successful: %s" becomes "^Auction successful: .+$".
local auctionSubjects
local function AuctionSubjects()
    if auctionSubjects then
        return auctionSubjects
    end
    auctionSubjects = {}
    local formats = {
        AUCTION_SOLD_MAIL_SUBJECT, AUCTION_WON_MAIL_SUBJECT, AUCTION_EXPIRED_MAIL_SUBJECT,
        AUCTION_OUTBID_MAIL_SUBJECT, AUCTION_REMOVED_MAIL_SUBJECT,
    }
    for _, format in pairs(formats) do
        if type(format) == "string" then
            local pattern = format:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1"):gsub("%%%%s", ".+")
            auctionSubjects[#auctionSubjects + 1] = "^" .. pattern .. "$"
        end
    end
    return auctionSubjects
end

local function IsAuctionMail(index, subject)
    if GetInboxInvoiceInfo and GetInboxInvoiceInfo(index) then
        return true
    end
    if subject then
        for _, pattern in ipairs(AuctionSubjects()) do
            if subject:match(pattern) then
                return true
            end
        end
    end
    return false
end

-- Whether the sender setting (ValetDB.mailFrom) lets Valet touch a letter.
local function SenderAllowed(index, sender, subject)
    local mode = ValetDB.mailFrom
    if mode ~= "auction" and mode ~= "trusted" then
        return true
    end
    if IsAuctionMail(index, subject) then
        return true
    end
    if mode ~= "trusted" or not sender then
        return false
    end
    if trustCache[sender] == nil then
        trustCache[sender] = Valet.IsTrusted(sender, nil, MAIL_TRUST) ~= nil
    end
    return trustCache[sender]
end

-- A letter Valet emptied this visit, with nothing left to read, may go.
-- Anything unclear keeps it: a body the client has not loaded, a letter
-- the client would only return, or one Valet did not take from itself.
-- A letter is known by its place, sender and subject together: Valet
-- works from the last letter up, so the letters it has yet to reach keep
-- their place when one it finished disappears.
local function CanDelete(index, letterKey, money, itemCount)
    if not ValetDB.mailDelete or not DeleteInboxItem or not taken[letterKey] then
        return false
    end
    if (money or 0) > 0 or (itemCount or 0) > 0 then
        return false
    end
    if InboxItemCanDelete and not InboxItemCanDelete(index) then
        return false
    end
    local body = GetInboxText and GetInboxText(index)
    return type(body) == "string" and not body:find("%S")
end

--------------------------------------------------------------------------------
-- Collecting
--------------------------------------------------------------------------------

local function MarkTaken(letterKey)
    taken[letterKey] = true
    letterCount[letterKey] = true
end

-- Returns what to do next: "money", index; "item", index, attachment;
-- "delete", index; "wait" while the server still answers an earlier
-- request; "full" when items are left but the bags are; or nil when done.
-- Cash on delivery mail and mail from a Game Master are left alone.
local function NextMailAction()
    ConfirmItemRequests()
    local now = GetTime()
    local waiting, full = false, false
    local maxAttachments = ATTACHMENTS_MAX_RECEIVE or 16
    for index = GetInboxNumItems(), 1, -1 do
        local _, _, sender, subject, money, cod, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(index)
        if not isGM and (cod or 0) == 0 and SenderAllowed(index, sender, subject) then
            local letterKey = index .. "\0" .. (sender or "") .. "\0" .. (subject or "")
            if ValetDB.mailMoney and money and money > 0 then
                local key = "m" .. index
                local state = MailRequestState(key, now)
                if state == "wait" then
                    waiting = true
                elseif state == "take" then
                    MarkMailRequest(key, now)
                    MarkTaken(letterKey)
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
                        elseif state == "skip" then
                            refused[key] = name
                        elseif Valet.FreeBagSlots() == 0 then
                            full = true
                        else
                            MarkMailRequest(key, now)
                            MarkTaken(letterKey)
                            itemRequests[key] = { index, attachment, name, count or 1 }
                            return "item", index, attachment
                        end
                    end
                end
            end
            if CanDelete(index, letterKey, money, itemCount) then
                local key = "d" .. index
                local state = MailRequestState(key, now)
                if state == "wait" then
                    waiting = true
                elseif state == "take" then
                    MarkMailRequest(key, now)
                    deletedLetters = deletedLetters + 1
                    taken[letterKey] = nil
                    return "delete", index
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

local function Count(n, singular, plural)
    return string.format("%d %s", n, n == 1 and singular or plural)
end

local function FinishMail(bagsFull)
    StopMail()
    if not report or report.finished then
        return
    end
    -- Gold from what actually arrived, items from what left the inbox.
    local takenMoney = GetMoney() - startMoney
    local parts = {}
    if takenMoney > 0 then
        parts[#parts + 1] = Money(takenMoney)
    end
    if takenItems > 0 then
        parts[#parts + 1] = Count(takenItems, "item", "items")
    end
    if #parts > 0 then
        local letters = 0
        for _ in pairs(letterCount) do
            letters = letters + 1
        end
        report:Did("took %s from %s", table.concat(parts, " and "), Count(letters, "letter", "letters"))
    end
    if deletedLetters > 0 then
        report:Did("deleted %s", Count(deletedLetters, "empty letter", "empty letters"))
    end
    for _, name in pairs(refused) do
        report:Problem("left %s in the mail; it could not be taken (a unique item you already carry?)", name)
    end
    if bagsFull then
        report:Problem("your bags are full; the rest of the items are still in the mail")
    end
    if ValetDB.mailFrom == "auction" then
        report:Note("only touched auction house mail")
    elseif ValetDB.mailFrom == "trusted" then
        report:Note("only touched auction house mail and mail from friends and guildmates")
    end
    report:Finish()
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
    elseif action == "delete" then
        DeleteInboxItem(index)
    elseif action ~= "wait" then
        FinishMail(action == "full")
    end
end

local function StartMail()
    startMoney = GetMoney()
    takenItems = 0
    deletedLetters = 0
    wipe(letterCount)
    wipe(trustCache)
    wipe(taken)
    wipe(refused)
    wipe(itemRequests)
    wipe(mailTried)
    wipe(mailAttempts)
    StopMail()
    mailTicker = C_Timer.NewTicker(0.3, MailNext)
end

local function OnMailShow()
    mailOpen = true
    report = Valet.BeginReport("mail", "Mailbox")
    mailPending = (ValetDB.mailMoney or ValetDB.mailItems) and true or false
    if mailPending and Valet.Bypassed() then
        mailPending = false
        report:Note("left the mail alone because Shift was held")
    end
end

local function OnMailInboxUpdate()
    if mailOpen and mailPending then
        mailPending = false
        StartMail()
    end
end

-- Closing early still reports what was taken before it.
local function OnMailClosed()
    local collecting = mailTicker ~= nil
    mailOpen = false
    mailPending = false
    if collecting then
        FinishMail(false)
    end
end

Valet.On("MAIL_SHOW", OnMailShow)
Valet.On("MAIL_INBOX_UPDATE", OnMailInboxUpdate)
Valet.On("MAIL_CLOSED", OnMailClosed)
