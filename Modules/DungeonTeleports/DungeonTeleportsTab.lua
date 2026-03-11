local function GetSpellCooldownWrapper(spellID)
    -- Use C_Spell.GetSpellCooldown and handle protected secret numbers
    if _G.GetSpellCooldown then
         return _G.GetSpellCooldown(spellID)
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime, info.duration
        end
    end
    return 0, 0
end

local function GetSpellNameWrapper(spellID)
    if not spellID or spellID <= 0 then
        return nil
    end

    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(spellID)
        if name then
            return name
        end
    end

    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name then
            return name
        end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then
            return info.name
        end
    end

    if _G.GetSpellLink then
        local link = _G.GetSpellLink(spellID)
        if link then
            local name = link:match("%[(.-)%]")
            if name and name ~= "" then
                return name
            end
        end
    end

    return nil
end

local function ClearTeleportButtonAction(btn)
    if not btn then
        return
    end

    btn:SetAttribute("type", nil)
    btn:SetAttribute("type1", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("spell1", nil)
end

local function ShouldUseActionButtonKeyDown()
    if _G.GetCVarBool then
        return _G.GetCVarBool("ActionButtonUseKeyDown")
    end
    if _G.GetCVar then
        return tostring(_G.GetCVar("ActionButtonUseKeyDown")) == "1"
    end
    return false
end

local function ConfigureTeleportButtonClicks(btn)
    if not btn or not btn.RegisterForClicks then
        return
    end

    if ShouldUseActionButtonKeyDown() then
        btn:RegisterForClicks("LeftButtonDown")
    else
        btn:RegisterForClicks("LeftButtonUp")
    end
end

local function SetTeleportButtonSpellAction(btn, spellID)
    if not btn or not spellID or spellID <= 0 then
        ClearTeleportButtonAction(btn)
        return false
    end

    -- Prefer localized spell name but always fallback to spellID token.
    local spellToken = GetSpellNameWrapper(spellID) or spellID
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("type1", "spell")
    btn:SetAttribute("spell", spellToken)
    btn:SetAttribute("spell1", spellToken)
    return true
end

local function RefreshButtonCooldown(btn)
    if not btn or not btn.cooldown then return end
    if not btn.isKnown or not btn.currentSpellID or btn.currentSpellID <= 0 then
        btn.cooldown:Hide()
        return
    end

    local start, duration = GetSpellCooldownWrapper(btn.currentSpellID)
    if start and duration then
        -- Avoid numeric comparisons here because C_Spell can return protected secret numbers
        btn.cooldown:SetCooldown(start, duration)
        btn.cooldown:Show()
    else
        btn.cooldown:Hide()
    end
end

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function IsTeleportSpellKnown(spellID)
    if not spellID or spellID <= 0 then
        return false
    end

    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then
        return true
    end

    if IsPlayerSpell and IsPlayerSpell(spellID) then
        return true
    end

    if IsSpellKnown and IsSpellKnown(spellID) then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known then
            return true
        end
    end

    return false
end

local function GetSecondsUntilWeeklyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local seconds = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if seconds and seconds > 0 then
            return seconds
        end
    end
    if _G.GetSecondsUntilWeeklyReset then
        local seconds = _G.GetSecondsUntilWeeklyReset()
        if seconds and seconds > 0 then
            return seconds
        end
    end
    return nil
end

local function GetSecondsUntilDailyReset()
    if _G.GetQuestResetTime then
        local seconds = _G.GetQuestResetTime()
        if seconds and seconds > 0 then
            return seconds
        end
    end
    return nil
end

local function ParseYMD(ymd)
    if not ymd then
        return nil
    end

    local value = tostring(ymd)
    if value:len() ~= 8 then
        return nil
    end

    local year = tonumber(value:sub(1, 4))
    local month = tonumber(value:sub(5, 6))
    local day = tonumber(value:sub(7, 8))
    if not year or not month or not day then
        return nil
    end

    if month < 1 or month > 12 then
        return nil
    end

    local daysInMonth = ({31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31})[month]
    local isLeapYear = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
    if month == 2 and isLeapYear then
        daysInMonth = 29
    end

    if day < 1 or day > daysInMonth then
        return nil
    end

    return year, month, day
end

-- Converts a YMD date to the number of days since the Unix epoch (January 1, 1970).
-- This code will make sure addon will function correctly even if the client is using a non-Gregorian calendar or has a different epoch, as it relies on the same underlying date calculations as the game's date functions.
local function YMDToEpochDays(year, month, day)
    local y = year
    if month <= 2 then
        y = y - 1
    end
    local era
    if y >= 0 then
        era = math.floor(y / 400)
    else
        era = math.floor((y - 399) / 400)
    end
    local yoe = y - (era * 400)
    local mp
    if month > 2 then
        mp = month - 3
    else
        mp = month + 9
    end
    local doy = math.floor((153 * mp + 2) / 5) + day - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

local function EpochDaysToYMD(daysSinceEpoch)
    local z = daysSinceEpoch + 719468
    local era
    if z >= 0 then
        era = math.floor(z / 146097)
    else
        era = math.floor((z - 146096) / 146097)
    end
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local day = doy - math.floor((153 * mp + 2) / 5) + 1
    local month
    if mp < 10 then
        month = mp + 3
    else
        month = mp - 9
    end
    if month <= 2 then
        y = y + 1
    end
    return y, month, day
end

local function ShiftYMDByDays(ymd, days)
    local year, month, day = ParseYMD(ymd)
    if not year then
        return ymd
    end

    if not days or days == 0 then
        return tonumber(string.format("%04d%02d%02d", year, month, day))
    end

    local shiftedDays = YMDToEpochDays(year, month, day) + days
    local shiftedYear, shiftedMonth, shiftedDay = EpochDaysToYMD(shiftedDays)
    return tonumber(string.format("%04d%02d%02d", shiftedYear, shiftedMonth, shiftedDay))
end

local function DetectRegionForWeeklyReset()
    local portal = _G.GetCVar and _G.GetCVar("portal")
    if portal and portal ~= "" then
        portal = string.upper(portal)
        if portal == "EU" then
            return "EU"
        end
        if portal == "KR" or portal == "TW" or portal == "CN" then
            return "ASIA"
        end
        return "US"
    end

    if _G.GetCurrentRegion then
        local regionID = _G.GetCurrentRegion()
        if regionID == 3 then
            return "EU"
        end
        if regionID == 2 or regionID == 4 or regionID == 5 then
            return "ASIA"
        end
    end

    return "EU"
end

local function ConvertEUWeeklyYMDToCurrentRegion(ymd)
    local region = DetectRegionForWeeklyReset()
    if region == "US" then
        return ShiftYMDByDays(ymd, -1) -- US is 1 day before EU for weekly resets
    end
    return tonumber(ymd) or ymd
end

local function GetNextResetTimestamp(resetType)
    local now = GetServerTime()
    local seconds = resetType == "daily" and GetSecondsUntilDailyReset() or GetSecondsUntilWeeklyReset()
    if not seconds then
        return nil
    end
    return now + seconds
end

local function GetYMDTimestampAtReset(ymd, resetType)
    local year, month, day = ParseYMD(ymd)
    if not year then
        return nil
    end

    local nextReset = GetNextResetTimestamp(resetType or "weekly")
    if not nextReset then
        return nil
    end

    local resetDate = date("*t", nextReset)
    if not resetDate then
        return nil
    end

    local baseDays = YMDToEpochDays(resetDate.year, resetDate.month, resetDate.day)
    local targetDays = YMDToEpochDays(year, month, day)
    return nextReset + ((targetDays - baseDays) * 86400)
end

local function GetTodayYMD()
    return tonumber(date("%Y%m%d", GetServerTime()))
end

local function FormatRemainingDuration(remaining)
    if not remaining or remaining <= 0 then
        return "00h 00m"
    end

    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local minutes = math.floor((remaining % 3600) / 60)

    if days > 0 then
        return string.format("%dd %02dh %02dm", days, hours, minutes)
    end
    return string.format("%02dh %02dm", hours, minutes)
end

local function GetSeasonEndTimestampForDisplay(endsYMD)
    local regionEndsYMD = ConvertEUWeeklyYMDToCurrentRegion(endsYMD)
    local endsNumber = tonumber(regionEndsYMD)
    if not endsNumber then
        return nil
    end

    if endsNumber == GetTodayYMD() then
        local nextDaily = GetNextResetTimestamp("daily")
        if nextDaily then
            return nextDaily
        end
    end

    return GetYMDTimestampAtReset(regionEndsYMD, "weekly")
end

local function GetPostSeasonEndTimestamp(postEndsYMD)
    return GetYMDTimestampAtReset(ConvertEUWeeklyYMDToCurrentRegion(postEndsYMD), "weekly")
end

local function GetSeasonStartTimestamp(startsYMD)
    if not startsYMD then
        return nil
    end
    return GetYMDTimestampAtReset(ConvertEUWeeklyYMDToCurrentRegion(startsYMD), "weekly")
end

local function ResolveObtainableState(obtainable, startsYMD, endsYMD, postEndsYMD)
    if obtainable == false then
        return false
    end

    local now = GetServerTime()
    local startTimestamp = GetSeasonStartTimestamp(startsYMD)
    if startTimestamp and now < startTimestamp then
        return "starts"
    end

    local endTimestamp = endsYMD and GetSeasonEndTimestampForDisplay(endsYMD) or nil
    local postEndTimestamp = postEndsYMD and GetPostSeasonEndTimestamp(postEndsYMD) or nil

    if endTimestamp then
        if now < endTimestamp then
            return "ends"
        end
        if postEndTimestamp and now < postEndTimestamp then
            return "ends"
        end
        return false
    end

    if postEndTimestamp then
        if now < postEndTimestamp then
            return "ends"
        end
        return false
    end

    if obtainable == "starts" or obtainable == "ends" then
        return true
    end

    return obtainable
end

-- Teleport Data Structure
local TeleportCategories = {
    { text = "TWW Season 3", value = "TWW_S3" },
    { text = "Midnight Season 1", value = "MID_S1" },
    --{ text = "Midnight Season 2", value = "MID_S2" },
    { separator = true },
    { text = "Midnight", value = "Midnight" },
    { text = "The War Within", value = "The War Within" },
    { text = "Dragonflight", value = "Dragonflight" },
    { text = "Shadowlands", value = "Shadowlands" },
    { text = "Battle for Azeroth", value = "Battle for Azeroth" },
    { text = "Legion", value = "Legion" },
    { text = "Warlords of Draenor", value = "Warlords of Draenor" },
    { text = "Mists of Pandaria", value = "Mists of Pandaria" },
    { text = "Cataclysm", value = "Cataclysm" },
    { text = "Wrath of the Lich King", value = "Wrath of the Lich King" }
}

local TeleportData = {
    ["TWW_S3"] = {  -- The War Within Season 3 - Ended code will disable tab automatically.
        obtainable = "ends",
        ends = 20260121,
        postEnds = 20260303,
        ids = { 2660, 2662, 2649, 2773, 2830, 2287, 2441, 2810, },
    },
    ["MID_S1"] = {
        obtainable = "starts",
        starts = 20260325,
        --ends = 20260723, most likely July 2026 (date is speculative)
        --postEnds = 20260806, most likely August 2026 (date is speculative)
        ids = { 658, 1209, 1753, 2526, 2805, 2811, 2874, 2915, },
    },
    ["MID_S2"] = {
        obtainable = false,
        --starts = 20260806, (date is speculative)
        --ends = UNKNOWN,
        --postEnds = UNKNOWN,
        ids = { 2813, 2825, 2859, 2923, },
    },

    ["Midnight"] = {
        { id = 2805, name = "Windrunner Spire", texture = 7464939, spellID = 1254400, location = "Eversong Woods", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2811, name = "Magisters' Terrace", texture = 7467176, spellID = 1254572, location = "Eversong Woods", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2874, name = "Maisara Caverns", texture = 7478532, spellID = 1254559, location = "Zul'Aman", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2915, name = "Nexus-Point Xenas", texture = 7570499, spellID = 1254563, location = "Voidstorm", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2813, name = "Murder Row", texture = 7467177, spellID = 0, location = "Eversong Woods", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." }, --Not Added Yet
        { id = 2825, name = "Den of Nalorakk", texture = 7478533, spellID = 0, location = "Zul'Aman", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." }, --Not Added Yet
        { id = 2859, name = "The Blinding Vale", texture = 7478531, spellID = 0, location = "Harandar", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." }, --Not Added Yet
        { id = 2923, name = "Voidscar Arena", texture = 7479111, spellID = 0, location = "Voidstorm", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." }, --Not Added Yet
        --{ id = 2912, name = "The Voidspire", texture = 7507134, spellID = 0, location = "	Voidstorm", source = "Unknown" }, --Unconfirmed
        --{ id = 2939, name = "The Dreamrift", texture = 7570500, spellID = 0, location = "Harandar", source = "Unknown" }, --Unconfirmed
        --{ id = 2913, name = "March on Quel'Danas", texture = 7480125, spellID = 0, location = "Eversong Woods", source = "Unknown" }, --Unconfirmed
    },
    ["The War Within"] = {
        { id = 2660, name = "Ara-Kara, City of Echoes", texture = 5912537, spellID = 445417, location = "Azj-Kahet", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2661, name = "Cinderbrew Meadery", texture = 5912538, spellID = 445440, location = "Isle of Dorn", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2669, name = "City of Threads", texture = 5912539, spellID = 445416, location = "Azj-Kahet", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2651, name = "Darkflame Cleft", texture = 5912540, spellID = 445441, location = "Ringing Deeps", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2649, name = "Priory of the Sacred Flame", texture = 5912542, spellID = 445444, location = "Hallowfall", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2662, name = "The Dawnbreaker", texture = 5912543, spellID = 445414, location = "Hallowfall", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2648, name = "The Rookery", texture = 5912544, spellID = 445443, location = "Isle of Dorn", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2652, name = "The Stonevault", texture = 5912545, spellID = 445269, location = "Ringing Deeps", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2773, name = "Operation: Floodgate", texture = 6422410, spellID = 1216786, location = "Ringing Deeps", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2830, name = "Eco-Dome Al'dani", texture = 7074041, spellID = 1237215, location = "K'aresh", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2769, name = "Liberation of Undermine", texture = 6422409, spellID = 1226482, location = "Undermine", source = "Reach Renown 20 with Gallagio Loyalty Rewards Club.", obtainable = true },
        { id = 2810, name = "Manaforge Omega", texture = 7049313, spellID = 1239155, location = "K'aresh", source = "Reach Renown 15 with Manaforge Vandals.", obtainable = true },
    },
    ["Dragonflight"] = {
        { id = 2526, name = "Algeth'ar Academy", texture = 4742939, spellID = 393273, location = "Thaldraszus", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2520, name = "Brackenhide Hollow", texture = 4742933, spellID = 393267, location = "Azure Span", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2527, name = "Halls of Infusion", texture = 4742936, spellID = 393283, location = "Thaldraszus", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2519, name = "Neltharus", texture = 4742938, spellID = 393276, location = "Waking Shores", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2521, name = "Ruby Life Pools", texture = 4742937, spellID = 393256, location = "Waking Shores", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2515, name = "The Azure Vault", texture = 4742932, spellID = 393279, location = "Azure Span", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2516, name = "The Nokhud Offensive", texture = 4742934, spellID = 393262, location = "Ohn'ahran Plains", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2451, name = "Uldaman: Legacy of Tyr", texture = 4742940, spellID = 393222, location = "Badlands", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2522, name = "Vault of the Incarnates", texture = 4742941, spellID = 432254, location = "Thaldraszus", source = "Complete Achievement Mythic: Awakening the Dragonflight Raids" },
        { id = 2569, name = "Aberrus, the Shadowed Crucible", texture = 5149417, spellID = 432257, location = "Zaralek Cavern", source = "Complete Achievement Mythic: Awakening the Dragonflight Raids" },
        { id = 2549, name = "Amirdrassil, the Dream's Hope", texture = 5409262, spellID = 432258, location = "Emerald Dream", source = "Complete Achievement Mythic: Awakening the Dragonflight Raids" },
    },
    ["Shadowlands"] = {
        { id = 2286, name = "The Necrotic Wake", texture = 3759920, spellID = 354462, location = "Bastion", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2289, name = "Plaguefall", texture = 3759921, spellID = 354463, location = "Maldraxxus", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2290, name = "Mists of Tirna Scithe", texture = 3759919, spellID = 354464, location = "Ardenweald", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2287, name = "Halls of Atonement", texture = 3759918, spellID = 354465, location = "Revendreth", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2293, name = "Theater of Pain", texture = 3759924, spellID = 354467, location = "Maldraxxus", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2291, name = "De Other Side", texture = 3759925, spellID = 354468, location = "Ardenweald", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2285, name = "Spires of Ascension", texture = 3759923, spellID = 354466, location = "Bastion", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2284, name = "Sanguine Depths", texture = 3759922, spellID = 354469, location = "Revendreth", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2441, name = "Tazavesh, the Veiled Market", texture = 4182024, spellID = 367416, location = "Tazavesh", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2296, name = "Castle Nathria", texture = 3759916, spellID = 373190, location = "Revendreth", source = "Complete Achievement Mythic: Fates of the Shadowlands Raids" },
        { id = 2450, name = "Sanctum of Domination", texture = 4182023, spellID = 373191, location = "The Maw", source = "Complete Achievement Mythic: Fates of the Shadowlands Raids" },
        { id = 2481, name = "Sepulcher of the First Ones", texture = 4425895, spellID = 373192, location = "Zereth Mortis", source = "Complete Achievement Mythic: Fates of the Shadowlands Raids" },
    },
    ["Battle for Azeroth"] = {
        { id = 1763, name = "Atal'Dazar", texture = 1778890, spellID = 424187, location = "Zuldazar", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1754, name = "Freehold", texture = 1778891, spellID = 410071, location = "Tiragarde Sound", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1822, name = "Siege of Boralus", texture = 2177726, spellIDHorde = 464256, spellIDAlly = 445418, location = "Tiragarde Sound", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 1594, name = "The Motherlode!!", texture = 2177728, spellIDHorde = 467555, spellIDAlly = 467553, location = "Zuldazar", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 1841, name = "The Underrot", texture = 2177729, spellID = 410074, location = "Nazmir", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1862, name = "Waycrest Manor", texture = 2177732, spellID = 424167, location = "Drustvar", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2097, name = "Operation: Mechagon", texture = 3025327, spellID = 373274, location = "Mechagon Island", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
    },
    ["Legion"] = {
        { id = 1501, name = "Black Rook Hold", texture = 1411847, spellID = 424153, location = "Val'sharah", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1571, name = "Court of Stars", texture = 1498152, spellID = 393766, location = "Suramar", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1466, name = "Darkheart Thicket", texture = 1411849, spellID = 424163, location = "Val'sharah", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1477, name = "Halls of Valor", texture = 1498154, spellID = 393764, location = "Stormheim", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1458, name = "Neltharion's Lair", texture = 1450572, spellID = 410078, location = "Highmountain", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1651, name = "Return to Karazhan", texture = 1537281, spellID = 373262, location = "Deadwind Pass", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1753, name = "Seat of the Triumvirate", texture = 1718205, spellIDHorde= 1254550, spellIDAlly= 1254552, location="Mac'Aree / Eredar", source="Complete Mythic Keystone on Level 10 or higher within the time limit." },
    },
    ["Warlords of Draenor"] = {
        { id = 1175, name = "Bloodmaul Slag Mines", texture = 1041984, spellID = 159895, location = "Frostfire Ridge", source = "Challenge Mode: Gold (Legacy)" },
        { id = 1208, name = "Grimrail Depot", texture = 1041986, spellID = 159900, location = "Gorgrond", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1195, name = "Iron Docks", texture = 1060546, spellID = 159896, location = "Gorgrond", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1182, name = "Auchindoun", texture = 1041982, spellID = 159897, location = "Talador", source = "Challenge Mode: Gold (Legacy)" },
        { id = 1279, name = "The Everbloom", texture = 1060545, spellID = 159901, location = "Gorgrond", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1176, name = "Shadowmoon Burial Grounds", texture = 1041988, spellID = 159899, location = "Shadowmoon Valley", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1358, name = "Upper Blackrock Spire", texture = 1041990, spellID = 159902, location = "Blackrock Mountain", source = "Challenge Mode: Gold (Legacy)"},
        { id = 1209, name = "Skyreach", texture = 1041989, spellID = 159898, location = "Spires of Arak", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 10 or higher within the time limit." },
    },
    ["Mists of Pandaria"] = {
        { id = 960, name = "Temple of the Jade Serpent", texture = 632283, spellID = 131204, location = "Jade Forest", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 961, name = "Stormstout Brewery", texture = 632282, spellID = 131205, location = "Valley of the Four Winds", source = "Challenge Mode: Gold (Legacy)" },
        { id = 959, name = "Shado-Pan Monastery", texture = 632281, spellID = 131206, location = "Kun-Lai Summit", source = "Challenge Mode: Gold (Legacy)" },
        { id = 994, name = "Mogu'shan Palace", texture = 632279, spellID = 131222, location = "Vale of Eternal Blossoms", source = "Challenge Mode: Gold (Legacy)" },
        { id = 962, name = "Gate of the Setting Sun", texture = 632277, spellID = 131225, location = "Vale of Eternal Blossoms", source = "Challenge Mode: Gold (Legacy)" },
        { id = 1011, name = "Siege of Niuzao Temple", texture = 643266, spellID = 131228, location = "Townlong Steppes", source = "Challenge Mode: Gold (Legacy)" },
        { id = 1001, name = "Scarlet Halls", texture = 643265, spellID = 131231, location = "Tirisfal Glades", source = "Challenge Mode: Gold (Legacy)" },
        { id = 1004, name = "Scarlet Monastery", texture = 608253, spellID = 131229, location = "Tirisfal Glades", source = "Challenge Mode: Gold (Legacy)" },
        { id = 1007, name = "Scholomance", texture = 608254, spellID = 131232, location = "Western Plaguelands", source = "Challenge Mode: Gold (Legacy)" },
    },
    ["Cataclysm"] = {
        { id = 657, name = "Vortex Pinnacle", texture = 526414, spellID = 410080, location = "Uldum", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 643, name = "Throne of the Tides", texture = 526413, spellID = 424142, location = "Vashj'ir", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 670, name = "Grim Batol", texture = 526406, spellID = 445424, location = "Twilight Highlands", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
    },
    ["Wrath of the Lich King"] = {
        { id = 658, name = "Pit of Saron", texture = 608249, spellID = 1254555, location = "Icecrown", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
    }
}

local function IsFullTeleportDefinition(entry)
    if type(entry) ~= "table" then
        return false
    end

    return entry.name ~= nil
        or entry.texture ~= nil
        or entry.spellID ~= nil
        or entry.spellIDHorde ~= nil
        or entry.spellIDAlly ~= nil
end

local function IsSeasonCategory(categoryValue)
    if type(categoryValue) ~= "string" then
        return false
    end
    return categoryValue:match("_S%d+$") ~= nil
end

local function FindTeleportDefinitionByIdInCategory(categoryValue, teleportID)
    local categoryData = TeleportData[categoryValue]
    if type(categoryData) ~= "table" then
        return nil
    end

    local entries = categoryData.ids or categoryData
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.id == teleportID and IsFullTeleportDefinition(entry) then
            return entry
        end
    end

    return nil
end

local function GetCategoryEntriesAndMeta(categoryValue)
    local categoryData = TeleportData[categoryValue]
    if type(categoryData) ~= "table" then
        return nil, nil
    end

    if type(categoryData.ids) == "table" then
        return categoryData.ids, {
            obtainable = categoryData.obtainable,
            starts = categoryData.starts,
            ends = categoryData.ends,
            postEnds = categoryData.postEnds,
        }
    end

    return categoryData, nil
end

local function ShallowCopyTable(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function GetTeleportIdFromEntry(entry)
    if type(entry) == "number" then
        return entry
    end
    if type(entry) == "table" then
        return entry.id
    end
    return nil
end

local function MergeTeleportEntry(baseEntry, overrideEntry)
    local merged = ShallowCopyTable(baseEntry)
    if type(overrideEntry) ~= "table" then
        return merged
    end

    for key, value in pairs(overrideEntry) do
        if key ~= "refCategory" then
            merged[key] = value
        end
    end
    return merged
end

local function ApplySeasonMeta(entry, seasonMeta)
    if type(entry) ~= "table" or type(seasonMeta) ~= "table" then
        return entry
    end

    local merged = ShallowCopyTable(entry)

    -- manual obtainable flag on TeleportData always prior
    if merged.obtainable ~= nil then
        return merged
    end

    if seasonMeta.obtainable ~= nil then
        merged.obtainable = seasonMeta.obtainable
        merged.starts = seasonMeta.starts
        merged.ends = seasonMeta.ends
        merged.postEnds = seasonMeta.postEnds
    end

    return merged
end

local function GetSeasonMetaForTeleportId(teleportID)
    if not teleportID then
        return nil
    end

    for _, category in ipairs(TeleportCategories) do
        if category.value and not category.separator and IsSeasonCategory(category.value) then
            local ids, meta = GetCategoryEntriesAndMeta(category.value)
            if type(ids) == "table" and type(meta) == "table" and meta.obtainable ~= nil then
                for _, seasonEntry in ipairs(ids) do
                    local seasonId = GetTeleportIdFromEntry(seasonEntry)
                    if seasonId == teleportID then
                        return meta
                    end
                end
            end
        end
    end

    return nil
end

local function FindTeleportDefinitionById(teleportID, preferredCategory)
    if preferredCategory then
        local preferred = FindTeleportDefinitionByIdInCategory(preferredCategory, teleportID)
        if preferred then
            return preferred
        end
    end

    for _, category in ipairs(TeleportCategories) do
        if category.value and not category.separator and not IsSeasonCategory(category.value) and category.value ~= preferredCategory then
            local entry = FindTeleportDefinitionByIdInCategory(category.value, teleportID)
            if entry then
                return entry
            end
        end
    end

    return nil
end

local function ResolveTeleportEntry(categoryValue, entry, seasonMeta)
    local entryType = type(entry)
    if entryType ~= "number" and entryType ~= "table" then
        return nil
    end

    local resolved
    local teleportID = GetTeleportIdFromEntry(entry)

    if entryType == "number" then
        resolved = FindTeleportDefinitionById(entry)
    elseif IsFullTeleportDefinition(entry) then
        resolved = ShallowCopyTable(entry)
    else
        local refId = entry.id
        local refCategory = entry.refCategory or categoryValue
        if not refId or not refCategory then
            return nil
        end

        local sourceEntry = FindTeleportDefinitionById(refId, refCategory)
        if not sourceEntry then
            return nil
        end

        resolved = MergeTeleportEntry(sourceEntry, entry)
    end

    if not resolved then
        return nil
    end

    local effectiveSeasonMeta = seasonMeta
    if effectiveSeasonMeta == nil then
        effectiveSeasonMeta = GetSeasonMetaForTeleportId(teleportID or resolved.id)
    end

    return ApplySeasonMeta(resolved, effectiveSeasonMeta)
end

local function InitDungeonTeleportsTab()
    if _G["PVEFrameTab4"] then return end
    if not PVEFrame or not PVEFrameTab3 then return end

    local pendingCategoryValue
    local pendingCategoryText
    local pendingHideAfterCombat = false
    local selectedCategoryValue = "TWW_S3"
    local selectedCategoryText = "TWW Season 3"
    local availableCategories = {}
    local dropdown
    local InitializeDropdown

    local function GetCategoryTextByValue(value, categories, useDynamicText)
        local source = categories or availableCategories
        for _, cat in ipairs(source) do
            if cat.value == value then
                if useDynamicText and cat.dynamicText then
                    return cat.dynamicText
                end
                return cat.text
            end
        end
        return tostring(value or "")
    end

    local function GetSeasonCategoryBaseName(cat)
        local text = tostring(cat and cat.text or "")
        text = text:gsub("%s+[Pp]ost%-?[Ss]eason%s+%d+.*$", "")
        text = text:gsub("%s+[Ss]eason%s+%d+.*$", "")
        text = text:match("^%s*(.-)%s*$")
        if text and text ~= "" then
            return text
        end

        local value = tostring(cat and cat.value or "")
        local fallback = value:match("^(.-)_S%d+$")
        if fallback and fallback ~= "" then
            return fallback
        end
        return value
    end

    local function BuildSeasonCategoryState(cat)
        if not cat or not cat.value or not IsSeasonCategory(cat.value) then
            return true, cat and cat.text
        end

        local seasonNumber = tostring(cat.value):match("_S(%d+)$") or "?"
        local seasonName = GetSeasonCategoryBaseName(cat)
        local _, seasonMeta = GetCategoryEntriesAndMeta(cat.value)
        if type(seasonMeta) ~= "table" then
            return true, string.format("%s Season %s", seasonName, seasonNumber)
        end

        local now = GetServerTime()
        local state = ResolveObtainableState(seasonMeta.obtainable, seasonMeta.starts, seasonMeta.ends, seasonMeta.postEnds)

        if state == "starts" then
            local startsText = "Start date unavailable"
            if seasonMeta.starts then
                local startTimestamp = GetSeasonStartTimestamp(seasonMeta.starts)
                if startTimestamp then
                    local remaining = startTimestamp - now
                    if remaining > 0 then
                        startsText = "Starts in " .. FormatRemainingDuration(remaining)
                    else
                        startsText = "Started"
                    end
                end
            end

            return true, string.format("%s Season %s - %s", seasonName, seasonNumber, startsText)
        end

        if state == "ends" then
            local endTimestamp = seasonMeta.ends and GetSeasonEndTimestampForDisplay(seasonMeta.ends) or nil
            local postEndTimestamp = seasonMeta.postEnds and GetPostSeasonEndTimestamp(seasonMeta.postEnds) or nil

            if endTimestamp and endTimestamp > now then
                return true, string.format("%s Season %s - Ends in %s", seasonName, seasonNumber, FormatRemainingDuration(endTimestamp - now))
            end

            if postEndTimestamp and postEndTimestamp > now then
                return true, string.format("%s Post-Season %s - Ends in %s", seasonName, seasonNumber, FormatRemainingDuration(postEndTimestamp - now))
            end

            return false, nil
        end

        if state == false then
            return false, nil
        end

        return true, string.format("%s Season %s", seasonName, seasonNumber)
    end

    local function BuildVisibleCategories()
        local result = {}

        for _, cat in ipairs(TeleportCategories) do
            if cat.separator then
                table.insert(result, { separator = true })
            else
                local isVisible, dynamicText = BuildSeasonCategoryState(cat)
                if isVisible then
                    table.insert(result, { text = cat.text, dynamicText = dynamicText or cat.text, value = cat.value })
                end
            end
        end

        local cleaned = {}
        local previousWasSeparator = true
        for _, cat in ipairs(result) do
            if cat.separator then
                if not previousWasSeparator then
                    table.insert(cleaned, cat)
                    previousWasSeparator = true
                end
            else
                table.insert(cleaned, cat)
                previousWasSeparator = false
            end
        end

        if #cleaned > 0 and cleaned[#cleaned].separator then
            table.remove(cleaned, #cleaned)
        end

        return cleaned
    end

    local function GetFirstSelectableCategory(categories)
        for _, cat in ipairs(categories or {}) do
            if not cat.separator and cat.value then
                return cat.value
            end
        end
        return nil
    end

    local function IsCategoryAvailable(value, categories)
        for _, cat in ipairs(categories or {}) do
            if not cat.separator and cat.value == value then
                return true
            end
        end
        return false
    end

    local function RefreshCategoryOptions(preferredValue)
        local rebuilt = BuildVisibleCategories()
        availableCategories = rebuilt

        if preferredValue and IsCategoryAvailable(preferredValue, availableCategories) then
            selectedCategoryValue = preferredValue
        elseif not IsCategoryAvailable(selectedCategoryValue, availableCategories) then
            selectedCategoryValue = GetFirstSelectableCategory(availableCategories) or selectedCategoryValue
        end
        selectedCategoryText = GetCategoryTextByValue(selectedCategoryValue, availableCategories, true)

        if dropdown then
            if dropdown.SetList then
                dropdown:SetList(availableCategories)
                dropdown:SetValue(selectedCategoryValue)
            elseif UIDropDownMenu_Initialize and InitializeDropdown then
                UIDropDownMenu_Initialize(dropdown, InitializeDropdown)
                UIDropDownMenu_SetText(dropdown, GetCategoryTextByValue(selectedCategoryValue, availableCategories, false))
            end
        end
    end

    -- Create the new tab
    local tab = CreateFrame("Button", "PVEFrameTab4", PVEFrame, "PanelTabButtonTemplate")
    tab:SetID(4)
    tab:SetText("Dungeon Teleports")
    if PanelTemplates_TabResize then
        PanelTemplates_TabResize(tab, 0)
    end
    tab:SetPoint("LEFT", PVEFrameTab3, "RIGHT", 6, 0)
    tab:Show()
    if PanelTemplates_DeselectTab then
        PanelTemplates_DeselectTab(tab)
    end
    
    -- Create the content frame
    local contentFrame = CreateFrame("Frame", "DungeonTeleportsFrame", PVEFrame)
    contentFrame:SetAllPoints(PVEFrame)
    contentFrame:Hide()

    -- Title
    local title = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 70, -35)
    title:SetText("TWW Season 3")

    -- Background Inset
    local inset = CreateFrame("Frame", "$parentInset", contentFrame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", inset)
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(inset:GetWidth()-30, 500)
    scrollFrame:SetScrollChild(scrollChild)
    contentFrame.scrollChild = scrollChild
    contentFrame.buttons = {}
    contentFrame.cooldownRefreshPending = false
    
    -- Custom Scrollbar (from mQoL Addon Styles)
    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        mQoL_Styles.CreateCustomScrollbar(scrollFrame, scrollChild)
    end

    local function OnButtonEnter(self)
        self.border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        
        if self.teleportName then
            GameTooltip:AddLine(self.teleportName, 1, 1, 1)
        end
        if self.teleportLocation then
            GameTooltip:AddLine(self.teleportLocation, 0.7, 0.7, 0.7)
        end

        if not self.isKnown then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("How to obtain:", 1, 0.82, 0)
            local tooltipObtainable = ResolveObtainableState(self.teleportObtainable, self.teleportStarts, self.teleportEnds, self.teleportPostEnds)

            if tooltipObtainable == false then
                GameTooltip:AddLine("NOT CURRENTLY OBTAINABLE", 1, 0, 0)
            elseif tooltipObtainable == "starts" then
                local startTimestamp = GetSeasonStartTimestamp(self.teleportStarts)
                if startTimestamp then
                    local remaining = startTimestamp - GetServerTime()
                    if remaining > 0 then
                        GameTooltip:AddLine("Season starts in " .. FormatRemainingDuration(remaining), 1, 1, 0)
                    else
                        GameTooltip:AddLine("Season Started", 0, 1, 0)
                    end
                else
                    GameTooltip:AddLine("Season start date unavailable", 1, 0.5, 0.25)
                end
            elseif tooltipObtainable == "ends" then
                local text = "Season ends in"
                local endTimestamp = self.teleportEnds and GetSeasonEndTimestampForDisplay(self.teleportEnds) or nil
                local postEndTimestamp = self.teleportPostEnds and GetPostSeasonEndTimestamp(self.teleportPostEnds) or nil
                local currentTime = GetServerTime()
                local remaining = endTimestamp and (endTimestamp - currentTime) or nil
                if remaining and remaining > 0 then
                    text = text .. " " .. FormatRemainingDuration(remaining)
                else
                    local postRemaining = postEndTimestamp and (postEndTimestamp - currentTime) or nil
                    if postRemaining and postRemaining > 0 then
                        text = "Post-season ends in " .. FormatRemainingDuration(postRemaining)
                    else
                        text = "NOT CURRENTLY OBTAINABLE"
                    end
                end
                GameTooltip:AddLine(text, 1, 0, 0)
            end

            if self.teleportSource then
                GameTooltip:AddLine(self.teleportSource, 1, 1, 1, true)
            else
                GameTooltip:AddLine("Complete this dungeon on Mythic Keystone Level 10+ within the time limit.", 1, 1, 1, true)
            end
        end

        GameTooltip:Show()
    end

    local function OnButtonLeave(self)
        self.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        GameTooltip:Hide()
    end

    local function RefreshVisibleButtonCooldowns()
        if not contentFrame:IsShown() then
            return
        end
        for _, btn in pairs(contentFrame.buttons) do
            if btn:IsShown() then
                RefreshButtonCooldown(btn)
            end
        end
    end

    local function QueueCooldownRefresh()
        if contentFrame.cooldownRefreshPending then
            return
        end

        contentFrame.cooldownRefreshPending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                contentFrame.cooldownRefreshPending = false
                RefreshVisibleButtonCooldowns()
            end)
        else
            contentFrame.cooldownRefreshPending = false
            RefreshVisibleButtonCooldowns()
        end
    end

    -- Functions
    local function UpdateTeleportList(categoryValue)
        if IsInCombat() then
            return false
        end

        -- Clear existing buttons
        for _, btn in pairs(contentFrame.buttons) do
            btn:Hide()
        end
        
        local data, seasonMeta = GetCategoryEntriesAndMeta(categoryValue)
        if not data then return true end

        local resolvedData = {}
        for _, entry in ipairs(data) do
            local resolvedEntry = ResolveTeleportEntry(categoryValue, entry, seasonMeta)
            if resolvedEntry then
                table.insert(resolvedData, resolvedEntry)
            end
        end
        
        -- Card Style Layout
        local availableWidth = scrollChild:GetWidth() or 520
        local cols = 3
        local marginX = 10
        local marginY = 10
        local startX = 10
        local startY = -10

        local btnWidth = (availableWidth - (cols - 1) * marginX - 2 * startX) / cols
        local btnHeight = 95 
        
        for i, info in ipairs(resolvedData) do
            if not contentFrame.buttons[i] then
                local btn = CreateFrame("Button", nil, scrollChild, "SecureActionButtonTemplate")
                btn:SetSize(btnWidth, btnHeight)
                ConfigureTeleportButtonClicks(btn)
                
                -- Card Background
                btn.bg = btn:CreateTexture(nil, "BACKGROUND")
                btn.bg:SetAllPoints()
                btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
                
                -- Border
                btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
                btn.border:SetAllPoints()
                btn.border:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                btn.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

                -- Image Section
                btn.imageContainer = btn:CreateTexture(nil, "BACKGROUND")
                btn.imageContainer:SetPoint("TOPLEFT", 0, 0)
                btn.imageContainer:SetPoint("TOPRIGHT", 0, 0)
                btn.imageContainer:SetHeight(btnHeight * 0.6)
                btn.imageContainer:SetColorTexture(0.05, 0.05, 0.05, 1)
                
                btn.imageArea = btn:CreateTexture(nil, "ARTWORK")
                btn.imageArea:SetPoint("CENTER", btn.imageContainer, "CENTER")
                btn.imageArea:SetSize(btnHeight * 0.6, btnHeight * 0.6)
                btn.imageArea:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                
                -- Info Section (Instance Name and Location)
                btn.infoBg = btn:CreateTexture(nil, "ARTWORK")
                btn.infoBg:SetPoint("TOPLEFT", 0, -(btnHeight * 0.6))
                btn.infoBg:SetPoint("BOTTOMRIGHT", 0, 0)
                btn.infoBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

                -- Name
                btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                btn.nameText:SetPoint("TOPLEFT", btn.infoBg, "TOPLEFT", 5, -5)
                btn.nameText:SetPoint("TOPRIGHT", btn.infoBg, "TOPRIGHT", -5, -5)
                btn.nameText:SetJustifyH("LEFT")
                btn.nameText:SetJustifyV("TOP")
                btn.nameText:SetWordWrap(false)
                btn.nameText:SetMaxLines(1)

                -- Location
                btn.locText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.locText:SetPoint("BOTTOMLEFT", btn.infoBg, "BOTTOMLEFT", 5, 5)
                btn.locText:SetPoint("BOTTOMRIGHT", btn.infoBg, "BOTTOMRIGHT", -5, 5)
                btn.locText:SetJustifyH("LEFT")
                btn.locText:SetTextColor(0.7, 0.7, 0.7)
                btn.locText:SetMaxLines(1)

                -- Hover Effect
                btn:SetScript("OnEnter", OnButtonEnter)
                btn:SetScript("OnLeave", OnButtonLeave)
                  
                contentFrame.buttons[i] = btn
            end
            
            local btn = contentFrame.buttons[i]

            -- Ensure cooldown frame exists
            if not btn.cooldown then
                btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                btn.cooldown:SetAllPoints(btn)
                btn.cooldown:SetDrawEdge(false)
                if btn.cooldown.SetDrawBling then
                    btn.cooldown:SetDrawBling(false)
                end
                if btn.cooldown.EnableMouse then
                    btn.cooldown:EnableMouse(false)
                end
                btn.cooldown:SetHideCountdownNumbers(false)
                
                for _, region in ipairs({btn.cooldown:GetRegions()}) do
                    if region:GetObjectType() == "FontString" then
                        region:SetTextColor(1, 0.82, 0)
                    end
                end
            end
            
            -- Update Size
            btn:SetSize(btnWidth, btnHeight)
            btn.imageContainer:SetHeight(btnHeight * 0.6)
            btn.infoBg:SetPoint("TOPLEFT", 0, -(btnHeight * 0.6))

            -- Grid Position
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", startX + (col * (btnWidth + marginX)), startY - (row * (btnHeight + marginY)))
            btn:Show()
            
            btn.nameText:SetText(info.name)
            btn.locText:SetText(info.location or "Unknown Location")

            btn.teleportName = info.name
            btn.teleportLocation = info.location
            btn.teleportSource = info.source
            local effectiveObtainable = info.obtainable
            if effectiveObtainable == nil then
                effectiveObtainable = false
            end
            effectiveObtainable = ResolveObtainableState(effectiveObtainable, info.starts, info.ends, info.postEnds)
            btn.teleportObtainable = effectiveObtainable
            btn.teleportStarts = info.starts
            btn.teleportEnds = info.ends
            btn.teleportPostEnds = info.postEnds

            -- Setup click and visual state
            local isKnown = false
            local spellToUse = nil
            
            -- Determine player faction for faction specific spell ID selection (if applicable)
            local faction = UnitFactionGroup("player")
            
            -- Determine which spell ID to use based on faction (for few dungeons that have different IDs for Horde/Ally due to faction specific entrance)
            if info.spellIDHorde and info.spellIDAlly then
                if faction == "Horde" then
                    spellToUse = info.spellIDHorde
                else
                    spellToUse = info.spellIDAlly
                end
            else
                spellToUse = info.spellID
            end
            
            isKnown = IsTeleportSpellKnown(spellToUse)

            if isKnown then
                btn:Enable()
                btn:SetAlpha(1)
                btn.imageArea:SetDesaturated(false)
                btn.nameText:SetTextColor(1, 0.82, 0)
                if not SetTeleportButtonSpellAction(btn, spellToUse) then
                    -- Keep enabled for tooltip, but visual disable
                    btn:SetAlpha(0.5)
                    btn.imageArea:SetDesaturated(true)
                    btn.nameText:SetTextColor(0.5, 0.5, 0.5)
                end
            else -- Not known, visual disable only
                btn:Enable() 
                btn:SetAlpha(0.5) -- Grayed out
                btn.imageArea:SetDesaturated(true)
                btn.nameText:SetTextColor(0.5, 0.5, 0.5)
                ClearTeleportButtonAction(btn)
            end
            
            -- Store current spell ID for tooltip
            btn.currentSpellID = spellToUse
            btn.isKnown = isKnown

            -- Update Cooldown immediately
            if contentFrame:IsShown() then
                RefreshButtonCooldown(btn)
            else
                btn.cooldown:Hide()
            end
            
            -- Set Texture using texture FileID
            if info.texture and info.texture > 0 then
                btn.imageArea:ClearAllPoints()
                btn.imageArea:SetAllPoints(btn.imageContainer)
                btn.imageArea:SetTexture(info.texture)
                btn.imageArea:SetTexCoord(0.08, 0.65, 0.14, 0.58)
            end
        end
    
        local totalRows = math.ceil(#resolvedData / cols)
        local totalHeight = math.abs(startY) + (totalRows * (btnHeight + marginY)) 
        scrollChild:SetHeight(totalHeight)
        if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar and scrollFrame.scrollbar and scrollFrame.scrollbar.UpdateScrollbar then
             scrollFrame.scrollbar.UpdateScrollbar()
        end

        return true
    end
    
    local function RequestCategoryUpdate(categoryValue, categoryText)
        RefreshCategoryOptions(categoryValue)
        selectedCategoryText = categoryText or GetCategoryTextByValue(selectedCategoryValue, availableCategories, true)

        if IsInCombat() then
            pendingCategoryValue = selectedCategoryValue
            pendingCategoryText = selectedCategoryText
            contentFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return false
        end

        if UpdateTeleportList(selectedCategoryValue) then
            title:SetText(selectedCategoryText)
        end

        pendingCategoryValue = nil
        pendingCategoryText = nil
        contentFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return true
    end

    -- Event Handler for cooldowns and deferred secure updates
    contentFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "SPELL_UPDATE_COOLDOWN" then
            QueueCooldownRefresh()
        elseif event == "SPELLS_CHANGED" then
            RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        elseif event == "CVAR_UPDATE" then
            local cvarName = tostring(arg1 or ""):gsub("_", ""):lower()
            if cvarName == "actionbuttonusekeydown" and not IsInCombat() then
                for _, btn in pairs(contentFrame.buttons) do
                    ConfigureTeleportButtonClicks(btn)
                end
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingCategoryValue then
                RequestCategoryUpdate(pendingCategoryValue, pendingCategoryText)
            else
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            end
        end
    end)
    contentFrame:SetScript("OnShow", function(self)
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("CVAR_UPDATE")
        RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        for _, btn in pairs(self.buttons) do
            if btn:IsShown() then
                ConfigureTeleportButtonClicks(btn)
                RefreshButtonCooldown(btn)
            end
        end
        QueueCooldownRefresh()
    end)
    contentFrame:SetScript("OnHide", function(self)
        self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        self:UnregisterEvent("SPELLS_CHANGED")
        self:UnregisterEvent("CVAR_UPDATE")
        self.cooldownRefreshPending = false
    end)

    -- Dropdown
    if mQoL_Styles and mQoL_Styles.CreateCustomDropdown then
        RefreshCategoryOptions()
        dropdown = mQoL_Styles.CreateCustomDropdown(contentFrame, 160, availableCategories, selectedCategoryValue, function(value)
            RequestCategoryUpdate(value)
        end)
        dropdown:HookScript("OnMouseDown", function()
            RefreshCategoryOptions(selectedCategoryValue)
        end)
        dropdown:SetPoint("TOPRIGHT", -5, -30)
    end

    local UpdateDungeonTeleportsTabTextColor
    local isDungeonTeleportsTabForceDisabled = false
    local isInternalTabSwitch = false

    local function HideDungeonTeleportsFrame()
        if IsInCombat() then
            pendingHideAfterCombat = true
            return false
        end

        pendingHideAfterCombat = false
        if contentFrame then
            contentFrame:Hide()
        end
        if PanelTemplates_DeselectTab then
            PanelTemplates_DeselectTab(tab)
        end
        if UpdateDungeonTeleportsTabTextColor then
            UpdateDungeonTeleportsTabTextColor()
        end
        return true
    end

    local function SwitchToMythicPlusTab()
        if not PVEFrame or not PVEFrame:IsShown() or isInternalTabSwitch then
            return
        end

        isInternalTabSwitch = true
        if PVEFrame_ShowFrame then
            PVEFrame_ShowFrame("ChallengesFrame")
        elseif PVEFrame_TabOnClick and PVEFrameTab3 then
            PVEFrame_TabOnClick(PVEFrameTab3)
        end
        isInternalTabSwitch = false
    end

    local function ShowDungeonTeleportsFrame()
        if IsInCombat() then
            return
        end

        if not PVEFrame:IsShown() then
            ShowUIPanel(PVEFrame)
        end

        if PanelTemplates_DeselectTab then
            if PVEFrameTab1 then PanelTemplates_DeselectTab(PVEFrameTab1) end
            if PVEFrameTab2 then PanelTemplates_DeselectTab(PVEFrameTab2) end
            if PVEFrameTab3 then PanelTemplates_DeselectTab(PVEFrameTab3) end
        end
        if PanelTemplates_SelectTab then
            PanelTemplates_SelectTab(tab)
        end

        if GroupFinderFrame then GroupFinderFrame:Hide() end
        if PVPUIFrame then PVPUIFrame:Hide() end
        if ChallengesFrame then ChallengesFrame:Hide() end

        if PVEFrame_HideLeftInset then
            PVEFrame_HideLeftInset()
        elseif PVEFrameLeftInset then
            PVEFrameLeftInset:Hide()
        end

        RefreshCategoryOptions()
        contentFrame:Show()
        RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        PVEFrame:SetTitle("Dungeon Teleports")
        if PVEFrame.SetPortraitToAsset then
            PVEFrame:SetPortraitToAsset("Interface\\Icons\\Spell_Arcane_TeleportDalaran")
        elseif PortraitFrame_SetPortraitToAsset then
            PortraitFrame_SetPortraitToAsset(PVEFrame, "Interface\\Icons\\Spell_Arcane_TeleportDalaran")
        end
        PVEFrame:SetWidth(PVE_FRAME_BASE_WIDTH or 563)
        if UpdateUIPanelPositions then
            UpdateUIPanelPositions(PVEFrame)
        end
        if UpdateDungeonTeleportsTabTextColor then
            UpdateDungeonTeleportsTabTextColor()
        end
    end

    UpdateDungeonTeleportsTabTextColor = function()
        local text = tab.Text or _G[tab:GetName() .. "Text"]
        if not text then
            return
        end

        if isDungeonTeleportsTabForceDisabled then
            text:SetTextColor(0.5, 0.5, 0.5)
            return
        end

        local selectedTabID = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(PVEFrame) or nil
        local isActive = selectedTabID == tab:GetID() or (contentFrame and contentFrame:IsShown())
        local isHovered = tab:IsMouseOver()

        if isActive or isHovered then
            text:SetTextColor(1, 1, 1)
        else
            text:SetTextColor(1, 0.82, 0)
        end
    end

    local function SetDungeonTeleportsTabDisabled(isDisabled)
        isDungeonTeleportsTabForceDisabled = isDisabled and true or false
        tab:SetEnabled(not isDisabled)
        tab:SetAlpha(1)
        UpdateDungeonTeleportsTabTextColor()
    end

    local function UpdateDungeonTeleportsTabState()
        local inCombat = IsInCombat()
        if inCombat then
            if PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                pendingHideAfterCombat = true
                SwitchToMythicPlusTab()
            end
            if PanelTemplates_DisableTab then
                PanelTemplates_DisableTab(PVEFrame, 4)
            else
                tab:Disable()
            end
            if not contentFrame:IsShown() and PanelTemplates_DeselectTab then
                PanelTemplates_DeselectTab(tab)
            end
        else
            local selectedTabID = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(PVEFrame) or nil
            if contentFrame and contentFrame:IsShown() and selectedTabID ~= 4 then
                HideDungeonTeleportsFrame()
            end
            if pendingHideAfterCombat and PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                if HideDungeonTeleportsFrame() then
                    if PVEFrame_TabOnClick and PVEFrameTab3 then
                        PVEFrame_TabOnClick(PVEFrameTab3)
                    elseif PVEFrame_ShowFrame then
                        PVEFrame_ShowFrame("ChallengesFrame")
                    end
                end
            end
            if PanelTemplates_EnableTab then
                PanelTemplates_EnableTab(PVEFrame, 4)
            else
                tab:Enable()
            end
            if contentFrame:IsShown() and PanelTemplates_SelectTab then
                PanelTemplates_SelectTab(tab)
            elseif PanelTemplates_DeselectTab then
                PanelTemplates_DeselectTab(tab)
            end
        end

        SetDungeonTeleportsTabDisabled(inCombat)
        UpdateDungeonTeleportsTabTextColor()
    end

    tab:HookScript("OnEnter", UpdateDungeonTeleportsTabTextColor)
    tab:HookScript("OnLeave", UpdateDungeonTeleportsTabTextColor)

    tab:SetScript("OnClick", function()
        if IsInCombat() then
            return
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowDungeonTeleportsFrame()
    end)

    -- Initial Load
    RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)

    hooksecurefunc("PVEFrame_TabOnClick", function(clickedTab)
        if isInternalTabSwitch then
            return
        end
        UpdateDungeonTeleportsTabState()
    end)

    hooksecurefunc("PVEFrame_ShowFrame", function(sidePanelName)
        if isInternalTabSwitch then
            return
        end
        UpdateDungeonTeleportsTabState()
    end)

    PVEFrame:HookScript("OnHide", HideDungeonTeleportsFrame)
    PVEFrame:HookScript("OnShow", UpdateDungeonTeleportsTabState)

    local tabStateFrame = CreateFrame("Frame")
    tabStateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    tabStateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    tabStateFrame:SetScript("OnEvent", UpdateDungeonTeleportsTabState)
    UpdateDungeonTeleportsTabState()
end

local frame = CreateFrame("Frame")
local isInitialized = false

local function IsGroupFinderLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder")
end

local function TryInitialize(self)
    if isInitialized then
        return
    end
    if not IsGroupFinderLoaded() then
        return
    end
    if IsInCombat() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    InitDungeonTeleportsTab()
    isInitialized = true
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("ADDON_LOADED")
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "Blizzard_GroupFinder" then
            TryInitialize(self)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        TryInitialize(self)
    end
end)

TryInitialize(frame)
