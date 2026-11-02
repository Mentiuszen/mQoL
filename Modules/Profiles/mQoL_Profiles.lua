local addonName = ...

-- Profiles: export / import of mQoL settings with conversion between WoW clients.
--
-- An export string is   mQoL1:<checksum>:<base64(payload)>
-- The payload is a plain table (see Collect) written with a small length-prefixed
-- serializer. Import never executes data: the string is parsed by a bounded
-- recursive-descent reader, every value is validated against the whitelist in
-- SECTIONS, and anything the current client cannot use is converted or dropped.
--
-- Scope: shared Hub/module settings and module enable flags only. Per-character
-- or per-realm data (Mailbox lists, Raid/Edit Mode profile bodies, Account
-- Overview, action bar checksums, window positions) is deliberately excluded.
mQoL_Profiles = mQoL_Profiles or {}
local P = mQoL_Profiles

local FORMAT_VERSION = 1
local PREFIX = "mQoL1"
local MAX_STRING_BYTES = 4096
local MAX_NODES = 5000
local MAX_DEPTH = 12

-- Never exported or imported: Graphics is client-specific engine tuning.
local EXCLUDED_MODULES = { Graphics = true }

local DISABLE = mQoL_Database and mQoL_Database.DISABLE or "disable"

---------------------------------------------------------------------------
-- Client helpers
---------------------------------------------------------------------------

local function GetClientInfo()
    return mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
end

local function DescribeClient(ci)
    ci = ci or {}
    return ci.name or ci.versionKey or "Unknown"
end

local function GetAddonVersion()
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(getMeta) ~= "function" then return "?" end
    local ok, value = pcall(getMeta, addonName or "mQoL", "Version")
    return ok and value or "?"
end

---------------------------------------------------------------------------
-- Field schema
---------------------------------------------------------------------------
-- kind: "toggle"  boolean or "disable"      "bool"    boolean only
--       "dnumber" number or "disable"       "number"  number only
--       "string"  short string
-- probe(): optional capability test run at import time on the target client;
--          false means the setting does not exist there and is skipped.
-- schema(ci): optional, for settings whose key layout is chosen by the module
--          itself (Nameplates) rather than by what the client supports.

local function Toggle(probe, schema) return { kind = "toggle", probe = probe, schema = schema } end
local function Bool(schema) return { kind = "bool", schema = schema } end
local function DNumber(min, max, probe) return { kind = "dnumber", min = min, max = max, probe = probe } end
local function Number(min, max) return { kind = "number", min = min, max = max } end

local function IsRetail(ci) return ci.isRetail == true end
local function NotRetail(ci) return not ci.isRetail end

-- Capability probes. When the API needed to probe is missing the setting is
-- assumed available, so a probe can only remove settings it can disprove.
local function CVarProbe(name)
    return function()
        local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
        if type(getter) ~= "function" then return true end
        local ok, value = pcall(getter, name)
        return ok and value ~= nil
    end
end

local function GlobalFunctionProbe(name)
    return function() return type(_G[name]) == "function" end
end

local function ActionBarProbe(bar)
    return function()
        if Settings and type(Settings.GetValue) == "function" then
            local ok, value = pcall(Settings.GetValue, "PROXY_SHOW_ACTIONBAR_" .. bar)
            if ok and value ~= nil then return true end
        end
        if _G["SHOW_MULTI_ACTIONBAR_" .. (bar - 1)] ~= nil then return true end
        -- Settings API present but the bar is unknown, or nothing to test with.
        return not (Settings and type(Settings.GetValue) == "function") and bar <= 5
    end
end

-- Nameplates: Retail splits friendly nameplates into players/minions/NPCs
-- while the other clients use one master toggle plus a minions toggle.
-- Values may be a boolean or "disable"; "disable" means "do not touch the CVar".
local function Combine(...)
    local sawFalse, sawDisable = false, false
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v == true then return true end
        if v == false then sawFalse = true elseif v ~= nil then sawDisable = true end
    end
    if sawFalse then return false end
    if sawDisable then return DISABLE end
    return nil
end

local function TranslateNameplates(src, ci, report)
    local out = {}
    for k, v in pairs(src) do out[k] = v end

    if IsRetail(ci) then
        if out.showFriendlyPlayers == nil and out.showFriendlyNameplates ~= nil then
            out.showFriendlyPlayers = out.showFriendlyNameplates
            report("Nameplates: \"Friendly Nameplates\" mapped to \"Friendly Players\".")
        end
        if out.showFriendlyPlayerMinions == nil and out.showFriendlyMinions ~= nil then
            out.showFriendlyPlayerMinions = out.showFriendlyMinions
            report("Nameplates: friendly minions mapped to \"Friendly Player Minions\".")
        end
    else
        if out.showFriendlyNameplates == nil then
            local combined = Combine(out.showFriendlyPlayers, out.showFriendlyPlayerMinions, out.showFriendlyNpcs)
            if combined ~= nil then
                out.showFriendlyNameplates = combined
                report("Nameplates: Retail friendly players/minions/NPCs merged into \"Friendly Nameplates\".")
            end
        end
        if out.showFriendlyMinions == nil and out.showFriendlyPlayerMinions ~= nil then
            out.showFriendlyMinions = out.showFriendlyPlayerMinions
        end
    end
    return out
end

local SECTIONS = {
    {
        key = "Hub",
        label = "Hub",
        fields = {
            ["display.scale"] = Number(0.5, 2),
            ["display.opacity"] = Number(0.1, 1),
            ["minimap.hide"] = Bool(),
            ["minimap.minimapPos"] = Number(0, 360),
        },
    },
    {
        key = "GeneralQoL",
        label = "General QoL",
        module = "GeneralQoL",
        fields = {
            showLuaErrors = Toggle(CVarProbe("scriptErrors")),
            autoLoot = Toggle(CVarProbe("autoLootDefault")),
            autoQuestTracking = Toggle(CVarProbe("autoQuestWatch")),
            showMyName = Toggle(CVarProbe("UnitNameOwn")),
            fastAutoLoot = Toggle(),
            fastAutoLootSpeed = DNumber(0.01, 0.10),
            autoConsolidatedBuffs = Toggle(CVarProbe("consolidateBuffs")),
            showHead = Toggle(GlobalFunctionProbe("ShowHelm")),
            showCloak = Toggle(GlobalFunctionProbe("ShowCloak")),
        },
    },
    {
        key = "NameplatesQoL",
        label = "Nameplates QoL",
        module = "NameplatesQoL",
        translate = TranslateNameplates,
        fields = {
            showEnemyNameplates = Toggle(CVarProbe("nameplateShowEnemies")),
            showEnemyMinions = Toggle(CVarProbe("nameplateShowEnemyMinions")),
            showEnemyPets = Toggle(CVarProbe("nameplateShowEnemyPets")),
            showEnemyGuardians = Toggle(CVarProbe("nameplateShowEnemyGuardians")),
            showEnemyTotems = Toggle(CVarProbe("nameplateShowEnemyTotems")),
            showEnemyMinus = Toggle(CVarProbe("nameplateShowEnemyMinus")),
            separateEnemyMinions = Bool(),
            showFriendlyPlayers = Toggle(CVarProbe("nameplateShowFriendlyPlayers"), IsRetail),
            showFriendlyPlayerMinions = Toggle(CVarProbe("nameplateShowFriendlyPlayerMinions"), IsRetail),
            showFriendlyNameplates = Toggle(CVarProbe("nameplateShowFriends"), NotRetail),
            showFriendlyMinions = Toggle(CVarProbe("nameplateShowFriendlyMinions"), NotRetail),
            showFriendlyNpcs = Toggle(),
            showFriendlyPets = Toggle(),
            showFriendlyGuardians = Toggle(),
            showFriendlyTotems = Toggle(),
            separateMinions = Bool(),
            nameplateMaxDistance = DNumber(0, 200, CVarProbe("nameplateMaxDistance")),
        },
    },
    {
        key = "ActionBarsQoL",
        label = "Action Bars QoL",
        module = "ActionBarsQoL",
        fields = {
            alwaysShowActionBars = Toggle(CVarProbe("alwaysShowActionBars")),
            autoPushSpellToActionBar = Toggle(CVarProbe("AutoPushSpellToActionBar")),
            autoSelfCast = Toggle(CVarProbe("autoSelfCast")),
            showActionBars2 = Toggle(ActionBarProbe(2)),
            showActionBars3 = Toggle(ActionBarProbe(3)),
            showActionBars4 = Toggle(ActionBarProbe(4)),
            showActionBars5 = Toggle(ActionBarProbe(5)),
            showActionBars6 = Toggle(ActionBarProbe(6)),
            showActionBars7 = Toggle(ActionBarProbe(7)),
            showActionBars8 = Toggle(ActionBarProbe(8)),
        },
    },
    {
        key = "MythicPlusListing",
        label = "Mythic+ Listing",
        module = "MythicPlusListing",
        fields = {
            playstyle = { kind = "string" },
        },
    },
    {
        key = "DungeonTeleportsTab",
        label = "Dungeon Teleports Tab",
        module = "DungeonTeleportsTab",
        fields = {
            popupOnJoin = Toggle(),
            popupOnFull = Toggle(),
        },
    },
}

P.SECTIONS = SECTIONS

---------------------------------------------------------------------------
-- Value helpers
---------------------------------------------------------------------------

local function IsFinite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function SanitizeValue(spec, value)
    local kind = spec.kind
    if kind == "toggle" then
        if type(value) == "boolean" or value == DISABLE then return value end
    elseif kind == "bool" then
        if type(value) == "boolean" then return value end
    elseif kind == "dnumber" or kind == "number" then
        if kind == "dnumber" and value == DISABLE then return value end
        if IsFinite(value) then
            if spec.min and value < spec.min then value = spec.min end
            if spec.max and value > spec.max then value = spec.max end
            return value
        end
    elseif kind == "string" then
        if type(value) == "string" and #value <= 32 then return value end
    end
    return nil
end

local function GetPath(root, path)
    local node = root
    for part in string.gmatch(path, "[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[part]
    end
    return node
end

local function SetPath(root, path, value)
    local node = root
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do
        if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

local function GetSectionRoot(section, create)
    if type(mQoL_DB) ~= "table" then return nil end
    local moduleDB = mQoL_DB[section.key]
    if type(moduleDB) ~= "table" then
        if not create then return nil end
        moduleDB = {}
        mQoL_DB[section.key] = moduleDB
    end
    if type(moduleDB.settings) ~= "table" then
        if not create then return nil end
        moduleDB.settings = {}
    end
    local root = moduleDB.settings
    if section.root then
        if type(root[section.root]) ~= "table" then
            if not create then return nil end
            root[section.root] = {}
        end
        root = root[section.root]
    end
    return root
end

---------------------------------------------------------------------------
-- Serializer (no loadstring; length-prefixed strings, bounded parser)
---------------------------------------------------------------------------

local function Serialize(value, out, depth)
    local t = type(value)
    if t == "boolean" then
        out[#out + 1] = value and "T" or "F"
    elseif t == "number" then
        if not IsFinite(value) then value = 0 end
        out[#out + 1] = "N" .. string.format("%.17g", value) .. ";"
    elseif t == "string" then
        out[#out + 1] = "S" .. #value .. ":" .. value
    elseif t == "table" then
        if depth > MAX_DEPTH then error("profile data is nested too deeply") end
        out[#out + 1] = "{"
        for k, v in pairs(value) do
            local kt, vt = type(k), type(v)
            if (kt == "string" or kt == "number") and (vt == "boolean" or vt == "number" or vt == "string" or vt == "table") then
                Serialize(k, out, depth + 1)
                Serialize(v, out, depth + 1)
            end
        end
        out[#out + 1] = "}"
    end
end

local function Deserialize(text)
    local pos, nodes = 1, 0

    local function fail(msg) error(msg, 0) end

    local function read(depth)
        nodes = nodes + 1
        if nodes > MAX_NODES then fail("profile string is too large") end
        local c = string.sub(text, pos, pos)
        pos = pos + 1
        if c == "T" then return true end
        if c == "F" then return false end
        if c == "N" then
            local stop = string.find(text, ";", pos, true)
            if not stop then fail("truncated number") end
            local n = tonumber(string.sub(text, pos, stop - 1))
            if not IsFinite(n) then fail("invalid number") end
            pos = stop + 1
            return n
        end
        if c == "S" then
            local colon = string.find(text, ":", pos, true)
            if not colon then fail("truncated string") end
            local len = tonumber(string.sub(text, pos, colon - 1))
            if not len or len < 0 or len % 1 ~= 0 or len > MAX_STRING_BYTES then fail("invalid string length") end
            if colon + len > #text then fail("truncated string") end
            local s = string.sub(text, colon + 1, colon + len)
            pos = colon + len + 1
            return s
        end
        if c == "{" then
            if depth > MAX_DEPTH then fail("profile data is nested too deeply") end
            local result = {}
            while true do
                if string.sub(text, pos, pos) == "}" then
                    pos = pos + 1
                    return result
                end
                if pos > #text then fail("truncated table") end
                local k = read(depth + 1)
                if type(k) ~= "string" and type(k) ~= "number" then fail("invalid key") end
                result[k] = read(depth + 1)
            end
        end
        fail("unexpected data at position " .. (pos - 1))
    end

    local ok, result = pcall(read, 1)
    if not ok then return nil, tostring(result) end
    if pos <= #text then return nil, "unexpected trailing data" end
    if type(result) ~= "table" then return nil, "profile root must be a table" end
    return result
end

---------------------------------------------------------------------------
-- Base64 + checksum (plain arithmetic: WoW clients run Lua 5.1)
---------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_ENCODE, B64_DECODE = {}, {}
for i = 1, #B64 do
    local ch = string.sub(B64, i, i)
    B64_ENCODE[i - 1] = ch
    B64_DECODE[ch] = i - 1
end

local function Base64Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local b1, b2, b3 = string.byte(data, i, i + 2)
        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local c1 = math.floor(n / 262144)
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64_ENCODE[c1] .. B64_ENCODE[c2]
            .. (b2 and B64_ENCODE[c3] or "=") .. (b3 and B64_ENCODE[c4] or "=")
    end
    return table.concat(out)
end

local function Base64Decode(text)
    text = string.gsub(text, "%s", "")
    if #text == 0 or #text % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #text, 4 do
        local c1, c2, c3, c4 = string.byte(text, i, i + 3)
        local ch1, ch2 = B64_DECODE[string.char(c1)], B64_DECODE[string.char(c2)]
        local s3, s4 = string.char(c3), string.char(c4)
        local ch3 = s3 ~= "=" and B64_DECODE[s3] or nil
        local ch4 = s4 ~= "=" and B64_DECODE[s4] or nil
        if not ch1 or not ch2 or (s3 ~= "=" and not ch3) or (s4 ~= "=" and not ch4) then return nil end
        if s3 == "=" and s4 ~= "=" then return nil end
        local n = ch1 * 262144 + ch2 * 4096 + (ch3 or 0) * 64 + (ch4 or 0)
        local b1 = math.floor(n / 65536)
        local b2 = math.floor(n / 256) % 256
        local b3 = n % 256
        out[#out + 1] = string.char(b1)
        if ch3 then out[#out + 1] = string.char(b2) end
        if ch4 then out[#out + 1] = string.char(b3) end
    end
    return table.concat(out)
end

local function Checksum(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + string.byte(data, i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%08x", b * 65536 + a)
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------

-- Reads the current settings into a payload table.
function P:Collect()
    local ci = GetClientInfo()
    local payload = {
        format = FORMAT_VERSION,
        addon = GetAddonVersion(),
        created = type(time) == "function" and time() or 0,
        client = {
            key = ci.versionKey or "Unknown",
            name = ci.name or ci.versionKey or "Unknown",
            toc = ci.tocversion or 0,
            version = ci.version or "?",
        },
        sections = {},
        modules = {},
    }

    for _, section in ipairs(SECTIONS) do
        local root = GetSectionRoot(section, false)
        if root then
            local flat = {}
            for name, spec in pairs(section.fields) do
                local value = SanitizeValue(spec, GetPath(root, name))
                if value ~= nil then flat[name] = value end
            end
            if next(flat) then payload.sections[section.key] = flat end
        end
    end

    if mQoL_Modules and mQoL_Modules.AvailableModules then
        for _, module in ipairs(mQoL_Modules.AvailableModules) do
            if not EXCLUDED_MODULES[module.key] then
                payload.modules[module.key] = mQoL_Modules:IsModuleEnabled(module.key) == true
            end
        end
    end

    return payload
end

function P:Encode(payload)
    local out = {}
    local ok, err = pcall(Serialize, payload, out, 1)
    if not ok then return nil, tostring(err) end
    local data = table.concat(out)
    return PREFIX .. ":" .. Checksum(data) .. ":" .. Base64Encode(data)
end

function P:Export()
    return self:Encode(self:Collect())
end

---------------------------------------------------------------------------
-- Import
---------------------------------------------------------------------------

function P:Decode(text)
    if type(text) ~= "string" then return nil, "No profile string." end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")

    local prefix, checksum, body = string.match(text, "^(%w+):(%x+):(.+)$")
    if prefix ~= PREFIX then
        return nil, "This is not an mQoL profile string."
    end

    local data = Base64Decode(body)
    if not data then return nil, "The profile string is damaged (bad encoding)." end
    if Checksum(data) ~= string.lower(checksum) then
        return nil, "The profile string is damaged (checksum mismatch)."
    end

    local payload, err = Deserialize(data)
    if not payload then return nil, "The profile string is damaged (" .. tostring(err) .. ")." end
    if payload.format ~= FORMAT_VERSION then
        return nil, "Unsupported profile format. Update mQoL on this client."
    end
    if type(payload.sections) ~= "table" then payload.sections = {} end
    if type(payload.modules) ~= "table" then payload.modules = {} end
    if type(payload.client) ~= "table" then payload.client = {} end
    return payload
end

-- A setting is importable when the module's key layout allows it (schema) and
-- the running client actually has it (probe).
local function IsFieldAvailable(spec, ci)
    if spec.schema and not spec.schema(ci) then return false end
    if spec.probe then
        local ok, result = pcall(spec.probe)
        if ok and result == false then return false end
    end
    return true
end

-- Converts a decoded payload for the given client (defaults to the running one).
-- Returns a plan: { sections = {[key] = {[field] = value}}, modules = {[key] = bool},
-- report = {lines}, imported = n, dropped = n }. Nothing is written here.
function P:Convert(payload, ci)
    ci = ci or GetClientInfo()
    local plan = { sections = {}, modules = {}, report = {}, imported = 0, dropped = 0, skipped = 0 }
    local report = function(line) plan.report[#plan.report + 1] = line end

    local sourceName = type(payload.client.name) == "string" and payload.client.name or "unknown client"
    local sourceKey = payload.client.key
    plan.sourceName = sourceName
    plan.targetName = DescribeClient(ci)
    plan.converted = sourceKey ~= nil and sourceKey ~= ci.versionKey

    for _, section in ipairs(SECTIONS) do
        local src = payload.sections[section.key]
        if type(src) == "table" then
            local moduleData = section.module and mQoL_Modules and mQoL_Modules:GetModule(section.module)
            if moduleData and not mQoL_Modules:IsModuleAvailable(moduleData) then
                plan.skipped = plan.skipped + 1
                report(section.label .. ": skipped, not available on " .. plan.targetName .. ".")
            else
                if section.translate then src = section.translate(src, ci, report) end
                local out, droppedNames = {}, {}
                for name, spec in pairs(section.fields) do
                    local value = src[name]
                    if value ~= nil then
                        if not IsFieldAvailable(spec, ci) then
                            droppedNames[#droppedNames + 1] = name
                        else
                            local clean = SanitizeValue(spec, value)
                            if clean ~= nil then
                                out[name] = clean
                                plan.imported = plan.imported + 1
                            end
                        end
                    end
                end
                if #droppedNames > 0 then
                    table.sort(droppedNames)
                    plan.dropped = plan.dropped + #droppedNames
                    report(section.label .. ": not present on " .. plan.targetName .. ", skipped: "
                        .. table.concat(droppedNames, ", ") .. ".")
                end
                if next(out) then plan.sections[section.key] = out end
            end
        end
    end

    if mQoL_Modules and mQoL_Modules.AvailableModules then
        for _, module in ipairs(mQoL_Modules.AvailableModules) do
            local wanted = payload.modules[module.key]
            if type(wanted) == "boolean" and not EXCLUDED_MODULES[module.key] then
                if mQoL_Modules:IsModuleAvailable(module) then
                    plan.modules[module.key] = wanted
                elseif wanted then
                    plan.skipped = plan.skipped + 1
                    report("Module " .. module.label .. ": not available on " .. plan.targetName .. ".")
                end
            end
        end
    end

    return plan
end

-- Writes a plan into the saved variables. A reload applies it, because the
-- modules read their settings and enable flags at login.
function P:Apply(plan)
    if type(plan) ~= "table" then return false end
    mQoL_DB = mQoL_DB or {}

    for _, section in ipairs(SECTIONS) do
        local values = plan.sections[section.key]
        if values then
            local root = GetSectionRoot(section, true)
            for name, value in pairs(values) do
                SetPath(root, name, value)
            end
        end
    end

    if mQoL_Modules then
        for key, enabled in pairs(plan.modules) do
            if mQoL_Modules:SetModuleEnabled(key, enabled) then
                mQoL_Modules:MarkModuleSeen(key)
            end
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Saved profiles (mQoL_DB.Profiles.list[name] = payload)
---------------------------------------------------------------------------
-- Payloads are stored as exported, so a profile saved on one client converts
-- for whichever client applies it.

local MAX_NAME_LENGTH = 40

local function GetStore(create)
    if type(mQoL_DB) ~= "table" then return nil end
    if type(mQoL_DB.Profiles) ~= "table" then
        if not create then return nil end
        mQoL_DB.Profiles = {}
    end
    if type(mQoL_DB.Profiles.list) ~= "table" then
        if not create then return nil end
        mQoL_DB.Profiles.list = {}
    end
    return mQoL_DB.Profiles.list
end

function P:NormalizeName(name)
    if type(name) ~= "string" then return nil end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" then return nil end
    return string.sub(name, 1, MAX_NAME_LENGTH)
end

function P:GetSavedNames()
    local names = {}
    for name in pairs(GetStore(false) or {}) do names[#names + 1] = name end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    return names
end

function P:HasSaved(name)
    local store = GetStore(false)
    return store ~= nil and store[name] ~= nil
end

-- payload defaults to the current settings.
function P:SaveProfile(name, payload)
    name = self:NormalizeName(name)
    if not name then return false, "Enter a profile name first." end
    local store = GetStore(true)
    if not store then return false, "Saved variables are not available." end
    store[name] = payload or self:Collect()
    return true, name
end

function P:DeleteProfile(name)
    local store = GetStore(false)
    if store and store[name] then
        store[name] = nil
        return true
    end
    return false
end

function P:ExportSaved(name)
    local store = GetStore(false)
    return store and store[name] and self:Encode(store[name]) or nil
end

-- Applies a stored profile to this client. Returns the plan.
function P:ApplySaved(name)
    local store = GetStore(false)
    local payload = store and store[name]
    if type(payload) ~= "table" then return nil, "Profile not found." end
    payload.sections = type(payload.sections) == "table" and payload.sections or {}
    payload.modules = type(payload.modules) == "table" and payload.modules or {}
    payload.client = type(payload.client) == "table" and payload.client or {}
    local plan = self:Convert(payload)
    self:Apply(plan)
    return plan
end

---------------------------------------------------------------------------
-- Hub panel
---------------------------------------------------------------------------

local function BuildSummary(plan)
    local lines = {}
    lines[#lines + 1] = string.format("|cffffd100Source:|r %s   |cffffd100This client:|r %s", plan.sourceName, plan.targetName)
    if plan.converted then
        lines[#lines + 1] = "Settings will be converted for this game version."
    end
    lines[#lines + 1] = string.format("%d settings ready to import, %d not supported here, %d skipped.",
        plan.imported, plan.dropped, plan.skipped)
    local MAX_LINES = 4
    for index, line in ipairs(plan.report) do
        if index > MAX_LINES then
            lines[#lines + 1] = string.format("- ...and %d more.", #plan.report - MAX_LINES)
            break
        end
        lines[#lines + 1] = "- " .. line
    end
    return table.concat(lines, "\n")
end

local function AppliedMessage(plan, title)
    return string.format("%s\n%d settings applied, %d not supported here.", title, plan.imported, plan.dropped + plan.skipped)
end

local function ShowPopup(opts)
    if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
        mQoL_Styles.ShowCustomPopup(opts)
    elseif opts.onAccept then
        opts.onAccept()
    end
end

-- Deferred: when called from another popup's accept handler, that popup hides
-- the shared popup frame right after the handler returns.
local function ShowReloadPopup(message)
    if not (mQoL_Styles and mQoL_Styles.ShowCustomPopup) then
        print("|cffffff00[mQoL]|r " .. message .. " Type /reload to apply it.")
        return
    end
    mQoL_Compat.After(0, function()
        mQoL_Styles.ShowCustomPopup({
            text = message .. "\n\nA UI reload is required to apply it.\n\nReload now?",
            acceptText = "Reload UI",
            cancelText = "Later",
            onAccept = function() ReloadUI() end,
            width = 450,
            height = 210,
        })
    end)
end

-- Saves a payload under name, asking before replacing an existing profile.
-- onDone(ok, nameOrError) runs once the profile is saved or saving failed.
local function SaveProfileConfirmed(name, payloadProvider, onDone)
    name = P:NormalizeName(name)
    if not name then
        onDone(false, "Enter a profile name first.")
        return
    end
    local function save()
        onDone(P:SaveProfile(name, payloadProvider()))
    end
    if P:HasSaved(name) then
        ShowPopup({
            text = "A profile named \"" .. name .. "\" already exists.\n\nReplace it?",
            acceptText = "Replace",
            cancelText = "Cancel",
            onAccept = save,
            width = 450,
            height = 200,
        })
    else
        save()
    end
end

local function StyleBox(frame, bgColor, borderColor)
    mQoL_Templates.SetBackdrop(frame, { edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }, bgColor, borderColor)
end

local function SetEnabled(button, enabled)
    local method = enabled and button.Enable or button.Disable
    if method then method(button) end
    -- The styled buttons have no disabled look of their own.
    button:SetAlpha(enabled and 1 or 0.4)
end

local function SetVisible(widgets, visible)
    for _, widget in ipairs(widgets) do
        if visible then widget:Show() else widget:Hide() end
    end
end

---------------------------------------------------------------------------
-- Export / import dialog
---------------------------------------------------------------------------

local DIALOG_WIDTH, DIALOG_PAD = 600, 20
local TEXT_TOP, TEXT_HEIGHT = -66, 150
local FOOTER_HEIGHT, STATUS_HEIGHT = 28, 130
local EXPORT_HEIGHT = -TEXT_TOP + TEXT_HEIGHT + FOOTER_HEIGHT + 2 * DIALOG_PAD
local IMPORT_HEIGHT = EXPORT_HEIGHT + STATUS_HEIGHT

local dialog

local function CreateDialog()
    local f = CreateFrame("Frame", "mQoL_ProfilesDialog", UIParent)
    f:SetSize(DIALOG_WIDTH, EXPORT_HEIGHT)
    f:SetPoint("CENTER", 0, 80)
    -- Above the Hub window (DIALOG, level 50), below confirmation popups (FULLSCREEN).
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    table.insert(UISpecialFrames, f:GetName())
    StyleBox(f, { 0.08, 0.08, 0.08, 0.97 }, { 0.4, 0.4, 0.4, 1 })

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", DIALOG_PAD, -18)

    local closeX = mQoL_Templates.CreateCloseButton(f, 20, function() f:Hide() end)
    closeX:SetPoint("TOPRIGHT", -10, -10)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", DIALOG_PAD, -44)
    f.hint:SetWidth(DIALOG_WIDTH - 2 * DIALOG_PAD)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetTextColor(0.75, 0.75, 0.75)

    -- Multi-line text field: a bordered box with a clipped, wheel-scrolled edit box.
    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", DIALOG_PAD, TEXT_TOP)
    box:SetSize(DIALOG_WIDTH - 2 * DIALOG_PAD, TEXT_HEIGHT)
    StyleBox(box, { 0.15, 0.15, 0.15, 1 }, { 0.25, 0.25, 0.25, 1 })

    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetMaxLetters(0)
    edit:SetSize(DIALOG_WIDTH - 2 * DIALOG_PAD - 12, TEXT_HEIGHT - 12)
    scroll:SetScrollChild(edit)
    f.edit, f.scroll = edit, scroll

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - delta * 28
        self:SetVerticalScroll(math.max(0, math.min(value, self:GetVerticalScrollRange())))
    end)
    -- Keep the cursor in view while typing or moving through the text.
    edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local top, offset, visible = -y, scroll:GetVerticalScroll(), scroll:GetHeight()
        if top < offset then
            scroll:SetVerticalScroll(top)
        elseif top + height > offset + visible then
            scroll:SetVerticalScroll(top + height - visible)
        end
    end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if f.onTextChanged then f.onTextChanged(self, userInput) end
    end)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)

    local function FooterButton(text, width)
        return mQoL_Templates.CreateButton(f, text, width, FOOTER_HEIGHT)
    end

    -- Export footer
    local closeButton = FooterButton("Close", 120)
    closeButton:SetPoint("BOTTOMRIGHT", -DIALOG_PAD, DIALOG_PAD)
    closeButton:SetScript("OnClick", function() f:Hide() end)
    local selectButton = FooterButton("Select All", 120)
    selectButton:SetPoint("RIGHT", closeButton, "LEFT", -10, 0)
    selectButton:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    -- Import status and footer
    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", DIALOG_PAD, TEXT_TOP - TEXT_HEIGHT - 12)
    status:SetWidth(DIALOG_WIDTH - 2 * DIALOG_PAD)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")

    local applyButton = FooterButton("Apply and Reload", 160)
    applyButton:SetPoint("BOTTOMRIGHT", -DIALOG_PAD, DIALOG_PAD)
    local saveButton = FooterButton("Save as Profile", 140)
    saveButton:SetPoint("RIGHT", applyButton, "LEFT", -10, 0)

    local SaveImport
    local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", f, "BOTTOMLEFT", DIALOG_PAD, DIALOG_PAD + FOOTER_HEIGHT / 2)
    nameLabel:SetTextColor(1, 0.82, 0)
    nameLabel:SetText("Profile name")
    local nameBox = mQoL_Styles.CreateCustomInputBox(f, 155, FOOTER_HEIGHT, function() SaveImport() end)
    nameBox:SetPoint("BOTTOMLEFT", DIALOG_PAD + 85, DIALOG_PAD)
    nameBox:SetMaxLetters(MAX_NAME_LENGTH)

    local exportWidgets = { closeButton, selectButton }
    local importWidgets = { status, applyButton, saveButton, nameLabel, nameBox }

    local pendingPlan, pendingPayload, summary

    local function CheckImport(text)
        pendingPlan, pendingPayload, summary = nil, nil, ""
        SetEnabled(applyButton, false)
        SetEnabled(saveButton, false)
        if not string.find(text or "", "%S") then
            status:SetText("|cff999999Waiting for a profile string.|r")
            return
        end
        local payload, err = P:Decode(text)
        if not payload then
            status:SetText("|cffff4444" .. tostring(err) .. "|r")
            return
        end
        local plan = P:Convert(payload)
        pendingPayload = payload
        SetEnabled(saveButton, true)
        summary = BuildSummary(plan)
        if plan.imported > 0 or next(plan.modules) then
            pendingPlan = plan
            SetEnabled(applyButton, true)
        else
            summary = summary .. "\n|cffff4444Nothing in this profile can be applied on this client.|r"
        end
        status:SetText(summary)
    end

    applyButton:SetScript("OnClick", function()
        if not pendingPlan then return end
        local plan = pendingPlan
        if P:Apply(plan) then
            f:Hide()
            ShowReloadPopup(AppliedMessage(plan, "Profile imported."))
        end
    end)

    SaveImport = function()
        if not pendingPayload then return end
        local payload = pendingPayload
        SaveProfileConfirmed(nameBox:GetText(), function() return payload end, function(ok, result)
            if not ok then
                status:SetText(summary .. "\n|cffff4444" .. tostring(result) .. "|r")
                nameBox:SetFocus()
                return
            end
            f:Hide()
            if f.onSaved then f.onSaved(result) end
        end)
    end
    saveButton:SetScript("OnClick", SaveImport)

    f:SetScript("OnHide", function()
        edit:ClearFocus()
        nameBox:ClearFocus()
    end)

    function f:OpenExport(title, text)
        SetVisible(importWidgets, false)
        SetVisible(exportWidgets, true)
        self:SetHeight(EXPORT_HEIGHT)
        self.title:SetText(title)
        self.hint:SetText("Press Ctrl+C to copy the string, then use Import in mQoL on the other account or game version.")
        -- Read-only: any typing restores the string.
        self.onTextChanged = function(field, userInput)
            if userInput then
                field:SetText(text)
                field:HighlightText()
            end
        end
        edit:SetText(text)
        scroll:SetVerticalScroll(0)
        self:Show()
        edit:SetFocus()
        edit:HighlightText()
    end

    function f:OpenImport(onSaved)
        SetVisible(exportWidgets, false)
        SetVisible(importWidgets, true)
        self:SetHeight(IMPORT_HEIGHT)
        self.title:SetText("Import Profile")
        self.hint:SetText("Paste an mQoL profile string below (Ctrl+V). It is checked as soon as you paste it.")
        self.onSaved = onSaved
        self.onTextChanged = function(field) CheckImport(field:GetText()) end
        edit:SetText("")
        nameBox:SetText("")
        CheckImport("")
        scroll:SetVerticalScroll(0)
        self:Show()
        edit:SetFocus()
    end

    return f
end

local function GetDialog()
    dialog = dialog or CreateDialog()
    return dialog
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

function P:CreatePanel(parent)
    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "General Settings - Profiles", {
        text = "How Profiles work?",
        textColor = {1, 0.82, 0},
        explanation = "Save your mQoL settings under a name, or export them as a text string and import them on another account or game version.\n\n- On import mQoL checks which settings exist on this client: supported ones are converted and applied, the rest are skipped.\n- Applying a profile changes only the settings it contains and needs a UI reload.\n- Graphics and character-specific data (mailbox lists, raid and edit mode profile contents, account overview) are not included.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        animDuration = 0.25,
    }, "TopSeparator")

    -- One grid for the whole panel: content runs from x = 20 to 790, the width
    -- of the separators.
    local LEFT, RIGHT = 20, 790
    local FIELD_X, GAP = 130, 10
    local CONTROL_HEIGHT = 28
    local SIDE_BUTTON_WIDTH = 170
    local SIDE_BUTTON_X = RIGHT - SIDE_BUTTON_WIDTH
    local PAGE_SIZE, ROW_HEIGHT = 5, 30
    local ROW_BUTTON_WIDTH, ROW_BUTTON_HEIGHT = 95, 24
    local PAGER_SIZE = 24

    local y = contentContainer.currentY - 4

    local function Button(text, width, x, offsetY, height)
        local button = mQoL_Templates.CreateButton(contentContainer, text, width, height or CONTROL_HEIGHT)
        button:SetPoint("TOPLEFT", x, offsetY)
        return button
    end

    -- Section title with a one-line description under it.
    local function SectionHeader(title, description, offsetY)
        local header = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", LEFT, offsetY)
        header:SetText(title)
        local text = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", LEFT, offsetY - 24)
        text:SetTextColor(0.75, 0.75, 0.75)
        text:SetText(description)
        return header, offsetY - 46
    end

    -- Profiles: save under a name, then manage the saved list.
    local profilesHeader
    profilesHeader, y = SectionHeader("Profiles",
        "Save your current settings under a name and switch between saved profiles at any time.", y)

    local SaveCurrent
    local nameLabel = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", contentContainer, "TOPLEFT", LEFT, y - CONTROL_HEIGHT / 2)
    nameLabel:SetTextColor(1, 0.82, 0)
    nameLabel:SetText("Profile name")
    local nameBox = mQoL_Styles.CreateCustomInputBox(contentContainer, SIDE_BUTTON_X - GAP - FIELD_X, CONTROL_HEIGHT,
        function() SaveCurrent() end)
    nameBox:SetPoint("TOPLEFT", FIELD_X, y)
    nameBox:SetMaxLetters(MAX_NAME_LENGTH)
    local saveCurrentButton = Button("Save Current Settings", SIDE_BUTTON_WIDTH, SIDE_BUTTON_X, y)
    y = y - CONTROL_HEIGHT - 12

    -- Bordered list with a fixed number of striped rows.
    local list = CreateFrame("Frame", nil, contentContainer)
    list:SetPoint("TOPLEFT", LEFT, y)
    list:SetSize(RIGHT - LEFT, PAGE_SIZE * ROW_HEIGHT + 2)
    StyleBox(list, { 0.06, 0.06, 0.06, 1 }, { 0.25, 0.25, 0.25, 1 })
    for index = 2, PAGE_SIZE, 2 do
        local stripe = list:CreateTexture(nil, "BORDER")
        stripe:SetPoint("TOPLEFT", 1, -1 - (index - 1) * ROW_HEIGHT)
        stripe:SetSize(RIGHT - LEFT - 2, ROW_HEIGHT)
        mQoL_Compat.SetSolidColor(stripe, 1, 1, 1, 0.03)
    end
    y = y - PAGE_SIZE * ROW_HEIGHT - 2

    local emptyText = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("LEFT", list, "TOPLEFT", 1 + GAP, -1 - ROW_HEIGHT / 2)
    emptyText:SetText("No saved profiles yet.")

    -- Status on the left, pager on the right, under the list.
    y = y - 6
    local statusText = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusText:SetPoint("LEFT", contentContainer, "TOPLEFT", LEFT, y - PAGER_SIZE / 2)
    statusText:SetPoint("RIGHT", contentContainer, "TOPLEFT", RIGHT - 160, y - PAGER_SIZE / 2)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false)
    local nextButton = Button(">", PAGER_SIZE, RIGHT - PAGER_SIZE, y, PAGER_SIZE)
    local prevButton = Button("<", PAGER_SIZE, RIGHT - 2 * PAGER_SIZE - 4, y, PAGER_SIZE)
    local pageLabel = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    pageLabel:SetPoint("RIGHT", prevButton, "LEFT", -GAP, 0)
    y = y - PAGER_SIZE - 14

    local separator = contentContainer:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", LEFT, y)
    separator:SetSize(RIGHT - LEFT, 1)
    mQoL_Compat.SetSolidColor(separator, 1, 1, 1, 0.15)
    y = y - 16

    -- Import / Export: both open the string dialog.
    local _
    _, y = SectionHeader("Import / Export",
        "Share your settings as a text string with another account or game version.", y)
    local exportButton = Button("Export Current Settings", 200, LEFT, y)
    local importButton = Button("Import Profile", 200, LEFT + 200 + GAP, y)
    y = y - CONTROL_HEIGHT - 10

    local listRows = {}
    local page = 1
    local RefreshList

    local function ShowStatus(text, color)
        statusText:SetText(color and ("|cff" .. color .. text .. "|r") or text)
    end
    local OK, ERROR = "00ff00", "ff4444"

    local function OpenExport(title, text, err)
        if text then
            GetDialog():OpenExport(title, text)
        else
            ShowStatus("Export failed: " .. tostring(err or "profile not found"), ERROR)
        end
    end

    -- Buttons are packed against the right edge, the name takes the rest.
    local function CreateRow(index)
        local row = CreateFrame("Frame", nil, list)
        row:SetSize(RIGHT - LEFT - 2, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 1, -1 - (index - 1) * ROW_HEIGHT)

        local inset = (ROW_HEIGHT - ROW_BUTTON_HEIGHT) / 2
        local function RowButton(text, anchor)
            local button = mQoL_Templates.CreateButton(row, text, ROW_BUTTON_WIDTH, ROW_BUTTON_HEIGHT)
            if anchor then
                button:SetPoint("RIGHT", anchor, "LEFT", -5, 0)
            else
                button:SetPoint("RIGHT", -inset, 0)
            end
            return button
        end
        row.delete = RowButton("Delete")
        row.overwrite = RowButton("Overwrite", row.delete)
        row.export = RowButton("Export", row.overwrite)
        row.apply = RowButton("Apply", row.export)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", GAP, 0)
        row.label:SetPoint("RIGHT", row.apply, "LEFT", -GAP, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        return row
    end

    local function BindRow(row, name)
        row.label:SetText(name)
        row.apply:SetScript("OnClick", function()
            ShowPopup({
                text = "Apply profile \"" .. name .. "\"?\n\nSettings that do not exist on this client are skipped. A UI reload is required afterwards.",
                acceptText = "Apply",
                cancelText = "Cancel",
                onAccept = function()
                    local plan, err = P:ApplySaved(name)
                    if plan then
                        ShowStatus("Profile \"" .. name .. "\" applied. Reload the UI to finish.", OK)
                        ShowReloadPopup(AppliedMessage(plan, "Profile \"" .. name .. "\" applied."))
                    else
                        ShowStatus(tostring(err), ERROR)
                    end
                end,
                width = 450,
                height = 200,
            })
        end)
        row.export:SetScript("OnClick", function()
            OpenExport("Export Profile \"" .. name .. "\"", P:ExportSaved(name))
        end)
        row.overwrite:SetScript("OnClick", function()
            ShowPopup({
                text = "Overwrite profile \"" .. name .. "\" with your current settings?",
                acceptText = "Overwrite",
                cancelText = "Cancel",
                onAccept = function()
                    P:SaveProfile(name)
                    ShowStatus("Profile \"" .. name .. "\" updated with your current settings.", OK)
                end,
                width = 450,
                height = 180,
            })
        end)
        row.delete:SetScript("OnClick", function()
            ShowPopup({
                text = "Delete profile \"" .. name .. "\"?",
                acceptText = "Delete",
                cancelText = "Cancel",
                onAccept = function()
                    P:DeleteProfile(name)
                    ShowStatus("Profile \"" .. name .. "\" deleted.")
                    RefreshList()
                end,
                width = 450,
                height = 180,
            })
        end)
    end

    RefreshList = function()
        local names = P:GetSavedNames()
        local pages = math.max(1, math.ceil(#names / PAGE_SIZE))
        if page > pages then page = pages end

        for slot = 1, PAGE_SIZE do
            local row = listRows[slot]
            local name = names[(page - 1) * PAGE_SIZE + slot]
            if name then
                if not row then
                    row = CreateRow(slot)
                    listRows[slot] = row
                end
                BindRow(row, name)
                row:Show()
            elseif row then
                row:Hide()
            end
        end

        if #names == 0 then emptyText:Show() else emptyText:Hide() end
        profilesHeader:SetText(#names > 0 and string.format("Profiles |cff808080(%d)|r", #names) or "Profiles")
        if #names > PAGE_SIZE then
            pageLabel:SetText(string.format("Page %d / %d", page, pages))
            prevButton:Show()
            nextButton:Show()
            SetEnabled(prevButton, page > 1)
            SetEnabled(nextButton, page < pages)
        else
            pageLabel:SetText("")
            prevButton:Hide()
            nextButton:Hide()
        end
    end

    prevButton:SetScript("OnClick", function()
        page = page - 1
        RefreshList()
    end)
    nextButton:SetScript("OnClick", function()
        page = page + 1
        RefreshList()
    end)

    SaveCurrent = function()
        SaveProfileConfirmed(nameBox:GetText(), function() return P:Collect() end, function(ok, result)
            if ok then
                ShowStatus("Saved current settings as \"" .. result .. "\".", OK)
                RefreshList()
            else
                ShowStatus(tostring(result), ERROR)
            end
        end)
    end
    saveCurrentButton:SetScript("OnClick", SaveCurrent)

    exportButton:SetScript("OnClick", function()
        local text, err = P:Export()
        OpenExport("Export Current Settings", text, err)
    end)

    importButton:SetScript("OnClick", function()
        GetDialog():OpenImport(function(name)
            ShowStatus("Imported string saved as \"" .. name .. "\".", OK)
            RefreshList()
        end)
    end)

    scrollFrame:HookScript("OnHide", function()
        if dialog then dialog:Hide() end
    end)

    contentContainer.currentY = y
    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()
    RefreshList()

    return scrollFrame
end
