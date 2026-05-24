local addonName, L = ...
mQoL_AccountOverview = mQoL_AccountOverview or {}

local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
    return
end

local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local CreateCustomButton = mQoL_Styles and mQoL_Styles.CreateCustomButton
local CreateFrameBorder = mQoL_Templates and mQoL_Templates.CreateFrameBorder
local DeepCopy = mQoL_Utils.DeepCopy
local GetNow = mQoL_Utils.GetNow
local BuildGoldSnapshotData = mQoL_Utils.BuildGoldSnapshotData
local NormalizeGoldSnapshotData = mQoL_Utils.NormalizeGoldSnapshotData
local GetCurrentCharacterIdentity = mQoL_Utils.GetCurrentCharacterIdentity
local FormatMoneyCompact = mQoL_Utils.FormatMoneyCompact
local FormatAxisMoney = mQoL_Utils.FormatAxisMoney
local FormatDuration = mQoL_Utils.FormatDuration
local FormatTimestamp = mQoL_Utils.FormatTimestamp
local GetClassColor = mQoL_Utils.GetClassColorRGB
local ProfessionUtils = mQoL_ProfessionUtils
local WeeklyRewardUtils = mQoL_WeeklyRewardUtils
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

local HISTORY_MAX_POINTS = 20000
local HISTORY_RECENT_POINTS = 4000
local HISTORY_MERGE_WINDOW = 15 * SECONDS_PER_MINUTE
local HISTORY_CHART_POINTS = 64
local GOLD_CHART_WIDTH = 770
local GOLD_CHART_HEIGHT = 320
local GOLD_CHART_PLOT_TOP = 8
local GOLD_CHART_PLOT_BOTTOM = 12
local GOLD_CHART_VALUE_PADDING_RATIO = 0.03
local GOLD_CHART_FLAT_VALUE_PADDING_RATIO = 0.05
local OVERALL_DISPLAY_MIN_INTERVAL = 10 * SECONDS_PER_MINUTE
local PLAYED_REQUEST_COOLDOWN = 10
local PLAYED_DATA_STALE_AFTER = 6 * SECONDS_PER_HOUR
local BOOTSTRAP_SYNC_INTERVAL = 2
local BOOTSTRAP_SYNC_ATTEMPTS = 15
local OVERALL_ARCHIVE_MAX_POINTS = 12
local LEGION_CHALLENGE_LOOT_CAPTURE_WINDOW = 120
local DEFAULT_VAULT_PROGRESS_TEXT = "(0/3, 0/3, 0/3)"
local DEFAULT_UNSUPPORTED_VAULT_TEXT = "-"
local VAULT_PLACEHOLDER_ICON = WeeklyRewardUtils and WeeklyRewardUtils.DefaultIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
local ACCOUNT_OVERVIEW_STYLE = {
    headerBackground = { 0.095, 0.095, 0.105, 0.97 },
    headerBorder = { 0.22, 0.22, 0.24, 1 },
    headerAccent = { 0.16, 0.16, 0.18, 1 },
    headerText = { 0.95, 0.92, 0.86 },
    rowOdd = { 0.055, 0.055, 0.060, 0.94 },
    rowEven = { 0.075, 0.075, 0.082, 0.96 },
    rowSeparator = { 1, 1, 1, 0.035 },
    rowHighlight = { 1, 1, 1, 0.018 },
    cellBackground = { 0.125, 0.125, 0.132, 0.97 },
    cellBorder = { 0.23, 0.23, 0.25, 1 },
    cellHoverBackground = { 0.165, 0.165, 0.175, 0.98 },
    cellHoverBorder = { 0.34, 0.34, 0.37, 1 },
    cellActiveBackground = { 0.20, 0.16, 0.06, 0.98 },
    cellActiveBorder = { 0.47, 0.36, 0.14, 1 },
    placeholderBackground = { 0.095, 0.095, 0.105, 0.94 },
    placeholderBorder = { 0.17, 0.17, 0.19, 1 },
    placeholderText = { 0.70, 0.70, 0.74 },
}

local GOLD_RANGE_OPTIONS = {
    overall = { label = "Overall" },
    daily = { label = "Day", days = 1 },
    weekly = { label = "Week", days = 7 },
    monthly = { label = "Month", days = 30 },
    yearly = { label = "Year", days = 365 },
}

mQoL_AccountOverview.defaults = {
    settings = {
        selectedTab = "Characters",
        selectedGoldRange = "overall",
        favoriteCharacters = {},
    },
    characters = {},
    goldSession = {},
    overallArchive = {
        weekly = {},
        points = {},
        currentWeekKey = nil,
    },
    chartBuckets = {
        daily = {},
        weekly = {},
        monthly = {},
        yearly = {},
    },
    chartMeta = {
        daily = { currentKey = nil },
        weekly = { currentKey = nil },
        monthly = { currentKey = nil },
        yearly = { currentKey = nil },
    },
    accountBank = {
        money = 0,
        lastSeen = 0,
    },
    meta = {
        schemaVersion = 10, -- remember to remove this in release build its only dev db menagement
    },
}

mQoL_AccountOverview_DB = mQoL_AccountOverview_DB or {}

local function IsBootstrapMoneyWindow(session, now)
    return mQoL_Utils.IsBootstrapWindow(session, now, BOOTSTRAP_SYNC_INTERVAL, BOOTSTRAP_SYNC_ATTEMPTS, 5)
end

local GetProfessionSnapshot = ProfessionUtils.GetSnapshot
local MergeProfessionSnapshot = ProfessionUtils.MergeSnapshot
local HasProfessionData = ProfessionUtils.HasData
local GetProfessionDisplayEntries = ProfessionUtils.GetDisplayEntries
local GetProfessionSummaryText = ProfessionUtils.GetSummaryText
local GetProfessionDetailRows = ProfessionUtils.GetDetailRows
local NormalizeProfessionLabel = ProfessionUtils.NormalizeLabel

local function NormalizeWeeklyRewardSnapshot(rawValue)
    if WeeklyRewardUtils and type(WeeklyRewardUtils.NormalizeSnapshot) == "function" then
        return WeeklyRewardUtils.NormalizeSnapshot(rawValue)
    end

    return rawValue
end

local function CaptureCurrentWeeklyRewardSnapshot(rawValue, context)
    if WeeklyRewardUtils and type(WeeklyRewardUtils.CaptureCurrentSnapshot) == "function" then
        return WeeklyRewardUtils.CaptureCurrentSnapshot(rawValue, context)
    end

    return rawValue
end

local function CaptureChallengeCompletionInfo()
    if WeeklyRewardUtils and type(WeeklyRewardUtils.CaptureChallengeCompletionInfo) == "function" then
        return WeeklyRewardUtils.CaptureChallengeCompletionInfo()
    end

    return nil
end

local function GetRealtimeNow()
    if type(GetTime) == "function" then
        return tonumber(GetTime()) or 0
    end

    return tonumber(GetNow and GetNow()) or 0
end

local function ToPositiveInt(value)
    local numeric = tonumber(value)
    if not numeric or numeric <= 0 then
        return 0
    end

    return math.floor(numeric)
end

local function ResolveItemLevelFromLink(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return 0
    end

    if C_Item and type(C_Item.GetDetailedItemLevelInfo) == "function" then
        local ok, value = pcall(C_Item.GetDetailedItemLevelInfo, itemLink)
        if ok then
            local level = ToPositiveInt(value)
            if level > 0 then
                return level
            end
        end
    end

    if type(GetDetailedItemLevelInfo) == "function" then
        local ok, value = pcall(GetDetailedItemLevelInfo, itemLink)
        if ok then
            local level = ToPositiveInt(value)
            if level > 0 then
                return level
            end
        end
    end

    return 0
end

local function ExtractHighestItemLevelFromLootMessage(message)
    if type(message) ~= "string" or message == "" then
        return 0
    end

    local highest = 0
    for itemLink in message:gmatch("(|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r)") do
        local itemLevel = ResolveItemLevelFromLink(itemLink)
        if itemLevel > highest then
            highest = itemLevel
        end
    end

    if highest > 0 then
        return highest
    end

    for itemLink in message:gmatch("(|Hitem:[^|]+|h%[[^%]]+%]|h)") do
        local itemLevel = ResolveItemLevelFromLink(itemLink)
        if itemLevel > highest then
            highest = itemLevel
        end
    end

    return highest
end

function mQoL_AccountOverview:ArmLegionChallengeLootCapture(challengeCompletion)
    if not clientInfo.isLegion then return end

    local now = GetRealtimeNow()
    local state = {}

    state.startedAt = now
    state.expiresAt = now + LEGION_CHALLENGE_LOOT_CAPTURE_WINDOW
    state.updatedAt = now
    if type(challengeCompletion) == "table" then
        local level = ToPositiveInt(challengeCompletion.level)
        if level > 0 then
            state.challengeCompletion = {
                level = level,
                mapChallengeModeID = ToPositiveInt(challengeCompletion.mapChallengeModeID),
            }
        end
    end

    self.legionChallengeLootCapture = state
end

function mQoL_AccountOverview:TryCaptureLegionEndOfDungeonLoot(message)
    if not clientInfo.isLegion then
        return
    end

    local state = self.legionChallengeLootCapture
    if type(state) ~= "table" then
        return
    end

    local now = GetRealtimeNow()
    if (tonumber(state.expiresAt) or 0) <= now then
        self.legionChallengeLootCapture = nil
        return
    end

    local endOfDungeonItemLevel = ExtractHighestItemLevelFromLootMessage(message)
    if endOfDungeonItemLevel <= 0 then
        return
    end

    local knownBest = ToPositiveInt(state.endOfDungeonItemLevel)
    if knownBest > 0 and endOfDungeonItemLevel <= knownBest then
        return
    end

    local challengeCompletion = state.challengeCompletion or CaptureChallengeCompletionInfo()
    if type(challengeCompletion) ~= "table" or ToPositiveInt(challengeCompletion.level) <= 0 then
        state.endOfDungeonItemLevel = endOfDungeonItemLevel
        self.legionChallengeLootCapture = state
        return
    end

    state.endOfDungeonItemLevel = endOfDungeonItemLevel
    state.challengeCompletion = challengeCompletion
    self.legionChallengeLootCapture = nil

    self:UpdateCurrentCharacterSnapshot({
        refreshWeeklyReward = true,
        weeklyRewardContext = {
            challengeCompletion = challengeCompletion,
            endOfDungeonItemLevel = endOfDungeonItemLevel,
        },
    })
end

local function GetWeeklyRewardDisplayState(rawValue)
    if WeeklyRewardUtils and type(WeeklyRewardUtils.GetDisplayState) == "function" then
        return WeeklyRewardUtils.GetDisplayState(rawValue)
    end

    return {
        title = "Weekly Reward",
        summaryText = DEFAULT_VAULT_PROGRESS_TEXT,
        icon = VAULT_PLACEHOLDER_ICON,
        lines = {},
        snapshot = rawValue,
    }
end

local function NotifyWeeklyRewardViewFailure(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    if UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
        UIErrorsFrame:AddMessage(message, 1, 0.2, 0.2)
        return
    end

    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[mQoL]|r %s", message))
    end
end

local function OpenWeeklyRewardSnapshotView(rawValue, characterData)
    local viewer = _G.mQoL_WeeklyRewardViewer
    if viewer and type(viewer.OpenSnapshot) == "function" then
        return viewer.OpenSnapshot(rawValue, characterData)
    end

    NotifyWeeklyRewardViewFailure("Weekly reward viewer module is not loaded.")
    return false
end

local function GetDefaultWeeklyRewardSummaryText()
    local display = GetWeeklyRewardDisplayState(nil)
    local summaryText = display and display.summaryText
    if type(summaryText) == "string" and summaryText ~= "" then
        return summaryText
    end

    return clientInfo.isRetail and DEFAULT_VAULT_PROGRESS_TEXT or DEFAULT_UNSUPPORTED_VAULT_TEXT
end

local function ClampPositiveInteger(value)
    local numeric = tonumber(value)
    if not numeric or numeric <= 0 then
        return 0
    end

    return math.floor(numeric)
end

local function ResolveMaxPlayerLevel()
    if type(GetMaxLevelForPlayerExpansion) == "function" then
        local maxLevel = ClampPositiveInteger(GetMaxLevelForPlayerExpansion())
        if maxLevel > 0 then
            return maxLevel
        end
    end

    if type(GetMaxPlayerLevel) == "function" then
        local maxLevel = ClampPositiveInteger(GetMaxPlayerLevel())
        if maxLevel > 0 then
            return maxLevel
        end
    end

    if type(GetMaxLevelForLatestExpansion) == "function" then
        local maxLevel = ClampPositiveInteger(GetMaxLevelForLatestExpansion())
        if maxLevel > 0 then
            return maxLevel
        end
    end

    if ClampPositiveInteger(MAX_PLAYER_LEVEL) > 0 then
        return ClampPositiveInteger(MAX_PLAYER_LEVEL)
    end

    if type(GetMaxLevelForExpansionLevel) == "function" then
        local expansionLevel = ClampPositiveInteger(type(GetServerExpansionLevel) == "function" and GetServerExpansionLevel() or nil)
        if expansionLevel <= 0 and type(GetAccountExpansionLevel) == "function" then
            expansionLevel = ClampPositiveInteger(GetAccountExpansionLevel())
        end

        if expansionLevel > 0 then
            local maxLevel = ClampPositiveInteger(GetMaxLevelForExpansionLevel(expansionLevel))
            if maxLevel > 0 then
                return maxLevel
            end
        end
    end

    if type(MAX_PLAYER_LEVEL_TABLE) == "table" then
        local expansionLevel = ClampPositiveInteger(type(GetServerExpansionLevel) == "function" and GetServerExpansionLevel() or nil)
        if expansionLevel <= 0 and type(GetAccountExpansionLevel) == "function" then
            expansionLevel = ClampPositiveInteger(GetAccountExpansionLevel())
        end

        local maxLevel = ClampPositiveInteger(MAX_PLAYER_LEVEL_TABLE[expansionLevel])
        if maxLevel > 0 then
            return maxLevel
        end

        for _, value in pairs(MAX_PLAYER_LEVEL_TABLE) do
            maxLevel = math.max(maxLevel, ClampPositiveInteger(value))
        end

        if maxLevel > 0 then
            return maxLevel
        end
    end

    return 0
end

local function IsCharacterAtMaxLevel(character)
    if not clientInfo.isRetail then
        return true
    end

    local characterLevel = ClampPositiveInteger(type(character) == "table" and character.level or nil)
    local maxLevel = ResolveMaxPlayerLevel()
    if maxLevel <= 0 then
        return false
    end

    return characterLevel >= maxLevel
end

local function SupportsRetailAccountBank()
    return clientInfo.isRetail
        and C_Bank
        and Enum
        and Enum.BankType
        and Enum.BankType.Account ~= nil
        and type(C_Bank.FetchDepositedMoney) == "function"
end

local function GetAccountDB()
    mQoL_AccountOverview_DB = mQoL_AccountOverview_DB or {}

    if type(mQoL_AccountOverview_DB.Account) ~= "table" then
        mQoL_AccountOverview_DB.Account = DeepCopy(mQoL_AccountOverview.defaults)
    end

    local accountDB = mQoL_AccountOverview_DB.Account
    accountDB.settings = accountDB.settings or DeepCopy(mQoL_AccountOverview.defaults.settings)
    if type(accountDB.settings.favoriteCharacters) ~= "table" then
        accountDB.settings.favoriteCharacters = {}
    end
    accountDB.characters = accountDB.characters or {}
    if type(accountDB.goldSession) ~= "table" then
        if type(accountDB.goldHistory) == "table" then
            accountDB.goldSession = accountDB.goldHistory
        else
            accountDB.goldSession = {}
        end
    end
    accountDB.overallArchive = accountDB.overallArchive or DeepCopy(mQoL_AccountOverview.defaults.overallArchive)
    accountDB.chartBuckets = accountDB.chartBuckets or DeepCopy(mQoL_AccountOverview.defaults.chartBuckets)
    accountDB.chartMeta = accountDB.chartMeta or DeepCopy(mQoL_AccountOverview.defaults.chartMeta)
    accountDB.accountBank = accountDB.accountBank or DeepCopy(mQoL_AccountOverview.defaults.accountBank)
    accountDB.meta = accountDB.meta or DeepCopy(mQoL_AccountOverview.defaults.meta)

    local schemaVersion = tonumber(accountDB.meta.schemaVersion) or 0
    if schemaVersion < 3 then
        accountDB.settings.selectedGoldRange = "overall"
    end

    if schemaVersion < 5 then
        accountDB.overallArchive = DeepCopy(mQoL_AccountOverview.defaults.overallArchive)
    end

    if type(accountDB.overallArchive.weekly) ~= "table" then
        accountDB.overallArchive.weekly = {}
    end
    if type(accountDB.overallArchive.points) ~= "table" then
        accountDB.overallArchive.points = {}
    end
    if type(accountDB.overallArchive.currentWeekKey) ~= "string" then
        accountDB.overallArchive.currentWeekKey = nil
    end

    accountDB.goldHistory = nil
    accountDB.meta.schemaVersion = 10

    if accountDB.settings.selectedTab ~= "Characters" and accountDB.settings.selectedTab ~= "Gold Chart" then
        accountDB.settings.selectedTab = "Characters"
    end

    if not GOLD_RANGE_OPTIONS[accountDB.settings.selectedGoldRange] then
        accountDB.settings.selectedGoldRange = "overall"
    end

    return accountDB
end

local function GetStartOfDay(timestamp)
    local info = date("*t", timestamp)
    info.hour = 0
    info.min = 0
    info.sec = 0
    info.isdst = nil
    return time(info)
end

local function ShiftDays(timestamp, days)
    local info = date("*t", timestamp)
    info.day = info.day + days
    info.isdst = nil
    return time(info)
end

local function GetStartOfWeek(timestamp)
    local info = date("*t", timestamp)
    local daysSinceMonday = (info.wday + 5) % 7
    info.day = info.day - daysSinceMonday
    info.hour = 0
    info.min = 0
    info.sec = 0
    info.isdst = nil
    return time(info)
end

local function GetStartOfMonth(timestamp)
    local info = date("*t", timestamp)
    info.day = 1
    info.hour = 0
    info.min = 0
    info.sec = 0
    info.isdst = nil
    return time(info)
end

local function AddMonths(timestamp, offset)
    local info = date("*t", timestamp)
    info.day = 1
    info.hour = 0
    info.min = 0
    info.sec = 0
    info.month = info.month + offset
    info.isdst = nil
    return time(info)
end

local function GetLongTermArchiveKey(timestamp)
    return date("%d.%m.%Y", GetStartOfWeek(timestamp))
end

local function ParseLongTermArchiveKey(key)
    if type(key) ~= "string" then
        return nil
    end

    local day, month, year = key:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)$")
    if not day or not month or not year then
        return nil
    end

    return time({
        day = tonumber(day),
        month = tonumber(month),
        year = tonumber(year),
        hour = 0,
        min = 0,
        sec = 0,
        isdst = nil,
    })
end

local function AppendUniqueTimestamp(list, timestamp)
    if type(timestamp) ~= "number" then
        return
    end

    timestamp = math.floor(timestamp)
    if #list == 0 or list[#list] < timestamp then
        list[#list + 1] = timestamp
    end
end

local function GetDailyBucketKey(timestamp)
    local info = date("*t", timestamp)
    info.min = 0
    info.sec = 0
    info.hour = math.floor(info.hour / 2) * 2
    info.isdst = nil
    return time(info)
end

local function AddHours(timestamp, hours)
    local info = date("*t", timestamp)
    info.min = 0
    info.sec = 0
    info.hour = info.hour + hours
    info.isdst = nil
    return time(info)
end

local function GetRangeBucketKey(rangeKey, timestamp)
    if rangeKey == "daily" then
        return GetDailyBucketKey(timestamp)
    end
    if rangeKey == "weekly" then
        return GetStartOfDay(timestamp)
    end
    if rangeKey == "monthly" then
        return GetStartOfWeek(timestamp)
    end
    if rangeKey == "yearly" then
        return GetStartOfMonth(timestamp)
    end
    return timestamp
end

local function AdvanceRangeBucketKey(rangeKey, bucketKey)
    if rangeKey == "daily" then
        return AddHours(bucketKey, 2)
    end
    if rangeKey == "weekly" then
        return ShiftDays(bucketKey, 1)
    end
    if rangeKey == "monthly" then
        return ShiftDays(bucketKey, 7)
    end
    if rangeKey == "yearly" then
        return AddMonths(bucketKey, 1)
    end
    return bucketKey
end

local function RetreatRangeBucketKey(rangeKey, bucketKey)
    if rangeKey == "daily" then
        return AddHours(bucketKey, -2)
    end
    if rangeKey == "weekly" then
        return ShiftDays(bucketKey, -1)
    end
    if rangeKey == "monthly" then
        return ShiftDays(bucketKey, -7)
    end
    if rangeKey == "yearly" then
        return AddMonths(bucketKey, -1)
    end
    return bucketKey
end

local function GetRangeWindowSize(rangeKey)
    if rangeKey == "daily" then
        return 12
    end
    if rangeKey == "weekly" then
        return 7
    end
    if rangeKey == "monthly" then
        return 12
    end
    if rangeKey == "yearly" then
        return 12
    end
    return 0
end

local function GetRangePruneLimit(rangeKey)
    if rangeKey == "daily" then
        return 12
    end
    if rangeKey == "weekly" then
        return 7
    end
    if rangeKey == "monthly" then
        return 12
    end
    if rangeKey == "yearly" then
        return 12
    end
    return 0
end

local function GetRangeBucketLabel(rangeKey, bucketKey, index, windowSize)
    if rangeKey == "daily" then
        local info = date("*t", bucketKey)
        local hour = info.hour
        if hour == 0 then
            return "24"
        end
        return tostring(hour)
    end
    if rangeKey == "weekly" then
        return date("%A", bucketKey)
    end
    if rangeKey == "monthly" then
        return date("%d.%m", bucketKey)
    end
    if rangeKey == "yearly" then
        return date("%b", bucketKey)
    end
    return date("%d %b", bucketKey)
end

local function NormalizeGoldSession(history)
    local cleaned = {}

    for _, entry in ipairs(history or {}) do
        if type(entry) == "table" then
            local timestamp = math.floor(tonumber(entry.ts) or 0)
            local goldData = NormalizeGoldSnapshotData(entry)
            if timestamp > 0 then
                cleaned[#cleaned + 1] = {
                    ts = timestamp,
                    WarboundGold = goldData.WarboundGold,
                    CharacterGold = goldData.CharacterGold,
                    OverallGold = goldData.OverallGold,
                    total = goldData.OverallGold,
                }
            end
        end
    end

    table.sort(cleaned, function(a, b)
        return a.ts < b.ts
    end)

    return cleaned
end

local function DownsampleHistory(history, maxPoints)
    if #history <= maxPoints then
        return history
    end

    local sampled = {}
    local lastIndex = #history
    local step = (lastIndex - 1) / (maxPoints - 1)
    local previousIndex = 1

    sampled[1] = history[1]

    for i = 2, maxPoints - 1 do
        local rawIndex = math.floor(((i - 1) * step) + 1.5)
        local index = math.max(previousIndex + 1, math.min(lastIndex - 1, rawIndex))
        sampled[#sampled + 1] = history[index]
        previousIndex = index
    end

    sampled[#sampled + 1] = history[lastIndex]
    return sampled
end

local function NormalizeTimeSeriesEntries(entries)
    local normalized = {}

    for _, entry in ipairs(entries or {}) do
        local timestamp = math.floor(tonumber(entry and entry.ts) or 0)
        if timestamp > 0 then
            normalized[#normalized + 1] = {
                ts = timestamp,
                total = math.floor(tonumber(entry.total) or 0),
            }
        end
    end

    table.sort(normalized, function(a, b)
        return a.ts < b.ts
    end)

    local deduped = {}
    for _, entry in ipairs(normalized) do
        local lastEntry = deduped[#deduped]
        if lastEntry and lastEntry.ts == entry.ts then
            lastEntry.total = entry.total
        else
            deduped[#deduped + 1] = entry
        end
    end

    return deduped
end

local function AddOverallCheckpoint(checkpointsByTimestamp, timestamp, total, priority)
    timestamp = math.floor(tonumber(timestamp) or 0)
    if timestamp <= 0 then
        return
    end

    total = math.floor(tonumber(total) or 0)
    priority = tonumber(priority) or 0

    local existing = checkpointsByTimestamp[timestamp]
    if not existing or priority >= (existing.priority or 0) then
        checkpointsByTimestamp[timestamp] = {
            ts = timestamp,
            total = total,
            priority = priority,
        }
    end
end

local function GetEarliestObservedGoldTimestamp(accountDB)
    if type(accountDB) ~= "table" then
        return nil
    end

    local earliest

    local function Track(timestamp)
        timestamp = math.floor(tonumber(timestamp) or 0)
        if timestamp <= 0 then
            return
        end

        if not earliest or timestamp < earliest then
            earliest = timestamp
        end
    end

    for _, entry in ipairs(accountDB.goldSession or accountDB.goldHistory or {}) do
        Track(entry and entry.ts)
    end

    for _, character in pairs(accountDB.characters or {}) do
        Track(character and character.lastMoneySync)
        Track(character and character.lastSeen)
    end

    Track(accountDB.accountBank and accountDB.accountBank.lastSeen)
    return earliest
end

local function FormatOverallCheckpointLabel(timestamp, firstTimestamp, lastTimestamp)
    local spanDays = math.max(0, (tonumber(lastTimestamp) or 0) - (tonumber(firstTimestamp) or 0)) / SECONDS_PER_DAY
    if spanDays >= 365 then
        return date("%b %Y", timestamp)
    end
    if spanDays >= 1 then
        return date("%d %b", timestamp)
    end
    return date("%H:%M", timestamp)
end

local function ComputeRotationAngle(dx, dy)
    if math.atan2 then
        return math.atan2(dy, dx)
    end

    if dx == 0 then
        return dy >= 0 and (math.pi / 2) or (-math.pi / 2)
    end

    local angle = math.atan(dy / dx)
    if dx < 0 then
        angle = angle + math.pi
    end
    return angle
end

function mQoL_AccountOverview:InitializeDB()
    self.db = GetAccountDB()
    self.db.goldSession = NormalizeGoldSession(self.db.goldSession)
    self.currentCharacterKey = select(1, GetCurrentCharacterIdentity())
    self.session = self.session or {}
    self.session.loginAt = GetNow()
    self.session.bootstrapAttempts = 0
    self.session.moneyCharacterKey = self.currentCharacterKey
    self.session.hasReliableMoney = false
    self.session.lastReliableMoney = nil
    self:PruneGoldSession(GetNow())
    self:NormalizeAllCharacterWeeklyRewards()
end

function mQoL_AccountOverview:NormalizeAllCharacterWeeklyRewards()
    if not self.db or type(self.db.characters) ~= "table" then
        return
    end

    for _, character in pairs(self.db.characters) do
        if type(character) == "table" then
            character.weeklyReward = NormalizeWeeklyRewardSnapshot(character.weeklyReward)
        end
    end
end

function mQoL_AccountOverview:GetWarbandBankMoney()
    if not self.db or not self.db.accountBank then
        return 0
    end

    return math.floor(tonumber(self.db.accountBank.money) or 0)
end

function mQoL_AccountOverview:TryRefreshWarbandBankMoney(forceAllowCached)
    if not self.db or not SupportsRetailAccountBank() then
        return false
    end

    local canView = not C_Bank.CanViewBank or C_Bank.CanViewBank(Enum.BankType.Account)
    if not canView and not forceAllowCached then
        return false
    end

    local amount = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
    if type(amount) ~= "number" then
        return false
    end

    amount = math.max(0, math.floor(amount))
    local accountBank = self.db.accountBank or {}

    if canView or accountBank.lastSeen == nil or amount > 0 then
        accountBank.money = amount
        accountBank.lastSeen = GetNow()
        self.db.accountBank = accountBank
        return true
    end

    return false
end

function mQoL_AccountOverview:StopBootstrapSync()
    if self.bootstrapTicker then
        self.bootstrapTicker:Cancel()
        self.bootstrapTicker = nil
    end
end

function mQoL_AccountOverview:StartBootstrapSync()
    if not C_Timer or not C_Timer.NewTicker then
        return
    end

    self:StopBootstrapSync()
    self.session = self.session or {}
    self.session.loginAt = GetNow()
    self.session.bootstrapAttempts = 0

    self.bootstrapTicker = C_Timer.NewTicker(BOOTSTRAP_SYNC_INTERVAL, function(ticker)
        if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("AccountOverview") then
            ticker:Cancel()
            mQoL_AccountOverview.bootstrapTicker = nil
            return
        end

        mQoL_AccountOverview.session = mQoL_AccountOverview.session or {}
        mQoL_AccountOverview.session.bootstrapAttempts = (mQoL_AccountOverview.session.bootstrapAttempts or 0) + 1

        local attempt = mQoL_AccountOverview.session.bootstrapAttempts
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshStatic = true,
            refreshMoney = true,
            refreshProfessions = true,
            refreshWarbandBank = true,
            allowCachedWarbandBank = true,
            forceGoldSnapshot = false,
        })

        if attempt >= BOOTSTRAP_SYNC_ATTEMPTS then
            ticker:Cancel()
            mQoL_AccountOverview.bootstrapTicker = nil
        end
    end)
end

function mQoL_AccountOverview:GetCurrentCharacterRecord()
    if not self.db then
        self:InitializeDB()
    end

    local key = select(1, GetCurrentCharacterIdentity())
    self.currentCharacterKey = key
    return self.db.characters[key]
end

function mQoL_AccountOverview:GetCurrentCharacterMoney()
    local record = self:GetCurrentCharacterRecord()
    local storedMoney = record and math.floor(tonumber(record.money) or 0) or 0
    local liveMoney = GetMoney and math.floor(tonumber(GetMoney()) or 0) or 0
    local now = GetNow()
    local bootstrapWindowActive = IsBootstrapMoneyWindow(self.session, now)
    local hasReliableMoney = self.session
        and self.session.moneyCharacterKey == self.currentCharacterKey
        and self.session.hasReliableMoney
    local reliableMoney = hasReliableMoney and math.floor(tonumber(self.session.lastReliableMoney) or 0) or nil

    if liveMoney > 0 then
        return liveMoney
    end

    if reliableMoney ~= nil then
        return reliableMoney
    end

    if storedMoney > 0 and bootstrapWindowActive then
        return storedMoney
    end

    return liveMoney
end

function mQoL_AccountOverview:GetAccountTotalGold()
    if not self.db then
        return 0
    end

    local total = 0
    local currentKey = self.currentCharacterKey or select(1, GetCurrentCharacterIdentity())
    local currentMoney = self:GetCurrentCharacterMoney()

    for key, character in pairs(self.db.characters) do
        if key == currentKey then
            total = total + currentMoney
        else
            total = total + math.floor(tonumber(character.money) or 0)
        end
    end

    total = total + self:GetWarbandBankMoney()
    return total
end

function mQoL_AccountOverview:GetCharactersTotalGold()
    if not self.db then
        return 0
    end

    local total = 0
    local currentKey = self.currentCharacterKey or select(1, GetCurrentCharacterIdentity())
    local currentMoney = self:GetCurrentCharacterMoney()

    for key, character in pairs(self.db.characters) do
        if key == currentKey then
            total = total + currentMoney
        else
            total = total + math.floor(tonumber(character.money) or 0)
        end
    end

    return total
end

function mQoL_AccountOverview:GetGoldSnapshotData()
    local characterGold = self:GetCharactersTotalGold()
    local warboundGold = self:GetWarbandBankMoney()
    return BuildGoldSnapshotData(warboundGold, characterGold)
end

function mQoL_AccountOverview:AppendGoldSessionSnapshot(goldData, timestamp, forceSnapshot)
    if not self.db then
        return
    end

    local history = self.db.goldSession
    local lastEntry = history[#history]
    goldData = NormalizeGoldSnapshotData(goldData)
    local total = goldData.OverallGold
    timestamp = math.floor(tonumber(timestamp) or GetNow())

    if not lastEntry then
        history[#history + 1] = {
            ts = timestamp,
            WarboundGold = goldData.WarboundGold,
            CharacterGold = goldData.CharacterGold,
            OverallGold = goldData.OverallGold,
        }
        self:PruneGoldSession()
        return
    end

    local lastGoldData = NormalizeGoldSnapshotData(lastEntry)
    local shouldMerge = lastGoldData.OverallGold == total and math.abs(timestamp - (lastEntry.ts or 0)) < HISTORY_MERGE_WINDOW

    if shouldMerge then
        lastEntry.ts = timestamp
        lastEntry.WarboundGold = goldData.WarboundGold
        lastEntry.CharacterGold = goldData.CharacterGold
        lastEntry.OverallGold = goldData.OverallGold
    elseif forceSnapshot or timestamp - (lastEntry.ts or 0) >= HISTORY_MERGE_WINDOW or lastGoldData.OverallGold ~= total then
        history[#history + 1] = {
            ts = timestamp,
            WarboundGold = goldData.WarboundGold,
            CharacterGold = goldData.CharacterGold,
            OverallGold = goldData.OverallGold,
        }
    else
        lastEntry.ts = timestamp
        lastEntry.WarboundGold = goldData.WarboundGold
        lastEntry.CharacterGold = goldData.CharacterGold
        lastEntry.OverallGold = goldData.OverallGold
    end

    self:PruneGoldSession()
end

function mQoL_AccountOverview:PruneRangeStore(rangeKey)
    if not self.db or not self.db.chartBuckets then
        return
    end

    local store = self.db.chartBuckets[rangeKey]
    local limit = GetRangePruneLimit(rangeKey)
    if type(store) ~= "table" or not limit or limit <= 0 then
        return
    end

    local keys = {}
    for key in pairs(store) do
        keys[#keys + 1] = tonumber(key)
    end

    table.sort(keys)
    while #keys > limit do
        local oldest = table.remove(keys, 1)
        store[tostring(oldest)] = nil
    end
end

function mQoL_AccountOverview:FinalizeRangeBuckets(rangeKey, goldData, observedAt)
    if not self.db then
        return false
    end

    self.db.chartBuckets = self.db.chartBuckets or DeepCopy(mQoL_AccountOverview.defaults.chartBuckets)
    self.db.chartMeta = self.db.chartMeta or DeepCopy(mQoL_AccountOverview.defaults.chartMeta)
    goldData = NormalizeGoldSnapshotData(goldData)

    local store = self.db.chartBuckets[rangeKey]
    local meta = self.db.chartMeta[rangeKey]
    local currentBucketKey = GetRangeBucketKey(rangeKey, observedAt)
    local previousBucketKey = tonumber(meta.currentKey)

    if not previousBucketKey then
        meta.currentKey = currentBucketKey
        return false
    end

    if previousBucketKey == currentBucketKey then
        return false
    end

    local completedBucketKey = RetreatRangeBucketKey(rangeKey, currentBucketKey)
    meta.currentKey = currentBucketKey

    if completedBucketKey and completedBucketKey >= previousBucketKey then
        store[tostring(completedBucketKey)] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        self:PruneRangeStore(rangeKey)
        return true
    end

    return false
end

function mQoL_AccountOverview:ProcessChartBuckets(goldData, observedAt)
    if not self.db then
        return
    end

    local anyChanged = false
    for _, rangeKey in ipairs({ "daily", "weekly", "monthly", "yearly" }) do
        if self:FinalizeRangeBuckets(rangeKey, goldData, observedAt) then
            anyChanged = true
        end
    end

    if anyChanged then
        self:AppendGoldSessionSnapshot(goldData, observedAt, true)
    end
end

function mQoL_AccountOverview:ProcessOverallArchive(goldData, observedAt)
    if not self.db then
        return false
    end

    self.db.overallArchive = self.db.overallArchive or DeepCopy(mQoL_AccountOverview.defaults.overallArchive)
    goldData = NormalizeGoldSnapshotData(goldData)

    local archive = self.db.overallArchive
    archive.weekly = archive.weekly or {}
    archive.points = self:NormalizeOverallArchivePoints(archive.points or {})

    self:EnsureOverallArchivePoints(goldData.OverallGold, observedAt)

    local currentWeekStart = GetStartOfWeek(observedAt)
    local currentWeekKey = GetLongTermArchiveKey(currentWeekStart)
    local previousWeekKey = archive.currentWeekKey

    if type(previousWeekKey) ~= "string" or previousWeekKey == "" then
        archive.currentWeekKey = currentWeekKey
        return false
    end

    if previousWeekKey == currentWeekKey then
        return false
    end

    local previousWeekStart = ParseLongTermArchiveKey(previousWeekKey)
    if not previousWeekStart then
        archive.currentWeekKey = currentWeekKey
        return false
    end

    if previousWeekStart < currentWeekStart then
        local checkpointTime = currentWeekStart
        local observedKey = GetLongTermArchiveKey(checkpointTime)
        archive.weekly[observedKey] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        self:StoreOverallArchivePoint(checkpointTime, goldData.OverallGold)
    end

    archive.currentWeekKey = currentWeekKey
    return true
end

function mQoL_AccountOverview:PruneGoldSession(referenceTime)
    if not self.db then
        return
    end

    local history = NormalizeGoldSession(self.db.goldSession)
    local now = math.floor(tonumber(referenceTime) or GetNow())
    local currentBucketStart = GetDailyBucketKey(now)
    local filtered = {}

    for _, entry in ipairs(history) do
        if (tonumber(entry.ts) or 0) >= currentBucketStart then
            filtered[#filtered + 1] = entry
        end
    end

    history = filtered

    if #history <= HISTORY_MAX_POINTS then
        self.db.goldSession = history
        return
    end

    local recentCount = math.min(HISTORY_RECENT_POINTS, HISTORY_MAX_POINTS - 2)
    local olderKeep = HISTORY_MAX_POINTS - recentCount
    local splitIndex = math.max(1, #history - recentCount + 1)

    local older = {}
    for index = 1, splitIndex - 1 do
        older[#older + 1] = history[index]
    end

    local recent = {}
    for index = splitIndex, #history do
        recent[#recent + 1] = history[index]
    end

    if #older > olderKeep then
        older = DownsampleHistory(older, olderKeep)
    end

    local compacted = {}
    for _, entry in ipairs(older) do
        compacted[#compacted + 1] = entry
    end
    for _, entry in ipairs(recent) do
        compacted[#compacted + 1] = entry
    end

    self.db.goldSession = compacted
end

function mQoL_AccountOverview:RecordGoldSessionSnapshot(forceSnapshot, goldData)
    if not self.db then
        return
    end

    goldData = goldData or self:GetGoldSnapshotData()
    local now = GetNow()
    self:AppendGoldSessionSnapshot(goldData, now, forceSnapshot)
end

function mQoL_AccountOverview:UpdateCurrentCharacterSnapshot(opts)
    if not self.db then
        self:InitializeDB()
    end

    opts = opts or {}

    local key, name, realm = GetCurrentCharacterIdentity()
    self.currentCharacterKey = key

    local character = self.db.characters[key]
    if type(character) ~= "table" then
        character = {}
        self.db.characters[key] = character
    end

    local now = GetNow()

    if opts.refreshStatic or not character.classFile then
        local className, classFile = UnitClass("player")
        character.name = name
        character.realm = realm
        character.className = className or character.className or "Unknown"
        character.classFile = classFile or character.classFile or "PRIEST"
        character.level = UnitLevel("player") or character.level or 0
        character.faction = UnitFactionGroup("player") or character.faction or "Neutral"
        character.firstSeen = character.firstSeen or now
    end

    if opts.refreshMoney or character.money == nil then
        local fetchedMoney = GetMoney() or 0
        local existingMoney = math.floor(tonumber(character.money) or 0)
        local bootstrapWindowActive = IsBootstrapMoneyWindow(self.session, now)

        self.session = self.session or {}
        if self.session.moneyCharacterKey ~= key then
            self.session.moneyCharacterKey = key
            self.session.hasReliableMoney = false
            self.session.lastReliableMoney = nil
        end

        local hasReliableMoney = self.session.hasReliableMoney
        local reliableMoney = hasReliableMoney and math.floor(tonumber(self.session.lastReliableMoney) or 0) or nil
        local effectiveMoney = fetchedMoney
        local trustZeroMoney = opts.allowZeroMoney == true

        if fetchedMoney > 0 then
            self.session.hasReliableMoney = true
            self.session.lastReliableMoney = fetchedMoney
            hasReliableMoney = true
            reliableMoney = fetchedMoney
        elseif fetchedMoney == 0 then
            if trustZeroMoney then
                self.session.hasReliableMoney = true
                self.session.lastReliableMoney = 0
                hasReliableMoney = true
                reliableMoney = 0
            elseif reliableMoney ~= nil then
                effectiveMoney = reliableMoney
            elseif existingMoney > 0 then
                effectiveMoney = existingMoney
            end
        end

        if opts.forceLogoutMoney and fetchedMoney == 0 then
            if reliableMoney ~= nil then
                effectiveMoney = reliableMoney
            elseif existingMoney > 0 then
                effectiveMoney = existingMoney
            end
        end

        character.money = math.floor(tonumber(effectiveMoney) or 0)
        character.lastMoneySync = now
    end

    if opts.refreshProfessions or character.professions == nil then
        local existingProfessions = character.professions
        local existingHasProfessionData = HasProfessionData(existingProfessions)
        local fetchedProfessions = GetProfessionSnapshot()
        local fetchedHasProfessionData = HasProfessionData(fetchedProfessions)
        local mergedProfessions = MergeProfessionSnapshot(existingProfessions, fetchedProfessions)
        local hasCompleteProfessionSnapshot = type(fetchedProfessions) == "table"
            and (fetchedProfessions.primaryComplete or fetchedProfessions.secondaryComplete)
        local keepExistingProfessions = existingHasProfessionData
            and not fetchedHasProfessionData
            and not opts.allowEmptyProfessionSnapshot

        if not keepExistingProfessions
            and (hasCompleteProfessionSnapshot or HasProfessionData(mergedProfessions) or not existingHasProfessionData) then
            character.professions = mergedProfessions
        end
    end

    if opts.refreshWeeklyReward or character.weeklyReward == nil then
        character.weeklyReward = CaptureCurrentWeeklyRewardSnapshot(character.weeklyReward, opts.weeklyRewardContext)
    else
        character.weeklyReward = NormalizeWeeklyRewardSnapshot(character.weeklyReward)
    end

    if opts.totalTime then
        character.totalTime = math.floor(opts.totalTime)
        character.lastPlayedSync = now
        self.session.playedBase = character.totalTime
        self.session.playedSyncTime = now
    end

    if opts.levelTime then
        character.levelTime = math.floor(opts.levelTime)
    end

    character.lastSeen = now

    if opts.refreshWarbandBank or opts.refreshMoney or opts.forceGoldSnapshot then
        self:TryRefreshWarbandBankMoney(opts.allowCachedWarbandBank)
    end

    local goldData = self:GetGoldSnapshotData()
    self:ProcessChartBuckets(goldData, now)
    self:ProcessOverallArchive(goldData, now)
    self:RecordGoldSessionSnapshot(opts.forceGoldSnapshot, goldData)
    self:RefreshPanelIfVisible()
end

function mQoL_AccountOverview:QueueOpenTradeSkillProfessionSync()
    if not C_TradeSkillUI and type(GetTradeSkillLine) ~= "function" and not GetProfessions then
        return
    end

    local now = GetTime and GetTime() or GetNow()
    if self.openTradeSkillProfessionSyncQueued then
        return
    end

    if self.lastOpenTradeSkillProfessionSync and (now - self.lastOpenTradeSkillProfessionSync) < 0.25 then
        return
    end

    self.openTradeSkillProfessionSyncQueued = true

    local attempts = 0

    local function IsTradeSkillSnapshotReady()
        if not C_TradeSkillUI then
            return true
        end

        if type(C_TradeSkillUI.IsTradeSkillReady) == "function" and not C_TradeSkillUI.IsTradeSkillReady() then
            return false
        end

        if type(C_TradeSkillUI.IsDataSourceChanging) == "function" and C_TradeSkillUI.IsDataSourceChanging() then
            return false
        end

        return true
    end

    local function Sync()
        attempts = attempts + 1

        if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("AccountOverview") then
            mQoL_AccountOverview.openTradeSkillProfessionSyncQueued = false
            return
        end

        if not IsTradeSkillSnapshotReady() then
            if attempts < 8 and C_Timer and C_Timer.After then
                C_Timer.After(0.25, Sync)
            else
                mQoL_AccountOverview.openTradeSkillProfessionSyncQueued = false
            end

            return
        end

        mQoL_AccountOverview.lastOpenTradeSkillProfessionSync = GetTime and GetTime() or GetNow()
        mQoL_AccountOverview.openTradeSkillProfessionSyncQueued = false
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshProfessions = true,
        })
    end

    Sync()
end

function mQoL_AccountOverview:GetKnownCharacters()
    if not self.db then
        return {}
    end

    local currentKey = select(1, GetCurrentCharacterIdentity())
    local favorites = self.db.settings and self.db.settings.favoriteCharacters or {}
    local characters = {}

    for key, data in pairs(self.db.characters) do
        if type(data) == "table" then
            data.weeklyReward = NormalizeWeeklyRewardSnapshot(data.weeklyReward)
            local row = DeepCopy(data)
            row.key = key
            row.isCurrent = key == currentKey
            row.isFavorite = favorites[tostring(key)] == true
            characters[#characters + 1] = row
        end
    end

    table.sort(characters, function(a, b)
        if a.isFavorite ~= b.isFavorite then
            return a.isFavorite
        end

        if a.isCurrent ~= b.isCurrent then
            return a.isCurrent
        end

        local aSeen = tonumber(a.lastSeen) or 0
        local bSeen = tonumber(b.lastSeen) or 0
        if aSeen ~= bSeen then
            return aSeen > bSeen
        end

        local aName = string.format("%s-%s", a.name or "", a.realm or "")
        local bName = string.format("%s-%s", b.name or "", b.realm or "")
        return aName < bName
    end)

    return characters
end

function mQoL_AccountOverview:IsCharacterFavorite(characterKey)
    if not self.db or not self.db.settings or not characterKey then
        return false
    end

    local favorites = self.db.settings.favoriteCharacters
    return type(favorites) == "table" and favorites[tostring(characterKey)] == true
end

function mQoL_AccountOverview:SetCharacterFavorite(characterKey, isFavorite)
    if not self.db or not characterKey then
        return
    end

    self.db.settings = self.db.settings or DeepCopy(mQoL_AccountOverview.defaults.settings)
    self.db.settings.favoriteCharacters = self.db.settings.favoriteCharacters or {}

    local favorites = self.db.settings.favoriteCharacters
    favorites[tostring(characterKey)] = isFavorite and true or nil

    self:RefreshCharactersView()
    if self.activeTab == "Characters" then
        self:SetActiveTab("Characters")
    end
end

function mQoL_AccountOverview:ToggleCharacterFavorite(characterKey)
    self:SetCharacterFavorite(characterKey, not self:IsCharacterFavorite(characterKey))
end

function mQoL_AccountOverview:GetDisplayedPlayedTime(character)
    if not character then
        return nil
    end

    local totalTime = tonumber(character.totalTime)
    if character.key == self.currentCharacterKey and self.session and self.session.playedBase and self.session.playedSyncTime then
        local elapsed = math.max(0, GetNow() - self.session.playedSyncTime)
        totalTime = math.max(totalTime or 0, self.session.playedBase + elapsed)
    end

    return totalTime
end

function mQoL_AccountOverview:RefreshPanelIfVisible()
    if self.optionsScrollFrame and self.optionsScrollFrame:IsShown() then
        self:RefreshOverviewPanel()
    end
end

function mQoL_AccountOverview:RequestCurrentPlayedTime(forceRequest)
    if not RequestTimePlayed then
        return
    end

    local currentRecord = self:GetCurrentCharacterRecord()
    local nowSeconds = GetNow()

    if not forceRequest and currentRecord and currentRecord.lastPlayedSync then
        if (nowSeconds - currentRecord.lastPlayedSync) < PLAYED_DATA_STALE_AFTER then
            return
        end
    end

    local nowUiTime = GetTime and GetTime() or 0
    if not forceRequest and self.lastPlayedRequestAt and (nowUiTime - self.lastPlayedRequestAt) < PLAYED_REQUEST_COOLDOWN then
        return
    end

    self.lastPlayedRequestAt = nowUiTime
    self.isTimePlayedPending = true
    RequestTimePlayed()
end

local function AcquireTexture(pool, index, parent, layer)
    local texture = pool[index]
    if not texture then
        texture = parent:CreateTexture(nil, layer or "ARTWORK")
        pool[index] = texture
    end
    texture:Show()
    return texture
end

local function AcquireLine(pool, index, parent, layer)
    local line = pool[index]
    if not line then
        if parent.CreateLine then
            line = parent:CreateLine(nil, layer or "ARTWORK")
        else
            line = parent:CreateTexture(nil, layer or "ARTWORK")
        end
        pool[index] = line
    end
    line:Show()
    return line
end

local function AcquireFontString(pool, index, parent, template)
    local fontString = pool[index]
    if not fontString then
        fontString = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
        pool[index] = fontString
    end
    fontString:Show()
    return fontString
end

local function HidePool(pool)
    for _, object in ipairs(pool or {}) do
        if object and object.Hide then
            object:Hide()
        end
    end
end

local function RoundChartCoordinate(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function PrepareChartGridTexture(texture, alpha)
    if texture.SetDrawLayer then
        texture:SetDrawLayer("BORDER")
    end
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(true)
    end
    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(0)
    end
    texture:SetColorTexture(1, 1, 1, alpha)
end

local function SetTextureColor(texture, color)
    if not texture or type(color) ~= "table" then
        return
    end

    texture:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function SetOverviewCellButtonIcon(texture, icon)
    if not texture then
        return
    end

    texture:SetTexCoord(0, 1, 0, 1)

    local iconValue = icon or VAULT_PLACEHOLDER_ICON
    if type(iconValue) ~= "table" then
        texture:SetTexture(iconValue)
        return
    end

    local atlas = iconValue.atlas
    if type(atlas) == "string" and texture.SetAtlas then
        texture:SetAtlas(atlas, false)
    else
        texture:SetTexture(iconValue.texture or iconValue.file or iconValue.path or VAULT_PLACEHOLDER_ICON)
    end

    local texCoords = iconValue.texCoords or iconValue.texCoord
    if type(texCoords) == "table" then
        texture:SetTexCoord(texCoords[1] or 0, texCoords[2] or 1, texCoords[3] or 0, texCoords[4] or 1)
    end
end

local function SetBorderColor(border, color)
    if not border or type(color) ~= "table" then
        return
    end

    if border.top then
        border.top:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
    if border.bottom then
        border.bottom:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
    if border.left then
        border.left:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
    if border.right then
        border.right:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function UpdateOverviewCellButtonVisual(button)
    if not button or not button.bg then
        return
    end

    if button.isActive then
        SetTextureColor(button.bg, ACCOUNT_OVERVIEW_STYLE.cellActiveBackground)
        SetBorderColor(button.border, ACCOUNT_OVERVIEW_STYLE.cellActiveBorder)
        if button.label then
            button.label:SetTextColor(1, 0.88, 0.35)
        end
    elseif button.isHovered then
        SetTextureColor(button.bg, ACCOUNT_OVERVIEW_STYLE.cellHoverBackground)
        SetBorderColor(button.border, ACCOUNT_OVERVIEW_STYLE.cellHoverBorder)
        if button.label then
            button.label:SetTextColor(1, 1, 1)
        end
    elseif button.isPlaceholder then
        SetTextureColor(button.bg, ACCOUNT_OVERVIEW_STYLE.placeholderBackground)
        SetBorderColor(button.border, ACCOUNT_OVERVIEW_STYLE.placeholderBorder)
        if button.label then
            button.label:SetTextColor(
                ACCOUNT_OVERVIEW_STYLE.placeholderText[1],
                ACCOUNT_OVERVIEW_STYLE.placeholderText[2],
                ACCOUNT_OVERVIEW_STYLE.placeholderText[3]
            )
        end
    else
        SetTextureColor(button.bg, ACCOUNT_OVERVIEW_STYLE.cellBackground)
        SetBorderColor(button.border, ACCOUNT_OVERVIEW_STYLE.cellBorder)
        if button.label then
            button.label:SetTextColor(0.9, 0.9, 0.9)
        end
    end
end

local function ApplyOverviewCellButtonLayout(button, showIcon)
    if not button or not button.label or not button.icon then
        return
    end

    button.label:ClearAllPoints()
    if showIcon then
        button.icon:Show()
        button.label:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        button.label:SetJustifyH("LEFT")
        return
    end

    button.icon:Hide()
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    button.label:SetJustifyH("CENTER")
end

local function CreateOverviewCellButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button.isHovered = false
    button.isActive = false
    button.isPlaceholder = false
    button:RegisterForClicks("LeftButtonUp")

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()

    if CreateFrameBorder then
        button.border = CreateFrameBorder(button, 1, ACCOUNT_OVERVIEW_STYLE.cellBorder)
    end

    button.topHighlight = button:CreateTexture(nil, "ARTWORK")
    button.topHighlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.topHighlight:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    button.topHighlight:SetHeight(1)
    button.topHighlight:SetColorTexture(1, 1, 1, 0.045)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(16, 16)
    button.icon:SetPoint("LEFT", button, "LEFT", 4, 0)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    button.label:SetJustifyH("LEFT")
    button.label:SetWordWrap(false)

    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateOverviewCellButtonVisual(self)
        if self.handleEnter then
            self:handleEnter()
        end
    end)

    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        UpdateOverviewCellButtonVisual(self)
        if self.handleLeave then
            self:handleLeave()
        end
    end)

    function button:SetActive(isActive)
        if not self:IsEnabled() then
            isActive = false
        end

        self.isActive = isActive and true or false
        UpdateOverviewCellButtonVisual(self)
    end

    function button:SetContent(icon, text)
        self:Enable()
        self.isHovered = false
        self.isActive = false
        self.isPlaceholder = false
        ApplyOverviewCellButtonLayout(self, true)
        SetOverviewCellButtonIcon(self.icon, icon)
        self.label:SetText(text or "")
        UpdateOverviewCellButtonVisual(self)
    end

    function button:SetPlaceholder(text)
        self:Disable()
        self.isHovered = false
        self.isActive = false
        self.isPlaceholder = true
        ApplyOverviewCellButtonLayout(self, false)
        self.label:SetText(text or "-")
        UpdateOverviewCellButtonVisual(self)
    end

    UpdateOverviewCellButtonVisual(button)
    return button
end

local function CreateTabButton(parent, text, width)
    local button = CreateCustomButton and CreateCustomButton(parent, text, width or 140, 28) or CreateFrame("Button", nil, parent)
    button:SetSize(width or 140, 28)
    button.isHovered = false

    if not button.bg then
        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints()
        button.bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    end

    if not button.text then
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.text:SetPoint("CENTER")
        button.text:SetText(text)
    else
        button.text:SetText(text)
    end

    local function UpdateVisualState(self)
        if self.isActive then
            self.bg:SetColorTexture(self.isHovered and 0.20 or 0.18, self.isHovered and 0.20 or 0.18, self.isHovered and 0.20 or 0.18, 1)
            self.text:SetTextColor(1, 0.82, 0)
        else
            self.bg:SetColorTexture(self.isHovered and 0.20 or 0.12, self.isHovered and 0.20 or 0.12, self.isHovered and 0.20 or 0.12, 1)
            self.text:SetTextColor(self.isHovered and 1 or 0.82, self.isHovered and 1 or 0.82, self.isHovered and 1 or 0.82)
        end
    end

    function button:SetActive(isActive)
        self.isActive = isActive
        UpdateVisualState(self)
    end

    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateVisualState(self)
    end)

    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        UpdateVisualState(self)
    end)

    button:SetActive(false)
    return button
end

local CHARACTER_COLUMNS = {
    { key = "level", label = "Level", x = 12, width = 40, justify = "CENTER" },
    { key = "name", label = "Name", x = 62, width = 125, justify = "LEFT", headerJustify = "LEFT" },
    { key = "professions", label = "Professions", x = 192, width = 336, justify = "CENTER" },
    { key = "vault", label = "Vault", x = 532, width = 115, justify = "LEFT" },
    { key = "played", label = "Played", x = 651, width = 61, justify = "LEFT", headerJustify = "LEFT" },
    { key = "gold", label = "Gold", x = 716, width = 51, justify = "LEFT", headerJustify = "LEFT" },
}

local CHARACTER_PROFESSION_BUTTON_COUNT = 3
local CHARACTER_PROFESSION_BUTTON_GAP = 6

local CHARACTER_COLUMN_BY_KEY = {}
for _, column in ipairs(CHARACTER_COLUMNS) do
    CHARACTER_COLUMN_BY_KEY[column.key] = column
end

local function UpdateFavoriteButtonVisual(button)
    if not button or not button.icon then
        return
    end

    if button.isFavorite then
        button.icon:SetVertexColor(1, 0.82, 0, button.isHovered and 1 or 0.92)
        if button.icon.SetDesaturated then
            button.icon:SetDesaturated(false)
        end
        return
    end

    button.icon:SetVertexColor(0.62, 0.62, 0.66, button.isHovered and 0.95 or 0.55)
    if button.icon.SetDesaturated then
        button.icon:SetDesaturated(true)
    end
end

local function CreateFavoriteButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(18, 22)
    button:RegisterForClicks("LeftButtonUp")
    button.isFavorite = false
    button.isHovered = false

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(14, 14)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")

    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        UpdateFavoriteButtonVisual(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.isFavorite and "Remove Favorite" or "Toggle Favorite", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        UpdateFavoriteButtonVisual(self)
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self)
        if self.characterKey then
            mQoL_AccountOverview:ToggleCharacterFavorite(self.characterKey)
        end
    end)

    function button:SetFavorite(characterKey, isFavorite)
        self.characterKey = characterKey
        self.isFavorite = isFavorite and true or false
        UpdateFavoriteButtonVisual(self)
    end

    UpdateFavoriteButtonVisual(button)
    return button
end

function mQoL_AccountOverview:HideProfessionDetailFrame()
    if not self.professionDetailFrame then
        return
    end

    self.openProfessionDetailKey = nil

    local frame = self.professionDetailFrame
    if frame.owner and frame.owner.SetActive then
        frame.owner:SetActive(false)
    end
    frame.ownerDetailKey = nil
    frame.owner = nil
    frame:Hide()
end

function mQoL_AccountOverview:GetProfessionDetailParent()
    if self.optionsScrollFrame and self.optionsScrollFrame.GetParent then
        local parent = self.optionsScrollFrame:GetParent()
        if parent then
            return parent
        end
    end

    return self.contentContainer or self.viewsHost or self.optionsScrollFrame or UIParent
end

function mQoL_AccountOverview:UpdateProfessionDetailFrameLayer(frame)
    if not frame then
        return
    end

    local parent = frame:GetParent()
    local parentLevel = (parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 0
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(parentLevel + 40)
end

function mQoL_AccountOverview:EnsureProfessionDetailFrame()
    if self.professionDetailFrame then
        local parent = self:GetProfessionDetailParent()
        if parent and self.professionDetailFrame:GetParent() ~= parent then
            self.professionDetailFrame:SetParent(parent)
        end

        self:UpdateProfessionDetailFrameLayer(self.professionDetailFrame)

        return self.professionDetailFrame
    end

    local frame = CreateFrame("Frame", "mQoL_AccountOverview_ProfessionDetailFrame", self:GetProfessionDetailParent())
    frame:SetSize(300, 314)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()
    self:UpdateProfessionDetailFrameLayer(frame)

    if UISpecialFrames then
        table.insert(UISpecialFrames, frame:GetName())
    end

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.98)

    if CreateFrameBorder then
        frame.border = CreateFrameBorder(frame, 1, { 0.25, 0.25, 0.25, 1 })
    end

    frame.titleBar = CreateFrame("Frame", nil, frame)
    frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.titleBar:SetHeight(32)
    frame.titleBar:EnableMouse(true)

    frame.titleBar.bg = frame.titleBar:CreateTexture(nil, "BACKGROUND")
    frame.titleBar.bg:SetAllPoints()
    frame.titleBar.bg:SetColorTexture(0.1, 0.1, 0.1, 1)

    frame.title = frame.titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("CENTER", frame.titleBar, "CENTER", 0, -1)
    frame.title:SetTextColor(1, 0.82, 0)
    frame.title:SetShadowColor(0, 0, 0, 0.8)
    frame.title:SetShadowOffset(1, -1)

    frame.closeButton = CreateFrame("Button", nil, frame.titleBar)
    frame.closeButton:SetSize(20, 20)
    frame.closeButton:SetPoint("RIGHT", frame.titleBar, "RIGHT", -10, 0)
    frame.closeButton.tex = frame.closeButton:CreateTexture(nil, "ARTWORK")
    frame.closeButton.tex:SetAllPoints()
    frame.closeButton.tex:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Cross")
    frame.closeButton.tex:SetVertexColor(0.6, 0.6, 0.6)
    frame.closeButton:SetScript("OnEnter", function(self)
        self.tex:SetVertexColor(1, 0.2, 0.2)
    end)
    frame.closeButton:SetScript("OnLeave", function(self)
        self.tex:SetVertexColor(0.6, 0.6, 0.6)
    end)
    frame.closeButton:SetScript("OnClick", function()
        mQoL_AccountOverview:HideProfessionDetailFrame()
    end)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -44)
    frame.subtitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -44)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetTextColor(0.82, 0.82, 0.82)
    frame.subtitle:SetText("Detailed profession tiers")

    frame.separator = frame:CreateTexture(nil, "ARTWORK")
    frame.separator:SetColorTexture(1, 1, 1, 0.15)
    frame.separator:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -62)
    frame.separator:SetSize(276, 1)

    frame.headerLeft = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -78)
    frame.headerLeft:SetTextColor(0.9, 0.9, 0.9)
    frame.headerLeft:SetText("Expansion")

    frame.headerRight = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -78)
    frame.headerRight:SetTextColor(0.9, 0.9, 0.9)
    frame.headerRight:SetText("Skill")

    frame.rowsLeft = {}
    frame.rowsRight = {}
    frame.rowBackgrounds = {}
    frame.rowSeparators = {}

    frame:SetScript("OnMouseDown", function()
        GameTooltip:Hide()
    end)

    frame:SetScript("OnHide", function(self)
        GameTooltip:Hide()
        if self.owner and self.owner.SetActive then
            self.owner:SetActive(false)
        end
        mQoL_AccountOverview.openProfessionDetailKey = nil
        self.ownerDetailKey = nil
        self.owner = nil
        HidePool(self.rowsLeft)
        HidePool(self.rowsRight)
        HidePool(self.rowBackgrounds)
        HidePool(self.rowSeparators)
    end)

    self.professionDetailFrame = frame
    return frame
end

local function GetProfessionDetailKey(characterKey, professionEntry)
    local professionKey = NormalizeProfessionLabel and NormalizeProfessionLabel(professionEntry and professionEntry.name) or ""
    if professionKey == "" then
        return nil
    end

    return string.format("%s:%s", tostring(characterKey or ""), professionKey)
end

function mQoL_AccountOverview:PositionProfessionDetailFrame(frame)
    local parent = self:GetProfessionDetailParent()
    if parent and frame:GetParent() ~= parent then
        frame:SetParent(parent)
        self:UpdateProfessionDetailFrameLayer(frame)
    end

    frame:ClearAllPoints()

    parent = frame:GetParent()
    if not parent or parent == UIParent then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
end

function mQoL_AccountOverview:ShowProfessionDetailFrame(ownerButton, professionEntry)
    if not ownerButton or type(professionEntry) ~= "table" then
        return
    end

    local frame = self:EnsureProfessionDetailFrame()
    local detailKey = ownerButton.professionDetailKey or GetProfessionDetailKey(ownerButton.characterKey, professionEntry)
    if frame.owner and frame.owner ~= ownerButton and frame.owner.SetActive then
        frame.owner:SetActive(false)
    end

    frame.owner = ownerButton
    frame.ownerDetailKey = detailKey
    self.openProfessionDetailKey = detailKey
    ownerButton:SetActive(true)

    frame.title:SetText(professionEntry.name or "Profession")
    if professionEntry.isSecondarySummary then
        frame.subtitle:SetText("All secondary professions")
        frame.headerLeft:SetText("Profession")
        frame.headerRight:SetText("Skill")
    else
        frame.subtitle:SetText("Detailed profession tiers")
        frame.headerLeft:SetText("Expansion")
        frame.headerRight:SetText("Skill")
    end

    local detailRows = GetProfessionDetailRows(professionEntry)
    HidePool(frame.rowsLeft)
    HidePool(frame.rowsRight)
    HidePool(frame.rowBackgrounds)
    HidePool(frame.rowSeparators)

    local startY = -102
    local rowHeight = 20
    for index, rowData in ipairs(detailRows) do
        local rowOffset = startY - ((index - 1) * rowHeight)
        local rowBackground = AcquireTexture(frame.rowBackgrounds, index, frame, "BACKGROUND")
        rowBackground:ClearAllPoints()
        rowBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, rowOffset + 2)
        rowBackground:SetSize(276, rowHeight - 2)
        rowBackground:SetColorTexture(index % 2 == 1 and 0.08 or 0.10, index % 2 == 1 and 0.08 or 0.10, index % 2 == 1 and 0.08 or 0.10, 0.95)

        local rowSeparator = AcquireTexture(frame.rowSeparators, index, frame, "ARTWORK")
        rowSeparator:ClearAllPoints()
        rowSeparator:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, rowOffset + 1)
        rowSeparator:SetSize(268, 1)
        rowSeparator:SetColorTexture(1, 1, 1, 0.05)

        local left = AcquireFontString(frame.rowsLeft, index, frame, "GameFontNormalSmall")
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, rowOffset - 2)
        left:SetWidth(186)
        left:SetJustifyH("LEFT")
        left:SetText(rowData.label or "Unknown")
        left:SetTextColor(rowData.isActive and 0.92 or 0.62, rowData.isActive and 0.92 or 0.62, rowData.isActive and 0.92 or 0.62)

        local right = AcquireFontString(frame.rowsRight, index, frame, "GameFontNormalSmall")
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, rowOffset - 2)
        right:SetWidth(78)
        right:SetJustifyH("RIGHT")
        right:SetText(rowData.value or "-")
        right:SetTextColor(rowData.isActive and 1 or 0.58, rowData.isActive and 0.82 or 0.58, rowData.isActive and 0 or 0.58)
    end

    local frameHeight = math.max(164, 124 + (#detailRows * rowHeight))
    frame:SetHeight(frameHeight)
    self:PositionProfessionDetailFrame(frame)

    frame:Show()
end

function mQoL_AccountOverview:ToggleProfessionDetailFrame(ownerButton, professionEntry)
    if not ownerButton or type(professionEntry) ~= "table" then
        return
    end

    local frame = self:EnsureProfessionDetailFrame()
    local detailKey = ownerButton.professionDetailKey or GetProfessionDetailKey(ownerButton.characterKey, professionEntry)
    if frame:IsShown() and self.openProfessionDetailKey == detailKey then
        self:HideProfessionDetailFrame()
        return
    end

    self:ShowProfessionDetailFrame(ownerButton, professionEntry)
end

function mQoL_AccountOverview:EnsureCharactersView()
    if self.charactersView then
        return self.charactersView
    end

    local view = CreateFrame("Frame", nil, self.viewsHost)
    view:SetPoint("TOPLEFT", self.viewsHost, "TOPLEFT", 0, 0)
    view:SetWidth(770)
    view.rows = {}

    view.summaryText = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    view.summaryText:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0)
    view.summaryText:SetWidth(770)
    view.summaryText:SetWordWrap(false)
    view.summaryText:SetTextColor(1, 0.82, 0)

    view.header = CreateFrame("Frame", nil, view)
    view.header:SetSize(770, 26)
    view.header:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -22)

    view.header.bg = view.header:CreateTexture(nil, "BACKGROUND")
    view.header.bg:SetAllPoints()
    SetTextureColor(view.header.bg, ACCOUNT_OVERVIEW_STYLE.headerBackground)

    if CreateFrameBorder then
        view.header.border = CreateFrameBorder(view.header, 1, ACCOUNT_OVERVIEW_STYLE.headerBorder)
    end

    view.header.accent = view.header:CreateTexture(nil, "ARTWORK")
    view.header.accent:SetPoint("BOTTOMLEFT", view.header, "BOTTOMLEFT", 1, 1)
    view.header.accent:SetPoint("BOTTOMRIGHT", view.header, "BOTTOMRIGHT", -1, 1)
    view.header.accent:SetHeight(1)
    SetTextureColor(view.header.accent, ACCOUNT_OVERVIEW_STYLE.headerAccent)

    view.header.labels = {}
    for _, column in ipairs(CHARACTER_COLUMNS) do
        local label = view.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", view.header, "LEFT", column.x, 0)
        label:SetWidth(column.width)
        label:SetJustifyH(column.headerJustify or "CENTER")
        label:SetText(column.label)
        label:SetTextColor(
            ACCOUNT_OVERVIEW_STYLE.headerText[1],
            ACCOUNT_OVERVIEW_STYLE.headerText[2],
            ACCOUNT_OVERVIEW_STYLE.headerText[3]
        )
        view.header.labels[column.key] = label
    end

    view.emptyState = view:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    view.emptyState:SetPoint("TOPLEFT", view.header, "BOTTOMLEFT", 0, -20)
    view.emptyState:SetWidth(770)
    view.emptyState:SetJustifyH("CENTER")
    view.emptyState:SetText("No character data yet. It will populate automatically as you play on different characters.")
    view.emptyState:SetTextColor(0.85, 0.85, 0.85)
    view.emptyState:Hide()

    self.charactersView = view
    self.views.Characters = view
    return view
end

function mQoL_AccountOverview:EnsureCharacterRow(index)
    local view = self:EnsureCharactersView()
    local row = view.rows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, view)
    row:SetSize(770, 28)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.topHighlight = row:CreateTexture(nil, "ARTWORK")
    row.topHighlight:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.topHighlight:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.topHighlight:SetHeight(1)
    SetTextureColor(row.topHighlight, ACCOUNT_OVERVIEW_STYLE.rowHighlight)

    row.separator = row:CreateTexture(nil, "ARTWORK")
    row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.separator:SetHeight(1)
    SetTextureColor(row.separator, ACCOUNT_OVERVIEW_STYLE.rowSeparator)

    row.fonts = {}
    for _, column in ipairs(CHARACTER_COLUMNS) do
        local font = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        font:SetPoint("LEFT", row, "LEFT", column.x, 0)
        font:SetWidth(column.width)
        font:SetJustifyH(column.justify)
        font:SetWordWrap(false)
        row.fonts[column.key] = font
    end

    row.favoriteButton = CreateFavoriteButton(row)
    row.favoriteButton:SetPoint("LEFT", row, "LEFT", 0, 0)

    local professionColumn = CHARACTER_COLUMN_BY_KEY.professions
    row.professionsFrame = CreateFrame("Frame", nil, row)
    row.professionsFrame:SetPoint("LEFT", row, "LEFT", professionColumn.x, 0)
    row.professionsFrame:SetSize(professionColumn.width, 22)
    row.professionButtons = {}
    row.professionEmptyText = row.professionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.professionEmptyText:SetAllPoints()
    row.professionEmptyText:SetJustifyH("CENTER")
    row.professionEmptyText:SetText("-")
    row.professionEmptyText:SetTextColor(0.72, 0.72, 0.72)

    local vaultColumn = CHARACTER_COLUMN_BY_KEY.vault
    row.vaultFrame = CreateFrame("Frame", nil, row)
    row.vaultFrame:SetPoint("LEFT", row, "LEFT", vaultColumn.x, 0)
    row.vaultFrame:SetSize(vaultColumn.width, 22)

    row.vaultButton = CreateOverviewCellButton(row.vaultFrame)
    row.vaultButton:SetAllPoints()
    row.vaultButton:SetContent(VAULT_PLACEHOLDER_ICON, GetDefaultWeeklyRewardSummaryText())
    row.vaultButton.handleEnter = function(self)
        if not self:IsEnabled() or not self.weeklyRewardData then
            return
        end

        local display = GetWeeklyRewardDisplayState(self.weeklyRewardData)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(display.title or "Weekly Reward", 1, 0.82, 0)
        if clientInfo.isRetail then
            GameTooltip:AddLine("Click to View Vault Preview", 1, 1, 1)
        end
        for _, line in ipairs(display.lines or {}) do
            local color = line.color or { 0.85, 0.85, 0.85 }
            GameTooltip:AddLine(line.text or "", color[1] or 0.85, color[2] or 0.85, color[3] or 0.85, true)
        end
        GameTooltip:Show()
    end
    row.vaultButton.handleLeave = function()
        GameTooltip:Hide()
    end
    row.vaultButton:SetScript("OnClick", function(self)
        if not self:IsEnabled() or not self.weeklyRewardData then
            return
        end

        OpenWeeklyRewardSnapshotView(self.weeklyRewardData, self.weeklyRewardCharacter)
    end)

    view.rows[index] = row
    return row
end

function mQoL_AccountOverview:EnsureProfessionButton(row, index)
    row.professionButtons = row.professionButtons or {}
    local button = row.professionButtons[index]
    if button then
        return button
    end

    button = CreateOverviewCellButton(row.professionsFrame)
    button:SetSize(108, 22)
    button.handleEnter = function(self)
        if not self.professionEntry then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.professionEntry.name or "Profession", 1, 0.82, 0)
        if self.professionEntry.isSecondarySummary then
            GameTooltip:AddLine("Click to view all secondary professions.", 1, 1, 1)
            for _, entry in ipairs(self.professionEntry.secondaryProfessions or {}) do
                GameTooltip:AddLine(string.format("%s %s", entry.name or "Unknown", GetProfessionSummaryText(entry, true)), 1, 1, 1)
            end
        else
            GameTooltip:AddLine("Click to view detailed profession tiers.", 1, 1, 1)
            GameTooltip:AddLine(GetProfessionSummaryText(self.professionEntry, true), 1, 1, 1)
        end
        GameTooltip:Show()
    end
    button.handleLeave = function()
        GameTooltip:Hide()
    end
    button:SetScript("OnClick", function(self)
        if self.professionEntry then
            mQoL_AccountOverview:ToggleProfessionDetailFrame(self, self.professionEntry)
        end
    end)

    row.professionButtons[index] = button
    return button
end

function mQoL_AccountOverview:RefreshProfessionButtons(row, professions)
    local entries = GetProfessionDisplayEntries(professions) or {}
    local hasEntries = #entries > 0
    row.professionEmptyText:Hide()

    local visibleCount = CHARACTER_PROFESSION_BUTTON_COUNT
    local gap = CHARACTER_PROFESSION_BUTTON_GAP
    local totalGap = gap * math.max(0, visibleCount - 1)
    local buttonWidth = math.floor((row.professionsFrame:GetWidth() - totalGap) / visibleCount)
    local totalWidth = (buttonWidth * visibleCount) + totalGap
    local startOffset = math.floor((row.professionsFrame:GetWidth() - totalWidth) / 2)
    local matchedDetailOwner
    local matchedDetailEntry

    for index = 1, visibleCount do
        local button = self:EnsureProfessionButton(row, index)
        local professionEntry = hasEntries and entries[index] or nil
        if type(professionEntry) == "table" and professionEntry.isProfessionPlaceholder then
            professionEntry = nil
        end
        button:ClearAllPoints()
        button:SetPoint("LEFT", row.professionsFrame, "LEFT", startOffset + ((index - 1) * (buttonWidth + gap)), 0)
        button:SetSize(buttonWidth, 22)
        if professionEntry then
            local detailKey = GetProfessionDetailKey(row.characterKey, professionEntry)
            button.characterKey = row.characterKey
            button.professionDetailKey = detailKey
            button.professionEntry = professionEntry
            button:SetContent(professionEntry.icon or VAULT_PLACEHOLDER_ICON, GetProfessionSummaryText(professionEntry))
            button:SetActive(self.professionDetailFrame and self.professionDetailFrame:IsShown() and self.openProfessionDetailKey == detailKey)

            if self.openProfessionDetailKey and self.openProfessionDetailKey == detailKey then
                matchedDetailOwner = button
                matchedDetailEntry = professionEntry
            end
        else
            button.characterKey = nil
            button.professionDetailKey = nil
            button.professionEntry = nil
            button:SetPlaceholder("-")
        end

        button:Show()
    end

    for index = visibleCount + 1, #(row.professionButtons or {}) do
        local button = row.professionButtons[index]
        if button then
            button:Hide()
            button:SetActive(false)
            button.characterKey = nil
            button.professionDetailKey = nil
            button.professionEntry = nil
        end
    end

    return matchedDetailOwner, matchedDetailEntry
end

function mQoL_AccountOverview:RefreshCharactersView()
    local view = self:EnsureCharactersView()
    local characters = self:GetKnownCharacters()
    local charactersGold = self:GetCharactersTotalGold()
    local warbandBankGold = self:GetWarbandBankMoney()
    local totalGold = charactersGold + warbandBankGold
    local currentCharacter = self:GetCurrentCharacterRecord()
    local lastSeenText = currentCharacter and FormatTimestamp(currentCharacter.lastSeen) or "Unknown"

    if SupportsRetailAccountBank() then
        view.summaryText:SetText(string.format(
            "Known characters: %d    Characters: %s    Warband Bank: %s    Total tracked: %s    Last update: %s",
            #characters,
            FormatMoneyCompact(charactersGold),
            FormatMoneyCompact(warbandBankGold),
            FormatMoneyCompact(totalGold),
            lastSeenText
        ))
    else
        view.summaryText:SetText(string.format("Known characters: %d    Account gold: %s    Last update: %s", #characters, FormatMoneyCompact(totalGold), lastSeenText))
    end

    local detailWasOpen = self.professionDetailFrame and self.professionDetailFrame:IsShown() and self.openProfessionDetailKey ~= nil
    local detailOwner
    local detailEntry

    for _, row in ipairs(view.rows) do
        row:Hide()
    end

    if #characters == 0 then
        if detailWasOpen then
            self:HideProfessionDetailFrame()
        end

        view.emptyState:Show()
        view:SetHeight(150)
        view.contentHeight = 150
        return
    end

    view.emptyState:Hide()

    local startY = -50
    local rowHeight = 30

    for index, character in ipairs(characters) do
        local row = self:EnsureCharacterRow(index)
        row.characterKey = character.key
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, startY - ((index - 1) * rowHeight))
        SetTextureColor(row.bg, index % 2 == 1 and ACCOUNT_OVERVIEW_STYLE.rowOdd or ACCOUNT_OVERVIEW_STYLE.rowEven)

        local displayName = string.format("%s - %s", character.name or "Unknown", character.realm or "UnknownRealm")
        row.favoriteButton:SetFavorite(character.key, character.isFavorite)
        row.fonts.level:SetText(tostring(tonumber(character.level) or 0))
        row.fonts.level:SetTextColor(0.92, 0.92, 0.92)
        row.fonts.name:SetText(displayName)
        local classR, classG, classB = GetClassColor(character.classFile)
        row.fonts.name:SetTextColor(classR, classG, classB)

        row.fonts.professions:Hide()
        row.fonts.vault:Hide()
        local matchedDetailOwner, matchedDetailEntry = self:RefreshProfessionButtons(row, character.professions)
        if matchedDetailOwner then
            detailOwner = matchedDetailOwner
            detailEntry = matchedDetailEntry
        end

        if clientInfo.isRetail and not IsCharacterAtMaxLevel(character) then
            row.vaultButton.weeklyRewardData = nil
            row.vaultButton.weeklyRewardCharacter = nil
            row.vaultButton:SetPlaceholder("-")
        else
            local weeklyRewardDisplay = GetWeeklyRewardDisplayState(character.weeklyReward)
            row.vaultButton.weeklyRewardData = weeklyRewardDisplay.snapshot
            row.vaultButton.weeklyRewardCharacter = {
                key = character.key,
                name = character.name,
                realm = character.realm,
                className = character.className,
                classFile = character.classFile,
            }
            row.vaultButton:SetContent(weeklyRewardDisplay.icon or VAULT_PLACEHOLDER_ICON, weeklyRewardDisplay.summaryText or GetDefaultWeeklyRewardSummaryText())
            row.vaultButton.label:SetTextColor(0.88, 0.88, 0.88)
        end

        local playedText
        if character.isCurrent and self.isTimePlayedPending and not character.totalTime then
            playedText = "Syncing..."
        else
            playedText = FormatDuration(self:GetDisplayedPlayedTime(character))
        end
        row.fonts.played:SetText(playedText)
        row.fonts.played:SetTextColor(0.88, 0.88, 0.88)

        local rowGold = character.isCurrent and self:GetCurrentCharacterMoney() or math.floor(tonumber(character.money) or 0)
        row.fonts.gold:SetText(FormatMoneyCompact(rowGold))
        row.fonts.gold:SetTextColor(1, 0.82, 0)

        row:Show()
    end

    local totalHeight = math.abs(startY) + (#characters * rowHeight) + 20
    view:SetHeight(totalHeight)
    view.contentHeight = totalHeight

    if detailWasOpen then
        if detailOwner and detailEntry then
            self:ShowProfessionDetailFrame(detailOwner, detailEntry)
        else
            self:HideProfessionDetailFrame()
        end
    end
end

function mQoL_AccountOverview:GetSelectedGoldRange()
    local rangeKey = self.db and self.db.settings and self.db.settings.selectedGoldRange
    if not GOLD_RANGE_OPTIONS[rangeKey] then
        rangeKey = "overall"
    end
    return rangeKey
end

function mQoL_AccountOverview:GetStoredRangeValue(rangeKey, bucketKey)
    if not self.db or not self.db.chartBuckets then
        return nil
    end

    local store = self.db.chartBuckets[rangeKey]
    if type(store) ~= "table" then
        return nil
    end

    local value = store[tostring(bucketKey)]
    if value == nil then
        return nil
    end

    local goldData = NormalizeGoldSnapshotData(value)
    return goldData.OverallGold
end

function mQoL_AccountOverview:GetLastStoredRangeValueBefore(rangeKey, bucketKey)
    if not self.db or not self.db.chartBuckets then
        return nil
    end

    local store = self.db.chartBuckets[rangeKey]
    if type(store) ~= "table" then
        return nil
    end

    local latestKey
    local latestValue
    for rawKey, rawValue in pairs(store) do
        local numericKey = tonumber(rawKey)
        if numericKey and numericKey < bucketKey then
            if not latestKey or numericKey > latestKey then
                latestKey = numericKey
                latestValue = NormalizeGoldSnapshotData(rawValue).OverallGold
            end
        end
    end

    return latestValue
end

function mQoL_AccountOverview:GetVirtualGoldSession()
    local history = NormalizeGoldSession(self.db and self.db.goldSession or {})
    local now = GetNow()
    local totalGold = self:GetAccountTotalGold()

    if #history == 0 then
        return {
            { ts = now, total = totalGold }
        }, now
    end

    local virtual = {}
    for _, entry in ipairs(history) do
        virtual[#virtual + 1] = {
            ts = entry.ts,
            total = entry.total,
        }
    end

    local lastEntry = virtual[#virtual]
    if lastEntry.ts < now then
        virtual[#virtual + 1] = {
            ts = now,
            total = totalGold,
        }
    else
        lastEntry.total = totalGold
    end

    return virtual, now
end

function mQoL_AccountOverview:GetOverallArchiveEntries(currentTotal, now)
    if not self.db or not self.db.overallArchive or type(self.db.overallArchive.weekly) ~= "table" then
        return {}
    end

    local entries = {}
    for rawKey, rawValue in pairs(self.db.overallArchive.weekly) do
        local timestamp = ParseLongTermArchiveKey(rawKey)
        if timestamp then
            local goldData = NormalizeGoldSnapshotData(rawValue)
            entries[#entries + 1] = {
                ts = timestamp,
                WarboundGold = goldData.WarboundGold,
                CharacterGold = goldData.CharacterGold,
                OverallGold = goldData.OverallGold,
                total = goldData.OverallGold,
            }
        end
    end

    table.sort(entries, function(a, b)
        return a.ts < b.ts
    end)

    local currentWeekStart = GetStartOfWeek(now)
    if #entries == 0 or entries[#entries].ts < currentWeekStart then
        entries[#entries + 1] = {
            ts = currentWeekStart,
            total = currentTotal,
        }
    else
        entries[#entries].total = currentTotal
    end

    return entries
end

function mQoL_AccountOverview:NormalizeOverallArchivePoints(points)
    local normalized = NormalizeTimeSeriesEntries(points)
    local weeklyBuckets = {}
    local result = {}

    for _, entry in ipairs(normalized) do
        local weekStart = GetStartOfWeek(entry.ts)
        weeklyBuckets[weekStart] = {
            ts = weekStart,
            total = entry.total,
        }
    end

    for _, entry in pairs(weeklyBuckets) do
        result[#result + 1] = {
            ts = entry.ts,
            total = entry.total,
        }
    end

    table.sort(result, function(a, b)
        return a.ts < b.ts
    end)

    return result
end

function mQoL_AccountOverview:GetStoredOverallArchiveEntries()
    if not self.db or not self.db.overallArchive then
        return {}
    end

    local archive = self.db.overallArchive
    archive.points = self:NormalizeOverallArchivePoints(archive.points or {})

    local entries = {}
    for _, entry in ipairs(archive.points) do
        entries[#entries + 1] = {
            ts = entry.ts,
            total = entry.total,
        }
    end

    return entries
end

function mQoL_AccountOverview:GetStoredRangeEntries(rangeKey, rangeStart, rangeEnd)
    if not self.db or not self.db.chartBuckets then
        return {}
    end

    local store = self.db.chartBuckets[rangeKey]
    if type(store) ~= "table" then
        return {}
    end

    local entries = {}
    rangeStart = math.floor(tonumber(rangeStart) or 0)
    rangeEnd = math.floor(tonumber(rangeEnd) or 0)

    for rawKey, rawValue in pairs(store) do
        local timestamp = math.floor(tonumber(rawKey) or 0)
        if timestamp > 0 and timestamp >= rangeStart and (rangeEnd <= 0 or timestamp < rangeEnd) then
            local goldData = NormalizeGoldSnapshotData(rawValue)
            entries[#entries + 1] = {
                ts = timestamp,
                total = goldData.OverallGold,
            }
        end
    end

    table.sort(entries, function(a, b)
        return a.ts < b.ts
    end)

    return entries
end

function mQoL_AccountOverview:BuildBucketSeriesFromEntries(rangeKey, bucketKeys, sourceEntries, currentTotal, now)
    local entries = NormalizeTimeSeriesEntries(sourceEntries)
    local series = {}
    local carryValue
    local sourceIndex = 1
    local oldestBucketKey = bucketKeys[1]
    local windowSize = #bucketKeys

    while sourceIndex <= #entries and entries[sourceIndex].ts < oldestBucketKey do
        carryValue = entries[sourceIndex].total
        sourceIndex = sourceIndex + 1
    end

    if carryValue == nil then
        local firstWindowEntry = entries[sourceIndex]
        if firstWindowEntry and firstWindowEntry.ts < now then
            carryValue = firstWindowEntry.total
        end
    end

    if carryValue == nil then
        carryValue = currentTotal
    end

    for index, key in ipairs(bucketKeys) do
        local value
        if index == windowSize then
            value = currentTotal
        else
            while sourceIndex <= #entries and entries[sourceIndex].ts <= key do
                carryValue = entries[sourceIndex].total
                sourceIndex = sourceIndex + 1
            end
            value = carryValue
        end

        series[#series + 1] = {
            ts = index == windowSize and now or key,
            total = value,
            label = GetRangeBucketLabel(rangeKey, key, index, windowSize),
            bucketKey = key,
        }
    end

    return series, oldestBucketKey, now
end

function mQoL_AccountOverview:BuildOverallArchiveBootstrapEntries(currentTotal, now)
    local bootstrapEntries = NormalizeTimeSeriesEntries(self:BuildOverallCheckpointEntries(currentTotal, now))
    local currentWeekStart = GetStartOfWeek(now)
    local weeklyBuckets = {}

    for _, entry in ipairs(bootstrapEntries) do
        local weekStart = GetStartOfWeek(entry.ts)
        if weekStart < currentWeekStart then
            weeklyBuckets[weekStart] = {
                ts = weekStart,
                total = entry.total,
            }
        end
    end

    local result = {}
    for _, entry in pairs(weeklyBuckets) do
        result[#result + 1] = {
            ts = entry.ts,
            total = entry.total,
        }
    end

    table.sort(result, function(a, b)
        return a.ts < b.ts
    end)

    return result
end

function mQoL_AccountOverview:StoreOverallArchivePoint(timestamp, total)
    if not self.db then
        return
    end

    self.db.overallArchive = self.db.overallArchive or DeepCopy(mQoL_AccountOverview.defaults.overallArchive)
    local archive = self.db.overallArchive
    local points = self:GetStoredOverallArchiveEntries()

    points[#points + 1] = {
        ts = GetStartOfWeek(math.floor(tonumber(timestamp) or 0)),
        total = math.floor(tonumber(total) or 0),
    }

    archive.points = self:NormalizeOverallArchivePoints(points)
end

function mQoL_AccountOverview:EnsureOverallArchivePoints(currentTotal, now)
    if not self.db then
        return {}
    end

    self.db.overallArchive = self.db.overallArchive or DeepCopy(mQoL_AccountOverview.defaults.overallArchive)
    local archive = self.db.overallArchive
    archive.weekly = archive.weekly or {}
    archive.points = self:NormalizeOverallArchivePoints(archive.points or {})

    if #archive.points > 0 then
        return self:GetStoredOverallArchiveEntries()
    end

    archive.points = self:NormalizeOverallArchivePoints(self:BuildOverallArchiveBootstrapEntries(currentTotal, now))
    return self:GetStoredOverallArchiveEntries()
end

function mQoL_AccountOverview:GetRangeBucketEntries(rangeKey, minimumTimestamp)
    if not self.db or not self.db.chartBuckets then
        return {}
    end

    local store = self.db.chartBuckets[rangeKey]
    if type(store) ~= "table" then
        return {}
    end

    local entries = {}
    for rawKey, rawValue in pairs(store) do
        local sourceTimestamp = math.floor(tonumber(rawKey) or 0)
        if sourceTimestamp > 0 then
            local timestamp = sourceTimestamp
            if minimumTimestamp and timestamp < minimumTimestamp then
                timestamp = minimumTimestamp
            end
            local goldData = NormalizeGoldSnapshotData(rawValue)
            entries[#entries + 1] = {
                ts = timestamp,
                sourceTs = sourceTimestamp,
                total = goldData.OverallGold,
            }
        end
    end

    table.sort(entries, function(a, b)
        if a.ts ~= b.ts then
            return a.ts < b.ts
        end
        return (a.sourceTs or a.ts) < (b.sourceTs or b.ts)
    end)

    return entries
end

function mQoL_AccountOverview:BuildCharacterBootstrapOverallEntries()
    if not self.db or type(self.db.characters) ~= "table" then
        return {}
    end

    local snapshots = {}

    for key, character in pairs(self.db.characters) do
        local timestamp = math.floor(tonumber((character and character.lastMoneySync) or (character and character.lastSeen)) or 0)
        if timestamp > 0 then
            snapshots[#snapshots + 1] = {
                ts = timestamp,
                kind = "character",
                key = key,
                amount = math.floor(tonumber(character.money) or 0),
            }
        end
    end

    local accountBank = self.db.accountBank
    local bankTimestamp = math.floor(tonumber(accountBank and accountBank.lastSeen) or 0)
    if bankTimestamp > 0 then
        snapshots[#snapshots + 1] = {
            ts = bankTimestamp,
            kind = "bank",
            amount = math.floor(tonumber(accountBank.money) or 0),
        }
    end

    table.sort(snapshots, function(a, b)
        if a.ts ~= b.ts then
            return a.ts < b.ts
        end
        if a.kind ~= b.kind then
            return a.kind < b.kind
        end
        return (a.key or "") < (b.key or "")
    end)

    local entries = {}
    local knownCharacters = {}
    local runningCharactersTotal = 0
    local runningBankTotal = 0
    local index = 1

    while index <= #snapshots do
        local timestamp = snapshots[index].ts

        while index <= #snapshots and snapshots[index].ts == timestamp do
            local snapshot = snapshots[index]
            if snapshot.kind == "bank" then
                runningBankTotal = snapshot.amount
            else
                local previousAmount = knownCharacters[snapshot.key] or 0
                knownCharacters[snapshot.key] = snapshot.amount
                runningCharactersTotal = runningCharactersTotal - previousAmount + snapshot.amount
            end
            index = index + 1
        end

        entries[#entries + 1] = {
            ts = timestamp,
            total = runningCharactersTotal + runningBankTotal,
        }
    end

    return entries
end

function mQoL_AccountOverview:BuildOverallCheckpointEntries(currentTotal, now)
    local checkpointsByTimestamp = {}
    local history = NormalizeGoldSession(self.db and self.db.goldSession or {})
    local earliestObservedTimestamp = GetEarliestObservedGoldTimestamp(self.db)
    local hasOverallArchiveData = self.db
        and self.db.overallArchive
        and type(self.db.overallArchive.weekly) == "table"
        and next(self.db.overallArchive.weekly) ~= nil
    local archivedEntries = hasOverallArchiveData and self:GetOverallArchiveEntries(currentTotal, now) or {}
    local yearlyEntries = self:GetRangeBucketEntries("yearly", earliestObservedTimestamp)
    local monthlyEntries = self:GetRangeBucketEntries("monthly", earliestObservedTimestamp)
    local weeklyEntries = self:GetRangeBucketEntries("weekly", earliestObservedTimestamp)
    local dailyEntries = self:GetRangeBucketEntries("daily", earliestObservedTimestamp)
    local historyEntries = self:BuildThrottledOverallDisplaySeries(history, now)
    local hasFullSnapshots = #archivedEntries > 0
        or #yearlyEntries > 0
        or #monthlyEntries > 0
        or #weeklyEntries > 0
        or #dailyEntries > 0
        or #historyEntries > 0

    local function AppendEntries(entries, priority)
        for _, entry in ipairs(entries or {}) do
            AddOverallCheckpoint(checkpointsByTimestamp, entry.ts, entry.total, priority)
        end
    end

    if not hasFullSnapshots then
        AppendEntries(self:BuildCharacterBootstrapOverallEntries(), 10)
    end
    AppendEntries(archivedEntries, 20)
    AppendEntries(yearlyEntries, 30)
    AppendEntries(monthlyEntries, 40)
    AppendEntries(weeklyEntries, 50)
    AppendEntries(dailyEntries, 60)
    AppendEntries(historyEntries, 70)
    AddOverallCheckpoint(checkpointsByTimestamp, now, currentTotal, 100)

    local entries = {}
    for _, checkpoint in pairs(checkpointsByTimestamp) do
        entries[#entries + 1] = {
            ts = checkpoint.ts,
            total = checkpoint.total,
        }
    end

    table.sort(entries, function(a, b)
        return a.ts < b.ts
    end)

    return entries
end

function mQoL_AccountOverview:BuildOverallDisplayEntries(currentTotal, now)
    local checkpointsByTimestamp = {}
    local archiveEntries = self:EnsureOverallArchivePoints(currentTotal, now)
    local shouldSupplementArchive = #archiveEntries < (OVERALL_ARCHIVE_MAX_POINTS - 1)

    local function AppendEntries(entries, priority)
        for _, entry in ipairs(entries or {}) do
            AddOverallCheckpoint(checkpointsByTimestamp, entry.ts, entry.total, priority)
        end
    end

    AppendEntries(archiveEntries, 80)

    if shouldSupplementArchive then
        AppendEntries(self:BuildOverallCheckpointEntries(currentTotal, now), 40)
    end

    AddOverallCheckpoint(checkpointsByTimestamp, now, currentTotal, 100)

    local entries = {}
    for _, checkpoint in pairs(checkpointsByTimestamp) do
        entries[#entries + 1] = {
            ts = checkpoint.ts,
            total = checkpoint.total,
        }
    end

    table.sort(entries, function(a, b)
        return a.ts < b.ts
    end)

    return entries
end

function mQoL_AccountOverview:BuildDerivedOverallEntries(history, currentTotal, now)
    local currentWeekStart = GetStartOfWeek(now)
    local buckets = {}

    for _, entry in ipairs(history or {}) do
        local weekStart = GetStartOfWeek(entry.ts)
        if weekStart < currentWeekStart then
            local bucket = buckets[weekStart]
            if not bucket then
                bucket = {
                    ts = weekStart,
                    sum = 0,
                    count = 0,
                }
                buckets[weekStart] = bucket
            end

            bucket.sum = bucket.sum + math.floor(tonumber(entry.total) or 0)
            bucket.count = bucket.count + 1
        end
    end

    local entries = {}
    for _, bucket in pairs(buckets) do
        entries[#entries + 1] = {
            ts = bucket.ts,
            total = math.floor(bucket.sum / math.max(1, bucket.count)),
        }
    end

    table.sort(entries, function(a, b)
        return a.ts < b.ts
    end)

    entries[#entries + 1] = {
        ts = currentWeekStart,
        total = currentTotal,
    }

    return entries
end

function mQoL_AccountOverview:BuildCompressedOverallSeries(entries, currentTotal, now)
    local normalized = {}

    for _, entry in ipairs(entries or {}) do
        local timestamp = math.floor(tonumber(entry.ts) or 0)
        if timestamp > 0 then
            normalized[#normalized + 1] = {
                ts = timestamp,
                total = math.floor(tonumber(entry.total) or 0),
            }
        end
    end

    table.sort(normalized, function(a, b)
        return a.ts < b.ts
    end)

    local deduped = {}
    for _, entry in ipairs(normalized) do
        local lastEntry = deduped[#deduped]
        if lastEntry and lastEntry.ts == entry.ts then
            lastEntry.total = entry.total
        else
            deduped[#deduped + 1] = entry
        end
    end

    entries = deduped

    if #entries == 0 then
        return {
            { ts = now, total = currentTotal }
        }, now
    end

    local lastEntry = entries[#entries]
    if lastEntry.ts < now then
        entries[#entries + 1] = {
            ts = now,
            total = currentTotal,
        }
    else
        lastEntry.ts = now
        lastEntry.total = currentTotal
    end

    if #entries == 1 then
        local singleSeries = {
            { ts = entries[1].ts - (7 * SECONDS_PER_DAY), total = entries[1].total },
            { ts = now, total = currentTotal },
        }
        local firstTimestamp = singleSeries[1].ts
        local lastTimestamp = singleSeries[#singleSeries].ts
        for _, entry in ipairs(singleSeries) do
            entry.evenSpacing = true
            entry.label = FormatOverallCheckpointLabel(entry.ts, firstTimestamp, lastTimestamp)
        end
        return singleSeries, entries[1].ts
    end

    if #entries <= OVERALL_ARCHIVE_MAX_POINTS then
        local directSeries = {}
        for _, entry in ipairs(entries) do
            directSeries[#directSeries + 1] = {
                ts = entry.ts,
                total = entry.total,
                label = "",
                evenSpacing = true,
            }
        end
        local firstTimestamp = directSeries[1] and directSeries[1].ts or now
        local lastTimestamp = directSeries[#directSeries] and directSeries[#directSeries].ts or now
        for _, entry in ipairs(directSeries) do
            entry.label = FormatOverallCheckpointLabel(entry.ts, firstTimestamp, lastTimestamp)
        end
        return directSeries, entries[1].ts
    end

    local series = {}
    local selectedIndices = { 1 }
    local firstTimestamp = entries[1].ts
    local lastTimestamp = entries[#entries].ts
    local totalRange = math.max(1, lastTimestamp - firstTimestamp)
    local lastChosenIndex = 1

    for slot = 1, OVERALL_ARCHIVE_MAX_POINTS - 2 do
        local targetTimestamp = firstTimestamp + math.floor((totalRange * slot) / (OVERALL_ARCHIVE_MAX_POINTS - 1))
        local remainingSlots = (OVERALL_ARCHIVE_MAX_POINTS - 1) - slot
        local searchStart = lastChosenIndex + 1
        local searchEnd = math.max(searchStart, #entries - remainingSlots)
        local bestIndex = searchStart
        local bestDistance = math.huge

        for index = searchStart, searchEnd do
            local distance = math.abs(entries[index].ts - targetTimestamp)
            if distance < bestDistance then
                bestDistance = distance
                bestIndex = index
            end
        end

        if bestIndex > lastChosenIndex then
            selectedIndices[#selectedIndices + 1] = bestIndex
            lastChosenIndex = bestIndex
        end
    end

    if selectedIndices[#selectedIndices] ~= #entries then
        selectedIndices[#selectedIndices + 1] = #entries
    end

    for _, index in ipairs(selectedIndices) do
        local entry = entries[index]
        local lastSeriesEntry = series[#series]
        if not lastSeriesEntry or lastSeriesEntry.ts ~= entry.ts then
            series[#series + 1] = {
                ts = entry.ts,
                total = entry.total,
                label = "",
                evenSpacing = true,
            }
        else
            lastSeriesEntry.total = entry.total
        end
    end

    series[#series].ts = now
    series[#series].total = currentTotal

    local displayFirstTimestamp = series[1] and series[1].ts or now
    local displayLastTimestamp = series[#series] and series[#series].ts or now
    for _, entry in ipairs(series) do
        entry.label = FormatOverallCheckpointLabel(entry.ts, displayFirstTimestamp, displayLastTimestamp)
    end

    return series, entries[1].ts
end

function mQoL_AccountOverview:BuildThrottledOverallDisplaySeries(history, now)
    local interval = OVERALL_DISPLAY_MIN_INTERVAL
    local currentBucketIndex = math.floor(now / interval)
    local throttled = {}
    local activeBucketIndex
    local activeEntry

    for _, entry in ipairs(history or {}) do
        local bucketIndex = math.floor((tonumber(entry.ts) or 0) / interval)

        if activeBucketIndex == nil then
            activeBucketIndex = bucketIndex
            activeEntry = {
                ts = entry.ts,
                total = entry.total,
            }
        elseif bucketIndex == activeBucketIndex then
            activeEntry.ts = entry.ts
            activeEntry.total = entry.total
        else
            if activeBucketIndex < currentBucketIndex then
                throttled[#throttled + 1] = activeEntry
            end

            activeBucketIndex = bucketIndex
            activeEntry = {
                ts = entry.ts,
                total = entry.total,
            }
        end
    end

    if activeEntry and activeBucketIndex ~= nil and activeBucketIndex < currentBucketIndex then
        throttled[#throttled + 1] = activeEntry
    end

    if #throttled == 0 and #history > 0 then
        throttled[1] = {
            ts = history[#history].ts,
            total = history[#history].total,
        }
    end

    return throttled
end

function mQoL_AccountOverview:BuildGoldChartSeries(rangeKey)
    local now = GetNow()
    local currentTotal = self:GetAccountTotalGold()
    self:PruneGoldSession(now)
    local history = NormalizeGoldSession(self.db and self.db.goldSession or {})

    if #history == 0 then
        history = {
            { ts = now, total = currentTotal }
        }
    end

    if rangeKey == "overall" then
        local overallEntries = self:BuildOverallDisplayEntries(currentTotal, now)
        if #overallEntries == 0 then
            overallEntries = self:BuildDerivedOverallEntries(history, currentTotal, now)
        end

        if #overallEntries > 0 then
            return self:BuildCompressedOverallSeries(overallEntries, currentTotal, now)
        end

        return {
            { ts = now - SECONDS_PER_HOUR, total = currentTotal },
            { ts = now, total = currentTotal },
        }, now - SECONDS_PER_HOUR, now
    end

    local windowSize = GetRangeWindowSize(rangeKey)
    local currentBucketKey = GetRangeBucketKey(rangeKey, now)
    local oldestBucketKey = currentBucketKey

    for _ = 1, windowSize - 1 do
        oldestBucketKey = RetreatRangeBucketKey(rangeKey, oldestBucketKey)
    end

    local bucketKeys = {}
    local bucketKey = oldestBucketKey
    for _ = 1, windowSize do
        bucketKeys[#bucketKeys + 1] = bucketKey
        bucketKey = AdvanceRangeBucketKey(rangeKey, bucketKey)
    end

    if rangeKey == "monthly" then
        local storedMonthlyEntries = self:GetStoredRangeEntries(rangeKey, oldestBucketKey, currentBucketKey)
        local allStoredEntriesMatchCurrent = #storedMonthlyEntries > 0
        local archiveEntries = {}

        for _, entry in ipairs(storedMonthlyEntries) do
            if entry.total ~= currentTotal then
                allStoredEntriesMatchCurrent = false
                break
            end
        end

        local hasArchiveVariation = false
        for _, entry in ipairs(self:EnsureOverallArchivePoints(currentTotal, now)) do
            if entry.ts >= oldestBucketKey and entry.ts < now then
                archiveEntries[#archiveEntries + 1] = {
                    ts = entry.ts,
                    total = entry.total,
                }
                if entry.total ~= currentTotal then
                    hasArchiveVariation = true
                end
            end
        end

        if #storedMonthlyEntries < 2 or (allStoredEntriesMatchCurrent and hasArchiveVariation) then
            if #archiveEntries > 0 then
                return self:BuildBucketSeriesFromEntries(rangeKey, bucketKeys, archiveEntries, currentTotal, now)
            end
        end
    end

    return self:BuildBucketSeriesFromEntries(
        rangeKey,
        bucketKeys,
        self:GetStoredRangeEntries(rangeKey),
        currentTotal,
        now
    )
end

function mQoL_AccountOverview:SetGoldRange(rangeKey)
    if not GOLD_RANGE_OPTIONS[rangeKey] then
        return
    end

    if self.db and self.db.settings then
        self.db.settings.selectedGoldRange = rangeKey
    end

    if self.goldRangeButtons then
        for key, button in pairs(self.goldRangeButtons) do
            button:SetActive(key == rangeKey)
        end
    end

    self:RefreshGoldChartView()

    if self.activeTab == "Gold Chart" then
        self:SetActiveTab("Gold Chart")
    end
end

function mQoL_AccountOverview:EnsureGoldChartView()
    if self.goldChartView then
        return self.goldChartView
    end

    local view = CreateFrame("Frame", nil, self.viewsHost)
    view:SetPoint("TOPLEFT", self.viewsHost, "TOPLEFT", 0, 0)
    view:SetWidth(770)

    view.summaryText = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    view.summaryText:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0)
    view.summaryText:SetTextColor(1, 0.82, 0)

    view.rangeButtonsFrame = CreateFrame("Frame", nil, view)
    view.rangeButtonsFrame:SetPoint("TOPLEFT", view.summaryText, "BOTTOMLEFT", 0, -10)
    view.rangeButtonsFrame:SetSize(GOLD_CHART_WIDTH, 28)

    self.goldRangeButtons = self.goldRangeButtons or {}

    local previousButton
    for _, key in ipairs({ "overall", "daily", "weekly", "monthly", "yearly" }) do
        local option = GOLD_RANGE_OPTIONS[key]
        local button = CreateTabButton(view.rangeButtonsFrame, option.label, key == "overall" and 110 or 100)
        if previousButton then
            button:SetPoint("LEFT", previousButton, "RIGHT", 8, 0)
        else
            button:SetPoint("LEFT", view.rangeButtonsFrame, "LEFT", 0, 0)
        end
        button:SetScript("OnClick", function()
            mQoL_AccountOverview:SetGoldRange(key)
        end)
        self.goldRangeButtons[key] = button
        previousButton = button
    end

    view.statsText = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.statsText:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -408)
    view.statsText:SetWidth(GOLD_CHART_WIDTH)
    view.statsText:SetJustifyH("LEFT")
    view.statsText:SetTextColor(0.88, 0.88, 0.88)

    view.chart = CreateFrame("Frame", nil, view)
    view.chart:SetPoint("TOPLEFT", view.rangeButtonsFrame, "BOTTOMLEFT", 0, -12)
    view.chart:SetSize(GOLD_CHART_WIDTH, GOLD_CHART_HEIGHT)

    view.chart.bg = view.chart:CreateTexture(nil, "BACKGROUND")
    view.chart.bg:SetAllPoints()
    view.chart.bg:SetColorTexture(0.08, 0.08, 0.08, 0.96)

    if CreateFrameBorder then
        view.chart.border = CreateFrameBorder(view.chart, 1, { 0.22, 0.22, 0.22, 1 })
    end

    view.chart.plotLeft = 70
    view.chart.plotRight = 18
    view.chart.plotTop = GOLD_CHART_PLOT_TOP
    view.chart.plotBottom = GOLD_CHART_PLOT_BOTTOM
    view.chart.gridLines = {}
    view.chart.verticalLines = {}
    view.chart.yLabels = {}
    view.chart.xLabels = {}
    view.chart.segments = {}
    view.chart.points = {}

    view.chart.emptyText = view.chart:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    view.chart.emptyText:SetPoint("CENTER", view.chart, "CENTER", 0, 0)
    view.chart.emptyText:SetWidth(560)
    view.chart.emptyText:SetJustifyH("CENTER")
    view.chart.emptyText:SetTextColor(0.86, 0.86, 0.86)
    view.chart.emptyText:SetText("Not enough gold history yet. The chart starts filling automatically as you play.")

    self.goldChartView = view
    self.views["Gold Chart"] = view
    return view
end

function mQoL_AccountOverview:DrawGoldChart(samples)
    local view = self:EnsureGoldChartView()
    local chart = view.chart

    HidePool(chart.gridLines)
    HidePool(chart.verticalLines)
    HidePool(chart.yLabels)
    HidePool(chart.xLabels)
    HidePool(chart.segments)
    HidePool(chart.points)

    if #samples < 2 then
        chart.emptyText:Show()
        return
    end

    chart.emptyText:Hide()

    local chartWidth = tonumber(chart:GetWidth()) or GOLD_CHART_WIDTH
    local chartHeight = tonumber(chart:GetHeight()) or GOLD_CHART_HEIGHT
    if chartWidth <= (chart.plotLeft + chart.plotRight) then
        chartWidth = GOLD_CHART_WIDTH
    end
    if chartHeight <= (chart.plotTop + chart.plotBottom) then
        chartHeight = GOLD_CHART_HEIGHT
    end

    local plotWidth = math.max(1, RoundChartCoordinate(chartWidth - chart.plotLeft - chart.plotRight))
    local plotHeight = math.max(1, RoundChartCoordinate(chartHeight - chart.plotTop - chart.plotBottom))
    local firstTimestamp = samples[1].ts
    local lastTimestamp = samples[#samples].ts
    local timeRange = math.max(1, lastTimestamp - firstTimestamp)
    local minValue = samples[1].total
    local maxValue = samples[1].total

    for _, sample in ipairs(samples) do
        if sample.total < minValue then
            minValue = sample.total
        end
        if sample.total > maxValue then
            maxValue = sample.total
        end
    end

    if maxValue <= minValue then
        local padding = math.max(10000, maxValue * GOLD_CHART_FLAT_VALUE_PADDING_RATIO)
        minValue = math.max(0, minValue - padding)
        maxValue = maxValue + padding
    else
        local padding = math.max(1, (maxValue - minValue) * GOLD_CHART_VALUE_PADDING_RATIO)
        minValue = math.max(0, minValue - padding)
        maxValue = maxValue + padding
    end

    local valueRange = math.max(1, maxValue - minValue)
    local axisStep = valueRange / 4

    for index = 0, 4 do
        local y = RoundChartCoordinate(chart.plotBottom + (plotHeight * (index / 4)))
        local horizontal = AcquireTexture(chart.gridLines, index + 1, chart, "BORDER")
        horizontal:ClearAllPoints()
        PrepareChartGridTexture(horizontal, 0.08)
        horizontal:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", chart.plotLeft, y)
        horizontal:SetSize(plotWidth, 1)

        local yLabel = AcquireFontString(chart.yLabels, index + 1, chart, "GameFontNormalSmall")
        yLabel:ClearAllPoints()
        yLabel:SetPoint("RIGHT", chart, "BOTTOMLEFT", chart.plotLeft - 8, y)
        yLabel:SetJustifyH("RIGHT")
        yLabel:SetText(FormatAxisMoney(minValue + (valueRange * (index / 4)), axisStep))
        yLabel:SetTextColor(0.78, 0.78, 0.78)
    end

    local activeRange = self:GetSelectedGoldRange()
    local function FormatXAxisLabel(timestamp)
        if activeRange == "daily" then
            return date("%H:%M", timestamp)
        end
        if activeRange == "yearly" then
            return date("%b %Y", timestamp)
        end
        if activeRange == "overall" then
            local spanDays = timeRange / SECONDS_PER_DAY
            if spanDays >= 365 then
                return date("%b %Y", timestamp)
            elseif spanDays >= 30 then
                return date("%d %b", timestamp)
            elseif spanDays >= 1 then
                return date("%d %b", timestamp)
            end
            return date("%H:%M", timestamp)
        end
        return date("%d %b", timestamp)
    end

    local useBucketSpacing = samples[1] and (samples[1].evenSpacing or (activeRange ~= "overall" and samples[1].label))
    local sampleCount = #samples

    local function GetChartX(index, sample)
        if useBucketSpacing then
            if sampleCount <= 1 then
                return chart.plotLeft
            end
            return chart.plotLeft + (plotWidth * ((index - 1) / (sampleCount - 1)))
        end

        return chart.plotLeft + (((sample.ts - firstTimestamp) / timeRange) * plotWidth)
    end

    if useBucketSpacing then
        for index, sample in ipairs(samples) do
            local x = RoundChartCoordinate(GetChartX(index, sample))

            local vertical = AcquireTexture(chart.verticalLines, index, chart, "BORDER")
            vertical:ClearAllPoints()
            PrepareChartGridTexture(vertical, 0.05)
            vertical:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x, chart.plotBottom)
            vertical:SetSize(1, plotHeight)

            local xLabel = AcquireFontString(chart.xLabels, index, chart, "GameFontNormalSmall")
            xLabel:ClearAllPoints()
            xLabel:SetPoint("TOP", chart, "BOTTOMLEFT", x, 0)
            xLabel:SetText(sample.label or "")
            xLabel:SetTextColor(0.78, 0.78, 0.78)
        end
    else
        for index = 0, 4 do
            local x = RoundChartCoordinate(chart.plotLeft + (plotWidth * (index / 4)))
            local vertical = AcquireTexture(chart.verticalLines, index + 1, chart, "BORDER")
            vertical:ClearAllPoints()
            PrepareChartGridTexture(vertical, 0.05)
            vertical:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x, chart.plotBottom)
            vertical:SetSize(1, plotHeight)

            local xLabel = AcquireFontString(chart.xLabels, index + 1, chart, "GameFontNormalSmall")
            xLabel:ClearAllPoints()
            xLabel:SetPoint("TOP", chart, "BOTTOMLEFT", x, 0)
            xLabel:SetText(FormatXAxisLabel(firstTimestamp + (timeRange * (index / 4))))
            xLabel:SetTextColor(0.78, 0.78, 0.78)
        end
    end

    local previousX
    local previousY

    for index, sample in ipairs(samples) do
        local x = GetChartX(index, sample)
        local y = chart.plotBottom + (((sample.total - minValue) / valueRange) * plotHeight)

        local point = AcquireTexture(chart.points, index, chart, "OVERLAY")
        point:ClearAllPoints()
        point:SetColorTexture(1, 0.82, 0, index == #samples and 1 or 0.92)
        point:SetSize(index == #samples and 6 or 4, index == #samples and 6 or 4)
        point:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x - (point:GetWidth() / 2), y - (point:GetHeight() / 2))

        if previousX and previousY then
            local dx = x - previousX
            local dy = y - previousY
            local length = math.sqrt((dx * dx) + (dy * dy))

            local segment = AcquireLine(chart.segments, index - 1, chart, "ARTWORK")

            if chart.CreateLine then
                segment:SetColorTexture(1, 0.82, 0, 0.75)
                segment:SetThickness(2)
                segment:SetStartPoint("BOTTOMLEFT", previousX, previousY)
                segment:SetEndPoint("BOTTOMLEFT", x, y)
            else
                segment:ClearAllPoints()
                -- Fallback for legacy clients without CreateLine
                segment:SetTexture("Interface\\BUTTONS\\WHITE8X8")
                segment:SetVertexColor(1, 0.82, 0, 0.75)
                if segment.SetRotation then
                    segment:SetSize(length, 2)
                    segment:SetPoint("CENTER", chart, "BOTTOMLEFT", (previousX + x) / 2, (previousY + y) / 2)
                    segment:SetRotation(ComputeRotationAngle(dx, dy))
                else
                    segment:SetSize(2, math.max(2, math.abs(dy)))
                    segment:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", previousX, math.min(previousY, y))
                end
            end
        end

        previousX = x
        previousY = y
    end
end

function mQoL_AccountOverview:RefreshGoldChartView()
    local view = self:EnsureGoldChartView()
    local totalGold = self:GetAccountTotalGold()
    local rangeKey = self:GetSelectedGoldRange()
    local rangeData = GOLD_RANGE_OPTIONS[rangeKey] or GOLD_RANGE_OPTIONS.overall
    local series, rangeStart, now = self:BuildGoldChartSeries(rangeKey)
    local samples = DownsampleHistory(series, HISTORY_CHART_POINTS)
    local warbandBankGold = self:GetWarbandBankMoney()

    if SupportsRetailAccountBank() then
        view.summaryText:SetText(string.format(
            "%s gold trend. Current total: %s    Warband Bank: %s",
            rangeData.label,
            FormatMoneyCompact(totalGold),
            FormatMoneyCompact(warbandBankGold)
        ))
    else
        view.summaryText:SetText(string.format("%s gold trend. Current total: %s", rangeData.label, FormatMoneyCompact(totalGold)))
    end

    if self.goldRangeButtons then
        for key, button in pairs(self.goldRangeButtons) do
            button:SetActive(key == rangeKey)
        end
    end

    local firstValue = series[1].total
    local lastValue = series[#series].total
    local highest = series[1].total
    local lowest = series[1].total

    for _, entry in ipairs(series) do
        if entry.total > highest then
            highest = entry.total
        end
        if entry.total < lowest then
            lowest = entry.total
        end
    end

    local delta = lastValue - firstValue
    local deltaPrefix = delta >= 0 and "+" or ""

    view.statsText:SetText(string.format(
        "Range: %s to %s    Window change: %s%s    High: %s    Low: %s    Checkpoints: %d",
        date("%d %b %Y", rangeStart),
        date("%d %b %Y", now),
        deltaPrefix,
        FormatMoneyCompact(delta),
        FormatMoneyCompact(highest),
        FormatMoneyCompact(lowest),
        math.max(0, #series - 1)
    ))

    self:DrawGoldChart(samples)
    view:SetHeight(450)
    view.contentHeight = 450
end

function mQoL_AccountOverview:ResetGoldRangeForHubOpen()
    if not self.db then
        self:InitializeDB()
    end

    if self.db and self.db.settings then
        self.db.settings.selectedGoldRange = "overall"
    end

    if self.optionsScrollFrame and self.optionsScrollFrame:IsShown() then
        self:RefreshGoldChartView()
    end
end

function mQoL_AccountOverview:SetActiveTab(tabName)
    if not self.views or not self.views[tabName] then
        return
    end

    local previousTab = self.activeTab
    if previousTab ~= tabName or tabName ~= "Characters" then
        self:HideProfessionDetailFrame()
    end

    self.activeTab = tabName
    if self.db and self.db.settings then
        self.db.settings.selectedTab = tabName
    end

    for name, view in pairs(self.views) do
        view:SetShown(name == tabName)
    end

    for name, button in pairs(self.tabButtons or {}) do
        button:SetActive(name == tabName)
    end

    if tabName == "Characters" then
        self:RequestCurrentPlayedTime(false)
    end

    local activeView = self.views[tabName]
    local activeHeight = activeView.contentHeight or activeView:GetHeight() or 1
    local bottomPadding = 10
    self.viewsHost:SetHeight(activeHeight)
    self.contentContainer.currentY = self.viewsAnchorY - activeHeight - bottomPadding

    if self.panel and self.panel.UpdateScrollChildHeight then
        self.panel.UpdateScrollChildHeight()
    end
end

function mQoL_AccountOverview:RefreshOverviewPanel()
    if not self.optionsScrollFrame then
        return
    end

    self:RefreshCharactersView()
    self:RefreshGoldChartView()
    self:SetActiveTab(self.activeTab or (self.db and self.db.settings and self.db.settings.selectedTab) or "Characters")
end

function mQoL_AccountOverview:CreateOptionsPanel(parent)
    if self.optionsScrollFrame then
        self.optionsScrollFrame:SetParent(parent)
        self.optionsScrollFrame:ClearAllPoints()
        self.optionsScrollFrame:SetAllPoints()
        self:RefreshOverviewPanel()
        return self.optionsScrollFrame
    end

    if not self.db then
        self:InitializeDB()
    end

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Account Overview", nil, "TopSeparator")

    self.optionsScrollFrame = scrollFrame
    self.panel = panel
    self.contentContainer = contentContainer
    self.views = {}
    self.tabButtons = {}

    local tabsFrame = CreateFrame("Frame", nil, contentContainer)
    tabsFrame:SetPoint("TOPLEFT", contentContainer, "TOPLEFT", 20, contentContainer.currentY)
    tabsFrame:SetSize(770, 28)

    local charactersButton = CreateTabButton(tabsFrame, "Characters", 150)
    charactersButton:SetPoint("LEFT", tabsFrame, "LEFT", 0, 0)

    local goldButton = CreateTabButton(tabsFrame, "Gold Chart", 150)
    goldButton:SetPoint("LEFT", charactersButton, "RIGHT", 10, 0)

    self.tabButtons["Characters"] = charactersButton
    self.tabButtons["Gold Chart"] = goldButton
    contentContainer.optionsLabels["Characters"] = charactersButton.text
    contentContainer.optionsLabels["Gold Chart"] = goldButton.text

    local tabSeparatorY = contentContainer.currentY - 36
    local tabSeparator = contentContainer:CreateTexture(nil, "ARTWORK")
    tabSeparator:SetColorTexture(1, 1, 1, 0.15)
    tabSeparator:SetPoint("TOPLEFT", contentContainer, "TOPLEFT", 20, tabSeparatorY)
    tabSeparator:SetSize(770, 1)

    self.viewsAnchorY = tabSeparatorY - 18

    local viewsHost = CreateFrame("Frame", nil, contentContainer)
    viewsHost:SetPoint("TOPLEFT", contentContainer, "TOPLEFT", 20, self.viewsAnchorY)
    viewsHost:SetSize(770, 1)
    self.viewsHost = viewsHost

    self:EnsureCharactersView()
    self:EnsureGoldChartView()

    charactersButton:SetScript("OnClick", function()
        mQoL_AccountOverview:SetActiveTab("Characters")
    end)

    goldButton:SetScript("OnClick", function()
        mQoL_AccountOverview:SetActiveTab("Gold Chart")
    end)

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end

    scrollFrame:SetScript("OnShow", function()
        mQoL_AccountOverview:RefreshOverviewPanel()
    end)

    self:RefreshOverviewPanel()
    return scrollFrame
end

local function RegisterAccountOverviewPanel()
    if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
        mQoL_Hub:RegisterModuleOptions("mQoL_AccountOverview", "Account Overview", function(parent)
            return mQoL_AccountOverview:CreateOptionsPanel(parent)
        end)
    end
end

local eventFrame = CreateFrame("Frame")
local function RegisterAccountOverviewEvent(eventName)
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, eventName)
    return ok
end

RegisterAccountOverviewEvent("PLAYER_LOGIN")
RegisterAccountOverviewEvent("PLAYER_ENTERING_WORLD")
RegisterAccountOverviewEvent("PLAYER_MONEY")
RegisterAccountOverviewEvent("PLAYER_LEVEL_UP")
RegisterAccountOverviewEvent("SKILL_LINES_CHANGED")
RegisterAccountOverviewEvent("CHAT_MSG_SKILL")
RegisterAccountOverviewEvent("PLAYER_LOGOUT")
RegisterAccountOverviewEvent("TIME_PLAYED_MSG")
RegisterAccountOverviewEvent("BANKFRAME_OPENED")
RegisterAccountOverviewEvent("TRADE_SKILL_SHOW")
RegisterAccountOverviewEvent("TRADE_SKILL_LIST_UPDATE")
RegisterAccountOverviewEvent("TRADE_SKILL_DETAILS_UPDATE")
RegisterAccountOverviewEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
RegisterAccountOverviewEvent("TRADE_SKILL_UPDATE")
RegisterAccountOverviewEvent("CRAFT_SHOW")
RegisterAccountOverviewEvent("CRAFT_UPDATE")
RegisterAccountOverviewEvent("WEEKLY_REWARDS_UPDATE")
RegisterAccountOverviewEvent("WEEKLY_REWARDS_ITEM_CHANGED")
RegisterAccountOverviewEvent("CHALLENGE_MODE_COMPLETED")
RegisterAccountOverviewEvent("CHAT_MSG_LOOT")

local function QueueProfessionSyncFromProfessionsUI()
    mQoL_AccountOverview:QueueOpenTradeSkillProfessionSync()
end

if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
    EventRegistry:RegisterCallback("ProfessionsFrame.Show", QueueProfessionSyncFromProfessionsUI, mQoL_AccountOverview)
    EventRegistry:RegisterCallback("Professions.ProfessionSelected", QueueProfessionSyncFromProfessionsUI, mQoL_AccountOverview)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("AccountOverview") then
            return
        end

        mQoL_AccountOverview:InitializeDB()
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshStatic = true,
            refreshMoney = true,
            refreshProfessions = true,
            refreshWeeklyReward = true,
            refreshWarbandBank = true,
            allowCachedWarbandBank = true,
            forceGoldSnapshot = true,
        })
        mQoL_AccountOverview:StartBootstrapSync()
        RegisterAccountOverviewPanel()

        if C_Timer and C_Timer.After then
            C_Timer.After(2, function()
                if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("AccountOverview") then
                    return
                end

                mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
                    refreshStatic = true,
                    refreshMoney = true,
                    refreshProfessions = true,
                    refreshWeeklyReward = true,
                    refreshWarbandBank = true,
                    allowCachedWarbandBank = true,
                    forceGoldSnapshot = true,
                })
            end)
        end

        return
    end

    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("AccountOverview") then
        return
    end

    if not mQoL_AccountOverview.db then
        mQoL_AccountOverview:InitializeDB()
    end

    if event == "PLAYER_ENTERING_WORLD" then
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshStatic = true,
            refreshMoney = true,
            refreshProfessions = true,
            refreshWeeklyReward = true,
            refreshWarbandBank = true,
            allowCachedWarbandBank = true,
            forceGoldSnapshot = true,
        })
        mQoL_AccountOverview:StartBootstrapSync()
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("AccountOverview") then
                    return
                end

                mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
                    refreshStatic = true,
                    refreshMoney = true,
                    refreshProfessions = true,
                    refreshWeeklyReward = true,
                    refreshWarbandBank = true,
                    allowCachedWarbandBank = true,
                    forceGoldSnapshot = true,
                })
            end)
        end
    elseif event == "PLAYER_MONEY" then
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshMoney = true,
            refreshWarbandBank = true,
            allowZeroMoney = true,
        })
    elseif event == "PLAYER_LEVEL_UP" then
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshStatic = true,
            refreshMoney = true,
            refreshWarbandBank = true,
            forceGoldSnapshot = true,
        })
    elseif event == "SKILL_LINES_CHANGED" then
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshProfessions = true,
            allowEmptyProfessionSnapshot = true,
        })
    elseif event == "CHAT_MSG_SKILL" then
        mQoL_AccountOverview:QueueOpenTradeSkillProfessionSync()
    elseif event == "TIME_PLAYED_MSG" then
        local totalTime, levelTime = ...
        mQoL_AccountOverview.isTimePlayedPending = false
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshStatic = true,
            totalTime = totalTime,
            levelTime = levelTime,
        })
    elseif event == "BANKFRAME_OPENED" then
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshMoney = true,
            refreshWarbandBank = true,
            forceGoldSnapshot = true,
        })
    elseif event == "TRADE_SKILL_SHOW"
        or event == "TRADE_SKILL_LIST_UPDATE"
        or event == "TRADE_SKILL_DETAILS_UPDATE"
        or event == "TRADE_SKILL_DATA_SOURCE_CHANGED"
        or event == "TRADE_SKILL_UPDATE"
        or event == "CRAFT_SHOW"
        or event == "CRAFT_UPDATE" then
        mQoL_AccountOverview:QueueOpenTradeSkillProfessionSync()
    elseif event == "WEEKLY_REWARDS_UPDATE" or event == "WEEKLY_REWARDS_ITEM_CHANGED" then
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshWeeklyReward = true,
        })
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        local challengeCompletion = CaptureChallengeCompletionInfo()
        mQoL_AccountOverview:ArmLegionChallengeLootCapture(challengeCompletion)
        local captureState = mQoL_AccountOverview.legionChallengeLootCapture
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshWeeklyReward = true,
            weeklyRewardContext = {
                challengeCompletion = challengeCompletion,
                endOfDungeonItemLevel = type(captureState) == "table" and ToPositiveInt(captureState.endOfDungeonItemLevel) or 0,
            },
        })
    elseif event == "CHAT_MSG_LOOT" then
        local message = ...
        mQoL_AccountOverview:TryCaptureLegionEndOfDungeonLoot(message)
    elseif event == "PLAYER_LOGOUT" then
        mQoL_AccountOverview:StopBootstrapSync()
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshStatic = true,
            refreshMoney = true,
            forceLogoutMoney = true,
            refreshWeeklyReward = true,
            refreshWarbandBank = true,
            allowCachedWarbandBank = true,
            forceGoldSnapshot = true,
        })
    end
end)