mQoL_WeeklyRewardUtils = mQoL_WeeklyRewardUtils or {}

local WeeklyRewardUtils = mQoL_WeeklyRewardUtils
local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local Utils = mQoL_Utils or {}
local GetNow = Utils.GetNow or time

-- Keep collection and formatting here so AccountOverview only wires events and renders DB state.
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local GREAT_VAULT_ICON_TEXTURE_SIZE = 2048
local GREAT_VAULT_EMPTY_ICON = {
    texture = "Interface\\LootFrame\\LootGreatVaultFX",
    texCoords = {
        22 / GREAT_VAULT_ICON_TEXTURE_SIZE,
        146 / GREAT_VAULT_ICON_TEXTURE_SIZE,
        33 / GREAT_VAULT_ICON_TEXTURE_SIZE,
        160 / GREAT_VAULT_ICON_TEXTURE_SIZE,
    },
}
local GREAT_VAULT_ACTIVE_ICON = {
    texture = "Interface\\LootFrame\\LootGreatVaultFXPart2",
    texCoords = {
        48 / GREAT_VAULT_ICON_TEXTURE_SIZE,
        172 / GREAT_VAULT_ICON_TEXTURE_SIZE,
        63 / GREAT_VAULT_ICON_TEXTURE_SIZE,
        191 / GREAT_VAULT_ICON_TEXTURE_SIZE,
    },
}
local DEFAULT_VAULT_SUMMARY_TEXT = "(0/3, 0/3, 0/3)"
local DEFAULT_LEGION_SUMMARY_TEXT = "0/1"
local DEFAULT_UNSUPPORTED_SUMMARY_TEXT = "-"

-- End of Dungeon ilvl added to automatically determine current weekly chest season
local LEGION_REWARD_ILVL_BY_KEY_S1 = { -- Confirmed weekly chest values for 7.0.3
    [2] = { endOfDungeon = 845, weeklyChest = 850 },
    [3] = { endOfDungeon = 845, weeklyChest = 855 },
    [4] = { endOfDungeon = 850, weeklyChest = 860 },
    [5] = { endOfDungeon = 850, weeklyChest = 865 },
    [6] = { endOfDungeon = 855, weeklyChest = 865 },
    [7] = { endOfDungeon = 855, weeklyChest = 870 },
    [8] = { endOfDungeon = 860, weeklyChest = 870 },
    [9] = { endOfDungeon = 860, weeklyChest = 875 },
    [10] = { endOfDungeon = 865, weeklyChest = 880 },
    [11] = { endOfDungeon = 870, weeklyChest = 880 }, -- Patch 7.1.0 adds 5 extra item level
    [12] = { endOfDungeon = 870, weeklyChest = 885 },
    [13] = { endOfDungeon = 875, weeklyChest = 890 },
    [14] = { endOfDungeon = 880, weeklyChest = 895 },
    [15] = { endOfDungeon = 885, weeklyChest = 900 }, -- Patch 7.1.5 adds another 15 item level increase
}

local LEGION_REWARD_ILVL_BY_KEY_S2 = { -- Confirmed weekly chest values for 7.2.0
    [2] = { endOfDungeon = 870, weeklyChest = 875 },
    [3] = { endOfDungeon = 870, weeklyChest = 880 },
    [4] = { endOfDungeon = 875, weeklyChest = 885 },
    [5] = { endOfDungeon = 875, weeklyChest = 890 },
    [6] = { endOfDungeon = 880, weeklyChest = 890 },
    [7] = { endOfDungeon = 880, weeklyChest = 895 },
    [8] = { endOfDungeon = 885, weeklyChest = 895 },
    [9] = { endOfDungeon = 885, weeklyChest = 900 },
    [10] = { endOfDungeon = 890, weeklyChest = 905 },
    [11] = { endOfDungeon = 890, weeklyChest = 910 }, -- Patch 7.2.5 adds 25 ilvl increase
    [12] = { endOfDungeon = 895, weeklyChest = 915 },
    [13] = { endOfDungeon = 900, weeklyChest = 920 },
    [14] = { endOfDungeon = 905, weeklyChest = 925 },
    [15] = { endOfDungeon = 910, weeklyChest = 930 },
}

local LEGION_REWARD_ILVL_BY_KEY_S3 = { -- Unconfirmed but expected weekly chest values for 7.3.0
    [2] = { endOfDungeon = 890, weeklyChest = 905 },
    [3] = { endOfDungeon = 895, weeklyChest = 910 },
    [4] = { endOfDungeon = 895, weeklyChest = 915 },
    [5] = { endOfDungeon = 900, weeklyChest = 920 },
    [6] = { endOfDungeon = 900, weeklyChest = 920 },
    [7] = { endOfDungeon = 905, weeklyChest = 925 },
    [8] = { endOfDungeon = 910, weeklyChest = 925 },
    [9] = { endOfDungeon = 910, weeklyChest = 935 },
    [10] = { endOfDungeon = 915, weeklyChest = 935 },
    [11] = { endOfDungeon = 920, weeklyChest = 940 }, -- Patch 7.3.5 adds 25 ilvl increase
    [12] = { endOfDungeon = 925, weeklyChest = 945 },
    [13] = { endOfDungeon = 930, weeklyChest = 950 },
    [14] = { endOfDungeon = 935, weeklyChest = 955 },
    [15] = { endOfDungeon = 940, weeklyChest = 960 },
}

local LEGION_REWARD_TABLES_BY_SEASON = {
    S1 = LEGION_REWARD_ILVL_BY_KEY_S1,
    S2 = LEGION_REWARD_ILVL_BY_KEY_S2,
    S3 = LEGION_REWARD_ILVL_BY_KEY_S3,
}

local LEGION_SEASON_ORDER = { "S1", "S2", "S3" }
local LEGION_DEFAULT_SEASON = "S1"

-- Uses the local client clock on purpose so private-server users can retune this easily.
local LEGION_WEEKLY_RESET_WEEKDAY = 4 -- 1 = Sunday, 4 = Wednesday
local LEGION_WEEKLY_RESET_HOUR = 8
local LEGION_WEEKLY_RESET_MINUTE = 0

local GROUP_ORDER = {
    { key = "raid", label = "Raid", total = 3, enumFields = { "Raid" }, fallbackType = 3, defaultThresholds = { 2, 4, 6 } },
    { key = "dungeons", label = DUNGEONS or "Dungeons", total = 3, enumFields = { "Activities", "dungeons" }, fallbackType = 1, defaultThresholds = { 1, 4, 8 } },
    { key = "world", label = "World", total = 3, enumFields = { "World" }, fallbackType = 6, defaultThresholds = { 2, 4, 8 } },
}

WeeklyRewardUtils.DefaultIcon = DEFAULT_ICON
WeeklyRewardUtils.GreatVaultEmptyIcon = GREAT_VAULT_EMPTY_ICON
WeeklyRewardUtils.GreatVaultActiveIcon = GREAT_VAULT_ACTIVE_ICON
WeeklyRewardUtils.DefaultVaultSummaryText = DEFAULT_VAULT_SUMMARY_TEXT
WeeklyRewardUtils.DefaultLegionSummaryText = DEFAULT_LEGION_SUMMARY_TEXT
WeeklyRewardUtils.DefaultUnsupportedSummaryText = DEFAULT_UNSUPPORTED_SUMMARY_TEXT
WeeklyRewardUtils.LegionRewardItemLevelByKey = LEGION_REWARD_TABLES_BY_SEASON
WeeklyRewardUtils.LegionWeeklyChestItemLevelByKey = LEGION_REWARD_TABLES_BY_SEASON

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

local function NormalizeOptionalText(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    return value
end

local function SafeFormatText(template, ...)
    if type(template) ~= "string" or template == "" then
        return nil
    end

    local ok, text = pcall(string.format, template, ...)
    if ok and type(text) == "string" and text ~= "" then
        return text
    end

    return template
end

local function NormalizeLegionSeasonID(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    value = string.upper(value)
    if LEGION_REWARD_TABLES_BY_SEASON[value] then
        return value
    end

    return nil
end

local function GetLegionRewardTableBySeason(seasonID)
    seasonID = NormalizeLegionSeasonID(seasonID) or LEGION_DEFAULT_SEASON
    return LEGION_REWARD_TABLES_BY_SEASON[seasonID], seasonID
end

local function ResolveLegionRewardsForLevel(rewardTable, bestLevel)
    bestLevel = ClampNumber(bestLevel)
    if type(rewardTable) ~= "table" or bestLevel <= 0 then
        return nil
    end

    local bestMatchLevel = 0
    local bestRewards = nil
    for level, rewards in pairs(rewardTable) do
        level = ClampNumber(level)
        if bestLevel >= level and level >= bestMatchLevel then
            bestMatchLevel = level
            bestRewards = rewards
        end
    end

    return bestRewards, bestMatchLevel
end

local function DetectLegionSeasonFromEndOfDungeon(bestLevel, endOfDungeonItemLevel, preferredSeasonID)
    bestLevel = ClampNumber(bestLevel)
    endOfDungeonItemLevel = ClampNumber(endOfDungeonItemLevel)
    preferredSeasonID = NormalizeLegionSeasonID(preferredSeasonID)
    if bestLevel <= 0 or endOfDungeonItemLevel <= 0 then
        return nil
    end

    if preferredSeasonID then
        local preferredTable = LEGION_REWARD_TABLES_BY_SEASON[preferredSeasonID]
        local rewards = ResolveLegionRewardsForLevel(preferredTable, bestLevel)
        if ClampNumber(rewards and rewards.endOfDungeon) == endOfDungeonItemLevel then
            return preferredSeasonID
        end
    end

    for _, seasonID in ipairs(LEGION_SEASON_ORDER) do
        if seasonID ~= preferredSeasonID then
            local rewardTable = LEGION_REWARD_TABLES_BY_SEASON[seasonID]
            local rewards = ResolveLegionRewardsForLevel(rewardTable, bestLevel)
            if ClampNumber(rewards and rewards.endOfDungeon) == endOfDungeonItemLevel then
                return seasonID
            end
        end
    end

    return nil
end

local function CreateRetailSlot(index, threshold)
    return {
        index = ClampNumber(index),
        progress = 0,
        threshold = ClampNumber(threshold),
        unlocked = false,
        itemLevel = 0,
        activityID = 0,
        level = 0,
        activityTierID = 0,
        raidString = nil,
        progressText = nil,
    }
end

local function BuildRetailSlots(groupInfo)
    local slots = {}

    for index = 1, ClampNumber(groupInfo and groupInfo.total) do
        local thresholds = groupInfo and groupInfo.defaultThresholds or nil
        slots[index] = CreateRetailSlot(index, thresholds and thresholds[index])
    end

    return slots
end

local function BuildRetailGroups()
    local groups = {}

    for _, groupInfo in ipairs(GROUP_ORDER) do
        groups[groupInfo.key] = {
            completed = 0,
            total = groupInfo.total,
            itemLevels = {},
            slots = BuildRetailSlots(groupInfo),
        }
    end

    return groups
end

local function BuildLegionGroups()
    return {
        raid = { completed = 0, total = 0, itemLevels = {}, slots = {} },
        dungeons = { completed = 0, total = 1, itemLevels = {}, slots = {} },
        world = { completed = 0, total = 0, itemLevels = {}, slots = {} },
    }
end

local function BuildUnsupportedGroups()
    return {
        raid = { completed = 0, total = 0, itemLevels = {}, slots = {} },
        dungeons = { completed = 0, total = 0, itemLevels = {}, slots = {} },
        world = { completed = 0, total = 0, itemLevels = {}, slots = {} },
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
            currentSeason = nil,
            endOfDungeonItemLevel = 0,
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

local function CountUnlockedRetailSlots(values, maxSlots)
    local unlockedCount = 0

    for index = 1, ClampNumber(maxSlots) do
        local slot = type(values) == "table" and values[index] or nil
        if type(slot) == "table" and slot.unlocked then
            unlockedCount = unlockedCount + 1
        end
    end

    return unlockedCount
end

local function BuildItemLevelsFromRetailSlots(values, maxSlots)
    local itemLevels = {}

    for index = 1, ClampNumber(maxSlots) do
        local slot = type(values) == "table" and values[index] or nil
        if type(slot) == "table" and slot.unlocked then
            itemLevels[#itemLevels + 1] = ClampNumber(slot.itemLevel)
        end
    end

    return itemLevels
end

local function NormalizeRetailSlots(values, groupInfo, fallbackCompleted, fallbackItemLevels)
    local normalized = BuildRetailSlots(groupInfo)
    local completed = ClampNumber(fallbackCompleted)
    local itemLevels = NormalizeItemLevelList(fallbackItemLevels)
    local unlockedIndex = 0

    for index = 1, ClampNumber(groupInfo and groupInfo.total) do
        local slot = normalized[index]
        local rawSlot = type(values) == "table" and values[index] or nil

        slot.index = index
        slot.threshold = ClampNumber(rawSlot and rawSlot.threshold)
        if slot.threshold <= 0 then
            local fallbackThresholds = groupInfo and groupInfo.defaultThresholds or nil
            slot.threshold = ClampNumber(fallbackThresholds and fallbackThresholds[index])
        end

        slot.progress = ClampNumber(rawSlot and rawSlot.progress)
        slot.unlocked = type(rawSlot) == "table" and rawSlot.unlocked and true or false
        slot.activityID = ClampNumber(rawSlot and rawSlot.activityID)
        slot.level = ClampNumber(rawSlot and rawSlot.level)
        slot.activityTierID = ClampNumber(rawSlot and rawSlot.activityTierID)
        slot.raidString = NormalizeOptionalText(rawSlot and rawSlot.raidString)
        slot.progressText = NormalizeOptionalText(rawSlot and rawSlot.progressText)

        if type(rawSlot) ~= "table" and index <= completed then
            slot.unlocked = true
        end

        if slot.unlocked and slot.progress <= 0 then
            slot.progress = slot.threshold > 0 and slot.threshold or 1
        end

        slot.itemLevel = ClampNumber(rawSlot and rawSlot.itemLevel)
        if slot.unlocked then
            unlockedIndex = unlockedIndex + 1
            if slot.itemLevel <= 0 then
                slot.itemLevel = ClampNumber(itemLevels[unlockedIndex])
            end
        end
    end

    return normalized
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
            targetGroup.total = groupInfo.total
            targetGroup.slots = NormalizeRetailSlots(
                storedGroup and storedGroup.slots,
                groupInfo,
                storedGroup and storedGroup.completed,
                storedGroup and storedGroup.itemLevels
            )
            targetGroup.completed = math.min(groupInfo.total, CountUnlockedRetailSlots(targetGroup.slots, groupInfo.total))
            targetGroup.itemLevels = NormalizeItemLevelList(storedGroup and storedGroup.itemLevels)

            local slotItemLevels = BuildItemLevelsFromRetailSlots(targetGroup.slots, groupInfo.total)
            if #targetGroup.itemLevels == 0 then
                targetGroup.itemLevels = slotItemLevels
            else
                for index = 1, math.min(groupInfo.total, #slotItemLevels) do
                    if ClampNumber(targetGroup.itemLevels[index]) <= 0 and ClampNumber(slotItemLevels[index]) > 0 then
                        targetGroup.itemLevels[index] = ClampNumber(slotItemLevels[index])
                    end
                end
            end

            local unlockedIndex = 0
            for slotIndex = 1, groupInfo.total do
                local slot = targetGroup.slots[slotIndex]
                if slot and slot.unlocked then
                    unlockedIndex = unlockedIndex + 1
                    if ClampNumber(slot.itemLevel) <= 0 then
                        slot.itemLevel = ClampNumber(targetGroup.itemLevels[unlockedIndex])
                    end
                end
            end
        end

        base.summaryText = string.format(
            "(%d/3, %d/3, %d/3)",
            base.groups.raid.completed,
            base.groups.dungeons.completed,
            base.groups.world.completed
        )
        return base
    end

    if kind == "legion_weekly_chest" then
        local storedLegacy = type(rawValue.legacy) == "table" and rawValue.legacy or {}
        base.legacy.bestLevel = ClampNumber(storedLegacy.bestLevel)
        base.legacy.dungeonMapID = ClampNumber(storedLegacy.dungeonMapID)
        base.legacy.dungeonName = type(storedLegacy.dungeonName) == "string" and storedLegacy.dungeonName or nil
        base.legacy.currentSeason = NormalizeLegionSeasonID(storedLegacy.currentSeason)
        base.legacy.endOfDungeonItemLevel = ClampNumber(storedLegacy.endOfDungeonItemLevel)
        if not base.legacy.dungeonName and base.legacy.dungeonMapID > 0 then
            base.legacy.dungeonName = GetLegionDungeonName(base.legacy.dungeonMapID)
        end
        base.groups.dungeons.completed = base.legacy.bestLevel > 0 and 1 or 0

        local storedGroup = type(rawValue.groups) == "table" and rawValue.groups.dungeons or nil
        base.groups.dungeons.itemLevels = NormalizeItemLevelList(storedGroup and storedGroup.itemLevels)
        if base.groups.dungeons.completed > 0 and #base.groups.dungeons.itemLevels == 0 then
            base.groups.dungeons.itemLevels = { GetLegionWeeklyChestItemLevel(base.legacy.bestLevel, base.legacy.currentSeason) }
        end
        base.summaryText = string.format("%d/1", base.groups.dungeons.completed)
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

local function ResolveRetailActivityProgressText(activity, groupInfo)
    if type(activity) ~= "table" or type(groupInfo) ~= "table" then
        return nil
    end

    local level = ClampNumber(activity.level)

    if groupInfo.key == "raid" then
        if DifficultyUtil and type(DifficultyUtil.GetDifficultyName) == "function" then
            return NormalizeOptionalText(SafeCall(DifficultyUtil.GetDifficultyName, level))
        end

        return nil
    end

    if groupInfo.key == "dungeons" then
        local heroicDifficultyID = DifficultyUtil and DifficultyUtil.ID and ClampNumber(DifficultyUtil.ID.DungeonHeroic) or 0
        local difficultyID = ClampNumber(
            SafeCall(C_WeeklyRewards and C_WeeklyRewards.GetDifficultyIDForActivityTier, activity.activityTierID)
        )

        if heroicDifficultyID > 0 and difficultyID == heroicDifficultyID then
            return NormalizeOptionalText(WEEKLY_REWARDS_HEROIC) or "Heroic"
        end

        if level > 0 then
            return SafeFormatText(WEEKLY_REWARDS_MYTHIC, level) or string.format("Mythic %d", level)
        end

        return nil
    end

    if groupInfo.key == "world" then
        if level > 0 then
            return SafeFormatText(GREAT_VAULT_WORLD_TIER, level) or string.format("Tier %d", level)
        end

        return nil
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
        local existingGroup = existingSnapshot.groups[groupInfo.key] or {}

        for slotIndex, activity in ipairs(type(activities) == "table" and activities or {}) do
            if slotIndex > groupInfo.total then
                break
            end

            local targetSlot = targetGroup.slots[slotIndex] or CreateRetailSlot(slotIndex, groupInfo.defaultThresholds and groupInfo.defaultThresholds[slotIndex])
            local existingSlot = type(existingGroup.slots) == "table" and existingGroup.slots[slotIndex] or nil
            local progress = ClampNumber(activity and activity.progress)
            local threshold = ClampNumber(activity and activity.threshold)
            local isComplete = threshold > 0 and progress >= threshold

            targetSlot.index = slotIndex
            targetSlot.progress = progress
            targetSlot.threshold = threshold > 0 and threshold or ClampNumber(targetSlot.threshold)
            targetSlot.unlocked = isComplete
            targetSlot.activityID = ClampNumber(activity and activity.id)
            targetSlot.itemLevel = ClampNumber(ResolveRetailActivityItemLevel(activity))
            targetSlot.level = ClampNumber(activity and activity.level)
            targetSlot.activityTierID = ClampNumber(activity and activity.activityTierID)
            targetSlot.raidString = NormalizeOptionalText(activity and activity.raidString)
            targetSlot.progressText = isComplete and ResolveRetailActivityProgressText(activity, groupInfo) or nil

            if isComplete and targetSlot.itemLevel <= 0 then
                targetSlot.itemLevel = ClampNumber(existingSlot and existingSlot.itemLevel)
            end

            if isComplete and targetSlot.level <= 0 then
                targetSlot.level = ClampNumber(existingSlot and existingSlot.level)
            end

            if isComplete and targetSlot.activityTierID <= 0 then
                targetSlot.activityTierID = ClampNumber(existingSlot and existingSlot.activityTierID)
            end

            if isComplete and not targetSlot.raidString then
                targetSlot.raidString = NormalizeOptionalText(existingSlot and existingSlot.raidString)
            end

            if isComplete and not targetSlot.progressText then
                targetSlot.progressText = NormalizeOptionalText(existingSlot and existingSlot.progressText)
            end

            targetGroup.slots[slotIndex] = targetSlot

            if isComplete then
                targetGroup.completed = math.min(groupInfo.total, targetGroup.completed + 1)
                targetGroup.itemLevels[#targetGroup.itemLevels + 1] = ClampNumber(targetSlot.itemLevel)
            end
        end
    end

    for _, groupInfo in ipairs(GROUP_ORDER) do
        local targetGroup = snapshot.groups[groupInfo.key]
        local existingGroup = existingSnapshot.groups[groupInfo.key] or {}

        for slotIndex = 1, groupInfo.total do
            local targetSlot = targetGroup.slots[slotIndex]
            local existingSlot = type(existingGroup.slots) == "table" and existingGroup.slots[slotIndex] or nil

            if targetSlot and targetSlot.unlocked and ClampNumber(targetSlot.itemLevel) <= 0 and ClampNumber(existingSlot and existingSlot.itemLevel) > 0 then
                targetSlot.itemLevel = ClampNumber(existingSlot.itemLevel)
            end
        end

        targetGroup.completed = math.min(groupInfo.total, CountUnlockedRetailSlots(targetGroup.slots, groupInfo.total))
        targetGroup.itemLevels = BuildItemLevelsFromRetailSlots(targetGroup.slots, groupInfo.total)

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
        snapshot.groups.dungeons.completed,
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

GetLegionWeeklyChestItemLevel = function(bestLevel, seasonID)
    bestLevel = ClampNumber(bestLevel)
    if bestLevel <= 0 then
        return 0
    end

    local rewardTable = GetLegionRewardTableBySeason(seasonID)
    local rewards = ResolveLegionRewardsForLevel(rewardTable, bestLevel)
    return ClampNumber(rewards and rewards.weeklyChest)
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
    local endOfDungeonItemLevel = ClampNumber(type(context) == "table" and context.endOfDungeonItemLevel)

    if bestLevel > snapshot.legacy.bestLevel then
        snapshot.legacy.bestLevel = bestLevel
        snapshot.legacy.dungeonMapID = ClampNumber(challengeCompletion.mapChallengeModeID)
        snapshot.legacy.dungeonName = GetLegionDungeonName(snapshot.legacy.dungeonMapID)
        snapshot.groups.dungeons.completed = 1
    end

    if endOfDungeonItemLevel > 0 then
        snapshot.legacy.endOfDungeonItemLevel = endOfDungeonItemLevel

        local levelForDetection = bestLevel > 0 and bestLevel or snapshot.legacy.bestLevel
        local detectedSeasonID = DetectLegionSeasonFromEndOfDungeon(
            levelForDetection,
            endOfDungeonItemLevel,
            snapshot.legacy.currentSeason
        )
        if detectedSeasonID then
            snapshot.legacy.currentSeason = detectedSeasonID
        end
    end

    if snapshot.legacy.bestLevel > 0 then
        snapshot.groups.dungeons.completed = 1
        snapshot.groups.dungeons.itemLevels = {
            GetLegionWeeklyChestItemLevel(snapshot.legacy.bestLevel, snapshot.legacy.currentSeason),
        }
    end

    snapshot.summaryText = string.format("%d/1", snapshot.groups.dungeons.completed)
    snapshot.lastSync = ClampNumber(GetNow())
    return snapshot
end

local function BuildTooltipLines(snapshot)
    local lines = {}

    if snapshot.kind == "great_vault" then
        for groupIndex, groupInfo in ipairs(GROUP_ORDER) do
            local group = snapshot.groups[groupInfo.key] or {}
            lines[#lines + 1] = {
                text = groupInfo.label,
                color = { 1, 0.82, 0 },
            }

            for slotIndex = 1, ClampNumber(groupInfo.total) do
                local slot = type(group.slots) == "table" and group.slots[slotIndex] or nil
                local progress = ClampNumber(slot and slot.progress)
                local threshold = ClampNumber(slot and slot.threshold)
                local itemLevel = ClampNumber(slot and slot.itemLevel)

                if threshold <= 0 then
                    threshold = ClampNumber(groupInfo.defaultThresholds and groupInfo.defaultThresholds[slotIndex])
                end

                if type(slot) == "table" and slot.unlocked and progress <= 0 then
                    progress = threshold > 0 and threshold or 1
                end

                if threshold > 0 then
                    progress = math.min(progress, threshold)
                end

                local itemLevelText = "-"
                if type(slot) == "table" and slot.unlocked and itemLevel > 0 then
                    itemLevelText = string.format("%d ilvl", itemLevel)
                end

                lines[#lines + 1] = {
                    text = string.format("%d/%d - %s", progress, threshold, itemLevelText),
                    color = { 0.9, 0.9, 0.9 },
                }
            end

            if groupIndex < #GROUP_ORDER then
                lines[#lines + 1] = {
                    text = " ",
                    color = { 0.9, 0.9, 0.9 },
                }
            end
        end

        return lines
    end

    if snapshot.kind == "legion_weekly_chest" then
        local group = snapshot.groups.dungeons or {}
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

local function HasCompletedGreatVaultSlot(snapshot)
    if type(snapshot) ~= "table" or snapshot.kind ~= "great_vault" or type(snapshot.groups) ~= "table" then
        return false
    end

    for _, groupInfo in ipairs(GROUP_ORDER) do
        local group = snapshot.groups[groupInfo.key]
        if ClampNumber(group and group.completed) > 0 then
            return true
        end

        local slots = type(group) == "table" and group.slots or nil
        if type(slots) == "table" then
            for slotIndex = 1, ClampNumber(groupInfo.total) do
                local slot = slots[slotIndex]
                if type(slot) == "table" and slot.unlocked then
                    return true
                end
            end
        end
    end

    return false
end

local function GetDisplayIcon(snapshot)
    if clientInfo.isRetail and type(snapshot) == "table" and snapshot.kind == "great_vault" then
        return HasCompletedGreatVaultSlot(snapshot) and GREAT_VAULT_ACTIVE_ICON or GREAT_VAULT_EMPTY_ICON
    end

    return DEFAULT_ICON
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
        icon = GetDisplayIcon(snapshot),
        lines = BuildTooltipLines(snapshot),
        snapshot = snapshot,
    }
end

function WeeklyRewardUtils.GetRetailGroupOrder()
    local groups = {}

    for _, groupInfo in ipairs(GROUP_ORDER) do
        groups[#groups + 1] = {
            key = groupInfo.key,
            label = groupInfo.label,
            total = groupInfo.total,
            defaultThresholds = groupInfo.defaultThresholds,
        }
    end

    return groups
end