local addonName, _ = ...
mQoL_Main = mQoL_Main or {}

--mQoL ToC Detection
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
	return
end

local clientInfo = mQoL_VersionDetection.clientInfo
local DISABLE = mQoL_Database.DISABLE

-- Styles
local CreateCustomScrollbar = mQoL_Styles.CreateCustomScrollbar
local CreateCustomButton = mQoL_Styles.CreateCustomButton
local CreateCustomDropdown = mQoL_Styles.CreateCustomDropdown
local CreateCustomSlider = mQoL_Styles.CreateCustomSlider
local CreateCustomInputBox = mQoL_Styles.CreateCustomInputBox
local CreateCustomCheckbox = mQoL_Styles.CreateCustomCheckbox

--Info Box
local CreateInfoSection = mQoL_Hub.CreateInfoSection

-- Default settings (handled by First Setup and DatabaseSafety)
mQoL_Main.defaults = {
    general = {},
    nameplates = {},
    actionBars = {},
}

function mQoL_Main:InitializeDB()
    self.db = mQoL_Database:MigrateModule("MainQoL", mQoL_Main.defaults)
end

-- Apply CVar with safety gate
function applyCVar(cvar, value)
    -- Safety gate - block CVar applications until DatabaseSafety verifies the database
    -- This prevents overwriting user settings on first load of updated addon
    if mQoL_DatabaseSafety and not mQoL_DatabaseSafety:IsReady() then
        return
    end

    if mQoL_Database:IsDisabled(value) then return end

    if value == true then
        SetCVar(cvar, 1)
    elseif value == false then
        SetCVar(cvar, 0)
    elseif type(value) == "number" then
        SetCVar(cvar, value)
    end
end

-- Apply all settings (better dont use this one because it applies everything at once and action bars will taint on retail for sure)
function mQoL_Main:ApplySettings()
    local s = self.db and self.db.settings

    if not s then
        return
    end

    self:ApplyGeneralSettings(s.general)
    C_Timer.After(0.5, function() self:ApplyNameplateSettings(s.nameplates) end)
    self:ApplyActionBarVisibilitySettings(s.actionBars)
    self:ApplyActionBarSettings(s.actionBars)
end

function mQoL_Main:ApplyGeneralSettings(g)
    if not g then return end
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("GeneralQoL") then return end

    local function apply_showLuaErrors(value)
        applyCVar("scriptErrors", value)
    end

    local function apply_autoLoot(value)
        applyCVar("autoLootDefault", value)
    end

    local function apply_autoLootRate(value)
        applyCVar("autoLootRate", value)
    end

    local function apply_autoQuestTracking(value)
        applyCVar("autoQuestWatch", value)
    end

    local function apply_showMyName(value)
        applyCVar("UnitNameOwn", value)
    end

    local function apply_showHead(value)
        if not mQoL_Database:IsDisabled(value) and type(ShowHelm) == "function" and (clientInfo.isClassic or clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC) then
            ShowHelm(value == true)
        end
    end

    local function apply_showCloak(value)
        if not mQoL_Database:IsDisabled(value) and type(ShowCloak) == "function" and (clientInfo.isClassic or clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC) then
            ShowCloak(value == true)
        end
    end

    -- Apply all at once
    apply_showLuaErrors(g.showLuaErrors)
    apply_autoLoot(g.autoLoot)
    apply_autoLootRate(g.autoLootRate)
    apply_autoQuestTracking(g.autoQuestTracking)
    apply_showMyName(g.showMyName)
    apply_showHead(g.showHead)
    apply_showCloak(g.showCloak)

    -- Export to object for later GUI usage
    self.ApplySetting = self.ApplySetting or {}
    self.ApplySetting.General = {
        showLuaErrors = apply_showLuaErrors,
        autoLoot = apply_autoLoot,
        autoLootRate = apply_autoLootRate,
        autoQuestTracking = apply_autoQuestTracking,
        showMyName = apply_showMyName,
        showHead = apply_showHead,
        showCloak = apply_showCloak,
    }
end

function mQoL_Main:ApplyNameplateSettings(np)
    if not np then return end
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("NameplatesQoL") then return end

    local function apply_showEnemyNameplates(value)
        applyCVar("nameplateShowEnemies", value)
    end

    -- Retail: Enemy minion CVars
    local function apply_showEnemyMinions(value)
        applyCVar("nameplateShowEnemyMinions", value)
    end

    local function apply_showEnemyPets(value)
        applyCVar("nameplateShowEnemyPets", value)
    end

    local function apply_showEnemyGuardians(value)
        applyCVar("nameplateShowEnemyGuardians", value)
    end

    local function apply_showEnemyTotems(value)
        applyCVar("nameplateShowEnemyTotems", value)
    end

    local function apply_showEnemyMinus(value)
        applyCVar("nameplateShowEnemyMinus", value)
    end

    -- Non-retail: single friendly nameplates CVar
    local function apply_showFriendlyNameplates(value)
        applyCVar("nameplateShowFriends", value)
    end

    -- Retail 12.0.0+: split friendly nameplates CVars
    local function apply_showFriendlyPlayers(value)
        applyCVar("nameplateShowFriendlyPlayers", value)
    end

    local function apply_showFriendlyPlayerMinions(value)
        applyCVar("nameplateShowFriendlyPlayerMinions", value)
    end

    local function apply_showFriendlyNpcs(value)
        applyCVar("nameplateShowFriendlyNpcs", value)
    end

    -- Retail: separate friendly minion type CVars
    local function apply_showFriendlyPets(value)
        applyCVar("nameplateShowFriendlyPlayerPets", value)
    end

    local function apply_showFriendlyGuardians(value)
        applyCVar("nameplateShowFriendlyPlayerGuardians", value)
    end

    local function apply_showFriendlyTotems(value)
        applyCVar("nameplateShowFriendlyPlayerTotems", value)
    end

    local function apply_nameplateShowAll(np)
        if not np then return end

        -- Safety gate check
        if mQoL_DatabaseSafety and not mQoL_DatabaseSafety:IsReady() then
            return
        end

        local showEnemy = (not mQoL_Database:IsDisabled(np.showEnemyNameplates)) and np.showEnemyNameplates or false

        local showFriendly
        if clientInfo.isRetail then
            local friendlyPlayers = (not mQoL_Database:IsDisabled(np.showFriendlyPlayers)) and np.showFriendlyPlayers or false
            local friendlyNpcs = (not mQoL_Database:IsDisabled(np.showFriendlyNpcs)) and np.showFriendlyNpcs or false

            local friendlyMinions
            if np.separateMinions then
                local pets = (not mQoL_Database:IsDisabled(np.showFriendlyPets)) and np.showFriendlyPets or false
                local guardians = (not mQoL_Database:IsDisabled(np.showFriendlyGuardians)) and np.showFriendlyGuardians or false
                local totems = (not mQoL_Database:IsDisabled(np.showFriendlyTotems)) and np.showFriendlyTotems or false
                friendlyMinions = pets or guardians or totems
            else
                friendlyMinions = (not mQoL_Database:IsDisabled(np.showFriendlyPlayerMinions)) and np.showFriendlyPlayerMinions or false
            end

            showFriendly = friendlyPlayers or friendlyMinions or friendlyNpcs
        else
            showFriendly = (not mQoL_Database:IsDisabled(np.showFriendlyNameplates)) and np.showFriendlyNameplates or false
        end

        local showAll = (showEnemy or showFriendly) and 1 or 0
        SetCVar("nameplateShowAll", showAll)
    end

    local function apply_nameplateMaxDistance(value)
        applyCVar("nameplateMaxDistance", value)
    end

    -- Apply all at once
    apply_showEnemyNameplates(np.showEnemyNameplates)

    if clientInfo.isRetail then
        -- Enemy minions
        if np.separateEnemyMinions then
            apply_showEnemyPets(np.showEnemyPets)
            apply_showEnemyGuardians(np.showEnemyGuardians)
            apply_showEnemyTotems(np.showEnemyTotems)
            apply_showEnemyMinus(np.showEnemyMinus)
        else
            -- Force sync all granulars to master setting
            local val = np.showEnemyMinions
            apply_showEnemyMinions(val)
            apply_showEnemyPets(val)
            apply_showEnemyGuardians(val)
            apply_showEnemyTotems(val)
            apply_showEnemyMinus(val)
        end

        -- Friendly
        apply_showFriendlyPlayers(np.showFriendlyPlayers)

        if np.separateMinions then
            apply_showFriendlyPets(np.showFriendlyPets)
            apply_showFriendlyGuardians(np.showFriendlyGuardians)
            apply_showFriendlyTotems(np.showFriendlyTotems)
        else
            -- Force sync all granulars to master setting
            local val = np.showFriendlyPlayerMinions
            apply_showFriendlyPlayerMinions(val)
            apply_showFriendlyPets(val)
            apply_showFriendlyGuardians(val)
            apply_showFriendlyTotems(val)
        end

        apply_showFriendlyNpcs(np.showFriendlyNpcs)
    elseif clientInfo.isLegion or clientInfo.isBCC or clientInfo.isEra or clientInfo.isClassic then
        -- Legion/BCC/Era/Pandaria: Granular minion types
        if np.separateEnemyMinions then
            applyCVar("nameplateShowEnemyPets", np.showEnemyPets)
            applyCVar("nameplateShowEnemyGuardians", np.showEnemyGuardians)
            applyCVar("nameplateShowEnemyTotems", np.showEnemyTotems)
            applyCVar("nameplateShowEnemyMinus", np.showEnemyMinus)
        else
            -- Force sync to master
            local val = np.showEnemyMinions
            applyCVar("nameplateShowEnemyMinions", val)
            applyCVar("nameplateShowEnemyPets", val)
            applyCVar("nameplateShowEnemyGuardians", val)
            applyCVar("nameplateShowEnemyTotems", val)
            applyCVar("nameplateShowEnemyMinus", val)
        end

        applyCVar("nameplateShowFriends", np.showFriendlyNameplates)
        applyCVar("nameplateShowFriendlyNPCs", np.showFriendlyNpcs)

        if np.separateMinions then
            applyCVar("nameplateShowFriendlyPets", np.showFriendlyPets)
            applyCVar("nameplateShowFriendlyGuardians", np.showFriendlyGuardians)
            applyCVar("nameplateShowFriendlyTotems", np.showFriendlyTotems)
        else
            -- Force sync to master
            local val = np.showFriendlyMinions
            applyCVar("nameplateShowFriendlyMinions", val)
            applyCVar("nameplateShowFriendlyPets", val)
            applyCVar("nameplateShowFriendlyGuardians", val)
            applyCVar("nameplateShowFriendlyTotems", val)
        end
    end

    apply_nameplateShowAll(np)
    apply_nameplateMaxDistance(np.nameplateMaxDistance)

    -- Store granular appliers for later GUI usage
    self.ApplySetting = self.ApplySetting or {}
    self.ApplySetting.Nameplates = {
        showEnemyNameplates = function(value)
            np.showEnemyNameplates = value
            apply_showEnemyNameplates(value)
            apply_nameplateShowAll(np)
        end,
        nameplateMaxDistance = function(value)
            np.nameplateMaxDistance = value
            apply_nameplateMaxDistance(value)
        end,
    }

    -- Retail-specific appliers
    if clientInfo.isRetail then
        -- Enemy minion appliers
        self.ApplySetting.Nameplates.showEnemyMinions = function(value)
            np.showEnemyMinions = value
            apply_showEnemyMinions(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyPets = function(value)
            np.showEnemyPets = value
            apply_showEnemyPets(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyGuardians = function(value)
            np.showEnemyGuardians = value
            apply_showEnemyGuardians(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyTotems = function(value)
            np.showEnemyTotems = value
            apply_showEnemyTotems(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyMinus = function(value)
            np.showEnemyMinus = value
            apply_showEnemyMinus(value)
            apply_nameplateShowAll(np)
        end

        -- Friendly appliers
        self.ApplySetting.Nameplates.showFriendlyPlayers = function(value)
            np.showFriendlyPlayers = value
            apply_showFriendlyPlayers(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyPlayerMinions = function(value)
            np.showFriendlyPlayerMinions = value
            apply_showFriendlyPlayerMinions(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyNpcs = function(value)
            np.showFriendlyNpcs = value
            apply_showFriendlyNpcs(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyPets = function(value)
            np.showFriendlyPets = value
            apply_showFriendlyPets(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyGuardians = function(value)
            np.showFriendlyGuardians = value
            apply_showFriendlyGuardians(value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyTotems = function(value)
            np.showFriendlyTotems = value
            apply_showFriendlyTotems(value)
            apply_nameplateShowAll(np)
        end
    elseif clientInfo.isLegion or clientInfo.isBCC or clientInfo.isEra or clientInfo.isClassic then
        -- Legion/BCC/Era/Pandaria: Granular minion types
        -- Enemy minion appliers
        self.ApplySetting.Nameplates.showEnemyMinions = function(value)
            np.showEnemyMinions = value
            applyCVar("nameplateShowEnemyMinions", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyPets = function(value)
            np.showEnemyPets = value
            applyCVar("nameplateShowEnemyPets", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyGuardians = function(value)
            np.showEnemyGuardians = value
            applyCVar("nameplateShowEnemyGuardians", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyTotems = function(value)
            np.showEnemyTotems = value
            applyCVar("nameplateShowEnemyTotems", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyMinus = function(value)
            np.showEnemyMinus = value
            applyCVar("nameplateShowEnemyMinus", value)
            apply_nameplateShowAll(np)
        end

        -- Friendly appliers
        self.ApplySetting.Nameplates.showFriendlyNameplates = function(value)
            np.showFriendlyNameplates = value
            applyCVar("nameplateShowFriends", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyNpcs = function(value)
            np.showFriendlyNpcs = value
            applyCVar("nameplateShowFriendlyNPCs", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyMinions = function(value)
            np.showFriendlyMinions = value
            applyCVar("nameplateShowFriendlyMinions", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyPets = function(value)
            np.showFriendlyPets = value
            applyCVar("nameplateShowFriendlyPets", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyGuardians = function(value)
            np.showFriendlyGuardians = value
            applyCVar("nameplateShowFriendlyGuardians", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyTotems = function(value)
            np.showFriendlyTotems = value
            applyCVar("nameplateShowFriendlyTotems", value)
            apply_nameplateShowAll(np)
        end
    end
end

-- This is replacement for bugged blizzard CVAR in 7.3.5
function mQoL_Main:Legion_ForceUpdateGridVisibility(show)
    if InCombatLockdown() then return end
    local bars = {"MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft"}
    local newVal = show and 1 or 0
    for _, barName in ipairs(bars) do
        for i = 1, 12 do
            local btn = _G[barName.."Button"..i]
            if btn then
                btn:SetAttribute("showgrid", newVal)
                if show then
                    btn:Show()
                    if btn.NormalTexture then
                        btn.NormalTexture:SetVertexColor(1.0, 1.0, 1.0, 0.5)
                    end
                else
                    if not btn:GetAttribute("statehidden") and not HasAction(btn.action) then
                        btn:Hide()
                    end
                end
            end
        end
    end
end

function mQoL_Main:ApplyActionBarVisibilitySettings(ab)
    if not ab then return end
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("ActionBarsQoL") then return end

    local function apply_autoPushSpellToActionBar(value)
        applyCVar("AutoPushSpellToActionBar", value)
    end

    local function apply_autoSelfCast(value)
        applyCVar("autoSelfCast", value)
    end

    local function apply_alwaysShowActionBars(value)
        if clientInfo.isRetail or clientInfo.isBCC then return end
        if mQoL_Database:IsDisabled(value) then return end

        -- Safety gate check
        if mQoL_DatabaseSafety and not mQoL_DatabaseSafety:IsReady() then
            return
        end

        local cvarValue = value and "1" or "0"

        if clientInfo.isLegion then
            -- Legion uses global variable ALWAYS_SHOW_MULTIBARS
            ALWAYS_SHOW_MULTIBARS = cvarValue
            SetCVar("alwaysShowActionBars", cvarValue)

            -- Manual update because MultiActionBar_UpdateGridVisibility is blocked by issecure() check
            mQoL_Main:Legion_ForceUpdateGridVisibility(value)

            if InterfaceOptions_UpdateMultiActionBars then
                 InterfaceOptions_UpdateMultiActionBars()
            end
        else
            -- Classic/Pandaria/Era use Settings API with CVar
            SetCVar("alwaysShowActionBars", cvarValue)

            -- Call Blizzard's update function to refresh the UI state
            if MultiActionBar_UpdateGridVisibility then
                MultiActionBar_UpdateGridVisibility()
            end
        end
    end

    apply_autoPushSpellToActionBar(ab.autoPushSpellToActionBar)
    apply_autoSelfCast(ab.autoSelfCast)
    apply_alwaysShowActionBars(ab.alwaysShowActionBars)

    self.ApplySetting = self.ApplySetting or {}
    self.ApplySetting.ActionBars = self.ApplySetting.ActionBars or {}
    self.ApplySetting.ActionBars.autoPushSpellToActionBar = function(value)
        ab.autoPushSpellToActionBar = value
        apply_autoPushSpellToActionBar(value)
    end
    self.ApplySetting.ActionBars.autoSelfCast = function(value)
        ab.autoSelfCast = value
        apply_autoSelfCast(value)
    end
    self.ApplySetting.ActionBars.alwaysShowActionBars = function(value)
        ab.alwaysShowActionBars = value
        apply_alwaysShowActionBars(value)
    end
end

-- Action Bars checksum helpers
local function GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    realm = realm:gsub("%s+", "")
    return name .. "-" .. realm
end

local function GenerateBarsChecksum(actionBars)
    local ab = actionBars or {}
    local checksum = ""

    local function encode(value)
        if mQoL_Database:IsDisabled(value) then
            return "-"
        end
        return value and "1" or "0"
    end

    for i = 2, 5 do
        local key = "showActionBars" .. i
        checksum = checksum .. encode(ab[key])
    end

    if clientInfo.isRetail then
        for i = 6, 8 do
            local key = "showActionBars" .. i
            checksum = checksum .. encode(ab[key])
        end
    end

    return checksum
end

local function GetBarsChecksum(characterKey)
    mQoL_DB["MainQoL"] = mQoL_DB["MainQoL"] or {}
    mQoL_DB["MainQoL"].barsChecksums = mQoL_DB["MainQoL"].barsChecksums or {}
    return mQoL_DB["MainQoL"].barsChecksums[characterKey]
end

local function SaveBarsChecksum(characterKey, checksum)
    mQoL_DB["MainQoL"] = mQoL_DB["MainQoL"] or {}
    mQoL_DB["MainQoL"].barsChecksums = mQoL_DB["MainQoL"].barsChecksums or {}
    mQoL_DB["MainQoL"].barsChecksums[characterKey] = checksum
end

local function ShowBarsReloadPopup()
    mQoL_Styles.ShowCustomPopup({
        text = "Action bar settings have changed.\n\nA UI reload is required to avoid taint and ensure buttons work correctly.\n\nThis will also apply automatically on logout or after a manual /reload.\n\nReload now?",
        acceptText = "Reload UI",
        cancelText = "Later",
        onAccept = function()
            if mQoL_Main and mQoL_Main.ApplyActionBarSettings then
                local ab = mQoL_Main.db and mQoL_Main.db.settings and mQoL_Main.db.settings.actionBars or {}
                mQoL_Main:ApplyActionBarSettings(ab)
            end
            ReloadUI()
        end,
        onCancel = function() end,
        width = 450,
        height = 220
    })
end

function mQoL_Main:ApplyActionBarSettings(ab)
    if not ab then return end
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("ActionBarsQoL") then return end

    -- Checksum verification to prevent taint
    if IsActionBarChecksumEnabled() and mQoL_DB and mQoL_DB["MainQoL"] then
        local characterKey = GetCharacterKey()
        local savedChecksum = GetBarsChecksum(characterKey)
        local currentChecksum = GenerateBarsChecksum(ab)

        -- If checksum matches, it means we don't need to touch action bars
        -- THIS IS CRITICAL TO AVOID TAINT ON RETAIL
        if savedChecksum and savedChecksum == currentChecksum then
            return
        end
    end

    local function apply_showActionBar(key, value)
        if mQoL_Database:IsDisabled(value) then return end

        local map
        if clientInfo.isLegion then
            map = {
                showActionBars2 = "SHOW_MULTI_ACTIONBAR_1",
                showActionBars3 = "SHOW_MULTI_ACTIONBAR_2",
                showActionBars4 = "SHOW_MULTI_ACTIONBAR_3",
                showActionBars5 = "SHOW_MULTI_ACTIONBAR_4",
            }
        elseif clientInfo.isClassic or clientInfo.isRetail or clientInfo.isEra or clientInfo.isBCC then
            map = {
                showActionBars2 = "PROXY_SHOW_ACTIONBAR_2",
                showActionBars3 = "PROXY_SHOW_ACTIONBAR_3",
                showActionBars4 = "PROXY_SHOW_ACTIONBAR_4",
                showActionBars5 = "PROXY_SHOW_ACTIONBAR_5",
            }
            if clientInfo.isRetail or clientInfo.isBCC then
                map.showActionBars6 = "PROXY_SHOW_ACTIONBAR_6"
                map.showActionBars7 = "PROXY_SHOW_ACTIONBAR_7"
                map.showActionBars8 = "PROXY_SHOW_ACTIONBAR_8"
            end
        end

        local settingKey = map and map[key]
        if not settingKey then return end

        if clientInfo.isLegion then
            _G[settingKey] = value == true
            C_Timer.After(0.1, InterfaceOptions_UpdateMultiActionBars)
        else
            Settings.SetValue(settingKey, value)
            MultiActionBar_Update()
        end
    end

    -- Apply all at once
    for i = 2, 8 do
        local key = "showActionBars" .. i
        if ab[key] ~= nil then
            apply_showActionBar(key, ab[key])
        end
    end

    -- Store granular appliers for later GUI usage
    self.ApplySetting = self.ApplySetting or {}
    self.ApplySetting.ActionBars = self.ApplySetting.ActionBars or {}
    for i = 2, 8 do
        local key = "showActionBars" .. i
        self.ApplySetting.ActionBars[key] = function(value)
            ab[key] = value
            apply_showActionBar(key, value)
            if IsActionBarChecksumEnabled() then
                ShowBarsReloadPopup()
            end
        end
    end

    if IsActionBarChecksumEnabled() and mQoL_DB then
        local characterKey = GetCharacterKey()
        local checksum = GenerateBarsChecksum(ab)
        SaveBarsChecksum(characterKey, checksum)
    end
end

-- If any lua error related to action bars tainting occurs, this can be enabled to show reload popup when action bar settings are changed
-- and this will use checksum to detect changes if they actually occurred so apply only when needed
-- By default enabled for Retail only as taint is confirmed there (i was unable to use extra action bar with addon enabled without tainting frames)
function IsActionBarChecksumEnabled()
    local enableRetail      = true  --frames will taint its confirmed
    local enableClassic     = false
    local enableLegion      = false
    local enablePandaria    = false
    local enableEra         = false
    local enableBCC         = false

    if clientInfo.isRetail then return enableRetail end
    if clientInfo.isClassic then return enableClassic end
    if clientInfo.isLegion then return enableLegion end
    if clientInfo.isPandaria then return enablePandaria end
    if clientInfo.isEra then return enableEra end
    if clientInfo.isBCC then return enableBCC end

    return true
end

function mQoL_Main:CreateDropdownOptions(panel, opts, yOffset)
    yOffset = yOffset or 0
    opts = opts or {}

    local key = opts.key
    local items = opts.items
    if not items then
        error("Missing items table in CreateDropdownOptions")
    end

    local s = self.db.settings.general
    local labelOffset = opts.labelOffset or 140
    local dropdownWidth = opts.dropdownWidth or 100
    local currentValue = opts.selectedValue or (key and s[key])

    local labelLines = opts.labelLines
    if not labelLines then
        if opts.label then
            labelLines = { opts.label }
        elseif key then
            labelLines = { key }
        else
            labelLines = { "Missing Label" }
        end
    end

    local labelFrames = {}
    local totalLabelHeight = 0
    local spacing = 2

    -- Create label frames and calculate total height
    for i, line in ipairs(labelLines) do
        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetText(line)
        lbl:SetJustifyH("LEFT")
        lbl:SetJustifyV("TOP")
        lbl:SetWidth(labelOffset)
        lbl:SetWordWrap(true)
        lbl:Show()

        local height = lbl:GetStringHeight()
        totalLabelHeight = totalLabelHeight + height
        if i > 1 then totalLabelHeight = totalLabelHeight + spacing end

        table.insert(labelFrames, { frame = lbl, height = height })
    end

    local dropdownHeight = 26

    local labelYOffset

    if #labelLines == 1 then
        -- For single line, center vertically with a small offset
        local singleLineHeight = labelFrames[1].height
        local singleLineYOffset = 3
        labelYOffset = yOffset - (dropdownHeight - singleLineHeight) / 4 - singleLineYOffset
    else
        -- For multiple lines, center the block of text
        labelYOffset = yOffset + (dropdownHeight - totalLabelHeight) / 2
    end

    -- Set label frames based on calculated labelYOffset
    local currentY = labelYOffset
    for i, info in ipairs(labelFrames) do
        local lbl = info.frame
        local h = info.height
        lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 170 - labelOffset, currentY)
        currentY = currentY - h - spacing
    end

    local dropdown = CreateCustomDropdown(panel, dropdownWidth, items, currentValue)
    dropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", 170, yOffset)

    panel.optionsLabels[labelLines[1]] = labelFrames[1].frame

    panel._labels = panel._labels or {}
    panel._dropdowns = panel._dropdowns or {}

    for _, info in ipairs(labelFrames) do
        table.insert(panel._labels, info.frame)
    end
    table.insert(panel._dropdowns, dropdown)

    yOffset = yOffset - (40 + (#labelLines - 1) * 12)

    return yOffset
end

-- Universal three-state dropdown creator (Show/Hide/Disable) (Disable allows to not change the setting by addon at all)
function mQoL_Main:CreateDropdownThreeState(panel, yOffset, label, key, sectionTbl, extraSpacing)
    extraSpacing = extraSpacing or 0

    local labelText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelText:SetPoint("TOPLEFT", 10, yOffset)
    labelText:SetText(label)
    panel.optionsLabels[label] = labelText

    local options = {
        { text = "Show", value = true },
        { text = "Hide", value = false },
        { text = "Disable", value = DISABLE },
    }

    local dropdownItems = {}
    for _, opt in ipairs(options) do
        table.insert(dropdownItems, {
            text = opt.text,
            value = opt.value,
            onSelect = function()
                sectionTbl[key] = opt.value
                local sectionName
                if sectionTbl == self.db.settings.nameplates then
                    sectionName = "Nameplates"
                elseif sectionTbl == self.db.settings.actionBars then
                    sectionName = "ActionBars"
                end

                if sectionName and mQoL_Main.ApplySetting and mQoL_Main.ApplySetting[sectionName] and mQoL_Main.ApplySetting[sectionName][key] then
                    mQoL_Main.ApplySetting[sectionName][key](opt.value)
                else
                    mQoL_Main:ApplySettings()
                end
            end,
        })
    end

    -- Normalize current value
    local currentValue = sectionTbl[key]
    local selectedValue
    if currentValue == true then
        selectedValue = true
    elseif currentValue == false then
        selectedValue = false
    elseif currentValue == DISABLE then
        selectedValue = DISABLE
    else
        selectedValue = DISABLE -- fallback
    end

    local dropdown = CreateCustomDropdown(panel, 100, dropdownItems, selectedValue)
    dropdown:SetPoint("TOPLEFT", 150, yOffset + 2)

    return yOffset - 30 - extraSpacing
end

function mQoL_Main:CreateGeneralPanel(parent)
    local s = self.db.settings.general

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "General Quality of Life Settings", {
        text = "How General QoL works?",
        textColor = {1, 0.82, 0},
        explanation = "Essential Quality of Life improvements for your Alts.\n\n• Settings listed here will apply to all Alts on login.\n• Some settings are available only for specific game versions.\n• Settings can be Disabled to prevent the addon from modifying them.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "MainSeparator")

    local AddGap = mQoL_Templates.AddGap

    -- Shortcut to AddOptionRow
    local function AddOptionRow(panel, label, type, opts, extra, applyFunc)
        return mQoL_Hub:AddOptionRow(panel, label, type, opts, extra, applyFunc)
    end

    -- Checkboxes
    AddOptionRow(contentContainer, "Enable LUA Errors", "checkbox", {
        value = s.showLuaErrors,
        onValueChanged = function(_, value)
            s.showLuaErrors = value
            if mQoL_Main.ApplySetting and mQoL_Main.ApplySetting.General and mQoL_Main.ApplySetting.General.showLuaErrors then
                mQoL_Main.ApplySetting.General.showLuaErrors(value)
            else
                mQoL_Main:ApplyGeneralSettings(s)
            end
        end
    })
    AddGap(contentContainer, "Standard")

    AddOptionRow(contentContainer, "Enable Autoloot", "checkbox", {
        value = s.autoLoot,
        onValueChanged = function(_, value)
            s.autoLoot = value
            mQoL_Main:ApplyGeneralSettings(s)
        end
    })
    AddGap(contentContainer, "Standard")

    local autoLootRateMin, autoLootRateMax, autoLootRateStep = 1, 100, 1
    local autoLootRateEditBox = CreateCustomInputBox(contentContainer)
    autoLootRateEditBox:SetSize(60, 24)
    autoLootRateEditBox.bg = autoLootRateEditBox:CreateTexture(nil, "BACKGROUND")
    autoLootRateEditBox.bg:SetAllPoints()
    autoLootRateEditBox.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    autoLootRateEditBox.border = mQoL_Templates.CreateFrameBorder(autoLootRateEditBox, 1, {0.25, 0.25, 0.25, 1})

    local autoLootRate = tonumber(s.autoLootRate) or 100
    autoLootRate = math.max(autoLootRateMin, math.min(autoLootRateMax, autoLootRate))
    local autoLootRateApplyFunc

    local _, autoLootRateSlider = AddOptionRow(contentContainer, "Auto Loot Rate", "slider", {
        min = autoLootRateMin,
        max = autoLootRateMax,
        step = autoLootRateStep,
        value = autoLootRate,
        onValueChanged = function(_, value)
            autoLootRateEditBox:SetText(tostring(math.floor((value or autoLootRateMin) + 0.5)))
        end,
        applyLabel = "Apply Rate",
        applyWidth = 120
    }, {autoLootRateEditBox}, function()
        autoLootRateApplyFunc()
    end)

    autoLootRateEditBox:SetText(tostring(autoLootRate))
    autoLootRateEditBox.slider = autoLootRateSlider

    autoLootRateApplyFunc = mQoL_Hub:SetupNumberInputBox(autoLootRateEditBox, autoLootRateSlider, autoLootRateMin, autoLootRateMax, autoLootRateStep, function(val)
        s.autoLootRate = val
        if mQoL_Main.ApplySetting and mQoL_Main.ApplySetting.General and mQoL_Main.ApplySetting.General.autoLootRate then
            mQoL_Main.ApplySetting.General.autoLootRate(val)
        else
            mQoL_Main:ApplyGeneralSettings(s)
        end
    end, function(val)
        return tostring(math.floor((val or autoLootRateMin) + 0.5))
    end)

    AddOptionRow(contentContainer, "Enable Auto Quest Tracking", "checkbox", {
        value = s.autoQuestTracking,
        onValueChanged = function(_, value)
            s.autoQuestTracking = value
            mQoL_Main:ApplyGeneralSettings(s)
            end
    })
    AddGap(contentContainer, "BottomSeparator")

    -- Dropdown Items for My Name
    local dropdownItems = {
        { text = "Show", value = true, onSelect = function() s.showMyName = true; mQoL_Main:ApplyGeneralSettings(s) end },
        { text = "Hide", value = false, onSelect = function() s.showMyName = false; mQoL_Main:ApplyGeneralSettings(s) end },
        { text = "Disable", value = DISABLE, onSelect = function() s.showMyName = DISABLE; mQoL_Main:ApplyGeneralSettings(s) end },
    }

    AddOptionRow(contentContainer, "My Name", "dropdown", {
        list = dropdownItems,
        value = mQoL_Hub.NormalizeTriState(s.showMyName)
    })
    AddGap(contentContainer, "Standard")

    -- Show Head / Show Cloak (Classic/Era/Pandaria/BCC only)
    if clientInfo.isClassic or clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC then
        -- Show Head
        AddOptionRow(contentContainer, "Show Head", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showHead = true; mQoL_Main:ApplyGeneralSettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showHead = false; mQoL_Main:ApplyGeneralSettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showHead = DISABLE; mQoL_Main:ApplyGeneralSettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showHead)
        })
        AddGap(contentContainer, "Standard")

        -- Show Cloak
        AddOptionRow(contentContainer, "Show Cloak", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showCloak = true; mQoL_Main:ApplyGeneralSettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showCloak = false; mQoL_Main:ApplyGeneralSettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showCloak = DISABLE; mQoL_Main:ApplyGeneralSettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showCloak)
        })
        AddGap(contentContainer, "Standard")
    end

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

function mQoL_Main:CreateNameplatesPanel(parent)
    local s = self.db.settings.nameplates

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Nameplates Quality of Life Settings", {
        text = "How Nameplates QoL works?",
        textColor = {1, 0.82, 0},
        explanation = "Customize the visibility and behavior of nameplates.\n\n• Customize visibility of nameplates for different unit types for both enemy and friendly nameplates.\n• Customize nameplates view distance within the range supported by the client.\n• Settings can be Disabled to prevent the addon from modifying them.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "MainSeparator")

    local AddGap = mQoL_Templates.AddGap

    -- Shortcut to AddOptionRow
    local function AddOptionRow(label, type, opts)
        return mQoL_Hub:AddOptionRow(contentContainer, label, type, opts)
    end

    -- Nameplate dropdowns
    AddOptionRow("Enemy Nameplates", "dropdown", {
        list = {
            { text = "Show", value = true, onSelect = function() s.showEnemyNameplates = true; mQoL_Main:ApplyNameplateSettings(s) end },
            { text = "Hide", value = false, onSelect = function() s.showEnemyNameplates = false; mQoL_Main:ApplyNameplateSettings(s) end },
            { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyNameplates = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
        },
        value = mQoL_Hub.NormalizeTriState(s.showEnemyNameplates)
    })
    AddGap(contentContainer, "Standard")

    -- Friendly Nameplates (version-specific)
    if clientInfo.isRetail then
        -- ENEMY SECTION
        AddOptionRow("Enemy Minions Nameplates", "dropdown", {
            list = {
                { text = "Show All", value = true, onSelect = function() 
                    s.showEnemyMinions = true
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = true
                    s.showEnemyGuardians = true
                    s.showEnemyTotems = true
                    s.showEnemyMinus = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showEnemyMinions = false
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = false
                    s.showEnemyGuardians = false
                    s.showEnemyTotems = false
                    s.showEnemyMinus = false
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showEnemyMinions = DISABLE
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = DISABLE
                    s.showEnemyGuardians = DISABLE
                    s.showEnemyTotems = DISABLE
                    s.showEnemyMinus = DISABLE
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateEnemyMinions = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateEnemyMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showEnemyMinions)
        })
        AddGap(contentContainer, "Standard")
        
        -- Enemy sub-controls when separateEnemyMinions is enabled
        if s.separateEnemyMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyPets = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyPets = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyPets = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyGuardians = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyGuardians = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyGuardians = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyTotems = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyTotems = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyTotems = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyTotems)
            })
            AddGap(contentContainer, "Standard")

            contentContainer.nextIsSeparator = true
            AddOptionRow("      Minor Enemies", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyMinus = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyMinus = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyMinus = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyMinus)
            })
            AddGap(contentContainer, "Standard")
        else
            AddGap(contentContainer, "Standard")
        end
        
        --Seperator
        AddGap(contentContainer, "BottomSeparator")

        -- FRIENDLY SECTION
        AddOptionRow("Friendly Players Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyPlayers = true; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyPlayers = false; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyPlayers = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showFriendlyPlayers)
        })
        AddGap(contentContainer, "Standard")

        -- Friendly Minions with optional separate controls
        AddOptionRow("Friendly Minions Nameplates", "dropdown", {
            list = {
                { text = "Show All", value = true, onSelect = function() 
                    s.showFriendlyPlayerMinions = true
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = true
                    s.showFriendlyGuardians = true
                    s.showFriendlyTotems = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showFriendlyPlayerMinions = false
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = false
                    s.showFriendlyGuardians = false
                    s.showFriendlyTotems = false
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showFriendlyPlayerMinions = DISABLE
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = DISABLE
                    s.showFriendlyGuardians = DISABLE
                    s.showFriendlyTotems = DISABLE
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateMinions = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showFriendlyPlayerMinions)
        })
        AddGap(contentContainer, "Standard")
        
        -- Friendly sub-controls when separateMinions is enabled
        if s.separateMinions then
            AddOptionRow("      Pets", "dropdown", { -- Hit space 6 times like THE BOY
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyPets = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyPets = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyPets = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyGuardians = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyGuardians = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyGuardians = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyTotems = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyTotems = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyTotems = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyTotems)
            })
            AddGap(contentContainer, "Standard")
        end

        contentContainer.nextIsSeparator = true
        AddOptionRow("Friendly NPCs Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyNpcs = true; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNpcs = false; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNpcs = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showFriendlyNpcs)
        })
        AddGap(contentContainer, "Standard")

        --SEPARATOR
        AddGap(contentContainer, "BottomSeparator")
    elseif clientInfo.isLegion then
        -- Legion: Granular minion types like Retail but with different CVars
        -- Enemy Minions
        AddOptionRow("Enemy Minions Nameplates", "dropdown", {
            list = {
                { text = "Show All", value = true, onSelect = function() 
                    s.showEnemyMinions = true
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = true
                    s.showEnemyGuardians = true
                    s.showEnemyTotems = true
                    s.showEnemyMinus = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showEnemyMinions = false
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = false
                    s.showEnemyGuardians = false
                    s.showEnemyTotems = false
                    s.showEnemyMinus = false
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showEnemyMinions = DISABLE
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = DISABLE
                    s.showEnemyGuardians = DISABLE
                    s.showEnemyTotems = DISABLE
                    s.showEnemyMinus = DISABLE
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateEnemyMinions = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateEnemyMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showEnemyMinions)
        })
        AddGap(contentContainer, "Standard")

        if s.separateEnemyMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyPets = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyPets = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyPets = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyGuardians = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyGuardians = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyGuardians = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyTotems = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyTotems = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyTotems = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyTotems)
            })
            AddGap(contentContainer, "Standard")

            contentContainer.nextIsSeparator = true
            AddOptionRow("      Minor Enemies", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyMinus = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyMinus = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyMinus = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyMinus)
            })
            AddGap(contentContainer, "Standard")
        else
            AddGap(contentContainer, "Standard")
        end

        -- Separator
        AddGap(contentContainer, "BottomSeparator")

        -- Friendly Nameplates
        AddOptionRow("Friendly Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyNameplates = true; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNameplates = false; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNameplates = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showFriendlyNameplates)
        })
        AddGap(contentContainer, "Standard")

        -- Friendly Minions
        AddOptionRow("Friendly Minions Nameplates", "dropdown", {
            list = {
                { text = "Show All", value = true, onSelect = function() 
                    s.showFriendlyMinions = true
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = true
                    s.showFriendlyGuardians = true
                    s.showFriendlyTotems = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showFriendlyMinions = false
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = false
                    s.showFriendlyGuardians = false
                    s.showFriendlyTotems = false
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showFriendlyMinions = DISABLE
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = DISABLE
                    s.showFriendlyGuardians = DISABLE
                    s.showFriendlyTotems = DISABLE
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateMinions = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showFriendlyMinions)
        })
        AddGap(contentContainer, "Standard")

        if s.separateMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyPets = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyPets = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyPets = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyGuardians = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyGuardians = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyGuardians = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyTotems = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyTotems = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyTotems = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyTotems)
            })
            AddGap(contentContainer, "Standard")
        end

        -- Separator
        AddGap(contentContainer, "BottomSeparator")

    elseif clientInfo.isBCC or clientInfo.isEra or clientInfo.isClassic or clientInfo.isLegion then
        -- BCC/Era/Pandaria/Legion: Granular Enemy/Friendly Minions
        AddOptionRow("Enemy Minions", "dropdown", {
            list = {
                { text = "Show All", value = true, onSelect = function() 
                    s.showEnemyMinions = true
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = true
                    s.showEnemyGuardians = true
                    s.showEnemyTotems = true
                    s.showEnemyMinus = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showEnemyMinions = false
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = false
                    s.showEnemyGuardians = false
                    s.showEnemyTotems = false
                    s.showEnemyMinus = false
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showEnemyMinions = DISABLE
                    s.separateEnemyMinions = false
                    -- Sync separate settings
                    s.showEnemyPets = DISABLE
                    s.showEnemyGuardians = DISABLE
                    s.showEnemyTotems = DISABLE
                    s.showEnemyMinus = DISABLE
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateEnemyMinions = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateEnemyMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showEnemyMinions)
        })
        AddGap(contentContainer, "Standard")

        if s.separateEnemyMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyPets = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyPets = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyPets = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyGuardians = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyGuardians = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyGuardians = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyTotems = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyTotems = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyTotems = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyTotems)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Minor Enemies", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyMinus = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyMinus = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyMinus = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyMinus)
            })
            AddGap(contentContainer, "Standard")
        end

        AddGap(contentContainer, "BottomSeparator")

        AddOptionRow("Friendly Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyNameplates = true; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNameplates = false; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNameplates = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showFriendlyNameplates)
        })
        AddGap(contentContainer, "Standard")

        AddOptionRow("Friendly NPCs Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyNpcs = true; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNpcs = false; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNpcs = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showFriendlyNpcs)
        })
        AddGap(contentContainer, "Standard")

        -- Sub-options for Friendly Minions
        AddOptionRow("Friendly Minions", "dropdown", {
            list = {
                { text = "Show All", value = true, onSelect = function() 
                    s.showFriendlyMinions = true
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = true
                    s.showFriendlyGuardians = true
                    s.showFriendlyTotems = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showFriendlyMinions = false
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = false
                    s.showFriendlyGuardians = false
                    s.showFriendlyTotems = false
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showFriendlyMinions = DISABLE
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = DISABLE
                    s.showFriendlyGuardians = DISABLE
                    s.showFriendlyTotems = DISABLE
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateMinions = true
                    mQoL_Main:ApplyNameplateSettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showFriendlyMinions)
        })
        AddGap(contentContainer, "Standard")

        if s.separateMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyPets = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyPets = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyPets = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyGuardians = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyGuardians = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyGuardians = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyTotems = true; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyTotems = false; mQoL_Main:ApplyNameplateSettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyTotems = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyTotems)
            })
            AddGap(contentContainer, "Standard")
        end

        AddGap(contentContainer, "BottomSeparator")

    else
        -- Classic/other: single Friendly option only
        AddOptionRow("Friendly Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyNameplates = true; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNameplates = false; mQoL_Main:ApplyNameplateSettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNameplates = DISABLE; mQoL_Main:ApplyNameplateSettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showFriendlyNameplates)
        })
        AddGap(contentContainer, "Standard")
    end

    -- Max Nameplate Distance
    local distances = {20, 40, 60}
    if clientInfo.isClassic then distances = {21, 41} end
    if clientInfo.isBCC then distances = {21, 41} end
    if clientInfo.isEra then distances = {10, 20} end
    if clientInfo.isLegion then distances = {20, 40, 60, 80, 100} end

    local distanceItems = {}
    for _, val in ipairs(distances) do
        table.insert(distanceItems, {
            text = tostring(val),
            value = val,
            onSelect = function() 
                s.nameplateMaxDistance = val
                mQoL_Main:ApplyNameplateSettings(s)
            end,
        })
    end

    AddOptionRow("Max Nameplate Distance", "dropdown", {
        list = distanceItems,
        value = s.nameplateMaxDistance or distances[1]
    })
    AddGap(contentContainer, "Standard")

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

function mQoL_Main:CreateActionBarsPanel(parent)
    local s = self.db.settings.actionBars

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Action Bars Quality of Life Settings", {
        text = "How Action Bars QoL works?",
        textColor = {1, 0.82, 0},
        explanation = "Manage Action Bar visibility.\n\n• Always Show Action Bars is only available in non-Retail or BCC clients.\n• To control Action Bars visibility on Retail or BCC, use Edit Mode Profile.\n• On Retail, changing these settings will require you to reload UI to prevent action bars tainting.\n• Settings can be Disabled to prevent the addon from modifying them.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "MainSeparator")

    local AddGap = mQoL_Templates.AddGap

    -- Shotcut to add option rows
    local function AddOptionRow(label, type, opts)
        return mQoL_Hub:AddOptionRow(contentContainer, label, type, opts)
    end

    if not clientInfo.isRetail then
        local val = s.alwaysShowActionBars
        if val == nil then val = DISABLE end

        AddOptionRow("Always Show Action Bars", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.alwaysShowActionBars = true; mQoL_Main:ApplyActionBarVisibilitySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.alwaysShowActionBars = false; mQoL_Main:ApplyActionBarVisibilitySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.alwaysShowActionBars = DISABLE; mQoL_Main:ApplyActionBarVisibilitySettings(s) end },
            },
            value = val
        })
        AddGap(contentContainer, "Standard")
    end

    AddOptionRow("Auto Push Spell To Action Bar", "checkbox", {
        value = s.autoPushSpellToActionBar,
        onValueChanged = function(_, value)
            s.autoPushSpellToActionBar = value
            if mQoL_Main.ApplySetting and mQoL_Main.ApplySetting.ActionBars and mQoL_Main.ApplySetting.ActionBars.autoPushSpellToActionBar then
                mQoL_Main.ApplySetting.ActionBars.autoPushSpellToActionBar(value)
            else
                mQoL_Main:ApplyActionBarVisibilitySettings(s)
            end
        end
    })
    AddGap(contentContainer, "Standard")

    AddOptionRow("Auto Self Cast", "checkbox", {
        value = s.autoSelfCast,
        onValueChanged = function(_, value)
            s.autoSelfCast = value
            if mQoL_Main.ApplySetting and mQoL_Main.ApplySetting.ActionBars and mQoL_Main.ApplySetting.ActionBars.autoSelfCast then
                mQoL_Main.ApplySetting.ActionBars.autoSelfCast(value)
            else
                mQoL_Main:ApplyActionBarVisibilitySettings(s)
            end
        end
    })
    AddGap(contentContainer, "Standard")
    AddGap(contentContainer, "BottomSeparator")

    -- Action Bars Dropdowns
    local function AddActionBarDropdown(label, key)
        local function onSelect(val)
            s[key] = val
            if mQoL_Main.ApplySetting and mQoL_Main.ApplySetting.ActionBars and mQoL_Main.ApplySetting.ActionBars[key] then
                mQoL_Main.ApplySetting.ActionBars[key](val)
            else
                mQoL_Main:ApplyActionBarSettings(s)
                if IsActionBarChecksumEnabled() then
                    ShowBarsReloadPopup()
                end
            end
        end

        AddOptionRow(label, "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() onSelect(true) end },
                { text = "Hide", value = false, onSelect = function() onSelect(false) end },
                { text = "Disable", value = DISABLE, onSelect = function() onSelect(DISABLE) end },
            },
            value = mQoL_Hub.NormalizeTriState(s[key])
        })
        AddGap(contentContainer, "Standard")
    end

    AddActionBarDropdown("Action Bar 2", "showActionBars2")
    AddActionBarDropdown("Action Bar 3", "showActionBars3")
    AddActionBarDropdown("Action Bar 4", "showActionBars4")
    AddActionBarDropdown("Action Bar 5", "showActionBars5")

    if clientInfo.isRetail or clientInfo.isBCC then
        AddActionBarDropdown("Action Bar 6", "showActionBars6")
        AddActionBarDropdown("Action Bar 7", "showActionBars7")
        AddActionBarDropdown("Action Bar 8", "showActionBars8")
    end

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

-- Event handler
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if mQoL_Main.InitializeDB then
            mQoL_Main:InitializeDB()
        end

        if IsLoggedIn() then
            C_Timer.After(0, function() mQoL_Main:ApplySettings() end)
        end

    elseif event == "PLAYER_LOGIN" then
        if not mQoL_Main.db and mQoL_Main.InitializeDB then
            mQoL_Main:InitializeDB()
        end

        C_Timer.After(0, function()
            mQoL_Main:ApplySettings()
        end)

        if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
            if mQoL_Modules:ShouldLoadModule("GeneralQoL") then
                mQoL_Hub:RegisterModuleOptions("mQoL_Main_GeneralQoL", "General QoL", function(parent) return mQoL_Main:CreateGeneralPanel(parent) end)
            end
            if mQoL_Modules:ShouldLoadModule("NameplatesQoL") then
                mQoL_Hub:RegisterModuleOptions("mQoL_Main_Nameplates", "Nameplates", function(parent) return mQoL_Main:CreateNameplatesPanel(parent) end)
            end
            if mQoL_Modules:ShouldLoadModule("ActionBarsQoL") then
                mQoL_Hub:RegisterModuleOptions("mQoL_Main_ActionBars", "Action Bars", function(parent) return mQoL_Main:CreateActionBarsPanel(parent) end)
            end
        end
    end
end)
