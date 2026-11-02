local addonName = ...

mQoL_VersionDetection = mQoL_VersionDetection or {}
local D = mQoL_VersionDetection

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
        maxToc = 50599,
        aliases = {},
    },
    {
        key = "Vanilla",
        name = "Classic Era (Vanilla)",
        flag = "isVanilla",
        minToc = 11300,
        maxToc = 11599,
        aliases = {},
    },
    {
        key = "TBC",
        name = "Burning Crusade Classic",
        flag = "isTBC",
        minToc = 20500,
        maxToc = 20599,
        aliases = {},
    },
    {
        key = "Forever",
        name = "Forever",
        flag = "isForever",
        minToc = 16000,
        maxToc = 16099,
        aliases = {},
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

local FLAGS = {
    "isRetail",
    "isMoP",
    "isLegion",
    "isVanilla",
    "isTBC",
    "isForever",
    "isAuto",
}

local function ValidTOC(value)
    return type(value) == "number"
        and value == value
        and value > 0
        and value < math.huge
        and value % 1 == 0
end

local function Register(tree, definition)
    if D.locked then
        return false, "Client identity is locked for this session; register before module startup"
    end

    if type(definition) ~= "table"
        or type(definition.key) ~= "string"
        or definition.key == ""
        or type(definition.flag) ~= "string"
        or not definition.flag:match("^is%a[%w_]*$") then
        return false, "Definition requires a non-empty key and an is-prefixed flag"
    end

    if definition.key == "Auto" or definition.flag == "isAuto" then
        return false, "Auto is reserved"
    end

    local low = definition.toc or definition.minToc
    local high = definition.toc or definition.maxToc or definition.minToc
    if not ValidTOC(low)
        or not ValidTOC(high)
        or low > high
        or definition.match ~= nil
        or (definition.toc and (definition.minToc or definition.maxToc)) then
        return false, "Use one exact TOC or a finite, ordered TOC range"
    end

    if definition.aliases ~= nil and type(definition.aliases) ~= "table" then
        return false, "aliases must be a table"
    end

    local reserved = {}
    for _, list in ipairs({ACTIVE_TREE, LEGACY_TREE}) do
        for _, existing in ipairs(list) do
            if existing.key == definition.key
                or (low <= existing.maxToc and high >= existing.minToc) then
                return false, "Duplicate or overlapping client definition"
            end

            reserved[existing.flag] = true
            for _, alias in ipairs(existing.aliases) do
                reserved[alias] = true
            end
        end
    end

    if reserved[definition.flag] then
        return false, "Client flag is already assigned"
    end

    local aliases = {}
    local seen = {[definition.flag] = true}
    for _, alias in ipairs(definition.aliases or {}) do
        if type(alias) ~= "string"
            or not alias:match("^is%a[%w_]*$")
            or alias == "isAuto"
            or reserved[alias]
            or seen[alias] then
            return false, "Conflicting alias"
        end

        aliases[#aliases + 1] = alias
        seen[alias] = true
    end

    table.insert(tree, 1, {
        key = definition.key,
        name = definition.name or definition.key,
        flag = definition.flag,
        minToc = low,
        maxToc = high,
        aliases = aliases,
    })
    return true
end

function D:RegisterActiveVersion(definition)
    return Register(ACTIVE_TREE, definition)
end

function D:RegisterLegacyVersion(definition)
    return Register(LEGACY_TREE, definition)
end

function D:TranslateVersionKey(key)
    return key
end

function D:Lock()
    self.locked = true
end

function D:Detect()
    if self.locked then
        return self.clientInfo, "Client identity is locked for this session"
    end

    local version, build, date, raw, reason
    if type(GetBuildInfo) == "function" then
        local ok, a, b, c, d = pcall(GetBuildInfo)
        if ok then
            version, build, date, raw = a, b, c, d
        else
            reason = "GetBuildInfo failed: " .. tostring(a)
        end
    else
        reason = "GetBuildInfo is unavailable"
    end

    local toc = tonumber(raw)
    if not ValidTOC(toc) then
        toc = 0
        reason = reason or "Invalid TOC (expected a positive finite integer)"
    end

    local clientInfo = {
        version = version or "Unknown",
        build = build or "0",
        date = date or "",
        rawTOC = raw,
        tocversion = toc,
        tree = "Auto",
        versionKey = "Auto",
        detectionReason = reason,
    }

    for _, flag in ipairs(FLAGS) do
        clientInfo[flag] = false
    end

    self.ActiveClientInfo, self.LegacyClientInfo, self.AutoClientInfo = nil, nil, nil
    local found = false

    if toc > 0 then
        for _, branch in ipairs({
            {name = "Active", defs = ACTIVE_TREE},
            {name = "Legacy", defs = LEGACY_TREE},
        }) do
            for _, definition in ipairs(branch.defs) do
                if toc >= definition.minToc and toc <= definition.maxToc then
                    clientInfo.tree = branch.name
                    clientInfo.versionKey = definition.key
                    clientInfo.name = definition.name
                    clientInfo[definition.flag] = true

                    for _, alias in ipairs(definition.aliases) do
                        clientInfo[alias] = true
                    end

                    found = true
                    break
                end
            end

            if found then
                break
            end
        end
    end

    if not found then
        clientInfo.isAuto = true
        clientInfo.detectionReason = reason
            or "TOC is outside the explicit Active and Legacy ranges"
    end

    self[clientInfo.tree .. "ClientInfo"] = clientInfo
    self.clientInfo = clientInfo
    return clientInfo
end

function D:IsActive()
    return self.clientInfo and self.clientInfo.tree == "Active"
end

function D:IsLegacy()
    return self.clientInfo and self.clientInfo.tree == "Legacy"
end

function D:IsAuto()
    return self.clientInfo and self.clientInfo.tree == "Auto"
end

function D:GetTree()
    return self.clientInfo and self.clientInfo.tree or "Unknown"
end

function D:GetClientInfo()
    return self.clientInfo
end

function D:UsesCapabilityChecks()
    local clientInfo = self.clientInfo
    return clientInfo and (clientInfo.isAuto == true or clientInfo.isForever == true) or false
end

D:Detect()
