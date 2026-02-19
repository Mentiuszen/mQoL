local addonName = "mQoL"
local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}

-- Namespace (already created by VersionAdapters)
mQoL_RaidProfiles = mQoL_RaidProfiles or {}
local ProfileManager = {}
mQoL_RaidProfiles.ProfileManager = ProfileManager

-- Situational mode key constant
local SITUATIONAL_MODE_KEY = "Use Situational Instead"
mQoL_RaidProfiles.SITUATIONAL_MODE_KEY = SITUATIONAL_MODE_KEY

-- Defaults
mQoL_RaidProfiles.defaults = {
    forcedRaidProfile = "", 
    raidProfileMode = "Disabled",
    raidProfiles = {}, -- [ProfileName] = {cvar=value, ...}
    -- Advanced Mode Data
    advancedClassProfiles = {}, -- [Class] = ProfileName
    advancedSpecProfiles = {},   -- [SpecID] = ProfileName
    advancedViewMode = "Class",  -- UI State: "Class" or "Spec"
    advancedSituational = {},    -- [ID] = {Party="", Raid="", Arena="", Battleground=""}
    -- Simple Mode Data
    simpleSituational = false,
    simpleSituationalProfiles = {
        Party = "",
        Raid = "",
        Arena = "",
        Battleground = ""
    }
}

-- Ensure global DB exists
mQoL_RaidProfiles_DB = mQoL_RaidProfiles_DB or {}

-- Deep copy helper
local function TableCopy(src)
    local dest = {}
    for k, v in pairs(src) do
        if type(v) == "table" then dest[k] = TableCopy(v) else dest[k] = v end
    end
    return dest
end

-- Get player's database (handles migration from old format)
local function GetPlayerRaidProfilesDB()
    mQoL_RaidProfiles_DB = mQoL_RaidProfiles_DB or {}

    -- Ensure Account exists
    if not mQoL_RaidProfiles_DB["Account"] then
        mQoL_RaidProfiles_DB["Account"] = TableCopy(mQoL_RaidProfiles.defaults)
    end

    local accountDB = mQoL_RaidProfiles_DB["Account"]

    -- Migration: Merge all other keys into Account (was bugged in test versions)
    local keysToRemove = {}
    for key, data in pairs(mQoL_RaidProfiles_DB) do
        if key ~= "Account" then
            -- Merge Raid Profiles
            if data.raidProfiles then
                for profileName, profileData in pairs(data.raidProfiles) do
                    if not accountDB.raidProfiles[profileName] then
                        accountDB.raidProfiles[profileName] = profileData
                    end
                end
            end
            table.insert(keysToRemove, key)
        end
    end

    -- Cleanup migrated keys
    for _, key in ipairs(keysToRemove) do
        mQoL_RaidProfiles_DB[key] = nil
        print(addonName .. ": Migrated data from '" .. key .. "' to Account.")
    end

    return mQoL_RaidProfiles_DB["Account"]
end

-- Initialize database
function mQoL_RaidProfiles:InitializeDB()
    self.db = { settings = GetPlayerRaidProfilesDB() }

    -- Ensure structure exists
    if not self.db.settings.raidProfiles then
        self.db.settings.raidProfiles = {}
    end
    if not self.db.settings.advancedSituational then
        self.db.settings.advancedSituational = {}
    end
end

-- Combat lockdown handling
local function SetupCombatEventFrame()
    if mQoL_RaidProfiles.combatEventFrame then return end

    mQoL_RaidProfiles.combatEventFrame = CreateFrame("Frame")
    mQoL_RaidProfiles.combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    mQoL_RaidProfiles.combatEventFrame:SetScript("OnEvent", function()
        if mQoL_RaidProfiles.pendingProfileLoad then
            local pending = mQoL_RaidProfiles.pendingProfileLoad
            mQoL_RaidProfiles.pendingProfileLoad = nil
            mQoL_RaidProfiles:LoadRaidProfile(pending)
            -- Trigger frame layout refresh after profile load to ensure proper positioning
            C_Timer.After(0.1, function()
                if CompactRaidFrameContainer then
                    if CompactRaidFrameContainer.TryUpdate then
                        CompactRaidFrameContainer:TryUpdate()
                    elseif CompactRaidFrameContainer_TryUpdate then
                        CompactRaidFrameContainer_TryUpdate(CompactRaidFrameContainer)
                    end
                end
            end)
        end
    end)
end

-- Load a raid profile
function mQoL_RaidProfiles:LoadRaidProfile(profileName)
    if not profileName or profileName == "" then return end

    -- Handle combat lockdown
    if InCombatLockdown() then
        self.pendingProfileLoad = profileName
        SetupCombatEventFrame()
        print(addonName .. ": In combat - profile '" .. profileName .. "' will be applied after combat.")
        return
    end

    -- Get saved data
    local savedCVars = self.db.settings.raidProfiles and self.db.settings.raidProfiles[profileName]
    if not savedCVars or type(savedCVars) ~= "table" then
        print(addonName .. ": Raid Profile '" .. profileName .. "' not found or invalid.")
        return
    end

    -- Use version adapter to load
    local Adapters = self.VersionAdapters
    Adapters:LoadProfile(savedCVars, profileName)
end

function mQoL_RaidProfiles:SaveRaidProfile(name)
    local Adapters = self.VersionAdapters
    local cvarData = Adapters:SaveProfile()

    self.db.settings.raidProfiles[name] = cvarData
    print(addonName .. ": Saved Raid Profile '" .. name .. "' to mQoL Storage.")

    if self.RefreshSavedProfiles then
        self.RefreshSavedProfiles()
    end
end

function mQoL_RaidProfiles:RenameProfile(oldName, newName)
    if not oldName or not newName or oldName == newName then return end

    local s = self.db.settings
    if not s.raidProfiles or not s.raidProfiles[oldName] then return end

    -- 1. Copy data to new profile
    s.raidProfiles[newName] = s.raidProfiles[oldName]

    -- 2. Delete old profile
    s.raidProfiles[oldName] = nil

    -- 3. Update references
    if s.forcedRaidProfile == oldName then
        s.forcedRaidProfile = newName
    end

    if s.simpleSituationalProfiles then
        for k, v in pairs(s.simpleSituationalProfiles) do
            if v == oldName then s.simpleSituationalProfiles[k] = newName end
        end
    end

    if s.advancedClassProfiles then
        for k, v in pairs(s.advancedClassProfiles) do
            if v == oldName then s.advancedClassProfiles[k] = newName end
        end
    end

    if s.advancedSpecProfiles then
        for k, v in pairs(s.advancedSpecProfiles) do
            if v == oldName then s.advancedSpecProfiles[k] = newName end
        end
    end

    if s.advancedSituational then
        for k, situTable in pairs(s.advancedSituational) do
            for sit, v in pairs(situTable) do
                if v == oldName then situTable[sit] = newName end
            end
        end
    end

    print(addonName .. ": Renamed profile '" .. oldName .. "' to '" .. newName .. "'.")

    if self.RefreshSavedProfiles then
        self.RefreshSavedProfiles()
    end
end

function mQoL_RaidProfiles:GetFramePosition(frame)
    if not frame then return nil end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    if not point then return nil end

    local relativeToName = nil
    if relativeTo then
        relativeToName = relativeTo:GetName()
        if not relativeToName then
            return nil 
        end
    else
        relativeToName = "UIParent"
    end

    return {
        point = point,
        relativeTo = relativeToName,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end

function mQoL_RaidProfiles:SetFramePosition(frame, pos)
    if not frame or not pos then return end
    if InCombatLockdown() then return end

    frame:ClearAllPoints()
    local relativeTo = _G[pos.relativeTo] or UIParent
    frame:SetPoint(pos.point, relativeTo, pos.relativePoint, pos.x, pos.y)
end

function mQoL_RaidProfiles:GetCurrentSituation()
    local inInstance, instanceType = IsInInstance()

    if instanceType == "arena" then return "Arena" end
    if instanceType == "pvp" then return "Battleground" end

    if IsInRaid() then return "Raid"
    elseif IsInGroup() then return "Party" end

    return nil
end

-- Get player's current spec ID (works across all versions)
local function GetPlayerSpecID()
    local getSpecIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not getSpecIndex or not getSpecInfo then return nil end
    local specIndex = getSpecIndex()
    if not specIndex then return nil end
    local specID = getSpecInfo(specIndex)
    if specID and specID ~= 0 then return specID end
    return nil
end

function mQoL_RaidProfiles:UpdateCurrentProfile(immediate)
    if self.updateTimer then self.updateTimer:Cancel() end

    local function Update()
        local s = self.db.settings
        local profileToLoad = nil
        local mode = s.raidProfileMode or "Simple"
        local situation = self:GetCurrentSituation()

        if mode == "Simple" then
            if s.forcedRaidProfile == SITUATIONAL_MODE_KEY and situation then
                local sitProfile = s.simpleSituationalProfiles and s.simpleSituationalProfiles[situation]
                if sitProfile and sitProfile ~= "" then
                    profileToLoad = sitProfile
                end
            end

            if not profileToLoad and s.forcedRaidProfile and s.forcedRaidProfile ~= "" and s.forcedRaidProfile ~= SITUATIONAL_MODE_KEY then
                profileToLoad = s.forcedRaidProfile
            end

        elseif mode == "Advanced" then
            local _, classFile = UnitClass("player")
            local specID
            if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC or clientInfo.isLegion then
                specID = GetPlayerSpecID()
            end

            local specProfile = specID and s.advancedSpecProfiles and s.advancedSpecProfiles[specID]
            local classProfile = classFile and s.advancedClassProfiles and s.advancedClassProfiles[classFile]

            if situation and s.advancedSituational then
                if specID and s.advancedSituational[specID] then
                    local sitProfile = s.advancedSituational[specID][situation]
                    if sitProfile and sitProfile ~= "" then
                        profileToLoad = sitProfile
                    end
                end
                if not profileToLoad and classFile and s.advancedSituational[classFile] then
                    local sitProfile = s.advancedSituational[classFile][situation]
                    if sitProfile and sitProfile ~= "" then
                        profileToLoad = sitProfile
                    end
                end
            end

            if not profileToLoad then
                profileToLoad = specProfile or classProfile
            end
        end

        if profileToLoad then
            self:LoadRaidProfile(profileToLoad)
        end
    end

    if immediate then
        Update()
    else
        self.updateTimer = C_Timer.NewTimer(0.5, Update)
    end
end

function mQoL_RaidProfiles:IsSituationalModeEnabled()
    local s = self.db and self.db.settings
    if not s then return false end

    local mode = s.raidProfileMode or "Simple"

    if mode == "Simple" then
        return (s.forcedRaidProfile == SITUATIONAL_MODE_KEY)
    elseif mode == "Advanced" then
        return true
    end

    return false
end