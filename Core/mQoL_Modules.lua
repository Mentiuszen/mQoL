local addonName = ...

mQoL_Modules = mQoL_Modules or {}

-- Initialize logic
function mQoL_Modules:Initialize()
    mQoL_DB = mQoL_DB or {}
    mQoL_DB.Modules = mQoL_DB.Modules or {}

    -- Set defaults if missing
    for _, module in ipairs(self.AvailableModules) do
        if mQoL_DB.Modules[module.key] == nil then
            local isHardlocked = self:IsModuleHardlocked(module)
            if isHardlocked then
                mQoL_DB.Modules[module.key] = false
            elseif module.defaultEnabled ~= nil then
                mQoL_DB.Modules[module.key] = (module.defaultEnabled == true) and self:IsModuleCompatible(module)
            else
                mQoL_DB.Modules[module.key] = self:IsModuleCompatible(module)
            end
        end
    end
end

-- Define available modules and their compatibility
mQoL_Modules.AvailableModules = {
    {
        key = "AccountOverview",
        label = "Account Overview",
        description = "Account-wide overview with tracked characters, professions, played time, and gold history.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        defaultEnabled = true,
    },
    {
        key = "GeneralQoL",
        label = "General QoL",
        description = "General quality of life improvements (Auto Loot, Quest Tracking, etc).",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        defaultEnabled = true,
    },
    {
        key = "NameplatesQoL",
        label = "Nameplates QoL",
        description = "Nameplate settings and improvements.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        defaultEnabled = true,
    },
    {
        key = "ActionBarsQoL",
        label = "Action Bars QoL",
        description = "Action bar visibility and settings.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        defaultEnabled = true,
    },
    {
        key = "Mailbox",
        label = "Mailbox Improvements",
        description = "Enhancements for the mailbox UI and functionality.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        defaultEnabled = true,
    },
    {
        key = "Graphics",
        label = "Graphics Settings",
        description = "Additional graphics tweaks and options.",
        versions = {"isClassic", "isEra", "isBCC"},
        defaultEnabled = true,
    },
    {
        key = "BlizzardFixes",
        label = "Blizzard Fixes",
        description = "Fixes for various Blizzard UI bugs and annoyances.",
        versions = {"isClassic"},
        hardlock = {"isRetail", "isPandaria", "isLegion", "isEra", "isBCC"},
        defaultEnabled = true,
    },
    {
        key = "EditMode",
        label = "Edit Mode",
        description = "Manage Edit Mode profiles and settings.",
        versions = {"isRetail", "isBCC"},
        hardlock = {"isClassic", "isPandaria", "isLegion", "isEra"},
        defaultEnabled = true,
    },
    {
        key = "RaidProfiles",
        label = "Raid Profiles",
        description = "Automatic transfer of raid profiles between characters.",
        versions = {"isRetail", "isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        defaultEnabled = true,
    },
    {
        key = "MythicPlusListing",
        label = "Mythic+ Listing Helper",
        description = "Adds a Retail-only helper to the Premade Groups Mythic+ listing panel that shows party keystones.",
        versions = {"isRetail"},
        hardlock = {"isClassic", "isPandaria", "isLegion", "isEra", "isBCC"},
        defaultEnabled = true,
    }
}

-- Check if a module is compatible with the current running client
function mQoL_Modules:IsModuleCompatible(moduleData)
    local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo
    if not clientInfo then return false end

    for _, vKey in ipairs(moduleData.versions) do
        if clientInfo[vKey] then
            return true
        end
    end
    return false
end

-- Check if a module is strictly hardlocked for the current client (versions that it cannot be enabled on)
function mQoL_Modules:IsModuleHardlocked(moduleData)
    local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo
    if not clientInfo then return false end

    if moduleData.hardlock then
        for _, vKey in ipairs(moduleData.hardlock) do
            if clientInfo[vKey] then
                return true
            end
        end
    end
    return false
end

-- Check if a module is enabled in Database
function mQoL_Modules:IsModuleEnabled(key)
    if not mQoL_DB or not mQoL_DB.Modules then return true end -- Default to enabled if DB not loaded
    return mQoL_DB.Modules[key]
end

-- Strict check for Module loading: Must be Compatible and Enabled
function mQoL_Modules:ShouldLoadModule(key)
    local moduleData = nil
    for _, m in ipairs(self.AvailableModules) do
        if m.key == key then
            moduleData = m
            break
        end
    end

    if not moduleData then return false end -- Unknown module

    -- If Hardlocked don't load
    if self:IsModuleHardlocked(moduleData) then
        return false
    end

    if mQoL_DB and mQoL_DB.Modules and mQoL_DB.Modules[key] ~= nil then
        return mQoL_DB.Modules[key]
    end

    if moduleData.defaultEnabled ~= nil then
        return (moduleData.defaultEnabled == true) and self:IsModuleCompatible(moduleData)
    end

    return self:IsModuleCompatible(moduleData)
end

function mQoL_Modules:ShowReloadPopup()
    local ShowCustomPopup = mQoL_Styles and mQoL_Styles.ShowCustomPopup
    if not ShowCustomPopup then return end

    ShowCustomPopup({
        text = "Module settings have changed.\n\nA UI reload is required to apply changes to enabled/disabled modules.\n\nReload now?",
        acceptText = "Reload UI",
        cancelText = "Later",
        onAccept = function()
            ReloadUI()
        end,
        onCancel = function() end,
        width = 450,
        height = 220
    })
end

function mQoL_Modules:CreateModulesPanel(parent)
    local mQoL_Hub = _G["mQoL_Hub"]
    if not mQoL_Hub then return end

    local AddGap = mQoL_Templates and mQoL_Templates.AddGap
    if not AddGap then return end

    local scrollFrame, panel, contentContainer, infoButton, explanationFrame = mQoL_Templates.CreateStandardOptionsPanel(parent, "Module Manager", {
        text = "How Modules Management Works?",
        textColor = { 1, 0.82, 0 },
        explanation = "Manage the active components of the addon.\n\n• Enable or disable modules to customize addon functionality.\n• Unsupported modules for your current game version are below |cffff0000RED WARNING|r (use them at your own risk).",
        explanationColor = { 1, 1, 1 },
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
        animDuration = 0.25,
    }, "MainSeparator")

    -- Sort modules into two groups
    local compatibleModules = {}
    local incompatibleModules = {}

    for _, module in ipairs(self.AvailableModules) do
        -- Skip hardlocked modules
        if not self:IsModuleHardlocked(module) then
            if self:IsModuleCompatible(module) then
                table.insert(compatibleModules, module)
            else
                table.insert(incompatibleModules, module)
            end
        end
    end

    local function SortByName(a, b) return a.key < b.key end
    table.sort(compatibleModules, SortByName)
    table.sort(incompatibleModules, SortByName)

    -- Helper to render a module row
    local function RenderModuleRow(module, isCompatible)
        local labelText = module.label
        local description = module.description

        if not isCompatible then
            labelText = "|cff808080" .. labelText .. " (Unsupported)|r"
            description = description .. "\n|cffff0000Warning: This module is not designed for your game version.|r"
        end

        -- Initialize DB value if missing
        if mQoL_DB.Modules[module.key] == nil then
            if self:IsModuleHardlocked(module) then
                mQoL_DB.Modules[module.key] = false
            elseif module.defaultEnabled ~= nil then
                mQoL_DB.Modules[module.key] = (module.defaultEnabled == true) and self:IsModuleCompatible(module)
            else
                mQoL_DB.Modules[module.key] = self:IsModuleCompatible(module)
            end
        end

        mQoL_Hub:AddOptionRow(contentContainer, labelText, "checkbox", {
            value = mQoL_DB.Modules[module.key],
            tooltip = description,
            onValueChanged = function(self, value)
                mQoL_DB.Modules[module.key] = value
                mQoL_Modules:ShowReloadPopup()
            end,
        })
        AddGap(contentContainer, "Standard")
    end

    for _, module in ipairs(compatibleModules) do
        RenderModuleRow(module, true)
    end

    if #incompatibleModules > 0 then
        AddGap(contentContainer, "WarningSeparator", {
            text = "Unsupported by this version of game, but you can still enable them at your own risk.",
            textColor = { 1, 0, 0, 1 },
            lineColor = { 1, 0, 0, 0.3 },
        })

        for _, module in ipairs(incompatibleModules) do
            RenderModuleRow(module, false)
        end
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
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        mQoL_Modules:Initialize()
        RegisterModulesPanel()
    end
end)