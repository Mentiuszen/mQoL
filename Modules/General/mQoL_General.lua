local addonName = ...

mQoL_General = mQoL_General or mQoL_GeneralQoL or {}
mQoL_GeneralQoL = mQoL_General -- Legacy API alias

local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local DISABLE = mQoL_Database.DISABLE
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then return end
local CreateCustomInputBox = mQoL_Styles.CreateCustomInputBox

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

function mQoL_GeneralQoL:InitializeDB()
    mQoL_DB = mQoL_DB or {}
    mQoL_DB.GeneralQoL = mQoL_DB.GeneralQoL or {}

    local db = mQoL_DB.GeneralQoL
    if type(db.settings) ~= "table" then
        local legacySettings = mQoL_DB.MainQoL
            and mQoL_DB.MainQoL.settings
            and mQoL_DB.MainQoL.settings.general
        db.settings = CopySettings(legacySettings)
    end

    self.db = db
end

function mQoL_GeneralQoL:CaptureCurrentSettings()
    if not self.db or type(self.db.settings) ~= "table" then return end
    local settings = self.db.settings

    local function SetMissing(key, value)
        if settings[key] == nil and value ~= nil then
            settings[key] = value
        end
    end

    SetMissing("showMyName", mQoL_CVar:ReadBoolean("UnitNameOwn"))
    SetMissing("autoLoot", mQoL_CVar:ReadBoolean("autoLootDefault"))
    SetMissing("autoQuestTracking", mQoL_CVar:ReadBoolean("autoQuestWatch"))
    SetMissing("showLuaErrors", mQoL_CVar:ReadBoolean("scriptErrors"))
    SetMissing("fastAutoLoot", false)
    SetMissing("fastAutoLootSpeed", 0.02)

    if clientInfo.isClassic then
        SetMissing("autoConsolidatedBuffs", mQoL_CVar:ReadBoolean("consolidateBuffs"))
    end

    if clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC then
        local helmValue = mQoL_CVar:ReadBoolean("showHelm")
        local cloakValue = mQoL_CVar:ReadBoolean("showCloak")
        if type(ShowingHelm) == "function" then
            local success, value = pcall(ShowingHelm)
            if success then helmValue = value end
        end
        if type(ShowingCloak) == "function" then
            local success, value = pcall(ShowingCloak)
            if success then cloakValue = value end
        end
        SetMissing("showHead", helmValue)
        SetMissing("showCloak", cloakValue)
    end
end

function mQoL_GeneralQoL:ApplySettings(g)
    if not g then return end
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("GeneralQoL") then return end

    local function apply_showLuaErrors(value)
        mQoL_CVar:Apply("scriptErrors", value)
    end

    local function apply_autoLoot(value)
        mQoL_CVar:Apply("autoLootDefault", value)
    end

    local function apply_fastAutoLoot(value)
        if mQoL_FastAutoloot and type(mQoL_FastAutoloot.SetEnabled) == "function" then
            mQoL_FastAutoloot:SetEnabled(value == true)
        end
    end

    local function apply_autoQuestTracking(value)
        mQoL_CVar:Apply("autoQuestWatch", value)
    end

    local function apply_showMyName(value)
        mQoL_CVar:Apply("UnitNameOwn", value)
    end

    local function apply_showHead(value)
        if not mQoL_Database:IsDisabled(value) and type(ShowHelm) == "function" and (clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC) then
            ShowHelm(value == true)
        end
    end

    local function apply_showCloak(value)
        if not mQoL_Database:IsDisabled(value) and type(ShowCloak) == "function" and (clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC) then
            ShowCloak(value == true)
        end
    end

    local function apply_autoConsolidatedBuffs(value)
        if clientInfo.isClassic then
            mQoL_CVar:Apply("consolidateBuffs", value)
        end
    end

    -- Apply all at once
    apply_showLuaErrors(g.showLuaErrors)
    apply_autoLoot(g.autoLoot)
    apply_fastAutoLoot(g.fastAutoLoot)
    apply_autoQuestTracking(g.autoQuestTracking)
    apply_showMyName(g.showMyName)
    apply_showHead(g.showHead)
    apply_showCloak(g.showCloak)
    apply_autoConsolidatedBuffs(g.autoConsolidatedBuffs)

    -- Export to object for later GUI usage
    self.ApplySetting = self.ApplySetting or {}
    self.ApplySetting.General = {
        showLuaErrors = apply_showLuaErrors,
        autoLoot = apply_autoLoot,
        fastAutoLoot = apply_fastAutoLoot,
        autoQuestTracking = apply_autoQuestTracking,
        showMyName = apply_showMyName,
        showHead = apply_showHead,
        showCloak = apply_showCloak,
        autoConsolidatedBuffs = apply_autoConsolidatedBuffs,
    }
    SyncMainFacade()
end

function mQoL_GeneralQoL:CreatePanel(parent)
    local s = self.db.settings

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "General Quality of Life Settings", {
        text = "How General QoL works?",
        textColor = {1, 0.82, 0},
        explanation = "Essential Quality of Life improvements for your Alts.\n\n- Settings listed here will apply to all Alts on login.\n- Some settings are available only for specific game versions.\n- Settings can be Disabled to prevent the addon from modifying them.",
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
            if mQoL_GeneralQoL.ApplySetting and mQoL_GeneralQoL.ApplySetting.General and mQoL_GeneralQoL.ApplySetting.General.showLuaErrors then
                mQoL_GeneralQoL.ApplySetting.General.showLuaErrors(value)
            else
                mQoL_GeneralQoL:ApplySettings(s)
            end
        end
    })
    AddGap(contentContainer, "Standard")

    AddOptionRow(contentContainer, "Enable Auto Quest Tracking", "checkbox", {
        value = s.autoQuestTracking,
        onValueChanged = function(_, value)
            s.autoQuestTracking = value
            mQoL_GeneralQoL:ApplySettings(s)
            end
    })
    AddGap(contentContainer, "Standard")

    AddOptionRow(contentContainer, "Enable Autoloot", "checkbox", {
        value = s.autoLoot,
        onValueChanged = function(_, value)
            s.autoLoot = value
            mQoL_GeneralQoL:ApplySettings(s)
        end
    })
    AddGap(contentContainer, "Standard")

    AddOptionRow(contentContainer, "Fast Auto Loot", "checkbox", {
        value = s.fastAutoLoot ~= false,
        onValueChanged = function(_, value)
            s.fastAutoLoot = value
            if mQoL_GeneralQoL.ApplySetting and mQoL_GeneralQoL.ApplySetting.General and mQoL_GeneralQoL.ApplySetting.General.fastAutoLoot then
                mQoL_GeneralQoL.ApplySetting.General.fastAutoLoot(value)
            elseif mQoL_FastAutoloot and type(mQoL_FastAutoloot.SetEnabled) == "function" then
                mQoL_FastAutoloot:SetEnabled(value)
            end
        end
    })

    AddGap(contentContainer, "Standard")

    -- Auto Enable Consolidated Buffs (Classic only)
    if clientInfo.isClassic then
        AddOptionRow(contentContainer, "Enable Consolidated Buffs", "checkbox", {
            value = s.autoConsolidatedBuffs,
            onValueChanged = function(_, value)
                s.autoConsolidatedBuffs = value
                mQoL_GeneralQoL:ApplySettings(s)
            end
        })
        AddGap(contentContainer, "Standard")
    end

    AddGap(contentContainer, "BottomSeparator")

    local lootSpeedMin, lootSpeedMax, lootSpeedStep = 0.01, 0.10, 0.01
    local currentLootSpeed = mQoL_FastAutoloot and type(mQoL_FastAutoloot.GetSpeed) == "function"
        and mQoL_FastAutoloot:GetSpeed()
        or tonumber(s.fastAutoLootSpeed)
        or 0.02
    currentLootSpeed = math.max(lootSpeedMin, math.min(lootSpeedMax, currentLootSpeed))

    local lootSpeedEditBox = CreateCustomInputBox(contentContainer)
    lootSpeedEditBox:SetSize(60, 24)

    local lootSpeedApplyFunc
    local _, lootSpeedSlider = AddOptionRow(contentContainer, "Fast Auto Loot Speed", "slider", {
        value = currentLootSpeed,
        min = lootSpeedMin,
        max = lootSpeedMax,
        step = lootSpeedStep,
        applyLabel = "Apply Speed",
        applyWidth = 120,
        onValueChanged = function(_, value)
            lootSpeedEditBox:SetText(string.format("%.2f", value))
        end
    }, {lootSpeedEditBox}, function()
        lootSpeedApplyFunc()
    end)

    lootSpeedEditBox:SetText(string.format("%.2f", currentLootSpeed))
    lootSpeedEditBox.slider = lootSpeedSlider

    lootSpeedApplyFunc = mQoL_Hub:SetupNumberInputBox(lootSpeedEditBox, lootSpeedSlider, lootSpeedMin, lootSpeedMax, lootSpeedStep, function(val)
        s.fastAutoLootSpeed = val
        if mQoL_FastAutoloot and type(mQoL_FastAutoloot.SetSpeed) == "function" then
            mQoL_FastAutoloot:SetSpeed(val)
        end
    end)

    AddGap(contentContainer, "BottomSeparator")

    -- Dropdown Items for My Name
    local dropdownItems = {
        { text = "Show", value = true, onSelect = function() s.showMyName = true; mQoL_GeneralQoL:ApplySettings(s) end },
        { text = "Hide", value = false, onSelect = function() s.showMyName = false; mQoL_GeneralQoL:ApplySettings(s) end },
        { text = "Disable", value = DISABLE, onSelect = function() s.showMyName = DISABLE; mQoL_GeneralQoL:ApplySettings(s) end },
    }

    AddOptionRow(contentContainer, "My Name", "dropdown", {
        list = dropdownItems,
        value = mQoL_Hub.NormalizeTriState(s.showMyName)
    })
    AddGap(contentContainer, "Standard")

    -- Show Head / Show Cloak (Pandaria/Era/BCC only)
    if clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC then
        -- Show Head
        AddOptionRow(contentContainer, "Show Head", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showHead = true; mQoL_GeneralQoL:ApplySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showHead = false; mQoL_GeneralQoL:ApplySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showHead = DISABLE; mQoL_GeneralQoL:ApplySettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showHead)
        })
        AddGap(contentContainer, "Standard")

        -- Show Cloak
        AddOptionRow(contentContainer, "Show Cloak", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showCloak = true; mQoL_GeneralQoL:ApplySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showCloak = false; mQoL_GeneralQoL:ApplySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showCloak = DISABLE; mQoL_GeneralQoL:ApplySettings(s) end },
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

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == addonName then
        mQoL_GeneralQoL:InitializeDB()
        if mQoL_Modules:ShouldLoadModule("GeneralQoL") then
            mQoL_GeneralQoL:CaptureCurrentSettings()
        end

        if IsLoggedIn() then
            C_Timer.After(0, function()
                mQoL_GeneralQoL:ApplySettings(mQoL_GeneralQoL.db.settings)
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        if not mQoL_GeneralQoL.db then
            mQoL_GeneralQoL:InitializeDB()
        end
        if mQoL_Modules:ShouldLoadModule("GeneralQoL") then
            mQoL_GeneralQoL:CaptureCurrentSettings()
        end

        C_Timer.After(0, function()
            mQoL_GeneralQoL:ApplySettings(mQoL_GeneralQoL.db.settings)
        end)

        if mQoL_Hub and mQoL_Hub.RegisterModuleOptions
            and mQoL_Modules:ShouldLoadModule("GeneralQoL") then
            mQoL_Hub:RegisterModuleOptions("mQoL_GeneralQoL", "General QoL", function(parent)
                return mQoL_GeneralQoL:CreatePanel(parent)
            end)
        end
    end
end)
