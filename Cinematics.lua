-- Skip cinematics and movies you have already seen.
--
-- Valet remembers, account-wide, every movie (by its ID) and every in-game
-- cinematic (by where it started: map, zone, subzone and your position)
-- that played. With the setting on, one that played before is stopped as
-- it starts; one Valet has not seen always plays, and so does anything
-- while you hold Shift. Remembering happens whether the setting is on or
-- not, so turning it on later still never skips something new.

local _, ns = ...
local Valet = ns.core

-- Where a cinematic started. Two cinematics only share this when they
-- start on the same spot, like every new character's race intro. Nil when
-- your position is unknown, as in some instances: every cinematic there
-- would look the same, so none is remembered or skipped.
local function CinematicKey()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if position then
        x, y = position:GetXY()
    end
    if not x or not y then
        return nil
    end
    return string.format("%s|%s|%s|%.2f|%.2f", tostring(mapID), GetZoneText and GetZoneText() or "",
        GetSubZoneText and GetSubZoneText() or "", x, y)
end

-- Records it as seen; true when it had been seen before and may go.
local function Seen(list, key)
    local seen = ValetDB.seen[list]
    local before = seen[key] and true or false
    seen[key] = true
    return before and ValetDB.skipSeenCinematics and not Valet.Bypassed()
end

local function OnCinematicStart(canBeCancelled)
    -- Not a real cinematic but a vehicle or scripted camera: nothing to skip.
    if not canBeCancelled then
        return
    end
    local key = CinematicKey()
    if not key or not Seen("cinematics", key) then
        return
    end
    -- The cinematic frame opens from this same event; stop it a frame later.
    C_Timer.After(0, function()
        if InCinematic and InCinematic() and StopCinematic then
            StopCinematic()
            Valet.Report("cinematic", "Cinematic", "skipped a cinematic you have seen before")
        end
    end)
end

local function OnPlayMovie(movieID)
    if not movieID or not Seen("movies", movieID) then
        return
    end
    C_Timer.After(0, function()
        if not MovieFrame or not MovieFrame:IsShown() or MovieFrame.movieID ~= movieID then
            return
        end
        if MovieFrame.FinishMovie then
            MovieFrame:FinishMovie()
        else
            MovieFrame:Hide()
        end
        Valet.Report("cinematic", "Cinematic", "skipped a movie you have seen before")
    end)
end

Valet.On("CINEMATIC_START", OnCinematicStart)
Valet.On("PLAY_MOVIE", OnPlayMovie)
