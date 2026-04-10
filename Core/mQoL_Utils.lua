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