mQoL_WeeklyRewardUtils = mQoL_WeeklyRewardUtils or {}

local WeeklyRewardUtils = mQoL_WeeklyRewardUtils
local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local Utils = mQoL_Utils or {}
local GetNow = Utils.GetNow or time

-- Keep collection and formatting here so AccountOverview only wires events and renders DB state.
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_VAULT_SUMMARY_TEXT = "(0/3, 0/3, 0/3)"
local DEFAULT_LEGION_SUMMARY_TEXT = "0/1"
local DEFAULT_UNSUPPORTED_SUMMARY_TEXT = "-"

-- These values are for last season of legion later i add other season values. keep in mind there is superior thunderforging pls come back to retail system kekw so this ilvl are base value.
local LEGION_WEEKLY_CHEST_ILVL_BY_KEY = {
    [2] = 905,
    [3] = 910,
    [4] = 915,
    [5] = 920,
    [6] = 925,
    [7] = 930,
    [8] = 935,
    [9] = 940,
    [10] = 945,
    [11] = 950,
    [12] = 955,
    [13] = 960,
    [14] = 960,
    [15] = 960,
}

-- Uses the local client clock on purpose so private-server users can retune this easily.
local LEGION_WEEKLY_RESET_WEEKDAY = 4 -- 1 = Sunday, 4 = Wednesday
local LEGION_WEEKLY_RESET_HOUR = 8
local LEGION_WEEKLY_RESET_MINUTE = 0

local GROUP_ORDER = {
    { key = "raid", label = "Raid", total = 3, enumFields = { "Raid" }, fallbackType = 3 },
    { key = "mythicPlus", label = "Mythic+", total = 3, enumFields = { "Activities", "MythicPlus" }, fallbackType = 1 },
    { key = "world", label = "World", total = 3, enumFields = { "World" }, fallbackType = 6 },
}

WeeklyRewardUtils.DefaultIcon = DEFAULT_ICON
WeeklyRewardUtils.DefaultVaultSummaryText = DEFAULT_VAULT_SUMMARY_TEXT
WeeklyRewardUtils.DefaultLegionSummaryText = DEFAULT_LEGION_SUMMARY_TEXT
WeeklyRewardUtils.DefaultUnsupportedSummaryText = DEFAULT_UNSUPPORTED_SUMMARY_TEXT
WeeklyRewardUtils.LegionWeeklyChestItemLevelByKey = LEGION_WEEKLY_CHEST_ILVL_BY_KEY

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result1, result2, result3, result4 = pcall(func, ...)
    if not ok then
        return nil
    end

    return result1, result2, result3, result4
end

local function ClampNumber(value)
    local numeric = tonumber(value)
    if not numeric or numeric <= 0 then
        return 0
    end

    return math.floor(numeric)
end

local function BuildRetailGroups()
    return {
        raid = { completed = 0, total = 3, itemLevels = {} },
        mythicPlus = { completed = 0, total = 3, itemLevels = {} },
        world = { completed = 0, total = 3, itemLevels = {} },
    }
end

local function BuildLegionGroups()
    return {
        raid = { completed = 0, total = 0, itemLevels = {} },
        mythicPlus = { completed = 0, total = 1, itemLevels = {} },
        world = { completed = 0, total = 0, itemLevels = {} },
    }
end

local function BuildUnsupportedGroups()
    return {
        raid = { completed = 0, total = 0, itemLevels = {} },
        mythicPlus = { completed = 0, total = 0, itemLevels = {} },
        world = { completed = 0, total = 0, itemLevels = {} },
    }
end

local function GetRetailWeekKey()
    if not clientInfo.isRetail then
        return nil
    end

    if C_DateAndTime and type(C_DateAndTime.GetWeeklyResetStartTime) == "function" then
        local weeklyResetStart = ClampNumber(C_DateAndTime.GetWeeklyResetStartTime())
        if weeklyResetStart > 0 then
            return tostring(weeklyResetStart)
        end
    end

    if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" then
        local secondsUntilReset = ClampNumber(C_DateAndTime.GetSecondsUntilWeeklyReset())
        if secondsUntilReset > 0 then
            local weeklyResetStart = GetNow() + secondsUntilReset - (7 * 24 * 60 * 60)
            return tostring(ClampNumber(weeklyResetStart))
        end
    end

    return nil
end

local function GetLegacyWeekKey()
    local currentTime = GetNow()
    local info = date("*t", currentTime)
    local daysSinceReset = (info.wday - LEGION_WEEKLY_RESET_WEEKDAY) % 7

    info.day = info.day - daysSinceReset
    info.hour = LEGION_WEEKLY_RESET_HOUR
    info.min = LEGION_WEEKLY_RESET_MINUTE
    info.sec = 0
    info.isdst = nil

    local resetTime = time(info)
    if type(resetTime) ~= "number" then
        return tostring(ClampNumber(currentTime))
    end

    if resetTime > currentTime then
        resetTime = resetTime - (7 * 24 * 60 * 60)
    end

    return tostring(ClampNumber(resetTime))
end

local function GetCurrentMode()
    if clientInfo.isRetail and C_WeeklyRewards and type(C_WeeklyRewards.GetActivities) == "function" then
        return "great_vault"
    end

    if clientInfo.isLegion then
        return "legion_weekly_chest"
    end

    return "none"
end

local function GetCurrentWeekKeyForKind(kind)
    if kind == "great_vault" then
        if clientInfo.isRetail then
            return GetRetailWeekKey() or tostring(ClampNumber(GetNow()))
        end

        return nil
    end

    if kind == "legion_weekly_chest" then
        if clientInfo.isLegion then
            return GetLegacyWeekKey()
        end

        return nil
    end

    return "unsupported"
end

local function CreateBaseSnapshot(kind)
    local snapshot = {
        kind = kind,
        weekKey = GetCurrentWeekKeyForKind(kind),
        lastSync = 0,
        title = "Weekly Reward",
        summaryText = DEFAULT_UNSUPPORTED_SUMMARY_TEXT,
        groups = BuildUnsupportedGroups(),
        legacy = {
            bestLevel = 0,
            dungeonMapID = nil,
            dungeonName = nil,
        },
    }

    if kind == "great_vault" then
        snapshot.title = "Great Vault"
        snapshot.summaryText = DEFAULT_VAULT_SUMMARY_TEXT
        snapshot.groups = BuildRetailGroups()
    elseif kind == "legion_weekly_chest" then
        snapshot.title = "Weekly Chest"
        snapshot.summaryText = DEFAULT_LEGION_SUMMARY_TEXT
        snapshot.groups = BuildLegionGroups()
    end

    return snapshot
end

local function NormalizeItemLevelList(values)
    local result = {}

    for _, value in ipairs(values or {}) do
        result[#result + 1] = ClampNumber(value)
    end

    return result
end

local GetLegionDungeonName
local GetLegionWeeklyChestItemLevel

local function NormalizeSnapshotForKind(rawValue, kind)
    local base = CreateBaseSnapshot(kind)

    if type(rawValue) ~= "table" then
        return base
    end

    if base.weekKey ~= nil and tostring(rawValue.weekKey or "") ~= tostring(base.weekKey) then
        return base
    end

    if base.weekKey == nil and rawValue.weekKey ~= nil then
        base.weekKey = tostring(rawValue.weekKey)
    end

    base.lastSync = ClampNumber(rawValue.lastSync)

    if kind == "great_vault" then
        for _, groupInfo in ipairs(GROUP_ORDER) do
            local storedGroup = type(rawValue.groups) == "table" and rawValue.groups[groupInfo.key] or nil
            local targetGroup = base.groups[groupInfo.key]
            targetGroup.completed = math.min(groupInfo.total, ClampNumber(storedGroup and storedGroup.completed))
            targetGroup.total = groupInfo.total
            targetGroup.itemLevels = NormalizeItemLevelList(storedGroup and storedGroup.itemLevels)
        end

        base.summaryText = string.format(
            "(%d/3, %d/3, %d/3)",
            base.groups.raid.completed,
            base.groups.mythicPlus.completed,
            base.groups.world.completed
        )
        return base
    end

    if kind == "legion_weekly_chest" then
        local storedLegacy = type(rawValue.legacy) == "table" and rawValue.legacy or {}
        base.legacy.bestLevel = ClampNumber(storedLegacy.bestLevel)
        base.legacy.dungeonMapID = ClampNumber(storedLegacy.dungeonMapID)
        base.legacy.dungeonName = type(storedLegacy.dungeonName) == "string" and storedLegacy.dungeonName or nil
        if not base.legacy.dungeonName and base.legacy.dungeonMapID > 0 then
            base.legacy.dungeonName = GetLegionDungeonName(base.legacy.dungeonMapID)
        end
        base.groups.mythicPlus.completed = base.legacy.bestLevel > 0 and 1 or 0

        local storedGroup = type(rawValue.groups) == "table" and rawValue.groups.mythicPlus or nil
        base.groups.mythicPlus.itemLevels = NormalizeItemLevelList(storedGroup and storedGroup.itemLevels)
        if base.groups.mythicPlus.completed > 0 and #base.groups.mythicPlus.itemLevels == 0 then
            base.groups.mythicPlus.itemLevels = { GetLegionWeeklyChestItemLevel(base.legacy.bestLevel) }
        end
        base.summaryText = string.format("%d/1", base.groups.mythicPlus.completed)
        return base
    end

    return base
end

local function GetWeeklyRewardEnumValue(groupInfo)
    local enumTable = Enum and Enum.WeeklyRewardChestThresholdType
    if type(enumTable) ~= "table" then
        return groupInfo.fallbackType
    end

    for _, field in ipairs(groupInfo.enumFields or {}) do
        if enumTable[field] ~= nil then
            return enumTable[field]
        end
    end

    return groupInfo.fallbackType
end

local function ResolveItemLevelFromLink(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    if C_Item and type(C_Item.GetDetailedItemLevelInfo) == "function" then
        local itemLevel = ClampNumber(SafeCall(C_Item.GetDetailedItemLevelInfo, itemLink))
        if itemLevel > 0 then
            return itemLevel
        end
    end

    if type(GetDetailedItemLevelInfo) == "function" then
        local itemLevel = ClampNumber(select(1, SafeCall(GetDetailedItemLevelInfo, itemLink)))
        if itemLevel > 0 then
            return itemLevel
        end
    end

    return nil
end

local function ResolveRetailActivityItemLevel(activity)
    if type(activity) ~= "table" then
        return nil
    end

    if type(activity.rewards) == "table" and C_WeeklyRewards and type(C_WeeklyRewards.GetItemHyperlink) == "function" then
        for _, reward in ipairs(activity.rewards) do
            local itemDBID = reward and reward.itemDBID
            if itemDBID then
                local itemLink = C_WeeklyRewards.GetItemHyperlink(itemDBID)
                local itemLevel = ResolveItemLevelFromLink(itemLink)
                if itemLevel then
                    return itemLevel
                end
            end
        end
    end

    if C_WeeklyRewards and type(C_WeeklyRewards.GetExampleRewardItemHyperlinks) == "function" then
        local itemLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
        local itemLevel = ResolveItemLevelFromLink(itemLink)
        if itemLevel then
            return itemLevel
        end
    end

    return nil
end

local function CollectRetailSnapshot(rawValue)
    local snapshot = CreateBaseSnapshot("great_vault")
    local existingSnapshot = NormalizeSnapshotForKind(rawValue, "great_vault")
    snapshot.lastSync = ClampNumber(GetNow())

    for _, groupInfo in ipairs(GROUP_ORDER) do
        local rewardType = GetWeeklyRewardEnumValue(groupInfo)
        local activities = SafeCall(C_WeeklyRewards and C_WeeklyRewards.GetActivities, rewardType)
        local targetGroup = snapshot.groups[groupInfo.key]

        for _, activity in ipairs(type(activities) == "table" and activities or {}) do
            local progress = ClampNumber(activity and activity.progress)
            local threshold = ClampNumber(activity and activity.threshold)
            local isComplete = threshold > 0 and progress >= threshold
            if isComplete then
                targetGroup.completed = math.min(groupInfo.total, targetGroup.completed + 1)
                targetGroup.itemLevels[#targetGroup.itemLevels + 1] = ClampNumber(ResolveRetailActivityItemLevel(activity))
            end
        end
    end

    for _, groupInfo in ipairs(GROUP_ORDER) do
        local targetGroup = snapshot.groups[groupInfo.key]
        local existingGroup = existingSnapshot.groups[groupInfo.key] or {}
        for index = 1, math.min(targetGroup.completed, #targetGroup.itemLevels) do
            local currentItemLevel = ClampNumber(targetGroup.itemLevels[index])
            local existingItemLevel = ClampNumber(existingGroup.itemLevels and existingGroup.itemLevels[index])
            if currentItemLevel <= 0 and existingItemLevel > 0 then
                targetGroup.itemLevels[index] = existingItemLevel
            end
        end
    end

    snapshot.summaryText = string.format(
        "(%d/3, %d/3, %d/3)",
        snapshot.groups.raid.completed,
        snapshot.groups.mythicPlus.completed,
        snapshot.groups.world.completed
    )

    return snapshot
end

GetLegionDungeonName = function(mapChallengeModeID)
    mapChallengeModeID = ClampNumber(mapChallengeModeID)
    if mapChallengeModeID <= 0 then
        return nil
    end

    if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
        local name = SafeCall(C_ChallengeMode.GetMapUIInfo, mapChallengeModeID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end

    return nil
end

GetLegionWeeklyChestItemLevel = function(bestLevel)
    bestLevel = ClampNumber(bestLevel)
    if bestLevel <= 0 then
        return 0
    end

    local bestMatchLevel = 0
    local bestItemLevel = 0
    for level, itemLevel in pairs(LEGION_WEEKLY_CHEST_ILVL_BY_KEY) do
        if bestLevel >= level and level >= bestMatchLevel then
            bestMatchLevel = level
            bestItemLevel = ClampNumber(itemLevel)
        end
    end

    return bestItemLevel
end

local function CaptureChallengeCompletionInfo()
    if not C_ChallengeMode then
        return nil
    end

    if type(C_ChallengeMode.GetChallengeCompletionInfo) == "function" then
        local info = SafeCall(C_ChallengeMode.GetChallengeCompletionInfo)
        if type(info) == "table" and ClampNumber(info.level) > 0 then
            return {
                level = ClampNumber(info.level),
                mapChallengeModeID = ClampNumber(info.mapChallengeModeID),
            }
        end
    end

    if type(C_ChallengeMode.GetCompletionInfo) == "function" then
        local mapChallengeModeID, level = SafeCall(C_ChallengeMode.GetCompletionInfo)
        if ClampNumber(level) > 0 then
            return {
                level = ClampNumber(level),
                mapChallengeModeID = ClampNumber(mapChallengeModeID),
            }
        end
    end

    return nil
end

local function UpdateLegionSnapshot(rawValue, context)
    local snapshot = NormalizeSnapshotForKind(rawValue, "legion_weekly_chest")
    local challengeCompletion = type(context) == "table" and context.challengeCompletion or nil
    local bestLevel = ClampNumber(challengeCompletion and challengeCompletion.level)

    if bestLevel > snapshot.legacy.bestLevel then
        snapshot.legacy.bestLevel = bestLevel
        snapshot.legacy.dungeonMapID = ClampNumber(challengeCompletion.mapChallengeModeID)
        snapshot.legacy.dungeonName = GetLegionDungeonName(snapshot.legacy.dungeonMapID)
        snapshot.groups.mythicPlus.completed = 1
        snapshot.groups.mythicPlus.itemLevels = { GetLegionWeeklyChestItemLevel(bestLevel) }
    end

    snapshot.summaryText = string.format("%d/1", snapshot.groups.mythicPlus.completed)
    snapshot.lastSync = ClampNumber(GetNow())
    return snapshot
end

local function BuildTooltipLines(snapshot)
    local lines = {}

    if snapshot.kind == "great_vault" then
        for _, groupInfo in ipairs(GROUP_ORDER) do
            local group = snapshot.groups[groupInfo.key] or {}
            lines[#lines + 1] = {
                text = string.format("%s %d/%d", groupInfo.label, ClampNumber(group.completed), ClampNumber(group.total)),
                color = { 1, 0.82, 0 },
            }

            local visibleItemLevels = NormalizeItemLevelList(group.itemLevels)
            if #visibleItemLevels == 0 then
                lines[#lines + 1] = {
                    text = "No reward unlocked this week.",
                    color = { 0.72, 0.72, 0.72 },
                }
            else
                for _, itemLevel in ipairs(visibleItemLevels) do
                    if itemLevel > 0 then
                        lines[#lines + 1] = {
                            text = string.format("%d item level", itemLevel),
                            color = { 0.9, 0.9, 0.9 },
                        }
                    else
                        lines[#lines + 1] = {
                            text = "Pending item level data.",
                            color = { 0.72, 0.72, 0.72 },
                        }
                    end
                end
            end
        end

        return lines
    end

    if snapshot.kind == "legion_weekly_chest" then
        local group = snapshot.groups.mythicPlus or {}
        lines[#lines + 1] = {
            text = string.format("Mythic+ %d/%d", ClampNumber(group.completed), ClampNumber(group.total)),
            color = { 1, 0.82, 0 },
        }

        if snapshot.legacy.dungeonName then
            lines[#lines + 1] = {
                text = snapshot.legacy.dungeonName,
                color = { 0.9, 0.9, 0.9 },
            }
        end

        if snapshot.legacy.bestLevel > 0 then
            lines[#lines + 1] = {
                text = string.format("Best key: +%d", snapshot.legacy.bestLevel),
                color = { 0.9, 0.9, 0.9 },
            }

            local itemLevel = ClampNumber(group.itemLevels and group.itemLevels[1])
            if itemLevel > 0 then
                lines[#lines + 1] = {
                    text = string.format("%d item level", itemLevel),
                    color = { 0.9, 0.9, 0.9 },
                }
            else
                lines[#lines + 1] = {
                    text = "Pending item level data.",
                    color = { 0.72, 0.72, 0.72 },
                }
            end
        else
            lines[#lines + 1] = {
                text = "No Mythic+ run tracked this week.",
                color = { 0.72, 0.72, 0.72 },
            }
        end

        return lines
    end

    lines[#lines + 1] = {
        text = "Not available on this client.",
        color = { 0.72, 0.72, 0.72 },
    }
    return lines
end

function WeeklyRewardUtils.GetCurrentMode()
    return GetCurrentMode()
end

function WeeklyRewardUtils.NormalizeSnapshot(rawValue)
    local kind = type(rawValue) == "table" and rawValue.kind or nil
    if kind ~= "great_vault" and kind ~= "legion_weekly_chest" and kind ~= "none" then
        kind = GetCurrentMode()
    end

    return NormalizeSnapshotForKind(rawValue, kind)
end

function WeeklyRewardUtils.CaptureCurrentSnapshot(rawValue, context)
    local mode = GetCurrentMode()
    if mode == "great_vault" then
        return CollectRetailSnapshot(rawValue)
    end

    if mode == "legion_weekly_chest" then
        return UpdateLegionSnapshot(rawValue, context)
    end

    local snapshot = NormalizeSnapshotForKind(rawValue, "none")
    snapshot.lastSync = ClampNumber(GetNow())
    return snapshot
end

function WeeklyRewardUtils.CaptureChallengeCompletionInfo()
    return CaptureChallengeCompletionInfo()
end

function WeeklyRewardUtils.GetDisplayState(rawValue)
    local snapshot = WeeklyRewardUtils.NormalizeSnapshot(rawValue)
    return {
        kind = snapshot.kind,
        title = snapshot.title,
        summaryText = snapshot.summaryText,
        icon = DEFAULT_ICON,
        lines = BuildTooltipLines(snapshot),
        snapshot = snapshot,
    }
end