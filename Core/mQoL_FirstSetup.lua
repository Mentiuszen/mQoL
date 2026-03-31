local addonName, L = ...

-- Initialize safety flag
mQoL_DB = mQoL_DB or {}
if mQoL_DB.firstSetupDone == nil then
    mQoL_DB.firstSetupDone = false
end

-- Check if Hub is Available
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
    return
end

-- Check Client Version
local clientInfo = mQoL_VersionDetection.clientInfo

-- Get client version key
local function GetClientVersion()
    if clientInfo.isRetail then return "Retail" end
    if clientInfo.isLegion then return "Legion" end
    if clientInfo.isClassic then return "Classic" end
    if clientInfo.isEra then return "Era" end
    if clientInfo.isBCC then return "BCC" end
    if clientInfo.isPandaria then return "Pandaria" end
    return "Retail"
end

-- Default settings per client version
local defaultSettingsMap = {
    Retail = {
        general = { showMyName=true, autoLoot=true, autoLootRate=100, autoQuestTracking=true, showLuaErrors=false },
        nameplates = {
            showEnemyNameplates=true, showEnemyMinions=true, separateEnemyMinions=false, showEnemyPets=true, showEnemyGuardians=true, showEnemyTotems=true, showEnemyMinus=true,
            showFriendlyPlayers=false, showFriendlyPlayerMinions=false, separateMinions=false, showFriendlyPets=false, showFriendlyGuardians=false, showFriendlyTotems=false, showFriendlyNpcs=false,
            nameplateMaxDistance=60
        },
        actionBars = { alwaysShowActionBars=true, autoPushSpellToActionBar=false, autoSelfCast=true, showActionBars2=true, showActionBars3=true, showActionBars4=true, showActionBars5=true, showActionBars6=true, showActionBars7=false, showActionBars8=false },
    },
    Legion = {
        general = { showMyName=true, autoLoot=true, autoLootRate=100, autoQuestTracking=true, showLuaErrors=false },
        nameplates = {
            showEnemyNameplates=true, showEnemyMinions=true, separateEnemyMinions=false, showEnemyPets=true, showEnemyGuardians=true, showEnemyTotems=true, showEnemyMinus=true,
            showFriendlyNameplates=false, showFriendlyMinions=false, separateMinions=false, showFriendlyPets=false, showFriendlyGuardians=false, showFriendlyTotems=false,
            nameplateMaxDistance=60
        },
        actionBars = { alwaysShowActionBars=true, autoPushSpellToActionBar=false, autoSelfCast=true, showActionBars2=true, showActionBars3=true, showActionBars4=true, showActionBars5=true },
    },
    Classic = {
        general = { showMyName=true, autoLoot=true, autoLootRate=100, autoQuestTracking=true, showLuaErrors=false, showHead=true, showCloak=true },
        nameplates = {
            showEnemyNameplates=true, showEnemyMinions=true, showEnemyMinus=true,
            showFriendlyNameplates=false, showFriendlyMinions=false,
            nameplateMaxDistance=41
        },
        actionBars = { alwaysShowActionBars=true, autoPushSpellToActionBar=false, autoSelfCast=true, showActionBars2=true, showActionBars3=true, showActionBars4=true, showActionBars5=true },
    },
    Era = {
        general = { showMyName=true, autoLoot=true, autoLootRate=100, autoQuestTracking=true, showLuaErrors=false, showHead=true, showCloak=true },
        nameplates = {
            showEnemyNameplates=true, showEnemyMinions=true, showEnemyMinus=true,
            showFriendlyNameplates=false, showFriendlyMinions=false,
            nameplateMaxDistance=20
        },
        actionBars = { alwaysShowActionBars=true, autoPushSpellToActionBar=false, autoSelfCast=true, showActionBars2=true, showActionBars3=true, showActionBars4=true, showActionBars5=true },
    },
    BCC = {
        general = { showMyName=true, autoLoot=true, autoLootRate=100, autoQuestTracking=true, showLuaErrors=false, showHead=true, showCloak=true },
        nameplates = {
            showEnemyNameplates=true, showEnemyMinions=true, showEnemyMinus=true,
            showFriendlyNameplates=false, showFriendlyMinions=false,
            nameplateMaxDistance=41
        },
        actionBars = { alwaysShowActionBars=true, autoPushSpellToActionBar=false, autoSelfCast=true, showActionBars2=true, showActionBars3=true, showActionBars4=true, showActionBars5=true, showActionBars6=true, showActionBars7=false, showActionBars8=false },
    },
    Pandaria = {
        general = { showMyName=true, autoLoot=true, autoLootRate=100, autoQuestTracking=true, showLuaErrors=false, showHead=true, showCloak=true },
        nameplates = { showEnemyNameplates=true, showFriendlyNameplates=false, nameplateMaxDistance=41 },
        actionBars = { alwaysShowActionBars=true, autoPushSpellToActionBar=false, autoSelfCast=true, showActionBars2=true, showActionBars3=true, showActionBars4=true, showActionBars5=true },
    },
}

-- Get Current Player game settings
function GetCurrentGameSettings()
    local generalSettings = {
        showMyName = GetCVarBool("UnitNameOwn"),
        autoLoot = GetCVarBool("autoLootDefault"),
        autoLootRate = tonumber(GetCVar("autoLootRate")) or 100,
        autoQuestTracking = GetCVarBool("autoQuestWatch") or true,
        showLuaErrors = GetCVarBool("scriptErrors"),
        showHead = GetCVarBool("showHelm"),
        showCloak = GetCVarBool("showCloak"),
    }

    if clientInfo.isClassic or clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBCC then
        if ShowingHelm then
            generalSettings.showHead = ShowingHelm()
        end
        if ShowingCloak then
            generalSettings.showCloak = ShowingCloak()
        end
    end

    local nameplateSettings = {
        showEnemyNameplates = GetCVarBool("nameplateShowEnemies"),
        showEnemyMinions = GetCVarBool("nameplateShowEnemyMinions"),
        showEnemyPets = GetCVarBool("nameplateShowEnemyPets"),
        showEnemyGuardians = GetCVarBool("nameplateShowEnemyGuardians"),
        showEnemyTotems = GetCVarBool("nameplateShowEnemyTotems"),
        showEnemyMinus = GetCVarBool("nameplateShowEnemyMinus"),
        separateEnemyMinions = false, -- Addon specific
        nameplateMaxDistance = tonumber(GetCVar("nameplateMaxDistance")) or 40,
    }

    -- Retail 12.0.0+ uses split friendly nameplate CVars
    if clientInfo.isRetail then
        nameplateSettings.showFriendlyPlayers = GetCVarBool("nameplateShowFriendlyPlayers")
        nameplateSettings.showFriendlyPlayerMinions = GetCVarBool("nameplateShowFriendlyPlayerMinions")
        nameplateSettings.showFriendlyNpcs = GetCVarBool("nameplateShowFriendlyNpcs")
        nameplateSettings.showFriendlyPets = GetCVarBool("nameplateShowFriendlyPlayerPets")
        nameplateSettings.showFriendlyGuardians = GetCVarBool("nameplateShowFriendlyPlayerGuardians")
        nameplateSettings.showFriendlyTotems = GetCVarBool("nameplateShowFriendlyPlayerTotems")
        nameplateSettings.separateMinions = false -- Addon specific
    else
        nameplateSettings.showFriendlyNameplates = GetCVarBool("nameplateShowFriends")
        nameplateSettings.showFriendlyMinions = GetCVarBool("nameplateShowFriendlyMinions")
        
        -- Non-retail specific extra checks
        nameplateSettings.showFriendlyPets = GetCVarBool("nameplateShowFriendlyPets")
        nameplateSettings.showFriendlyGuardians = GetCVarBool("nameplateShowFriendlyGuardians")
        nameplateSettings.showFriendlyTotems = GetCVarBool("nameplateShowFriendlyTotems")
        nameplateSettings.showFriendlyNpcs = GetCVarBool("nameplateShowFriendlyNPCs")
        nameplateSettings.separateMinions = false -- Addon specific
    end

    local actionBarsSettings = {}
    if clientInfo.isRetail then
        for i = 2, 8 do
            local key = "showActionBars"..i
            local proxyKey = "PROXY_SHOW_ACTIONBAR_"..i
            actionBarsSettings[key] = Settings.GetValue(proxyKey) or false
        end
    elseif clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC then
        for i = 2, 5 do
            local key = "showActionBars"..i
            local proxyKey = "PROXY_SHOW_ACTIONBAR_"..i
            actionBarsSettings[key] = Settings.GetValue(proxyKey) or false
        end
        actionBarsSettings.showActionBars6 = false
        actionBarsSettings.showActionBars7 = false
        actionBarsSettings.showActionBars8 = false
    elseif clientInfo.isLegion or clientInfo.isPandaria then
        actionBarsSettings.showActionBars2 = SHOW_MULTI_ACTIONBAR_1 == "1"
        actionBarsSettings.showActionBars3 = SHOW_MULTI_ACTIONBAR_2 == "1"
        actionBarsSettings.showActionBars4 = SHOW_MULTI_ACTIONBAR_3 == "1"
        actionBarsSettings.showActionBars5 = SHOW_MULTI_ACTIONBAR_4 == "1"
        actionBarsSettings.showActionBars6 = false
        actionBarsSettings.showActionBars7 = false
        actionBarsSettings.showActionBars8 = false
    end

    actionBarsSettings.alwaysShowActionBars = GetCVarBool("alwaysShowActionBars")
    actionBarsSettings.autoPushSpellToActionBar = GetCVarBool("AutoPushSpellToActionBar")
    actionBarsSettings.autoSelfCast = GetCVarBool("autoSelfCast")

    return {
        general = generalSettings,
        nameplates = nameplateSettings,
        actionBars = actionBarsSettings,
    }
end

-- Change name to more normal format (its used in first setup popup when showing settings that will change)
local function NormalizeName(key)
    local translations = {
        showHead = "Show Head",
        showCloak = "Show Cloak",
        showMyName = "Show My Name",
        autoLoot = "Auto Loot",
        autoLootRate = "Auto Loot Rate",
        autoQuestTracking = "Auto Quest Tracking",
        showLuaErrors = "Show Lua Errors",
        alwaysShowActionBars = "Always Show Action Bars",
        autoPushSpellToActionBar = "Auto Push Spell To Action Bar",
        autoSelfCast = "Auto Self Cast",
        showActionBars2 = "Show Action Bar 2",
        showActionBars3 = "Show Action Bar 3",
        showActionBars4 = "Show Action Bar 4",
        showActionBars5 = "Show Action Bar 5",
        showActionBars6 = "Show Action Bar 6",
        showActionBars7 = "Show Action Bar 7",
        showActionBars8 = "Show Action Bar 8",
        showEnemyNameplates = "Show Enemy Nameplates",
        showFriendlyNameplates = "Show Friendly Nameplates",
        showFriendlyPlayers = "Friendly Players Nameplates",
        showFriendlyPlayerMinions = "Friendly Minions Nameplates",
        showFriendlyNpcs = "Friendly NPCs Nameplates",
        nameplateMaxDistance = "Nameplate Max Distance",
    }

    if translations[key] then
        return translations[key]
    end

    -- fallback
    local text = key:gsub("(%l)(%u)", "%1 %2")
    text = text:gsub("(%a)(%d+)", "%1 %2")       -- insert space before number
    text = text:gsub("^%l", string.upper)        -- capitalize first letter
    return text
end

-- Category Order
local categoryOrder = {
    ["DISPLAY"] = {
        "showMyName",
        "autoLoot",
        "autoLootRate",
        "autoQuestTracking",
        "showLuaErrors",
        "showHead",
        "showCloak",
    },
    ["ACTION BARS"] = {
        "alwaysShowActionBars",
        "autoPushSpellToActionBar",
        "autoSelfCast",
        "showActionBars2",
        "showActionBars3",
        "showActionBars4",
        "showActionBars5",
        "showActionBars6",
        "showActionBars7",
        "showActionBars8",
    },
    ["NAMEPLATES"] = clientInfo.isRetail and {
        "showEnemyNameplates",
        "showFriendlyPlayers",
        "showFriendlyPlayerMinions",
        "showFriendlyNpcs",
        "nameplateMaxDistance",
    } or {
        "showEnemyNameplates",
        "showFriendlyNameplates",
        "nameplateMaxDistance",
    },
}

-- Check for difference between addon defaults and user settings that will display in ShowChangeSidepanel (first setup popup)
function BuildSettingsDiff(current, defaults)
    local diff = {}

    for categoryName, keys in pairs(categoryOrder) do
        local categoryDiff = {}
        for _, key in ipairs(keys) do
            local defaultVal = defaults[key]
            local currentVal = current[key]
            if defaultVal ~= nil then
                if type(defaultVal) == "table" then
                    local subDiff = BuildSettingsDiff(currentVal or {}, defaultVal)
                    for _, line in ipairs(subDiff) do
                        table.insert(categoryDiff, line)
                    end
                else
                    if currentVal ~= defaultVal then
                        table.insert(categoryDiff, string.format(
                            "|cffFF0000%s: %s -> %s|r",
                            NormalizeName(key),
                            tostring(currentVal),
                            tostring(defaultVal)
                        ))
                    end
                end
            end
        end

        if #categoryDiff > 0 then
            table.insert(diff, "|cffFFD100"..categoryName..":|r")
            for _, line in ipairs(categoryDiff) do
                table.insert(diff, "  "..line)
            end
        end
    end

    -- other keys if there are any
    for key, defaultVal in pairs(defaults) do
        if not tContainsAny(categoryOrder, key) then
            local currentVal = current[key]
            if type(defaultVal) == "table" then
                local subDiff = BuildSettingsDiff(currentVal or {}, defaultVal)
                for _, line in ipairs(subDiff) do
                    table.insert(diff, line)
                end
            else
                if currentVal ~= defaultVal then
                    table.insert(diff, string.format(
                        "|cffFF0000%s: %s -> %s|r",
                        NormalizeName(key),
                        tostring(currentVal),
                        tostring(defaultVal)
                    ))
                end
            end
        end
    end

    return diff
end

function tContainsAny(categories, key)
    for _, keys in pairs(categories) do
        for _, k in ipairs(keys) do
            if k == key then return true end
        end
    end
    return false
end

-- Settings Differences sidepanel
function ShowChangeSidepanel(diffList, anchor)
    anchor = anchor or "MQOL_CONFIRM_DEFAULTS"

    if not diffList or #diffList == 0 then
        diffList = {"|cff00ff00No settings will be changed.|r"}
    end

    local panel = _G.MQL_ChangeSidepanel
    if not panel then
        panel = CreateFrame("Frame", "MQL_ChangeSidepanel", UIParent)
        
        if mQoL_Templates and mQoL_Templates.SetBackdrop then
            mQoL_Templates.SetBackdrop(panel, 
                { edgeSize = 1 }, -- Border only request (conceptually) or just border params
                { 0.1, 0.1, 0.1, 0.95 }, 
                { 0.5, 0.5, 0.5, 1 }
            )
        end

        panel:SetSize(360, 440)
        panel:SetFrameStrata("FULLSCREEN")
        panel:SetClampedToScreen(true)

        -- Title
        panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        panel.title:SetPoint("TOPLEFT", 12, -10)
        panel.title:SetText("|cffffd100Settings that will change:|r")

        -- ScrollFrame
        panel.scrollFrame = CreateFrame("ScrollFrame", nil, panel)
        panel.scrollFrame:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
        panel.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

        panel.content = CreateFrame("Frame", nil, panel.scrollFrame)
        panel.scrollFrame:SetScrollChild(panel.content)
        panel.content:SetSize(300,1)

        if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
             mQoL_Styles.CreateCustomScrollbar(panel.scrollFrame, panel.content, { thumbWidth = 8 })
        end


        -- FontString
        panel.text = panel.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        panel.text:SetPoint("TOPLEFT", 0, 0)
        panel.text:SetWidth(300)
        panel.text:SetJustifyH("LEFT")
    end

    local popup
    if type(anchor) == "string" then
        popup = StaticPopup_FindVisible(anchor)
    elseif type(anchor) == "table" and anchor.GetObjectType then
        popup = anchor
    end

    if not popup and mQoL_Styles and mQoL_Styles.globalPopup and mQoL_Styles.globalPopup.IsShown and mQoL_Styles.globalPopup:IsShown() then
        popup = mQoL_Styles.globalPopup
    end

    if not popup then
        C_Timer.After(0.05, function() ShowChangeSidepanel(diffList, anchor) end)
        return
    end

    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", popup, "TOPRIGHT", 8, 0)

    -- Format Lines
    local formattedLines = {}
    local lastWasCategory = false
    for _, line in ipairs(diffList) do
        if line:find("^|cffFFD100") then
            if lastWasCategory then
                table.insert(formattedLines, "")
            end
            table.insert(formattedLines, "|cffffffff|cffFFFFFF"..line:gsub("|cffFFD100","").."|r|r")
            lastWasCategory = true
        else
            table.insert(formattedLines, "  "..line)
            lastWasCategory = false
        end
    end

    panel.text:SetText(table.concat(formattedLines, "\n"))
    panel.content:SetHeight(panel.text:GetStringHeight() + 10)
    panel:Show()
end

-- First Setup Panel
local firstSetupPanel

function FirstSetupPanel()
    if firstSetupPanel then return firstSetupPanel end

    local panel = CreateFrame("Frame", "mQoLFirstSetupPanel", UIParent)
    
    if mQoL_Templates and mQoL_Templates.SetBackdrop then
        mQoL_Templates.SetBackdrop(panel, 
            { edgeSize = 1 }, 
            { 0, 0, 0, 0.95 }, 
            { 0.5, 0.5, 0.5, 1 }
        )
    end

    panel:SetSize(400, 250)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    -- Close button
    local closeBtn = mQoL_Templates.CreateCloseButton(panel, 20, function() panel:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP",0,-15)
    title:SetText("mQoL First Setup")

	-- Description
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOP",0,-45)
    desc:SetWidth(360)
    desc:SetJustifyH("CENTER")
    desc:SetText("Welcome! Choose how to initialize your QoL settings.")

    local isPopupShown = false

	-- Button: Use My Current Settings
	local btnMySettings = mQoL_Templates.CreateButton(panel, "Use My Current Settings", 160, 30)
	btnMySettings:SetPoint("BOTTOMLEFT", 20, 20)
	btnMySettings:SetScript("OnClick", function()
		if isPopupShown then return end
		isPopupShown = true

        local function AcceptCurrentSettings()
            local currentSettings = GetCurrentGameSettings()

            mQoL_DB["MainQoL"] = { settings = currentSettings }
            mQoL_DB.firstSetupDone = true

            if mQoL_Main then
                if mQoL_Main.InitializeDB then
                    mQoL_Main:InitializeDB()
                end
                if mQoL_Main.ApplySettings then
                    mQoL_Main:ApplySettings()
                end
                if mQoL_Main.ApplyActionBarSettings and currentSettings.actionBars then
                    mQoL_Main:ApplyActionBarSettings(currentSettings.actionBars)
                end
            end

            panel:Hide()
            isPopupShown = false
            ReloadUI()
        end

        local function CancelPopup()
            isPopupShown = false
        end

        if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
            mQoL_Styles.ShowCustomPopup({
                text = "This will save your current game settings to mQoL. Continue?",
                acceptText = "Yes",
                cancelText = "No",
                onAccept = AcceptCurrentSettings,
                onCancel = CancelPopup,
            })
        else
            StaticPopupDialogs["MQOL_CONFIRM_CURRENT"] = {
                text = "This will save your current game settings to mQoL. Continue?",
                button1 = "Yes",
                button2 = "No",
                OnAccept = AcceptCurrentSettings,
                OnCancel = CancelPopup,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("MQOL_CONFIRM_CURRENT")
        end
	end)

	-- Button: Use Addon Defaults
	local btnAddonDefaults = mQoL_Templates.CreateButton(panel, "Use Addon Defaults", 160, 30)
	btnAddonDefaults:SetPoint("BOTTOMRIGHT", -20, 20)
	btnAddonDefaults:SetScript("OnClick", function()
		if isPopupShown then return end
		isPopupShown = true

		-- Get Current Player Settings for differences build
		local current = GetCurrentGameSettings()

		-- Get Addon Default Settings for differences build
		local versionKey = GetClientVersion()
		local defaults = defaultSettingsMap[versionKey]

		-- Build Difference Sidepanel List
		local diff = {}
		for category, set in pairs(defaults) do
			local partDiff = BuildSettingsDiff(current[category] or {}, set, category)
			for _, line in ipairs(partDiff) do
				table.insert(diff, line)
			end
		end

        local function HideSidepanel()
            if _G.MQL_ChangeSidepanel then
                _G.MQL_ChangeSidepanel:Hide()
            end
        end

        local function ApplyDefaults()
            mQoL_DB["MainQoL"] = { settings = defaults }
            mQoL_DB.firstSetupDone = true

            if mQoL_Main then
                if mQoL_Main.InitializeDB then
                    mQoL_Main:InitializeDB()
                end
                if mQoL_Main.ApplySettings then
                    mQoL_Main:ApplySettings()
                end
                if mQoL_Main.ApplyActionBarSettings and defaults.actionBars then
                    mQoL_Main:ApplyActionBarSettings(defaults.actionBars)
                end
            end

            HideSidepanel()
            if firstSetupPanel then
                firstSetupPanel:Hide()
            end
            ReloadUI()
        end

        local function CancelDefaultsPopup()
            HideSidepanel()
            isPopupShown = false
        end

        if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
            local popup = mQoL_Styles.ShowCustomPopup({
                text = "This will overwrite your current CVAR settings.\n\nType CONFIRM to proceed:",
                acceptText = "Confirm",
                cancelText = "Cancel",
                hasEditBox = true,
                maxLetters = 10,
                onAccept = function(editBox)
                    local text = editBox and editBox:GetText() or ""
                    if text:upper() == "CONFIRM" then
                        ApplyDefaults()
                    end
                    isPopupShown = false
                end,
                onCancel = CancelDefaultsPopup,
            })

            ShowChangeSidepanel(diff, popup)

            local acceptBtn = popup.acceptBtn or popup.blizzAcceptBtn
            local editBox = popup.editBox or (popup.GetEditBox and popup.GetEditBox())
            if acceptBtn and acceptBtn.Disable then
                acceptBtn:Disable()
            end

            if editBox and editBox.SetScript then
                editBox:SetScript("OnTextChanged", function(self2)
                    if not acceptBtn then return end
                    if self2:GetText():upper() == "CONFIRM" then
                        if acceptBtn.Enable then acceptBtn:Enable() end
                    else
                        if acceptBtn.Disable then acceptBtn:Disable() end
                    end
                end)

                editBox:SetScript("OnEnterPressed", function(self2)
                    if acceptBtn and acceptBtn.IsEnabled and acceptBtn:IsEnabled() and self2:GetText():upper() == "CONFIRM" then
                        if acceptBtn.Click then acceptBtn:Click() end
                    end
                    self2:ClearFocus()
                end)

                editBox:SetScript("OnEscapePressed", function(self2)
                    CancelDefaultsPopup()
                    if popup and popup.Hide then popup:Hide() end
                    self2:ClearFocus()
                end)
            end
        else
            ShowChangeSidepanel(diff, "MQOL_CONFIRM_DEFAULTS")

            StaticPopupDialogs["MQOL_CONFIRM_DEFAULTS"] = {
                text = "This will overwrite your current CVAR settings.\n\nType CONFIRM to proceed:",
                button1 = "Confirm",
                button2 = "Cancel",
                hasEditBox = true,
                maxLetters = 10,
                OnAccept = function(self)
                    local editBox = _G[self:GetName().."EditBox"]
                    local text = editBox and editBox:GetText() or ""
                    if text:upper() == "CONFIRM" then
                        ApplyDefaults()
                    else
                        print("|cffff5555[mQoL]|r Action canceled. Type CONFIRM to enable the button.")
                    end
                    isPopupShown = false
                end,
                OnShow = function(self)
                    local editBox = _G[self:GetName().."EditBox"]
                    local btn1 = _G[self:GetName().."Button1"]

                    btn1:Disable()

                    editBox:SetScript("OnTextChanged", function(self2)
                        if self2:GetText():upper() == "CONFIRM" then
                            btn1:Enable()
                        else
                            btn1:Disable()
                        end
                    end)
                end,
                OnCancel = CancelDefaultsPopup,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("MQOL_CONFIRM_DEFAULTS")
        end
	end)
    firstSetupPanel = panel
    return panel
end

-- Event handler
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not mQoL_DB.firstSetupDone then
        C_Timer.After(2, function()
            if mQoL_Database and FirstSetupPanel then
                local panel = FirstSetupPanel()
                if panel then
                    panel:Show()
                else
                    print("|cffff5555[mQoL]|r Cannot run First Setup Panel")
                end
            end
        end)
    end
end)
