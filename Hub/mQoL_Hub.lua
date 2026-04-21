local addonName, L = ...
mQoL_Hub = mQoL_Hub or {}
mQoL_Hub.name = addonName
mQoL_Hub.modules = {}

-- Addon Prefix
local ADDON_PREFIX = "mQoLHub"

local vreg = _G.vreg
mQoL_Hub.VersionData = mQoL_Hub.VersionData or {}

-- Addon Version
mQoL_Hub.version = "1.2.0"
mQoL_Hub.build = "229"
mQoL_Hub.vendor = "test"	--dev / test / release

-- Styles
local CreateCustomScrollbar = mQoL_Styles.CreateCustomScrollbar
local CreateCustomButton = mQoL_Styles.CreateCustomButton
local CreateCustomDropdown = mQoL_Styles.CreateCustomDropdown
local CreateCustomSlider = mQoL_Styles.CreateCustomSlider
local CreateCustomInputBox = mQoL_Styles.CreateCustomInputBox
local CreateCustomCheckbox = mQoL_Styles.CreateCustomCheckbox

print(string.format("|cffffff00[mQoL]|r |cff00ff00v%s Loaded.|r", mQoL_Hub.version))
print("|cff00ff00Use |cffffff00/mQoL|r |cff00ff00to open the menu.|r")

-- Toc Detection
local clientInfo = mQoL_VersionDetection.clientInfo

function mQoL_Hub:RegisterModuleOptions(id, label, panelFunc)
    self.modules[label] = panelFunc
end

mQoL_Hub.searchIndex = {
	{ label = "Hide Minimap Button", panel = "Display", available = true },
	{ label = "Window Scale", panel = "Display", available = true },
	{ label = "Window Opacity", panel = "Display", available = true },
	{ label = "Enable LUA Errors", panel = "General QoL", available = true },
    { label = "Enable Autoloot", panel = "General QoL", available = true },
	{ label = "Fast Auto Loot", panel = "General QoL", available = true },
	{ label = "Enable Auto Quest Tracking", panel = "General QoL", available = true },
	{ label = "My Name", panel = "General QoL", available = true },
    { label = "Enemy Nameplates", panel = "Nameplates", available = true },
    { label = "Friendly Nameplates", panel = "Nameplates", available = true },
	{ label = "Max Nameplate Distance", panel = "Nameplates", available = true },
    { label = "Always Show Action Bars", panel = "Action Bars", available = not clientInfo.isRetail or clientInfo.isBCC },
	{ label = "Auto Push Spell To Action Bar", panel = "Action Bars", available = true },
	{ label = "Auto Self Cast", panel = "Action Bars", available = true },
	{ label = "Action Bar 2", panel = "Action Bars", available = true },
	{ label = "Action Bar 3", panel = "Action Bars", available = true },
	{ label = "Action Bar 4", panel = "Action Bars", available = true },
	{ label = "Action Bar 5", panel = "Action Bars", available = true },
	{ label = "Action Bar 6", panel = "Action Bars", available = clientInfo.isRetail or clientInfo.isBCC },
	{ label = "Action Bar 7", panel = "Action Bars", available = clientInfo.isRetail or clientInfo.isBCC },
	{ label = "Action Bar 8", panel = "Action Bars", available = clientInfo.isRetail or clientInfo.isBCC },
    { label = "Auto Open Mailbox Side Panel", panel = "Mailbox", available = true },
    { label = "Enable Gold Summary from Mailbox", panel = "Mailbox", available = true },
    { label = "Auto Mailbox Subject", panel = "Mailbox", available = true },
    { label = "Alts List", panel = "Mailbox", available = true },
    { label = "Guild List", panel = "Mailbox", available = true },
    { label = "Friends List", panel = "Mailbox", available = true },
	{ label = "View Distance", panel = "Graphics", available = clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC },
    { label = "Fog Distance", panel = "Graphics", available = clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC },
    { label = "Edit Mode Profile Mode", panel = "Edit Mode", available = clientInfo.isRetail or clientInfo.isBCC },
    { label = "Force Edit Mode Profile", panel = "Edit Mode", available = clientInfo.isRetail or clientInfo.isBCC },
    { label = "Use Raid Frames in 5-Man Party", panel = "Raid Profiles", available = true },
    { label = "Saved Raid Profiles", panel = "Raid Profiles", available = true },
    { label = "Forced Raid Profile Mode", panel = "Raid Profiles", available = true },
    { label = "Force Raid Profile", panel = "Raid Profiles", available = true },
    { label = "PvP Rewards Fix", panel = "Blizzard Fixes", available = clientInfo.isClassic },
    { label = "Pandaria Map Navigation", panel = "Blizzard Fixes", available = clientInfo.isClassic },
    { label = "Consolidated Buffs Improvement", panel = "Blizzard Fixes", available = clientInfo.isClassic },
    { label = "Corpse Map Texture Fix", panel = "Blizzard Fixes", available = clientInfo.isClassic },
    { label = "Minimap Instance Difficulty Fix", panel = "Blizzard Fixes", available = clientInfo.isClassic },
    { label = "Auto Reset Instance", panel = "Blizzard Fixes", available = clientInfo.isClassic },
    { label = "Encounter Journal Tab Fix", panel = "Blizzard Fixes", available = clientInfo.isClassic },
}

-- SLASH COMMAND OPEN MAIN WINDOW
SLASH_MQOL_HUB1 = "/mQoL"
SlashCmdList["MQOL_HUB"] = function()
    mQoL_Hub:ToggleMainPanel()
end

 -- Slash Command for version check window
SLASH_MQOL_HUBVERSION1 = "/mqv"
local function SendAddonMessage(prefix, text, type, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(prefix, text, type, target)
    elseif _G.SendAddonMessage then
        _G.SendAddonMessage(prefix, text, type, target)
    end
end

SlashCmdList["MQOL_HUBVERSION"] = function()
    if not mQoL_Hub.VersionFrame then
        mQoL_Hub:CreateVersionPanel()
    end
    mQoL_Hub.VersionFrame:Show()
    mQoL_Hub:ClearVersionPanel()

    mQoL_Hub:AddVersionRow(UnitName("player"), mQoL_Hub.vendor or "unknown", mQoL_Hub.version or "unknown", mQoL_Hub.build or "unknown")
    mQoL_Hub:RefreshVersionPanel()

    if IsInRaid() then
        SendAddonMessage(ADDON_PREFIX, "!VREQ", "RAID")
    elseif IsInGroup() then
        SendAddonMessage(ADDON_PREFIX, "!VREQ", "PARTY")
    end
end

-- Libs for minimap
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local hubLauncher = LDB:NewDataObject("mQoL_Hub", {
    type = "launcher",
    text = "mQoL Hub",
    icon = "Interface\\AddOns\\mQoL\\Media\\Textures\\logo",
    OnTooltipShow = function(tooltip)
        tooltip:ClearLines()
        tooltip:AddLine("|cffFFD100mQoL Hub v" .. (mQoL_Hub.version or "unknown") .. "|r")
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff00ff00Left Click|r: Open Home Panel")
        tooltip:AddLine("|cff00ff00Right Click|r: Open Version Panel")
    end,
})

function mQoL_Hub:InitializeMinimap()
    LDBIcon:Register("mQoL_Hub", hubLauncher, self.db.minimap)

    if self.db.minimap and self.db.minimap.hide then
        LDBIcon:Hide("mQoL_Hub")
    end

	hubLauncher.OnClick = function(_, button)
		if button == "LeftButton" then
			if self.ToggleMainPanel then
				self:ToggleMainPanel()
			end

		elseif button == "RightButton" then
			if not self.VersionFrame then
				self:CreateVersionPanel()
			end

			if self.VersionFrame:IsShown() then
				self.VersionFrame:Hide()
			else
				self.VersionFrame:Show()
				self:ClearVersionPanel()
				self:AddVersionRow(UnitName("player"), self.vendor or "unknown", self.version or "unknown", self.build or "unknown")
				self:RefreshVersionPanel()

                if IsInRaid() then
                    SendAddonMessage(ADDON_PREFIX, "!VREQ", "RAID")
                elseif IsInGroup() then
                    SendAddonMessage(ADDON_PREFIX, "!VREQ", "PARTY")
                end
			end
		end
	end
end

--Default Settings
mQoL_Hub.defaults = {
    minimap = { hide = false, minimapPos = 220 },
    display = { scale = 1.0, opacity = 1.0 },
    home = { introSeen = false },
}

--Initialize Database
function mQoL_Hub:InitializeDB()
    mQoL_Database:MigrateModule("Hub", self.defaults)
    self.db = mQoL_Database:GetSettings("Hub")
end

--Highlight for search
function mQoL_Hub:HighlightOption(optionLabel)
    if not self.activePanel or not self.activePanel.optionsLabels then return end
    
    -- Add small delay to ensure UI is fully rendered
    C_Timer.After(0.01, function()
        local label = self.activePanel.optionsLabels[optionLabel]
        if not label then return end
        
        -- Store original color if not already stored
        if not label.originalColor then
            label.originalColor = {label:GetTextColor()}
        end
        
        local totalTime = 3
        local elapsed = 0
        local pulseDuration = 0.5
        
        if label.highlightTicker then
            label.highlightTicker:Cancel()
            label.highlightTicker = nil
            -- Restore original color
            label:SetTextColor(label.originalColor[1], label.originalColor[2], label.originalColor[3])
        end
        
        label.highlightTicker = C_Timer.NewTicker(0.05, function()
            elapsed = elapsed + 0.05
            if elapsed >= totalTime then
                -- Restore original color
                label:SetTextColor(label.originalColor[1], label.originalColor[2], label.originalColor[3])
                label.highlightTicker:Cancel()
                label.highlightTicker = nil
                return
            end
            
            local phase = (elapsed % pulseDuration) / pulseDuration
            local intensity = phase < 0.5 and (phase * 2) or (2 - phase * 2)
            
            -- Pulse between original color and red
            local r = label.originalColor[1] * (1 - intensity) + 1 * intensity
            local g = label.originalColor[2] * (1 - intensity)
            local b = label.originalColor[3] * (1 - intensity)
            
            label:SetTextColor(r, g, b)
        end)
    end)
end

function mQoL_Hub:SetupNumberInputBox(editBox, slider, minVal, maxVal, step, onApply, formatValue)
    local function FormatNumber(val)
        if formatValue then
            return formatValue(val)
        end
        return string.format("%.2f", val)
    end

    local function ApplyFunction(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(minVal, math.min(maxVal, val))
            val = math.floor(val / step + 0.5) * step
            self:SetText(FormatNumber(val))
            if slider and slider.SetValue then
                slider:SetValue(val)
            end
            if onApply then
                onApply(val)
            end
        else
            if slider and slider.GetValue then
                self:SetText(FormatNumber(slider:GetValue()))
            end
        end
        self:ClearFocus()
    end

    editBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        local cleanText = text:gsub("[^0-9.]", "")
        local firstDot = cleanText:find("%.")
        if firstDot then
            local before = cleanText:sub(1, firstDot)
            local after = cleanText:sub(firstDot + 1):gsub("%.", "")
            cleanText = before .. after
        end
        if cleanText ~= text then
            self:SetText(cleanText)
        end
    end)

    editBox:SetScript("OnEnterPressed", ApplyFunction)

    -- Return function to be called by Apply button
    return function()
        ApplyFunction(editBox)
    end
end

function mQoL_Hub:AddOptionRow(parent, name, controlType, controlParams, extra, applyFunc)

    -- Layout / spacing parameters
    local leftMargin = 30
    local labelWidth = 180
    local spacing = 20
    local buttonWidth = 150
    local maxControlWidth = 360
	local sliderInputSpacing = 20
	local rightMargin = 50
    local betweenOptionsSpacing = 0

    -- Element Sizes
    local rowWidth = 850
    local rowHeight = 30
    local checkboxSize = 28
    local sliderHeight = 14
    local inputHeight = 28
    local buttonHeight = 28
    local dropdownHeight = 28

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(rowWidth, rowHeight)

    -- Label
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", row, "LEFT", leftMargin, 0)
    label:SetSize(labelWidth, rowHeight)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(name)
    label:SetTextColor(1, 0.82, 0)

    -- Store label reference in panel
    if not parent.optionsLabels then parent.optionsLabels = {} end
    parent.optionsLabels[name] = label

    local uiAreaWidth = rowWidth - leftMargin - labelWidth - spacing - rightMargin
    if extra and #extra > 0 then
        for _, frame in ipairs(extra) do
            uiAreaWidth = uiAreaWidth - frame:GetWidth() - sliderInputSpacing
        end
    end

    local uiArea = CreateFrame("Frame", nil, row)
    uiArea:SetPoint("LEFT", label, "RIGHT", spacing, 0)
    uiArea:SetSize(uiAreaWidth, rowHeight)

    local control
    local contentOffset = 0 -- Variable to track vertical offset for content alignment

    if controlType == "checkbox" then
        control = CreateCustomCheckbox(uiArea, "")
        control:SetSize(checkboxSize, checkboxSize)
        control:SetPoint("LEFT", uiArea, "LEFT", 0, 0)
        if controlParams.value ~= nil then
            control:SetValue(controlParams.value)
        end
        if controlParams.onValueChanged then
            control.OnValueChanged = controlParams.onValueChanged
        end

	elseif controlType == "slider" then
		local sliderRowHeight = controlParams.hasMarkers and 70 or 50
		row:SetHeight(sliderRowHeight)
		uiArea:SetHeight(sliderRowHeight)
		contentOffset = (sliderRowHeight - rowHeight) / 2

		label:ClearAllPoints()
		label:SetPoint("LEFT", row, "LEFT", leftMargin, contentOffset)
		
		-- Slider With Markers Support
		control = mQoL_Styles.CreateCustomSlider(
			uiArea,
			"",     -- No label on slider itself
			controlParams.min,
			controlParams.max,
			controlParams.step,
			maxControlWidth,
			sliderHeight,
			controlParams.hasMarkers and controlParams.markers or nil  -- Only pass markers if hasMarkers is true
		)
		control:SetPoint("LEFT", uiArea, "LEFT", 0, 0)

		-- Adjust slider width if there are extra elements
		local sliderWidth = maxControlWidth
		if extra and #extra > 0 then
			local totalExtraWidth = 0
			for _, frame in ipairs(extra) do
				totalExtraWidth = totalExtraWidth + frame:GetWidth() + sliderInputSpacing
			end
			sliderWidth = sliderWidth - totalExtraWidth
			if sliderWidth < 20 then sliderWidth = 20 end
		end
		control:SetWidth(sliderWidth)

		-- Set initial value
		if controlParams.value then
			control:SetValue(controlParams.value)
		end

		-- OnValueChanged handler
		if controlParams.onValueChanged then
			control:SetScript("OnValueChanged", function(self, value)
				controlParams.onValueChanged(self, value)
				self:UpdateThumb()
				self:UpdateMarkers() -- Update markers if present
			end)
		end

		-- Additional elements next to slider (e.g., Apply button)
		if extra then
			local prev = control
			for _, frame in ipairs(extra) do
				frame:SetParent(uiArea)
				frame:SetPoint("LEFT", prev, "RIGHT", sliderInputSpacing, 0)
				prev = frame
			end
		end

    elseif controlType == "dropdown" then
        local dropdownWidth = math.min(150, uiAreaWidth or 150)
        control = mQoL_Styles.CreateCustomDropdown(
            uiArea,
            dropdownWidth,
            controlParams.list or {},
            controlParams.value,
            controlParams.onValueChanged
        )
        control:SetPoint("LEFT", uiArea, "LEFT", 0, 0)

        -- Add support for extra elements (buttons) next to dropdown
        if extra then
            local prev = control
            for _, frame in ipairs(extra) do
                frame:SetParent(uiArea)
                frame:SetPoint("LEFT", prev, "RIGHT", sliderInputSpacing, 0)
                prev = frame
            end
        end

    elseif controlType == "inputbox" then
        local width = math.min(controlParams.width or 150, uiAreaWidth)
        control = CreateCustomInputBox(uiArea)
        control:SetSize(width, inputHeight)
        control:SetPoint("LEFT", uiArea, "LEFT", 0, 0)

        control.bg = control:CreateTexture(nil, "BACKGROUND")
        control.bg:SetAllPoints()
        control.bg:SetColorTexture(0.15, 0.15, 0.15, 1)

        if mQoL_Templates and mQoL_Templates.CreateFrameBorder then
            control.border = mQoL_Templates.CreateFrameBorder(control, 1, {0.25, 0.25, 0.25, 1})
        end

        if controlParams.text then
            control:SetText(controlParams.text)
        end

        if controlParams.onEnterPressed then
            control:SetScript("OnEnterPressed", function(self)
                controlParams.onEnterPressed(self)
                self:ClearFocus()
            end)
        end

        -- Add support for extra elements (buttons) next to inputbox
        if extra then
            local prev = control
            for _, frame in ipairs(extra) do
                frame:SetParent(uiArea)
                frame:SetPoint("LEFT", prev, "RIGHT", sliderInputSpacing, 0)
                prev = frame
            end
        end

	elseif controlType == "editableList" then
		local list = controlParams.list or {}
		local maxEntries = controlParams.maxEntries or #list
		local editableListWidth = controlParams.width or 140
		local editableListHeight = controlParams.entryHeight or 22
		local editableListSpacing = controlParams.entrySpacing or 2
		local labelSpacing = controlParams.labelSpacing or 5
		local yOffset = controlParams.yOffset or 0
		local applyButtonHeight = 22
		local applyButtonSpacing = 5

		-- calculating row height
		local rowHeightList = maxEntries * (editableListHeight + editableListSpacing) + labelSpacing + applyButtonHeight + applyButtonSpacing
		row:SetHeight(rowHeightList)

		-- Repositioning label
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", row, "TOPLEFT", leftMargin, -yOffset)

		-- Creating editable list container
		control = CreateFrame("Frame", nil, row)
		control:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -labelSpacing)
		control:SetSize(editableListWidth, maxEntries * (editableListHeight + editableListSpacing))

		local editboxes = {}
		local entryYOffset = 0
		for i = 1, maxEntries do
			local editbox = mQoL_Styles.CreateCustomInputBox(control, editableListWidth, editableListHeight, function(self)
				local text = self:GetText():trim()
				if text ~= "" then
					list[i] = text
				else
					list[i] = nil
				end
				if controlParams.onEnterPressed then
					controlParams.onEnterPressed(list)
				end
			end)
			editbox:SetPoint("TOPLEFT", control, "TOPLEFT", 0, entryYOffset)
			editbox:SetText(list[i] or "")
			entryYOffset = entryYOffset - (editableListHeight + editableListSpacing)
			editboxes[i] = editbox
		end

		-- Save Button
		local saveButton = mQoL_Styles.CreateCustomButton(row, "Save", 100, applyButtonHeight)
		saveButton:SetPoint("TOPLEFT", control, "BOTTOMLEFT", 0, -applyButtonSpacing)
		saveButton:SetScript("OnClick", function()
			if controlParams.onApply then
				controlParams.onApply(list)
			end
		end)
	end

	-- Apply Button (change position based on control type)
	if applyFunc then
		local customLabel = controlParams.applyLabel or "Apply" -- use custom label if provided
		local customWidth = controlParams.applyWidth or buttonWidth -- use custom width if provided
		
		-- Adjust height for different control types
		local applyBtnHeight = inputHeight
		if controlType == "slider" then
			applyBtnHeight = buttonHeight  -- standard button height for sliders
		end
		
		local applyBtn = CreateCustomButton(row, customLabel)
		applyBtn:SetSize(customWidth, applyBtnHeight)  -- set size with custom width and height

		if controlType == "editableList" then
			applyBtn:SetPoint("TOPLEFT", control, "BOTTOMLEFT", 0, -5)
		else
			applyBtn:SetPoint("RIGHT", row, "RIGHT", -rightMargin, contentOffset)
			applyBtn:ClearAllPoints()
			applyBtn:SetPoint("RIGHT", row, "RIGHT", -rightMargin, contentOffset)
		end

		applyBtn:SetScript("OnClick", function()
			if controlType == "editableList" then
				local list = controlParams.list or {}
				for i, editbox in ipairs(control:GetChildren()) do
					if editbox.GetText then
						local text = editbox:GetText():trim()
						if text ~= "" then
							list[i] = text
						else
							list[i] = nil
						end
					end
				end
				if controlParams.onApply then
					controlParams.onApply(list)
				end
			elseif controlType == "inputbox" then
				if controlParams.onEnterPressed then
					controlParams.onEnterPressed(control)
				end
				control:ClearFocus()
			else
				applyFunc()
			end
		end)
	end

    -- Positioning the row
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", -10, parent.currentY or -70)

    local spacingToApply = betweenOptionsSpacing

    parent.currentY = (parent.currentY or -70) - row:GetHeight() - spacingToApply
    parent._mQoL_LastGapType = nil
    parent._mQoL_LastGapSize = nil
    parent._mQoL_LastGapCount = nil

    return row, control
end

function mQoL_Hub.NormalizeTriState(value)
    if value == "disable" then
        return "disable"
    elseif value == true then
        return true
    else
        return false
    end
end

function mQoL_Hub:GetIntroVersionKey(version)
    if type(version) ~= "string" then return version end
    local major, minor = version:match("^(%d+)%.(%d+)")
    if major and minor then
        return major .. "." .. minor
    end
    return version
end

-- HOME PANEL
function mQoL_Hub:CreateHomePanel(parent)
    local scrollFrame, scrollChild = mQoL_Templates.CreateScrollPanel(parent, { width = 850, height = 600 })
    
    -- Intro Logic
    local shouldShowIntro = false
    local lastSeenVersion = self.db.home and self.db.home.introSeen
    local currentVersion = mQoL_Hub.version or "1.0.0"
    local lastSeenKey = self:GetIntroVersionKey(lastSeenVersion)
    local currentKey = self:GetIntroVersionKey(currentVersion)

    -- Show if never seen OR if version changed
    if lastSeenKey ~= currentKey then
        shouldShowIntro = true
    end

    if shouldShowIntro then
        -- Pass scrollFrame as parent for intro, scrollChild as content to reveal
        self:RunHomeIntro(scrollFrame, scrollChild)
    end
    
    local panel = scrollChild
    local currentY = -20

    -- Replay Intro Button (Top Right)
    local replayBtn = mQoL_Styles.CreateCustomButton(panel, "Play Intro Again", 140, 24)
    replayBtn:SetPoint("TOPRIGHT", -60, -20)
    replayBtn:SetScript("OnClick", function()
        mQoL_Hub:RunHomeIntro(scrollFrame, scrollChild)
    end)

    -- Welcome Title (Centered with Separator)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, currentY)
    title:SetText("Welcome to mQoL 1.2.0")
    title:SetTextColor(1, 0.82, 0)
    title:SetJustifyH("CENTER")
    currentY = currentY - 30

    -- Separator under title
    local titleSeparator = panel:CreateTexture(nil, "ARTWORK")
    titleSeparator:SetColorTexture(1, 1, 1, 0.3)
    titleSeparator:SetPoint("TOPLEFT", 20, currentY)
    titleSeparator:SetSize(770, 1)
    currentY = currentY - 30

    -- What's New Section
    local newsTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    newsTitle:SetPoint("TOPLEFT", 20, currentY)
    newsTitle:SetText("What's New in v1.2.0?")
    newsTitle:SetTextColor(0.3, 0.7, 1)
    currentY = currentY - 30

    local function AddBulletPoint(text)
        local textFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        textFS:SetPoint("TOPLEFT", 45, currentY)
        textFS:SetWidth(760)
        textFS:SetJustifyH("LEFT")
        textFS:SetText(text)
        
        local bullet = panel:CreateTexture(nil, "ARTWORK")
        bullet:SetSize(6, 6)
        bullet:SetPoint("RIGHT", textFS, "LEFT", -6, 0)
        bullet:SetColorTexture(1, 1, 1, 0.8)
        
        currentY = currentY - textFS:GetStringHeight() - 10
    end

    AddBulletPoint("Dungeon Teleports: New tab in Group Finder for easy access to teleports, seasons support and detailed tooltips.")
    AddBulletPoint("Account Overview: New panel displaying a list of all your characters and an interactive Gold Chart.")
    AddBulletPoint("Great Vault Preview: See Great Vault of your other characters without character switching.")
    AddBulletPoint("Party Keystones: View keystones of your party members and quickly list keystone.")
    AddBulletPoint("New QoL Options: Added settings for Auto Push Spell To Action Bar, and Auto Self Cast.")
    AddBulletPoint("Fast Auto Loot: Much faster auto loot option with customizable delay.")
    AddBulletPoint("Edit Mode Backups: Automatically creates and keeps up to 5 backups of your UI profiles upon login.")
    AddBulletPoint("Miscellaneous: Better combat protection for UI elements, simplified intro, and general improvements.")
    
    currentY = currentY - 20

    -- Available Commands Section
    local cmdTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cmdTitle:SetPoint("TOPLEFT", 20, currentY)
    cmdTitle:SetText("Available Commands")
    cmdTitle:SetTextColor(0.3, 0.7, 1)
    currentY = currentY - 30

    local function AddCommand(cmd, desc)
        local cmdFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cmdFS:SetPoint("TOPLEFT", 30, currentY)
        cmdFS:SetText(cmd)
        cmdFS:SetTextColor(1, 0.82, 0)
        
        local descFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        descFS:SetPoint("LEFT", cmdFS, "RIGHT", 10, 0)
        descFS:SetText("- " .. desc)
        
        currentY = currentY - cmdFS:GetStringHeight() - 8
    end

    AddCommand("/mQoL", "Open the main menu")
    AddCommand("/mqv", "Check party members mQoL version")

    currentY = currentY - 20

    -- Did You Know? Section
    local tipsTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tipsTitle:SetPoint("TOPLEFT", 20, currentY)
    tipsTitle:SetText("Did You Know?")
    tipsTitle:SetTextColor(0.3, 0.7, 1)
    currentY = currentY - 30

    local function AddTip(text)
        local textFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        textFS:SetPoint("TOPLEFT", 45, currentY)
        textFS:SetWidth(760)
        textFS:SetJustifyH("LEFT")
        textFS:SetText(text)
        
        local bullet = panel:CreateTexture(nil, "ARTWORK")
        bullet:SetSize(4, 4)
        bullet:SetPoint("RIGHT", textFS, "LEFT", -6, 0)
        bullet:SetColorTexture(1, 0.82, 0, 0.8)
        
        currentY = currentY - textFS:GetStringHeight() - 8
    end

    AddTip("You can right-click the minimap button to quickly open the Version Checker.")
    AddTip("You can use the search bar in the side menu to instantly find any setting.")
    AddTip("Some options have a third state (disabled). This prevents the addon from modifying that specific setting.")

    -- Update scroll height (content + footer space)
    local footerHeight = 100
    local contentHeight = math.abs(currentY)
    local totalHeight = math.max(contentHeight + footerHeight, 600)
    scrollChild:SetHeight(totalHeight)

    -- Separator
    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(1, 1, 1, 0.15)
    separator:SetPoint("BOTTOMLEFT", 20, 80)
    separator:SetSize(770, 1)

    -- Footer Text
    local footerText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    footerText:SetPoint("TOP", separator, "BOTTOM", 0, -15)
    footerText:SetWidth(770)
    footerText:SetJustifyH("CENTER")
    footerText:SetText("mQoL is constantly evolving. Stay tuned for more updates!")

    if scrollFrame.scrollbar and scrollFrame.scrollbar.UpdateScrollbar then
        scrollFrame.scrollbar:UpdateScrollbar()
    end

    return scrollFrame
end

mQoL_Hub:RegisterModuleOptions(nil, "Home", function(parent) return mQoL_Hub:CreateHomePanel(parent) end)

function mQoL_Hub:CreateAboutPanel(parent)
    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "About", nil, "TopSeparator")

    local header = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 20, contentContainer.currentY)
    header:SetWidth(770)
    header:SetJustifyH("LEFT")
    header:SetTextColor(0.3, 0.7, 1)
    header:SetText("Contact & Support")
    contentContainer.currentY = contentContainer.currentY - (header:GetStringHeight() + 14)

    local function CreateCopyableLinkRow(labelText, valueText, y)
        local rowWidth = 770
        local labelWidth = 150
        local gap = 14

        local row = CreateFrame("Frame", nil, contentContainer)
        row:SetSize(rowWidth, 28)
        row:SetPoint("TOPLEFT", 20, y)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetWidth(labelWidth)
        label:SetJustifyH("LEFT")
        label:SetText(labelText or "")

        local editBoxWidth = rowWidth - labelWidth - gap
        local editBox = CreateCustomInputBox(row, editBoxWidth, 26)
        editBox:SetPoint("LEFT", label, "RIGHT", gap, 0)
        editBox:SetText(valueText or "")
        editBox:SetCursorPosition(0)

        local locked = false
        editBox:SetScript("OnTextChanged", function(self, userInput)
            if locked then return end
            if userInput then
                locked = true
                self:SetText(valueText or "")
                self:SetCursorPosition(0)
                self:HighlightText()
                locked = false
            end
        end)
        editBox:SetScript("OnEditFocusGained", function(self)
            self:HighlightText()
        end)
        editBox:SetScript("OnEditFocusLost", function(self)
            self:HighlightText(0, 0)
            self:SetCursorPosition(0)
        end)
        editBox:SetScript("OnMouseUp", function(self)
            self:SetFocus()
            self:HighlightText()
        end)

        return y - 34
    end

    contentContainer.currentY = CreateCopyableLinkRow("Discord", "@Mentiuszen", contentContainer.currentY)
    contentContainer.currentY = CreateCopyableLinkRow("GitHub Repo", "https://github.com/Mentiuszen/mQoL", contentContainer.currentY)
    contentContainer.currentY = CreateCopyableLinkRow("Bug Reports", "https://github.com/Mentiuszen/mQoL/issues", contentContainer.currentY)
    contentContainer.currentY = contentContainer.currentY - 20

    local footerHeight = 100
    local _, _, _, _, containerYOffset = contentContainer:GetPoint()
    containerYOffset = containerYOffset or 0
    local contentHeight = math.abs(containerYOffset) + math.abs(contentContainer.currentY or 0)
    local minHeight = (scrollFrame and scrollFrame:GetHeight()) or 0
    local totalHeight = math.max(contentHeight + footerHeight, minHeight)
    panel:SetHeight(totalHeight)

    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(1, 1, 1, 0.15)
    separator:SetPoint("BOTTOMLEFT", 20, 80)
    separator:SetSize(770, 1)

    local authorText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    authorText:SetPoint("TOP", separator, "BOTTOM", 0, -15)
    authorText:SetWidth(770)
    authorText:SetJustifyH("CENTER")
    authorText:SetText("Created by Mentiuszen-KulTiras (EU)")

    panel.UpdateScrollChildHeight = function()
        local _, _, _, _, cY = contentContainer:GetPoint()
        cY = cY or 0
        local cH = math.abs(cY) + math.abs(contentContainer.currentY or 0)
        local minH = (scrollFrame and scrollFrame:GetHeight()) or 0
        panel:SetHeight(math.max(cH + footerHeight, minH))
        if scrollFrame.scrollbar and scrollFrame.scrollbar.UpdateScrollbar then
            scrollFrame.scrollbar:UpdateScrollbar()
        end
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

mQoL_Hub:RegisterModuleOptions(nil, "About", function(parent) return mQoL_Hub:CreateAboutPanel(parent) end)

-- PANEL DISPLAY
function mQoL_Hub:CreateDisplayPanel(parent)
    local scrollFrame, panel, contentContainer, infoButton, explanationFrame = mQoL_Templates.CreateStandardOptionsPanel(parent, "General Settings - Display", {
        text = "About Addon Window Customization",
        textColor = {1, 0.82, 0},
        explanation = "Control the overall appearance of the mQoL interface.\nThese settings only control the appearance of the addon window.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "TopSeparator")
    local AddGap = mQoL_Templates.AddGap

    -- Minimap Button
    self:AddOptionRow(contentContainer, "Hide Minimap Button", "checkbox", {
        value = self.db.minimap.hide,
        onValueChanged = function(_, value)
            self.db.minimap.hide = value
            if value then
                LibStub("LibDBIcon-1.0"):Hide("mQoL_Hub")
            else
                LibStub("LibDBIcon-1.0"):Show("mQoL_Hub")
            end
        end
    })
    AddGap(contentContainer, "BottomSeparator")

	-- Window Scale
	local scaleMin, scaleMax, scaleStep = 0.5, 1.5, 0.05
	local currentScale = (self.db.display and self.db.display.scale) or self.defaults.display.scale

	-- Input Box
	local scaleEditBox = CreateCustomInputBox(contentContainer)
	scaleEditBox:SetSize(60, 24)
	scaleEditBox.bg = scaleEditBox:CreateTexture(nil, "BACKGROUND")
	scaleEditBox.bg:SetAllPoints()
	scaleEditBox.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
	scaleEditBox.border = mQoL_Templates.CreateFrameBorder(scaleEditBox, 1, {0.25, 0.25, 0.25, 1})

	-- Slider + row
	local scaleApplyFunc -- Declarate variable for Apply function
	local scaleRow, scaleSlider = self:AddOptionRow(contentContainer, "Window Scale", "slider", {
		value = currentScale,
		min = scaleMin,
		max = scaleMax,
		step = scaleStep,
		applyLabel = "Apply Scale",
		applyWidth = 120,
		onValueChanged = function(_, value)
			-- Update input box when slider changes
			scaleEditBox:SetText(string.format("%.2f", value))
		end
	}, {scaleEditBox}, function()
		scaleApplyFunc() -- Use returned function
	end)

	-- Initial value for the input box
	scaleEditBox:SetText(string.format("%.2f", currentScale))
	scaleEditBox.slider = scaleSlider

	-- Synchronizing input box with slider and Enter key
	scaleApplyFunc = self:SetupNumberInputBox(scaleEditBox, scaleSlider, scaleMin, scaleMax, scaleStep, function(val)
		self.db.display.scale = val
		if self.MainFrame then
			self.MainFrame:SetScale(val)
		end
	end)

	-- Window Opacity
	local opacityEditBox = CreateCustomInputBox(contentContainer)
	opacityEditBox:SetSize(60, 24)
	opacityEditBox.bg = opacityEditBox:CreateTexture(nil, "BACKGROUND")
	opacityEditBox.bg:SetAllPoints()
	opacityEditBox.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
	opacityEditBox.border = mQoL_Templates.CreateFrameBorder(opacityEditBox, 1, {0.25, 0.25, 0.25, 1})

	local defaultOpacity = (self.db.display and self.db.display.opacity) or self.defaults.display.opacity
	local function ApplyOpacity(alpha)
		local function ApplyTexture(tex)
			if not tex or not tex.SetAlpha then return end
			local baseAlpha = tex.mQoL_baseAlpha
			if type(baseAlpha) ~= "number" then baseAlpha = 1 end
			local finalAlpha = baseAlpha * alpha
			if finalAlpha > 1 then finalAlpha = 1 end
			if finalAlpha < 0 then finalAlpha = 0 end
			tex:SetAlpha(finalAlpha)
		end

		if self.MainFrame then
			ApplyTexture(self.MainFrame.bg)
			if self.MainFrame.titleBar then
				ApplyTexture(self.MainFrame.titleBar.bg)
			end
			if self.MainFrame.borderFrame then
				local bf = self.MainFrame.borderFrame
				ApplyTexture(bf.top)
				ApplyTexture(bf.bottom)
				ApplyTexture(bf.left)
				ApplyTexture(bf.right)
			end
		end

		if self.sidebar then
			ApplyTexture(self.sidebar.bg)
			if self.sidebar.searchFrame then
				ApplyTexture(self.sidebar.searchFrame.bg)
			end
			if self.sidebar.resultsFrame then
				ApplyTexture(self.sidebar.resultsFrame.bg)
			end
		end
	end
	ApplyOpacity(defaultOpacity)

	local opacityApplyFunc -- Declarate variable for Apply function
	local opacityRow, opacitySlider = self:AddOptionRow(contentContainer, "Window Opacity", "slider", {
		value = defaultOpacity,
		min = 0.50,
		max = 1.00,
		step = 0.05,
		applyLabel = "Apply Opacity",
		applyWidth = 120,
		onValueChanged = function(_, value)
			opacityEditBox:SetText(string.format("%.2f", value))
		end
	}, {opacityEditBox}, function()
		opacityApplyFunc() -- Use returned function
	end)

	opacityEditBox:SetText(string.format("%.2f", defaultOpacity))
	if opacitySlider and opacitySlider.GetValue then
		opacitySlider:SetValue(defaultOpacity)
	end
	opacityEditBox.slider = opacitySlider
	
	-- Synchronizing input box with slider and Enter key
	opacityApplyFunc = self:SetupNumberInputBox(opacityEditBox, opacitySlider, 0.5, 1.0, 0.05, function(val)
		self.db.display.opacity = val
		ApplyOpacity(val)
	end)
    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

-- SIDE PANEL STRUCTURE
local PANEL_STRUCTURE = {
    ["Overview"] = {
        "Home",
        "Account Overview",
        "About",
    },
    ["General Settings"] = {
        "Display",
        "Modules",
        "Profiles",
    },
    ["Quality of Life Settings"] = {
        "General QoL",
        "Nameplates",
        "Action Bars",
		"Mailbox",
        "Raid Profiles",
        "Edit Mode",
    },
    ["Custom Features"] = {
        "Graphics",
		"Blizzard Fixes",
    },
}

function mQoL_Hub.CreateInfoSection(parent, yOffset, opts)
    opts = opts or {}
    local text = opts.text or "What do these options do?"
    local textColor = opts.textColor or {1, 0.82, 0}
    local explanationText = opts.explanation or "These options adjust various quality of life settings."
    local explanationColor = opts.explanationColor or {1, 1, 1}
    local width = opts.width or 770
    local iconTexture = opts.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    local animDuration = opts.animDuration or 0.5

    -- Info button
    local infoButton = CreateFrame("Button", nil, parent)
    infoButton:SetSize(width, 20)
    infoButton:SetPoint("TOPLEFT", 20, yOffset)

    local icon = infoButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", infoButton, "LEFT", 0, 0)
    icon:SetTexture(iconTexture)

    local infoText = infoButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    infoText:SetText(text)
    infoText:SetTextColor(unpack(textColor))
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(false)

    local arrow = infoButton:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetPoint("LEFT", infoText, "RIGHT", 4, 0)
    arrow:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Down")
    infoButton.arrow = arrow

    -- Explanation frame (mask)
    local explanationFrame = CreateFrame("Frame", nil, parent)
    explanationFrame:SetPoint("TOPLEFT", infoButton, "BOTTOMLEFT", 0, -4)
    explanationFrame:SetSize(width, 0) -- start hidden
    explanationFrame:Hide()
    explanationFrame:SetClipsChildren(true)

    -- FontString inside explanationFrame
    local explanationFS = explanationFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    explanationFS:SetPoint("TOPLEFT", 0, 0)
    explanationFS:SetJustifyH("LEFT")
    explanationFS:SetJustifyV("TOP")
    explanationFS:SetText(explanationText)
    explanationFS:SetTextColor(unpack(explanationColor))
    explanationFS:SetWidth(width)
    explanationFS:SetWordWrap(true)

    local expanded = false
    local fullHeight = 0 
    local templateSpacing = mQoL_Templates and mQoL_Templates.Spacing or nil
    local baseOffsetCollapsed = opts.contentOffsetCollapsed or (templateSpacing and templateSpacing.InfoCollapsedOffset) or 28
    local baseOffsetExpanded = opts.contentOffsetExpanded or (templateSpacing and templateSpacing.InfoExpandedOffset) or 32

    local function SmoothScroll(frame, from, to, duration, onUpdate)
        local elapsed = 0
        frame:SetHeight(from)
        frame:Show()
        frame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local progress = math.min(elapsed / duration, 1)
            local eased = (1 - math.cos(progress * math.pi)) / 2
            local height = from + (to - from) * eased
            frame:SetHeight(height)
            if onUpdate then onUpdate(height) end
            if progress >= 1 then
                frame:SetHeight(to)
                frame:SetScript("OnUpdate", nil)
                if onUpdate then onUpdate(to) end
            end
        end)
    end

    infoButton:SetScript("OnClick", function()
        expanded = not expanded
        arrow:SetTexture(expanded 
            and "Interface\\AddOns\\mQoL\\Media\\Textures\\Up"
            or "Interface\\AddOns\\mQoL\\Media\\Textures\\Down")

        -- Save scroll position BEFORE animation starts
        local scrollFrame = parent:GetParent()
        local savedScroll = 0
        if scrollFrame and scrollFrame.GetVerticalScroll then
            savedScroll = scrollFrame:GetVerticalScroll()
        end

        if expanded then
            -- Lazy calc height
            explanationFS:SetWidth(width)
            fullHeight = explanationFS:GetStringHeight() + 10
            
            explanationFrame:Show()
            SmoothScroll(explanationFrame, 0, fullHeight, animDuration, function(h)
                if parent.contentContainer then
                    parent.contentContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset - h - baseOffsetExpanded)
                end
                -- Update scrollChild height when info section expands, pass current expansion height
                if parent.UpdateScrollChildHeight then
                    parent.UpdateScrollChildHeight(h)
                end
                -- Restore scroll position (clamped to new max) and sync scrollbar
                if scrollFrame and scrollFrame.SetVerticalScroll then
                    local scrollChild = scrollFrame:GetScrollChild()
                    if scrollChild then
                        local contentHeight = scrollChild:GetHeight()
                        local frameHeight = scrollFrame:GetHeight()
                        local maxScroll = math.max(0, contentHeight - frameHeight)
                        local clampedScroll = math.min(savedScroll, maxScroll)
                        scrollFrame:SetVerticalScroll(clampedScroll)
                        -- Sync scrollbar slider value
                        if scrollFrame.scrollbar then
                            scrollFrame.scrollbar:SetValue(clampedScroll)
                        end
                    end
                end
            end)
        else
            -- Collapsing
            local startHeight = fullHeight > 0 and fullHeight or explanationFrame:GetHeight()
             SmoothScroll(explanationFrame, startHeight, 0, animDuration, function(h)
                if parent.contentContainer then
                    local offset = (h and h > 0) and baseOffsetExpanded or baseOffsetCollapsed
                    parent.contentContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset - h - offset)
                end
                -- Update scrollChild height when info section collapses, pass current expansion height
                if parent.UpdateScrollChildHeight then
                    parent.UpdateScrollChildHeight(h)
                end
                -- Restore scroll position (clamped to new max) and sync scrollbar
                if scrollFrame and scrollFrame.SetVerticalScroll then
                    local scrollChild = scrollFrame:GetScrollChild()
                    if scrollChild then
                        local contentHeight = scrollChild:GetHeight()
                        local frameHeight = scrollFrame:GetHeight()
                        local maxScroll = math.max(0, contentHeight - frameHeight)
                        local clampedScroll = math.min(savedScroll, maxScroll)
                        scrollFrame:SetVerticalScroll(clampedScroll)
                        -- Sync scrollbar slider value
                        if scrollFrame.scrollbar then
                            scrollFrame.scrollbar:SetValue(clampedScroll)
                        end
                    end
                end
                if h <= 0 then 
                    explanationFrame:Hide()
                end
            end)
        end
    end)

    local newYOffset = yOffset - baseOffsetCollapsed
    return newYOffset, infoButton, explanationFrame
end

--Build 162 - fix active button update
function mQoL_Hub:SetActiveSidebarButton(panelName)
    if not self.sidebar or not self.sidebar.categoryBlocks then return end
    local categoryBlocks = self.sidebar.categoryBlocks

    for _, block in pairs(categoryBlocks) do
        for _, btn in ipairs(block.buttons) do
            if btn.panelName == panelName or btn.text:GetText() == panelName then
                -- expand category if collapsed
                if not block.expanded and block.arrow and block.arrow.Click then
                    block.arrow:Click()
                end
                -- deselect previous
                if self.sidebar.activeButton and self.sidebar.activeButton ~= btn then
                    self.sidebar.activeButton.text:SetTextColor(1, 1, 1)
                end
                -- select new
                btn.text:SetTextColor(0.3, 0.7, 1)
                self.sidebar.activeButton = btn
                return
            end
        end
    end
end

function mQoL_Hub:CreateSidePanel(parent)
    local sidebar = CreateFrame("Frame", "mQoL_Hub_Sidebar", parent)
    sidebar:SetSize(220, 600)
    sidebar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -32)

    sidebar.bg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebar.bg:SetAllPoints()
    sidebar.bg:SetColorTexture(0.10, 0.10, 0.10, 1.0)
	sidebar.bg.mQoL_baseAlpha = 1.0

    -- Smooth Height Animation
	local function SmoothHeight(frame, from, to, duration, onUpdate, updateButtons)
		local elapsed = 0
		local heightDiff = to - from
		frame:SetHeight(from)
		frame:SetScript("OnUpdate", function(self, delta)
			elapsed = elapsed + delta
			local progress = math.min(elapsed / duration, 1)
			local eased = (1 - math.cos(progress * math.pi)) / 2
			local current = from + heightDiff * eased
			frame:SetHeight(current)

			if updateButtons then
				updateButtons(current)
			end
			if onUpdate then onUpdate() end
			
			if not frame or not frame:IsShown() then
				self:SetScript("OnUpdate", nil)
				return
			end

			if progress >= 1 then
				self:SetScript("OnUpdate", nil)
				frame:SetHeight(to)
				if updateButtons then
					updateButtons(to)
				end
				if onUpdate then onUpdate() end
			end
		end)
	end

    --Search Bar Frame
    local searchFrame = CreateFrame("Frame", nil, sidebar)
    searchFrame:SetSize(200, 40)
    searchFrame:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, -10)
	sidebar.searchFrame = searchFrame

    searchFrame.bg = searchFrame:CreateTexture(nil, "BACKGROUND")
    searchFrame.bg:SetAllPoints()
    searchFrame.bg:SetColorTexture(0, 0, 0, 0.75)
	searchFrame.bg.mQoL_baseAlpha = 0.75

    local searchBox = CreateFrame("EditBox", nil, searchFrame)
    searchBox:SetPoint("TOPLEFT", 4, -2)
    searchBox:SetPoint("BOTTOMRIGHT", -4, 2)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(34, 4, 0, 0)
	searchBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

    local searchIcon = searchFrame:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(28, 28)
    searchIcon:SetPoint("LEFT", 6, 0)
    searchIcon:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\magnifier")
    searchIcon:SetTexCoord(0, 1, 0, 1)

    local placeholder = searchFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
    placeholder:SetText("Search")
	placeholder:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

	local resultsFrame
	resultsFrame = CreateFrame("Frame", nil, sidebar)
    resultsFrame:SetPoint("TOPLEFT", searchFrame, "BOTTOMLEFT", 0, -2)
    resultsFrame:SetPoint("TOPRIGHT", searchFrame, "BOTTOMRIGHT", 0, -2)
    resultsFrame:SetHeight(50)
    resultsFrame:EnableMouse(true)
    resultsFrame:SetMouseMotionEnabled(true)
    resultsFrame:SetFrameStrata("DIALOG")
    resultsFrame:SetFrameLevel(sidebar:GetFrameLevel() + 10)
    
	local bg = resultsFrame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.85)
	resultsFrame.bg = bg
	resultsFrame.bg.mQoL_baseAlpha = 0.85
	sidebar.resultsFrame = resultsFrame
    resultsFrame:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, resultsFrame)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(200, 1)  -- Width fixed, height will expand
    scrollFrame:SetScrollChild(scrollChild)

    local scrollbar = CreateCustomScrollbar(scrollFrame, scrollChild)

    local resultButtons = {}
	local selectedIndex = nil
	local visibleResultsCount = 0
	
	local function UpdateResultHighlight()
		if not selectedIndex or not resultButtons[selectedIndex] then return end

		for i, btn in ipairs(resultButtons) do
			if i == selectedIndex and btn and btn:IsShown() then
				btn.text:SetTextColor(0.3, 0.7, 1)

				local btnTop = btn:GetTop()
				local btnBottom = btn:GetBottom()
				local scrollTop = scrollFrame and scrollFrame:GetTop()
				local scrollBottom = scrollFrame and scrollFrame:GetBottom()

				local scrollValue = scrollbar and scrollbar:GetValue() or 0

				if btnTop and scrollTop and btnTop > scrollTop then
					local diff = btnTop - scrollTop
					scrollValue = scrollValue - diff
				elseif btnBottom and scrollBottom and btnBottom < scrollBottom then
					local diff = scrollBottom - btnBottom
					scrollValue = scrollValue + diff
				end

				if scrollbar then
					local min, max = scrollbar:GetMinMaxValues()
					if min and scrollValue < min then scrollValue = min end
					if max and scrollValue > max then scrollValue = max end
					scrollbar:SetValue(scrollValue)
				end
			else
				if btn and btn.text then
					btn.text:SetTextColor(1, 1, 1)
				end
			end
		end
	end

    -- KeyDown handling for navigation
	searchBox.Orig_OnKeyDown = searchBox:GetScript("OnKeyDown")
	searchBox:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetText("")
			resultsFrame:Hide()
			self:ClearFocus()
			return
		end

		if resultsFrame:IsShown() then
			if key == "DOWN" then
				if not selectedIndex or selectedIndex >= visibleResultsCount then
					selectedIndex = 1
				else
					selectedIndex = selectedIndex + 1
				end
				UpdateResultHighlight()
			elseif key == "UP" then
				if not selectedIndex or selectedIndex <= 1 then
					selectedIndex = visibleResultsCount
				else
					selectedIndex = selectedIndex - 1
				end
				UpdateResultHighlight()
			elseif key == "ENTER" then
				if selectedIndex then
					local btn = resultButtons[selectedIndex]
					if btn and btn:IsShown() then
						btn:Click()
					end
				end
			end
		end

		if self.Orig_OnKeyDown then
			self.Orig_OnKeyDown(self, key)
		end
	end)

    -- Function to truncate text with ellipsis if too wide
    local function TruncateText(text, maxWidth)
        if not text or text == "" then return text end

        -- Use temporary FontString to test width
        local tempFontString = searchFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tempFontString:SetText(text)

        if tempFontString:GetStringWidth() <= maxWidth then
            tempFontString:SetText("")  -- Clear temporary text
            return text
        end

        local truncated = text
        while truncated ~= "" and tempFontString:GetStringWidth() > maxWidth do
            truncated = truncated:sub(1, -2)  -- Remove last character
            tempFontString:SetText(truncated .. "...")
            if tempFontString:GetStringWidth() <= maxWidth then
                tempFontString:SetText("")  -- Clear temporary text
                return truncated .. "..."
            end
        end

        tempFontString:SetText("")  -- Clear temporary text
        return "..."
    end

    -- OnTextChanged handling
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText():lower()
        placeholder:SetShown(text == "")

        for _, btn in ipairs(resultButtons) do btn:Hide() end

        if text == "" then
            resultsFrame:Hide()
            return
        end

		if scrollbar and scrollbar.UpdateScrollbar then
			scrollbar:UpdateScrollbar()
		end

        local MAX_VISIBLE_RESULTS = 5
        local BUTTON_HEIGHT = 24

        local found = 0
        for _, entry in ipairs(mQoL_Hub.searchIndex) do
			local isModuleLoaded = mQoL_Hub.modules and mQoL_Hub.modules[entry.panel]
            if entry.label:lower():find(text, 1, true) and entry.available and isModuleLoaded then
                found = found + 1
                local btn = resultButtons[found]
                if not btn then
                    btn = CreateFrame("Button", nil, scrollChild)
                    btn:SetSize(160, BUTTON_HEIGHT)
                    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    btn.text:SetPoint("LEFT", 4, 0)
                    btn.text:SetPoint("RIGHT", -20, 0)
                    btn.text:SetWidth(136)  -- Max width for text
                    btn.text:SetJustifyH("LEFT")

					btn:SetScript("OnEnter", function()
						btn.text:SetTextColor(0.3, 0.7, 1)  -- Blue
						UIFrameFadeIn(btn.text, 0.2, btn.text:GetAlpha(), 1)
					end)

					btn:SetScript("OnLeave", function()
						btn.text:SetTextColor(1, 1, 1)  -- White
						UIFrameFadeOut(btn.text, 0.2, btn.text:GetAlpha(), 1) -- slightly transparent
					end)

                    table.insert(resultButtons, btn)
                end

                btn:SetPoint("TOPLEFT", 0, -((found - 1) * BUTTON_HEIGHT))
                
                -- Truncate text if too wide
                local displayText = TruncateText(entry.label, 136)
                btn.text:SetText(displayText)
                btn.text:SetTextColor(1, 1, 1)

				btn:SetScript("OnClick", function()
					searchBox:SetText("")
					resultsFrame:Hide()
					searchBox:ClearFocus()

					if mQoL_Hub.ShowPanel then
						mQoL_Hub:ShowPanel(entry.panel)
						mQoL_Hub:SetActiveSidebarButton(entry.panel)
						C_Timer.After(0.1, function()
							mQoL_Hub:HighlightOption(entry.label)
						end)
					end
				end)

                btn:Show()
            end
        end

		visibleResultsCount = found

		-- set selectedIndex to first result if any
		selectedIndex = (found > 0) and 1 or nil
		UpdateResultHighlight()

        -- Adjust resultsFrame height
        local visibleCount = math.min(found, MAX_VISIBLE_RESULTS)
        scrollChild:SetHeight(found * BUTTON_HEIGHT) -- Set scrollChild height
        resultsFrame:SetHeight(visibleCount * BUTTON_HEIGHT + 8)
        resultsFrame:SetShown(found > 0)

        -- Force scrollbar update after setting height
        if scrollbar and scrollbar.UpdateScrollbar then
            scrollbar:UpdateScrollbar()
        end
    end)

    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "" then
            placeholder:Hide()
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            placeholder:Show()
        end
    end)

    -- Setup Icons and Layout
    local textStartX = 34
    local iconStartX = 10

    local iconTextures = {
        ["Overview"] = "Interface\\AddOns\\mQoL\\Media\\Textures\\house",
        ["General Settings"] = "Interface\\AddOns\\mQoL\\Media\\Textures\\gear",
        ["Quality of Life Settings"] = "Interface\\AddOns\\mQoL\\Media\\Textures\\stars",
        ["Custom Features"] = "Interface\\AddOns\\mQoL\\Media\\Textures\\puzzle",
    }

    local arrowUp = "Interface\\AddOns\\mQoL\\Media\\Textures\\Up"
    local arrowDown = "Interface\\AddOns\\mQoL\\Media\\Textures\\Down"

    local categoryBlocks = {}
    local activeButton = nil

    -- Update Layout Function
	local function UpdateLayout()
		local topOffset = -60				-- upper offset od search box
		local categorySpacing = 15			-- category spacing
		local categoryHeight = 24			-- category label height
		local buttonSpacing = 2				-- spacing between category label and buttons

		local y = topOffset

		for _, category in ipairs({ "Overview", "General Settings", "Quality of Life Settings", "Custom Features" }) do
			local block = categoryBlocks[category]
			if block and #block.buttons > 0 then
				block.container:Show()
				block.buttonsFrame:Show()
				block.container:SetPoint("TOPLEFT", 0, y)
				y = y - categoryHeight - buttonSpacing
				block.buttonsFrame:SetPoint("TOPLEFT", 10, y)
				local buttonsHeight = block.buttonsFrame:GetHeight()
				y = y - buttonsHeight - categorySpacing
			elseif block then
				block.container:Hide()
				block.buttonsFrame:Hide()
			end
		end
	end

    -- Category Label with Expand/Collapse
    local function AddCategoryLabel(name)
        local block = {}
		block.buttons = {}

        local container = CreateFrame("Frame", nil, sidebar)
        container:SetSize(220, 20)

        local icon = container:CreateTexture(nil, "OVERLAY")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", 15, 0)
        icon:SetTexture(iconTextures[name])
        icon:SetTexCoord(0, 1, 0, 1)

        local label = container:CreateFontString(nil, "OVERLAY")
        label:SetFont("Fonts\\FRIZQT__.TTF", 14)
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        label:SetTextColor(1, 0.82, 0)
        label:SetText(name)
        -- Store label reference in panel
        if not parent.optionsLabels then parent.optionsLabels = {} end
        parent.optionsLabels[name] = label

        local arrow = CreateFrame("Button", nil, container)
        arrow:SetSize(14, 14)
        arrow:SetPoint("LEFT", label, "RIGHT", 6, 0)
        arrow.tex = arrow:CreateTexture(nil, "OVERLAY")
        arrow.tex:SetAllPoints()
        arrow.tex:SetTexture(arrowUp)

        local buttonsFrame = CreateFrame("Frame", nil, sidebar)
        buttonsFrame:SetPoint("TOPLEFT", 10, 0)
        buttonsFrame:SetPoint("TOPRIGHT", -10, 0)
        buttonsFrame:SetHeight(24 * (#block.buttons))
        buttonsFrame:SetClipsChildren(true)

        block.container = container
        block.arrow = arrow
        block.buttonsFrame = buttonsFrame
        block.expanded = true
        block.buttons = {}

        categoryBlocks[name] = block

		arrow:SetScript("OnClick", function()
			block.expanded = not block.expanded
			arrow.tex:SetTexture(block.expanded and arrowUp or arrowDown)

			local buttonCount = #block.buttons
			local targetHeight = block.expanded and (24 * buttonCount) or 1

			-- Update button visibility during animation
			local function UpdateButtonVisibility(currentHeight)
				for i, btn in ipairs(block.buttons) do
					local top = (i - 1) * 24
					if top + 24 <= currentHeight then
						btn:Show()
						btn:SetAlpha(1)
						btn:EnableMouse(true)
					elseif top < currentHeight then
						btn:Show()
						btn:SetAlpha((currentHeight - top) / 24)
						btn:EnableMouse(false)
					else
						btn:Hide()
						btn:EnableMouse(false)
					end
				end
			end

			SmoothHeight(
				block.buttonsFrame,
				block.buttonsFrame:GetHeight(),
				targetHeight,
				0.2,
				UpdateLayout,
				UpdateButtonVisibility
			)
		end)

        return block
    end

    -- Sidebar Button
	local function AddSidebarButton(name, block)
		local btn = CreateFrame("Button", nil, block.buttonsFrame)
		btn:SetSize(200, 24)
		btn.panelName = name

		btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		btn.text:SetPoint("LEFT", textStartX - iconStartX, 0)
		btn.text:SetFont("Fonts\\FRIZQT__.TTF", 12)
		btn.text:SetText(name)
		btn.text:SetTextColor(1, 1, 1)
        -- Store label reference in panel
        if not parent.optionsLabels then parent.optionsLabels = {} end
        parent.optionsLabels[name] = btn.text

		-- Hover Effect
		btn:SetScript("OnEnter", function()
			if btn ~= mQoL_Hub.sidebar.activeButton then
				btn.text:SetTextColor(0.3, 0.7, 1)
			end
		end)

		btn:SetScript("OnLeave", function()
			if btn ~= mQoL_Hub.sidebar.activeButton then
				btn.text:SetTextColor(1, 1, 1)
			end
		end)

		-- Click Action
		btn:SetScript("OnClick", function()
			if mQoL_Hub.ShowPanel then
				mQoL_Hub:ShowPanel(name)
			end
			mQoL_Hub:SetActiveSidebarButton(name)
		end)

		btn:Show()
		btn:EnableMouse(true)

		return btn
	end

    -- Build Sidebar Structure
	for _, category in ipairs({ "Overview", "General Settings", "Quality of Life Settings", "Custom Features" }) do
		local block = AddCategoryLabel(category)
		local visibleIndex = 0
		for _, sub in ipairs(PANEL_STRUCTURE[category]) do
			if mQoL_Hub.modules[sub] then
				visibleIndex = visibleIndex + 1
				local btn = AddSidebarButton(sub, block)
				-- set button position
				btn:SetPoint("TOPLEFT", block.buttonsFrame, "TOPLEFT", 0, -24 * (visibleIndex - 1))
				table.insert(block.buttons, btn)
			end
		end
		local buttonCount = #block.buttons
		local height = 24 * buttonCount
		block.buttonsFrame:SetHeight(height)
	end

    UpdateLayout()
	
	sidebar.categoryBlocks = categoryBlocks
	
	-- Left bottom corner - version
	local versionText = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	versionText:SetPoint("BOTTOMLEFT", 10, 10)
	versionText:SetText("|cffffff00Version:|r " .. (mQoL_Hub.version or "?"))
	versionText:SetFont("Fonts\\FRIZQT__.TTF", 10)

	-- Right bottom corner - build
	local buildText = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	buildText:SetPoint("BOTTOMRIGHT", -10, 10)
	buildText:SetText("|cffffff00Build:|r " .. (mQoL_Hub.build or "?"))
	buildText:SetFont("Fonts\\FRIZQT__.TTF", 10)
	
    return sidebar, searchBox
end

function mQoL_Hub:CreateMainPanel()
    local f = CreateFrame("Frame", "mQoL_Hub_MainFrame", UIParent)
    self.MainFrame = f
    table.insert(UISpecialFrames, f:GetName())
    f:SetScale((self.db.display and self.db.display.scale) or 1.0)
    f:SetSize(1070, 632)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:Hide()
	f:HookScript("OnHide", function()
		if mQoL_Styles and mQoL_Styles.HideAllDropdownLists then
			mQoL_Styles.HideAllDropdownLists()
		end
	end)
    f:HookScript("OnShow", function()
        local accountOverview = _G["mQoL_AccountOverview"]
        if accountOverview and accountOverview.ResetGoldRangeForHubOpen then
            accountOverview:ResetGoldRangeForHubOpen()
        end
    end)

    -- Background
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetColorTexture(0.05, 0.05, 0.05, 1)
	f.bg.mQoL_baseAlpha = 1.0

    -- Border
    if mQoL_Templates and mQoL_Templates.CreateFrameBorder then
		f.borderFrame = mQoL_Templates.CreateFrameBorder(f, 1, {0.25, 0.25, 0.25, 1})
		if f.borderFrame then
			local baseAlpha = 1
			if f.borderFrame.top then f.borderFrame.top.mQoL_baseAlpha = baseAlpha end
			if f.borderFrame.bottom then f.borderFrame.bottom.mQoL_baseAlpha = baseAlpha end
			if f.borderFrame.left then f.borderFrame.left.mQoL_baseAlpha = baseAlpha end
			if f.borderFrame.right then f.borderFrame.right.mQoL_baseAlpha = baseAlpha end
		end
    end

    -- Initialize panels table
    self.panels = {}

    -- Seperated Sidebar
    self.sidebar, self.searchBox = self:CreateSidePanel(f)

    -- Content Window
    local content = CreateFrame("Frame", "mQoL_Hub_ContentWindow", f)
	self.MainFrame.ContentWindow = content
    content:SetSize(850, 600)
    content:SetPoint("TOPLEFT", "mQoL_Hub_Sidebar", "TOPRIGHT", 0, 0)

	f.bg:ClearAllPoints()
	f.bg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	f.bg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    -- Title Bar
    local titleBar = CreateFrame("Frame", nil, f)
    f.titleBar = titleBar
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(32)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.bg = titleBg
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.08, 0.08, 0.08, 1.0)
	titleBg.mQoL_baseAlpha = 1.2

    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, -1)
    titleText:SetText("mQoL")
    titleText:SetTextColor(1, 0.82, 0)
    titleText:SetShadowColor(0, 0, 0, 0.8)
    titleText:SetShadowOffset(1, -1)

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", -10, 0)
    closeBtn.tex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeBtn.tex:SetAllPoints()
    closeBtn.tex:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Cross")
    closeBtn.tex:SetVertexColor(0.6, 0.6, 0.6)
    closeBtn:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1, 0.2, 0.2) end)
    closeBtn:SetScript("OnLeave", function(self) self.tex:SetVertexColor(0.6, 0.6, 0.6) end)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Content Area
    local contentArea = CreateFrame("Frame", nil, content)
    contentArea:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -20)
    contentArea:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)

    self.ContentArea = contentArea

	-- Generate Panels
	local panels = {}
	for categoryName, subcategories in pairs(PANEL_STRUCTURE) do
		for _, sub in ipairs(subcategories) do
			local panelFunc = mQoL_Hub.modules[sub]
			if panelFunc then
				local panel = panelFunc(contentArea)
				if panel.SetAllPoints then
					panel:SetAllPoints()
				else
					-- For scrollFrames, set position manually
					panel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
					panel:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", 0, 0)
				end
				panel:Hide()
				panels[sub] = panel
			end
		end
	end

	-- ShowPanel
	function self:ShowPanel(name)
		if self.activePanel then
			self.activePanel:Hide()
		end

		local panel = panels[name]
		if not panel then
			self.activePanel = nil
			self.activePanelName = nil
			return
		end
		panel:Show()
		self.activePanel = panel
		self.activePanelName = name  -- Track current panel name for refresh
		
		-- Only initialize optionsLabels if it doesnt exist
		if not self.activePanel.optionsLabels then
			-- Check if this is a scrollFrame with scrollChild
			local scrollChild = panel.GetScrollChild and panel:GetScrollChild()
			if scrollChild and scrollChild.optionsLabels then
				-- Panel is a scrollFrame get optionsLabels from scrollChild
				self.activePanel.optionsLabels = scrollChild.optionsLabels
			else
				-- Regular panel or scrollFrame without optionsLabels
				local mQoL_QoL = _G["mQoL_QoL"]
				local hasQoL = (mQoL_QoL ~= nil)
					and (type(mQoL_QoL.modules) == "table")
					and (type(mQoL_QoL.modules[name]) == "function")
				if hasQoL then
					local ok, modulePanelOrErr = pcall(mQoL_QoL.modules[name], UIParent)
					if ok and type(modulePanelOrErr) == "table" then
						local modulePanel = modulePanelOrErr
						if type(modulePanel.optionsLabels) == "table" then
							self.activePanel.optionsLabels = modulePanel.optionsLabels
						else
							self.activePanel.optionsLabels = {}
						end
						if modulePanel.Hide then modulePanel:Hide() end
						if modulePanel.SetParent then modulePanel:SetParent(nil) end
					else
						self.activePanel.optionsLabels = {}
					end
				else
					self.activePanel.optionsLabels = {}
				end
			end
		end
	end
	
	-- Destroy and recreate current panel to refresh dynamic content
	function self:RefreshCurrentPanel()
		local currentName = self.activePanelName
		if not currentName then return end
		
		-- Destroy current panel and remove from cache
		if self.activePanel then
			self.activePanel:Hide()
			self.activePanel:SetParent(nil)
			self.activePanel = nil
		end
		panels[currentName] = nil  -- Clear from cache to force recreation
		
		-- Get the panel creation function and recreate
		local panelFunc = self.modules[currentName]
		if panelFunc then
			local panel = panelFunc(contentArea)
			if panel then
				if panel.SetAllPoints then
					panel:SetAllPoints()
				else
					panel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
					panel:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", 0, 0)
				end
				panels[currentName] = panel
				panel:Show()
				self.activePanel = panel
				
				-- Update optionsLabels
				local scrollChild = panel.GetScrollChild and panel:GetScrollChild()
				if scrollChild and scrollChild.optionsLabels then
					self.activePanel.optionsLabels = scrollChild.optionsLabels
				end
				
				if scrollChild and scrollChild.UpdateScrollChildHeight then
					scrollChild.UpdateScrollChildHeight()
				elseif panel.UpdateScrollChildHeight then
					panel.UpdateScrollChildHeight()
				end
			end
		end
	end

    -- Default Panel
    local defaultPanel = (PANEL_STRUCTURE["Overview"] and PANEL_STRUCTURE["Overview"][1]) or (PANEL_STRUCTURE["General Settings"] and PANEL_STRUCTURE["General Settings"][1])
    self:ShowPanel(defaultPanel)
	self:SetActiveSidebarButton(defaultPanel)
end

local function CreateButton(parent, text, point, x, y, width, height)
    local btn = mQoL_Templates.CreateButton(parent, text, width, height)
    btn:SetPoint(point, x, y)
    return btn
end

function mQoL_Hub:CreateProfilesPanel(parent)

    local isEnabled = false --Disable profiles tab (this code is anyway not working right now) (Plans for future update maybe 1.2 or later)

	if not isEnabled then
		local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "General Settings - Profiles", {
			text = "How Profiles work?",
			textColor = {1, 0.82, 0},
			explanation = "Profiles are currently disabled. They will be enabled in a future update. \nProfiles will allow you to export and import your settings for different accounts and game versions.",
			explanationColor = {1, 1, 1},
			width = 770,
			icon = "Interface\\Icons\\INV_Misc_QuestionMark",
			animDuration = 0.25
		}, "TopSeparator")
		local AddGap = mQoL_Templates.AddGap

		-- Information Message about unavailability
		local message = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		message:SetPoint("TOPLEFT", 20, contentContainer.currentY)
		message:SetWidth(770)
		message:SetJustifyH("LEFT")
		message:SetText("|cffff0000Profiles are currently unavailable in this version. Profile creation, sharing, and import/export are disabled. \n\nProfiles are planned for a future update.|r")
		AddGap(contentContainer, "Additional", 30)

        -- Removed all code from version 1.0 as its not functional right now and won't be at all after ui rework

		panel.UpdateScrollChildHeight = function()
			mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
		end
		panel.UpdateScrollChildHeight()

		return scrollFrame
	end
end

function mQoL_Hub:ToggleMainPanel()
    if not self.MainFrame then
        self:CreateMainPanel()
    end

    local hubSettings = mQoL_Database:GetSettings("Hub")
    local frameScale = hubSettings.display and hubSettings.display.scale or 1.0

    if self.MainFrame then
        self.MainFrame:SetScale(frameScale)
        if self.MainFrame:IsShown() then
            self.MainFrame:Hide()
        else
            self.MainFrame:Show()
        end
    end
end

local versionPanel

function mQoL_Hub:CreateVersionPanel()
    local f = CreateFrame("Frame", "mQoL_Hub_VersionFrame", UIParent)
    self.VersionFrame = f
    table.insert(UISpecialFrames, f:GetName())

	local function ApplyHubScale()
		local hubSettings = mQoL_Database and mQoL_Database.GetSettings and mQoL_Database:GetSettings("Hub") or nil
		local frameScale = hubSettings and hubSettings.display and hubSettings.display.scale or 1.0
		f:SetScale(frameScale)
	end

    f:SetSize(400, 600)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(50)
    f:Hide()
	ApplyHubScale()
	f:HookScript("OnShow", ApplyHubScale)

    -- Background
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.05, 0.05, 0.05, 1)

    if mQoL_Templates and mQoL_Templates.CreateFrameBorder then
         mQoL_Templates.CreateFrameBorder(f, 1, {0.25, 0.25, 0.25, 1})
    end

    -- Title Bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(32)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.1, 0.1, 0.1, 1)

    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	titleText:SetPoint("CENTER", titleBar, "CENTER", 0, -1)
	titleText:SetText("mQoL Hub Versions")
	titleText:SetTextColor(1, 0.82, 0)
    titleText:SetShadowColor(0, 0, 0, 0.8)
    titleText:SetShadowOffset(1, -1)

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", -10, 0)
    closeBtn.tex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeBtn.tex:SetAllPoints()
    closeBtn.tex:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Cross")
    closeBtn.tex:SetVertexColor(0.6, 0.6, 0.6)
    closeBtn:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1, 0.2, 0.2) end)
    closeBtn:SetScript("OnLeave", function(self) self.tex:SetVertexColor(0.6, 0.6, 0.6) end)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Layout configuration
    local totalWidth = 400
    local leftMargin = 30
    local rightMargin = 30
    local nameWidth = 160
    local vendorWidth = 60
    local versionWidth = 60
    local buildWidth = 60

    -- Header
    f.headerFrame = CreateFrame("Frame", nil, f)
    f.headerFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -40)
    f.headerFrame:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.headerFrame:SetHeight(30)

    f.headerName = f.headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.headerName:SetPoint("LEFT", f.headerFrame, "LEFT", leftMargin + 5, 0)
    f.headerName:SetWidth(nameWidth)
    f.headerName:SetJustifyH("LEFT")
    f.headerName:SetText("Name")

    f.headerVendor = f.headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.headerVendor:SetPoint("LEFT", f.headerFrame, "LEFT", leftMargin + nameWidth, 0)
    f.headerVendor:SetWidth(vendorWidth)
    f.headerVendor:SetJustifyH("LEFT")
    f.headerVendor:SetText("Vendor")

    f.headerVersion = f.headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.headerVersion:SetPoint("LEFT", f.headerFrame, "LEFT", leftMargin + nameWidth + vendorWidth, 0)
    f.headerVersion:SetWidth(versionWidth)
    f.headerVersion:SetJustifyH("LEFT")
    f.headerVersion:SetText("Version")

    f.headerBuild = f.headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.headerBuild:SetPoint("LEFT", f.headerFrame, "LEFT", leftMargin + nameWidth + vendorWidth + versionWidth, 0)
    f.headerBuild:SetWidth(buildWidth)
    f.headerBuild:SetJustifyH("LEFT")
    f.headerBuild:SetText("Build")

    -- Separator
    local sep = f.headerFrame:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.3)
    sep:SetPoint("BOTTOMLEFT", f.headerFrame, "BOTTOMLEFT", leftMargin - 10, -2)
    sep:SetSize(totalWidth - leftMargin - rightMargin - 12, 1)

    -- Scroll Frame below Separator
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f)
    f.scrollFrame:SetPoint("TOPLEFT", f.headerFrame, "BOTTOMLEFT", 0, -5)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)

    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(totalWidth - leftMargin - rightMargin - 12, 1)
    f.content:SetPoint("TOPLEFT")
    f.content:SetPoint("TOPRIGHT")
    f.scrollFrame:SetScrollChild(f.content)

    -- Custom scrollbar
    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        f.customScrollbar = mQoL_Styles.CreateCustomScrollbar(f.scrollFrame, f.content, { thumbWidth = 16 })
    end

    f.rowHeight = 20
    f.colX = {
        name = leftMargin + 5,
        vendor = leftMargin + nameWidth,
        version = leftMargin + nameWidth + vendorWidth,
        build = leftMargin + nameWidth + vendorWidth + versionWidth
    }

    f.columnWidths = {
        name = nameWidth,
        vendor = vendorWidth,
        version = versionWidth,
        build = buildWidth
    }

    f.rows = {}
    return f
end

function mQoL_Hub:RefreshVersionPanel()
    if not self.VersionFrame or not self.VersionData then return end

    local f = self.VersionFrame
    local content = f.content
    local rows = f.rows
    local playerFullName = vreg.NormalizeName(UnitName("player"))

    for _, row in ipairs(rows) do
        row:Hide()
    end

    -- Sort data based on stable criteria
    table.sort(self.VersionData, function(a, b)
        local vreg1 = vreg.hasmark(vreg.NormalizeName(a.name))
        local vreg2 = vreg.hasmark(vreg.NormalizeName(b.name))

        if vreg1 and not vreg2 then return true
        elseif not vreg1 and vreg2 then return false
        elseif vreg.NormalizeName(a.name) == playerFullName then return true
        elseif vreg.NormalizeName(b.name) == playerFullName then return false
        else return a.name < b.name
        end
    end)

    local rowHeight = f.rowHeight or 20
    local colX = f.colX
    local columnWidths = f.columnWidths or { name = 120, vendor = 60, version = 60, build = 60 }

    local y = 0

    for i, entry in ipairs(self.VersionData) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(content:GetWidth(), rowHeight)

            -- Name (Player)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", row, "LEFT", colX.name, 0)
            row.nameText:SetWidth(columnWidths.name)
            row.nameText:SetJustifyH("LEFT")

            -- Vendor (Source of Addon) (Release = CurseForge etc) (Test = Closed Test) (Dev = UNSTABLE PISS OF SHIT CODE THAT BARLY WORKS)
            row.vendorText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.vendorText:SetPoint("LEFT", row, "LEFT", colX.vendor, 0)
            row.vendorText:SetWidth(columnWidths.vendor)
            row.vendorText:SetJustifyH("LEFT")

            -- Version
            row.versionText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.versionText:SetPoint("LEFT", row, "LEFT", colX.version, 0)
            row.versionText:SetWidth(columnWidths.version)
            row.versionText:SetJustifyH("LEFT")

            -- Build
            row.buildText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.buildText:SetPoint("LEFT", row, "LEFT", colX.build, 0)
            row.buildText:SetWidth(columnWidths.build)
            row.buildText:SetJustifyH("LEFT")

            rows[i] = row
        end

        local fullName = entry.name
        -- Clean name for display (remove realm if present, roughly)
        local displayName = fullName:gsub("%-.*$", "")
        
        -- Default to hiding mark
        if row.devMark then row.devMark:Hide() end
        
        if vreg and vreg.hasmark and vreg.NormalizeName then
            if vreg.hasmark(vreg.NormalizeName(fullName)) then
                if not row.devMark then
                    row.devMark = row:CreateTexture(nil, "OVERLAY")
                    row.devMark:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\mark")
                    row.devMark:SetSize(20, 20)
                    row.devMark:SetPoint("LEFT", row, "LEFT", 12, 0)
                end
                row.devMark:Show()
            end
        end

        row.nameText:SetText(displayName)
        
        row.vendorText:SetText(entry.vendor or "")
        row.versionText:SetText(entry.version or "")
        row.buildText:SetText(entry.build or "")

        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        row:Show()

        y = y + rowHeight
    end

    content:SetHeight(math.max(y, 1))
    f.scrollFrame:SetVerticalScroll(0)
    if f.customScrollbar and f.customScrollbar.UpdateScrollbar then
        f.customScrollbar:UpdateScrollbar()
    end
end

function mQoL_Hub:ClearVersionPanel()
	if not self.VersionFrame then return end
    local rows = self.VersionFrame.rows
    if rows then
        for _, row in ipairs(rows) do
            row:Hide()
        end
    end
    self.VersionFrame.rows = {}
	self.VersionData = {}
end

function mQoL_Hub:AddVersionRow(name, vendor, version, build)
	local f = self.VersionFrame
    if not f or not f.content then 
        return 
    end

    -- Check if entry exists, update it
    for i, entry in ipairs(self.VersionData) do
        if entry.name == name then
            entry.vendor = vendor
            entry.version = version
            entry.build = build
            self:RefreshVersionPanel()
            return
        end
    end

    -- Add new entry
    local newEntry = {
        name = name,
        vendor = vendor,
        version = version,
        build = build
    }
    table.insert(self.VersionData, newEntry)

    local rowHeight = f.rowHeight or 20
    local colX = f.colX
    local columnWidths = f.columnWidths or { name = 120, vendor = 60, version = 60, build = 60 }

    local rowIndex = #f.rows + 1
    local rowY = -((rowIndex - 1) * rowHeight)

    local row = CreateFrame("Frame", nil, f.content)
    row:SetSize(f.content:GetWidth(), rowHeight)
    row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, rowY)

    -- Name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", colX.name, 0)
    row.nameText:SetWidth(columnWidths.name)
    row.nameText:SetJustifyH("LEFT")
    
    local displayName = name or ""
    if vreg and vreg.decorate and vreg.NormalizeName then
        displayName = vreg.decorate(vreg.NormalizeName(name), displayName)
    end
    row.nameText:SetText(displayName)

    -- Vendor
    row.vendorText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.vendorText:SetPoint("LEFT", row, "LEFT", colX.vendor, 0)
    row.vendorText:SetWidth(columnWidths.vendor)
    row.vendorText:SetJustifyH("LEFT")
    row.vendorText:SetText(vendor or "")

    -- Version
    row.versionText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.versionText:SetPoint("LEFT", row, "LEFT", colX.version, 0)
    row.versionText:SetWidth(columnWidths.version)
    row.versionText:SetJustifyH("LEFT")
    row.versionText:SetText(version or "")

    -- Build
    row.buildText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.buildText:SetPoint("LEFT", row, "LEFT", colX.build, 0)
    row.buildText:SetWidth(columnWidths.build)
    row.buildText:SetJustifyH("LEFT")
    row.buildText:SetText(build or "")

    table.insert(f.rows, row)

    local contentHeight = #f.rows * rowHeight
    f.content:SetHeight(math.max(contentHeight, f.scrollFrame:GetHeight() or 1))

    self:RefreshVersionPanel()
end

local function RegisterMessagePrefix(prefix)
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    end
end

local function SendAddonMessage(prefix, message, channel, target)
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(prefix, message, channel, target)
    else
        -- Old API fallback
        SendAddonMessage(prefix, message, channel, target)
    end
end

-- Event Handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("CHAT_MSG_PARTY")
eventFrame:RegisterEvent("CHAT_MSG_RAID")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Register Addon Message Prefix
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
        end

        -- Initialize Database
        mQoL_Hub:InitializeDB()

        -- Initialize Minimap
        mQoL_Hub:InitializeMinimap()

        -- Register Options Panels
        if mQoL_Hub.RegisterModuleOptions then
            mQoL_Hub:RegisterModuleOptions("mQoL_Hub_Display", "Display", function(parent)
                return mQoL_Hub:CreateDisplayPanel(parent)
            end)

            mQoL_Hub:RegisterModuleOptions("mQoL_Hub_Profiles", "Profiles", function(parent)
                return mQoL_Hub:CreateProfilesPanel(parent)
            end)
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = arg1, arg2, arg3, arg4
        if prefix ~= ADDON_PREFIX then return end
        
        -- Fix: Safe normalization (pcall due to potential secret value) (Midnight Fix)
        local senderNormalized = sender
        if vreg and vreg.NormalizeName then
            local success, res = pcall(vreg.NormalizeName, sender)
            if not success then return end -- Secret value, ignore
            senderNormalized = res
        end
        
        local playerNormalized = vreg and vreg.NormalizeName and vreg.NormalizeName(UnitName("player")) or UnitName("player")
        
        -- Safe comparison
        local isSelf = false
        local success, res = pcall(function() return senderNormalized == playerNormalized end)
        if not success then return end -- Secret value in comparison
        if res then return end -- Is self

        if msg == "!VREQ" or msg == "!MHVREQ" then
            -- Fix: Include vendor in response (was missing before)
            C_ChatInfo.SendAddonMessage(ADDON_PREFIX,
                "!MHVRESP:" .. (mQoL_Hub.vendor or "unknown") .. ":" .. (mQoL_Hub.version or "unknown") .. ":" .. (mQoL_Hub.build or "unknown"),
                channel)
            return
        end

        -- Fix: Parse vendor from response
        local vendor, version, build = msg:match("^!MHVRESP:(.-):(.-):(.-)$")
        
        -- Backwards compatibility attempt (if needed for old versions sending 2 args)
        if not vendor then
             version, build = msg:match("^!MHVRESP:(.-):(.-)$")
             if version then vendor = "unknown" end
        end

        if version and build then
            local fullName = senderNormalized -- Use normalized name
            mQoL_Hub:AddVersionRow(fullName, vendor, version, build)
        end

    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_WHISPER" then
        local msg, sender = arg1, arg2
        local playerName = UnitName("player")
        
        -- Fix: Use pcall for comparison to safely handle "secret value" (protected strings)
        local success, result = pcall(function() return sender == playerName end)
        if not success then return end
        if result then return end

        local channel = event == "CHAT_MSG_WHISPER" and "WHISPER"
                     or event == "CHAT_MSG_PARTY" and "PARTY"
                     or "RAID"

        if msg == "!mQoLVersion" or msg == "?mQoLVersion" then
            local response = "mQoL Version " .. (mQoL_Hub.version or "unknown") ..
                             " Build " .. (mQoL_Hub.build or "unknown")
            if channel == "WHISPER" then
                SendChatMessage(response, "WHISPER", nil, sender)
            else
                SendChatMessage(response, channel)
            end
            return
        end

    elseif event == "PLAYER_LOGIN" then
        local hubSettings = mQoL_Database:GetSettings("Hub")
        if mQoL_Hub.MainFrame and hubSettings.display then
            mQoL_Hub.MainFrame:SetScale(hubSettings.display.scale or 1.0)
        end
    end
end)