mQoL_DB = mQoL_DB or {}

mQoL_Database = {}

-- Return Player Server and Faction
local function GetServerAndFaction()
    local realm = GetRealmName() or "UnknownRealm"
    local faction = UnitFactionGroup("player") or "Neutral"
    return realm, faction
end

-- Migrate Database
function mQoL_Database:MigrateModule(moduleName, defaults)
    -- If not exist create it
    mQoL_DB[moduleName] = mQoL_DB[moduleName] or {}
    local moduleDB = mQoL_DB[moduleName]

    -- create section
    moduleDB.settings = moduleDB.settings or {}
    local settings = moduleDB.settings

    -- add missing settings
    for key, defaultValue in pairs(defaults) do
        if settings[key] == nil then
            settings[key] = defaultValue
            print("|cffffff00[mQoL " .. moduleName .. "]|r Adding missing setting [" .. key .. "] = " .. tostring(defaultValue))
        end
    end

    -- remove old settings
    for key in pairs(settings) do
        if defaults[key] == nil then
            print("|cffffff00[mQoL " .. moduleName .. "]|r Removing obsolete setting [" .. key .. "]")
            settings[key] = nil
        end
    end

    moduleDB.settings = settings

    -- Profiles for servers/faction
    if defaults.profiles then
        moduleDB.profiles = moduleDB.profiles or {}
        local realm, faction = GetServerAndFaction()
        local profileKey = realm .. "-" .. faction
        moduleDB.profiles[profileKey] = moduleDB.profiles[profileKey] or {}
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

-- remove old modules if any exist (may not work not tested)
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