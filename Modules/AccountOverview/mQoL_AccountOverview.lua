local addonName, L = ...
mQoL_AccountOverview = mQoL_AccountOverview or {}

local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
    return
end

local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local CreateCustomButton = mQoL_Styles and mQoL_Styles.CreateCustomButton
local CreateFrameBorder = mQoL_Templates and mQoL_Templates.CreateFrameBorder

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

local HISTORY_MAX_POINTS = 20000
local HISTORY_RECENT_POINTS = 4000
local HISTORY_MERGE_WINDOW = 15 * SECONDS_PER_MINUTE
local HISTORY_CHART_POINTS = 64
local OVERALL_DISPLAY_MIN_INTERVAL = 10 * SECONDS_PER_MINUTE
local PLAYED_REQUEST_COOLDOWN = 10
local PLAYED_DATA_STALE_AFTER = 6 * SECONDS_PER_HOUR
local BOOTSTRAP_SYNC_INTERVAL = 2
local BOOTSTRAP_SYNC_ATTEMPTS = 15
local OVERALL_ARCHIVE_MAX_POINTS = 12

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
    },
    characters = {},
    goldHistory = {},
    overallArchive = {
        weekly = {},
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
        schemaVersion = 6,
    },
}

mQoL_AccountOverview_DB = mQoL_AccountOverview_DB or {}

local function TableCopy(src)
    if type(src) ~= "table" then
        return src
    end

    local dest = {}
    for key, value in pairs(src) do
        dest[key] = TableCopy(value)
    end

    return dest
end

local function GetNow()
    return time()
end

local function IsBootstrapMoneyWindow(session, now)
    local loginAt = session and session.loginAt or 0
    return loginAt > 0 and (now - loginAt) <= ((BOOTSTRAP_SYNC_INTERVAL * BOOTSTRAP_SYNC_ATTEMPTS) + 5)
end

local function BuildGoldSnapshotData(warboundGold, characterGold)
    warboundGold = math.floor(tonumber(warboundGold) or 0)
    characterGold = math.floor(tonumber(characterGold) or 0)
    return {
        WarboundGold = warboundGold,
        CharacterGold = characterGold,
        OverallGold = warboundGold + characterGold,
    }
end

local function NormalizeGoldSnapshotData(rawValue)
    if type(rawValue) ~= "table" then
        return BuildGoldSnapshotData(0, rawValue)
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

    local normalized = BuildGoldSnapshotData(warboundGold, characterGold)
    normalized.OverallGold = overallGold
    normalized.total = overallGold
    return normalized
end

local function GetCurrentCharacterIdentity()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    local realmKey = realm:gsub("%s", "")
    return realmKey .. "-" .. name, name, realm
end

local function GetClassColor(classFile)
    local color = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r or 1, color.g or 1, color.b or 1
    end
    return 1, 1, 1
end

local function FormatLargeNumber(value)
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

local function FormatMoneyCompact(copper)
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
        return string.format("%s%s.%02dg", sign, FormatLargeNumber(gold), silver)
    end

    if silver > 0 then
        return string.format("%s%ds %dc", sign, silver, copperRemainder)
    end

    return string.format("%s%dc", sign, copperRemainder)
end

local function FormatAxisMoney(copper)
    local gold = (tonumber(copper) or 0) / 10000
    if gold >= 1000000 then
        return string.format("%.1fm", gold / 1000000)
    end
    if gold >= 1000 then
        return string.format("%.1fk", gold / 1000)
    end
    return string.format("%.0fg", gold)
end

local function FormatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds <= 0 then
        return "Unknown"
    end

    local days = math.floor(seconds / SECONDS_PER_DAY)
    local hours = math.floor((seconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR)
    local minutes = math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    end
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", minutes)
end

local function FormatTimestamp(timestamp)
    if not timestamp or timestamp <= 0 then
        return "Unknown"
    end
    return date("%d %b %Y %H:%M", timestamp)
end

local function GetProfessionSnapshot()
    local result = {
        primary = {},
        secondary = {},
    }

    if not GetProfessions or not GetProfessionInfo then
        return result
    end

    local primaryOne, primaryTwo, archaeology, fishing, cooking, firstAid = GetProfessions()

    local function Add(list, professionIndex)
        if not professionIndex then
            return
        end

        local name, icon, rank, maxRank = GetProfessionInfo(professionIndex)
        if not name then
            return
        end

        table.insert(list, {
            name = name,
            icon = icon,
            rank = rank or 0,
            maxRank = maxRank or 0,
        })
    end

    Add(result.primary, primaryOne)
    Add(result.primary, primaryTwo)
    Add(result.secondary, cooking)
    Add(result.secondary, fishing)
    Add(result.secondary, archaeology)
    Add(result.secondary, firstAid)

    return result
end

local function FormatProfessionList(professions)
    if type(professions) ~= "table" then
        return "No professions"
    end

    local source = professions.primary
    if type(source) ~= "table" or #source == 0 then
        source = professions.secondary
    end

    if type(source) ~= "table" or #source == 0 then
        return "No professions"
    end

    local parts = {}
    for index, entry in ipairs(source) do
        if index > 2 then
            break
        end

        if entry.maxRank and entry.maxRank > 0 then
            parts[#parts + 1] = string.format("%s %d/%d", entry.name or "Unknown", entry.rank or 0, entry.maxRank)
        elseif entry.rank and entry.rank > 0 then
            parts[#parts + 1] = string.format("%s %d", entry.name or "Unknown", entry.rank)
        else
            parts[#parts + 1] = entry.name or "Unknown"
        end
    end

    if #parts == 0 then
        return "No professions"
    end

    return table.concat(parts, " / ")
end

local function HasProfessionData(professions)
    if type(professions) ~= "table" then
        return false
    end

    local primary = professions.primary
    if type(primary) == "table" and #primary > 0 then
        return true
    end

    local secondary = professions.secondary
    if type(secondary) == "table" and #secondary > 0 then
        return true
    end

    return false
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
        mQoL_AccountOverview_DB.Account = TableCopy(mQoL_AccountOverview.defaults)
    end

    local accountDB = mQoL_AccountOverview_DB.Account
    accountDB.settings = accountDB.settings or TableCopy(mQoL_AccountOverview.defaults.settings)
    accountDB.characters = accountDB.characters or {}
    accountDB.goldHistory = accountDB.goldHistory or {}
    accountDB.overallArchive = accountDB.overallArchive or TableCopy(mQoL_AccountOverview.defaults.overallArchive)
    accountDB.chartBuckets = accountDB.chartBuckets or TableCopy(mQoL_AccountOverview.defaults.chartBuckets)
    accountDB.chartMeta = accountDB.chartMeta or TableCopy(mQoL_AccountOverview.defaults.chartMeta)
    accountDB.accountBank = accountDB.accountBank or TableCopy(mQoL_AccountOverview.defaults.accountBank)
    accountDB.meta = accountDB.meta or TableCopy(mQoL_AccountOverview.defaults.meta)

    local schemaVersion = tonumber(accountDB.meta.schemaVersion) or 0
    if schemaVersion < 3 then
        accountDB.settings.selectedGoldRange = "overall"
    end

    if schemaVersion < 5 then
        accountDB.overallArchive = TableCopy(mQoL_AccountOverview.defaults.overallArchive)
    end

    if type(accountDB.overallArchive.weekly) ~= "table" then
        accountDB.overallArchive.weekly = {}
    end
    if type(accountDB.overallArchive.currentWeekKey) ~= "string" then
        accountDB.overallArchive.currentWeekKey = nil
    end

    accountDB.meta.schemaVersion = 6

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
        return 72
    end
    if rangeKey == "weekly" then
        return 35
    end
    if rangeKey == "monthly" then
        return 26
    end
    if rangeKey == "yearly" then
        return 24
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
        return "Week" .. tostring(index or windowSize or 0)
    end
    if rangeKey == "yearly" then
        return date("%b", bucketKey)
    end
    return date("%d %b", bucketKey)
end

local function NormalizeGoldHistory(history)
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
    self.db.goldHistory = NormalizeGoldHistory(self.db.goldHistory)
    self.currentCharacterKey = select(1, GetCurrentCharacterIdentity())
    self.session = self.session or {}
    self.session.loginAt = GetNow()
    self.session.bootstrapAttempts = 0
    self.session.moneyCharacterKey = self.currentCharacterKey
    self.session.hasReliableMoney = false
    self.session.lastReliableMoney = nil
    self:PruneGoldHistory(GetNow())
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

function mQoL_AccountOverview:AppendOverallSnapshot(goldData, timestamp, forceSnapshot)
    if not self.db then
        return
    end

    local history = self.db.goldHistory
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
        self:PruneGoldHistory()
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

    self:PruneGoldHistory()
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

    self.db.chartBuckets = self.db.chartBuckets or TableCopy(mQoL_AccountOverview.defaults.chartBuckets)
    self.db.chartMeta = self.db.chartMeta or TableCopy(mQoL_AccountOverview.defaults.chartMeta)
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

    local changed = false
    local guard = 0
    while previousBucketKey < currentBucketKey and guard < 64 do
        store[tostring(previousBucketKey)] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        changed = true
        previousBucketKey = AdvanceRangeBucketKey(rangeKey, previousBucketKey)
        guard = guard + 1
    end

    meta.currentKey = currentBucketKey

    if changed then
        self:PruneRangeStore(rangeKey)
    end

    return changed
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
        self:AppendOverallSnapshot(goldData, observedAt, true)
    end
end

function mQoL_AccountOverview:ProcessOverallArchive(goldData, observedAt)
    if not self.db then
        return false
    end

    self.db.overallArchive = self.db.overallArchive or TableCopy(mQoL_AccountOverview.defaults.overallArchive)
    goldData = NormalizeGoldSnapshotData(goldData)

    local archive = self.db.overallArchive
    archive.weekly = archive.weekly or {}

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

    while previousWeekStart < currentWeekStart do
        archive.weekly[GetLongTermArchiveKey(previousWeekStart)] = BuildGoldSnapshotData(goldData.WarboundGold, goldData.CharacterGold)
        previousWeekStart = ShiftDays(previousWeekStart, 7)
    end

    archive.currentWeekKey = currentWeekKey
    return true
end

function mQoL_AccountOverview:PruneGoldHistory(referenceTime)
    if not self.db then
        return
    end

    local history = NormalizeGoldHistory(self.db.goldHistory)
    local now = math.floor(tonumber(referenceTime) or GetNow())
    local currentDayStart = GetStartOfDay(now)
    local filtered = {}

    for _, entry in ipairs(history) do
        if (tonumber(entry.ts) or 0) >= currentDayStart then
            filtered[#filtered + 1] = entry
        end
    end

    history = filtered

    if #history <= HISTORY_MAX_POINTS then
        self.db.goldHistory = history
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

    self.db.goldHistory = compacted
end

function mQoL_AccountOverview:RecordGoldSnapshot(forceSnapshot, goldData)
    if not self.db then
        return
    end

    goldData = goldData or self:GetGoldSnapshotData()
    local now = GetNow()
    self:AppendOverallSnapshot(goldData, now, forceSnapshot)
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
        local fetchedProfessions = GetProfessionSnapshot()
        if HasProfessionData(fetchedProfessions) or not HasProfessionData(character.professions) then
            character.professions = fetchedProfessions
        end
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
    self:RecordGoldSnapshot(opts.forceGoldSnapshot, goldData)
    self:RefreshPanelIfVisible()
end

function mQoL_AccountOverview:GetKnownCharacters()
    if not self.db then
        return {}
    end

    local currentKey = select(1, GetCurrentCharacterIdentity())
    local characters = {}

    for key, data in pairs(self.db.characters) do
        if type(data) == "table" then
            local row = TableCopy(data)
            row.key = key
            row.isCurrent = key == currentKey
            characters[#characters + 1] = row
        end
    end

    table.sort(characters, function(a, b)
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
    { key = "name", label = "Character", x = 12, width = 200, justify = "LEFT" },
    { key = "class", label = "Class / Level", x = 220, width = 100, justify = "LEFT" },
    { key = "professions", label = "Professions", x = 330, width = 230, justify = "LEFT" },
    { key = "played", label = "Played", x = 570, width = 90, justify = "LEFT" },
    { key = "gold", label = "Gold", x = 665, width = 90, justify = "RIGHT" },
}

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
    view.summaryText:SetTextColor(1, 0.82, 0)

    view.noteText = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.noteText:SetPoint("TOPLEFT", view.summaryText, "BOTTOMLEFT", 0, -6)
    view.noteText:SetTextColor(0.85, 0.85, 0.85)
    view.noteText:SetText("Played time refreshes for the current character when this tab opens.")

    view.header = CreateFrame("Frame", nil, view)
    view.header:SetSize(770, 26)
    view.header:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -44)

    view.header.bg = view.header:CreateTexture(nil, "BACKGROUND")
    view.header.bg:SetAllPoints()
    view.header.bg:SetColorTexture(0.1, 0.1, 0.1, 0.95)

    if CreateFrameBorder then
        view.header.border = CreateFrameBorder(view.header, 1, { 0.22, 0.22, 0.22, 1 })
    end

    view.header.labels = {}
    for _, column in ipairs(CHARACTER_COLUMNS) do
        local label = view.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", view.header, "LEFT", column.x, 0)
        label:SetWidth(column.width)
        label:SetJustifyH(column.justify)
        label:SetText(column.label)
        label:SetTextColor(0.9, 0.9, 0.9)
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

    row.fonts = {}
    for _, column in ipairs(CHARACTER_COLUMNS) do
        local font = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        font:SetPoint("LEFT", row, "LEFT", column.x, 0)
        font:SetWidth(column.width)
        font:SetJustifyH(column.justify)
        font:SetWordWrap(false)
        row.fonts[column.key] = font
    end

    view.rows[index] = row
    return row
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

    for _, row in ipairs(view.rows) do
        row:Hide()
    end

    if #characters == 0 then
        view.emptyState:Show()
        view:SetHeight(150)
        view.contentHeight = 150
        return
    end

    view.emptyState:Hide()

    local startY = -74
    local rowHeight = 30

    for index, character in ipairs(characters) do
        local row = self:EnsureCharacterRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, startY - ((index - 1) * rowHeight))
        row.bg:SetColorTexture(index % 2 == 1 and 0.07 or 0.09, index % 2 == 1 and 0.07 or 0.09, index % 2 == 1 and 0.07 or 0.09, 0.92)

        local displayName = string.format("%s - %s", character.name or "Unknown", character.realm or "UnknownRealm")
        if character.isCurrent then
            displayName = displayName .. " (Current)"
        end

        row.fonts.name:SetText(displayName)
        row.fonts.name:SetTextColor(character.isCurrent and 1 or 0.92, character.isCurrent and 0.82 or 0.92, 0.92)

        local classText = string.format("%s %d", character.className or "Unknown", tonumber(character.level) or 0)
        local classR, classG, classB = GetClassColor(character.classFile)
        row.fonts.class:SetText(classText)
        row.fonts.class:SetTextColor(classR, classG, classB)

        row.fonts.professions:SetText(FormatProfessionList(character.professions))
        row.fonts.professions:SetTextColor(0.9, 0.9, 0.9)

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

function mQoL_AccountOverview:GetVirtualGoldHistory()
    local history = NormalizeGoldHistory(self.db and self.db.goldHistory or {})
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
    if #entries == 0 then
        return {
            { ts = now, total = currentTotal }
        }, now
    end

    if #entries == 1 then
        return {
            { ts = entries[1].ts - (7 * SECONDS_PER_DAY), total = entries[1].total },
            { ts = now, total = currentTotal },
        }, entries[1].ts
    end

    if #entries <= OVERALL_ARCHIVE_MAX_POINTS then
        local directSeries = {}
        for index, entry in ipairs(entries) do
            directSeries[#directSeries + 1] = {
                ts = index == #entries and now or entry.ts,
                total = index == #entries and currentTotal or entry.total,
            }
        end
        return directSeries, entries[1].ts
    end

    local series = {}
    local remainingEntries = #entries
    local remainingSlots = OVERALL_ARCHIVE_MAX_POINTS
    local startIndex = 1

    while startIndex <= #entries and remainingSlots > 0 do
        local groupSize = math.ceil(remainingEntries / remainingSlots)
        local endIndex = math.min(#entries, startIndex + groupSize - 1)
        local sum = 0
        local count = 0

        for index = startIndex, endIndex do
            sum = sum + math.floor(tonumber(entries[index].total) or 0)
            count = count + 1
        end

        series[#series + 1] = {
            ts = entries[startIndex].ts,
            total = math.floor((sum / math.max(1, count)) + 0.5),
        }

        remainingEntries = #entries - endIndex
        remainingSlots = remainingSlots - 1
        startIndex = endIndex + 1
    end

    series[#series].ts = now
    series[#series].total = currentTotal

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
    self:PruneGoldHistory(now)
    local history = NormalizeGoldHistory(self.db and self.db.goldHistory or {})

    if #history == 0 then
        history = {
            { ts = now, total = currentTotal }
        }
    end

    if rangeKey == "overall" then
        local earliestHistoryTimestamp = history[1] and history[1].ts or now
        if (now - earliestHistoryTimestamp) > (365 * SECONDS_PER_DAY) then
            local archivedEntries = self:GetOverallArchiveEntries(currentTotal, now)
            if #archivedEntries < 2 then
                archivedEntries = self:BuildDerivedOverallEntries(history, currentTotal, now)
            end

            if #archivedEntries > 0 then
                return self:BuildCompressedOverallSeries(archivedEntries, currentTotal, now)
            end
        end

        local overallSeries = self:BuildThrottledOverallDisplaySeries(history, now)
        if #overallSeries == 1 then
            overallSeries = {
                { ts = overallSeries[1].ts - SECONDS_PER_HOUR, total = overallSeries[1].total },
                { ts = overallSeries[1].ts, total = overallSeries[1].total },
            }
        end
        return overallSeries, overallSeries[1].ts, overallSeries[#overallSeries].ts
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

    local series = {}
    local carryValue = self:GetLastStoredRangeValueBefore(rangeKey, oldestBucketKey)
    if carryValue == nil then
        for index, key in ipairs(bucketKeys) do
            if index >= #bucketKeys then
                break
            end

            local firstWindowValue = self:GetStoredRangeValue(rangeKey, key)
            if firstWindowValue ~= nil then
                carryValue = firstWindowValue
                break
            end
        end
    end

    if carryValue == nil then
        carryValue = currentTotal
    end

    for index, key in ipairs(bucketKeys) do
        local value
        if index == #bucketKeys then
            value = currentTotal
        else
            local storedValue = self:GetStoredRangeValue(rangeKey, key)
            if storedValue ~= nil then
                carryValue = storedValue
            end
            value = carryValue
        end

        series[#series + 1] = {
            ts = index == #bucketKeys and now or key,
            total = value,
            label = GetRangeBucketLabel(rangeKey, key, index, windowSize),
            bucketKey = key,
        }
    end

    return series, oldestBucketKey, now
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
    view.rangeButtonsFrame:SetSize(770, 28)

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
    view.statsText:SetWidth(770)
    view.statsText:SetJustifyH("LEFT")
    view.statsText:SetTextColor(0.88, 0.88, 0.88)

    view.chart = CreateFrame("Frame", nil, view)
    view.chart:SetPoint("TOPLEFT", view.rangeButtonsFrame, "BOTTOMLEFT", 0, -12)
    view.chart:SetSize(770, 320)

    view.chart.bg = view.chart:CreateTexture(nil, "BACKGROUND")
    view.chart.bg:SetAllPoints()
    view.chart.bg:SetColorTexture(0.08, 0.08, 0.08, 0.96)

    if CreateFrameBorder then
        view.chart.border = CreateFrameBorder(view.chart, 1, { 0.22, 0.22, 0.22, 1 })
    end

    view.chart.plotLeft = 70
    view.chart.plotRight = 18
    view.chart.plotTop = 20
    view.chart.plotBottom = 34
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

    local plotWidth = chart:GetWidth() - chart.plotLeft - chart.plotRight
    local plotHeight = chart:GetHeight() - chart.plotTop - chart.plotBottom
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
        local padding = math.max(10000, maxValue * 0.1)
        minValue = math.max(0, minValue - padding)
        maxValue = maxValue + padding
    else
        local padding = math.max(10000, (maxValue - minValue) * 0.15)
        minValue = math.max(0, minValue - padding)
        maxValue = maxValue + padding
    end

    local valueRange = math.max(1, maxValue - minValue)

    for index = 0, 4 do
        local y = chart.plotBottom + (plotHeight * (index / 4))
        local horizontal = AcquireTexture(chart.gridLines, index + 1, chart, "BACKGROUND")
        horizontal:ClearAllPoints()
        horizontal:SetColorTexture(1, 1, 1, 0.08)
        horizontal:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", chart.plotLeft, y)
        horizontal:SetSize(plotWidth, 1)

        local yLabel = AcquireFontString(chart.yLabels, index + 1, chart, "GameFontNormalSmall")
        yLabel:ClearAllPoints()
        yLabel:SetPoint("RIGHT", chart, "BOTTOMLEFT", chart.plotLeft - 8, y)
        yLabel:SetJustifyH("RIGHT")
        yLabel:SetText(FormatAxisMoney(minValue + (valueRange * (index / 4))))
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

    local useBucketSpacing = activeRange ~= "overall" and samples[1] and samples[1].label
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
            local x = GetChartX(index, sample)

            local vertical = AcquireTexture(chart.verticalLines, index, chart, "BACKGROUND")
            vertical:ClearAllPoints()
            vertical:SetColorTexture(1, 1, 1, 0.05)
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
            local x = chart.plotLeft + (plotWidth * (index / 4))
            local vertical = AcquireTexture(chart.verticalLines, index + 1, chart, "BACKGROUND")
            vertical:ClearAllPoints()
            vertical:SetColorTexture(1, 1, 1, 0.05)
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

            local segment = AcquireTexture(chart.segments, index - 1, chart, "ARTWORK")
            segment:ClearAllPoints()
            segment:SetColorTexture(1, 0.82, 0, 0.75)

            if segment.SetRotation then
                segment:SetSize(length, 2)
                segment:SetPoint("CENTER", chart, "BOTTOMLEFT", (previousX + x) / 2, (previousY + y) / 2)
                segment:SetRotation(ComputeRotationAngle(dx, dy))
            else
                segment:SetSize(2, math.max(2, math.abs(dy)))
                segment:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", previousX, math.min(previousY, y))
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
    self.viewsHost:SetHeight(activeHeight)
    self.contentContainer.currentY = self.viewsAnchorY - activeHeight - 20

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
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("TIME_PLAYED_MSG")
eventFrame:RegisterEvent("BANKFRAME_OPENED")

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
        })
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
    elseif event == "PLAYER_LOGOUT" then
        mQoL_AccountOverview:StopBootstrapSync()
        mQoL_AccountOverview:UpdateCurrentCharacterSnapshot({
            refreshStatic = true,
            refreshMoney = true,
            forceLogoutMoney = true,
            refreshProfessions = true,
            refreshWarbandBank = true,
            allowCachedWarbandBank = true,
            forceGoldSnapshot = true,
        })
    end
end)
