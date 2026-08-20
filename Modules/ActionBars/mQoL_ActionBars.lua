local addonName = ...

mQoL_ActionBars = mQoL_ActionBars or mQoL_ActionBarsQoL or {}
mQoL_ActionBarsQoL = mQoL_ActionBars -- Legacy API alias

local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local DISABLE = mQoL_Database.DISABLE
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then return end

local function SyncMainFacade()
    if mQoL_Main and type(mQoL_Main.SyncCompatibilityState) == "function" then
        mQoL_Main:SyncCompatibilityState()
    end
end

local function CopySettings(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

function mQoL_ActionBarsQoL:InitializeDB()
    mQoL_DB = mQoL_DB or {}
    mQoL_DB.ActionBarsQoL = mQoL_DB.ActionBarsQoL or {}

    local db = mQoL_DB.ActionBarsQoL
    if type(db.settings) ~= "table" then
        local legacySettings = mQoL_DB.MainQoL
            and mQoL_DB.MainQoL.settings
            and mQoL_DB.MainQoL.settings.actionBars
        db.settings = CopySettings(legacySettings)
    end
    if type(db.barsChecksums) ~= "table" then
        local legacyChecksums = mQoL_DB.MainQoL and mQoL_DB.MainQoL.barsChecksums
        db.barsChecksums = CopySettings(legacyChecksums)
    end

    self.db = db
end

function mQoL_ActionBarsQoL:CaptureCurrentSettings()
    if not self.db or type(self.db.settings) ~= "table" then return end
    local settings = self.db.settings

    local function SetMissing(key, value)
        if settings[key] == nil and value ~= nil then
            settings[key] = value
        end
    end

    SetMissing("alwaysShowActionBars", mQoL_CVar:ReadBoolean("alwaysShowActionBars"))
    if not clientInfo.isLegion then
        SetMissing("autoPushSpellToActionBar", mQoL_CVar:ReadBoolean("AutoPushSpellToActionBar"))
    end
    SetMissing("autoSelfCast", mQoL_CVar:ReadBoolean("autoSelfCast"))

    local lastBar = (clientInfo.isRetail or clientInfo.isBCC) and 8 or 5
    for bar = 2, lastBar do
        local value
        if clientInfo.isLegion then
            local legacyValue = _G["SHOW_MULTI_ACTIONBAR_" .. (bar - 1)]
            if legacyValue ~= nil then
                value = legacyValue == true or legacyValue == 1 or legacyValue == "1"
            end
        else
            value = mQoL_CVar:ReadSettingBoolean("PROXY_SHOW_ACTIONBAR_" .. bar)
        end
        SetMissing("showActionBars" .. bar, value)
    end
end

function mQoL_ActionBarsQoL:Legion_ForceUpdateGridVisibility(show)
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

function mQoL_ActionBarsQoL:ApplyVisibilitySettings(ab)
    if not ab then return end
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("ActionBarsQoL") then return end

    local function apply_autoPushSpellToActionBar(value)
        if clientInfo.isLegion then return end
        mQoL_CVar:Apply("AutoPushSpellToActionBar", value)
    end

    local function apply_autoSelfCast(value)
        mQoL_CVar:Apply("autoSelfCast", value)
    end

    local function apply_alwaysShowActionBars(value)
        if clientInfo.isRetail or clientInfo.isBCC then return end
        if mQoL_Database:IsDisabled(value) then return end

        local cvarValue = value and "1" or "0"

        if clientInfo.isLegion then
            -- Legion uses global variable ALWAYS_SHOW_MULTIBARS
            ALWAYS_SHOW_MULTIBARS = cvarValue
            SetCVar("alwaysShowActionBars", cvarValue)

            -- Manual update because MultiActionBar_UpdateGridVisibility is blocked by issecure() check
            mQoL_ActionBarsQoL:Legion_ForceUpdateGridVisibility(value)

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
    SyncMainFacade()
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
    mQoL_DB["ActionBarsQoL"] = mQoL_DB["ActionBarsQoL"] or {}
    mQoL_DB["ActionBarsQoL"].barsChecksums = mQoL_DB["ActionBarsQoL"].barsChecksums or {}
    return mQoL_DB["ActionBarsQoL"].barsChecksums[characterKey]
end

local function SaveBarsChecksum(characterKey, checksum)
    mQoL_DB["ActionBarsQoL"] = mQoL_DB["ActionBarsQoL"] or {}
    mQoL_DB["ActionBarsQoL"].barsChecksums = mQoL_DB["ActionBarsQoL"].barsChecksums or {}
    mQoL_DB["ActionBarsQoL"].barsChecksums[characterKey] = checksum
end

local function ShowBarsReloadPopup()
    mQoL_Styles.ShowCustomPopup({
        text = "Action bar settings have changed.\n\nA UI reload is required to avoid taint and ensure buttons work correctly.\n\nThis will also apply automatically on logout or after a manual /reload.\n\nReload now?",
        acceptText = "Reload UI",
        cancelText = "Later",
        onAccept = function()
            if mQoL_ActionBarsQoL and mQoL_ActionBarsQoL.ApplySettings then
                local ab = mQoL_ActionBarsQoL.db and mQoL_ActionBarsQoL.db.settings or {}
                mQoL_ActionBarsQoL:ApplySettings(ab)
            end
            ReloadUI()
        end,
        onCancel = function() end,
        width = 450,
        height = 220
    })
end

function mQoL_ActionBarsQoL:ApplySettings(ab)
    if not ab then return end
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("ActionBarsQoL") then return end

    -- Checksum verification to prevent taint
    if mQoL_ActionBarsQoL:IsActionBarChecksumEnabled() and mQoL_DB and mQoL_DB["ActionBarsQoL"] then
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
            if mQoL_ActionBarsQoL:IsActionBarChecksumEnabled() then
                ShowBarsReloadPopup()
            end
        end
    end

    if mQoL_ActionBarsQoL:IsActionBarChecksumEnabled() and mQoL_DB then
        local characterKey = GetCharacterKey()
        local checksum = GenerateBarsChecksum(ab)
        SaveBarsChecksum(characterKey, checksum)
    end
    SyncMainFacade()
end

-- If any lua error related to action bars tainting occurs, this can be enabled to show reload popup when action bar settings are changed
-- and this will use checksum to detect changes if they actually occurred so apply only when needed
-- By default enabled for Retail only as taint is confirmed there (i was unable to use extra action bar with addon enabled without tainting frames)
function mQoL_ActionBarsQoL:IsActionBarChecksumEnabled()
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

function mQoL_ActionBarsQoL:CreatePanel(parent)
    local s = self.db.settings

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Action Bars Quality of Life Settings", {
        text = "How Action Bars QoL works?",
        textColor = {1, 0.82, 0},
        explanation = "Manage Action Bar visibility.\n\n- Always Show Action Bars is only available in non-Retail or BCC clients.\n- To control Action Bars visibility on Retail or BCC, use Edit Mode Profile.\n- On Retail, changing these settings will require you to reload UI to prevent action bars tainting.\n- Settings can be Disabled to prevent the addon from modifying them.",
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
                { text = "Show", value = true, onSelect = function() s.alwaysShowActionBars = true; mQoL_ActionBarsQoL:ApplyVisibilitySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.alwaysShowActionBars = false; mQoL_ActionBarsQoL:ApplyVisibilitySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.alwaysShowActionBars = DISABLE; mQoL_ActionBarsQoL:ApplyVisibilitySettings(s) end },
            },
            value = val
        })
        AddGap(contentContainer, "Standard")
    end

    if not clientInfo.isLegion then
        AddOptionRow("Auto Push Spell To Action Bar", "checkbox", {
            value = s.autoPushSpellToActionBar,
            onValueChanged = function(_, value)
                s.autoPushSpellToActionBar = value
                if mQoL_ActionBarsQoL.ApplySetting and mQoL_ActionBarsQoL.ApplySetting.ActionBars and mQoL_ActionBarsQoL.ApplySetting.ActionBars.autoPushSpellToActionBar then
                    mQoL_ActionBarsQoL.ApplySetting.ActionBars.autoPushSpellToActionBar(value)
                else
                    mQoL_ActionBarsQoL:ApplyVisibilitySettings(s)
                end
            end
        })
        AddGap(contentContainer, "Standard")
    end

    AddOptionRow("Auto Self Cast", "checkbox", {
        value = s.autoSelfCast,
        onValueChanged = function(_, value)
            s.autoSelfCast = value
            if mQoL_ActionBarsQoL.ApplySetting and mQoL_ActionBarsQoL.ApplySetting.ActionBars and mQoL_ActionBarsQoL.ApplySetting.ActionBars.autoSelfCast then
                mQoL_ActionBarsQoL.ApplySetting.ActionBars.autoSelfCast(value)
            else
                mQoL_ActionBarsQoL:ApplyVisibilitySettings(s)
            end
        end
    })
    AddGap(contentContainer, "Standard")
    AddGap(contentContainer, "BottomSeparator")

    -- Action Bars Dropdowns
    local function AddActionBarDropdown(label, key)
        local function onSelect(val)
            s[key] = val
            if mQoL_ActionBarsQoL.ApplySetting and mQoL_ActionBarsQoL.ApplySetting.ActionBars and mQoL_ActionBarsQoL.ApplySetting.ActionBars[key] then
                mQoL_ActionBarsQoL.ApplySetting.ActionBars[key](val)
            else
                mQoL_ActionBarsQoL:ApplySettings(s)
                if mQoL_ActionBarsQoL:IsActionBarChecksumEnabled() then
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

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == addonName then
        mQoL_ActionBarsQoL:InitializeDB()
        if mQoL_Modules:ShouldLoadModule("ActionBarsQoL") then
            mQoL_ActionBarsQoL:CaptureCurrentSettings()
        end

        if IsLoggedIn() then
            C_Timer.After(0, function()
                local settings = mQoL_ActionBarsQoL.db.settings
                mQoL_ActionBarsQoL:ApplyVisibilitySettings(settings)
                mQoL_ActionBarsQoL:ApplySettings(settings)
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        if not mQoL_ActionBarsQoL.db then
            mQoL_ActionBarsQoL:InitializeDB()
        end
        if mQoL_Modules:ShouldLoadModule("ActionBarsQoL") then
            mQoL_ActionBarsQoL:CaptureCurrentSettings()
        end

        C_Timer.After(0, function()
            local settings = mQoL_ActionBarsQoL.db.settings
            mQoL_ActionBarsQoL:ApplyVisibilitySettings(settings)
            mQoL_ActionBarsQoL:ApplySettings(settings)
        end)

        if mQoL_Hub and mQoL_Hub.RegisterModuleOptions
            and mQoL_Modules:ShouldLoadModule("ActionBarsQoL") then
            mQoL_Hub:RegisterModuleOptions("mQoL_ActionBarsQoL", "Action Bars", function(parent)
                return mQoL_ActionBarsQoL:CreatePanel(parent)
            end)
        end
    end
end)
