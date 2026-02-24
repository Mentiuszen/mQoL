mQoL_DB = mQoL_DB or {}

mQoL_Database = {}

mQoL_Database.DISABLE = "disable"

function mQoL_Database:IsDisabled(value)
	return value == self.DISABLE or value == nil
end

-- Return Player Server and Faction
local function GetServerAndFaction()
    local realm = GetRealmName() or "UnknownRealm"
    local faction = UnitFactionGroup("player") or "Neutral"
    return realm, faction
end

local function CloneValue(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[CloneValue(k, seen)] = CloneValue(v, seen)
    end
    return copy
end

function mQoL_Database:EnsureProfile(moduleName, profileDefaults)
    mQoL_DB[moduleName] = mQoL_DB[moduleName] or {}
    local moduleDB = mQoL_DB[moduleName]
    moduleDB.profiles = moduleDB.profiles or {}

    local realm, faction = GetServerAndFaction()
    local profileKey = realm .. "-" .. faction

    local defaults = profileDefaults or {}
    local profile = moduleDB.profiles[profileKey]
    if type(profile) ~= "table" then
        profile = CloneValue(defaults)
        moduleDB.profiles[profileKey] = profile
        return profile
    end

    for key, defaultValue in pairs(defaults) do
        if profile[key] == nil then
            profile[key] = CloneValue(defaultValue)
        end
    end

    for key in pairs(profile) do
        if defaults[key] == nil then
            profile[key] = nil
        end
    end

    return profile
end

function mQoL_Database:SaveProfile(moduleName, profile)
    if moduleName == nil then return end
    mQoL_DB[moduleName] = mQoL_DB[moduleName] or {}
    local moduleDB = mQoL_DB[moduleName]
    moduleDB.profiles = moduleDB.profiles or {}

    local realm, faction = GetServerAndFaction()
    local profileKey = realm .. "-" .. faction
    moduleDB.profiles[profileKey] = profile
end

-- Migrate Database
function mQoL_Database:MigrateModule(moduleName, defaults, opts)
    defaults = defaults or {}
    opts = opts or {}

    -- If not exist create it
    mQoL_DB[moduleName] = mQoL_DB[moduleName] or {}
    local moduleDB = mQoL_DB[moduleName]

    -- create section
    moduleDB.settings = moduleDB.settings or {}
    local settings = moduleDB.settings

    -- add missing settings
    for key, defaultValue in pairs(defaults) do
        if key ~= "profiles" and settings[key] == nil then
            settings[key] = CloneValue(defaultValue)
            print("|cffffff00[mQoL " .. moduleName .. "]|r Adding missing setting [" .. key .. "] = " .. tostring(defaultValue))
        end
    end

    -- remove old settings
    for key in pairs(settings) do
        if key == "profiles" or defaults[key] == nil then
            print("|cffffff00[mQoL " .. moduleName .. "]|r Removing obsolete setting [" .. key .. "]")
            settings[key] = nil
        end
    end

    moduleDB.settings = settings

    -- Profiles for servers/faction
    local enableProfiles = (defaults and defaults.profiles) or opts.profiles or (opts.profileDefaults ~= nil)
    if enableProfiles then
        if opts.profileDefaults ~= nil then
            self:EnsureProfile(moduleName, opts.profileDefaults)
        else
            moduleDB.profiles = moduleDB.profiles or {}
            local realm, faction = GetServerAndFaction()
            local profileKey = realm .. "-" .. faction
            moduleDB.profiles[profileKey] = moduleDB.profiles[profileKey] or {}
        end
    end

    return moduleDB
end

-- set settings
function mQoL_Database:SetSettings(moduleName, section, key, value)
    mQoL_DB[moduleName] = mQoL_DB[moduleName] or {}
    mQoL_DB[moduleName].settings = mQoL_DB[moduleName].settings or {}
    local settings = mQoL_DB[moduleName].settings

    if key ~= nil and section ~= nil then
        if type(settings[section]) ~= "table" then
            settings[section] = {}
        end
        settings[section][key] = value
    elseif key ~= nil and section == nil then
        settings[key] = value
    elseif section ~= nil then
        settings[section] = value
    else
        mQoL_DB[moduleName].settings = value
    end
end

-- get settings
function mQoL_Database:GetSettings(moduleName, section, key)
    mQoL_DB[moduleName] = mQoL_DB[moduleName] or {}
    mQoL_DB[moduleName].settings = mQoL_DB[moduleName].settings or {}
    local settings = mQoL_DB[moduleName].settings

    if section ~= nil and key ~= nil then
        settings[section] = settings[section] or {}
        return settings[section][key]
    elseif section ~= nil then
        settings[section] = settings[section] or {}
        return settings[section]
    else
        return settings
    end
end

-- get server/faction profile
function mQoL_Database:GetProfile(moduleName)
    local moduleDB = mQoL_DB[moduleName]
    if not moduleDB or not moduleDB.profiles then return nil end
    local realm, faction = GetServerAndFaction()
    local profileKey = realm .. "-" .. faction
    return moduleDB.profiles[profileKey]
end

-- remove old modules if any exist
function mQoL_Database:CleanupModules(activeModules)
    local valid = {}
    for _, modName in ipairs(activeModules) do
        valid[modName] = true
    end

    for modName in pairs(mQoL_DB) do
        if modName ~= "firstSetupDone" and not valid[modName] then
            print("|cffffff00[mQoL]|r Removing obsolete module section [" .. modName .. "]")
            mQoL_DB[modName] = nil
        end
    end
end