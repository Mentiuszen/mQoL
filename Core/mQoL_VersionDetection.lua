local addonName = ...

mQoL_VersionDetection = mQoL_VersionDetection or {}

local TRANSLATION_MAP = {
    isClassic = "isMoP",
    isMoP = "isClassic",
    isEra = "isVanilla",
    isVanilla = "isEra",
    isBCC = "isTBC",
    isTBC = "isBCC",
}

local function AttachTranslationMetatable(tbl)
    if not tbl then return tbl end
    local mt = {
        __index = function(t, key)
            local alias = TRANSLATION_MAP[key]
            if alias then
                return rawget(t, alias)
            end
            return nil
        end
    }
    setmetatable(tbl, mt)
    return tbl
end

local ACTIVE_TREE = {
    {
        key = "Retail",
        name = "Retail",
        flag = "isRetail",
        minToc = 120000,
        maxToc = 999999,
        aliases = {},
    },
    {
        key = "MoP",
        name = "Mists of Pandaria Classic",
        flag = "isMoP",
        minToc = 50500,
        maxToc = 50505,
        aliases = {"isClassic"},
    },
    {
        key = "Vanilla",
        name = "Classic Era (Vanilla)",
        flag = "isVanilla",
        minToc = 11300,
        maxToc = 11599,
        aliases = {"isEra"},
    },
    {
        key = "TBC",
        name = "Burning Crusade Classic",
        flag = "isTBC",
        minToc = 20500,
        maxToc = 20506,
        aliases = {"isBCC"},
    },
}

local LEGACY_TREE = {
    {
        key = "Legion",
        name = "Legion",
        flag = "isLegion",
        minToc = 70000,
        maxToc = 70300,
        aliases = {},
    },
}

local function MatchesVersion(def, toc)
    if type(def.match) == "function" then
        local ok, res = pcall(def.match, toc)
        return ok and res
    end
    if def.minToc and def.maxToc then
        return toc >= def.minToc and toc <= def.maxToc
    end
    if def.minToc then
        return toc >= def.minToc
    end
    if def.toc then
        return toc == def.toc
    end
    return false
end

function mQoL_VersionDetection:RegisterActiveVersion(def)
    if not def or not def.key then return end
    table.insert(ACTIVE_TREE, 1, def)
end

function mQoL_VersionDetection:RegisterLegacyVersion(def)
    if not def or not def.key then return end
    table.insert(LEGACY_TREE, 1, def)
end

function mQoL_VersionDetection:TranslateVersionKey(key)
    return TRANSLATION_MAP[key] or key
end

function mQoL_VersionDetection:Detect()
    local version, build, date, tocversion = GetBuildInfo()
    tocversion = tonumber(tocversion) or 0

    local clientInfo = {
        version = version,
        build = build,
        date = date,
        tocversion = tocversion,
        tree = "Unknown",
        versionKey = "Unknown",
        isRetail = false,
        isClassic = false,
        isLegion = false,
        isPandaria = false,
        isEra = false,
        isBCC = false,
        isMoP = false,
        isVanilla = false,
        isTBC = false,
        isAuto = false,
    }

    -- 1. Scan ACTIVE_TREE
    for _, def in ipairs(ACTIVE_TREE) do
        if MatchesVersion(def, tocversion) then
            clientInfo.tree = "Active"
            clientInfo.versionKey = def.key
            clientInfo[def.flag] = true
            for _, alias in ipairs(def.aliases or {}) do
                clientInfo[alias] = true
            end
            AttachTranslationMetatable(clientInfo)
            self.ActiveClientInfo = clientInfo
            self.clientInfo = clientInfo
            return clientInfo
        end
    end

    -- 2. Scan LEGACY_TREE
    for _, def in ipairs(LEGACY_TREE) do
        if MatchesVersion(def, tocversion) then
            clientInfo.tree = "Legacy"
            clientInfo.versionKey = def.key
            clientInfo[def.flag] = true
            for _, alias in ipairs(def.aliases or {}) do
                clientInfo[alias] = true
            end
            AttachTranslationMetatable(clientInfo)
            self.LegacyClientInfo = clientInfo
            self.clientInfo = clientInfo
            return clientInfo
        end
    end

    -- 3. Fallback: AUTO Mode
    if mQoL_ClientTest and type(mQoL_ClientTest.GenerateAutoClientInfo) == "function" then
        clientInfo = mQoL_ClientTest:GenerateAutoClientInfo(version, build, date, tocversion)
    else
        clientInfo.tree = "Auto"
        clientInfo.isAuto = true
    end

    AttachTranslationMetatable(clientInfo)
    self.AutoClientInfo = clientInfo
    self.clientInfo = clientInfo
    return clientInfo
end

function mQoL_VersionDetection:IsActive()
    return self.clientInfo and self.clientInfo.tree == "Active"
end

function mQoL_VersionDetection:IsLegacy()
    return self.clientInfo and self.clientInfo.tree == "Legacy"
end

function mQoL_VersionDetection:IsAuto()
    return self.clientInfo and self.clientInfo.tree == "Auto"
end

function mQoL_VersionDetection:GetTree()
    return self.clientInfo and self.clientInfo.tree or "Unknown"
end

function mQoL_VersionDetection:GetClientInfo()
    return self.clientInfo
end

-- Run detection immediately on load
mQoL_VersionDetection:Detect()
