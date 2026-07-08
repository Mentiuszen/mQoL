local addonName = ...
mQoL = mQoL or {}

-- Enforce mQoL Hub First
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
    return
end

-- ToC Detection
local clientInfo = mQoL_VersionDetection.clientInfo

-- Styles
local CreateCustomScrollbar = mQoL_Styles and mQoL_Styles.CreateCustomScrollbar
local CreateCustomButton = mQoL_Styles and mQoL_Styles.CreateCustomButton
local CreateCustomDropdown = mQoL_Styles and mQoL_Styles.CreateCustomDropdown
local CreateCustomSlider = mQoL_Styles and mQoL_Styles.CreateCustomSlider
local CreateCustomInputBox = mQoL_Styles and mQoL_Styles.CreateCustomInputBox
local CreateCustomCheckbox = mQoL_Styles and mQoL_Styles.CreateCustomCheckbox

-- Create Blizzard Fixes Panel
function mQoL.CreateBlizzardPanel(parent)
    local function ShowReloadPopup()
        mQoL_Styles.ShowCustomPopup({
            text = "Settings have changed.\n\nA UI reload is required for these changes to take effect.\n\nReload now?",
            acceptText = "Reload UI",
            cancelText = "Later",
            onAccept = function()
                ReloadUI()
            end,
            onCancel = function() end,
            width = 450,
            height = 200
        })
    end

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Blizzard Fixes", {
        text = "How do these fixes work?",
        textColor = {1, 0.82, 0},
        explanation = "Apply targeted fixes for known Blizzard UI bugs.\n\n• This will fix bugs I found playing Pandaria Classic for now.\n• Consolidated Buffs is not strictly a bug, but it is an improvement; use it if you like it.\n• These bugs are confirmed, and when Blizzard fixes them, I will remove the fix. But for now, only 2 bugs got fixed. -.-",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "TopSeparator")

    local AddGap = mQoL_Templates.AddGap

    -- Checkbox Options
    local blizzardOptions = {
        { key = "fixPvPRewards", label = "PvP Rewards Fix", tooltip = "Fixes Honor/Conquest reward display." },
        { key = "fixPandariaMap", label = "Pandaria Map Navigation", tooltip = "Adds navigation arrows and zone levels to Pandaria maps." },
        { key = "fixConsolidatedBuffs", label = "Consolidated Buffs Fix", tooltip = "Fixes the consolidated buffs display." },
        { key = "fixCorpseMap", label = "Corpse Map Texture Fix", tooltip = "Fixes the corpse texture on the world map." },
        { key = "fixMinimapDifficulty", label = "Minimap Instance Difficulty Fix", tooltip = "Fixes the instance difficulty indicator on the minimap." },
        { key = "fixRaidDifficultyReset", label = "Auto Reset Instance", tooltip = "Automatically resets instances when changing difficulty." },
        { key = "fixJournalTabs", label = "Encounter Journal Tab Fix", tooltip = "Fixes Encounter Journal tabs selection." },
    }

    for i, opt in ipairs(blizzardOptions) do
        local isEnabled = mQoL_DB.BlizzardFixes[opt.key]
        
        local row, cb = mQoL_Hub:AddOptionRow(contentContainer, opt.label, "checkbox", {
            value = isEnabled,
            onValueChanged = function(self, state)
                mQoL_DB.BlizzardFixes[opt.key] = state
                ShowReloadPopup()
            end
        })
        if i < #blizzardOptions then
            AddGap(contentContainer, "Standard")
        end
    end

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

-- Register Blizzard Fixes Panel in mQoL Hub
local function RegisterBlizzardPanel()
    if mQoL_Hub and type(mQoL_Hub.CreateInfoSection) == "function" and type(mQoL_Hub.RegisterModuleOptions) == "function" then
        mQoL_Hub:RegisterModuleOptions("mQoL_Blizzard", "Blizzard Fixes", function(parent)
            return mQoL.CreateBlizzardPanel(parent)
        end)
    else
        -- Retry after delay if mQoL_Hub is not ready
        C_Timer.After(0.5, RegisterBlizzardPanel)
    end
end

-- Initialize DB
local function InitializeDB()
    if not mQoL_DB then mQoL_DB = {} end
    if not mQoL_DB.BlizzardFixes then mQoL_DB.BlizzardFixes = {} end
    
    -- Set Default Settings
    local defaultSettings = {
        fixPvPRewards = true,
        fixPandariaMap = true,
        fixConsolidatedBuffs = true,
        fixCorpseMap = true,
        fixMinimapDifficulty = true,
        fixRaidDifficultyReset = true,
        fixJournalTabs = true,
    }

    for k, v in pairs(defaultSettings) do
        if mQoL_DB.BlizzardFixes[k] == nil then
            mQoL_DB.BlizzardFixes[k] = v
        end
    end
end

-- Event Handler
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
		InitializeDB()
		RegisterBlizzardPanel()
    end
end)