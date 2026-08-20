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
local ClampPositiveInteger = mQoL_Utils.ClampPositiveInteger
local GetStartOfDay = mQoL_Utils.GetStartOfDay
local ShiftDays = mQoL_Utils.ShiftDays
local GetStartOfWeek = mQoL_Utils.GetStartOfWeek
local GetStartOfMonth = mQoL_Utils.GetStartOfMonth
local AddMonths = mQoL_Utils.AddMonths
local AddHours = mQoL_Utils.AddHours
local ResolveMaxPlayerLevel = mQoL_Utils.ResolveMaxPlayerLevel
local ProfessionUtils = mQoL_ProfessionUtils or _G.mQoL_ProfessionUtils
local WeeklyRewardUtils = mQoL_WeeklyRewardUtils or _G.mQoL_WeeklyRewardUtils
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

local CHARACTER_SORT_DEFAULT = { key = "lastcharacter", ascending = false }
local CHARACTER_SORT_FIELDS = {
    lastcharacter = true,
    name = true,
    level = true,
    vault = true,
    played = true,
    gold = true,
}
local CHARACTER_SORT_DEFAULT_ASCENDING = {
    lastcharacter = false,
    name = true,
    level = false,
    vault = false,
    played = false,
    gold = false,
}
local CHARACTER_SORT_UP_TEXTURE = "Interface\\AddOns\\mQoL\\Media\\Textures\\Up"
local CHARACTER_SORT_DOWN_TEXTURE = "Interface\\AddOns\\mQoL\\Media\\Textures\\Down"

mQoL_AccountOverview.defaults = {
    settings = {
        selectedTab = "Characters",
        selectedGoldRange = "overall",
        favoriteCharacters = {},
        characterSort = { key = CHARACTER_SORT_DEFAULT.key, ascending = CHARACTER_SORT_DEFAULT.ascending },
        playedTimeFilters = { groupBy = "CLASS", chartType = "BAR" },
    },
    characters = {},
    goldSession = {},
    overallArchive = {
        daily = {},
        points = {},
        currentDayKey = nil,
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
        schemaVersion = 11,
    },
}

mQoL_AccountOverview_DB = mQoL_AccountOverview_DB or {}

local function IsBootstrapMoneyWindow(session, now)
    return mQoL_Utils.IsBootstrapWindow(session, now, BOOTSTRAP_SYNC_INTERVAL, BOOTSTRAP_SYNC_ATTEMPTS, 5)
end

local GetProfessionSnapshot = ProfessionUtils and ProfessionUtils.GetSnapshot
local MergeProfessionSnapshot = ProfessionUtils and ProfessionUtils.MergeSnapshot
local HasProfessionData = ProfessionUtils and ProfessionUtils.HasData
local GetProfessionDisplayEntries = ProfessionUtils and ProfessionUtils.GetDisplayEntries
local GetProfessionSummaryText = ProfessionUtils and ProfessionUtils.GetSummaryText
local GetProfessionDetailRows = ProfessionUtils and ProfessionUtils.GetDetailRows
local NormalizeProfessionLabel = ProfessionUtils and ProfessionUtils.NormalizeLabel

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

local ToPositiveInt = ClampPositiveInteger

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
    if type(accountDB.settings.playedTimeFilters) ~= "table" then
        accountDB.settings.playedTimeFilters = {
            groupBy = "CLASS",
            chartType = "BAR",
        }
    else
        accountDB.settings.playedTimeFilters.groupBy = accountDB.settings.playedTimeFilters.groupBy or "CLASS"
        accountDB.settings.playedTimeFilters.chartType = accountDB.settings.playedTimeFilters.chartType or "BAR"
        accountDB.settings.playedTimeFilters.realm = nil
        accountDB.settings.playedTimeFilters.class = nil
        accountDB.settings.playedTimeFilters.spec = nil
    end
    if type(accountDB.settings.characterSort) ~= "table"
        or not CHARACTER_SORT_FIELDS[accountDB.settings.characterSort.key] then
        accountDB.settings.characterSort = {
            key = CHARACTER_SORT_DEFAULT.key,
            ascending = CHARACTER_SORT_DEFAULT.ascending,
        }
    else
        accountDB.settings.characterSort.ascending = accountDB.settings.characterSort.ascending == true
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

    -- Migrate weekly to daily archive schema (schemaVersion 11)
    if accountDB.overallArchive then
        if type(accountDB.overallArchive.weekly) == "table" then
            if type(accountDB.overallArchive.daily) ~= "table" then
                accountDB.overallArchive.daily = accountDB.overallArchive.weekly
            end
            accountDB.overallArchive.weekly = nil
        end
        if type(accountDB.overallArchive.currentWeekKey) == "string" then
            if type(accountDB.overallArchive.currentDayKey) ~= "string" then
                accountDB.overallArchive.currentDayKey = accountDB.overallArchive.currentWeekKey
            end
            accountDB.overallArchive.currentWeekKey = nil
        end
    end

    accountDB.overallArchive = accountDB.overallArchive or DeepCopy(mQoL_AccountOverview.defaults.overallArchive)
    if type(accountDB.overallArchive.daily) ~= "table" then
        accountDB.overallArchive.daily = {}
    end
    if type(accountDB.overallArchive.points) ~= "table" then
        accountDB.overallArchive.points = {}
    end
    if type(accountDB.overallArchive.currentDayKey) ~= "string" then
        accountDB.overallArchive.currentDayKey = nil
    end

    accountDB.goldHistory = nil
    accountDB.meta.schemaVersion = 11

    if accountDB.settings.selectedTab ~= "Characters" and accountDB.settings.selectedTab ~= "Gold Chart" and accountDB.settings.selectedTab ~= "Played Time" then
        accountDB.settings.selectedTab = "Characters"
    end

    if not GOLD_RANGE_OPTIONS[accountDB.settings.selectedGoldRange] then
        accountDB.settings.selectedGoldRange = "overall"
    end

    return accountDB
end

local function GetHalfDayIntervalStart(timestamp)
    local info = date("*t", timestamp)
    info.min = 0
    info.sec = 0
    if info.hour >= 12 then
        info.hour = 12
    else
        info.hour = 0
    end
    info.isdst = nil
    return time(info)
end

local function AdvanceHalfDayIntervalStart(timestamp)
    local info = date("*t", timestamp)
    if info.hour >= 12 then
        info.hour = 0
        info.day = info.day + 1
    else
        info.hour = 12
    end
    info.min = 0
    info.sec = 0
    info.isdst = nil
    return time(info)
end

local function GetLongTermArchiveKey(timestamp)
    local info = date("*t", timestamp)
    local suffix = info.hour >= 12 and "PM" or "AM"
    return date("%d.%m.%Y-", timestamp) .. suffix
end

local function ParseLongTermArchiveKey(key)
    if type(key) ~= "string" then
        return nil
    end

    local day, month, year, suffix = key:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)%-(%a%a)$")
    if not day or not month or not year or not suffix then
        day, month, year = key:match("^(%d%d)%.(%d%d)%.(%d%d%d%d)$")
        if not day or not month or not year then
            return nil
        end
        suffix = "AM"
    end

    local hour = (suffix == "PM") and 12 or 0
    return time({
        day = tonumber(day),
        month = tonumber(month),
        year = tonumber(year),
        hour = hour,
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
    -- Re-evaluate references in case they were loaded after this file
    ProfessionUtils = mQoL_ProfessionUtils or _G.mQoL_ProfessionUtils
    WeeklyRewardUtils = mQoL_WeeklyRewardUtils or _G.mQoL_WeeklyRewardUtils
    if ProfessionUtils then
        GetProfessionSnapshot = ProfessionUtils.GetSnapshot
        MergeProfessionSnapshot = ProfessionUtils.MergeSnapshot
        HasProfessionData = ProfessionUtils.HasData
        GetProfessionDisplayEntries = ProfessionUtils.GetDisplayEntries
        GetProfessionSummaryText = ProfessionUtils.GetSummaryText
        GetProfessionDetailRows = ProfessionUtils.GetDetailRows
        NormalizeProfessionLabel = ProfessionUtils.NormalizeLabel
    end

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

function mQoL_AccountOverview:StopPeriodicTracker()
    if self.periodicTicker then
        self.periodicTicker:Cancel()
        self.periodicTicker = nil
    end
end

function mQoL_AccountOverview:StartPeriodicTracker()
    if not C_Timer or not C_Timer.NewTicker then
        return
    end

    self:StopPeriodicTracker()

    self.periodicTicker = C_Timer.NewTicker(60, function()
        if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("AccountOverview") then
            if mQoL_AccountOverview.periodicTicker then
                mQoL_AccountOverview.periodicTicker:Cancel()
                mQoL_AccountOverview.periodicTicker = nil
            end
            return
        end

        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshMoney = true,
            refreshWarbandBank = true,
            allowCachedWarbandBank = true,
        })
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
        store[tostring(currentBucketKey)] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        return false
    end

    if previousBucketKey == currentBucketKey then
        store[tostring(currentBucketKey)] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        return false
    end

    if previousBucketKey > currentBucketKey then
        meta.currentKey = currentBucketKey
        store[tostring(currentBucketKey)] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        return false
    end

    local inheritVal = store[tostring(previousBucketKey)]
    if not inheritVal then
        local latestK
        for rawK, rawV in pairs(store) do
            local numK = tonumber(rawK)
            if numK and numK < previousBucketKey then
                if not latestK or numK > latestK then
                    latestK = numK
                    inheritVal = rawV
                end
            end
        end
    end
    if not inheritVal then
        inheritVal = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
    else
        inheritVal = NormalizeGoldSnapshotData(inheritVal)
    end

    local k = AdvanceRangeBucketKey(rangeKey, previousBucketKey)
    while k < currentBucketKey do
        store[tostring(k)] = BuildGoldSnapshotData(inheritVal.WarboundGold, inheritVal.CharacterGold)
        k = AdvanceRangeBucketKey(rangeKey, k)
    end

    store[tostring(currentBucketKey)] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
    meta.currentKey = currentBucketKey

    self:PruneRangeStore(rangeKey)
    return true
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
    archive.daily = archive.daily or {}
    archive.points = self:NormalizeOverallArchivePoints(archive.points or {})

    self:EnsureOverallArchivePoints(goldData.OverallGold, observedAt)

    local currentIntervalStart = GetHalfDayIntervalStart(observedAt)
    local currentDayKey = GetLongTermArchiveKey(currentIntervalStart)
    local previousDayKey = archive.currentDayKey

    if type(previousDayKey) ~= "string" or previousDayKey == "" then
        archive.currentDayKey = currentDayKey
        archive.daily[currentDayKey] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        self:StoreOverallArchivePoint(currentIntervalStart, goldData.OverallGold)
        return false
    end

    if previousDayKey == currentDayKey then
        archive.daily[currentDayKey] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        self:StoreOverallArchivePoint(currentIntervalStart, goldData.OverallGold)
        return false
    end

    local previousIntervalStart = ParseLongTermArchiveKey(previousDayKey)
    if not previousIntervalStart then
        archive.currentDayKey = currentDayKey
        archive.daily[currentDayKey] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        self:StoreOverallArchivePoint(currentIntervalStart, goldData.OverallGold)
        return false
    end

    if previousIntervalStart < currentIntervalStart then
        local inheritVal = archive.daily[previousDayKey]
        if not inheritVal then
            local latestTS
            for rawK, rawV in pairs(archive.daily) do
                local ts = ParseLongTermArchiveKey(rawK)
                if ts and ts < previousIntervalStart then
                    if not latestTS or ts > latestTS then
                        latestTS = ts
                        inheritVal = rawV
                    end
                end
            end
        end
        if not inheritVal then
            inheritVal = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        else
            inheritVal = NormalizeGoldSnapshotData(inheritVal)
        end

        local k = AdvanceHalfDayIntervalStart(previousIntervalStart)
        while k < currentIntervalStart do
            local kKey = GetLongTermArchiveKey(k)
            archive.daily[kKey] = BuildGoldSnapshotData(inheritVal.WarboundGold, inheritVal.CharacterGold)
            self:StoreOverallArchivePoint(k, inheritVal.OverallGold)
            k = AdvanceHalfDayIntervalStart(k)
        end
    end

    archive.daily[currentDayKey] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
    self:StoreOverallArchivePoint(currentIntervalStart, goldData.OverallGold)
    archive.currentDayKey = currentDayKey
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

        local getSpecIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
        local getSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
        local specIndex = getSpecIndex and getSpecIndex()
        if specIndex then
            local specID, specName, _, specIcon = getSpecInfo(specIndex)
            if specID then
                character.specID = specID
                character.specName = specName
                character.specIcon = specIcon
            end
        end
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

local function NormalizeCharacterSortSettings(settings)
    settings = settings or {}

    local sort = type(settings.characterSort) == "table" and settings.characterSort or nil
    local key = sort and sort.key
    local usedDefaultKey = false
    if not CHARACTER_SORT_FIELDS[key] then
        key = CHARACTER_SORT_DEFAULT.key
        usedDefaultKey = true
    end

    local ascending = sort and sort.ascending == true
    if sort == nil or usedDefaultKey then
        ascending = CHARACTER_SORT_DEFAULT.ascending
    end
    settings.characterSort = {
        key = key,
        ascending = ascending,
    }

    return settings.characterSort
end

local function NormalizeSortText(value)
    return string.lower(tostring(value or ""))
end

local function GetCharacterDisplayNameSortValue(character)
    return NormalizeSortText(string.format("%s-%s", character.name or "", character.realm or ""))
end

local function GetCharacterVaultSortValue(character)
    if clientInfo.isRetail and not IsCharacterAtMaxLevel(character) then
        return ""
    end

    local display = GetWeeklyRewardDisplayState(character.weeklyReward)
    return NormalizeSortText(display and display.summaryText or GetDefaultWeeklyRewardSummaryText())
end

local function GetCharacterGoldSortValue(owner, character)
    if character.isCurrent then
        return owner:GetCurrentCharacterMoney()
    end

    return math.floor(tonumber(character.money) or 0)
end

local function BuildCharacterSortValues(owner, character)
    return {
        name = GetCharacterDisplayNameSortValue(character),
        level = tonumber(character.level) or 0,
        vault = GetCharacterVaultSortValue(character),
        played = tonumber(owner:GetDisplayedPlayedTime(character)) or 0,
        gold = GetCharacterGoldSortValue(owner, character),
    }
end

local function CompareCharacterFallback(a, b)
    if a.isCurrent ~= b.isCurrent then
        return a.isCurrent
    end

    local aSeen = tonumber(a.lastSeen) or 0
    local bSeen = tonumber(b.lastSeen) or 0
    if aSeen ~= bSeen then
        return aSeen > bSeen
    end

    local aName = GetCharacterDisplayNameSortValue(a)
    local bName = GetCharacterDisplayNameSortValue(b)
    if aName ~= bName then
        return aName < bName
    end

    return tostring(a.key or "") < tostring(b.key or "")
end

local function CompareCharacterSortValue(a, b, sortKey, ascending)
    local aValue = a.sortValues and a.sortValues[sortKey]
    local bValue = b.sortValues and b.sortValues[sortKey]

    if aValue ~= bValue then
        if ascending then
            return aValue < bValue
        end

        return aValue > bValue
    end

    return nil
end

local function SortCharactersForOverview(characters, sortSettings)
    local sortKey = sortSettings and sortSettings.key or CHARACTER_SORT_DEFAULT.key
    local ascending = sortSettings and sortSettings.ascending == true

    table.sort(characters, function(a, b)
        if a.isFavorite ~= b.isFavorite then
            return a.isFavorite
        end

        if sortKey ~= "lastcharacter" then
            local sortResult = CompareCharacterSortValue(a, b, sortKey, ascending)
            if sortResult ~= nil then
                return sortResult
            end
        end

        return CompareCharacterFallback(a, b)
    end)
end

function mQoL_AccountOverview:GetCharacterSortSettings()
    if not self.db then
        self:InitializeDB()
    end

    self.db.settings = self.db.settings or DeepCopy(mQoL_AccountOverview.defaults.settings)
    return NormalizeCharacterSortSettings(self.db.settings)
end

function mQoL_AccountOverview:SetCharacterSort(sortKey)
    if sortKey == "lastcharacter" or not CHARACTER_SORT_FIELDS[sortKey] then
        return
    end

    local sort = self:GetCharacterSortSettings()
    local defaultAscending = CHARACTER_SORT_DEFAULT_ASCENDING[sortKey] == true
    if sort.key == sortKey then
        if sort.ascending == defaultAscending then
            sort.ascending = not defaultAscending
        else
            sort.key = CHARACTER_SORT_DEFAULT.key
            sort.ascending = CHARACTER_SORT_DEFAULT.ascending
        end
    else
        sort.key = sortKey
        sort.ascending = defaultAscending
    end

    self:RefreshCharactersView()
    if self.activeTab == "Characters" then
        self:SetActiveTab("Characters")
    end
end

function mQoL_AccountOverview:GetKnownCharacters()
    if not self.db then
        return {}
    end

    local currentKey = select(1, GetCurrentCharacterIdentity())
    self.currentCharacterKey = currentKey
    local favorites = self.db.settings and self.db.settings.favoriteCharacters or {}
    local sortSettings = self:GetCharacterSortSettings()
    local characters = {}

    for key, data in pairs(self.db.characters) do
        if type(data) == "table" then
            data.weeklyReward = NormalizeWeeklyRewardSnapshot(data.weeklyReward)
            local row = DeepCopy(data)
            row.key = key
            row.isCurrent = key == currentKey
            row.isFavorite = favorites[tostring(key)] == true
            row.sortValues = BuildCharacterSortValues(self, row)
            characters[#characters + 1] = row
        end
    end

    SortCharactersForOverview(characters, sortSettings)

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

local function Clamp(val, minVal, maxVal)
    return math.max(minVal, math.min(maxVal, val))
end

local function AcquireFrame(pool, index, parent)
    local frame = pool[index]
    if not frame then
        frame = CreateFrame("Frame", nil, parent)
        pool[index] = frame
    end
    frame:Show()
    return frame
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
    for _, object in pairs(pool or {}) do
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

local function UpdateCharacterSortHeaderButton(button)
    if not button or not button.sortKey then
        return
    end

    local sort = mQoL_AccountOverview:GetCharacterSortSettings()
    local isActive = sort.key == button.sortKey
    local headerText = ACCOUNT_OVERVIEW_STYLE.headerText
    local label = button.labelText or ""

    button.text:SetText(label)

    if isActive then
        local texture = sort.ascending and CHARACTER_SORT_UP_TEXTURE or CHARACTER_SORT_DOWN_TEXTURE
        local textWidth = button.text.GetStringWidth and button.text:GetStringWidth() or 0

        button.icon:SetTexture(texture)
        button.icon:ClearAllPoints()
        if button.headerJustify == "LEFT" then
            button.icon:SetPoint("RIGHT", button, "LEFT", -2, 0)
        elseif button.headerJustify == "RIGHT" then
            button.icon:SetPoint("RIGHT", button, "RIGHT", -math.floor(textWidth + 4), 0)
        else
            button.icon:SetPoint("RIGHT", button, "CENTER", -math.floor((textWidth / 2) + 4), 0)
        end
        button.icon:Show()
    else
        button.icon:Hide()
    end

    button.text:SetTextColor(
        isActive and 1 or headerText[1],
        isActive and 0.82 or headerText[2],
        isActive and 0 or headerText[3]
    )
end

local function CreateCharacterSortHeaderButton(parent, column)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("LEFT", parent, "LEFT", column.x, 0)
    button:SetSize(column.width, 26)
    if parent.GetFrameLevel and button.SetFrameLevel then
        button:SetFrameLevel(parent:GetFrameLevel() + 2)
    end
    button:RegisterForClicks("LeftButtonUp")
    button.sortKey = column.key
    button.labelText = column.label
    button.headerJustify = column.headerJustify or "CENTER"

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetAllPoints()
    button.text:SetJustifyH(button.headerJustify)
    button.text:SetText(button.labelText)

    button.icon = button:CreateTexture(nil, "OVERLAY")
    if button.icon.SetDrawLayer then
        button.icon:SetDrawLayer("OVERLAY", 7)
    end
    button.icon:SetSize(8, 8)
    button.icon:Hide()

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Sort by " .. (column.label or ""), 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self)
        mQoL_AccountOverview:SetCharacterSort(self.sortKey)
    end)

    UpdateCharacterSortHeaderButton(button)
    return button
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
    frame.secondaryTables = {}

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
        HidePool(self.secondaryTables)
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

local function GetSecondaryProfessionTableRows(entry)
    local rows = {}

    if type(entry) ~= "table" then
        return rows
    end

    for _, rowData in ipairs(GetProfessionDetailRows(entry) or {}) do
        if rowData.isActive and rowData.value and rowData.value ~= "-" then
            rows[#rows + 1] = {
                label = rowData.label or "Current",
                value = rowData.value,
                isActive = true,
            }
        end
    end

    if #rows == 0 then
        rows[#rows + 1] = {
            label = "Current",
            value = GetProfessionSummaryText(entry, false),
            isActive = true,
        }
    end

    return rows
end

local function EnsureSecondaryProfessionTable(frame, index)
    frame.secondaryTables = frame.secondaryTables or {}
    local tableFrame = frame.secondaryTables[index]
    if tableFrame then
        tableFrame:Show()
        return tableFrame
    end

    tableFrame = CreateFrame("Frame", nil, frame)
    tableFrame.rowsLeft = {}
    tableFrame.rowsRight = {}
    tableFrame.rowBackgrounds = {}
    tableFrame.rowSeparators = {}

    tableFrame.title = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tableFrame.title:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, 0)
    tableFrame.title:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", 0, 0)
    tableFrame.title:SetJustifyH("CENTER")
    tableFrame.title:SetTextColor(1, 0.82, 0)

    tableFrame.separator = tableFrame:CreateTexture(nil, "ARTWORK")
    tableFrame.separator:SetColorTexture(1, 1, 1, 0.12)
    tableFrame.separator:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, -20)
    tableFrame.separator:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", 0, -20)
    tableFrame.separator:SetHeight(1)

    tableFrame.headerLeft = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tableFrame.headerLeft:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 2, -32)
    tableFrame.headerLeft:SetJustifyH("LEFT")
    tableFrame.headerLeft:SetTextColor(0.9, 0.9, 0.9)
    tableFrame.headerLeft:SetText("Expansion")

    tableFrame.headerRight = tableFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tableFrame.headerRight:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", -2, -32)
    tableFrame.headerRight:SetJustifyH("RIGHT")
    tableFrame.headerRight:SetTextColor(0.9, 0.9, 0.9)
    tableFrame.headerRight:SetText("Skill")

    frame.secondaryTables[index] = tableFrame
    return tableFrame
end

local function PopulateSecondaryProfessionTable(tableFrame, professionEntry, width)
    local rows = GetSecondaryProfessionTableRows(professionEntry)
    tableFrame:SetWidth(width)
    tableFrame:SetHeight(54 + (#rows * 20))
    tableFrame.title:SetText(professionEntry.name or "Unknown")
    tableFrame.headerLeft:SetWidth(width - 76)
    tableFrame.headerRight:SetWidth(66)

    HidePool(tableFrame.rowsLeft)
    HidePool(tableFrame.rowsRight)
    HidePool(tableFrame.rowBackgrounds)
    HidePool(tableFrame.rowSeparators)

    local rowStartY = -54
    local rowHeight = 20
    for index, rowData in ipairs(rows) do
        local rowOffset = rowStartY - ((index - 1) * rowHeight)

        local rowBackground = AcquireTexture(tableFrame.rowBackgrounds, index, tableFrame, "BACKGROUND")
        rowBackground:ClearAllPoints()
        rowBackground:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, rowOffset + 2)
        rowBackground:SetSize(width, rowHeight - 2)
        rowBackground:SetColorTexture(index % 2 == 1 and 0.08 or 0.10, index % 2 == 1 and 0.08 or 0.10, index % 2 == 1 and 0.08 or 0.10, 0.95)

        local rowSeparator = AcquireTexture(tableFrame.rowSeparators, index, tableFrame, "ARTWORK")
        rowSeparator:ClearAllPoints()
        rowSeparator:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 2, rowOffset + 1)
        rowSeparator:SetSize(width - 4, 1)
        rowSeparator:SetColorTexture(1, 1, 1, 0.05)

        local left = AcquireFontString(tableFrame.rowsLeft, index, tableFrame, "GameFontNormalSmall")
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 4, rowOffset - 2)
        left:SetWidth(width - 82)
        left:SetJustifyH("LEFT")
        left:SetText(rowData.label or "Current")
        left:SetTextColor(rowData.isActive and 0.92 or 0.62, rowData.isActive and 0.92 or 0.62, rowData.isActive and 0.92 or 0.62)

        local right = AcquireFontString(tableFrame.rowsRight, index, tableFrame, "GameFontNormalSmall")
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", -4, rowOffset - 2)
        right:SetWidth(72)
        right:SetJustifyH("RIGHT")
        right:SetText(rowData.value or "-")
        right:SetTextColor(rowData.isActive and 1 or 0.58, rowData.isActive and 0.82 or 0.58, rowData.isActive and 0 or 0.58)
    end

    return #rows
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

    local isSecondaryDetail = professionEntry.isSecondarySummary and true or false
    local secondaryEntries = isSecondaryDetail and professionEntry.secondaryProfessions or nil
    local secondaryCount = type(secondaryEntries) == "table" and math.max(1, #secondaryEntries) or 1
    local secondaryColumnWidth = 180
    local secondaryColumnGap = 12
    local frameWidth = isSecondaryDetail and math.max(288, 24 + (secondaryCount * secondaryColumnWidth) + ((secondaryCount - 1) * secondaryColumnGap)) or 300
    frame:SetWidth(frameWidth)
    frame.separator:SetSize(frameWidth - 24, 1)

    frame.title:SetText(professionEntry.name or "Profession")
    if isSecondaryDetail then
        frame.subtitle:SetText("All secondary professions")
        frame.headerLeft:Hide()
        frame.headerRight:Hide()
    else
        frame.subtitle:SetText("Detailed profession tiers")
        frame.headerLeft:ClearAllPoints()
        frame.headerLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -78)
        frame.headerLeft:SetWidth(186)
        frame.headerLeft:SetJustifyH("LEFT")
        frame.headerLeft:SetText("Expansion")
        frame.headerLeft:Show()
        frame.headerRight:SetText("Skill")
        frame.headerRight:Show()
    end

    HidePool(frame.rowsLeft)
    HidePool(frame.rowsRight)
    HidePool(frame.rowBackgrounds)
    HidePool(frame.rowSeparators)
    HidePool(frame.secondaryTables)

    if isSecondaryDetail then
        local maxRows = 1
        local totalColumnsWidth = (secondaryCount * secondaryColumnWidth) + ((secondaryCount - 1) * secondaryColumnGap)
        local startX = (frameWidth - totalColumnsWidth) / 2
        for index, entry in ipairs(secondaryEntries or {}) do
            if type(entry) == "table" then
                local tableFrame = EnsureSecondaryProfessionTable(frame, index)
                tableFrame:ClearAllPoints()
                tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + ((index - 1) * (secondaryColumnWidth + secondaryColumnGap)), -78)
                maxRows = math.max(maxRows, PopulateSecondaryProfessionTable(tableFrame, entry, secondaryColumnWidth))
            end
        end

        if not secondaryEntries or #secondaryEntries == 0 then
            local tableFrame = EnsureSecondaryProfessionTable(frame, 1)
            tableFrame:ClearAllPoints()
            tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", startX, -78)
            maxRows = math.max(maxRows, PopulateSecondaryProfessionTable(tableFrame, { name = "Secondary" }, secondaryColumnWidth))
        end

        local frameHeight = math.max(200, 148 + (maxRows * 20))
        frame:SetHeight(frameHeight)
        self:PositionProfessionDetailFrame(frame)

        frame:Show()
        return
    end

    local detailRows = GetProfessionDetailRows(professionEntry)
    local startY = -102
    local rowHeight = 20
    for index, rowData in ipairs(detailRows) do
        local rowOffset = startY - ((index - 1) * rowHeight)
        local rowBackground = AcquireTexture(frame.rowBackgrounds, index, frame, "BACKGROUND")
        rowBackground:ClearAllPoints()
        rowBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, rowOffset + 2)
        rowBackground:SetSize(frameWidth - 24, rowHeight - 2)
        rowBackground:SetColorTexture(index % 2 == 1 and 0.08 or 0.10, index % 2 == 1 and 0.08 or 0.10, index % 2 == 1 and 0.08 or 0.10, 0.95)

        local rowSeparator = AcquireTexture(frame.rowSeparators, index, frame, "ARTWORK")
        rowSeparator:ClearAllPoints()
        rowSeparator:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, rowOffset + 1)
        rowSeparator:SetSize(frameWidth - 32, 1)
        rowSeparator:SetColorTexture(1, 1, 1, 0.05)

        local left = AcquireFontString(frame.rowsLeft, index, frame, "GameFontNormalSmall")
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, rowOffset - 2)
        left:SetJustifyH("LEFT")
        left:SetWidth(186)
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

local function AddSecondaryProfessionTooltipSection(entry, isFirstSection)
    if type(entry) ~= "table" then
        return
    end

    if not isFirstSection then
        GameTooltip:AddLine(" ")
    end

    GameTooltip:AddLine(entry.name or "Unknown", 1, 0.82, 0)
    GameTooltip:AddLine(GetProfessionSummaryText(entry, true), 1, 1, 1)
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
    view.header.sortButtons = {}
    for _, column in ipairs(CHARACTER_COLUMNS) do
        if CHARACTER_SORT_FIELDS[column.key] then
            local button = CreateCharacterSortHeaderButton(view.header, column)
            view.header.sortButtons[column.key] = button
            view.header.labels[column.key] = button.text
        else
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
            GameTooltip:AddLine(" ", 1, 1, 1)
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
            GameTooltip:AddLine(" ")
            for index, entry in ipairs(self.professionEntry.secondaryProfessions or {}) do
                AddSecondaryProfessionTooltipSection(entry, index == 1)
            end
        else
            GameTooltip:AddLine("Click to view detailed profession tiers.", 1, 1, 1)
            GameTooltip:AddLine(" ")
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

    for _, button in pairs(view.header.sortButtons or {}) do
        UpdateCharacterSortHeaderButton(button)
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
    if not self.db or not self.db.overallArchive or type(self.db.overallArchive.daily) ~= "table" then
        return {}
    end

    local entries = {}
    for rawKey, rawValue in pairs(self.db.overallArchive.daily) do
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

    local currentIntervalStart = GetHalfDayIntervalStart(now)
    if #entries == 0 or entries[#entries].ts < currentIntervalStart then
        entries[#entries + 1] = {
            ts = currentIntervalStart,
            total = currentTotal,
        }
    else
        entries[#entries].total = currentTotal
    end

    return entries
end

function mQoL_AccountOverview:NormalizeOverallArchivePoints(points)
    local normalized = NormalizeTimeSeriesEntries(points)
    local dailyBuckets = {}
    local result = {}

    for _, entry in ipairs(normalized) do
        local halfDayStart = GetHalfDayIntervalStart(entry.ts)
        dailyBuckets[halfDayStart] = {
            ts = entry.ts,
            total = entry.total,
        }
    end

    for _, entry in pairs(dailyBuckets) do
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
        local actualTs = key
        if index == windowSize then
            value = currentTotal
            actualTs = now
        else
            local foundEntry = nil
            while sourceIndex <= #entries and entries[sourceIndex].ts <= key do
                carryValue = entries[sourceIndex].total
                foundEntry = entries[sourceIndex]
                sourceIndex = sourceIndex + 1
            end
            value = carryValue
            if foundEntry then
                actualTs = foundEntry.ts
            end
        end

        series[#series + 1] = {
            ts = actualTs,
            total = value,
            label = GetRangeBucketLabel(rangeKey, key, index, windowSize),
            bucketKey = key,
        }
    end

    return series, oldestBucketKey, now
end

function mQoL_AccountOverview:BuildOverallArchiveBootstrapEntries(currentTotal, now)
    local bootstrapEntries = NormalizeTimeSeriesEntries(self:BuildOverallCheckpointEntries(currentTotal, now))
    local currentIntervalStart = GetHalfDayIntervalStart(now)
    local dailyBuckets = {}

    for _, entry in ipairs(bootstrapEntries) do
        local halfDayStart = GetHalfDayIntervalStart(entry.ts)
        if halfDayStart < currentIntervalStart then
            dailyBuckets[halfDayStart] = {
                ts = entry.ts,
                total = entry.total,
            }
        end
    end

    local result = {}
    for _, entry in pairs(dailyBuckets) do
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
        ts = math.floor(tonumber(timestamp) or 0),
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
    archive.daily = archive.daily or {}
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
        and type(self.db.overallArchive.daily) == "table"
        and next(self.db.overallArchive.daily) ~= nil
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
    local currentDayStart = GetStartOfDay(now)
    local buckets = {}

    for _, entry in ipairs(history or {}) do
        local dayStart = GetStartOfDay(entry.ts)
        if dayStart < currentDayStart then
            local bucket = buckets[dayStart]
            if not bucket then
                bucket = {
                    ts = dayStart,
                    sum = 0,
                    count = 0,
                }
                buckets[dayStart] = bucket
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
        ts = currentDayStart,
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

    self.zoomMinTS = nil
    self.zoomMaxTS = nil
    if self.goldChartView and self.goldChartView.resetZoomBtn then
        self.goldChartView.resetZoomBtn:Hide()
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

function mQoL_AccountOverview:ResetGoldChartZoom()
    self.zoomMinTS = nil
    self.zoomMaxTS = nil
    if self.goldChartView and self.goldChartView.resetZoomBtn then
        self.goldChartView.resetZoomBtn:Hide()
    end
    self:RefreshGoldChartView()
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

    view.resetZoomBtn = CreateTabButton(view.rangeButtonsFrame, "Reset Zoom", 110)
    view.resetZoomBtn:SetPoint("RIGHT", view.rangeButtonsFrame, "RIGHT", 0, 0)
    view.resetZoomBtn:SetScript("OnClick", function()
        mQoL_AccountOverview:ResetGoldChartZoom()
    end)
    view.resetZoomBtn:Hide()

    view.chart.pointButtons = {}
    view.chart:EnableMouse(true)
    
    view.chart:SetScript("OnMouseDown", function(self, button)
        if mQoL_AccountOverview:GetSelectedGoldRange() ~= "overall" then
            return
        end
        if button == "LeftButton" then
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            local relativeX = (x / scale) - self:GetLeft()
            
            local chartWidth = self:GetWidth() or GOLD_CHART_WIDTH
            local plotWidth = chartWidth - self.plotLeft - self.plotRight
            local minPlotX = self.plotLeft
            local maxPlotX = self.plotLeft + plotWidth
            
            if relativeX >= minPlotX and relativeX <= maxPlotX then
                self.isZoomDragging = true
                self.dragStartX = relativeX
                
                if not self.zoomSelection then
                    self.zoomSelection = self:CreateTexture(nil, "OVERLAY")
                    self.zoomSelection:SetColorTexture(1, 0.82, 0, 0.15)
                end
                
                local plotHeight = self:GetHeight() - self.plotBottom - self.plotTop
                self.zoomSelection:ClearAllPoints()
                self.zoomSelection:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", relativeX, self.plotBottom)
                self.zoomSelection:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", relativeX, self.plotBottom + plotHeight)
                self.zoomSelection:Show()
            end
        elseif button == "RightButton" then
            mQoL_AccountOverview:ResetGoldChartZoom()
        end
    end)

    view.chart:SetScript("OnUpdate", function(self, elapsed)
        if self.isZoomDragging then
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            local currentX = (x / scale) - self:GetLeft()
            
            local chartWidth = self:GetWidth() or GOLD_CHART_WIDTH
            local plotWidth = chartWidth - self.plotLeft - self.plotRight
            local minPlotX = self.plotLeft
            local maxPlotX = self.plotLeft + plotWidth
            
            currentX = Clamp(currentX, minPlotX, maxPlotX)
            
            local minX = math.min(self.dragStartX, currentX)
            local maxX = math.max(self.dragStartX, currentX)
            
            local plotHeight = self:GetHeight() - self.plotBottom - self.plotTop
            self.zoomSelection:ClearAllPoints()
            self.zoomSelection:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", minX, self.plotBottom)
            self.zoomSelection:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", maxX, self.plotBottom + plotHeight)
        end
    end)

    view.chart:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isZoomDragging then
            self.isZoomDragging = false
            if self.zoomSelection then
                self.zoomSelection:Hide()
            end
            
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            local relativeX = (x / scale) - self:GetLeft()
            
            local chartWidth = self:GetWidth() or GOLD_CHART_WIDTH
            local plotWidth = chartWidth - self.plotLeft - self.plotRight
            local minPlotX = self.plotLeft
            local maxPlotX = self.plotLeft + plotWidth
            
            relativeX = Clamp(relativeX, minPlotX, maxPlotX)
            
            local minX = math.min(self.dragStartX, relativeX)
            local maxX = math.max(self.dragStartX, relativeX)
            
            if (maxX - minX) > 5 then
                if self.firstTimestamp and self.lastTimestamp then
                    local range = self.lastTimestamp - self.firstTimestamp
                    local pctMin = (minX - minPlotX) / plotWidth
                    local pctMax = (maxX - minPlotX) / plotWidth
                    
                    local zoomMin = self.firstTimestamp + pctMin * range
                    local zoomMax = self.firstTimestamp + pctMax * range
                    
                    mQoL_AccountOverview.zoomMinTS = zoomMin
                    mQoL_AccountOverview.zoomMaxTS = zoomMax
                    
                    mQoL_AccountOverview:RefreshGoldChartView()
                end
            end
        end
    end)

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
    HidePool(chart.pointButtons)

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
    
    chart.firstTimestamp = firstTimestamp
    chart.lastTimestamp = lastTimestamp

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
    local isZoomed = self.zoomMinTS and self.zoomMaxTS
    local function FormatXAxisLabel(timestamp)
        if isZoomed then
            local spanDays = timeRange / SECONDS_PER_DAY
            if spanDays >= 365 then
                return date("%b %Y", timestamp)
            elseif spanDays >= 30 then
                return date("%d %b", timestamp)
            elseif spanDays >= 1 then
                return date("%d %b", timestamp)
            else
                return date("%H:%M", timestamp)
            end
        end

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
        point:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)

        local pointBtn = AcquireFrame(chart.pointButtons, index, chart)
        pointBtn:ClearAllPoints()
        pointBtn:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)
        pointBtn:SetSize(16, 16)
        pointBtn:EnableMouse(true)
        pointBtn.sample = sample
        pointBtn.index = index
        pointBtn.pointVisual = point
        
        pointBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Gold Checkpoint", 1, 0.82, 0)
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddDoubleLine("Time:", mQoL_Utils.FormatTimestamp(self.sample.ts), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine("Total Gold:", FormatMoneyCompact(self.sample.total), 0.7, 0.7, 0.7, 1, 0.82, 0)
            
            if self.index > 1 and samples[self.index - 1] then
                local prev = samples[self.index - 1]
                local diff = self.sample.total - prev.total
                local diffStr = FormatMoneyCompact(diff)
                if diff > 0 then
                    diffStr = "+" .. diffStr
                    GameTooltip:AddDoubleLine("Change:", diffStr, 0.7, 0.7, 0.7, 0.1, 1, 0.1)
                elseif diff < 0 then
                    GameTooltip:AddDoubleLine("Change:", diffStr, 0.7, 0.7, 0.7, 1, 0.1, 0.1)
                else
                    GameTooltip:AddDoubleLine("Change:", "No Change", 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
                end
            end
            GameTooltip:Show()
            
            self.pointVisual:SetSize(self.index == #samples and 10 or 8, self.index == #samples and 10 or 8)
            self.pointVisual:SetColorTexture(1, 1, 1, 1)
        end)
        
        pointBtn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            self.pointVisual:SetSize(self.index == #samples and 6 or 4, self.index == #samples and 6 or 4)
            self.pointVisual:SetColorTexture(1, 0.82, 0, self.index == #samples and 1 or 0.92)
        end)
        
        pointBtn:SetScript("OnMouseDown", function(self, button)
            local chartScript = chart:GetScript("OnMouseDown")
            if chartScript then
                chartScript(chart, button)
            end
        end)
        
        pointBtn:SetScript("OnMouseUp", function(self, button)
            local chartScript = chart:GetScript("OnMouseUp")
            if chartScript then
                chartScript(chart, button)
            end
        end)

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

    local isZoomed = false
    if self.zoomMinTS and self.zoomMaxTS then
        local zoomedSeries = {}
        for _, entry in ipairs(series) do
            if entry.ts >= self.zoomMinTS and entry.ts <= self.zoomMaxTS then
                table.insert(zoomedSeries, { ts = entry.ts, total = entry.total })
            end
        end
        if #zoomedSeries >= 2 then
            series = zoomedSeries
            rangeStart = self.zoomMinTS
            now = self.zoomMaxTS
            isZoomed = true
        end
    end

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

    if view.resetZoomBtn then
        view.resetZoomBtn:SetShown(isZoomed)
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

    local formatStr = isZoomed and "%d %b %Y %H:%M" or "%d %b %Y"
    view.statsText:SetText(string.format(
        "Range: %s to %s    Window change: %s%s    High: %s    Low: %s    Checkpoints: %d%s",
        date(formatStr, rangeStart),
        date(formatStr, now),
        deltaPrefix,
        FormatMoneyCompact(delta),
        FormatMoneyCompact(highest),
        FormatMoneyCompact(lowest),
        math.max(0, #series - 1),
        isZoomed and " (Zoomed)" or ""
    ))

    self:DrawGoldChart(samples)
    view:SetHeight(450)
    view.contentHeight = 450
end

local CLASS_ICON_TCOORDS = {
    ["WARRIOR"]     = {0, 0.25, 0, 0.25},
    ["MAGE"]        = {0.25, 0.5, 0, 0.25},
    ["ROGUE"]       = {0.5, 0.75, 0, 0.25},
    ["DRUID"]       = {0.75, 1, 0, 0.25},
    ["HUNTER"]      = {0, 0.25, 0.25, 0.5},
    ["SHAMAN"]      = {0.25, 0.5, 0.25, 0.5},
    ["PRIEST"]      = {0.5, 0.75, 0.25, 0.5},
    ["WARLOCK"]     = {0.75, 1, 0.25, 0.5},
    ["PALADIN"]     = {0, 0.25, 0.5, 0.75},
    ["DEATHKNIGHT"] = {0.25, 0.5, 0.5, 0.75},
    ["MONK"]        = {0.5, 0.75, 0.5, 0.75},
    ["DEMONHUNTER"] = {0.75, 1, 0.5, 0.75},
    ["EVOKER"]      = {0, 0.25, 0.75, 1},
}

local function GetCharacterIcon(character)
    if character.specIcon then
        return character.specIcon, nil
    end

    local classFile = character.classFile
    if classFile then
        local coords = CLASS_ICON_TCOORDS[classFile]
        if coords then
            return "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes", coords
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark", nil
end

function mQoL_AccountOverview:EnsurePlayedTimeView()
    if self.playedTimeView then
        return self.playedTimeView
    end

    local view = CreateFrame("Frame", nil, self.viewsHost)
    view:SetPoint("TOPLEFT", self.viewsHost, "TOPLEFT", 0, 0)
    view:SetWidth(770)
    view.chartRows = {}

    view.summaryText = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    view.summaryText:SetPoint("LEFT", view, "TOPLEFT", 0, -13)
    view.summaryText:SetTextColor(1, 0.82, 0)

    local CreateCustomDropdown = mQoL_Styles and mQoL_Styles.CreateCustomDropdown
    if CreateCustomDropdown then
        view.chartTypeDropdown = CreateCustomDropdown(view, 180, {
            { text = "Horizontal Bars", value = "BAR" },
            { text = "Column Chart", value = "GRAPH" },
            { text = "Pie Chart", value = "DIST" },
        }, "BAR", function(val)
            self.db.settings.playedTimeFilters.chartType = val
            self:RefreshPlayedTimeView()
        end)
        view.chartTypeDropdown:SetPoint("RIGHT", view, "TOPRIGHT", 0, -13)
    end

    view.chartContainer = CreateFrame("Frame", nil, view)
    view.chartContainer:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -45)
    view.chartContainer:SetWidth(770)

    view.emptyState = view:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    view.emptyState:SetPoint("CENTER", view.chartContainer, "CENTER", 0, 0)
    view.emptyState:SetText("No characters match the selected filters.")
    view.emptyState:Hide()

    view.graphFrame = CreateFrame("Frame", nil, view)
    view.graphFrame:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -45)
    view.graphFrame:SetSize(770, 360)
    view.graphFrame:Hide()

    view.graphFrame.bg = view.graphFrame:CreateTexture(nil, "BACKGROUND")
    view.graphFrame.bg:SetAllPoints()
    view.graphFrame.bg:SetColorTexture(0.08, 0.08, 0.08, 0.96)

    if CreateFrameBorder then
        view.graphFrame.border = CreateFrameBorder(view.graphFrame, 1, { 0.22, 0.22, 0.22, 1 })
    end

    view.graphFrame.plotLeft = 70
    view.graphFrame.plotRight = 18
    view.graphFrame.plotTop = 20
    view.graphFrame.plotBottom = 40
    view.graphFrame.gridLines = {}
    view.graphFrame.yLabels = {}
    view.graphFrame.xLabels = {}
    view.graphFrame.bars = {}
    view.graphFrame.barButtons = {}

    view.distArea = CreateFrame("Frame", nil, view)
    view.distArea:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -45)
    view.distArea:SetWidth(770)
    view.distArea:Hide()

    view.distArea.pieFrame = CreateFrame("Frame", nil, view.distArea)
    view.distArea.pieFrame:SetSize(360, 360)
    view.distArea.pieFrame:SetPoint("TOP", view.distArea, "TOP", 0, -5)

    view.distArea.pieFrame.centerTextTitle = view.distArea.pieFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.distArea.pieFrame.centerTextTitle:SetPoint("BOTTOM", view.distArea.pieFrame, "CENTER", 0, 2)
    view.distArea.pieFrame.centerTextTitle:SetText("TOTAL")
    view.distArea.pieFrame.centerTextTitle:SetTextColor(0.65, 0.65, 0.65)

    view.distArea.pieFrame.centerTextValue = view.distArea.pieFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    view.distArea.pieFrame.centerTextValue:SetPoint("TOP", view.distArea.pieFrame, "CENTER", 0, -2)
    view.distArea.pieFrame.centerTextValue:SetTextColor(1, 0.82, 0)

    view.distArea.pieLines = {}
    view.distArea.pieLabelLines = {}
    view.distArea.pieLabelTexts = {}

    self.playedTimeView = view
    self.views["Played Time"] = view
    return view
end

function mQoL_AccountOverview:EnsureChartRow(index)
    local view = self:EnsurePlayedTimeView()
    view.chartRows = view.chartRows or {}
    local row = view.chartRows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, view.chartContainer)
    row:SetSize(770, 36)
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.06, 0.06, 0.07, 0.5)

    row.barBg = row:CreateTexture(nil, "BORDER")
    row.barBg:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
    row.barBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 4)
    row.barBg:SetColorTexture(0.12, 0.12, 0.14, 0.6)

    row.barFill = row:CreateTexture(nil, "ARTWORK")
    row.barFill:SetPoint("TOPLEFT", row.barBg, "TOPLEFT", 0, 0)
    row.barFill:SetPoint("BOTTOMLEFT", row.barBg, "BOTTOMLEFT", 0, 0)
    row.barFill:SetColorTexture(1, 1, 1, 1)

    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row.barBg, "LEFT", 6, 0)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 8, 4)
    row.nameText:SetJustifyH("LEFT")

    row.subText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.subText:SetPoint("LEFT", row.icon, "RIGHT", 8, -8)
    row.subText:SetJustifyH("LEFT")
    row.subText:SetTextColor(0.65, 0.65, 0.65)

    row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.timeText:SetPoint("RIGHT", row.barBg, "RIGHT", -8, 4)
    row.timeText:SetJustifyH("RIGHT")

    row.pctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.pctText:SetPoint("RIGHT", row.barBg, "RIGHT", -8, -8)
    row.pctText:SetJustifyH("RIGHT")
    row.pctText:SetTextColor(0.8, 0.8, 0.8)

    if CreateFrameBorder then
        row.border = CreateFrameBorder(row, 1, { 0.2, 0.2, 0.22, 0.6 })
    end

    row:SetScript("OnEnter", function(self)
        if not self.aggregatedData then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.aggregatedData.name, 1, 0.82, 0)
        GameTooltip:AddLine(" ", 1, 1, 1)

        GameTooltip:AddDoubleLine("Total Played:", FormatDuration(self.aggregatedData.time), 0.7, 0.7, 0.7, 1, 0.82, 0)
        GameTooltip:AddDoubleLine("Percentage of Total:", string.format("%.1f%%", self.pct or 0), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("Characters:", tostring(self.aggregatedData.charCount), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ", 1, 1, 1)

        GameTooltip:AddLine("Contributing Characters:", 1, 0.82, 0)
        for _, char in ipairs(self.aggregatedData.characters) do
            local charPlayed = mQoL_AccountOverview:GetDisplayedPlayedTime(char) or 0
            local charColor = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[char.classFile] or NORMAL_FONT_COLOR
            local specStr = char.specName and (" (" .. char.specName .. ")") or ""
            GameTooltip:AddDoubleLine(
                string.format("%s - %s (Lvl %d%s)", char.name, char.realm, char.level, specStr),
                FormatDuration(charPlayed),
                charColor.r, charColor.g, charColor.b,
                1, 1, 1
            )
        end
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    view.chartRows[index] = row
    return row
end

function mQoL_AccountOverview:RefreshPlayedTimeView()
    local view = self:EnsurePlayedTimeView()
    if not view then
        return
    end

    local pieFrame = view.distArea.pieFrame
    if pieFrame then
        pieFrame:SetScript("OnUpdate", nil)
        pieFrame:SetScript("OnEnter", nil)
        pieFrame:SetScript("OnLeave", nil)
        pieFrame:SetScript("OnHide", nil)
        pieFrame.lastHoveredSeg = nil
        pieFrame.isHovered = false
    end

    local characters = self:GetKnownCharacters()
    local totalPlayed = 0
    local classData = {}

    for _, char in ipairs(characters) do
        local played = self:GetDisplayedPlayedTime(char) or 0
        totalPlayed = totalPlayed + played

        if char.classFile then
            if not classData[char.classFile] then
                classData[char.classFile] = {
                    classFile = char.classFile,
                    name = char.className or char.classFile,
                    time = 0,
                    charCount = 0,
                    characters = {},
                }
            end
            classData[char.classFile].time = classData[char.classFile].time + played
            classData[char.classFile].charCount = classData[char.classFile].charCount + 1
            table.insert(classData[char.classFile].characters, char)
        end
    end

    local sortFunc = function(a, b)
        return (self:GetDisplayedPlayedTime(a) or 0) > (self:GetDisplayedPlayedTime(b) or 0)
    end
    for _, data in pairs(classData) do
        table.sort(data.characters, sortFunc)
    end

    local chartType = self.db.settings.playedTimeFilters.chartType or "BAR"
    if view.chartTypeDropdown then
        view.chartTypeDropdown:SetValue(chartType)
    end

    local activeDataList = {}
    for _, data in pairs(classData) do
        table.insert(activeDataList, data)
    end

    table.sort(activeDataList, function(a, b)
        if a.time ~= b.time then
            return a.time > b.time
        end
        return (a.name or "") < (b.name or "")
    end)

    view.chartContainer:SetShown(chartType == "BAR")
    view.graphFrame:SetShown(chartType == "GRAPH")
    view.distArea:SetShown(chartType == "DIST")

    view.summaryText:SetText(string.format("Total played time across all characters: %s", FormatDuration(totalPlayed)))

    if #activeDataList == 0 then
        view.emptyState:SetPoint("CENTER", chartType == "BAR" and view.chartContainer or (chartType == "GRAPH" and view.graphFrame or view.distArea), "CENTER", 0, 0)
        view.emptyState:Show()
    else
        view.emptyState:Hide()
    end

    -- 1. Horizontal Bars Mode
    if chartType == "BAR" then
        local startY = 0
        local rowHeight = 42
        local maxPlayed = 0

        for _, data in ipairs(activeDataList) do
            if data.time > maxPlayed then
                maxPlayed = data.time
            end
        end

        for index, data in ipairs(activeDataList) do
            local row = self:EnsureChartRow(index)
            row.aggregatedData = data
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", view.chartContainer, "TOPLEFT", 0, startY - (index - 1) * rowHeight)

            local texturePath, coords = GetCharacterIcon(data)
            row.icon:SetTexture(texturePath)
            if coords then
                row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            else
                row.icon:SetTexCoord(0, 1, 0, 1)
            end

            row.nameText:SetText(data.name)
            local r, g, b = GetClassColor(data.classFile)
            row.nameText:SetTextColor(r, g, b)

            local countStr = data.charCount == 1 and "1 character" or string.format("%d characters", data.charCount)
            row.subText:SetText(countStr)

            row.timeText:SetText(FormatDuration(data.time))
            row.timeText:SetTextColor(0.9, 0.9, 0.9)

            local pct = totalPlayed > 0 and (data.time / totalPlayed * 100) or 0
            row.pct = pct
            row.pctText:SetText(string.format("%.1f%%", pct))

            local ratio = maxPlayed > 0 and (data.time / maxPlayed) or 0
            row.barFill:SetColorTexture(r, g, b, 0.65)
            row.barFill:SetWidth(math.max(1, ratio * 762))

            row:Show()
        end

        for i = #activeDataList + 1, #(view.chartRows or {}) do
            if view.chartRows[i] then
                view.chartRows[i]:Hide()
                view.chartRows[i].aggregatedData = nil
            end
        end

        local listHeight = #activeDataList * rowHeight
        view.chartContainer:SetHeight(math.max(10, listHeight))

        local totalHeight = 45 + math.max(10, listHeight) + 20
        view:SetHeight(totalHeight)
        view.contentHeight = totalHeight

    -- 2. Column Chart Mode
    elseif chartType == "GRAPH" then
        local chart = view.graphFrame
        local plotWidth = chart:GetWidth() - chart.plotLeft - chart.plotRight
        local plotHeight = chart:GetHeight() - chart.plotTop - chart.plotBottom

        HidePool(chart.gridLines)
        HidePool(chart.yLabels)
        HidePool(chart.xLabels)
        HidePool(chart.bars)
        HidePool(chart.barButtons)
        if chart.xIcons then
            for _, icon in pairs(chart.xIcons) do
                icon:Hide()
            end
        end

        local maxTime = 0
        local numBars = #activeDataList
        for i = 1, numBars do
            local data = activeDataList[i]
            if data.time > maxTime then
                maxTime = data.time
            end
        end
        if maxTime <= 0 then maxTime = 3600 end

        for index = 0, 4 do
            local y = chart.plotBottom + (plotHeight * (index / 4))

            local line = AcquireTexture(chart.gridLines, index + 1, chart, "BORDER")
            line:ClearAllPoints()
            PrepareChartGridTexture(line, 0.08)
            line:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", chart.plotLeft, y)
            line:SetSize(plotWidth, 1)

            local label = AcquireFontString(chart.yLabels, index + 1, chart, "GameFontNormalSmall")
            label:ClearAllPoints()
            label:SetPoint("RIGHT", chart, "BOTTOMLEFT", chart.plotLeft - 8, y)
            label:SetJustifyH("RIGHT")
            local val = maxTime * (index / 4)
            local text = val <= 0 and "" or FormatDuration(val)
            label:SetText(text)
            label:SetTextColor(0.78, 0.78, 0.78)
        end

        local colGap = 15
        local leftPadding = 15
        local barWidth = math.min(50, (plotWidth - leftPadding - (numBars - 1) * colGap) / numBars)
        local startX = chart.plotLeft + leftPadding

        for i = 1, numBars do
            local data = activeDataList[i]
            local x = startX + (i - 1) * (barWidth + colGap) + barWidth / 2
            local barHeight = (data.time / maxTime) * plotHeight

            local bar = AcquireTexture(chart.bars, i, chart, "ARTWORK")
            bar:ClearAllPoints()
            local r, g, b = GetClassColor(data.classFile)
            bar:SetColorTexture(r, g, b, 0.7)
            bar:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x - barWidth/2, chart.plotBottom)
            bar:SetSize(barWidth, math.max(1, barHeight))

            local topLabel = AcquireFontString(chart.xLabels, i, chart, "GameFontNormalSmall")
            topLabel:ClearAllPoints()
            topLabel:SetPoint("BOTTOM", chart, "BOTTOMLEFT", x, chart.plotBottom + barHeight + 4)
            local pct = totalPlayed > 0 and (data.time / totalPlayed * 100) or 0
            topLabel:SetText(string.format("%.1f%%", pct))
            topLabel:SetTextColor(0.9, 0.9, 0.9)
            topLabel:Show()

            local iconTexture, iconCoords = GetCharacterIcon(data)
            local iconFrame = chart.xIcons and chart.xIcons[i]
            if not iconFrame then
                iconFrame = CreateFrame("Frame", nil, chart)
                iconFrame:SetSize(20, 20)
                iconFrame.tex = iconFrame:CreateTexture(nil, "ARTWORK")
                iconFrame.tex:SetAllPoints()
                chart.xIcons = chart.xIcons or {}
                chart.xIcons[i] = iconFrame
            end
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("TOP", chart, "BOTTOMLEFT", x, chart.plotBottom - 6)
            iconFrame.tex:SetTexture(iconTexture)
            if iconCoords then
                iconFrame.tex:SetTexCoord(iconCoords[1], iconCoords[2], iconCoords[3], iconCoords[4])
            else
                iconFrame.tex:SetTexCoord(0, 1, 0, 1)
            end
            iconFrame:Show()

            local mouseFrame = chart.barButtons[i]
            if not mouseFrame then
                mouseFrame = CreateFrame("Frame", nil, chart)
                mouseFrame:EnableMouse(true)
                chart.barButtons[i] = mouseFrame
            end
            mouseFrame:ClearAllPoints()
            mouseFrame:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x - barWidth/2, chart.plotBottom)
            mouseFrame:SetSize(barWidth, math.max(20, barHeight))
            mouseFrame:Show()
            mouseFrame.aggregatedData = data
            mouseFrame.pct = pct
            mouseFrame.barTexture = bar

            mouseFrame:SetScript("OnEnter", function(self)
                if not self.aggregatedData then return end
                self.barTexture:SetColorTexture(r, g, b, 0.9)

                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(self.aggregatedData.name, 1, 0.82, 0)
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddDoubleLine("Total Played:", FormatDuration(self.aggregatedData.time), 0.7, 0.7, 0.7, 1, 0.82, 0)
                GameTooltip:AddDoubleLine("Percentage of Total:", string.format("%.1f%%", self.pct or 0), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
                GameTooltip:AddDoubleLine("Characters:", tostring(self.aggregatedData.charCount), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
                GameTooltip:AddLine(" ", 1, 1, 1)

                GameTooltip:AddLine("Contributing Characters:", 1, 0.82, 0)
                for _, char in ipairs(self.aggregatedData.characters) do
                    local charPlayed = mQoL_AccountOverview:GetDisplayedPlayedTime(char) or 0
                    local charColor = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[char.classFile] or NORMAL_FONT_COLOR
                    local specStr = char.specName and (" (" .. char.specName .. ")") or ""
                    GameTooltip:AddDoubleLine(
                        string.format("%s - %s (Lvl %d%s)", char.name, char.realm, char.level, specStr),
                        FormatDuration(charPlayed),
                        charColor.r, charColor.g, charColor.b,
                        1, 1, 1
                    )
                end
                GameTooltip:Show()
            end)

            mouseFrame:SetScript("OnLeave", function(self)
                self.barTexture:SetColorTexture(r, g, b, 0.7)
                GameTooltip:Hide()
            end)
        end

        view.contentHeight = 45 + 360 + 20
        view:SetHeight(view.contentHeight)

    -- 3. Pie/Donut Chart Mode
    elseif chartType == "DIST" then
        local pieFrame = view.distArea.pieFrame
        local HighlightClass, ResetHighlight

        HidePool(view.distArea.segments)
        HidePool(view.distArea.segmentButtons)

        pieFrame:Show()

        pieFrame.centerTextValue:SetText(FormatDuration(totalPlayed))

        HidePool(view.distArea.pieLines)
        HidePool(view.distArea.pieLabelLines)
        HidePool(view.distArea.pieLabelTexts)

        local numSegments = #activeDataList
        local numRows = math.ceil(numSegments / 2)
        local legendHeight = 0
        local currentAngle = 0
        for index, data in ipairs(activeDataList) do
            local pct = totalPlayed > 0 and (data.time / totalPlayed) or 0
            local degrees = pct * 360
            data.startAngle = currentAngle
            data.endAngle = currentAngle + degrees
            currentAngle = currentAngle + degrees
        end

        local R_outer = 140
        local R_inner = 90

        -- Draw the slices (720 steps = 0.5 degrees per step for high density/no visual gaps)
        local lineIndex = 1
        for step = 1, 720 do
            local degree = (step - 0.5) / 2
            local angle = 90 - degree
            local rad = math.rad(angle)

            local segment = nil
            for _, data in ipairs(activeDataList) do
                if degree >= data.startAngle and degree < data.endAngle then
                    segment = data
                    break
                end
            end

            if segment then
                local line = AcquireLine(view.distArea.pieLines, lineIndex, pieFrame, "ARTWORK")
                lineIndex = lineIndex + 1

                local r, g, b = GetClassColor(segment.classFile)
                line.r, line.g, line.b = r, g, b
                line.classFile = segment.classFile

                local x1 = R_inner * math.cos(rad)
                local y1 = R_inner * math.sin(rad)
                local x2 = R_outer * math.cos(rad)
                local y2 = R_outer * math.sin(rad)

                if pieFrame.CreateLine then
                    line:SetColorTexture(r, g, b, 0.85)
                    line:SetThickness(3.5)
                    line:SetStartPoint("CENTER", x1, y1)
                    line:SetEndPoint("CENTER", x2, y2)
                    line:Show()
                else
                    line:ClearAllPoints()
                    line:SetTexture("Interface\\BUTTONS\\WHITE8X8")
                    line:SetVertexColor(r, g, b, 0.85)
                    line:SetSize(4, 4)
                    line:SetPoint("CENTER", pieFrame, "CENTER", x2, y2)
                end
            end
        end

        for i = lineIndex, #(view.distArea.pieLines or {}) do
            if view.distArea.pieLines[i] then view.distArea.pieLines[i]:Hide() end
        end

        -- Callout lines and labels with Anti-Collision vertical alignment
        local rightLabels = {}
        local leftLabels = {}

        for _, data in ipairs(activeDataList) do
            local pct = totalPlayed > 0 and (data.time / totalPlayed) or 0
            if data.time > 0 then -- draw callouts for any class with played time
                local midDegree = (data.startAngle + data.endAngle) / 2
                local midAngle = 90 - midDegree
                local midRad = math.rad(midAngle)

                local x1 = R_outer * math.cos(midRad)
                local y1 = R_outer * math.sin(midRad)
                local x2 = (R_outer + 25) * math.cos(midRad)
                local y2 = (R_outer + 25) * math.sin(midRad)
                local isRightSide = x2 >= 0

                local labelNode = {
                    data = data,
                    pct = pct,
                    midRad = midRad,
                    x1 = x1,
                    y1 = y1,
                    x2 = x2,
                    y2 = y2,
                    isRightSide = isRightSide,
                }
                if isRightSide then
                    table.insert(rightLabels, labelNode)
                else
                    table.insert(leftLabels, labelNode)
                end
            end
        end

        -- Sort by original y coordinate descending (highest Y first)
        table.sort(rightLabels, function(a, b) return a.y2 > b.y2 end)
        table.sort(leftLabels, function(a, b) return a.y2 > b.y2 end)

        -- Spacing adjustment pass
        local minDistance = 19
        local function AdjustHemisphereY(labels)
            if #labels <= 1 then return end
            -- Top-to-bottom pass
            for i = 2, #labels do
                if (labels[i-1].y2 - labels[i].y2) < minDistance then
                    labels[i].y2 = labels[i-1].y2 - minDistance
                end
            end
            -- Bottom-to-top pass (to prevent excessive bottom shifts)
            for i = #labels - 1, 1, -1 do
                if (labels[i].y2 - labels[i+1].y2) < minDistance then
                    labels[i].y2 = labels[i+1].y2 + minDistance
                end
            end
        end

        AdjustHemisphereY(rightLabels)
        AdjustHemisphereY(leftLabels)

        local labelLineIndex = 1
        local labelTextIndex = 1

        local function DrawLabels(labels)
            for _, node in ipairs(labels) do
                local r, g, b = GetClassColor(node.data.classFile)

                local x1, y1 = node.x1, node.y1
                local isRightSide = node.isRightSide
                local y_elbow = node.y2
                local x3 = isRightSide and 185 or -185
                local y3 = y_elbow

                local useLShape = false
                if y1 > 0 and y_elbow > y1 then
                    useLShape = true
                elseif y1 < 0 and y_elbow < y1 then
                    useLShape = true
                end

                local line1 = AcquireLine(view.distArea.pieLabelLines, labelLineIndex, pieFrame, "ARTWORK")
                labelLineIndex = labelLineIndex + 1
                line1.classFile = node.data.classFile

                local line2 = AcquireLine(view.distArea.pieLabelLines, labelLineIndex, pieFrame, "ARTWORK")
                labelLineIndex = labelLineIndex + 1
                line2.classFile = node.data.classFile

                local line3 = AcquireLine(view.distArea.pieLabelLines, labelLineIndex, pieFrame, "ARTWORK")
                labelLineIndex = labelLineIndex + 1
                line3.classFile = node.data.classFile

                if useLShape then
                    -- L-Shape routing (2 segments: vertical, then horizontal)
                    if pieFrame.CreateLine then
                        line1:SetColorTexture(r, g, b, 0.5)
                        line1:SetThickness(1.2)
                        line1:SetStartPoint("CENTER", x1, y1)
                        line1:SetEndPoint("CENTER", x1, y_elbow)
                        line1:Show()

                        line2:SetColorTexture(r, g, b, 0.5)
                        line2:SetThickness(1.2)
                        line2:SetStartPoint("CENTER", x1, y_elbow)
                        line2:SetEndPoint("CENTER", x3, y3)
                        line2:Show()

                        line3:Hide()
                    else
                        line1:Hide()
                        line2:Hide()

                        line3:ClearAllPoints()
                        line3:SetTexture("Interface\\BUTTONS\\WHITE8X8")
                        line3:SetVertexColor(r, g, b, 0.85)
                        line3:SetSize(4, 4)
                        line3:SetPoint("CENTER", pieFrame, "CENTER", x1, y_elbow)
                        line3:Show()
                    end
                else
                    -- Standard 3-segment slanted routing
                    local R_radial = R_outer + 12
                    local x_radial = R_radial * math.cos(node.midRad)
                    local y_radial = R_radial * math.sin(node.midRad)
                    local x_elbow = isRightSide and 170 or -170

                    if pieFrame.CreateLine then
                        line1:SetColorTexture(r, g, b, 0.5)
                        line1:SetThickness(1.2)
                        line1:SetStartPoint("CENTER", x1, y1)
                        line1:SetEndPoint("CENTER", x_radial, y_radial)
                        line1:Show()

                        line2:SetColorTexture(r, g, b, 0.5)
                        line2:SetThickness(1.2)
                        line2:SetStartPoint("CENTER", x_radial, y_radial)
                        line2:SetEndPoint("CENTER", x_elbow, y_elbow)
                        line2:Show()

                        line3:SetColorTexture(r, g, b, 0.5)
                        line3:SetThickness(1.2)
                        line3:SetStartPoint("CENTER", x_elbow, y_elbow)
                        line3:SetEndPoint("CENTER", x3, y3)
                        line3:Show()
                    else
                        line1:Hide()
                        line2:Hide()

                        line3:ClearAllPoints()
                        line3:SetTexture("Interface\\BUTTONS\\WHITE8X8")
                        line3:SetVertexColor(r, g, b, 0.85)
                        line3:SetSize(4, 4)
                        line3:SetPoint("CENTER", pieFrame, "CENTER", x_elbow, y_elbow)
                        line3:Show()
                    end
                end

                local labelFrame = view.distArea.pieLabelTexts[labelTextIndex]
                if labelFrame and labelFrame.text and labelFrame.text:GetParent() ~= pieFrame then
                    labelFrame.text:Hide()
                    labelFrame.text = nil
                end

                if not labelFrame then
                    labelFrame = CreateFrame("Frame", nil, pieFrame)
                    labelFrame:EnableMouse(true)
                    view.distArea.pieLabelTexts[labelTextIndex] = labelFrame
                end

                if not labelFrame.text then
                    labelFrame.text = pieFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    labelFrame:SetScript("OnHide", function(self)
                        if self.text then self.text:Hide() end
                    end)
                    labelFrame:SetScript("OnShow", function(self)
                        if self.text then self.text:Show() end
                    end)
                end

                labelFrame:Show()
                labelFrame.text:Show()
                labelTextIndex = labelTextIndex + 1
                labelFrame.classFile = node.data.classFile

                labelFrame.text:SetText(string.format("%s %.1f%%", node.data.name, node.pct * 100))
                labelFrame.text:SetTextColor(r, g, b)

                -- Anchor the FontString to the pie frame first, so its position is calculated
                labelFrame.text:ClearAllPoints()
                if node.isRightSide then
                    labelFrame.text:SetPoint("LEFT", pieFrame, "CENTER", x3 + 5, y3)
                    labelFrame.text:SetJustifyH("LEFT")
                else
                    labelFrame.text:SetPoint("RIGHT", pieFrame, "CENTER", x3 - 5, y3)
                    labelFrame.text:SetJustifyH("RIGHT")
                end

                -- Then anchor the mouse-sensitive labelFrame around the FontString text bounds
                labelFrame:ClearAllPoints()
                labelFrame:SetPoint("TOPLEFT", labelFrame.text, "TOPLEFT", -4, 4)
                labelFrame:SetPoint("BOTTOMRIGHT", labelFrame.text, "BOTTOMRIGHT", 4, -4)

                -- Mouse scripts on label text frame
                labelFrame:SetScript("OnEnter", function(self)
                    HighlightClass(node.data.classFile)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:AddLine(node.data.name, 1, 0.82, 0)
                    GameTooltip:AddLine(" ", 1, 1, 1)
                    local pct = totalPlayed > 0 and (node.data.time / totalPlayed * 100) or 0
                    GameTooltip:AddDoubleLine("Total Played:", FormatDuration(node.data.time), 0.7, 0.7, 0.7, 1, 0.82, 0)
                    GameTooltip:AddDoubleLine("Percentage of Total:", string.format("%.1f%%", pct), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
                    GameTooltip:AddDoubleLine("Characters:", tostring(node.data.charCount), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
                    GameTooltip:AddLine(" ", 1, 1, 1)

                    GameTooltip:AddLine("Contributing Characters:", 1, 0.82, 0)
                    for _, char in ipairs(node.data.characters) do
                        local charPlayed = mQoL_AccountOverview:GetDisplayedPlayedTime(char) or 0
                        local charColor = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[char.classFile] or NORMAL_FONT_COLOR
                        local specStr = char.specName and (" (" .. char.specName .. ")") or ""
                        GameTooltip:AddDoubleLine(
                            string.format("%s - %s (Lvl %d%s)", char.name, char.realm, char.level, specStr),
                            FormatDuration(charPlayed),
                            charColor.r, charColor.g, charColor.b,
                            1, 1, 1
                        )
                    end
                    GameTooltip:Show()
                end)

                labelFrame:SetScript("OnLeave", function()
                    ResetHighlight()
                    GameTooltip:Hide()
                end)
            end
        end

        DrawLabels(rightLabels)
        DrawLabels(leftLabels)

        for i = labelLineIndex, #(view.distArea.pieLabelLines or {}) do
            if view.distArea.pieLabelLines[i] then view.distArea.pieLabelLines[i]:Hide() end
        end

        for i = labelTextIndex, #(view.distArea.pieLabelTexts or {}) do
            local frame = view.distArea.pieLabelTexts[i]
            if frame then
                frame:Hide()
                if frame.text then frame.text:Hide() end
            end
        end

        HighlightClass = function(classFile)
            for _, line in ipairs(view.distArea.pieLines) do
                if line:IsShown() then
                    if not classFile or line.classFile == classFile then
                        line:SetAlpha(1.0)
                    else
                        line:SetAlpha(0.2)
                    end
                end
            end
            for _, line in ipairs(view.distArea.pieLabelLines) do
                if line:IsShown() then
                    if not classFile or line.classFile == classFile then
                        line:SetAlpha(1.0)
                    else
                        line:SetAlpha(0.2)
                    end
                end
            end
            for _, txt in ipairs(view.distArea.pieLabelTexts) do
                if txt:IsShown() then
                    if not classFile or txt.classFile == classFile then
                        txt:SetAlpha(1.0)
                    else
                        txt:SetAlpha(0.25)
                    end
                end
            end
        end

        ResetHighlight = function()
            for _, line in ipairs(view.distArea.pieLines) do
                if line:IsShown() then
                    line:SetAlpha(1.0)
                end
            end
            for _, line in ipairs(view.distArea.pieLabelLines) do
                if line:IsShown() then
                    line:SetAlpha(1.0)
                end
            end
            for _, txt in ipairs(view.distArea.pieLabelTexts) do
                if txt:IsShown() then
                    txt:SetAlpha(1.0)
                end
            end
        end

        pieFrame:SetScript("OnEnter", function(self)
            self:SetScript("OnUpdate", function(self, elapsed)
                if not self:IsMouseOver() then
                    if self.isHovered then
                        self.isHovered = false
                        self.lastHoveredSeg = nil
                        ResetHighlight()
                        GameTooltip:Hide()
                    end
                    return
                end

                local x, y = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                x, y = x / scale, y / scale
                local cx, cy = self:GetCenter()
                local dx = x - cx
                local dy = y - cy
                local distance = math.sqrt(dx*dx + dy*dy)

                if distance >= R_inner and distance <= R_outer then
                    local mAngle = math.deg(math.atan2(dy, dx))
                    local deg = 90 - mAngle
                    if deg < 0 then
                        deg = deg + 360
                    elseif deg >= 360 then
                        deg = deg - 360
                    end

                    local hoveredSeg = nil
                    for _, data in ipairs(activeDataList) do
                        if deg >= data.startAngle and deg < data.endAngle then
                            hoveredSeg = data
                            break
                        end
                    end

                    if hoveredSeg ~= self.lastHoveredSeg then
                        self.lastHoveredSeg = hoveredSeg
                        if hoveredSeg then
                            self.isHovered = true
                            HighlightClass(hoveredSeg.classFile)

                            GameTooltip:SetOwner(self, "ANCHOR_TOP")
                            GameTooltip:ClearLines()
                            GameTooltip:AddLine(hoveredSeg.name, 1, 0.82, 0)
                            GameTooltip:AddLine(" ", 1, 1, 1)
                            local pct = totalPlayed > 0 and (hoveredSeg.time / totalPlayed * 100) or 0
                            GameTooltip:AddDoubleLine("Total Played:", FormatDuration(hoveredSeg.time), 0.7, 0.7, 0.7, 1, 0.82, 0)
                            GameTooltip:AddDoubleLine("Percentage of Total:", string.format("%.1f%%", pct), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
                            GameTooltip:AddDoubleLine("Characters:", tostring(hoveredSeg.charCount), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
                            GameTooltip:AddLine(" ", 1, 1, 1)

                            GameTooltip:AddLine("Contributing Characters:", 1, 0.82, 0)
                            for _, char in ipairs(hoveredSeg.characters) do
                                local charPlayed = mQoL_AccountOverview:GetDisplayedPlayedTime(char) or 0
                                local charColor = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[char.classFile] or NORMAL_FONT_COLOR
                                local specStr = char.specName and (" (" .. char.specName .. ")") or ""
                                GameTooltip:AddDoubleLine(
                                    string.format("%s - %s (Lvl %d%s)", char.name, char.realm, char.level, specStr),
                                    FormatDuration(charPlayed),
                                    charColor.r, charColor.g, charColor.b,
                                    1, 1, 1
                                )
                            end
                            GameTooltip:Show()
                        else
                            self.isHovered = false
                            ResetHighlight()
                            GameTooltip:Hide()
                        end
                    end
                else
                    if self.lastHoveredSeg ~= nil then
                        self.lastHoveredSeg = nil
                        self.isHovered = false
                        ResetHighlight()
                        GameTooltip:Hide()
                    end
                end
            end)
        end)

        pieFrame:SetScript("OnLeave", function(self)
            self:SetScript("OnUpdate", nil)
            self.lastHoveredSeg = nil
            if self.isHovered then
                self.isHovered = false
                ResetHighlight()
                GameTooltip:Hide()
            end
        end)

        pieFrame:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
            self.lastHoveredSeg = nil
            self.isHovered = false
            ResetHighlight()
            GameTooltip:Hide()
        end)

        view.distArea:SetHeight(370 + legendHeight + 10)

        view.contentHeight = 45 + (370 + legendHeight + 10) + 10
        view:SetHeight(view.contentHeight)
    end

    if self.activeTab == "Played Time" and self.viewsHost then
        local bottomPadding = 10
        self.viewsHost:SetHeight(view.contentHeight)
        self.contentContainer.currentY = self.viewsAnchorY - view.contentHeight - bottomPadding
        if self.panel and self.panel.UpdateScrollChildHeight then
            self.panel.UpdateScrollChildHeight()
        end
    end
end

function mQoL_AccountOverview:ResetGoldRangeForHubOpen()
    if not self.db then
        self:InitializeDB()
    end

    if self.db and self.db.settings then
        self.db.settings.selectedGoldRange = "overall"
    end

    self.zoomMinTS = nil
    self.zoomMaxTS = nil
    if self.goldChartView and self.goldChartView.resetZoomBtn then
        self.goldChartView.resetZoomBtn:Hide()
    end

    if self.optionsScrollFrame and self.optionsScrollFrame:IsShown() then
        self:RefreshGoldChartView()
    end
end

function mQoL_AccountOverview:SetActiveTab(tabName, forceRefresh)
    if not self.views or not self.views[tabName] then
        return
    end

    local previousTab = self.activeTab
    if previousTab ~= tabName or tabName ~= "Characters" then
        self:HideProfessionDetailFrame()
    end

    local tabChanged = (previousTab ~= tabName)
    self.activeTab = tabName
    if self.db and self.db.settings then
        self.db.settings.selectedTab = tabName
    end

    if tabChanged or forceRefresh then
        if tabName == "Characters" then
            self:RefreshCharactersView()
        elseif tabName == "Gold Chart" then
            self:RefreshGoldChartView()
        elseif tabName == "Played Time" then
            if self.RefreshPlayedTimeView then
                self:RefreshPlayedTimeView()
            end
        end
    end

    for name, view in pairs(self.views) do
        view:SetShown(name == tabName)
    end

    for name, button in pairs(self.tabButtons or {}) do
        button:SetActive(name == tabName)
    end

    if tabName == "Characters" or tabName == "Played Time" then
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

    local activeTab = self.activeTab or (self.db and self.db.settings and self.db.settings.selectedTab) or "Characters"

    self:SetActiveTab(activeTab, true)
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

    local playedTimeButton = CreateTabButton(tabsFrame, "Played Time", 150)
    playedTimeButton:SetPoint("LEFT", goldButton, "RIGHT", 10, 0)

    self.tabButtons["Characters"] = charactersButton
    self.tabButtons["Gold Chart"] = goldButton
    self.tabButtons["Played Time"] = playedTimeButton
    contentContainer.optionsLabels["Characters"] = charactersButton.text
    contentContainer.optionsLabels["Gold Chart"] = goldButton.text
    contentContainer.optionsLabels["Played Time"] = playedTimeButton.text

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
    if self.EnsurePlayedTimeView then
        self:EnsurePlayedTimeView()
    end

    charactersButton:SetScript("OnClick", function()
        mQoL_AccountOverview:SetActiveTab("Characters")
    end)

    goldButton:SetScript("OnClick", function()
        mQoL_AccountOverview:SetActiveTab("Gold Chart")
    end)

    playedTimeButton:SetScript("OnClick", function()
        mQoL_AccountOverview:SetActiveTab("Played Time")
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
RegisterAccountOverviewEvent("PLAYER_SPECIALIZATION_CHANGED")
RegisterAccountOverviewEvent("ACTIVE_TALENT_GROUP_CHANGED")
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
        mQoL_AccountOverview:StartPeriodicTracker()
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
        mQoL_AccountOverview:StartPeriodicTracker()
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
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshStatic = true,
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
        mQoL_AccountOverview:StopPeriodicTracker()
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
