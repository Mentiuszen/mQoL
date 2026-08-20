local addonName = ...

-- Module Registry
--
-- This file is intentionally limited to module metadata and module state. The
-- setup flow itself lives in Core/mQoL_Setup.lua, which makes it possible to use
-- the same wizard for a fresh installation and for modules added in an update.
mQoL_Modules = mQoL_Modules or {}

mQoL_Modules.REGISTRY_VERSION = 1

-- Every optional module starts disabled. Hub is core functionality and is not
-- represented here, so it is always available.
mQoL_Modules.AvailableModules = {
    {
        key = "AccountOverview",
        label = "Account Overview",
        description = "Account-wide overview with tracked characters, professions, played time, and gold history.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        setupVersion = 1,
        order = 10,
    },
    {
        key = "GeneralQoL",
        label = "General QoL",
        description = "General quality of life improvements, including Auto Loot and Quest Tracking.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        controller = "mQoL_General",
        setupVersion = 1,
        order = 20,
    },
    {
        key = "NameplatesQoL",
        label = "Nameplates QoL",
        description = "Nameplate settings and improvements.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        controller = "mQoL_Nameplates",
        setupVersion = 1,
        order = 30,
    },
    {
        key = "ActionBarsQoL",
        label = "Action Bars QoL",
        description = "Action bar visibility and settings.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        controller = "mQoL_ActionBars",
        setupVersion = 1,
        order = 40,
    },
    {
        key = "Mailbox",
        label = "Mailbox Improvements",
        description = "Enhancements for the mailbox UI and functionality.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        setupVersion = 1,
        order = 50,
    },
    {
        key = "Graphics",
        label = "Graphics Settings",
        description = "Additional graphics tweaks and options.",
        versions = {"isClassic", "isEra", "isBCC"},
        setupVersion = 1,
        order = 60,
    },
    {
        key = "BlizzardFixes",
        label = "Blizzard Fixes",
        description = "Fixes for various Blizzard UI bugs and annoyances.",
        versions = {"isClassic", "isBCC"},
        hardlock = {"isRetail", "isPandaria", "isLegion", "isEra"},
        setupVersion = 1,
        order = 70,
    },
    {
        key = "EditMode",
        label = "Edit Mode",
        description = "Manage Edit Mode profiles and settings.",
        versions = {"isRetail", "isBCC", "isClassic", "isEra"},
        hardlock = {"isPandaria", "isLegion"},
        setupVersion = 1,
        order = 80,
    },
    {
        key = "RaidProfiles",
        label = "Raid Profiles",
        description = "Automatic transfer of raid profiles between characters.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        setupVersion = 1,
        order = 90,
    },
    {
        key = "DungeonTeleports",
        label = "Dungeon Teleports",
        description = "Adds dungeon teleport navigation to the Group Finder interface.",
        versions = {"isRetail", "isClassic"},
        hardlock = {"isPandaria", "isLegion", "isEra", "isBCC"},
        setupVersion = 1,
        order = 100,
    },
    {
        key = "MythicPlusListing",
        label = "Mythic+ Listing Helper",
        description = "Adds a Retail-only helper to the Premade Groups Mythic+ listing panel that shows party keystones.",
        versions = {"isRetail"},
        hardlock = {"isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        setupVersion = 1,
        order = 110,
    },
}

local function HasLegacySetup()
    if not mQoL_DB then return false end

    return mQoL_DB.firstSetupDone == true
        or type(mQoL_DB.MainQoL) == "table"
        or type(mQoL_DB.Modules) == "table"
end

local function GetSetupState()
    mQoL_DB = mQoL_DB or {}
    mQoL_DB.Setup = mQoL_DB.Setup or {}

    local setup = mQoL_DB.Setup
    setup.seenModules = setup.seenModules or {}
    return setup
end

function mQoL_Modules:GetModule(key)
    for _, module in ipairs(self.AvailableModules) do
        if module.key == key then
            return module
        end
    end
    return nil
end

function mQoL_Modules:IsModuleCompatible(moduleData)
    local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo
    if not moduleData or not clientInfo then return false end

    for _, versionKey in ipairs(moduleData.versions or {}) do
        if clientInfo[versionKey] then
            return true
        end
    end
    return false
end

function mQoL_Modules:IsModuleHardlocked(moduleData)
    local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo
    if not moduleData or not clientInfo or not moduleData.hardlock then return false end

    for _, versionKey in ipairs(moduleData.hardlock) do
        if clientInfo[versionKey] then
            return true
        end
    end
    return false
end

function mQoL_Modules:IsModuleAvailable(moduleData)
    return moduleData
        and not self:IsModuleHardlocked(moduleData)
        and self:IsModuleCompatible(moduleData)
end

function mQoL_Modules:GetCompatibleModules()
    local modules = {}

    for _, module in ipairs(self.AvailableModules) do
        if self:IsModuleAvailable(module) then
            table.insert(modules, module)
        end
    end

    table.sort(modules, function(a, b)
        if a.order == b.order then
            return a.label < b.label
        end
        return (a.order or 0) < (b.order or 0)
    end)

    return modules
end

function mQoL_Modules:GetModuleSetupVersion(moduleData)
    return tonumber(moduleData and moduleData.setupVersion) or 1
end

function mQoL_Modules:MarkModuleSeen(key)
    local moduleData = self:GetModule(key)
    if not moduleData then return end

    local setup = GetSetupState()
    setup.seenModules[key] = self:GetModuleSetupVersion(moduleData)
end

function mQoL_Modules:GetUnseenCompatibleModules()
    local setup = GetSetupState()
    local modules = {}

    for _, module in ipairs(self:GetCompatibleModules()) do
        local seenVersion = tonumber(setup.seenModules[module.key]) or 0
        if seenVersion < self:GetModuleSetupVersion(module) then
            table.insert(modules, module)
        end
    end

    return modules
end

function mQoL_Modules:IsModuleEnabled(key)
    return mQoL_DB
        and mQoL_DB.Modules
        and mQoL_DB.Modules[key] == true
end

function mQoL_Modules:PrepareModuleSettings(key)
    local moduleData = self:GetModule(key)
    if not moduleData or not moduleData.controller then
        return true
    end

    local controller = _G[moduleData.controller]
    if not controller or type(controller.CaptureCurrentSettings) ~= "function" then
        print(string.format("|cffff4444[mQoL]|r Cannot initialize settings for [%s].", key))
        return false
    end

    local success, errorMessage = pcall(controller.CaptureCurrentSettings, controller)
    if not success then
        print(string.format("|cffff4444[mQoL]|r Failed to initialize settings for [%s]: %s", key, tostring(errorMessage)))
        return false
    end
    return true
end

function mQoL_Modules:SetModuleEnabled(key, enabled, allowUnsupported)
    local moduleData = self:GetModule(key)
    if not moduleData or self:IsModuleHardlocked(moduleData) then
        return false
    end

    if enabled and not allowUnsupported and not self:IsModuleCompatible(moduleData) then
        return false
    end

    if enabled and not self:PrepareModuleSettings(key) then
        return false
    end

    mQoL_DB = mQoL_DB or {}
    mQoL_DB.Modules = mQoL_DB.Modules or {}
    mQoL_DB.Modules[key] = enabled == true
    return true
end

-- Strict runtime check. Until a player enables a module, only Hub remains active.
function mQoL_Modules:ShouldLoadModule(key)
    local moduleData = self:GetModule(key)
    if not moduleData or self:IsModuleHardlocked(moduleData) then
        return false
    end

    return self:IsModuleEnabled(key)
end

function mQoL_Modules:Initialize()
    mQoL_DB = mQoL_DB or {}
    local hasLegacySetup = HasLegacySetup()
    local hadModuleSelections = type(mQoL_DB.Modules) == "table"
    mQoL_DB.Modules = mQoL_DB.Modules or {}

    local setup = GetSetupState()
    setup.pendingReload = false
    if not setup.initialized then
        setup.initialized = true
        setup.registryVersion = self.REGISTRY_VERSION

        -- Existing installations retain their selections and are not forced
        -- through the new welcome wizard. Future modules will still be shown.
        if hasLegacySetup then
            setup.completed = true
            setup.migratedFromLegacy = true
            setup.migratedWithoutRegistry = not hadModuleSelections
            for _, module in ipairs(self.AvailableModules) do
                if not hadModuleSelections or mQoL_DB.Modules[module.key] ~= nil then
                    setup.seenModules[module.key] = self:GetModuleSetupVersion(module)
                end
            end
        else
            setup.completed = false
        end
    end

    for _, module in ipairs(self.AvailableModules) do
        if mQoL_DB.Modules[module.key] == nil then
            -- Before the registry existed, compatible modules were enabled by
            -- default. Preserve that behavior once, while fresh installs and
            -- genuinely new modules remain opt-in.
            mQoL_DB.Modules[module.key] = setup.migratedWithoutRegistry == true
                and self:IsModuleAvailable(module)
                or false
        end
    end
end

function mQoL_Modules:ShowReloadPopup()
    local ShowCustomPopup = mQoL_Styles and mQoL_Styles.ShowCustomPopup
    if not ShowCustomPopup then return end

    ShowCustomPopup({
        text = "Module settings have changed.\n\nA UI reload is required to apply changes to enabled and disabled modules.\n\nReload now?",
        acceptText = "Reload UI",
        cancelText = "Later",
        onAccept = function()
            ReloadUI()
        end,
        width = 450,
        height = 220,
    })
end

function mQoL_Modules:CreateModulesPanel(parent)
    local mQoL_Hub = _G["mQoL_Hub"]
    if not mQoL_Hub or not mQoL_Templates then return end

    local AddGap = mQoL_Templates.AddGap
    if not AddGap then return end

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Module Manager", {
        text = "How Modules Management Works?",
        textColor = {1, 0.82, 0},
        explanation = "Only the mQoL Hub is active by default. Enable the modules you want to use; a reload applies the new selection.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
        animDuration = 0.25,
    }, "MainSeparator")

    for _, module in ipairs(self:GetCompatibleModules()) do
        mQoL_Hub:AddOptionRow(contentContainer, module.label, "checkbox", {
            value = self:IsModuleEnabled(module.key),
            tooltip = module.description,
            onValueChanged = function(_, value)
                if self:SetModuleEnabled(module.key, value) then
                    self:MarkModuleSeen(module.key)
                    self:ShowReloadPopup()
                end
            end,
        })
        AddGap(contentContainer, "Standard")
    end

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

local function RegisterModulesPanel()
    local mQoL_Hub = _G["mQoL_Hub"]
    if mQoL_Hub and type(mQoL_Hub.RegisterModuleOptions) == "function" then
        mQoL_Hub:RegisterModuleOptions("mQoL_Modules", "Modules", function(parent)
            return mQoL_Modules:CreateModulesPanel(parent)
        end)
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, RegisterModulesPanel)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, loadedAddonName)
    if loadedAddonName == addonName then
        mQoL_Modules:Initialize()
        RegisterModulesPanel()
    end
end)

-- SavedVariables are available before addon Lua files execute. Initialize the
-- registry here so every module loaded later in the TOC can gate all top-level
-- initialization consistently.
mQoL_Modules:Initialize()
