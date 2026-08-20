local addonName = ...

mQoL_Nameplates = mQoL_Nameplates or mQoL_NameplatesQoL or {}
mQoL_NameplatesQoL = mQoL_Nameplates -- Legacy API alias

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

function mQoL_NameplatesQoL:InitializeDB()
    mQoL_DB = mQoL_DB or {}
    mQoL_DB.NameplatesQoL = mQoL_DB.NameplatesQoL or {}

    local db = mQoL_DB.NameplatesQoL
    if type(db.settings) ~= "table" then
        local legacySettings = mQoL_DB.MainQoL
            and mQoL_DB.MainQoL.settings
            and mQoL_DB.MainQoL.settings.nameplates
        db.settings = CopySettings(legacySettings)
    end

    self.db = db
end

function mQoL_NameplatesQoL:CaptureCurrentSettings()
    if not self.db or type(self.db.settings) ~= "table" then return end
    local settings = self.db.settings

    local function SetMissing(key, value)
        if settings[key] == nil and value ~= nil then
            settings[key] = value
        end
    end

    SetMissing("showEnemyNameplates", mQoL_CVar:ReadBoolean("nameplateShowEnemies"))
    SetMissing("showEnemyMinions", mQoL_CVar:ReadBoolean("nameplateShowEnemyMinions"))
    SetMissing("showEnemyPets", mQoL_CVar:ReadBoolean("nameplateShowEnemyPets"))
    SetMissing("showEnemyGuardians", mQoL_CVar:ReadBoolean("nameplateShowEnemyGuardians"))
    SetMissing("showEnemyTotems", mQoL_CVar:ReadBoolean("nameplateShowEnemyTotems"))
    SetMissing("showEnemyMinus", mQoL_CVar:ReadBoolean("nameplateShowEnemyMinus"))
    SetMissing("separateEnemyMinions", false)

    if clientInfo.isRetail then
        SetMissing("showFriendlyPlayers", mQoL_CVar:ReadBoolean("nameplateShowFriendlyPlayers"))
        SetMissing("showFriendlyPlayerMinions", mQoL_CVar:ReadBoolean("nameplateShowFriendlyPlayerMinions"))
        SetMissing("showFriendlyNpcs", mQoL_CVar:ReadBoolean("nameplateShowFriendlyNpcs"))
        SetMissing("showFriendlyPets", mQoL_CVar:ReadBoolean("nameplateShowFriendlyPlayerPets"))
        SetMissing("showFriendlyGuardians", mQoL_CVar:ReadBoolean("nameplateShowFriendlyPlayerGuardians"))
        SetMissing("showFriendlyTotems", mQoL_CVar:ReadBoolean("nameplateShowFriendlyPlayerTotems"))
    else
        SetMissing("showFriendlyNameplates", mQoL_CVar:ReadBoolean("nameplateShowFriends"))
        SetMissing("showFriendlyMinions", mQoL_CVar:ReadBoolean("nameplateShowFriendlyMinions"))
        SetMissing("showFriendlyNpcs", mQoL_CVar:ReadBoolean("nameplateShowFriendlyNPCs"))
        SetMissing("showFriendlyPets", mQoL_CVar:ReadBoolean("nameplateShowFriendlyPets"))
        SetMissing("showFriendlyGuardians", mQoL_CVar:ReadBoolean("nameplateShowFriendlyGuardians"))
        SetMissing("showFriendlyTotems", mQoL_CVar:ReadBoolean("nameplateShowFriendlyTotems"))
    end

    SetMissing("separateMinions", false)
    SetMissing("nameplateMaxDistance", mQoL_CVar:ReadNumber("nameplateMaxDistance"))
end

function mQoL_NameplatesQoL:ApplySettings(np)
    if not np then return end
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("NameplatesQoL") then return end

    local function apply_showEnemyNameplates(value)
        mQoL_CVar:Apply("nameplateShowEnemies", value)
    end

    -- Retail: Enemy minion CVars
    local function apply_showEnemyMinions(value)
        mQoL_CVar:Apply("nameplateShowEnemyMinions", value)
    end

    local function apply_showEnemyPets(value)
        mQoL_CVar:Apply("nameplateShowEnemyPets", value)
    end

    local function apply_showEnemyGuardians(value)
        mQoL_CVar:Apply("nameplateShowEnemyGuardians", value)
    end

    local function apply_showEnemyTotems(value)
        mQoL_CVar:Apply("nameplateShowEnemyTotems", value)
    end

    local function apply_showEnemyMinus(value)
        mQoL_CVar:Apply("nameplateShowEnemyMinus", value)
    end

    -- Non-retail: single friendly nameplates CVar
    local function apply_showFriendlyNameplates(value)
        mQoL_CVar:Apply("nameplateShowFriends", value)
    end

    -- Retail 12.0.0+: split friendly nameplates CVars
    local function apply_showFriendlyPlayers(value)
        mQoL_CVar:Apply("nameplateShowFriendlyPlayers", value)
    end

    local function apply_showFriendlyPlayerMinions(value)
        mQoL_CVar:Apply("nameplateShowFriendlyPlayerMinions", value)
    end

    local function apply_showFriendlyNpcs(value)
        mQoL_CVar:Apply("nameplateShowFriendlyNpcs", value)
    end

    -- Retail: separate friendly minion type CVars
    local function apply_showFriendlyPets(value)
        mQoL_CVar:Apply("nameplateShowFriendlyPlayerPets", value)
    end

    local function apply_showFriendlyGuardians(value)
        mQoL_CVar:Apply("nameplateShowFriendlyPlayerGuardians", value)
    end

    local function apply_showFriendlyTotems(value)
        mQoL_CVar:Apply("nameplateShowFriendlyPlayerTotems", value)
    end

    local function apply_nameplateShowAll(np)
        if not np then return end

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
        mQoL_CVar:Apply("nameplateMaxDistance", value)
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
            mQoL_CVar:Apply("nameplateShowEnemyPets", np.showEnemyPets)
            mQoL_CVar:Apply("nameplateShowEnemyGuardians", np.showEnemyGuardians)
            mQoL_CVar:Apply("nameplateShowEnemyTotems", np.showEnemyTotems)
            mQoL_CVar:Apply("nameplateShowEnemyMinus", np.showEnemyMinus)
        else
            -- Force sync to master
            local val = np.showEnemyMinions
            mQoL_CVar:Apply("nameplateShowEnemyMinions", val)
            mQoL_CVar:Apply("nameplateShowEnemyPets", val)
            mQoL_CVar:Apply("nameplateShowEnemyGuardians", val)
            mQoL_CVar:Apply("nameplateShowEnemyTotems", val)
            mQoL_CVar:Apply("nameplateShowEnemyMinus", val)
        end

        mQoL_CVar:Apply("nameplateShowFriends", np.showFriendlyNameplates)
        mQoL_CVar:Apply("nameplateShowFriendlyNPCs", np.showFriendlyNpcs)

        if np.separateMinions then
            mQoL_CVar:Apply("nameplateShowFriendlyPets", np.showFriendlyPets)
            mQoL_CVar:Apply("nameplateShowFriendlyGuardians", np.showFriendlyGuardians)
            mQoL_CVar:Apply("nameplateShowFriendlyTotems", np.showFriendlyTotems)
        else
            -- Force sync to master
            local val = np.showFriendlyMinions
            mQoL_CVar:Apply("nameplateShowFriendlyMinions", val)
            mQoL_CVar:Apply("nameplateShowFriendlyPets", val)
            mQoL_CVar:Apply("nameplateShowFriendlyGuardians", val)
            mQoL_CVar:Apply("nameplateShowFriendlyTotems", val)
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
            mQoL_CVar:Apply("nameplateShowEnemyMinions", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyPets = function(value)
            np.showEnemyPets = value
            mQoL_CVar:Apply("nameplateShowEnemyPets", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyGuardians = function(value)
            np.showEnemyGuardians = value
            mQoL_CVar:Apply("nameplateShowEnemyGuardians", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyTotems = function(value)
            np.showEnemyTotems = value
            mQoL_CVar:Apply("nameplateShowEnemyTotems", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showEnemyMinus = function(value)
            np.showEnemyMinus = value
            mQoL_CVar:Apply("nameplateShowEnemyMinus", value)
            apply_nameplateShowAll(np)
        end

        -- Friendly appliers
        self.ApplySetting.Nameplates.showFriendlyNameplates = function(value)
            np.showFriendlyNameplates = value
            mQoL_CVar:Apply("nameplateShowFriends", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyNpcs = function(value)
            np.showFriendlyNpcs = value
            mQoL_CVar:Apply("nameplateShowFriendlyNPCs", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyMinions = function(value)
            np.showFriendlyMinions = value
            mQoL_CVar:Apply("nameplateShowFriendlyMinions", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyPets = function(value)
            np.showFriendlyPets = value
            mQoL_CVar:Apply("nameplateShowFriendlyPets", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyGuardians = function(value)
            np.showFriendlyGuardians = value
            mQoL_CVar:Apply("nameplateShowFriendlyGuardians", value)
            apply_nameplateShowAll(np)
        end
        self.ApplySetting.Nameplates.showFriendlyTotems = function(value)
            np.showFriendlyTotems = value
            mQoL_CVar:Apply("nameplateShowFriendlyTotems", value)
            apply_nameplateShowAll(np)
        end
    end
    SyncMainFacade()
end

-- This is replacement for bugged blizzard CVAR in 7.3.5

function mQoL_NameplatesQoL:CreatePanel(parent)
    local s = self.db.settings

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Nameplates Quality of Life Settings", {
        text = "How Nameplates QoL works?",
        textColor = {1, 0.82, 0},
        explanation = "Customize the visibility and behavior of nameplates.\n\n- Customize visibility of nameplates for different unit types for both enemy and friendly nameplates.\n- Customize nameplates view distance within the range supported by the client.\n- Settings can be Disabled to prevent the addon from modifying them.",
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
            { text = "Show", value = true, onSelect = function() s.showEnemyNameplates = true; mQoL_NameplatesQoL:ApplySettings(s) end },
            { text = "Hide", value = false, onSelect = function() s.showEnemyNameplates = false; mQoL_NameplatesQoL:ApplySettings(s) end },
            { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyNameplates = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                    mQoL_NameplatesQoL:ApplySettings(s)
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
                    mQoL_NameplatesQoL:ApplySettings(s)
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
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateEnemyMinions = true
                    mQoL_NameplatesQoL:ApplySettings(s)
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
                    { text = "Show", value = true, onSelect = function() s.showEnemyPets = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyPets = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyPets = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyGuardians = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyGuardians = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyGuardians = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyTotems = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyTotems = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyTotems = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyTotems)
            })
            AddGap(contentContainer, "Standard")

            contentContainer.nextIsSeparator = true
            AddOptionRow("      Minor Enemies", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyMinus = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyMinus = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyMinus = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                { text = "Show", value = true, onSelect = function() s.showFriendlyPlayers = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyPlayers = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyPlayers = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showFriendlyPlayerMinions = false
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = false
                    s.showFriendlyGuardians = false
                    s.showFriendlyTotems = false
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showFriendlyPlayerMinions = DISABLE
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = DISABLE
                    s.showFriendlyGuardians = DISABLE
                    s.showFriendlyTotems = DISABLE
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateMinions = true
                    mQoL_NameplatesQoL:ApplySettings(s)
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
                    { text = "Show", value = true, onSelect = function() s.showFriendlyPets = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyPets = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyPets = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyGuardians = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyGuardians = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyGuardians = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyTotems = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyTotems = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyTotems = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyTotems)
            })
            AddGap(contentContainer, "Standard")
        end

        contentContainer.nextIsSeparator = true
        AddOptionRow("Friendly NPCs Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyNpcs = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNpcs = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNpcs = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                    mQoL_NameplatesQoL:ApplySettings(s)
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
                    mQoL_NameplatesQoL:ApplySettings(s)
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
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateEnemyMinions = true
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateEnemyMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showEnemyMinions)
        })
        AddGap(contentContainer, "Standard")

        if s.separateEnemyMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyPets = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyPets = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyPets = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyGuardians = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyGuardians = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyGuardians = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyTotems = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyTotems = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyTotems = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyTotems)
            })
            AddGap(contentContainer, "Standard")

            contentContainer.nextIsSeparator = true
            AddOptionRow("      Minor Enemies", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyMinus = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyMinus = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyMinus = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                { text = "Show", value = true, onSelect = function() s.showFriendlyNameplates = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNameplates = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNameplates = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showFriendlyMinions = false
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = false
                    s.showFriendlyGuardians = false
                    s.showFriendlyTotems = false
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showFriendlyMinions = DISABLE
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = DISABLE
                    s.showFriendlyGuardians = DISABLE
                    s.showFriendlyTotems = DISABLE
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateMinions = true
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showFriendlyMinions)
        })
        AddGap(contentContainer, "Standard")

        if s.separateMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyPets = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyPets = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyPets = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyGuardians = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyGuardians = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyGuardians = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyTotems = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyTotems = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyTotems = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                    mQoL_NameplatesQoL:ApplySettings(s)
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
                    mQoL_NameplatesQoL:ApplySettings(s)
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
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateEnemyMinions = true
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateEnemyMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showEnemyMinions)
        })
        AddGap(contentContainer, "Standard")

        if s.separateEnemyMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyPets = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyPets = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyPets = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyGuardians = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyGuardians = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyGuardians = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyTotems = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyTotems = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyTotems = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyTotems)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Minor Enemies", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showEnemyMinus = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showEnemyMinus = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showEnemyMinus = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showEnemyMinus)
            })
            AddGap(contentContainer, "Standard")
        end

        AddGap(contentContainer, "BottomSeparator")

        AddOptionRow("Friendly Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyNameplates = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNameplates = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNameplates = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showFriendlyNameplates)
        })
        AddGap(contentContainer, "Standard")

        AddOptionRow("Friendly NPCs Nameplates", "dropdown", {
            list = {
                { text = "Show", value = true, onSelect = function() s.showFriendlyNpcs = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNpcs = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNpcs = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Hide All", value = false, onSelect = function() 
                    s.showFriendlyMinions = false
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = false
                    s.showFriendlyGuardians = false
                    s.showFriendlyTotems = false
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Disable", value = DISABLE, onSelect = function() 
                    s.showFriendlyMinions = DISABLE
                    s.separateMinions = false
                    -- Sync separate settings
                    s.showFriendlyPets = DISABLE
                    s.showFriendlyGuardians = DISABLE
                    s.showFriendlyTotems = DISABLE
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
                { text = "Separate Each Type", value = "separate", onSelect = function() 
                    s.separateMinions = true
                    mQoL_NameplatesQoL:ApplySettings(s)
                    mQoL_Hub:RefreshCurrentPanel()
                end },
            },
            value = s.separateMinions and "separate" or mQoL_Hub.NormalizeTriState(s.showFriendlyMinions)
        })
        AddGap(contentContainer, "Standard")

        if s.separateMinions then
            AddOptionRow("      Pets", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyPets = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyPets = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyPets = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyPets)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Guardians", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyGuardians = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyGuardians = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyGuardians = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
                },
                value = mQoL_Hub.NormalizeTriState(s.showFriendlyGuardians)
            })
            AddGap(contentContainer, "Standard")

            AddOptionRow("      Totems", "dropdown", {
                list = {
                    { text = "Show", value = true, onSelect = function() s.showFriendlyTotems = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Hide", value = false, onSelect = function() s.showFriendlyTotems = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                    { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyTotems = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
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
                { text = "Show", value = true, onSelect = function() s.showFriendlyNameplates = true; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Hide", value = false, onSelect = function() s.showFriendlyNameplates = false; mQoL_NameplatesQoL:ApplySettings(s) end },
                { text = "Disable", value = DISABLE, onSelect = function() s.showFriendlyNameplates = DISABLE; mQoL_NameplatesQoL:ApplySettings(s) end },
            },
            value = mQoL_Hub.NormalizeTriState(s.showFriendlyNameplates)
        })
        AddGap(contentContainer, "Standard")
    end

    -- Max Nameplate Distance
    local distances = {20, 40, 60}
    if clientInfo.isClassic then distances = {21, 41} end
    if clientInfo.isBCC then distances = {21, 41} end
    if clientInfo.isEra then distances = {21, 41} end
    if clientInfo.isLegion then distances = {20, 40, 60, 80, 100} end

    local distanceItems = {}
    for _, val in ipairs(distances) do
        table.insert(distanceItems, {
            text = tostring(val),
            value = val,
            onSelect = function() 
                s.nameplateMaxDistance = val
                mQoL_NameplatesQoL:ApplySettings(s)
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

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == addonName then
        mQoL_NameplatesQoL:InitializeDB()
        if mQoL_Modules:ShouldLoadModule("NameplatesQoL") then
            mQoL_NameplatesQoL:CaptureCurrentSettings()
        end

        if IsLoggedIn() then
            C_Timer.After(0, function()
                mQoL_NameplatesQoL:ApplySettings(mQoL_NameplatesQoL.db.settings)
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        if not mQoL_NameplatesQoL.db then
            mQoL_NameplatesQoL:InitializeDB()
        end
        if mQoL_Modules:ShouldLoadModule("NameplatesQoL") then
            mQoL_NameplatesQoL:CaptureCurrentSettings()
        end

        C_Timer.After(0.5, function()
            mQoL_NameplatesQoL:ApplySettings(mQoL_NameplatesQoL.db.settings)
        end)

        if mQoL_Hub and mQoL_Hub.RegisterModuleOptions
            and mQoL_Modules:ShouldLoadModule("NameplatesQoL") then
            mQoL_Hub:RegisterModuleOptions("mQoL_NameplatesQoL", "Nameplates", function(parent)
                return mQoL_NameplatesQoL:CreatePanel(parent)
            end)
        end
    end
end)
