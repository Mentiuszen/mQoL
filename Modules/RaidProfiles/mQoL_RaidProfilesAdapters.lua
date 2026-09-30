local addonName = "mQoL"
local C_Timer = mQoL_Compat.Timer
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
        "raidFramesHealthBarColorBG",
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
    Classic = { -- Classic Clients that do not got a update to new format (Era and Current MoP Classic 5.5.3)
        "raidFramesDisplayClassColor",
        "raidOptionDisplayPets",
        "raidOptionDisplayMainTankAndAssist",
        "showDispelDebuffs",
        "raidFramesDisplayOnlyDispellableDebuffs",
        "raidFramesHealthText",
        "raidOptionShowBorders",
        "raidFramesDisplayPowerBars",
        "raidOptionKeepGroupsTogether",
        "raidOptionHorizontalGroups",
        "raidOptionSortMode",
        "raidFramesHeight",
        "raidFramesWidth",
    },
    ModernClassic = {   -- Modern Classic Clients that got update to new format (BCC and MoP Classic 5.5.4)
        "raidFramesDisplayIncomingHeals",
        "raidFramesDisplayPowerBars",
        "raidFramesDisplayOnlyHealerPowerBars",
        "raidFramesDisplayAggroHighlight",
        "raidFramesDisplayClassColor",
        "raidOptionDisplayPets",
        "raidOptionDisplayMainTankAndAssist",
        "raidFramesDisplayDebuffs",
        "raidFramesDisplayOnlyDispellableDebuffs",
        "raidFramesHealthText",
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
        raidOptionHorizontalGroups = "horizontalGroups",
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

local function SafeCall(func, ...)
    if not func then
        return false
    end

    local ok, result = pcall(func, ...)
    if not ok then
        return false
    end

    return true, result
end

function mQoL_RaidProfiles:ShouldHandleUseCompactPartyFrames()
    if mQoL_Auto then return mQoL_CVar:CanRead('useCompactPartyFrames') end
    return clientInfo.isEra or clientInfo.isVanilla or clientInfo.isLegion
end

function mQoL_RaidProfiles:ApplyUseCompactPartyFrames(value)
    if mQoL_Auto then return mQoL_CVar:Apply('useCompactPartyFrames',value) end
    if not self:ShouldHandleUseCompactPartyFrames() then
        return
    end

    local cvarValue = (value == true or value == 1 or value == "1" or value == "true") and "1" or "0"
    if BlizzardOptionsPanel_SetCVarSafe then
        SafeCall(BlizzardOptionsPanel_SetCVarSafe, "useCompactPartyFrames", cvarValue)
    else
        SafeCall(SetCVar, "useCompactPartyFrames", cvarValue)
    end

    local blizzardControl = _G.CompactUnitFrameProfilesRaidStylePartyFrames
    if blizzardControl and blizzardControl.setFunc then
        local ok = SafeCall(blizzardControl.setFunc, cvarValue)
        if ok then
            return
        end
    end

    if RaidOptionsFrame_UpdatePartyFrames then
        SafeCall(RaidOptionsFrame_UpdatePartyFrames)
    end

    if CompactRaidFrameManager_UpdateShown and CompactRaidFrameManager then
        SafeCall(CompactRaidFrameManager_UpdateShown, CompactRaidFrameManager)
    end

    if CompactRaidFrameContainer then
        if CompactRaidFrameContainer.TryUpdate then
            SafeCall(CompactRaidFrameContainer.TryUpdate, CompactRaidFrameContainer)
        elseif CompactRaidFrameContainer_TryUpdate then
            SafeCall(CompactRaidFrameContainer_TryUpdate, CompactRaidFrameContainer)
        end
    end
end

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
            SafeCall(DeleteRaidProfile, MQOL_PROFILE_NAME)
        end
    end

    if CreateNewRaidProfile then
        SafeCall(CreateNewRaidProfile, MQOL_PROFILE_NAME)
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
                    if SafeCall(SetRaidProfileOption, MQOL_PROFILE_NAME, optionName, optValue) then
                        applied = applied + 1
                    end
                elseif cvar == "useCompactPartyFrames" then
                    mQoL_RaidProfiles:ApplyUseCompactPartyFrames(value)
                end
            end
        end
    end

    return applied
end

-- Activate Blizzard profile safely
local function ActivateBlizzardProfile()
    if CompactUnitFrameProfiles_ActivateRaidProfile then
        local success = SafeCall(CompactUnitFrameProfiles_ActivateRaidProfile, MQOL_PROFILE_NAME)
        if not success then
            if SetActiveRaidProfile then
                SafeCall(SetActiveRaidProfile, MQOL_PROFILE_NAME)
            end
        end
    elseif SetActiveRaidProfile then
        SafeCall(SetActiveRaidProfile, MQOL_PROFILE_NAME)
        if CompactUnitFrameProfiles_ApplyCurrentSettings then
            SafeCall(CompactUnitFrameProfiles_ApplyCurrentSettings)
        end
    end
    
    -- Ensure frame layout is updated after profile activation
    C_Timer.After(0.05, function()
        if CompactRaidFrameContainer then
            if CompactRaidFrameContainer.TryUpdate then
                SafeCall(CompactRaidFrameContainer.TryUpdate, CompactRaidFrameContainer)
            elseif CompactRaidFrameContainer_TryUpdate then
                SafeCall(CompactRaidFrameContainer_TryUpdate, CompactRaidFrameContainer)
            end
        end
    end)
end

-- Apply saved positions (Classic/Legion only)
local function ApplyPositions(positions)
    if not positions then return end

    C_Timer.After(0.01, function()
        if SetRaidProfileSavedPosition then
            SafeCall(SetRaidProfileSavedPosition, MQOL_PROFILE_NAME,
                positions.isDynamic or false,
                positions.topPoint or "TOP",
                positions.topOffset or 200,
                positions.bottomPoint or "TOP",
                positions.bottomOffset or 400,
                positions.leftPoint or "LEFT",
                positions.leftOffset or 200
            )
            if CompactRaidFrameManager_ResizeFrame_LoadPosition then
                SafeCall(CompactRaidFrameManager_ResizeFrame_LoadPosition, CompactRaidFrameManager)
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

VersionAdapters.ModernClassic = {
    cvars = CVarLists.ModernClassic,
    cvarToOption = nil, -- New Classic/BCC clients uses cvar-backed raid frame settings

    LoadProfile = VersionAdapters.Retail.LoadProfile,
    SaveProfile = VersionAdapters.Retail.SaveProfile,
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
VersionAdapters.Unavailable={cvars={},format='unavailable',LoadProfile=function() return false,'No compatible raid adapter' end,SaveProfile=function() return {} end}
VersionAdapters.AutoOptions={cvars={},format='raid-options-v1',cvarToOption=CvarToOptionMappings.Legion}
VersionAdapters.AutoCVars={cvars={},format='raid-cvars-v1'}
local function AutoRead()
    return mQoL_Auto:GetFeature('RaidProfiles','capture',true)
end
local function AutoSave()
    local r=AutoRead();local values={}
    if not r or r.state~='ready' then return values end
    if r.adapter=='raid-options-v1' then
        for cvar,option in pairs(CvarToOptionMappings.Legion) do
            local value=r.data.values[option]
            if value~=nil then values[cvar]=ConvertValueForSave(value) end
        end
    else for cvar,value in pairs(r.data.values) do values[cvar]=value end end
    if next(values) then
        values._format=r.adapter;values._schema=1
        if r.adapter=='raid-options-v1' and type(GetRaidProfileSavedPosition)=='function' then
            local ok,positions=pcall(SavePositions)
            if ok and positions and type(positions.isDynamic)=='boolean' then values._positions=positions end
        end
    end
    return values
end
local function AutoLoad(saved)
    if not mQoL_Modules:ShouldLoadModule('RaidProfiles') then return false,'Module disabled' end
    local allowed,reason,r=mQoL_Auto:CanUse('RaidProfiles','apply',true)
    if not allowed then return false,reason end
    if mQoL_Compat.InCombat() then
        local controller=mQoL_RaidProfiles
        if not controller.pendingCombatFrame then
            controller.pendingCombatFrame=CreateFrame('Frame')
            controller.pendingCombatFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
            controller.pendingCombatFrame:SetScript('OnEvent',function()
                if controller.pendingProfileUpdate then
                    controller.pendingProfileUpdate=nil
                    if mQoL_Modules:ShouldLoadModule('RaidProfiles') then controller:UpdateCurrentProfile(true) end
                end
            end)
        end
        controller.pendingProfileUpdate=true
        return false,'Deferred until combat ends'
    end
    if saved._format and (saved._format~=r.adapter or saved._schema~=1) then return false,'Incompatible saved raid profile format' end
    local operations={}
    for key,value in pairs(saved) do
        if type(key)=='string' and key:sub(1,1)~='_' then
            local option=r.adapter=='raid-options-v1' and CvarToOptionMappings.Legion[key] or key
            if option and r.data.values[option]~=nil then
                if type(value)~='string' and type(value)~='boolean' and not mQoL_Compat.Number(value) then return false,'Invalid profile value: '..key end
                operations[#operations+1]={key=key,option=option,value=value}
            end
        end
    end
    if #operations==0 then return false,'Profile has no supported options' end
    local positions=saved._positions
    if positions then
        local positionOK,positionReason=mQoL_Auto:CanUse('RaidProfiles','positions',true)
        if not positionOK then return false,positionReason end
        if type(positions)~='table' or type(positions.isDynamic)~='boolean' then return false,'Invalid saved position format' end
        if not positions.isDynamic then
            local points={TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
            for _,key in ipairs({'topPoint','bottomPoint','leftPoint'}) do if not points[positions[key]] then return false,'Invalid saved anchor' end end
            for _,key in ipairs({'topOffset','bottomOffset','leftOffset'}) do if not mQoL_Compat.Number(positions[key]) then return false,'Invalid saved offset' end end
        end
    end
    if r.adapter=='raid-options-v1' then
        local ok,exists=mQoL_Compat.Read('RaidProfileExists',MQOL_PROFILE_NAME)
        if not ok then return false,exists end
        if not exists then
            local countOK,count=mQoL_Compat.Read('GetNumRaidProfiles')
            local maxOK,max=mQoL_Compat.Read('GetMaxNumRaidProfiles')
            if not countOK or not maxOK or not mQoL_Compat.Number(count) or not mQoL_Compat.Number(max) or count>=max then return false,'Raid profile limit unavailable or reached' end
            local created,err=mQoL_Compat.Write('CreateNewRaidProfile',MQOL_PROFILE_NAME)
            if not created then return false,err end
            local verified,present=mQoL_Compat.Read('RaidProfileExists',MQOL_PROFILE_NAME)
            if not verified or not present then return false,'Raid profile creation was not confirmed' end
        end
        for _,operation in ipairs(operations) do
            local value=ConvertValueForLoad(operation.value)
            local ok,err=mQoL_Compat.Write('SetRaidProfileOption',MQOL_PROFILE_NAME,operation.option,value)
            if not ok then return false,err end
            local read,actual=mQoL_Compat.Read('GetRaidProfileOption',MQOL_PROFILE_NAME,operation.option)
            if not read or ConvertValueForSave(actual)~=ConvertValueForSave(value) then return false,'Raid option readback failed: '..operation.option end
        end
        local ok,err=mQoL_Compat.Write('SetActiveRaidProfile',MQOL_PROFILE_NAME)
        if not ok then return false,err end
        if positions then
            ok,err=mQoL_Compat.Write('SetRaidProfileSavedPosition',MQOL_PROFILE_NAME,positions.isDynamic,positions.topPoint,positions.topOffset,positions.bottomPoint,positions.bottomOffset,positions.leftPoint,positions.leftOffset)
            if not ok then return false,err end
            local read,dynamic,top,topOffset,bottom,bottomOffset,left,leftOffset=mQoL_Compat.Read('GetRaidProfileSavedPosition',MQOL_PROFILE_NAME)
            if not read or dynamic~=positions.isDynamic then return false,'Saved position readback failed' end
            if not dynamic and (top~=positions.topPoint or topOffset~=positions.topOffset or bottom~=positions.bottomPoint or bottomOffset~=positions.bottomOffset or left~=positions.leftPoint or leftOffset~=positions.leftOffset) then return false,'Saved position readback failed' end
            ok,err=mQoL_Compat.Write('CompactRaidFrameManager_ResizeFrame_LoadPosition',CompactRaidFrameManager)
            if not ok then return false,err end
        end
        ok,err=mQoL_Compat.Write('CompactUnitFrameProfiles_ApplyCurrentSettings')
        if not ok then return false,err end
        local read,active=mQoL_Compat.Read('GetActiveRaidProfile')
        return read and active==MQOL_PROFILE_NAME,'Raid profile activation must be confirmed'
    end
    for _,operation in ipairs(operations) do
        local ok,err=mQoL_CVar:Apply(operation.key,operation.value)
        if not ok then return false,err end
    end
    return true
end
VersionAdapters.AutoOptions.SaveProfile,VersionAdapters.AutoCVars.SaveProfile=AutoSave,AutoSave
VersionAdapters.AutoOptions.LoadProfile,VersionAdapters.AutoCVars.LoadProfile=AutoLoad,AutoLoad
function VersionAdapters:GetCurrent()
    if mQoL_Auto then
        local r=AutoRead()
        if not r or r.state~='ready' then return self.Unavailable end
        local adapter=r.adapter=='raid-options-v1' and self.AutoOptions or self.AutoCVars
        adapter.cvars={}
        if r.adapter=='raid-options-v1' then
            for cvar,option in pairs(CvarToOptionMappings.Legion) do if r.data.values[option]~=nil then adapter.cvars[#adapter.cvars+1]=cvar end end
        else for cvar in pairs(r.data.values) do adapter.cvars[#adapter.cvars+1]=cvar end end
        table.sort(adapter.cvars);return adapter
    end
    if clientInfo.isBCC or clientInfo.isTBC or clientInfo.isClassic or clientInfo.isMoP then
        return self.ModernClassic
    elseif clientInfo.isEra or clientInfo.isVanilla then
        return self.Classic
    elseif clientInfo.isLegion then
        return self.Legion
    elseif clientInfo.isRetail then
        return self.Retail
    end
    return self.Unavailable
end

-- Get CVars for current version
function VersionAdapters:GetCVars()
    return self:GetCurrent().cvars
end

-- Load profile using appropriate adapter
function VersionAdapters:LoadProfile(savedCVars, profileName)
    local adapter = self:GetCurrent()
    if not mQoL_Auto and savedCVars._format then
        local format=(adapter==self.Classic or adapter==self.Legion) and 'raid-options-v1' or 'raid-cvars-v1'
        if savedCVars._format~=format or savedCVars._schema~=1 then return false,'Incompatible saved raid profile format' end
        local plain={}
        for key,value in pairs(savedCVars) do if key=='_positions' or (type(key)=='string' and key:sub(1,1)~='_') then plain[key]=value end end
        savedCVars=plain
    end
    return adapter.LoadProfile(savedCVars, profileName)
end

-- Save profile using appropriate adapter
function VersionAdapters:SaveProfile()
    local adapter = self:GetCurrent()
    return adapter.SaveProfile(adapter.cvars)
end
