local addonName, L = ...
mQoL_Hub = mQoL_Hub or {}
mQoL_Hub.name = addonName
mQoL_Hub.modules = {}

-- Addon Prefix
local ADDON_PREFIX = "mQoLHub"

local vreg = _G.vreg
mQoL_Hub.VersionData = mQoL_Hub.VersionData or {}

-- Addon Version
mQoL_Hub.version = "1.0.9"
mQoL_Hub.build = "67"
mQoL_Hub.vendor = "release"		--dev / test / release

-- Client Version
local version, build, date, tocversion = GetBuildInfo()
tocversion = tonumber(tocversion) or 0

-- DB version -- NOT USED REMOVED IN 1.1.0
local DB_VERSION = 10

print(string.format("|cffffff00[mQoL Hub]|r |cff00ff00v%s Loaded.|r", mQoL_Hub.version))
print("|cff00ff00Use |cffffff00/mQoL|r |cff00ff00to open the menu.|r")

--This Full ToC System needs to be rewrited in ver 1.1.0
mQoL_Hub.clientInfo = {
    version = version,
    tocversion = tocversion,
    isRetail = false,
    isClassic = false,
    --Mists of Pandaria (5.4.x) and Legion (7.3.x)
    isLegion = false,
    isPandaria = false,
	isEra = false,
	isBcc = false,
}

if tocversion >= 120000 then								-- Retail (toc prepatch 12.0 = 120000) (toc release 12.0 = 120001)
	mQoL_Hub.clientInfo.isRetail = true
elseif tocversion >= 50500 and tocversion <= 50505 then		-- Classic 2019 Cata Mop itp (4.4.2) (toc = 40400) (toc mop = 50505) Maybe in future there will be added support for TBC/WOTLK if blizzard re-release it
	mQoL_Hub.clientInfo.isClassic = true
elseif tocversion >= 70000 and tocversion <= 70300 then				-- Legion (7.3.5) (toc = 70300)
	mQoL_Hub.clientInfo.isLegion = true
elseif tocversion >= 11300 and tocversion <= 11507 then				-- Classic Vanilla (1.15.7) (toc = 11507)
	mQoL_Hub.clientInfo.isEra = true
elseif tocversion >= 20500 and tocversion <= 20505 then
	mQoL_Hub.clientInfo.isBcc = true
elseif tocversion >= 50001 and tocversion <= 50400 then				-- Mists of Pandaria (5.4.8) (toc = 50400)
	mQoL_Hub.clientInfo.isPandaria = true
	print("|cff00ff00[mQoL Hub] |cffff4444WARNING|r|cff00ff00 - Mists of Pandaria 5.4 is not yet supported.|r")
else
    print("|cff00ff00[mQoL Hub] |cffff4444WARNING|r|cff00ff00 - unsupported client version: " .. (tocversion or "UNKNOWN") .. "|r")
end

local clientInfo = mQoL_Hub.clientInfo
	
function mQoL_Hub:RegisterModuleOptions(id, label, panelFunc)
    self.modules[label] = panelFunc
end

-- SLASH COMMAND OPEN MAIN WINDOW
SLASH_MQOL_HUB1 = "/mQoL"
SlashCmdList["MQOL_HUB"] = function()
    mQoL_Hub:ToggleMainPanel()
end

-- Slash Command for version check window
SLASH_MQOL_HUBVERSION1 = "/mqv"
SlashCmdList["MQOL_HUBVERSION"] = function()
    if not mQoL_Hub.VersionFrame then
        mQoL_Hub:CreateVersionPanel()
    end
    mQoL_Hub.VersionFrame:Show()
    mQoL_Hub:ClearVersionPanel()

    local playerName = UnitName("player")
    local realmName = GetRealmName():gsub("%s+", "")
    local fullName = playerName .. "-" .. realmName

    tinsert(mQoL_Hub.VersionData, {
        name = fullName,
        version = mQoL_Hub.version or "unknown",
        build = mQoL_Hub.build or "unknown"
    })

    mQoL_Hub:RefreshVersionPanel()

    if IsInRaid() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "!MHVREQ", "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "!MHVREQ", "PARTY")
    end
end

-- Libs for minimap
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local hubLauncher = LDB:NewDataObject("mQoL_Hub", {
    type = "launcher",
    text = "mQoL Hub",
    icon = "Interface\\AddOns\\mQoL\\Media\\Textures\\logo",
    OnClick = function(_, button)
        if button == "LeftButton" then
            mQoL_Hub:ToggleMainPanel()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("mQoL")
        tooltip:AddLine("Open Panel", 1, 1, 1)
    end,
})

function mQoL_Hub:InitializeMinimap()
    local hubSettings = mQoL_Database:GetSettings("Hub") or {}
    hubSettings.minimap = hubSettings.minimap or { hide = false }

    LDBIcon:Register("mQoL_Hub", hubLauncher, hubSettings.minimap)
    if hubSettings.minimap.hide then
        LDBIcon:Hide("mQoL_Hub")
    end
end

--Default Settings
mQoL_Hub.defaults = {
    minimap = { hide = false, minimapPos = 220 },
    display = { scale = 1.0 },
}

--Initialize Database
function mQoL_Hub:InitializeDB()
    mQoL_Database:MigrateModule("Hub", self.defaults)
    self.db = mQoL_Database:GetSettings("Hub")
end

-- Display Panel
function mQoL_Hub:CreateDisplayPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)

    local hubSettings = mQoL_Database:GetSettings("Hub") or {}

    --Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("General Settings - Display")
    title:SetTextColor(1, 1, 1)

    --Separator
    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(1, 1, 1, 0.3)
    separator:SetSize(930, 1)
    separator:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

	-- check if minimap exist
	hubSettings.minimap = hubSettings.minimap or { hide = false }

	--Minimap button
	local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	checkbox.text:SetText("Hide Minimap Button")
	checkbox.text:SetFontObject("GameFontHighlight")
	checkbox.text:SetTextColor(1, 0.82, 0)
	checkbox:SetChecked(hubSettings.minimap.hide)

	checkbox:SetScript("OnClick", function(self)
		hubSettings.minimap.hide = self:GetChecked()
		mQoL_Database:SetSettings("Hub", hubSettings)
		if self:GetChecked() then
			LibStub("LibDBIcon-1.0"):Hide("mQoL_Hub")
		else
			LibStub("LibDBIcon-1.0"):Show("mQoL_Hub")
		end
	end)

    --Window Scale
	local sliderTemplate = "OptionsSliderTemplate"
	if clientInfo.isBcc then
		sliderTemplate = "OptionsSliderTemplate, BackdropTemplate"
	end

    local scaleSlider = CreateFrame("Slider", "mQoL_HubScaleSlider", panel, sliderTemplate)
    scaleSlider:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -20)
	
	if clientInfo.isBcc then
		scaleSlider:SetHeight(17)
		scaleSlider:SetBackdrop({
			bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
			edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
			tile = true, tileSize = 8, edgeSize = 8,
			insets = { left = 3, right = 3, top = 6, bottom = 6 }
		})
	end
	
    scaleSlider:SetMinMaxValues(0.5, 1.5)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetWidth(200)
    scaleSlider:SetValue(hubSettings.display.scale or 1.0)
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[scaleSlider:GetName() .. "High"]:SetText("1.5")
    local sliderText = _G[scaleSlider:GetName() .. "Text"]
    sliderText:SetText("Window Scale")
    sliderText:SetTextColor(1, 0.82, 0)

    local scaleEditBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    scaleEditBox:SetSize(50, 20)
    scaleEditBox:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
    scaleEditBox:SetAutoFocus(false)
    scaleEditBox:SetNumeric(false)
    scaleEditBox:SetText(string.format("%.2f", hubSettings.display.scale or 1.0))

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        scaleEditBox:SetText(string.format("%.2f", value))
    end)

    scaleEditBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0.5 and val <= 1.5 then
            scaleSlider:SetValue(val)
        end
    end)

    local applyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyButton:SetSize(100, 22)
    applyButton:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -10)
    applyButton:SetText("Apply Scale")
    applyButton:SetScript("OnClick", function()
        local newScale = math.floor(scaleSlider:GetValue() * 100 + 0.5) / 100
        hubSettings.display.scale = newScale
        mQoL_Database:SetSettings("Hub", hubSettings)
        if mQoL_Hub.MainFrame then
            mQoL_Hub.MainFrame:SetScale(newScale)
        end
    end)

    return panel
end

-- UI Panel Structure (Sidepanel in 1.1.0)
local PANEL_STRUCTURE = {
    ["General Settings"] = {
        "Display",
        "Profiles",
    },
    ["Quality of Life Settings"] = {
        "General QoL",
        "Nameplates",
        "Action Bars",
		"Mailbox",
    },
    ["Advanced Settings"] = {
        "Graphics",
    },
}

--Main Panel
function mQoL_Hub:CreateMainPanel()
	local hubSettings = mQoL_Database:GetSettings("Hub")
	local frameScale = hubSettings.display.scale or 1.0
	local f
	if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
		f = CreateFrame("Frame", "mQoL_Hub_MainFrame", UIParent, "BackdropTemplate")
		self.MainFrame = f
		tinsert(UISpecialFrames, f:GetName())
		f:SetScale(frameScale)
		f:SetSize(1200, 647)
		f:SetPoint("CENTER")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:SetClampedToScreen(true)
		f:SetFrameStrata("DIALOG")
		f:Hide()

		local bg = f:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0.85)

	elseif clientInfo.isLegion then
		f = CreateFrame("Frame", "mQoL_Hub_MainFrame", UIParent)
		self.MainFrame = f
		tinsert(UISpecialFrames, f:GetName())
		f:SetScale(frameScale)
		f:SetSize(1200, 647)
		f:SetPoint("CENTER")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:SetClampedToScreen(true)
		f:SetFrameStrata("DIALOG")
		f:Hide()

		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			tile = true,
			tileSize = 32,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

	elseif clientInfo.isPandaria then
		f = CreateFrame("Frame", "mQoL_Hub_MainFrame", UIParent)
		self.MainFrame = f
		tinsert(UISpecialFrames, f:GetName())
		f:SetScale(frameScale)
		f:SetSize(1200, 675)
		f:SetPoint("CENTER")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:SetClampedToScreen(true)
		f:SetFrameStrata("DIALOG")
		f:Hide()

		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			tile = true,
			tileSize = 32,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

	else
		return
	end

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(32)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function(self)
		f:StartMoving()
	end)
	titleBar:SetScript("OnDragStop", function(self)
		f:StopMovingOrSizing()
	end)

	--Title
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, -3)
    titleText:SetText("mQoL Hub")
    titleText:SetTextColor(1, 0.82, 0)
    titleText:SetShadowColor(0, 0, 0, 0.8)
    titleText:SetShadowOffset(1, -1)

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -10, -3)
    closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeBtn.text:SetPoint("CENTER")
    closeBtn.text:SetText("X")
    closeBtn.text:SetTextColor(1, 0.2, 0.2)
    closeBtn:SetScript("OnEnter", function() closeBtn.text:SetTextColor(1, 0.4, 0.4) end)
    closeBtn:SetScript("OnLeave", function() closeBtn.text:SetTextColor(1, 0.2, 0.2) end)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetSize(200, 615)
    sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)

    local divider = f:CreateTexture(nil, "OVERLAY")
    divider:SetColorTexture(1, 1, 1, 0.1)
    divider:SetSize(2, 600)
    divider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 5, 0)

    local content = CreateFrame("Frame", nil, f)
    content:SetSize(970, 615)
    content:SetPoint("TOPLEFT", divider, "TOPRIGHT", 5, 0)

    local panels = {}

    for categoryName, subcategories in pairs(PANEL_STRUCTURE) do
        for _, sub in ipairs(subcategories) do
            local panelFunc = mQoL_Hub.modules[sub]
            if panelFunc then
                local panel = panelFunc(content)
                panel:SetAllPoints()
                panel:Hide()
                panels[sub] = panel
            else
                local panel = CreateFrame("Frame", nil, content)
                panel:SetAllPoints()
                panel:Hide()
                local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                label:SetPoint("TOPLEFT", 10, -10)
				
				local ci = clientInfo
				label:SetText("|cffff4444'" .. sub .. "' options are not available in this version of the game (" ..
					(ci.isRetail and "Retail" or
					 ci.isClassic and "Classic" or
					 ci.isEra and "Era" or
					 ci.isLegion and "Legion" or
					 ci.isPandaria and "Mists of Pandaria" or
					 "Unknown") .. " " .. (ci.version or "Unknown patch") .. ").|r")

                panels[sub] = panel
            end
        end
    end

    local function ClearContent()
        for _, child in ipairs({ content:GetChildren() }) do
            child:Hide()
        end
    end

    local function ShowPanel(name)
        ClearContent()
        if panels[name] then
            panels[name]:Show()
        end
    end

    local function AddCategoryLabel(name, yOffset)
        local label = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("TOPLEFT", 0, yOffset)
        label:SetText(name)
        label:SetTextColor(1, 0.82, 0)
        return label
    end

    local function AddSidebarButton(name, yOffset)
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(190, 24)
        btn:SetPoint("TOPLEFT", 15, yOffset)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(1, 1, 1, 0)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        btn.text:SetPoint("LEFT", 10, 0)
        btn.text:SetText(name)
        btn.text:SetTextColor(1, 1, 1)

        btn:SetScript("OnEnter", function()
            btn.bg:SetColorTexture(1, 1, 1, 0.1)
        end)
        btn:SetScript("OnLeave", function()
            btn.bg:SetColorTexture(1, 1, 1, 0)
        end)
        btn:SetScript("OnClick", function()
            ShowPanel(name)
        end)
    end

    local yOffset = -10
    for index, category in ipairs({ "General Settings", "Quality of Life Settings", "Advanced Settings" }) do
        yOffset = yOffset - 10
        AddCategoryLabel(category, yOffset)
        yOffset = yOffset - 28

        for _, sub in ipairs(PANEL_STRUCTURE[category]) do
            AddSidebarButton(sub, yOffset)
            yOffset = yOffset - 28
        end

        if index < #PANEL_STRUCTURE then
            yOffset = yOffset - 40
        end
    end

    local defaultPanel = PANEL_STRUCTURE["General Settings"][1]
	
	-- Version Info
	local versionText = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	versionText:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 2, 15)
	versionText:SetText("|cffffff00Version:|r " .. (mQoL_Hub.version or "?"))

	-- Build Info
	local buildText = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	buildText:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -2, 15)
	buildText:SetText("|cffffff00Build:|r " .. (mQoL_Hub.build or "?"))
	
    ShowPanel(defaultPanel)
end

local function CreateButton(parent, text, point, x, y, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 60, height or 22)
    btn:SetPoint(point, x, y)
    btn:SetText(text)
    return btn
end

function mQoL_Hub:CreateProfilesPanel(parent)

    local isEnabled = false --Disable profiles tab (this code is anyway not working right now)

    local panel = CreateFrame("Frame", nil, parent)

    if not isEnabled then
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 10, -10)
        title:SetText("General Settings - Profiles")
        title:SetTextColor(1, 1, 1)

		-- Separator
		local separator = panel:CreateTexture(nil, "ARTWORK")
		separator:SetColorTexture(1, 1, 1, 0.3)
		separator:SetSize(930, 1)
		separator:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

        local message = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        message:SetPoint("TOPLEFT", 10, -50)
        message:SetText("|cffff4444This feature is not yet available in this version.|r")

        return panel
    end

    -- Title
    local mainTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    mainTitle:SetPoint("TOPLEFT", 10, -10)
    mainTitle:SetText("General Settings - Profiles")
    mainTitle:SetTextColor(1, 0.82, 0)

    -- Separator
    local separatorTop = panel:CreateTexture(nil, "ARTWORK")
    separatorTop:SetColorTexture(1, 1, 1, 0.3)
    separatorTop:SetSize(600, 1)
    separatorTop:SetPoint("TOPLEFT", 5, -40)

    local yOffset = -60

    local function CreateDropdown(section)
        local dropdown
        if clientInfo.isLegion or clientInfo.isPandaria then
            dropdown = CreateFrame("Frame", "mQoL_Hub_"..section.."_Dropdown", panel, "UIDropDownMenuTemplate")
        else
            dropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
        end
        UIDropDownMenu_SetWidth(dropdown, 150)
        UIDropDownMenu_Initialize(dropdown, function(self)
            local profiles = mQoL_Hub.profiles[section]
            for name, _ in pairs(profiles) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.func = function()
                    mQoL_Hub.activeProfile[section] = name
                    UIDropDownMenu_SetText(dropdown, name)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetText(dropdown, mQoL_Hub.activeProfile[section])
        return dropdown
    end

    local function CreateButton(text, parent, x, y, width, height)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(width or 80, height or 22)
        btn:SetPoint("TOPLEFT", x, y)
        btn:SetText(text)
        return btn
    end

    local function CreateLabel(text, size, x, y)
        local font = size == "large" and "GameFontNormalLarge" or "GameFontNormal"
        local label = panel:CreateFontString(nil, "OVERLAY", font)
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(text)
        return label
    end

    local function CreateProfileSection(sectionName, sectionKey)
        local sectionTitle = CreateLabel(sectionName, "large", 10, yOffset)
        sectionTitle:SetTextColor(1, 0.82, 0)

        yOffset = yOffset - 35
        CreateLabel("Current Profile:", nil, 10, yOffset)
        yOffset = yOffset - 20

        local rowFrame = CreateFrame("Frame", nil, panel)
        rowFrame:SetSize(400, 25)
        rowFrame:SetPoint("TOPLEFT", -10, yOffset)

        local dropdown = CreateDropdown(sectionKey)
        dropdown:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)

        local btnLoad = CreateButton("Load", rowFrame, 190, 2, 60, 25)
        local btnDelete = CreateButton("Delete", rowFrame, 255, 2, 60, 25)

        yOffset = yOffset - 40

		CreateLabel("Save Profile:", nil, 10, yOffset)
		
		yOffset = yOffset - 20
		
        local editFrame = CreateFrame("Frame", nil, panel)
        editFrame:SetSize(400, 25)
        editFrame:SetPoint("TOPLEFT", 10, yOffset)

        local editBox = CreateFrame("EditBox", nil, editFrame, "InputBoxTemplate")
        editBox:SetSize(160, 25)
        editBox:SetPoint("LEFT", 5, 2)
        editBox:SetAutoFocus(false)
        editBox:SetText("")

        local btnSaveAs = CreateButton("Save", editFrame, 170, 0, 60)

        yOffset = yOffset - 30

        local btnImport = CreateButton("Export Profile", panel, 10, yOffset, 130)
		
		yOffset = yOffset - 30
		
        local btnExport = CreateButton("Import Profile", panel, 10, yOffset, 130)

        yOffset = yOffset - 50
    end

    CreateProfileSection("mQoL Hub Profile", "mQoL_Hub")

    -- separator
    local separatorMid = panel:CreateTexture(nil, "ARTWORK")
    separatorMid:SetColorTexture(1, 1, 1, 0.2)
    separatorMid:SetSize(600, 1)
    separatorMid:SetPoint("TOPLEFT", 5, yOffset)

    yOffset = yOffset - 10

    return panel
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
    local f
    if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
        f = CreateFrame("Frame", "mQoL_Hub_VersionFrame", UIParent, "BackdropTemplate")
    elseif clientInfo.isLegion or clientInfo.isPandaria then
        f = CreateFrame("Frame", "mQoL_Hub_VersionFrame", UIParent)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            tile = true,
            tileSize = 32,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    else
        return
    end

    self.VersionFrame = f
    tinsert(UISpecialFrames, f:GetName())
    f:SetSize(300, 400)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.85)
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOP", 0, -10)
    f.title:SetText("mQoL Versions")

    local closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() f:Hide() end)
    f.closeButton = closeButton

    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", 10, -40)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    f.content = CreateFrame("Frame", nil, f.scrollFrame)
    f.content:SetSize(240, 1)
    f.scrollFrame:SetScrollChild(f.content)

    f.rows = {}
end

function mQoL_Hub:RefreshVersionPanel()
    if not self.VersionFrame or not self.VersionData then return end

    local content = self.VersionFrame.content
    local rows = self.VersionFrame.rows
    local playerFullName = vreg.NormalizeName(UnitName("player"))

    for _, row in ipairs(rows) do
        row:Hide()
    end

    table.sort(self.VersionData, function(a, b)
        local vreg1 = vreg.hasmark(a.name)
        local vreg2 = vreg.hasmark(b.name)

        if vreg1 and not vreg2 then return true
        elseif not vreg1 and vreg2 then return false
        elseif a.name == playerFullName then return true
        elseif b.name == playerFullName then return false
        else return a.name < b.name
        end
    end)

    local y = 0
    for i, entry in ipairs(self.VersionData) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(240, 20)

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", 5, 0)

            row.versionText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.versionText:SetPoint("RIGHT", -5, 0)

            rows[i] = row
        end

        local fullName = entry.name
        local displayName = fullName:gsub("%-.*$", "")

        row.nameText:SetText(vreg.decorate(fullName, displayName))
        row.versionText:SetText(entry.version .. " Build " .. entry.build)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        row:Show()

        y = y + 20
    end
    content:SetHeight(math.max(y, 1))
end

function mQoL_Hub:ClearVersionPanel()
    if not self.VersionFrame then return end
    for _, row in ipairs(self.VersionFrame.rows) do
        row:Hide()
    end
    self.VersionFrame.rows = {}
    self.VersionData = {}
end

function mQoL_Hub:AddVersionRow(player, version, build)
    if not self.VersionData then
        self.VersionData = {}
    end

    local fullName = vreg.NormalizeName(player)

    for i, row in ipairs(self.VersionData) do
        if row.name == fullName then
            table.remove(self.VersionData, i)
            break
        end
    end

    local entry = { name = fullName, version = version, build = build }

    local playerFullName = vreg.NormalizeName(UnitName("player"))
    if fullName == playerFullName then
        table.insert(self.VersionData, 1, entry)
    else
        table.insert(self.VersionData, entry)
    end

    if self.RefreshVersionPanel then
        self:RefreshVersionPanel()
    end
end

local function RegisterMessagePrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    else
        -- only retail
    end
end

local function SendAddonMessage(prefix, message, channel, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(prefix, message, channel, target)
    else
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
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
        end

        -- Migrate DB
        mQoL_Hub:InitializeDB()

        -- Inicialize Minimap
        mQoL_Hub:InitializeMinimap()

        -- Panel Register
        if mQoL_Hub.RegisterModuleOptions then
            mQoL_Hub:RegisterModuleOptions("mQoL_Hub_Display", "Display", function(parent)
                return mQoL_Hub:CreateDisplayPanel(parent)
            end)

            mQoL_Hub:RegisterModuleOptions("mQoL_Hub_Profiles", "Profiles", function(parent)
                return mQoL_Hub:CreateProfilesPanel(parent)
            end)
        end

    elseif event == "PLAYER_LOGIN" then
        local hubSettings = mQoL_Database:GetSettings("Hub")
        if mQoL_Hub.MainFrame and hubSettings.display then
            mQoL_Hub.MainFrame:SetScale(hubSettings.display.scale or 1.0)
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = arg1, arg2, arg3, arg4
        if prefix ~= ADDON_PREFIX then return end
        
        -- Safe comparison (pcall due to secret value)
        local success, result = pcall(function() return sender == UnitName("player") end)
        if not success then return end -- Secret value, ignore
        if result then return end -- Ignore self

        -- /mqv respond
        if msg == "!VREQ" then
            C_ChatInfo.SendAddonMessage(ADDON_PREFIX,
                "!MHVRESP:" .. (mQoL_Hub.version or "unknown") .. ":" .. (mQoL_Hub.build or "unknown"),
                channel)
            return
        end

        -- get a respond
        local version, build = msg:match("^!MHVRESP:(.-):(.-)$")
		if version and build then
			local fullName = vreg.NormalizeName(sender)
			local exists = false
			for _, entry in ipairs(mQoL_Hub.VersionData) do
				if entry.name == fullName then
					exists = true
					break
				end
			end
			if not exists then
				tinsert(mQoL_Hub.VersionData, {
					name = fullName,
					version = version,
					build = build
				})
				mQoL_Hub:RefreshVersionPanel()
			end
		end

    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_WHISPER" then
        local msg, sender = arg1, arg2
        local playerName = UnitName("player")
        
        -- Safe comparison (pcall due to secret value)
        local success, result = pcall(function() return sender == playerName end)
        if not success then return end -- Secret value, ignore
        if result then return end -- Ignore self

        local channel = event == "CHAT_MSG_WHISPER" and "WHISPER"
                     or event == "CHAT_MSG_PARTY" and "PARTY"
                     or "RAID"

        -- old chat command
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
    end
end)