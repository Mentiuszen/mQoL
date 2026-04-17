mQoL_ProfessionUtils = mQoL_ProfessionUtils or {}

local ProfessionUtils = mQoL_ProfessionUtils
local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local DeepCopy = mQoL_Utils and mQoL_Utils.DeepCopy

local TIER_DEFINITIONS = {
    { key = "classic", label = "Classic", abbr = "CL", aliases = { "classic" } },
    { key = "outland", label = "Outland", abbr = "TBC", aliases = { "outland" } },
    { key = "northrend", label = "Northrend", abbr = "WotLK", aliases = { "northrend" } },
    { key = "cataclysm", label = "Cataclysm", abbr = "Cata", aliases = { "cataclysm" } },
    { key = "pandaria", label = "Pandaria", abbr = "MoP", aliases = { "pandaria" } },
    { key = "draenor", label = "Draenor", abbr = "WoD", aliases = { "draenor" } },
    { key = "legion", label = "Legion", abbr = "Leg", aliases = { "legion", "broken isles" } },
    { key = "bfa", label = "Battle for Azeroth", abbr = "BfA", aliases = { "battle for azeroth", "kul tiran", "zandalari" } },
    { key = "shadowlands", label = "Shadowlands", abbr = "SL", aliases = { "shadowlands" } },
    { key = "dragonflight", label = "Dragonflight", abbr = "DF", aliases = { "dragonflight", "dragon isles" } },
    { key = "warwithin", label = "The War Within", abbr = "TWW", aliases = { "the war within", "khaz algar" } },
    { key = "midnight", label = "Midnight", abbr = "MID", aliases = { "midnight" } },
}

local TIER_INDEX = {}
for index, definition in ipairs(TIER_DEFINITIONS) do
    definition.order = index
    TIER_INDEX[definition.key] = definition
end

ProfessionUtils.TierDefinitions = TIER_DEFINITIONS
ProfessionUtils.TierIndex = TIER_INDEX

local RANK_KEYS = { "rank", "skillLevel", "skill", "level", "current", "value", "currentLevel", "currentRank" }
local MAX_KEYS = { "maxRank", "maxSkillLevel", "max", "cap", "skillCap", "maximum", "maxValue", "maxLevel" }
local TIER_CONTAINER_KEYS = {
    "tiers",
    "tierData",
    "expansions",
    "expansionData",
    "expansionSkills",
    "skillTiers",
    "skills",
}

local function EscapeLuaPattern(text)
    return tostring(text or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function NormalizeLabel(text)
    text = tostring(text or "")
    text = text:lower()
    text = text:gsub("[%-%_]", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

ProfessionUtils.NormalizeLabel = NormalizeLabel

local function BuildTierAbbreviation(label)
    local normalized = NormalizeLabel(label)
    if normalized == "" then
        return "CUR"
    end

    local initials = {}
    for token in normalized:gmatch("%S+") do
        initials[#initials + 1] = token:sub(1, 1):upper()
        if #initials >= 3 then
            break
        end
    end

    if #initials >= 2 then
        return table.concat(initials, "")
    end

    local compact = normalized:gsub("%s+", "")
    return compact:sub(1, math.min(3, #compact)):upper()
end

local function GetTierDefinition(expansionLabel)
    local normalized = NormalizeLabel(expansionLabel)
    if normalized == "" then
        return nil
    end

    for _, definition in ipairs(TIER_DEFINITIONS) do
        if definition.key == normalized then
            return definition
        end

        for _, alias in ipairs(definition.aliases or {}) do
            if NormalizeLabel(alias) == normalized then
                return definition
            end
        end
    end

    return nil
end

local function ExtractExpansionLabel(skillLineName, professionName)
    skillLineName = tostring(skillLineName or "")
    professionName = tostring(professionName or "")

    if skillLineName == "" or (professionName ~= "" and skillLineName == professionName) then
        return ""
    end

    if professionName ~= "" then
        local trimmed = skillLineName:gsub("%s+" .. EscapeLuaPattern(professionName) .. "$", "")
        trimmed = trimmed:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" and trimmed ~= skillLineName then
            return trimmed
        end
    end

    return skillLineName
end

local function BuildTierFromLabel(expansionLabel, rank, maxRank, skillLineID)
    local definition = GetTierDefinition(expansionLabel)
    local entry = {
        skillLineID = skillLineID,
        rawLabel = expansionLabel,
        rank = math.floor(tonumber(rank) or 0),
        maxRank = math.floor(tonumber(maxRank) or 0),
    }

    if definition then
        entry.key = definition.key
        entry.label = definition.label
        entry.abbr = definition.abbr
        entry.order = definition.order
    else
        local displayLabel = expansionLabel ~= "" and expansionLabel or "Current"
        entry.key = NormalizeLabel(displayLabel)
        entry.label = displayLabel
        entry.abbr = BuildTierAbbreviation(displayLabel)
        entry.order = 900
    end

    return entry
end

local function BuildTierEntry(professionName, skillLineName, rank, maxRank, skillLineID)
    return BuildTierFromLabel(ExtractExpansionLabel(skillLineName, professionName), rank, maxRank, skillLineID)
end

local function BuildKnownTierEntry(professionName, skillLineName, rank, maxRank, skillLineID)
    local expansionLabel = ExtractExpansionLabel(skillLineName, professionName)
    if not GetTierDefinition(expansionLabel) then
        return nil
    end

    return BuildTierFromLabel(expansionLabel, rank, maxRank, skillLineID)
end

local function IsUsablePlayerTradeSkillOpen()
    if not C_TradeSkillUI then
        return false
    end

    if type(C_TradeSkillUI.IsTradeSkillReady) == "function" and not C_TradeSkillUI.IsTradeSkillReady() then
        return false
    end

    if type(C_TradeSkillUI.IsTradeSkillLinked) == "function" and C_TradeSkillUI.IsTradeSkillLinked() then
        return false
    end

    if type(C_TradeSkillUI.IsTradeSkillGuild) == "function" and C_TradeSkillUI.IsTradeSkillGuild() then
        return false
    end

    if type(C_TradeSkillUI.IsNPCCrafting) == "function" and C_TradeSkillUI.IsNPCCrafting() then
        return false
    end

    return true
end

local function GetTradeSkillCategoryIDs()
    if not C_TradeSkillUI or type(C_TradeSkillUI.GetCategories) ~= "function" then
        return nil
    end

    local result = { pcall(C_TradeSkillUI.GetCategories) }
    local ok = table.remove(result, 1)
    if not ok then
        return nil
    end

    if #result == 1 and type(result[1]) == "table" then
        return result[1]
    end

    return result
end

local function AddOpenTradeSkillCategoriesToCache(cache)
    if not IsUsablePlayerTradeSkillOpen()
        or type(C_TradeSkillUI.GetBaseProfessionInfo) ~= "function"
        or type(C_TradeSkillUI.GetCategoryInfo) ~= "function" then
        return
    end

    local baseOk, baseInfo = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if not baseOk or type(baseInfo) ~= "table" then
        return
    end

    local professionName = baseInfo.professionName
    if not professionName or professionName == "" or professionName == "UNKNOWN" then
        return
    end

    local categoryIDs = GetTradeSkillCategoryIDs()
    if type(categoryIDs) ~= "table" then
        return
    end

    local bucket = {
        entries = {},
        seen = {},
    }
    cache.byProfession[professionName] = bucket
    cache.byName[NormalizeLabel(professionName)] = bucket
    cache.byID[baseInfo.professionID] = bucket

    for _, categoryID in ipairs(categoryIDs) do
        local categoryOk, categoryInfo = pcall(C_TradeSkillUI.GetCategoryInfo, categoryID)
        if categoryOk and type(categoryInfo) == "table" then
            local rank = categoryInfo.skillLineCurrentLevel
            local maxRank = categoryInfo.skillLineMaxLevel
            local numericRank = math.floor(tonumber(rank) or 0)
            local numericMaxRank = math.floor(tonumber(maxRank) or 0)
            if numericRank > 0 or numericMaxRank > 0 then
                local displayName = categoryInfo.name
                if displayName and displayName ~= "" and displayName ~= professionName then
                    local tier = BuildKnownTierEntry(professionName, displayName, numericRank, numericMaxRank, categoryInfo.skillLineID)
                    if tier then
                        local tierKey = tier.key or tostring(categoryInfo.skillLineID or displayName)
                        local existing = bucket.seen[tierKey]

                        if existing then
                            existing.rank = math.max(existing.rank or 0, tier.rank or 0)
                            existing.maxRank = math.max(existing.maxRank or 0, tier.maxRank or 0)
                        else
                            bucket.seen[tierKey] = tier
                            bucket.entries[#bucket.entries + 1] = tier
                        end
                    end
                end
            end
        end
    end
end

local function BuildTradeSkillLineCache()
    if not clientInfo.isRetail or not C_TradeSkillUI then
        return nil
    end

    local cache = {
        byID = {},
        byName = {},
        byProfession = {},
    }

    AddOpenTradeSkillCategoriesToCache(cache)

    if next(cache.byProfession) then
        return cache
    end

    return nil
end

local function CollectTierEntries(professionName, parentSkillLineID, currentSkillLineName, rank, maxRank, tradeSkillLineCache)
    local entries = {}
    local seen = {}

    local function AddEntry(entry)
        if type(entry) ~= "table" then
            return
        end

        local entryKey = entry.key or tostring(entry.skillLineID or entry.label or (#entries + 1))
        local existing = seen[entryKey]
        if existing then
            existing.rank = math.max(existing.rank or 0, entry.rank or 0)
            existing.maxRank = math.max(existing.maxRank or 0, entry.maxRank or 0)
            return
        end

        seen[entryKey] = entry
        entries[#entries + 1] = entry
    end

    if type(tradeSkillLineCache) == "table" then
        local bucket = tradeSkillLineCache.byID and tradeSkillLineCache.byID[parentSkillLineID]
        if not bucket and tradeSkillLineCache.byName then
            bucket = tradeSkillLineCache.byName[NormalizeLabel(professionName)]
        end

        if type(bucket) == "table" then
            for _, tier in ipairs(bucket.entries or {}) do
                AddEntry(tier)
            end
        end
    end

    AddEntry(BuildTierEntry(professionName, currentSkillLineName, rank, maxRank, parentSkillLineID))

    table.sort(entries, function(a, b)
        local aOrder = tonumber(a.order) or 999
        local bOrder = tonumber(b.order) or 999
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end
        return tostring(a.label or "") < tostring(b.label or "")
    end)

    return entries
end


function ProfessionUtils.GetSnapshot()
    local result = {
        primary = {},
        secondary = {},
    }
    local tradeSkillLineCache = BuildTradeSkillLineCache()

    if not GetProfessions or not GetProfessionInfo then
        return result
    end

    local primaryOne, primaryTwo, archaeology, fishing, cooking, firstAid = GetProfessions()

    local function Add(list, professionIndex)
        if not professionIndex then
            return
        end

        local name, icon, rank, maxRank, _, _, skillLine, _, _, _, skillLineName = GetProfessionInfo(professionIndex)
        if not name then
            return
        end

        list[#list + 1] = {
            name = name,
            icon = icon,
            rank = rank or 0,
            maxRank = maxRank or 0,
            skillLine = skillLine,
            skillLineName = skillLineName,
            tiers = CollectTierEntries(name, skillLine, skillLineName, rank, maxRank, tradeSkillLineCache),
        }
    end

    Add(result.primary, primaryOne)
    Add(result.primary, primaryTwo)
    Add(result.secondary, cooking)
    Add(result.secondary, fishing)
    Add(result.secondary, archaeology)
    Add(result.secondary, firstAid)

    return result
end

function ProfessionUtils.GetOpenableProfessionScans()
    local scans = {}
    if not clientInfo.isRetail or not GetProfessions or not GetProfessionInfo then
        return scans
    end

    local seen = {}
    local primaryOne, primaryTwo, archaeology, fishing, cooking, firstAid = GetProfessions()

    local function Add(professionIndex)
        if not professionIndex then
            return
        end

        local name, icon, _, _, _, _, skillLine = GetProfessionInfo(professionIndex)
        if not name or not skillLine or seen[skillLine] then
            return
        end

        seen[skillLine] = true
        scans[#scans + 1] = {
            name = name,
            icon = icon,
            skillLineID = skillLine,
        }
    end

    Add(primaryOne)
    Add(primaryTwo)
    Add(cooking)
    Add(fishing)
    Add(archaeology)
    Add(firstAid)

    return scans
end

function ProfessionUtils.OpenProfessionForScan(scan)
    if not clientInfo.isRetail or type(scan) ~= "table" then
        return false
    end

    if C_TradeSkillUI and type(C_TradeSkillUI.OpenTradeSkill) == "function" and scan.skillLineID then
        local ok = pcall(C_TradeSkillUI.OpenTradeSkill, scan.skillLineID)
        if ok then
            return true
        end
    end

    if scan.name and type(CastSpellByName) == "function" then
        local ok = pcall(CastSpellByName, scan.name)
        if ok then
            return true
        end
    end

    return false
end

local function ExtractTierNumber(rawTier, keys)
    if type(rawTier) ~= "table" then
        return nil
    end

    for _, key in ipairs(keys) do
        local value = tonumber(rawTier[key])
        if value ~= nil then
            return math.floor(value)
        end
    end

    return nil
end

local function NormalizeTierRecord(rawTier, fallbackKey)
    if type(rawTier) ~= "table" then
        return nil
    end

    local rank = ExtractTierNumber(rawTier, RANK_KEYS)
    local maxRank = ExtractTierNumber(rawTier, MAX_KEYS)
    if rank == nil and maxRank == nil then
        return nil
    end

    local label = rawTier.label
        or rawTier.expansion
        or rawTier.expansionName
        or rawTier.tier
        or rawTier.tierName
        or rawTier.skillLineName
        or rawTier.rawLabel
        or fallbackKey

    local normalized = BuildTierFromLabel(label or "", rank or 0, maxRank or 0, rawTier.skillLineID or rawTier.skillLine or rawTier.id)
    local explicitKey = rawTier.key or fallbackKey
    if explicitKey then
        local definition = TIER_INDEX[NormalizeLabel(explicitKey)]
        if definition then
            normalized.key = definition.key
            normalized.label = definition.label
            normalized.abbr = definition.abbr
            normalized.order = definition.order
        end
    end

    return normalized
end

local function AddNormalizedTier(target, seen, rawTier, fallbackKey)
    local normalized = NormalizeTierRecord(rawTier, fallbackKey)
    if not normalized then
        return
    end

    if not TIER_INDEX[normalized.key or ""] then
        return
    end

    local dedupeKey = normalized.key or normalized.label or tostring(normalized.skillLineID or (#target + 1))
    local existing = seen[dedupeKey]
    if existing then
        existing.rank = math.max(tonumber(existing.rank) or 0, tonumber(normalized.rank) or 0)
        existing.maxRank = math.max(tonumber(existing.maxRank) or 0, tonumber(normalized.maxRank) or 0)
        return
    end

    seen[dedupeKey] = normalized
    target[#target + 1] = normalized
end

function ProfessionUtils.GetNormalizedTiers(professionEntry)
    if type(professionEntry) ~= "table" then
        return nil
    end

    local normalizedTiers = {}
    local seen = {}

    for _, containerKey in ipairs(TIER_CONTAINER_KEYS) do
        local container = professionEntry[containerKey]
        if type(container) == "table" then
            for key, value in pairs(container) do
                if type(value) == "table" then
                    AddNormalizedTier(normalizedTiers, seen, value, type(key) == "string" and key or nil)
                end
            end
        end
    end

    for _, definition in ipairs(TIER_DEFINITIONS) do
        AddNormalizedTier(normalizedTiers, seen, professionEntry[definition.key], definition.key)
    end

    if #normalizedTiers == 0 then
        return nil
    end

    table.sort(normalizedTiers, function(a, b)
        local aOrder = tonumber(a.order) or 999
        local bOrder = tonumber(b.order) or 999
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end
        return tostring(a.label or "") < tostring(b.label or "")
    end)

    return normalizedTiers
end

function ProfessionUtils.CollectListEntries(list)
    if type(list) ~= "table" then
        return nil
    end

    local entries = {}
    local seen = {}

    for _, entry in ipairs(list) do
        if type(entry) == "table" and not seen[entry] then
            seen[entry] = true
            entries[#entries + 1] = entry
        end
    end

    for key, entry in pairs(list) do
        if type(key) ~= "number" and type(entry) == "table" and not seen[entry] then
            seen[entry] = true
            entries[#entries + 1] = entry
        end
    end

    return #entries > 0 and entries or nil
end

local function MergeEntries(existingEntry, fetchedEntry)
    if type(existingEntry) ~= "table" then
        return DeepCopy(fetchedEntry)
    end

    if type(fetchedEntry) ~= "table" then
        local mergedExisting = DeepCopy(existingEntry)
        local normalizedExistingTiers = ProfessionUtils.GetNormalizedTiers(mergedExisting)
        if normalizedExistingTiers and #normalizedExistingTiers > 0 then
            mergedExisting.tiers = normalizedExistingTiers
        end
        return mergedExisting
    end

    local merged = DeepCopy(existingEntry)
    for key, value in pairs(fetchedEntry) do
        if key ~= "tiers" and value ~= nil then
            merged[key] = DeepCopy(value)
        end
    end

    local combinedTiers = {}
    local seen = {}
    for _, sourceEntry in ipairs({ existingEntry, fetchedEntry }) do
        for _, tier in ipairs(ProfessionUtils.GetNormalizedTiers(sourceEntry) or {}) do
            AddNormalizedTier(combinedTiers, seen, tier, tier.key or tier.label)
        end
    end

    if #combinedTiers > 0 then
        merged.tiers = combinedTiers
    end

    return merged
end

local function MergeList(existingList, fetchedList)
    local mergedList = {}
    local fetchedByName = {}
    local usedNames = {}
    local normalizedExistingList = ProfessionUtils.CollectListEntries(existingList)
    local normalizedFetchedList = ProfessionUtils.CollectListEntries(fetchedList)

    if type(normalizedFetchedList) == "table" then
        for _, fetchedEntry in ipairs(normalizedFetchedList) do
            local entryNameKey = NormalizeLabel(fetchedEntry and fetchedEntry.name)
            if entryNameKey ~= "" and not fetchedByName[entryNameKey] then
                fetchedByName[entryNameKey] = fetchedEntry
            end
        end
    end

    if type(normalizedExistingList) == "table" then
        for _, existingEntry in ipairs(normalizedExistingList) do
            local entryNameKey = NormalizeLabel(existingEntry and existingEntry.name)
            local fetchedEntry = entryNameKey ~= "" and fetchedByName[entryNameKey] or nil
            mergedList[#mergedList + 1] = MergeEntries(existingEntry, fetchedEntry)
            if entryNameKey ~= "" then
                usedNames[entryNameKey] = true
            end
        end
    end

    if type(normalizedFetchedList) == "table" then
        for _, fetchedEntry in ipairs(normalizedFetchedList) do
            local entryNameKey = NormalizeLabel(fetchedEntry and fetchedEntry.name)
            if entryNameKey == "" or not usedNames[entryNameKey] then
                mergedList[#mergedList + 1] = MergeEntries(nil, fetchedEntry)
            end
        end
    end

    return mergedList
end

function ProfessionUtils.MergeSnapshot(existingProfessions, fetchedProfessions)
    return {
        primary = MergeList(
            type(existingProfessions) == "table" and existingProfessions.primary or nil,
            type(fetchedProfessions) == "table" and fetchedProfessions.primary or nil
        ),
        secondary = MergeList(
            type(existingProfessions) == "table" and existingProfessions.secondary or nil,
            type(fetchedProfessions) == "table" and fetchedProfessions.secondary or nil
        ),
    }
end

function ProfessionUtils.HasData(professions)
    if type(professions) ~= "table" then
        return false
    end

    local primary = ProfessionUtils.CollectListEntries(professions.primary)
    if type(primary) == "table" and #primary > 0 then
        return true
    end

    local secondary = ProfessionUtils.CollectListEntries(professions.secondary)
    return type(secondary) == "table" and #secondary > 0
end

function ProfessionUtils.GetDisplayEntries(professions)
    if type(professions) ~= "table" then
        return nil
    end

    local source = ProfessionUtils.CollectListEntries(professions.primary)
    if not source then
        source = ProfessionUtils.CollectListEntries(professions.secondary)
    end

    if type(source) ~= "table" or #source == 0 then
        return nil
    end

    local entries = {}
    for index, entry in ipairs(source) do
        if index > 2 then
            break
        end
        entries[#entries + 1] = entry
    end

    return #entries > 0 and entries or nil
end

function ProfessionUtils.GetCurrentTier(professionEntry)
    if type(professionEntry) ~= "table" then
        return nil
    end

    local tiers = ProfessionUtils.GetNormalizedTiers(professionEntry)
    if type(tiers) == "table" and #tiers > 0 then
        local highestKnownTier
        local fallbackTier
        for _, tier in ipairs(tiers) do
            if TIER_INDEX[tier.key or ""] then
                highestKnownTier = tier
            else
                fallbackTier = tier
            end
        end
        return highestKnownTier or fallbackTier
    end

    if professionEntry.skillLineName or professionEntry.rank or professionEntry.maxRank then
        return BuildTierEntry(
            professionEntry.name,
            professionEntry.skillLineName or professionEntry.name,
            professionEntry.rank,
            professionEntry.maxRank,
            professionEntry.skillLine
        )
    end

    return nil
end

function ProfessionUtils.FormatSkillValue(rank, maxRank)
    rank = math.floor(tonumber(rank) or 0)
    maxRank = math.floor(tonumber(maxRank) or 0)
    if rank <= 0 and maxRank <= 0 then
        return "-"
    end
    return string.format("%d/%d", rank, maxRank)
end

function ProfessionUtils.GetSummaryText(professionEntry)
    local currentTier = ProfessionUtils.GetCurrentTier(professionEntry)
    if not currentTier then
        return "-"
    end

    local skillText = ProfessionUtils.FormatSkillValue(currentTier.rank, currentTier.maxRank)
    if currentTier.label == "Current" then
        return skillText
    end

    if currentTier.abbr and currentTier.abbr ~= "" then
        return string.format("%s %s", currentTier.abbr, skillText)
    end

    return skillText
end

function ProfessionUtils.GetDetailRows(professionEntry)
    local rows = {}
    local tiersByKey = {}
    local hasMappedTier = false
    local currentTier = ProfessionUtils.GetCurrentTier(professionEntry)
    local normalizedTiers = ProfessionUtils.GetNormalizedTiers(professionEntry)

    if type(normalizedTiers) == "table" then
        for _, tier in ipairs(normalizedTiers) do
            local tierKey = tier.key or tier.label
            if tierKey then
                tiersByKey[tierKey] = tier
                if TIER_INDEX[tier.key or ""] then
                    hasMappedTier = true
                end
            end
        end
    end

    if currentTier and TIER_INDEX[currentTier.key or ""] and not tiersByKey[currentTier.key] then
        tiersByKey[currentTier.key] = currentTier
        hasMappedTier = true
    end

    if hasMappedTier then
        for _, definition in ipairs(TIER_DEFINITIONS) do
            local tier = tiersByKey[definition.key]
            rows[#rows + 1] = {
                label = definition.label,
                value = tier and ProfessionUtils.FormatSkillValue(tier.rank, tier.maxRank) or "-",
                isActive = tier ~= nil,
            }
        end

        return rows
    end

    rows[#rows + 1] = {
        label = (currentTier and currentTier.label) or "Current",
        value = currentTier and ProfessionUtils.FormatSkillValue(currentTier.rank, currentTier.maxRank) or "-",
        isActive = currentTier ~= nil,
    }
    return rows
end