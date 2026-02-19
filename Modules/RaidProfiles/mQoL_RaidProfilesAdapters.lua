local addonName = "mQoL"
local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}

-- Namespace
mQoL_RaidProfiles = mQoL_RaidProfiles or {}
local VersionAdapters = {}
mQoL_RaidProfiles.VersionAdapters = VersionAdapters

local CVarLists = {
    Retail = {
        "raidFramesDisplayIncomingHeals",
        "raidFramesDisplayPowerBars",
        "raidFramesDisplayOnlyHealerPowerBars",
        "raidFramesDisplayAggroHighlight",
        "raidFramesDisplayClassColor",
        "raidFramesHealthBarColor",
        "raidOptionDisplayPets",
        "raidOptionDisplayMainTankAndAssist",
        "raidFramesDisplayDebuffs",
        "raidFramesDisplayLargerRoleSpecificDebuffs",
        "raidFramesDisplayOnlyDispellableDebuffs",
        "raidFramesCenterBigDefensive",
        "raidFramesDispelIndicatorType",
        "raidFramesDispelIndicatorOverlay",
        "raidFramesHealthText",
    },
    Classic = {
        "raidFramesDisplayClassColor",
        "raidOptionDisplayPets",
        "raidOptionDisplayMainTankAndAssist",
        "showDispelDebuffs",
        "raidFramesDisplayOnlyDispellableDebuffs",
        "raidFramesHealthText",
        "raidOptionShowBorders",
        "raidFramesDisplayPowerBars",
        "raidOptionKeepGroupsTogether",
        "raidOptionSortMode",
        "raidFramesHeight",
        "raidFramesWidth",
    },
    Legion = {
        "raidFramesDisplayClassColor",
        "raidOptionDisplayPets",
        "raidOptionDisplayMainTankAndAssist",
        "raidFramesDisplayIncomingHeals", 
        "raidFramesDisplayPowerBars",
        "raidFramesDisplayAggroHighlight",
        "showDispelDebuffs", 
        "raidFramesDisplayOnlyDispellableDebuffs",
        "raidFramesHealthText",
        "raidFramesHeight",
        "raidFramesWidth",
        "raidOptionShowBorders",
        "raidOptionKeepGroupsTogether",
        "raidOptionSortMode",
        "raidOptionHorizontalGroups",
    },
}

local CvarToOptionMappings = {
    Classic = {
        raidFramesDisplayClassColor = "useClassColors",
        raidOptionDisplayPets = "displayPets",
        raidOptionDisplayMainTankAndAssist = "displayMainTankAndAssist",
        showDispelDebuffs = "displayNonBossDebuffs",
        raidFramesDisplayOnlyDispellableDebuffs = "displayOnlyDispellableDebuffs",
        raidFramesHealthText = "healthText",
        raidOptionShowBorders = "displayBorder",
        raidFramesDisplayPowerBars = "displayPowerBar",
        raidOptionKeepGroupsTogether = "keepGroupsTogether",
        raidOptionSortMode = "sortBy",
        raidFramesHeight = "frameHeight",
        raidFramesWidth = "frameWidth",
    },
    Legion = {
        raidFramesDisplayClassColor = "useClassColors",
        raidOptionDisplayPets = "displayPets",
        raidOptionDisplayMainTankAndAssist = "displayMainTankAndAssist",
        raidFramesDisplayIncomingHeals = "displayHealPrediction",
        showDispelDebuffs = "displayNonBossDebuffs",
        raidFramesDisplayOnlyDispellableDebuffs = "displayOnlyDispellableDebuffs",
        raidFramesHealthText = "healthText",
        raidOptionShowBorders = "displayBorder",
        raidFramesDisplayPowerBars = "displayPowerBar",
        raidFramesDisplayAggroHighlight = "displayAggroHighlight",
        raidOptionKeepGroupsTogether = "keepGroupsTogether",
        raidOptionSortMode = "sortBy",
        raidOptionHorizontalGroups = "horizontalGroups",
        raidFramesHeight = "frameHeight",
        raidFramesWidth = "frameWidth",
    },
}

local MQOL_PROFILE_NAME = "mQoL"

-- Convert string value to appropriate type for Blizzard API
local function ConvertValueForLoad(value)
    if value == "1" then return true
    elseif value == "0" then return false
    elseif tonumber(value) then return tonumber(value)
    end
    return value
end

-- Convert value to string for storage
local function ConvertValueForSave(value)
    if value == true then return "1"
    elseif value == false then return "0"
    end
    return tostring(value)
end

-- Show max profiles error popup
local function ShowMaxProfilesError(max)
    if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
        mQoL_Styles.ShowCustomPopup({
            text = addonName .. ":\nCannot load profile. You have reached the maximum number of Raid Profiles ("..max..").\n\nPlease delete one profile in the Blizzard Interface > Raid Profiles settings.",
            acceptText = "OK",
            cancelText = "Close",
            width = 450,
            height = 220,
        })
    else
        print(addonName .. ": ERROR - Cannot load profile. You have reached the maximum number of Raid Profiles ("..max.."). Please delete one profile in the Blizzard Interface > Raid Profiles settings.")
    end
end

-- Ensure mQoL profile exists in Blizzard system (Classic/Legion only)
local function EnsureBlizzardProfile()
    local exists = RaidProfileExists and RaidProfileExists(MQOL_PROFILE_NAME)

    if not exists then
        local count = (GetNumRaidProfiles and GetNumRaidProfiles()) or 0
        local max = (GetMaxNumRaidProfiles and GetMaxNumRaidProfiles()) or 5
        if count >= max then
            ShowMaxProfilesError(max)
            return false
        end
    end

    if exists then
        if DeleteRaidProfile then
            DeleteRaidProfile(MQOL_PROFILE_NAME)
        end
    end

    if CreateNewRaidProfile then
        CreateNewRaidProfile(MQOL_PROFILE_NAME)
    end

    return true
end

-- Apply profile options using Blizzard API (Classic/Legion)
local function ApplyProfileOptions(savedCVars, cvarToOption)
    local applied = 0

    if SetRaidProfileOption then
        for cvar, value in pairs(savedCVars) do
            if cvar ~= "_positions" then 
                local optionName = cvarToOption[cvar]
                if optionName then
                    local optValue = ConvertValueForLoad(value)
                    SetRaidProfileOption(MQOL_PROFILE_NAME, optionName, optValue)
                    applied = applied + 1
                elseif cvar == "useCompactPartyFrames" then
                    SetCVar(cvar, value)
                end
            end
        end
    end

    return applied
end

-- Activate Blizzard profile safely
local function ActivateBlizzardProfile()
    if CompactUnitFrameProfiles_ActivateRaidProfile then
        local success, err = pcall(CompactUnitFrameProfiles_ActivateRaidProfile, MQOL_PROFILE_NAME)
        if not success then
            if SetActiveRaidProfile then
                SetActiveRaidProfile(MQOL_PROFILE_NAME)
            end
        end
    elseif SetActiveRaidProfile then
        SetActiveRaidProfile(MQOL_PROFILE_NAME)
        if CompactUnitFrameProfiles_ApplyCurrentSettings then
            pcall(CompactUnitFrameProfiles_ApplyCurrentSettings)
        end
    end
    
    -- Ensure frame layout is updated after profile activation
    C_Timer.After(0.05, function()
        if CompactRaidFrameContainer then
            if CompactRaidFrameContainer.TryUpdate then
                CompactRaidFrameContainer:TryUpdate()
            elseif CompactRaidFrameContainer_TryUpdate then
                CompactRaidFrameContainer_TryUpdate(CompactRaidFrameContainer)
            end
        end
    end)
end

-- Apply saved positions (Classic/Legion only)
local pendingPositions = nil
local positionEventFrame = nil

local function SetupPositionEventFrame()
    if positionEventFrame then return end

    positionEventFrame = CreateFrame("Frame")
    positionEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    positionEventFrame:SetScript("OnEvent", function()
        if pendingPositions and not InCombatLockdown() then
            local pos = pendingPositions
            pendingPositions = nil

            if SetRaidProfileSavedPosition then
                SetRaidProfileSavedPosition(MQOL_PROFILE_NAME, 
                    pos.isDynamic or false,
                    pos.topPoint or "TOP",
                    pos.topOffset or 200,
                    pos.bottomPoint or "TOP",
                    pos.bottomOffset or 400,
                    pos.leftPoint or "LEFT",
                    pos.leftOffset or 200
                )
                if CompactRaidFrameManager_ResizeFrame_LoadPosition then
                    CompactRaidFrameManager_ResizeFrame_LoadPosition(CompactRaidFrameManager)
                end
            end
        end
    end)
end

local function ApplyPositions(positions)
    if not positions then return end

    C_Timer.After(0.01, function()
        if InCombatLockdown() then
            -- Store for applying after combat
            pendingPositions = positions
            SetupPositionEventFrame()
            return
        end

        if SetRaidProfileSavedPosition then
            SetRaidProfileSavedPosition(MQOL_PROFILE_NAME, 
                positions.isDynamic or false,
                positions.topPoint or "TOP",
                positions.topOffset or 200,
                positions.bottomPoint or "TOP",
                positions.bottomOffset or 400,
                positions.leftPoint or "LEFT",
                positions.leftOffset or 200
            )
            if CompactRaidFrameManager_ResizeFrame_LoadPosition then
                CompactRaidFrameManager_ResizeFrame_LoadPosition(CompactRaidFrameManager)
            end
        end
    end)
end

-- Read profile options from Blizzard API (Classic/Legion)
local function ReadProfileOptions(cvars, cvarToOption)
    local cvarData = {}
    local activeProfile = GetActiveRaidProfile and GetActiveRaidProfile()

    if activeProfile and GetRaidProfileOption then
        for _, cvar in ipairs(cvars) do
            local optionName = cvarToOption[cvar]
            if optionName then
                local value = GetRaidProfileOption(activeProfile, optionName)
                cvarData[cvar] = ConvertValueForSave(value)
            else
                local value = GetCVar(cvar)
                if value then
                    cvarData[cvar] = value
                end
            end
        end
    else
        for _, cvar in ipairs(cvars) do
            local value = GetCVar(cvar)
            if value then cvarData[cvar] = value end
        end
    end

    return cvarData
end

-- Save positions from Blizzard API
local function SavePositions()
    if not GetRaidProfileSavedPosition then return nil end

    local activeProfile = GetActiveRaidProfile and GetActiveRaidProfile()
    if not activeProfile then return nil end

    local isDynamic, topPoint, topOffset, bottomPoint, bottomOffset, leftPoint, leftOffset = GetRaidProfileSavedPosition(activeProfile)
    return {
        isDynamic = isDynamic,
        topPoint = topPoint,
        topOffset = topOffset,
        bottomPoint = bottomPoint,
        bottomOffset = bottomOffset,
        leftPoint = leftPoint,
        leftOffset = leftOffset,
    }
end

VersionAdapters.Retail = {
    cvars = CVarLists.Retail,
    cvarToOption = nil, -- Retail doesn't use Blizzard profile API

    LoadProfile = function(savedCVars, profileName)
        local applied = 0
        for cvar, value in pairs(savedCVars) do
            if cvar ~= "_positions" then
                local cvarExists = true
                if C_CVar and C_CVar.GetCVar then
                    cvarExists = C_CVar.GetCVar(cvar) ~= nil
                end
                if cvarExists then
                    SetCVar(cvar, tostring(value))
                    applied = applied + 1
                end
            end
        end
        return true
    end,

    SaveProfile = function(cvars)
        local cvarData = {}
        for _, cvar in ipairs(cvars) do
            local value = GetCVar(cvar)
            if value then
                cvarData[cvar] = value
            end
        end
        return cvarData
    end,
}

VersionAdapters.Classic = {
    cvars = CVarLists.Classic,
    cvarToOption = CvarToOptionMappings.Classic,

    LoadProfile = function(savedCVars, profileName)
        if not EnsureBlizzardProfile() then
            return false
        end

        local applied = ApplyProfileOptions(savedCVars, CvarToOptionMappings.Classic)
        ActivateBlizzardProfile()
        ApplyPositions(savedCVars._positions)

        return true
    end,

    SaveProfile = function(cvars)
        local cvarData = ReadProfileOptions(cvars, CvarToOptionMappings.Classic)
        cvarData._positions = SavePositions()
        return cvarData
    end,
}

VersionAdapters.Legion = {
    cvars = CVarLists.Legion,
    cvarToOption = CvarToOptionMappings.Legion,

    LoadProfile = function(savedCVars, profileName)
        if not EnsureBlizzardProfile() then
            return false
        end

        local applied = ApplyProfileOptions(savedCVars, CvarToOptionMappings.Legion)
        ActivateBlizzardProfile()
        ApplyPositions(savedCVars._positions)

        return true
    end,

    SaveProfile = function(cvars)
        local cvarData = ReadProfileOptions(cvars, CvarToOptionMappings.Legion)
        cvarData._positions = SavePositions()
        return cvarData
    end,
}

-- Get adapter for current client version
function VersionAdapters:GetCurrent()
    if clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC then
        return self.Classic
    elseif clientInfo.isLegion then
        return self.Legion
    elseif clientInfo.isRetail then
        return self.Retail
    end
    -- Fallback to Retail if unknown
    return self.Retail
end

-- Get CVars for current version
function VersionAdapters:GetCVars()
    return self:GetCurrent().cvars
end

-- Load profile using appropriate adapter
function VersionAdapters:LoadProfile(savedCVars, profileName)
    local adapter = self:GetCurrent()
    return adapter.LoadProfile(savedCVars, profileName)
end

-- Save profile using appropriate adapter
function VersionAdapters:SaveProfile()
    local adapter = self:GetCurrent()
    return adapter.SaveProfile(adapter.cvars)
end