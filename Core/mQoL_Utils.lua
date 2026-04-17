local addonName = ...

mQoL_Utils = mQoL_Utils or {}

local function TrimString(value)
    if type(value) ~= "string" then
        return nil
    end

    if strtrim then
        return strtrim(value)
    end

    return value:match("^%s*(.-)%s*$")
end

function mQoL_Utils.IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

function mQoL_Utils.IsAddonLoadedSafe(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addon)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(addon)
    end
    return false
end

function mQoL_Utils.GetRealmSlug(realmName)
    realmName = realmName or GetRealmName() or ""
    return tostring(realmName):gsub("%s+", "")
end

function mQoL_Utils.NormalizeFullName(name)
    name = TrimString(name)
    if not name or name == "" then
        return nil
    end

    local playerName, realmName = strsplit("-", name, 2)
    if not playerName or playerName == "" then
        return nil
    end

    realmName = mQoL_Utils.GetRealmSlug(realmName)
    if realmName == "" then
        return playerName
    end

    return playerName .. "-" .. realmName
end

function mQoL_Utils.GetUnitFullName(unit)
    if not unit or not UnitExists or not UnitExists(unit) then
        return nil
    end

    return mQoL_Utils.NormalizeFullName(GetUnitName(unit, true))
end

function mQoL_Utils.GetShortName(name)
    name = TrimString(name)
    if not name or name == "" then
        return nil
    end

    return name:match("^[^-]+") or name
end

function mQoL_Utils.GetDisplayName(fullName)
    if not fullName or fullName == "" then
        return UNKNOWN
    end

    if Ambiguate then
        return Ambiguate(fullName, "short")
    end

    return mQoL_Utils.GetShortName(fullName) or fullName
end

function mQoL_Utils.ShallowCopy(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

function mQoL_Utils.DeepCopy(source, seen)
    if type(source) ~= "table" then
        return source
    end

    seen = seen or {}
    if seen[source] then
        return seen[source]
    end

    local copy = {}
    seen[source] = copy

    for key, value in pairs(source) do
        copy[mQoL_Utils.DeepCopy(key, seen)] = mQoL_Utils.DeepCopy(value, seen)
    end

    return copy
end

function mQoL_Utils.GetNow()
    return time()
end

function mQoL_Utils.IsBootstrapWindow(session, now, interval, attempts, padding)
    local loginAt = session and session.loginAt or 0
    local windowSeconds = ((tonumber(interval) or 0) * (tonumber(attempts) or 0)) + (tonumber(padding) or 0)
    return loginAt > 0 and ((tonumber(now) or mQoL_Utils.GetNow()) - loginAt) <= windowSeconds
end

function mQoL_Utils.BuildGoldSnapshotData(warboundGold, characterGold)
    warboundGold = math.floor(tonumber(warboundGold) or 0)
    characterGold = math.floor(tonumber(characterGold) or 0)
    return {
        WarboundGold = warboundGold,
        CharacterGold = characterGold,
        OverallGold = warboundGold + characterGold,
    }
end

function mQoL_Utils.NormalizeGoldSnapshotData(rawValue)
    if type(rawValue) ~= "table" then
        return mQoL_Utils.BuildGoldSnapshotData(0, rawValue)
    end

    local warboundGold = math.floor(tonumber(rawValue.WarboundGold) or 0)
    local characterGold = math.floor(tonumber(rawValue.CharacterGold) or 0)
    local overallGold = tonumber(rawValue.OverallGold)

    if overallGold == nil then
        overallGold = tonumber(rawValue.total)
    end

    overallGold = math.floor(overallGold or (warboundGold + characterGold))

    if characterGold == 0 and warboundGold == 0 and rawValue.total ~= nil then
        characterGold = overallGold
    elseif overallGold ~= (warboundGold + characterGold) then
        if characterGold == 0 then
            characterGold = math.max(0, overallGold - warboundGold)
        else
            overallGold = warboundGold + characterGold
        end
    end

    local normalized = mQoL_Utils.BuildGoldSnapshotData(warboundGold, characterGold)
    normalized.OverallGold = overallGold
    normalized.total = overallGold
    return normalized
end

function mQoL_Utils.GetCurrentCharacterIdentity()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return mQoL_Utils.GetRealmSlug(realm) .. "-" .. name, name, realm
end

function mQoL_Utils.FormatLargeNumber(value)
    value = math.floor(tonumber(value) or 0)
    local sign = value < 0 and "-" or ""
    local number = tostring(math.abs(value))

    while true do
        local updated, count = number:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        number = updated
        if count == 0 then
            break
        end
    end

    return sign .. number
end

function mQoL_Utils.FormatMoneyCompact(copper)
    copper = math.floor(tonumber(copper) or 0)
    local sign = copper < 0 and "-" or ""
    copper = math.abs(copper)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRemainder = copper % 100

    if gold >= 1000000 then
        return string.format("%s%.1fm g", sign, gold / 1000000)
    end

    if gold >= 1000 then
        return string.format("%s%.1fk g", sign, gold / 1000)
    end

    if gold > 0 then
        return string.format("%s%s.%02dg", sign, mQoL_Utils.FormatLargeNumber(gold), silver)
    end

    if silver > 0 then
        return string.format("%s%ds %dc", sign, silver, copperRemainder)
    end

    return string.format("%s%dc", sign, copperRemainder)
end

function mQoL_Utils.TrimTrailingZeroes(text)
    text = tostring(text or "")
    text = text:gsub("(%..-)0+$", "%1")
    text = text:gsub("%.$", "")
    return text
end

function mQoL_Utils.GetAxisDecimals(stepValue)
    stepValue = math.abs(tonumber(stepValue) or 0)
    if stepValue >= 1 then
        return 0
    end
    if stepValue >= 0.1 then
        return 1
    end
    if stepValue >= 0.01 then
        return 2
    end
    return 3
end

function mQoL_Utils.FormatAxisMoney(copper, stepCopper)
    local gold = (tonumber(copper) or 0) / 10000
    local absGold = math.abs(gold)
    local stepGold = math.abs((tonumber(stepCopper) or 0) / 10000)

    if absGold >= 1000000 then
        local decimals = mQoL_Utils.GetAxisDecimals(stepGold / 1000000)
        return mQoL_Utils.TrimTrailingZeroes(string.format("%." .. decimals .. "f", gold / 1000000)) .. "m"
    end
    if absGold >= 1000 then
        local decimals = mQoL_Utils.GetAxisDecimals(stepGold / 1000)
        return mQoL_Utils.TrimTrailingZeroes(string.format("%." .. decimals .. "f", gold / 1000)) .. "k"
    end

    local decimals = mQoL_Utils.GetAxisDecimals(stepGold)
    return mQoL_Utils.TrimTrailingZeroes(string.format("%." .. decimals .. "f", gold)) .. "g"
end

function mQoL_Utils.FormatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds <= 0 then
        return "Unknown"
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    end
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", minutes)
end

function mQoL_Utils.FormatTimestamp(timestamp)
    if not timestamp or timestamp <= 0 then
        return "Unknown"
    end
    return date("%d %b %Y %H:%M", timestamp)
end

function mQoL_Utils.GetClassColor(classFile, fallbackColor)
    if classFile and CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile] then
        return CUSTOM_CLASS_COLORS[classFile]
    end

    if classFile and C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFile)
        if color then
            return color
        end
    end

    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        return RAID_CLASS_COLORS[classFile]
    end

    return fallbackColor or NORMAL_FONT_COLOR or { r = 1, g = 1, b = 1 }
end

function mQoL_Utils.GetClassColorRGB(classFile, fallbackR, fallbackG, fallbackB)
    local color = mQoL_Utils.GetClassColor(classFile)
    return color.r or fallbackR or 1, color.g or fallbackG or 1, color.b or fallbackB or 1
end

function mQoL_Utils.GetCommDistribution()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid() then
        return "RAID"
    end

    if IsInGroup() then
        return "PARTY"
    end

    return nil
end

function mQoL_Utils.GetSecondsUntilWeeklyReset()
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

function mQoL_Utils.GetSecondsUntilDailyReset()
    if _G.GetQuestResetTime then
        local seconds = _G.GetQuestResetTime()
        if seconds and seconds > 0 then
            return seconds
        end
    end
    return nil
end

function mQoL_Utils.ParseYMD(ymd)
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

    local daysInMonth = ({ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[month]
    local isLeapYear = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
    if month == 2 and isLeapYear then
        daysInMonth = 29
    end

    if day < 1 or day > daysInMonth then
        return nil
    end

    return year, month, day
end

function mQoL_Utils.YMDToEpochDays(year, month, day)
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

function mQoL_Utils.EpochDaysToYMD(daysSinceEpoch)
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

function mQoL_Utils.ShiftYMDByDays(ymd, days)
    local year, month, day = mQoL_Utils.ParseYMD(ymd)
    if not year then
        return ymd
    end

    if not days or days == 0 then
        return tonumber(string.format("%04d%02d%02d", year, month, day))
    end

    local shiftedDays = mQoL_Utils.YMDToEpochDays(year, month, day) + days
    local shiftedYear, shiftedMonth, shiftedDay = mQoL_Utils.EpochDaysToYMD(shiftedDays)
    return tonumber(string.format("%04d%02d%02d", shiftedYear, shiftedMonth, shiftedDay))
end

function mQoL_Utils.DetectRegionForWeeklyReset()
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

function mQoL_Utils.ConvertEUWeeklyYMDToCurrentRegion(ymd)
    local region = mQoL_Utils.DetectRegionForWeeklyReset()
    if region == "US" then
        return mQoL_Utils.ShiftYMDByDays(ymd, -1)
    end

    return tonumber(ymd) or ymd
end

function mQoL_Utils.GetNextResetTimestamp(resetType)
    local now = GetServerTime()
    local seconds = resetType == "daily" and mQoL_Utils.GetSecondsUntilDailyReset() or mQoL_Utils.GetSecondsUntilWeeklyReset()
    if not seconds then
        return nil
    end

    return now + seconds
end

function mQoL_Utils.GetYMDTimestampAtReset(ymd, resetType)
    local year, month, day = mQoL_Utils.ParseYMD(ymd)
    if not year then
        return nil
    end

    local nextReset = mQoL_Utils.GetNextResetTimestamp(resetType or "weekly")
    if not nextReset then
        return nil
    end

    local resetDate = date("*t", nextReset)
    if not resetDate then
        return nil
    end

    local baseDays = mQoL_Utils.YMDToEpochDays(resetDate.year, resetDate.month, resetDate.day)
    local targetDays = mQoL_Utils.YMDToEpochDays(year, month, day)
    return nextReset + ((targetDays - baseDays) * 86400)
end

function mQoL_Utils.GetTodayYMD()
    return tonumber(date("%Y%m%d", GetServerTime()))
end

function mQoL_Utils.FormatRemainingDuration(remaining)
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