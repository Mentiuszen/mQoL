local addonName = ...
mQoL_MythicPlusListing = mQoL_MythicPlusListing or {}

local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
    return
end

local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
if not clientInfo.isRetail then
    return
end

local MODULE_KEY = "MythicPlusListing"
local COMM_PREFIX = "mQoLKeys"
local BLIZZARD_GROUPFINDER_ADDON = "Blizzard_GroupFinder"
local DETAILS_ADDON = "Details"
local ASTRAL_KEYS_ADDON = "AstralKeys"
local RAIDERIO_ADDON = "RaiderIO"
local MAX_GROUP_ROWS = 5

local CreateCustomButton = mQoL_Styles and mQoL_Styles.CreateCustomButton
local CreateCustomDropdown = mQoL_Styles and mQoL_Styles.CreateCustomDropdown
local CreateFrameBorder = mQoL_Templates and mQoL_Templates.CreateFrameBorder
local SetBackdrop = mQoL_Templates and mQoL_Templates.SetBackdrop
local CreateCloseButton = mQoL_Templates and mQoL_Templates.CreateCloseButton
local GENERAL_PLAYSTYLE = Enum and Enum.LFGEntryGeneralPlaystyle or {
    None = 0,
    Learning = 1,
    FunRelaxed = 2,
    FunSerious = 3,
    Expert = 4,
}
local DEFAULT_PLAYSTYLE_KEY = "relaxed"
local HUB_WINDOW_WIDTH = 560
local HUB_WINDOW_HEIGHT = 415
local LFG_CATEGORY_DUNGEONS = GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2
local LFG_FILTER_CURRENT_SEASON = Enum and Enum.LFGListFilter and Enum.LFGListFilter.CurrentSeason or 0
local LFG_FILTER_PVE = Enum and Enum.LFGListFilter and Enum.LFGListFilter.PvE or 0
local WINDOW_ANCHOR_X = 8
local WINDOW_ANCHOR_Y = -2
local LIST_INSET_SIDE = 8
local LIST_INSET_TOP = -44
local LIST_INSET_BOTTOM = 10
local CONTENT_SIDE = 12
local HEADER_TOP = -10
local HEADER_HEIGHT = 22
local TOOLBAR_HEIGHT = 24
local ROW_HEIGHT = 28
local ROW_GAP = 4
local ROW_TOP = -34
local COLUMN_NAME_X = 14
local COLUMN_NAME_WIDTH = 98
local COLUMN_KEY_X = 118
local COLUMN_KEY_WIDTH = 176
local COLUMN_RESILIENT_X = 304
local COLUMN_RESILIENT_WIDTH = 122
local COLUMN_BUTTON_X = 435
local COLUMN_BUTTON_WIDTH = 82
local COLUMN_BUTTON_HEIGHT = 20
local PLAYSTYLE_OPTIONS = {
    { text = "Learning", value = "learning", generalPlaystyle = GENERAL_PLAYSTYLE.Learning },
    { text = "Relaxed", value = "relaxed", generalPlaystyle = GENERAL_PLAYSTYLE.FunRelaxed },
    { text = "Competitive", value = "competitive", generalPlaystyle = GENERAL_PLAYSTYLE.FunSerious },
    { text = "Carry Offered", value = "carry", generalPlaystyle = GENERAL_PLAYSTYLE.Expert },
}
local PLAYSTYLE_OPTION_BY_KEY = {}

for _, option in ipairs(PLAYSTYLE_OPTIONS) do
    PLAYSTYLE_OPTION_BY_KEY[option.value] = option
end

mQoL_MythicPlusListing.defaults = {
    window = {
        point = "CENTER",
        x = 0,
        y = 0,
    },
}

local eventFrame = CreateFrame("Frame")

local function IsAddonLoadedSafe(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addon)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(addon)
    end
    return false
end

local function GetCurrentRealmSlug()
    local realm = GetRealmName() or ""
    return realm:gsub("%s+", "")
end

local function NormalizeFullName(name)
    if type(name) ~= "string" then
        return nil
    end

    name = strtrim(name)
    if name == "" then
        return nil
    end

    local playerName, realmName = strsplit("-", name, 2)
    if not playerName or playerName == "" then
        return nil
    end

    realmName = realmName or GetCurrentRealmSlug()
    realmName = realmName:gsub("%s+", "")

    if realmName == "" then
        return playerName
    end

    return playerName .. "-" .. realmName
end

local function GetUnitFullName(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    return NormalizeFullName(GetUnitName(unit, true))
end

local function GetShortName(name)
    if type(name) ~= "string" then
        return nil
    end

    name = strtrim(name)
    if name == "" then
        return nil
    end

    return name:match("^[^-]+") or name
end

local function GetDisplayName(fullName)
    if not fullName or fullName == "" then
        return UNKNOWN
    end

    if Ambiguate then
        return Ambiguate(fullName, "short")
    end

    return fullName:match("^[^-]+") or fullName
end

local function ShallowCopy(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function FirstPositiveNumber(...)
    for index = 1, select("#", ...) do
        local value = tonumber((select(index, ...)))
        if value and value > 0 then
            return value
        end
    end
    return 0
end

local function GetClassFileByID(classID)
    if not classID or classID <= 0 or not GetClassInfo then
        return nil
    end

    local _, classFile = GetClassInfo(classID)
    return classFile
end

local function GetClassColor(classFile)
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

    return NORMAL_FONT_COLOR
end

local function GetCommDistribution()
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

local function FormatScore(score)
    score = tonumber(score) or 0
    if score <= 0 then
        return "-"
    end

    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(math.floor(score + 0.5))
    end

    return tostring(math.floor(score + 0.5))
end

local function GetMapName(mapID)
    if not mapID or mapID <= 0 or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        return nil
    end

    return C_ChallengeMode.GetMapUIInfo(mapID)
end

local function HasUsableKeyData(data)
    if type(data) ~= "table" then
        return false
    end

    return (tonumber(data.level) or 0) > 0 and (tonumber(data.mapID) or 0) > 0
end

local function SetButtonLabel(button, text)
    if not button then
        return
    end

    if button.text and button.text.SetText then
        button.text:SetText(text or "")
    elseif button.SetText then
        button:SetText(text or "")
    end
end

local function SetButtonInteractionState(button, enabled, text)
    if not button then
        return
    end

    if text then
        SetButtonLabel(button, text)
    end

    if button.SetEnabled then
        button:SetEnabled(enabled and true or false)
    end

    if button.EnableMouse then
        button:EnableMouse(enabled and true or false)
    end

    button:SetAlpha(enabled and 1 or 0.55)

    if button.bg then
        if enabled then
            button.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
        else
            button.bg:SetColorTexture(0.08, 0.08, 0.08, 1)
        end
    end

    if button.text and button.text.SetTextColor then
        if enabled then
            button.text:SetTextColor(0.9, 0.9, 0.9)
        else
            button.text:SetTextColor(0.45, 0.45, 0.45)
        end
    end
end

local function GetHubWindowSize()
    if LFGListFrame and LFGListFrame.IsShown and LFGListFrame:IsShown() and LFGListFrame.GetHeight then
        return HUB_WINDOW_WIDTH, math.max(HUB_WINDOW_HEIGHT, math.floor((LFGListFrame:GetHeight() or HUB_WINDOW_HEIGHT) + 0.5))
    end

    return HUB_WINDOW_WIDTH, HUB_WINDOW_HEIGHT
end

local function GetWindowAnchorTarget()
    if LFGListFrame and LFGListFrame.IsShown and LFGListFrame:IsShown() then
        return LFGListFrame
    end

    return nil
end

local function FormatKeystone(data)
    if not data then
        return "No data"
    end

    local level = tonumber(data.level) or 0
    local mapID = tonumber(data.mapID) or 0

    if level <= 0 or mapID <= 0 then
        return "No key"
    end

    local mapName = GetMapName(mapID) or ("Map " .. mapID)
    return string.format("+%d %s", level, mapName)
end

local function FormatResilientText(resilientInfo, keyLevel)
    if (tonumber(keyLevel) or 0) <= 0 then
        return "No Key", 0.65, 0.65, 0.65
    end

    if resilientInfo and resilientInfo.isResilient then
        return "Resilient Keystone", 0.20, 0.90, 0.35
    end

    return "Regular Keystone", 1.00, 0.35, 0.35
end

local function BuildResilientInfoFromTimedRuns(timedRunsByMap, keyLevel, seasonalMapIDs, source)
    local floor = math.huge
    local completedMaps = 0
    local nextProgress = 0

    for _, mapID in ipairs(seasonalMapIDs or {}) do
        local runLevel = timedRunsByMap[mapID] or 0
        if runLevel > 0 then
            completedMaps = completedMaps + 1
        end
        floor = math.min(floor, runLevel)
    end

    if floor == math.huge then
        floor = 0
    end

    local resilientLevel = floor >= 12 and floor or 0
    local nextTargetLevel = resilientLevel > 0 and (resilientLevel + 1) or 12

    for _, mapID in ipairs(seasonalMapIDs or {}) do
        local runLevel = timedRunsByMap[mapID] or 0
        if runLevel >= nextTargetLevel then
            nextProgress = nextProgress + 1
        end
    end

    return {
        isResilient = floor >= keyLevel and keyLevel > 0,
        floor = floor,
        resilientLevel = resilientLevel,
        completedMaps = completedMaps,
        seasonalMaps = #(seasonalMapIDs or {}),
        nextTargetLevel = nextTargetLevel,
        nextProgress = nextProgress,
        source = source or "-",
    }
end

local function BuildActivityEntry(activityID, activityInfo)
    local mapID = activityInfo and tonumber(activityInfo.mapID) or 0
    if not activityInfo or not activityInfo.isMythicPlusActivity then
        return nil
    end

    return {
        activityID = activityID,
        groupID = activityInfo.groupFinderActivityGroupID,
        mapID = mapID,
        shortName = activityInfo.shortName,
        fullName = activityInfo.fullName,
        orderIndex = activityInfo.orderIndex,
    }
end

function mQoL_MythicPlusListing:InitializeDB()
    self.db = mQoL_Database:MigrateModule(MODULE_KEY, self.defaults)
    self.db.cache = self.db.cache or {}
    self.db.settings = self.db.settings or {}
    self.db.settings.window = self.db.settings.window or ShallowCopy(self.defaults.window)
    self.db.settings.playstyle = PLAYSTYLE_OPTION_BY_KEY[self.db.settings.playstyle] and self.db.settings.playstyle or DEFAULT_PLAYSTYLE_KEY
end

function mQoL_MythicPlusListing:StoreCacheEntry(fullName, keyData)
    if not self.db or type(self.db.cache) ~= "table" or not fullName or type(keyData) ~= "table" then
        return
    end

    fullName = NormalizeFullName(fullName)
    if not fullName then
        return
    end

    local newSeenAt = tonumber(keyData.seenAt) or GetServerTime()
    local existingEntry = self.db.cache[fullName]
    if existingEntry and (tonumber(existingEntry.seenAt) or 0) > newSeenAt then
        return
    end

    self.db.cache[fullName] = {
        level = tonumber(keyData.level) or 0,
        mapID = tonumber(keyData.mapID) or 0,
        classFile = keyData.classFile,
        rating = tonumber(keyData.rating) or 0,
        seenAt = newSeenAt,
    }
end

function mQoL_MythicPlusListing:GetCachedEntry(fullName)
    if not self.db or type(self.db.cache) ~= "table" then
        return nil, false
    end

    fullName = NormalizeFullName(fullName)
    if not fullName then
        return nil, false
    end

    local entry = self.db.cache[fullName]
    if not entry then
        return nil, false
    end

    local cached = ShallowCopy(entry)
    cached.source = "mQoL"
    return cached, true
end

function mQoL_MythicPlusListing:GetCurrentPlayerEntry()
    local fullName = GetUnitFullName("player")
    local _, classFile = UnitClass("player")
    local ratingSummary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    local rating = ratingSummary and ratingSummary.currentSeasonScore or 0
    local mapID = FirstPositiveNumber(
        C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID(),
        C_MythicPlus and C_MythicPlus.GetOwnedKeystoneMapID and C_MythicPlus.GetOwnedKeystoneMapID()
    )
    local entry = {
        level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and (C_MythicPlus.GetOwnedKeystoneLevel() or 0) or 0,
        mapID = mapID,
        classFile = classFile,
        rating = rating,
        seenAt = GetServerTime(),
        source = "mQoL",
    }

    if fullName then
        self:StoreCacheEntry(fullName, entry)
    end

    return fullName, entry
end

function mQoL_MythicPlusListing:GetOpenRaidLib()
    if self.openRaidLib and self.openRaidLib.GetKeystoneInfo then
        return self.openRaidLib
    end

    if not LibStub then
        return nil
    end

    local lib
    if type(LibStub) == "function" then
        lib = LibStub("LibOpenRaid-1.0", true)
    elseif type(LibStub) == "table" and LibStub.GetLibrary then
        lib = LibStub:GetLibrary("LibOpenRaid-1.0", true)
    end

    if lib and lib.GetKeystoneInfo then
        self.openRaidLib = lib
    end

    return self.openRaidLib
end

function mQoL_MythicPlusListing:BuildDetailsEntry(fullName, info)
    if type(info) ~= "table" then
        return nil
    end

    local entry = {
        level = tonumber(info.level) or 0,
        mapID = FirstPositiveNumber(info.challengeMapID, info.mythicPlusMapID, info.mapID),
        classFile = GetClassFileByID(tonumber(info.classID) or 0),
        rating = tonumber(info.rating) or 0,
        seenAt = GetServerTime(),
        source = "Details",
    }

    if fullName then
        self:StoreCacheEntry(fullName, entry)
    end

    return entry
end

function mQoL_MythicPlusListing:GetDetailsEntry(unit, fullName)
    local openRaidLib = self:GetOpenRaidLib()
    if not openRaidLib or not openRaidLib.GetKeystoneInfo then
        return nil, false
    end

    local tried = {}
    local candidates = {}

    local function AddCandidate(value)
        if not value or tried[value] then
            return
        end
        tried[value] = true
        table.insert(candidates, value)
    end

    if unit and UnitExists(unit) then
        AddCandidate(unit)
    end

    local normalizedFullName = NormalizeFullName(fullName)
    local shortName = GetShortName(fullName)

    AddCandidate(normalizedFullName)
    AddCandidate(shortName)

    for _, candidate in ipairs(candidates) do
        local info = openRaidLib.GetKeystoneInfo(candidate)
        if type(info) == "table" then
            local entry = self:BuildDetailsEntry(normalizedFullName, info)
            if HasUsableKeyData(entry) then
                return entry, true
            end
        end
    end

    if openRaidLib.GetAllKeystonesInfo then
        local allKeystones = openRaidLib.GetAllKeystonesInfo()
        if type(allKeystones) == "table" then
            for unitName, info in pairs(allKeystones) do
                local normalizedUnitName = NormalizeFullName(unitName)
                if (normalizedFullName and normalizedUnitName == normalizedFullName) or (shortName and GetShortName(unitName) == shortName) then
                    local entry = self:BuildDetailsEntry(normalizedFullName or normalizedUnitName, info)
                    if HasUsableKeyData(entry) then
                        return entry, true
                    end
                end
            end
        end
    end

    return nil, false
end

function mQoL_MythicPlusListing:GetAstralKeysEntry(fullName)
    if type(AstralKeys) ~= "table" then
        return nil, false
    end

    fullName = NormalizeFullName(fullName)
    if not fullName then
        return nil, false
    end

    for index = 1, #AstralKeys do
        local entry = AstralKeys[index]
        if type(entry) == "table" and NormalizeFullName(entry.unit) == fullName then
            local result = {
                level = tonumber(entry.key_level) or 0,
                mapID = tonumber(entry.dungeon_id) or 0,
                classFile = entry.class,
                rating = tonumber(entry.mplus_score) or 0,
                seenAt = tonumber(entry.time_stamp) or GetServerTime(),
                source = "AstralKeys",
            }

            self:StoreCacheEntry(fullName, result)
            return result, true
        end
    end

    return nil, false
end

function mQoL_MythicPlusListing:GetBestEntry(unit, fullName)
    local detailsEntry, hasDetails = self:GetDetailsEntry(unit, fullName)
    if hasDetails then
        return detailsEntry
    end

    local astralEntry, hasAstralKeys = self:GetAstralKeysEntry(fullName)
    if hasAstralKeys then
        return astralEntry
    end

    local cachedEntry = self:GetCachedEntry(fullName)
    if cachedEntry then
        return cachedEntry
    end

    return nil
end

function mQoL_MythicPlusListing:GetTrackedGroupMembers()
    local members = {}
    local seen = {}

    local function AddUnit(unit)
        if #members >= MAX_GROUP_ROWS then
            return
        end

        local fullName = GetUnitFullName(unit)
        if not fullName or seen[fullName] then
            return
        end

        seen[fullName] = true
        table.insert(members, {
            unit = unit,
            fullName = fullName,
        })
    end

    AddUnit("player")

    if IsInRaid() then
        local count = math.min(GetNumGroupMembers() or 0, MAX_GROUP_ROWS)
        for index = 1, count do
            AddUnit("raid" .. index)
        end
    elseif IsInGroup() then
        for index = 1, (GetNumSubgroupMembers() or 0) do
            AddUnit("party" .. index)
        end
    end

    return members
end

function mQoL_MythicPlusListing:GetSelectedPlaystyleKey()
    local playstyleKey = self.db and self.db.settings and self.db.settings.playstyle or DEFAULT_PLAYSTYLE_KEY
    if not PLAYSTYLE_OPTION_BY_KEY[playstyleKey] then
        playstyleKey = DEFAULT_PLAYSTYLE_KEY
    end

    return playstyleKey
end

function mQoL_MythicPlusListing:GetSelectedPlaystyleEnum()
    local option = PLAYSTYLE_OPTION_BY_KEY[self:GetSelectedPlaystyleKey()]
    return option and option.generalPlaystyle or GENERAL_PLAYSTYLE.Learning
end

function mQoL_MythicPlusListing:SetSelectedPlaystyleKey(playstyleKey, applyToEntryCreation)
    if not PLAYSTYLE_OPTION_BY_KEY[playstyleKey] then
        playstyleKey = DEFAULT_PLAYSTYLE_KEY
    end

    if self.db and self.db.settings then
        self.db.settings.playstyle = playstyleKey
    end

    local frame = self.window
    if frame and frame.playstyleDropdown and frame.playstyleDropdown.SetValue then
        frame.playstyleDropdown:SetValue(playstyleKey)
    end

    if applyToEntryCreation then
        local entryCreation = LFGListFrame and LFGListFrame.EntryCreation
        if entryCreation and entryCreation.selectedActivity and entryCreation.selectedGroup and entryCreation.selectedCategory and LFGListEntryCreation_OnPlayStyleSelectedInternal then
            LFGListEntryCreation_OnPlayStyleSelectedInternal(entryCreation, self:GetSelectedPlaystyleEnum())
            if entryCreation.PlayStyleDropdown and entryCreation.PlayStyleDropdown.GenerateMenu then
                entryCreation.PlayStyleDropdown:GenerateMenu()
            end
        end
    end
end

function mQoL_MythicPlusListing:GetRaiderIOKeystoneProfile(unit, fullName)
    if type(RaiderIO) ~= "table" or type(RaiderIO.GetProfile) ~= "function" then
        return nil
    end

    local profile
    if unit and UnitExists(unit) then
        profile = RaiderIO.GetProfile(unit)
    end

    if not profile and type(fullName) == "string" and fullName ~= "" then
        profile = RaiderIO.GetProfile(fullName)
    end

    local keystoneProfile = profile and profile.mythicKeystoneProfile
    if type(keystoneProfile) == "table" and keystoneProfile.hasRenderableData then
        return keystoneProfile
    end

    return nil
end

function mQoL_MythicPlusListing:MergeRaiderIODungeons(lookup, keystoneProfile)
    if type(lookup) ~= "table" or type(keystoneProfile) ~= "table" or type(keystoneProfile.sortedDungeons) ~= "table" then
        return
    end

    for _, sortedDungeon in ipairs(keystoneProfile.sortedDungeons) do
        local dungeon = sortedDungeon and sortedDungeon.dungeon
        local keystoneInstance = dungeon and tonumber(dungeon.keystone_instance) or 0
        if keystoneInstance > 0 and not lookup[keystoneInstance] then
            lookup[keystoneInstance] = dungeon
        end
    end
end

function mQoL_MythicPlusListing:GetRaiderIODungeonLookup(force)
    if self.raiderIODungeonLookup and not force then
        return self.raiderIODungeonLookup
    end

    local lookup = {}
    local members = self:GetTrackedGroupMembers()

    for _, member in ipairs(members) do
        self:MergeRaiderIODungeons(lookup, self:GetRaiderIOKeystoneProfile(member.unit, member.fullName))
    end

    self.raiderIODungeonLookup = lookup
    return lookup
end

function mQoL_MythicPlusListing:GetMythicPlusActivityCache(force)
    if self.activityCache and not force then
        return self.activityCache
    end

    local cache = {
        byMapID = {},
        byChallengeMapID = {},
        seasonalMapIDs = {},
    }
    local seasonalInstanceMapIDs = {}

    if not C_LFGList or not C_LFGList.GetAvailableActivities or not C_LFGList.GetActivityInfoTable then
        self.activityCache = cache
        return cache
    end

    local filtersToCheck = {
        bit.bor(LFG_FILTER_CURRENT_SEASON, LFG_FILTER_PVE),
        LFG_FILTER_PVE,
    }
    local seenActivities = {}

    for filterIndex, filters in ipairs(filtersToCheck) do
        local activities = C_LFGList.GetAvailableActivities(LFG_CATEGORY_DUNGEONS, nil, filters)
        if type(activities) == "table" then
            for _, activityID in ipairs(activities) do
                if not seenActivities[activityID] then
                    seenActivities[activityID] = true

                    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
                    local activity = BuildActivityEntry(activityID, activityInfo)
                    local mapID = activity and activity.mapID or 0
                    if activity and mapID > 0 then
                        if not cache.byMapID[mapID] then
                            cache.byMapID[mapID] = activity
                        end

                        local isCurrentSeason = filterIndex == 1
                        if not isCurrentSeason and LFG_FILTER_CURRENT_SEASON > 0 and bit.band(activityInfo.filters or 0, LFG_FILTER_CURRENT_SEASON) ~= 0 then
                            isCurrentSeason = true
                        end

                        if isCurrentSeason then
                            seasonalInstanceMapIDs[mapID] = true
                        end
                    end
                end
            end
        end
    end

    local raiderIOLookup = self:GetRaiderIODungeonLookup(force)
    for challengeMapID, dungeon in pairs(raiderIOLookup) do
        local activity
        local lfdActivityIDs = dungeon and dungeon.lfd_activity_ids
        if type(lfdActivityIDs) == "table" then
            for _, activityID in ipairs(lfdActivityIDs) do
                activity = BuildActivityEntry(activityID, C_LFGList.GetActivityInfoTable(activityID))
                if activity then
                    local activityMapID = tonumber(activity.mapID) or 0
                    if activityMapID > 0 then
                        cache.byMapID[activityMapID] = cache.byMapID[activityMapID] or activity
                    end
                    if activityMapID > 0 and seasonalInstanceMapIDs[activityMapID] then
                        cache.seasonalMapIDs[challengeMapID] = true
                    end
                    break
                end
            end
        end

        if not activity then
            local instanceMapIDs = dungeon and dungeon.instance_map_ids
            if type(instanceMapIDs) == "table" then
                for _, instanceMapID in ipairs(instanceMapIDs) do
                    activity = cache.byMapID[tonumber(instanceMapID) or 0]
                    if activity then
                        if seasonalInstanceMapIDs[tonumber(instanceMapID) or 0] then
                            cache.seasonalMapIDs[challengeMapID] = true
                        end
                        break
                    end
                end
            end
        end

        if activity then
            cache.byChallengeMapID[challengeMapID] = activity
        end
    end

    if not next(cache.seasonalMapIDs) then
        for mapID in pairs(cache.byChallengeMapID) do
            cache.seasonalMapIDs[mapID] = true
        end
    end

    self.activityCache = cache
    return cache
end

function mQoL_MythicPlusListing:GetSeasonalMapIDs()
    local cache = self:GetMythicPlusActivityCache()
    local mapIDs = {}

    for mapID in pairs(cache.seasonalMapIDs or {}) do
        table.insert(mapIDs, mapID)
    end

    table.sort(mapIDs)
    return mapIDs
end

function mQoL_MythicPlusListing:GetBlizzardResilientInfo(unit, keyLevel, seasonalMapIDs)
    keyLevel = tonumber(keyLevel) or 0
    if keyLevel <= 0 or not unit or not UnitExists(unit) or not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        return nil
    end

    seasonalMapIDs = seasonalMapIDs or self:GetSeasonalMapIDs()
    local fallbackInfo = {
        isResilient = false,
        floor = 0,
        completedMaps = 0,
        seasonalMaps = #seasonalMapIDs,
        source = "Blizzard",
    }

    if #seasonalMapIDs == 0 then
        return fallbackInfo
    end

    local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if type(ratingSummary) ~= "table" or type(ratingSummary.runs) ~= "table" then
        return fallbackInfo
    end

    local timedRunsByMap = {}
    for _, runInfo in ipairs(ratingSummary.runs) do
        if type(runInfo) == "table" and runInfo.finishedSuccess then
            local mapID = tonumber(runInfo.challengeModeID) or 0
            local runLevel = tonumber(runInfo.bestRunLevel) or 0
            if mapID > 0 and runLevel > (timedRunsByMap[mapID] or 0) then
                timedRunsByMap[mapID] = runLevel
            end
        end
    end

    return BuildResilientInfoFromTimedRuns(timedRunsByMap, keyLevel, seasonalMapIDs, "Blizzard")
end

function mQoL_MythicPlusListing:GetResilientInfo(unit, fullName, keyLevel, seasonalMapIDs)
    keyLevel = tonumber(keyLevel) or 0
    if keyLevel <= 0 then
        return nil
    end

    seasonalMapIDs = seasonalMapIDs or self:GetSeasonalMapIDs()
    if #seasonalMapIDs == 0 then
        return {
            isResilient = false,
            floor = 0,
            completedMaps = 0,
            seasonalMaps = 0,
            source = "-",
        }
    end

    local keystoneProfile = self:GetRaiderIOKeystoneProfile(unit, fullName)
    if type(keystoneProfile) == "table" and type(keystoneProfile.sortedDungeons) == "table" then
        local seasonalMapLookup = {}
        local timedRunsByMap = {}
        local hasSeasonalData = false

        for _, mapID in ipairs(seasonalMapIDs) do
            seasonalMapLookup[mapID] = true
        end

        for _, sortedDungeon in ipairs(keystoneProfile.sortedDungeons) do
            local dungeon = sortedDungeon and sortedDungeon.dungeon
            local mapID = dungeon and tonumber(dungeon.keystone_instance) or 0
            local runLevel = tonumber(sortedDungeon and sortedDungeon.level) or 0
            local chests = tonumber(sortedDungeon and sortedDungeon.chests) or 0

            if seasonalMapLookup[mapID] then
                hasSeasonalData = true
                if chests > 0 and runLevel > (timedRunsByMap[mapID] or 0) then
                    timedRunsByMap[mapID] = runLevel
                end
            end
        end

        if hasSeasonalData then
            return BuildResilientInfoFromTimedRuns(timedRunsByMap, keyLevel, seasonalMapIDs, "RaiderIO")
        end
    end

    return self:GetBlizzardResilientInfo(unit, keyLevel, seasonalMapIDs)
end

function mQoL_MythicPlusListing:GetQuickFillActivity(mapID)
    mapID = tonumber(mapID) or 0
    if mapID <= 0 then
        return nil
    end

    local cache = self:GetMythicPlusActivityCache()
    return (cache.byChallengeMapID and cache.byChallengeMapID[mapID]) or (cache.byMapID and cache.byMapID[mapID]) or nil
end

function mQoL_MythicPlusListing:GetQuickFillState(rowData)
    if type(rowData) ~= "table" then
        return false, "Use Key"
    end

    local entry = rowData.entry or {}
    local keyLevel = tonumber(entry.level) or 0
    local mapID = tonumber(entry.mapID) or 0
    if keyLevel <= 0 or mapID <= 0 then
        return false, "No Key"
    end

    local activity = self:GetQuickFillActivity(mapID)
    if not activity then
        return false, "No Match"
    end

    local entryCreation = LFGListFrame and LFGListFrame.EntryCreation
    if not LFGListFrame or not LFGListFrame.IsShown or not LFGListFrame:IsShown() or not entryCreation then
        return false, "Open LFG"
    end

    return true, "Use Key", activity
end

function mQoL_MythicPlusListing:QuickFillListing(rowData)
    local canQuickFill, reason, activity = self:GetQuickFillState(rowData)
    if not canQuickFill or not activity then
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            local message = "Open the Group Listing panel to use Party Keys."
            if reason == "No Match" then
                message = "This keystone cannot be matched to a current Mythic+ listing."
            elseif reason == "No Key" then
                message = "Selected player does not have an active keystone."
            end
            UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1)
        end
        return
    end

    local entryCreation = LFGListFrame and LFGListFrame.EntryCreation
    if not entryCreation or not LFGListEntryCreation_Select then
        return
    end

    if not entryCreation:IsShown() and LFGListFrame_SetActivePanel then
        LFGListFrame_SetActivePanel(LFGListFrame, entryCreation)
    end

    LFGListEntryCreation_Select(entryCreation, entryCreation.selectedFilters or 0, LFG_CATEGORY_DUNGEONS, activity.groupID, activity.activityID)

    if LFGListEntryCreation_OnPlayStyleSelectedInternal then
        LFGListEntryCreation_OnPlayStyleSelectedInternal(entryCreation, self:GetSelectedPlaystyleEnum())
    else
        entryCreation.generalPlaystyle = self:GetSelectedPlaystyleEnum()
    end

    if entryCreation.PlayStyleDropdown and entryCreation.PlayStyleDropdown.GenerateMenu then
        entryCreation.PlayStyleDropdown:GenerateMenu()
    end

    if LFGListEntryCreation_UpdateValidState then
        LFGListEntryCreation_UpdateValidState(entryCreation)
    end

    if self.window and self.window:IsShown() then
        self:UpdateWindow()
    end
end

function mQoL_MythicPlusListing:BuildDisplayData()
    local displayRows = {}
    local members = self:GetTrackedGroupMembers()
    local seasonalMapIDs = self:GetSeasonalMapIDs()
    local raiderIOLookup = self:GetRaiderIODungeonLookup()

    for _, member in ipairs(members) do
        local bestEntry = self:GetBestEntry(member.unit, member.fullName)
        local _, classFile = UnitClass(member.unit)

        if not bestEntry then
            bestEntry = {
                level = 0,
                mapID = 0,
                classFile = classFile,
                rating = 0,
                source = "-",
                seenAt = 0,
            }
        elseif not bestEntry.classFile then
            bestEntry.classFile = classFile
        end

        local resilientInfo = self:GetResilientInfo(member.unit, member.fullName, bestEntry.level, seasonalMapIDs)
        local resilientText, resilientR, resilientG, resilientB = FormatResilientText(resilientInfo, bestEntry.level)

        table.insert(displayRows, {
            unit = member.unit,
            entry = bestEntry,
            fullName = member.fullName,
            nameText = GetDisplayName(member.fullName),
            keyText = FormatKeystone(bestEntry),
            scoreText = FormatScore(bestEntry.rating),
            sourceText = bestEntry.source or "-",
            classFile = bestEntry.classFile,
            seenAt = bestEntry.seenAt,
            raiderIODungeon = raiderIOLookup[tonumber(bestEntry.mapID) or 0],
            resilientInfo = resilientInfo,
            resilientText = resilientText,
            resilientColor = {
                r = resilientR,
                g = resilientG,
                b = resilientB,
            },
        })
    end

    return displayRows
end

function mQoL_MythicPlusListing:ApplyWindowPosition(frame)
    frame:ClearAllPoints()

    local anchorTarget = GetWindowAnchorTarget()
    if anchorTarget then
        frame:SetScale(1)
        frame:SetPoint("TOPLEFT", anchorTarget, "TOPRIGHT", WINDOW_ANCHOR_X, WINDOW_ANCHOR_Y)
        return
    end

    local settings = self.db and self.db.settings and self.db.settings.window or self.defaults.window
    frame:SetPoint(settings.point or "CENTER", UIParent, settings.point or "CENTER", settings.x or 0, settings.y or 0)
end

function mQoL_MythicPlusListing:SaveWindowPosition(frame)
    if GetWindowAnchorTarget() then
        return
    end

    if not self.db or not self.db.settings then
        return
    end

    local point, _, _, x, y = frame:GetPoint()
    self.db.settings.window = {
        point = point or "CENTER",
        x = math.floor((x or 0) + 0.5),
        y = math.floor((y or 0) + 0.5),
    }
end

function mQoL_MythicPlusListing:CreateRow(parent, anchorTo, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    if anchorTo then
        row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -ROW_GAP)
        row:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", 0, -ROW_GAP)
    else
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_SIDE, ROW_TOP)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -CONTENT_SIDE, ROW_TOP)
    end

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if index % 2 == 0 then
        row.bg:SetColorTexture(0.10, 0.10, 0.10, 0.90)
    else
        row.bg:SetColorTexture(0.07, 0.07, 0.07, 0.90)
    end

    if CreateFrameBorder then
        row.border = CreateFrameBorder(row, 1, {0.18, 0.18, 0.18, 1})
    end

    row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.nameText:SetPoint("LEFT", row, "LEFT", COLUMN_NAME_X, 0)
    row.nameText:SetWidth(COLUMN_NAME_WIDTH)
    row.nameText:SetJustifyH("LEFT")

    row.keyText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.keyText:SetPoint("LEFT", row, "LEFT", COLUMN_KEY_X, 0)
    row.keyText:SetWidth(COLUMN_KEY_WIDTH)
    row.keyText:SetJustifyH("LEFT")

    row.resilientText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.resilientText:SetPoint("LEFT", row, "LEFT", COLUMN_RESILIENT_X, 0)
    row.resilientText:SetWidth(COLUMN_RESILIENT_WIDTH)
    row.resilientText:SetJustifyH("LEFT")

    row.quickFillButton = CreateCustomButton and CreateCustomButton(row, "Use Key", COLUMN_BUTTON_WIDTH, COLUMN_BUTTON_HEIGHT) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.quickFillButton:SetSize(COLUMN_BUTTON_WIDTH, COLUMN_BUTTON_HEIGHT)
    row.quickFillButton:SetPoint("LEFT", row, "LEFT", COLUMN_BUTTON_X, 0)
    SetButtonLabel(row.quickFillButton, "Use Key")
    row.quickFillButton:SetScript("OnClick", function(currentButton)
        local currentRow = currentButton:GetParent()
        if currentRow and currentRow.data then
            self:QuickFillListing(currentRow.data)
        end
    end)
    row.quickFillButton:SetScript("OnEnter", function(currentButton)
        if not currentButton:IsEnabled() then
            return
        end

        GameTooltip:SetOwner(currentButton, "ANCHOR_TOP")
        GameTooltip:AddLine("Use Key", 1, 0.82, 0)
        GameTooltip:AddLine("Switches Group Listing to this Mythic+ dungeon and applies the selected playstyle.", 1, 1, 1, true)
        local selectedOption = PLAYSTYLE_OPTION_BY_KEY[self:GetSelectedPlaystyleKey()]
        if selectedOption then
            GameTooltip:AddLine("Playstyle: " .. selectedOption.text, 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    row.quickFillButton:SetScript("OnLeave", GameTooltip_Hide)

    row:SetScript("OnEnter", function(currentRow)
        if not currentRow.data then
            return
        end

        GameTooltip:SetOwner(currentRow, "ANCHOR_RIGHT")
        GameTooltip:AddLine(currentRow.data.fullName or currentRow.data.nameText or UNKNOWN, 1, 0.82, 0)
        GameTooltip:AddDoubleLine("Keystone", currentRow.data.keyText or "No key", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Score", currentRow.data.scoreText or "-", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Source", currentRow.data.sourceText or "-", 1, 1, 1, 1, 1, 1)
        if currentRow.data.resilientInfo then
            local resilientColor = currentRow.data.resilientColor or {}
            GameTooltip:AddDoubleLine(
                "Type",
                currentRow.data.resilientText or "Regular Keystone",
                1,
                1,
                1,
                resilientColor.r or 1,
                resilientColor.g or 1,
                resilientColor.b or 1
            )
            GameTooltip:AddDoubleLine(
                "Resilient level",
                (currentRow.data.resilientInfo.resilientLevel or 0) >= 12 and ("+" .. (currentRow.data.resilientInfo.resilientLevel or 0)) or "None",
                1,
                1,
                1,
                0.8,
                1,
                0.8
            )
            GameTooltip:AddDoubleLine(
                "Next resilient progress",
                string.format("%d/%d", currentRow.data.resilientInfo.nextProgress or 0, currentRow.data.resilientInfo.seasonalMaps or 0),
                1,
                1,
                1,
                0.8,
                0.8,
                0.8
            )
            if currentRow.data.resilientInfo.source then
                GameTooltip:AddDoubleLine("Resilient source", currentRow.data.resilientInfo.source, 1, 1, 1, 0.8, 0.8, 0.8)
            end
        end
        if currentRow.data.seenAt and currentRow.data.seenAt > 0 then
            GameTooltip:AddLine("Last update: " .. date("%Y-%m-%d %H:%M", currentRow.data.seenAt), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    return row
end

function mQoL_MythicPlusListing:EnsureWindow()
    if self.window then
        local width, height = GetHubWindowSize()
        self.window:SetSize(width, height)
        return self.window
    end

    local frame = CreateFrame("Frame", "mQoLMythicPlusListingFrame", UIParent)
    local width, height = GetHubWindowSize()
    frame:SetSize(width, height)
    frame:SetScale(1)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetScript("OnShow", function()
        if frame.playstyleDropdown and frame.playstyleDropdown.SetValue then
            frame.playstyleDropdown:SetValue(self:GetSelectedPlaystyleKey())
        end
        self.activityCache = nil
        self:RefreshData(true)
        self:UpdateWindow()
    end)
    frame:SetScript("OnHide", function()
        if mQoL_Styles and mQoL_Styles.HideAllDropdownLists then
            mQoL_Styles.HideAllDropdownLists()
        end
    end)

    if SetBackdrop then
        SetBackdrop(frame, {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        }, {0.03, 0.03, 0.03, 0.96}, {0.22, 0.22, 0.22, 1})
    else
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        frame.bg:SetAllPoints()
        frame.bg:SetColorTexture(0.03, 0.03, 0.03, 0.96)
    end

    if CreateFrameBorder then
        frame.border = CreateFrameBorder(frame, 1, {0.22, 0.22, 0.22, 1})
    end

    table.insert(UISpecialFrames, frame:GetName())
    self:ApplyWindowPosition(frame)

    frame.titleBar = CreateFrame("Frame", nil, frame)
    frame.titleBar:SetPoint("TOPLEFT", 8, -8)
    frame.titleBar:SetPoint("TOPRIGHT", -8, -8)
    frame.titleBar:SetHeight(26)
    frame.titleBar:EnableMouse(true)
    frame.titleBar:RegisterForDrag("LeftButton")
    frame.titleBar:SetScript("OnDragStart", function()
        if GetWindowAnchorTarget() then
            return
        end
        frame:StartMoving()
    end)
    frame.titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SaveWindowPosition(frame)
    end)

    if SetBackdrop then
        SetBackdrop(frame.titleBar, {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        }, {0.08, 0.08, 0.08, 1}, {0.22, 0.22, 0.22, 1})
    else
        frame.titleBar.bg = frame.titleBar:CreateTexture(nil, "BACKGROUND")
        frame.titleBar.bg:SetAllPoints()
        frame.titleBar.bg:SetColorTexture(0.08, 0.08, 0.08, 1)
    end

    frame.titleText = frame.titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.titleText:SetPoint("LEFT", 10, 0)
    frame.titleText:SetText("Party Keystones")

    frame.closeButton = CreateCloseButton and CreateCloseButton(frame.titleBar, 18, function()
        frame:Hide()
    end) or CreateFrame("Button", nil, frame.titleBar)
    frame.closeButton:SetPoint("RIGHT", -4, 0)

    frame.listInset = CreateFrame("Frame", nil, frame)
    frame.listInset:SetPoint("TOPLEFT", LIST_INSET_SIDE, LIST_INSET_TOP)
    frame.listInset:SetPoint("BOTTOMRIGHT", -LIST_INSET_SIDE, LIST_INSET_BOTTOM)
    if SetBackdrop then
        SetBackdrop(frame.listInset, {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        }, {0.02, 0.02, 0.02, 0.94}, {0.18, 0.18, 0.18, 1})
    else
        frame.listInset.bg = frame.listInset:CreateTexture(nil, "BACKGROUND")
        frame.listInset.bg:SetAllPoints()
        frame.listInset.bg:SetColorTexture(0.02, 0.02, 0.02, 0.94)
    end

    frame.toolbar = CreateFrame("Frame", nil, frame.listInset)
    frame.toolbar:SetPoint("TOPLEFT", CONTENT_SIDE, -10)
    frame.toolbar:SetPoint("TOPRIGHT", -CONTENT_SIDE, -10)
    frame.toolbar:SetHeight(TOOLBAR_HEIGHT)

    local refreshButton = CreateCustomButton and CreateCustomButton(frame.toolbar, "Refresh", 84, 22) or CreateFrame("Button", nil, frame.toolbar, "UIPanelButtonTemplate")
    refreshButton:SetSize(84, 22)
    refreshButton:SetPoint("LEFT", frame.toolbar, "LEFT", COLUMN_BUTTON_X, 0)
    SetButtonLabel(refreshButton, "Refresh")
    refreshButton:SetScript("OnClick", function()
        self.activityCache = nil
        self:RefreshData(true)
        self:UpdateWindow()
    end)

    frame.refreshButton = refreshButton

    local playstyleDropdown = CreateCustomDropdown and CreateCustomDropdown(frame.toolbar, 230, PLAYSTYLE_OPTIONS, self:GetSelectedPlaystyleKey(), function(value)
        self:SetSelectedPlaystyleKey(value, true)
        self:UpdateWindow()
    end)
    if playstyleDropdown then
        playstyleDropdown:SetPoint("LEFT", frame.toolbar, "LEFT", 0, 0)
        frame.playstyleDropdown = playstyleDropdown
    end

    frame.headerBar = CreateFrame("Frame", nil, frame.listInset)
    frame.headerBar:SetPoint("TOPLEFT", frame.toolbar, "BOTTOMLEFT", 0, -10)
    frame.headerBar:SetPoint("TOPRIGHT", frame.toolbar, "BOTTOMRIGHT", 0, -10)
    frame.headerBar:SetHeight(HEADER_HEIGHT)
    if SetBackdrop then
        SetBackdrop(frame.headerBar, {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        }, {0.09, 0.09, 0.09, 1}, {0.20, 0.20, 0.20, 1})
    else
        frame.headerBar.bg = frame.headerBar:CreateTexture(nil, "BACKGROUND")
        frame.headerBar.bg:SetAllPoints()
        frame.headerBar.bg:SetColorTexture(0.09, 0.09, 0.09, 1)
    end

    local headers = frame.headerBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    headers:SetPoint("LEFT", COLUMN_NAME_X, 0)
    headers:SetWidth(COLUMN_NAME_WIDTH)
    headers:SetJustifyH("LEFT")
    headers:SetText("Name")

    local keyHeader = frame.headerBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    keyHeader:SetPoint("LEFT", COLUMN_KEY_X, 0)
    keyHeader:SetWidth(COLUMN_KEY_WIDTH)
    keyHeader:SetJustifyH("LEFT")
    keyHeader:SetText("Keystone")

    local resilientHeader = frame.headerBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    resilientHeader:SetPoint("LEFT", COLUMN_RESILIENT_X, 0)
    resilientHeader:SetWidth(COLUMN_RESILIENT_WIDTH)
    resilientHeader:SetJustifyH("LEFT")
    resilientHeader:SetText("Resilient?")

    local quickFillHeader = frame.headerBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    quickFillHeader:SetPoint("LEFT", COLUMN_BUTTON_X, 0)
    quickFillHeader:SetWidth(COLUMN_BUTTON_WIDTH)
    quickFillHeader:SetJustifyH("CENTER")
    quickFillHeader:SetText("Quick Fill")

    frame.rows = {}
    local anchorRow = frame.headerBar
    for index = 1, MAX_GROUP_ROWS do
        local row = self:CreateRow(frame.listInset, anchorRow, index)
        frame.rows[index] = row
        anchorRow = row
    end

    frame.emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.emptyText:SetPoint("CENTER", frame.listInset, "CENTER", 0, 0)
    frame.emptyText:SetText("No party members found.")
    frame.emptyText:Hide()

    self.window = frame
    return frame
end

function mQoL_MythicPlusListing:UpdateWindow()
    local frame = self:EnsureWindow()
    self:ApplyWindowPosition(frame)
    local rows = self:BuildDisplayData()

    for index, row in ipairs(frame.rows) do
        local rowData = rows[index]
        row.data = rowData

        if rowData then
            local color = GetClassColor(rowData.classFile)
            row.nameText:SetText(rowData.nameText)
            row.nameText:SetTextColor(color.r, color.g, color.b)
            row.keyText:SetText(rowData.keyText)
            row.resilientText:SetText(rowData.resilientText)
            if rowData.resilientColor then
                row.resilientText:SetTextColor(rowData.resilientColor.r or 1, rowData.resilientColor.g or 1, rowData.resilientColor.b or 1)
            else
                row.resilientText:SetTextColor(1, 1, 1)
            end

            local canQuickFill, buttonText = self:GetQuickFillState(rowData)
            SetButtonInteractionState(row.quickFillButton, canQuickFill, buttonText)
            row:Show()
        else
            row:Hide()
        end
    end

    frame.emptyText:SetShown(#rows == 0)
    if frame.playstyleDropdown and frame.playstyleDropdown.SetValue then
        frame.playstyleDropdown:SetValue(self:GetSelectedPlaystyleKey())
    end
end

function mQoL_MythicPlusListing:ToggleWindow()
    local frame = self:EnsureWindow()
    if frame:IsShown() then
        self.wantsWindowShown = false
        frame:Hide()
    else
        self.wantsWindowShown = true
        self:ApplyWindowPosition(frame)
        frame:Show()
        self:UpdateWindow()

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if self.wantsWindowShown and self.window and not self.window:IsShown() then
                    self:ApplyWindowPosition(self.window)
                    self.window:Show()
                    self:UpdateWindow()
                end
            end)
        end
    end
end

function mQoL_MythicPlusListing:EnsureEntryButton()
    if self.entryButton or not LFGListFrame or not LFGListFrame.EntryCreation then
        return
    end

    local entryCreation = LFGListFrame.EntryCreation
    local button = CreateCustomButton and CreateCustomButton(entryCreation, "Party Keys", 96, 22) or CreateFrame("Button", nil, entryCreation, "UIPanelButtonTemplate")
    button:SetSize(96, 22)
    SetButtonLabel(button, "Party Keys")
    button:SetPoint("LEFT", entryCreation.Label, "RIGHT", 16, 0)
    button:SetScript("OnClick", function()
        self:ToggleWindow()
    end)
    button:SetScript("OnEnter", function(currentButton)
        GameTooltip:SetOwner(currentButton, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Party Keystones", 1, 0.82, 0)
        GameTooltip:AddLine("Shows current party keys allowing fast group listing.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()

    self.entryButton = button
end

function mQoL_MythicPlusListing:UpdateEntryButton(entryCreation)
    if not self.entryButton then
        return
    end

    entryCreation = entryCreation or (LFGListFrame and LFGListFrame.EntryCreation)
    if not entryCreation then
        self.entryButton:Hide()
        if self.window and self.window:IsShown() then
            self:UpdateWindow()
        end
        return
    end

    local shouldShow = entryCreation:IsShown() and entryCreation.selectedCategory == LFG_CATEGORY_DUNGEONS
    self.entryButton:SetShown(shouldShow)
    if self.window and self.window:IsShown() then
        self:UpdateWindow()
    end
end

function mQoL_MythicPlusListing:TryHookGroupFinder()
    if self.groupFinderHooked or not IsAddonLoadedSafe(BLIZZARD_GROUPFINDER_ADDON) or not LFGListFrame or not LFGListFrame.EntryCreation then
        return
    end

    self.groupFinderHooked = true
    self:EnsureEntryButton()

    LFGListFrame.EntryCreation:HookScript("OnShow", function(entryCreation)
        self:UpdateEntryButton(entryCreation)
    end)
    LFGListFrame.EntryCreation:HookScript("OnHide", function()
        self:UpdateEntryButton(nil)
    end)
    LFGListFrame:HookScript("OnHide", function()
        if self.window and self.window:IsShown() then
            self.wantsWindowShown = false
            self.window:Hide()
        end
    end)
    LFGListFrame:HookScript("OnShow", function()
        if self.window and self.window:IsShown() then
            self:ApplyWindowPosition(self.window)
        end
    end)

    hooksecurefunc("LFGListEntryCreation_Show", function(entryCreation)
        self:UpdateEntryButton(entryCreation)
    end)

    hooksecurefunc("LFGListEntryCreation_Select", function(entryCreation)
        self:UpdateEntryButton(entryCreation)
    end)

    hooksecurefunc("LFGListEntryCreation_SetEditMode", function(entryCreation)
        self:UpdateEntryButton(entryCreation)
    end)

    self:UpdateEntryButton(LFGListFrame.EntryCreation)
end

function mQoL_MythicPlusListing:BuildOwnKeyPayload()
    local fullName, entry = self:GetCurrentPlayerEntry()
    if not fullName or not entry then
        return nil
    end

    return table.concat({
        "KEY",
        fullName,
        tostring(entry.level or 0),
        tostring(entry.mapID or 0),
        tostring(entry.classFile or ""),
        tostring(math.floor((entry.rating or 0) + 0.5)),
        tostring(entry.seenAt or GetServerTime()),
    }, ",")
end

function mQoL_MythicPlusListing:BroadcastOwnKey(force)
    local payload = self:BuildOwnKeyPayload()
    if not payload then
        return
    end

    local distribution = GetCommDistribution()
    if not distribution or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end

    if not force and self.lastPayload == payload and self.lastBroadcastAt and (GetTime() - self.lastBroadcastAt) < 2 then
        return
    end

    self.lastPayload = payload
    self.lastBroadcastAt = GetTime()
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, payload, distribution)
end

function mQoL_MythicPlusListing:ScheduleOwnBroadcast(delay, force)
    if self.broadcastTimer then
        self.broadcastTimer:Cancel()
    end

    self.broadcastTimer = C_Timer.NewTimer(delay or 0, function()
        self.broadcastTimer = nil
        self:BroadcastOwnKey(force)
        if self.window and self.window:IsShown() then
            self:UpdateWindow()
        end
    end)
end

function mQoL_MythicPlusListing:RequestMqoLPartyData(force)
    local distribution = GetCommDistribution()
    if not distribution or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return false
    end

    if not force and self.lastRequestAt and (GetTime() - self.lastRequestAt) < 2 then
        return false
    end

    self.lastRequestAt = GetTime()
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, "REQ", distribution)
    return true
end

function mQoL_MythicPlusListing:RegisterDetailsCallbacks()
    local openRaidLib = self:GetOpenRaidLib()
    if not openRaidLib or not openRaidLib.RegisterCallback then
        return
    end

    if self.detailsCallbacksRegistered and self.registeredOpenRaidLib == openRaidLib then
        return
    end

    if self.detailsCallbacksRegistered and self.registeredOpenRaidLib and self.registeredOpenRaidLib.UnregisterCallback then
        self.registeredOpenRaidLib.UnregisterCallback(self, "KeystoneUpdate", "OnDetailsKeystoneUpdate")
        self.registeredOpenRaidLib.UnregisterCallback(self, "KeystoneWipe", "OnDetailsKeystoneWipe")
    end

    openRaidLib.RegisterCallback(self, "KeystoneUpdate", "OnDetailsKeystoneUpdate")
    openRaidLib.RegisterCallback(self, "KeystoneWipe", "OnDetailsKeystoneWipe")
    self.detailsCallbacksRegistered = true
    self.registeredOpenRaidLib = openRaidLib
end

function mQoL_MythicPlusListing:RequestDetailsData(force)
    local openRaidLib = self:GetOpenRaidLib()
    if not openRaidLib then
        return false
    end

    if not force and self.lastDetailsRequestAt and (GetTime() - self.lastDetailsRequestAt) < 2 then
        return false
    end

    self.lastDetailsRequestAt = GetTime()

    if IsInRaid() and openRaidLib.RequestKeystoneDataFromRaid then
        return openRaidLib.RequestKeystoneDataFromRaid()
    end

    if openRaidLib.RequestKeystoneDataFromParty then
        return openRaidLib.RequestKeystoneDataFromParty()
    end

    return false
end

function mQoL_MythicPlusListing:RefreshData(force)
    if force then
        self.activityCache = nil
        self.raiderIODungeonLookup = nil
    end
    self:RegisterDetailsCallbacks()
    self:GetCurrentPlayerEntry()
    self:BroadcastOwnKey(false)
    self:RequestDetailsData(force)
    self:RequestMqoLPartyData(force)
end

function mQoL_MythicPlusListing:ScheduleRefresh(delay, force)
    if self.refreshTimer then
        self.refreshTimer:Cancel()
    end

    self.refreshTimer = C_Timer.NewTimer(delay or 0, function()
        self.refreshTimer = nil
        self:RefreshData(force)
        if self.window and self.window:IsShown() then
            self:UpdateWindow()
        end
    end)
end

function mQoL_MythicPlusListing:HandleAddonMessage(prefix, message, _, sender)
    if prefix ~= COMM_PREFIX or type(message) ~= "string" then
        return
    end

    local playerFullName = GetUnitFullName("player")
    local senderFullName = NormalizeFullName(sender)
    local command = strmatch(message, "^([^,]+)")

    if senderFullName and playerFullName and senderFullName == playerFullName then
        return
    end

    if command == "REQ" then
        self:ScheduleOwnBroadcast(0.25 + math.random(), true)
        return
    end

    if command ~= "KEY" then
        return
    end

    local _, fullName, level, mapID, classFile, rating, seenAt = strsplit(",", message)
    fullName = NormalizeFullName(fullName or sender)
    if not fullName then
        return
    end

    self:StoreCacheEntry(fullName, {
        level = tonumber(level) or 0,
        mapID = tonumber(mapID) or 0,
        classFile = classFile ~= "" and classFile or nil,
        rating = tonumber(rating) or 0,
        seenAt = tonumber(seenAt) or GetServerTime(),
        source = "mQoL",
    })

    if self.window and self.window:IsShown() then
        self:UpdateWindow()
    end
end

function mQoL_MythicPlusListing:OnDetailsKeystoneUpdate(unitName, keystoneInfo)
    unitName = NormalizeFullName(unitName)
    if not unitName or type(keystoneInfo) ~= "table" then
        return
    end

    self:BuildDetailsEntry(unitName, keystoneInfo)

    if self.window and self.window:IsShown() then
        self:UpdateWindow()
    end
end

function mQoL_MythicPlusListing:OnDetailsKeystoneWipe()
    if self.window and self.window:IsShown() then
        self:UpdateWindow()
    end
end

function mQoL_MythicPlusListing:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        if mQoL_Modules and not mQoL_Modules:ShouldLoadModule(MODULE_KEY) then
            return
        end

        self.enabled = true
        self:InitializeDB()

        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
        end

        self:RegisterDetailsCallbacks()
        self:GetCurrentPlayerEntry()

        if IsAddonLoadedSafe(BLIZZARD_GROUPFINDER_ADDON) then
            self:TryHookGroupFinder()
        end

        self:ScheduleRefresh(2, true)
        return
    end

    if not self.enabled then
        return
    end

    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == BLIZZARD_GROUPFINDER_ADDON then
            self:TryHookGroupFinder()
        elseif loadedAddon == DETAILS_ADDON then
            self:RegisterDetailsCallbacks()
            self:ScheduleRefresh(1, true)
        elseif loadedAddon == ASTRAL_KEYS_ADDON then
            self:ScheduleRefresh(0.5, true)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:ScheduleRefresh(2, true)
    elseif event == "GROUP_ROSTER_UPDATE" then
        self:ScheduleRefresh(1, true)
    elseif event == "BAG_UPDATE_DELAYED" then
        self:GetCurrentPlayerEntry()
        self:ScheduleOwnBroadcast(0.2, false)
    elseif event == "CHAT_MSG_ADDON" then
        self:HandleAddonMessage(...)
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        self:ScheduleRefresh(5, true)
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    mQoL_MythicPlusListing:OnEvent(event, ...)
end)
