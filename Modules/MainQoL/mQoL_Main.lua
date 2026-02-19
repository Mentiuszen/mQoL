local addonName, L = ...
mQoL_Main = mQoL_Main or {}

-- Check if Hub is Available
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
	return
end

-- Check Client Version
local clientInfo = mQoL_Hub.clientInfo

-- Default Settings -- DO NOT STORE HERE BLIZZARD SETTINGS ONLY FOR CUSTOM FUNCTIONS (Defaults are stored in FirstSetup)
mQoL_Main.defaults = {
	general = {
		forcedEditModeProfile = "",	--Empty means None
	},
	nameplates = {
		--LEAVE EMPTY!
    },
	actionBars = {
		--LEAVE EMPTY!
	}
}

-- Initialize Database
function mQoL_Main:InitializeDB()
	mQoL_Database:MigrateModule("MainQoL", self.defaults)
	self.db = mQoL_Database:GetSettings("MainQoL") or {}
end

-- Apply Settings
function mQoL_Main:ApplySettings()
	local general    = mQoL_Database:GetSettings("MainQoL", "general") or {}
	local nameplates = mQoL_Database:GetSettings("MainQoL", "nameplates") or {}

	-- Nameplates
	SetCVar("nameplateShowEnemies", nameplates.showEnemyNameplates and 1 or 0)
	SetCVar("nameplateShowFriends", nameplates.showFriendlyNameplates and 1 or 0)
	SetCVar("nameplateShowFriendlyPlayers", nameplates.showFriendlyNameplates and 1 or 0)
	SetCVar("nameplateShowFriendlyNpcs", nameplates.showFriendlyNameplates and 1 or 0)
	SetCVar("nameplateShowFriendlyPlayerMinions", nameplates.showFriendlyNameplates and 1 or 0)
	SetCVar("nameplateShowAll", (nameplates.showEnemyNameplates or nameplates.showFriendlyNameplates) and 1 or 0)
	SetCVar("nameplateMaxDistance", nameplates.nameplateMaxDistance or 41)

    -- General
	SetCVar("UnitNameOwn", general.showMyName and 1 or 0)
	SetCVar("autoLootDefault", general.autoLoot and 1 or 0)
	SetCVar("autoQuestWatch", general.autoQuestTracking and 1 or 0)
	SetCVar("scriptErrors", general.showLuaErrors and 1 or 0)

	if clientInfo.isClassic or clientInfo.isPandaria or clientInfo.isEra or clientInfo.isBcc then
		if ShowHelm then ShowHelm(general.showHead == true) end
		if ShowCloak then ShowCloak(general.showCloak == true) end
	end
end

-- Get Character Key (Name-Realm)
local function GetCharacterKey()
	local name = UnitName("player") or "Unknown"
	local realm = GetRealmName() or "UnknownRealm"
	realm = realm:gsub("%s+", "") -- Remove spaces
	return name .. "-" .. realm
end

-- Generate Checksum from Action Bars Settings
local function GenerateBarsChecksum(actionBars)
	local checksum = ""
    
	-- alwaysShowActionBars (only for non retail)
	if not clientInfo.isRetail then
		checksum = checksum .. (actionBars.alwaysShowActionBars and "1" or "0")
	end
    
    -- Action bars 2-5 (all versions)
	for i = 2, 5 do
		local key = "showActionBars" .. i
		checksum = checksum .. (actionBars[key] and "1" or "0")
	end
    
    -- Action bars 6-8 (retail only)
	if clientInfo.isRetail then
		for i = 6, 8 do
			local key = "showActionBars" .. i
			checksum = checksum .. (actionBars[key] and "1" or "0")
		end
	end

	return checksum
end

-- Get Saved Bars Checksum for Character
local function GetBarsChecksum(characterKey)
	mQoL_DB["MainQoL"] = mQoL_DB["MainQoL"] or {}
	mQoL_DB["MainQoL"].barsChecksums = mQoL_DB["MainQoL"].barsChecksums or {}
	return mQoL_DB["MainQoL"].barsChecksums[characterKey]
end

-- Save Bars Checksum for Character
local function SaveBarsChecksum(characterKey, checksum)
	mQoL_DB["MainQoL"] = mQoL_DB["MainQoL"] or {}
	mQoL_DB["MainQoL"].barsChecksums = mQoL_DB["MainQoL"].barsChecksums or {}
	mQoL_DB["MainQoL"].barsChecksums[characterKey] = checksum
end

-- Check if Bars Checksum matches current settings
local function CheckBarsChecksum()
	local characterKey = GetCharacterKey()
	local actionBars = mQoL_Database:GetSettings("MainQoL", "actionBars") or {}
	local currentChecksum = GenerateBarsChecksum(actionBars)
	local savedChecksum = GetBarsChecksum(characterKey)
	
	-- if checksum missing
	if not savedChecksum then
		return false
	end
	
	-- Compare checksums
	return currentChecksum == savedChecksum
end

-- Safe Update Action Bars (for Legion)
local function SafeUpdateActionBars()
	if InCombatLockdown() then return end

	if SHOW_MULTI_ACTIONBAR_1 == "1" then
		MultiActionBar_ShowAllGrids(MultiBarBottomLeft)
	else
		MultiActionBar_HideAllGrids(MultiBarBottomLeft)
	end

	if SHOW_MULTI_ACTIONBAR_2 == "1" then
		MultiActionBar_ShowAllGrids(MultiBarBottomRight)
	else
		MultiActionBar_HideAllGrids(MultiBarBottomRight)
	end

	if SHOW_MULTI_ACTIONBAR_3 == "1" then
		MultiActionBar_ShowAllGrids(MultiBarRight)
	else
		MultiActionBar_HideAllGrids(MultiBarRight)
	end

	if SHOW_MULTI_ACTIONBAR_4 == "1" then
		MultiActionBar_ShowAllGrids(MultiBarLeft)
	else
		MultiActionBar_HideAllGrids(MultiBarLeft)
	end
end

-- Show popup for action bars reload
local function ShowBarsReloadPopup()
	-- Register popup dialog if not already registered
	if not StaticPopupDialogs["MQOL_RELOAD_ACTIONBARS"] then
		StaticPopupDialogs["MQOL_RELOAD_ACTIONBARS"] = {
			text = "Action bar settings have changed.\n\nA UI reload is required to avoid taint and ensure buttons work correctly.\n\n This will also apply automatically on logout or after a manual /reload.\n\nReload now?",
			button1 = "Reload UI",
			button2 = "Later",
			OnAccept = function()
				-- Apply settings and save checksum
				if mQoL_Main and mQoL_Main.ApplyBarsSettings then
					mQoL_Main:ApplyBarsSettings()
				end
				-- Reload UI
				ReloadUI()
			end,
			OnCancel = function()
			-- Do nothing user can reload manually later
			end,
			timeout = 0,
			whileDead = false,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end

	StaticPopup_Show("MQOL_RELOAD_ACTIONBARS")
end

-- Apply Action Bars Settings
function mQoL_Main:ApplyBarsSettings()
	local actionBars = mQoL_Database:GetSettings("MainQoL", "actionBars") or {}

	-- Action Bars
	if not clientInfo.isRetail then
		SetCVar("alwaysShowActionBars", actionBars.alwaysShowActionBars and 1 or 0)
	end

	-- Legion
	if clientInfo.isLegion then
		SHOW_MULTI_ACTIONBAR_1 = actionBars.showActionBars2 and "1" or "0"
		SHOW_MULTI_ACTIONBAR_2 = actionBars.showActionBars3 and "1" or "0"
		SHOW_MULTI_ACTIONBAR_3 = actionBars.showActionBars4 and "1" or "0"
		SHOW_MULTI_ACTIONBAR_4 = actionBars.showActionBars5 and "1" or "0"
		SafeUpdateActionBars()
	end

	-- Classic and Era
	if clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
		for i = 2, 5 do
			local key = "showActionBars" .. i
			local val = actionBars[key]
			if val ~= nil then
				Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. i, val)
			end
		end
	end

	-- Retail
	if clientInfo.isRetail then
		for i = 2, 8 do
			local key = "showActionBars" .. i
			local val = actionBars[key]
			if val ~= nil then
				Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. i, val)
			end
		end
	end
	
	-- Save checksum after applying settings
	if clientInfo.isRetail then
		local characterKey = GetCharacterKey()
		local checksum = GenerateBarsChecksum(actionBars)
		SaveBarsChecksum(characterKey, checksum)
	end
end

-- Get editmode profiles
function mQoL_Main:GetEditModeProfiles()
	if not EditModeManagerFrame or not EditModeManagerFrame.GetLayouts then
		return {}
	end

	local profiles = EditModeManagerFrame:GetLayouts()
	local names = {}

	for _, profile in ipairs(profiles) do
		if profile and profile.layoutName then
			table.insert(names, profile.layoutName)
		end
	end

	return names
end

function mQoL_Main:GetEditModeProfileIndexByName(name)
	local profiles = EditModeManagerFrame and EditModeManagerFrame:GetLayouts()
	if not profiles then return nil end
	for i, profile in ipairs(profiles) do
		if profile.layoutName == name then
		return i
		end
	end
	return nil
end

-- Force editmode profile
local function ForceEditModeProfile(profileName)
	if EditModeManagerFrame and EditModeManagerFrame.GetLayouts and EditModeManagerFrame.SelectLayout then
		local profiles = EditModeManagerFrame:GetLayouts()
		for i, profile in ipairs(profiles) do
			if profile.layoutName == profileName then
				EditModeManagerFrame:SelectLayout(i)
				C_Timer.After(0.1, function()
					if EditModeManagerFrame.UpdateLayout then
						EditModeManagerFrame:UpdateLayout()
					end
				end)
				return
			end
		end
	else
	end
end

function mQoL_Main:CreateGeneralPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetSize(400, 350)
	local yOffset = -40

	-- Panel Title
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("Quality of Life Settings - General")
	title:SetTextColor(1, 1, 1)
    
	-- Separator
	local separator = panel:CreateTexture(nil, "ARTWORK")
	separator:SetColorTexture(1, 1, 1, 0.3)
	separator:SetSize(930, 1)
	separator:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

	-- Checkbox Func
	local function CreateCheckbox(label, key)
		local checkbox = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
		checkbox:SetPoint("TOPLEFT", 10, yOffset)
		checkbox:SetChecked(mQoL_Database:GetSettings("MainQoL", "general", key))
		checkbox:SetScript("OnClick", function(self)
			mQoL_Database:SetSettings("MainQoL", "general", key, self:GetChecked())
			mQoL_Main:ApplySettings()
		end)

		checkbox.label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
		checkbox.label:SetTextColor(1, 0.82, 0)
		checkbox.label:SetText(label)

		yOffset = yOffset - 30
	end

	-- Checkboxes
	CreateCheckbox("Enable LUA Errors", "showLuaErrors")
	CreateCheckbox("Enable Autoloot", "autoLoot")
	CreateCheckbox("Enable Auto Quest Tracking", "autoQuestTracking")
	CreateCheckbox("Show My Name", "showMyName")

	-- Classic / MoP - show head/cloak
	if clientInfo.isPandaria or clientInfo.isClassic then
		CreateCheckbox("Show Head", "showHead")
		CreateCheckbox("Show Cloak", "showCloak")
	end

    -- Retail - Forced Edit Mode Profile
	if clientInfo.isRetail then
		local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("TOPLEFT", 10, yOffset)
		label:SetText("Forced Edit Mode Profile:")
		label:SetTextColor(1, 0.82, 0)
		yOffset = yOffset - 25

		local dropdown = CreateFrame("Frame", "mQoLEditModeProfileDropdown", panel, "UIDropDownMenuTemplate")
		dropdown:SetPoint("TOPLEFT", 10, yOffset)
		UIDropDownMenu_SetWidth(dropdown, 180)

		local profiles = self:GetEditModeProfiles()
		if #profiles == 0 then
			profiles = {"No profiles found"}
		end

		local function OnClick(self)
			local value = self.value == "none" and "" or self.value
			mQoL_Database:SetSettings("MainQoL", "general", "forcedEditModeProfile", value)
			UIDropDownMenu_SetSelectedValue(dropdown, value ~= "" and value or "none")
			UIDropDownMenu_SetText(dropdown, value ~= "" and value or "None")
		end

		local function Initialize()
			local info = UIDropDownMenu_CreateInfo()
			info.text = "None"
			info.value = "none"
			info.func = OnClick
			UIDropDownMenu_AddButton(info)

			for _, prof in ipairs(profiles) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = prof
				info.value = prof
				info.func = OnClick
				UIDropDownMenu_AddButton(info)
			end
		end

		UIDropDownMenu_Initialize(dropdown, Initialize)

		local forcedProfile = mQoL_Database:GetSettings("MainQoL", "general", "forcedEditModeProfile")
		if forcedProfile and forcedProfile ~= "" then
			UIDropDownMenu_SetSelectedValue(dropdown, forcedProfile)
			UIDropDownMenu_SetText(dropdown, forcedProfile)
		else
			UIDropDownMenu_SetSelectedValue(dropdown, "none")
			UIDropDownMenu_SetText(dropdown, "None")
		end

		local applyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		applyButton:SetSize(80, 22)
		applyButton:SetPoint("LEFT", dropdown, "RIGHT", 10, 0)
		applyButton:SetText("Apply")

		applyButton:SetScript("OnClick", function()
			local profileName = mQoL_Database:GetSettings("MainQoL", "general", "forcedEditModeProfile")
			if profileName and profileName ~= "" then
				ForceEditModeProfile(profileName)
			end
		end)

		yOffset = yOffset - 40
	end

	return panel
end

function mQoL_Main:CreateNameplatesPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetSize(400, 300)
	local yOffset = -40

	-- panel title
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("Quality of Life Settings - Nameplates")
	title:SetTextColor(1, 1, 1)

	-- seperator
	local separator = panel:CreateTexture(nil, "ARTWORK")
	separator:SetColorTexture(1, 1, 1, 0.3)
	separator:SetSize(930, 1)
	separator:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

	-- checkbox func
	local function CreateCheckbox(label, key)
		local checkbox = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
		checkbox:SetPoint("TOPLEFT", 10, yOffset)
		checkbox:SetChecked(mQoL_Database:GetSettings("MainQoL", "nameplates", key))
		checkbox:SetScript("OnClick", function(self)
			mQoL_Database:SetSettings("MainQoL", "nameplates", key, self:GetChecked())
			mQoL_Main:ApplySettings()
		end)

		checkbox.label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
		checkbox.label:SetTextColor(1, 0.82, 0)
		checkbox.label:SetText(label)

		yOffset = yOffset - 30
	end

	-- nameplates checkboxes
	CreateCheckbox("Show Enemy Nameplates", "showEnemyNameplates")
	CreateCheckbox("Show Friendly Nameplates", "showFriendlyNameplates")

	-- dropdown for nameplates distance
	local distances = {20, 40, 60}
	if clientInfo.isEra or clientInfo.isBcc then distances = {10, 20} end
	if clientInfo.isClassic then distances = {21, 41} end
	if clientInfo.isLegion then distances = {20, 40, 60, 80, 100} end

	local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 10, yOffset)
	label:SetTextColor(1, 0.82, 0)
	label:SetText("Max nameplate distance:")
	yOffset = yOffset - 25

	local dropdown = CreateFrame("Frame", "mQoLNameplateDropdown", panel, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", 10, yOffset)
	UIDropDownMenu_SetWidth(dropdown, 100)

	local function OnClick(self)
		mQoL_Database:SetSettings("MainQoL", "nameplates", "nameplateMaxDistance", self.value)
		UIDropDownMenu_SetSelectedValue(dropdown, self.value)
		UIDropDownMenu_SetText(dropdown, tostring(self.value))
		mQoL_Main:ApplySettings()
	end

	local function Initialize()
		for _, val in ipairs(distances) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = tostring(val)
			info.value = val
			info.func = OnClick
			UIDropDownMenu_AddButton(info)
		end
	end

	UIDropDownMenu_Initialize(dropdown, Initialize)

	local currentDistance = mQoL_Database:GetSettings("MainQoL", "nameplates", "nameplateMaxDistance")
	UIDropDownMenu_SetSelectedValue(dropdown, currentDistance)
	UIDropDownMenu_SetText(dropdown, tostring(currentDistance))

	return panel
end

function mQoL_Main:CreateActionBarsPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetSize(400, 300)
	local yOffset = -40

	-- panel title
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("Quality of Life Settings - Action Bars")
	title:SetTextColor(1, 1, 1)

	-- Separator
	local separator = panel:CreateTexture(nil, "ARTWORK")
	separator:SetColorTexture(1, 1, 1, 0.3)
	separator:SetSize(930, 1)
	separator:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

	-- Warning message
	local warningText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	warningText:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -15)
	warningText:SetWidth(760)
	warningText:SetJustifyH("LEFT")
	warningText:SetJustifyV("TOP")
	warningText:SetTextColor(1, 0.82, 0)
	warningText:SetText("|cffff0000Warning:|r |cffffffffChanging these settings requires a UI reload on every character. Without reloading, Blizzard action bars may become tainted, causing certain buttons to stop working. A reload prompt will appear when you log in with an affected character.|r")
	yOffset = yOffset - 60

	-- checkbox func
	local function CreateCheckbox(label, key)
		local checkbox = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
		checkbox:SetPoint("TOPLEFT", 10, yOffset)
		checkbox:SetChecked(mQoL_Database:GetSettings("MainQoL", "actionBars", key))
		checkbox:SetScript("OnClick", function(self)
			mQoL_Database:SetSettings("MainQoL", "actionBars", key, self:GetChecked())
		end)
		checkbox.label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
		checkbox.label:SetTextColor(1, 0.82, 0)
		checkbox.label:SetText(label)
		yOffset = yOffset - 30
	end

	-- Checkboxes
	if not clientInfo.isRetail then
		CreateCheckbox("Always Show Action Bars", "alwaysShowActionBars")
	end
	CreateCheckbox("Show Action Bar 2", "showActionBars2")
	CreateCheckbox("Show Action Bar 3", "showActionBars3")
	CreateCheckbox("Show Action Bar 4", "showActionBars4")
	CreateCheckbox("Show Action Bar 5", "showActionBars5")

	if clientInfo.isRetail then
		CreateCheckbox("Show Action Bar 6", "showActionBars6")
		CreateCheckbox("Show Action Bar 7", "showActionBars7")
		CreateCheckbox("Show Action Bar 8", "showActionBars8")
	end

	return panel
end

-- Event handler
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		-- Initialize database
		if mQoL_Main and mQoL_Main.InitializeDB then
			mQoL_Main:InitializeDB()
		end

	elseif event == "PLAYER_LOGIN" then
		if mQoL_DB and mQoL_DB.firstSetupDone then
			-- apply settings
			C_Timer.After(0, function() 
				if mQoL_Main then
					if mQoL_Main.ApplySettings then
						mQoL_Main:ApplySettings()
					end
					-- Check and apply bars settings if needed
					if mQoL_Main.ApplyBarsSettings then
						if clientInfo.isRetail then
							local characterKey = GetCharacterKey()
							local actionBars = mQoL_Database:GetSettings("MainQoL", "actionBars") or {}
							local savedChecksum = GetBarsChecksum(characterKey)
	                        
							-- If no checksum exists apply settings and show popup
							if not savedChecksum then
								-- Apply settings
								mQoL_Main:ApplyBarsSettings()
								-- Show popup for user to confirm reload
								C_Timer.After(1, function()
									ShowBarsReloadPopup()
								end)
							else
								-- Check if checksum matches
								local currentChecksum = GenerateBarsChecksum(actionBars)
								if currentChecksum ~= savedChecksum then
									-- Show popup for user to confirm reload
									C_Timer.After(1, function()
										ShowBarsReloadPopup()
									end)
								end
							end
						else
							-- Non-Retail: Just apply settings without checksum check
							mQoL_Main:ApplyBarsSettings()
						end
					end
				end
			end)

			-- Register panels in hub
			if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
				mQoL_Hub:RegisterModuleOptions("mQoL_GeneralQoL", "General QoL", function(parent)
					return mQoL_Main:CreateGeneralPanel(parent)
				end)
				mQoL_Hub:RegisterModuleOptions("mQoL_Nameplates", "Nameplates", function(parent)
					return mQoL_Main:CreateNameplatesPanel(parent)
				end)
				mQoL_Hub:RegisterModuleOptions("mQoL_ActionBars", "Action Bars", function(parent)
					return mQoL_Main:CreateActionBarsPanel(parent)
				end)
			end

			-- Force Editmode profile
			if mQoL_Database and mQoL_Database.GetSettings then
				local profile = mQoL_Database:GetSettings("MainQoL", "general", "forcedEditModeProfile")
				if profile and profile ~= "" then
					C_Timer.After(2, function()
						if ForceEditModeProfile then
							ForceEditModeProfile(profile)
						end
					end)
				end
			end
		end
	end
end)