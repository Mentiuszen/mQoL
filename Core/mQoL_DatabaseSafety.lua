local addonName, L = ...

-- Database Safety System
-- This module handles safe migration of new settings for users who have already completed first setup.
-- It scans the database for missing keys and fills them with current game values.
-- If any settings were added, it prompts for a UI reload.

mQoL_DatabaseSafety = mQoL_DatabaseSafety or {}

-- Safety gate flag - blocks all CVar applications until migration is verified
mQoL_DatabaseSafety.isReady = false

-- Initialize safety flag
mQoL_DB = mQoL_DB or {}

-- Check Client Version
local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}

-- Get client version key (same as FirstSetup)
local function GetClientVersion()
    if clientInfo.isRetail then return "Retail" end
    if clientInfo.isLegion then return "Legion" end
    if clientInfo.isClassic then return "Classic" end
    if clientInfo.isEra then return "Era" end
    if clientInfo.isBCC then return "BCC" end
    if clientInfo.isPandaria then return "Pandaria" end
    return "Retail"
end

-- These define which keys should exist in each section
local ExpectedSettingsSchema = {
    Retail = {
        general = {
            "showMyName", "autoLoot", "autoQuestTracking", "showLuaErrors"
        },
        nameplates = { 
            "showEnemyNameplates", "showEnemyMinions", "separateEnemyMinions", 
            "showEnemyPets", "showEnemyGuardians", "showEnemyTotems", "showEnemyMinus",
            "showFriendlyPlayers", "showFriendlyPlayerMinions", "separateMinions",
            "showFriendlyPets", "showFriendlyGuardians", "showFriendlyTotems", 
            "showFriendlyNpcs", "nameplateMaxDistance"
        },
        actionBars = {
            "alwaysShowActionBars", "autoPushSpellToActionBar", "autoSelfCast", "showActionBars2", "showActionBars3",
            "showActionBars4", "showActionBars5", "showActionBars6",
            "showActionBars7", "showActionBars8"
        },
    },
    Legion = {
        general = {
            "showMyName", "autoLoot", "autoQuestTracking", "showLuaErrors"
        },
        nameplates = { 
            "showEnemyNameplates", "showEnemyMinions", "separateEnemyMinions",
            "showEnemyPets", "showEnemyGuardians", "showEnemyTotems", "showEnemyMinus",
            "showFriendlyNameplates", "showFriendlyMinions", "separateMinions",
            "showFriendlyPets", "showFriendlyGuardians", "showFriendlyTotems",
            "nameplateMaxDistance"
        },
        actionBars = {
            "alwaysShowActionBars", "autoSelfCast", "showActionBars2", "showActionBars3",
            "showActionBars4", "showActionBars5"
        },
    },
    Classic = {
        general = {
            "showMyName", "autoLoot", "autoQuestTracking", "showLuaErrors",
            "showHead", "showCloak"
        },
        nameplates = { 
            "showEnemyNameplates", "showEnemyMinions", "separateEnemyMinions",
            "showEnemyPets", "showEnemyGuardians", "showEnemyTotems", "showEnemyMinus",
            "showFriendlyNameplates", "showFriendlyMinions", "separateMinions",
            "showFriendlyPets", "showFriendlyGuardians", "showFriendlyTotems",
            "showFriendlyNpcs", "nameplateMaxDistance"
        },
        actionBars = {
            "alwaysShowActionBars", "autoPushSpellToActionBar", "autoSelfCast", "showActionBars2", "showActionBars3",
            "showActionBars4", "showActionBars5"
        },
    },
    Era = {
        general = {
            "showMyName", "autoLoot", "autoQuestTracking", "showLuaErrors",
            "showHead", "showCloak"
        },
        nameplates = { 
            "showEnemyNameplates", "showEnemyMinions", "separateEnemyMinions",
            "showEnemyPets", "showEnemyGuardians", "showEnemyTotems", "showEnemyMinus",
            "showFriendlyNameplates", "showFriendlyMinions", "separateMinions",
            "showFriendlyPets", "showFriendlyGuardians", "showFriendlyTotems",
            "showFriendlyNpcs", "nameplateMaxDistance"
        },
        actionBars = {
            "alwaysShowActionBars", "autoPushSpellToActionBar", "autoSelfCast", "showActionBars2", "showActionBars3",
            "showActionBars4", "showActionBars5"
        },
    },
    BCC = {
        general = {
            "showMyName", "autoLoot", "autoQuestTracking", "showLuaErrors",
            "showHead", "showCloak"
        },
        nameplates = { 
            "showEnemyNameplates", "showEnemyMinions", "separateEnemyMinions",
            "showEnemyPets", "showEnemyGuardians", "showEnemyTotems", "showEnemyMinus",
            "showFriendlyNameplates", "showFriendlyMinions", "separateMinions",
            "showFriendlyPets", "showFriendlyGuardians", "showFriendlyTotems",
            "showFriendlyNpcs", "nameplateMaxDistance"
        },
        actionBars = {
            "alwaysShowActionBars", "autoPushSpellToActionBar", "autoSelfCast", "showActionBars2", "showActionBars3",
            "showActionBars4", "showActionBars5", "showActionBars6",
            "showActionBars7", "showActionBars8"
        },
    },
    Pandaria = {
        general = {
            "showMyName", "autoLoot", "autoQuestTracking", "showLuaErrors",
            "showHead", "showCloak"
        },
        nameplates = { 
            "showEnemyNameplates", "showFriendlyNameplates", "nameplateMaxDistance"
        },
        actionBars = {
            "alwaysShowActionBars", "autoPushSpellToActionBar", "autoSelfCast", "showActionBars2", "showActionBars3",
            "showActionBars4", "showActionBars5"
        },
    },
}

-- Get current game value for a specific setting (This reads the actual game state, not addon defaults)
local function GetCurrentGameValue(section, key)
    -- General settings
    if section == "general" then
        if key == "showMyName" then
            return GetCVarBool("UnitNameOwn")
        elseif key == "autoLoot" then
            return GetCVarBool("autoLootDefault")
        elseif key == "autoQuestTracking" then
            local val = GetCVarBool("autoQuestWatch")
            return val ~= nil and val or true
        elseif key == "showLuaErrors" then
            return GetCVarBool("scriptErrors")
        elseif key == "showHead" then
            if clientInfo.isClassic or clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC then
                if ShowingHelm then
                    return ShowingHelm()
                end
            end
            return GetCVarBool("showHelm")
        elseif key == "showCloak" then
            if clientInfo.isClassic or clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC then
                if ShowingCloak then
                    return ShowingCloak()
                end
            end
            return GetCVarBool("showCloak")
        end
    end

    -- Nameplate settings
    if section == "nameplates" then
        -- Enemy nameplates
        if key == "showEnemyNameplates" then
            return GetCVarBool("nameplateShowEnemies")
        elseif key == "showEnemyMinions" then
            return GetCVarBool("nameplateShowEnemyMinions")
        elseif key == "showEnemyPets" then
            return GetCVarBool("nameplateShowEnemyPets")
        elseif key == "showEnemyGuardians" then
            return GetCVarBool("nameplateShowEnemyGuardians")
        elseif key == "showEnemyTotems" then
            return GetCVarBool("nameplateShowEnemyTotems")
        elseif key == "showEnemyMinus" then
            return GetCVarBool("nameplateShowEnemyMinus")
        elseif key == "separateEnemyMinions" then -- Addon-specific toggle, default to false
            return false

        -- Friendly nameplates (Retail 12.0.0+)
        elseif key == "showFriendlyPlayers" then
            if not clientInfo.isRetail then return nil end
            return GetCVarBool("nameplateShowFriendlyPlayers")
        elseif key == "showFriendlyPlayerMinions" then
            if not clientInfo.isRetail then return nil end
            return GetCVarBool("nameplateShowFriendlyPlayerMinions")
        elseif key == "showFriendlyNpcs" then
            local cvar = clientInfo.isRetail and "nameplateShowFriendlyNpcs" or "nameplateShowFriendlyNPCs"
            return GetCVarBool(cvar)
        elseif key == "showFriendlyPets" then
            local cvar = clientInfo.isRetail and "nameplateShowFriendlyPlayerPets" or "nameplateShowFriendlyPets"
            return GetCVarBool(cvar)
        elseif key == "showFriendlyGuardians" then
            local cvar = clientInfo.isRetail and "nameplateShowFriendlyPlayerGuardians" or "nameplateShowFriendlyGuardians"
            return GetCVarBool(cvar)
        elseif key == "showFriendlyTotems" then
            local cvar = clientInfo.isRetail and "nameplateShowFriendlyPlayerTotems" or "nameplateShowFriendlyTotems"
            return GetCVarBool(cvar)
        elseif key == "separateMinions" then -- Addon-specific toggle, default to false
            return false

        -- Friendly nameplates (non-Retail)
        elseif key == "showFriendlyNameplates" then
            return GetCVarBool("nameplateShowFriends")
        elseif key == "showFriendlyMinions" then
            return GetCVarBool("nameplateShowFriendlyMinions")

        -- Nameplates Distance
        elseif key == "nameplateMaxDistance" then
            local val = GetCVar("nameplateMaxDistance")
            return val and tonumber(val) or 40
        end
    end

    -- Action bar settings
    if section == "actionBars" then
        if key == "alwaysShowActionBars" then
            return GetCVarBool("alwaysShowActionBars")
        elseif key == "autoPushSpellToActionBar" then
            if clientInfo.isLegion then return nil end
            local val = GetCVarBool("AutoPushSpellToActionBar")
            return val ~= nil and val or true
        elseif key == "autoSelfCast" then
            local val = GetCVarBool("autoSelfCast")
            return val ~= nil and val or true
        end

        -- Action bars 2-8
        local barNum = key:match("showActionBars(%d+)")
        if barNum then
            barNum = tonumber(barNum)
            if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC then
                local proxyKey = "PROXY_SHOW_ACTIONBAR_" .. barNum
                if Settings and Settings.GetValue then
                    local ok, val = pcall(Settings.GetValue, proxyKey)
                    if ok then return val end
                end
                return false
            elseif clientInfo.isLegion or clientInfo.isPandaria then
                local globalVar = "SHOW_MULTI_ACTIONBAR_" .. (barNum - 1)
                local val = _G[globalVar]
                return val == "1" or val == true
            end
        end
    end
    return nil -- Return nil if we can't determine the value (will use fallback)
end

-- Fallback defaults when game value cannot be determined (used when GetCurrentGameValue returns nil)
local function GetFallbackValue(key)
    local fallbacks = {
        -- General
        showMyName = true,
        autoLoot = true,
        autoQuestTracking = true,
        showLuaErrors = false,
        showHead = true,
        showCloak = true,

        -- Nameplates - enemy
        showEnemyNameplates = true,
        showEnemyMinions = true,
        separateEnemyMinions = false,
        showEnemyPets = true,
        showEnemyGuardians = true,
        showEnemyTotems = true,
        showEnemyMinus = true,

        -- Nameplates - friendly
        showFriendlyPlayers = false,
        showFriendlyPlayerMinions = false,
        showFriendlyNpcs = false,
        showFriendlyPets = false,
        showFriendlyGuardians = false,
        showFriendlyTotems = false,
        separateMinions = false,
        showFriendlyNameplates = false,
        showFriendlyMinions = false,
        nameplateMaxDistance = 40,

        -- Action Bars
        alwaysShowActionBars = true,
        autoPushSpellToActionBar = false,
        autoSelfCast = true,
        showActionBars2 = true,
        showActionBars3 = true,
        showActionBars4 = true,
        showActionBars5 = true,
        showActionBars6 = false,
        showActionBars7 = false,
        showActionBars8 = false,
    }
    return fallbacks[key]
end

-- Check if safety system is ready (scan complete)
function mQoL_DatabaseSafety:IsReady()
    return self.isReady == true
end

-- Show reload popup using mQoL_Styles if available
local function ShowReloadPopup(migratedKeys)
    local message = "mQoL has detected new settings that were added in this update.\n\n"
    message = message .. "The following settings were initialized from your current game values:\n"

    for i, keyInfo in ipairs(migratedKeys) do
        if i <= 5 then
            message = message .. "\n• " .. keyInfo
        elseif i == 6 then
            message = message .. "\n• ... and " .. (#migratedKeys - 5) .. " more"
            break
        end
    end

    message = message .. "\n\nA UI reload is required to apply these changes properly."

    if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
        mQoL_Styles.ShowCustomPopup({
            text = message,
            acceptText = "Reload UI",
            cancelText = "Later",
            onAccept = function()
                ReloadUI()
            end,
            onCancel = function()
                print("|cffffff00[mQoL Safety]|r You can reload later with /reload to apply changes.")
            end,
            width = 450,
            height = 280,
        })
    else
        -- Fallback to StaticPopup
        StaticPopupDialogs["MQOL_SAFETY_RELOAD"] = {
            text = message,
            button1 = "Reload UI",
            button2 = "Later",
            OnAccept = function()
                ReloadUI()
            end,
            OnCancel = function()
                print("|cffffff00[mQoL Safety]|r You can reload later with /reload to apply changes.")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = false,
            preferredIndex = 3,
        }
        StaticPopup_Show("MQOL_SAFETY_RELOAD")
    end
end

-- Main scan and migrate function
function mQoL_DatabaseSafety:ScanAndMigrate()
    -- Only run if first setup is complete
    if not mQoL_DB.firstSetupDone then
        -- First setup not done - let FirstSetup handle it
        self.isReady = true
        return false, "First setup not done"
    end

    local versionKey = GetClientVersion()
    local schema = ExpectedSettingsSchema[versionKey]
    if not schema then
        print("|cffff5555[mQoL Safety]|r Unknown client version: " .. versionKey)
        self.isReady = true
        return false, "Unknown client version"
    end

    -- Ensure MainQoL structure exists
    mQoL_DB["MainQoL"] = mQoL_DB["MainQoL"] or {}
    mQoL_DB["MainQoL"].settings = mQoL_DB["MainQoL"].settings or {}
    local settings = mQoL_DB["MainQoL"].settings

    local migratedCount = 0
    local migratedKeys = {}

    -- Scan each section for missing keys
    for sectionName, expectedKeys in pairs(schema) do
        -- Ensure section exists
        settings[sectionName] = settings[sectionName] or {}
        local section = settings[sectionName]

        -- Check each expected key
        for _, key in ipairs(expectedKeys) do
            if section[key] == nil then
                -- Key is missing - get current game value
                local gameValue = GetCurrentGameValue(sectionName, key)

                -- Use game value if available, otherwise use fallback
                local finalValue = gameValue
                if finalValue == nil then
                    finalValue = GetFallbackValue(key)
                end

                -- Save the value
                section[key] = finalValue
                migratedCount = migratedCount + 1
                table.insert(migratedKeys, string.format("%s.%s = %s", sectionName, key, tostring(finalValue)))
            end
        end

    end

    -- Mark as ready
    self.isReady = true

    -- If we migrated anything, show reload popup
    if migratedCount > 0 then
        print("|cff00ff00[mQoL Safety]|r Added " .. migratedCount .. " new setting(s) from your current game values.")
        print("|cff00ff00[mQoL Safety]|r Your existing settings were preserved.")

        -- Delay popup slightly to ensure UI is ready
        C_Timer.After(1, function()
            ShowReloadPopup(migratedKeys)
        end)

        return true, migratedCount
    end

    return false, 0
end

-- Event handler - run scan on PLAYER_LOGIN
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- Run scan immediately (synchronously) before any CVars can be applied (to ensure safety gate is up until scan is complete)
    mQoL_DatabaseSafety:ScanAndMigrate()
end)