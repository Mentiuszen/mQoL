local addonName = ...

local NAV_INFO = {
    [371] = { name = "The Jade Forest",           levels = "85–86" },
    [376] = { name = "Valley of the Four Winds",  levels = "86–87" },
    [418] = { name = "Krasarang Wilds",           levels = "86–87" },
    [379] = { name = "Kun-Lai Summit",            levels = "87–88" },
    [388] = { name = "Townlong Steppes",          levels = "88–89" },
    [422] = { name = "Dread Wastes",              levels = "89–90" },
    [390] = { name = "Vale of Eternal Blossoms",  levels = "90" },
    [433] = { name = "The Veiled Stair",          levels = "86–87" },
    [507] = { name = "Isle of Giants",            levels = "90" },
    [554] = { name = "Timeless Isle",             levels = "90" },
    [391] = { name = "Shrine of Two Moons",      levels = "90" },
    [393] = { name = "Shrine of Seven Stars",    levels = "90" },
}

local NAV_LINKS = {
    [371] = { -- The Jade Forest
        {379, 0.00, 0.00, 0.45, 0.70, 0.00},
        {433, 0.25, 0.60, 0.07, 0.15, 0.00},
        {390, 0.00, 0.50, 0.40, 0.30, 0.00},
        {376, 0.15, 0.78, 0.38, 0.22, 0.00},
        {418, 0.15, 0.95, 0.35, 0.15, 0.00},
        {554, 0.92, 0.88, 0.20, 0.25, 0.00},
    },
    [376] = { -- Valley of the Four Winds
        {371, 1.00, 0.20, 0.15, 0.40, 0.00},	--Jade Forest #1 (Multiple entries for better hitbox)
		{371, 0.95, 0.05, 0.20, 0.20, 0.00},	--Jade Forest #2
        {418, 0.55, 1.00, 0.85, 0.30, 0.00},	--Krasarang #1
		{418, 0.70, 0.82, 0.55, 0.09, 0.00},	--Krasarang #2
		{418, 0.85, 0.74, 0.25, 0.10, 0.00},	--Krasarang #3
		{418, 0.85, 0.65, 0.20, 0.17, 0.00},	--Krasarang #4
        {390, 0.40, 0.10, 0.60, 0.20, 0.00},
        {433, 0.75, 0.10, 0.15, 0.17, 0.00},
        {422, 0.00, 0.60, 0.15, 0.80, 0.00},
        {388, 0.00, 0.00, 0.20, 0.35, 0.00},
    },
    [418] = {	--Krasarang Wilds
        {371, 0.95, 0.05, 0.20, 0.20, 0.00},
        {376, 0.47, 0.05, 0.70, 0.10, 0.00},	--Valley #1
		{376, 0.37, 0.15, 0.50, 0.10, 0.00},	--Valley #2
        {422, 0.05, 0.20, 0.15, 0.40, 0.00},
    },
    [390] = {	-- Vale of Eternal Blossoms
        {433, 1.00, 0.50, 0.10, 0.60, 0.00},
        {379, 0.50, 0.05, 0.75, 0.10, 0.00},
        {376, 0.60, 0.95, 0.80, 0.15, 0.00},
        {388, 0.05, 0.35, 0.10, 0.60, 0.00},
        {422, 0.00, 0.90, 0.30, 0.30, 0.00},
        {391, 0.62, 0.15, 0.09, 0.09, 0.00}, -- Shrine of Two Moons (Horde)
        {393, 0.89, 0.69, 0.09, 0.09, 33.00}, -- Shrine of Seven Stars (Alliance)
    },
    [379] = {	-- Kun-Lai Summit
        {371, 0.90, 0.80, 0.20, 0.50, 0.00},
        {390, 0.60, 0.97, 0.30, 0.08, 0.00},
        {388, 0.15, 0.85, 0.30, 0.40, 0.00},	--Townlong #1
		{388, 0.35, 0.93, 0.10, 0.17, 0.00},	--Townlong #2
        {507, 0.60, 0.05, 0.15, 0.10, 0.00},
    },
    [388] = {	--Townlong Steppes
        {379, 0.80, 0.15, 0.40, 0.30, 0.00},	--Kun-Lai #1
		{379, 0.90, 0.45, 0.25, 0.30, 0.00},	--Kun-Lai #2
        {390, 0.95, 0.90, 0.20, 0.25, 0.00},
        {422, 0.65, 0.95, 0.25, 0.15, 0.00},
    },
    [422] = {	--Dread Wastes
        {388, 0.45, 0.05, 0.50, 0.10, 0.00},
        {390, 0.90, 0.10, 0.35, 0.25, 0.00},
		{376, 0.87, 0.35, 0.26, 0.25, 0.00},	--Valley #1
        {376, 0.85, 0.60, 0.30, 0.35, 0.00},	--Valley #2
        {418, 0.85, 0.90, 0.30, 0.25, 0.00},
    },
    [507] = { --Isle of Giants
        {379, 0.50, 1.00, 1.00, 0.20, 0.00},
    },
    [554] = {	--Timeless Isle (not live yet but whatever)
        {371, 0.00, 0.50, 0.20, 1.00, 0.00},
    },
    [433] = {	--The Veiled Stair
        {371, 0.85, 0.15, 0.40, 0.50, 0.00},	--Jade Forest #1
		{371, 0.90, 0.50, 0.30, 0.40, 0.00},	--Jade Forest #2
        {376, 0.40, 0.95, 0.90, 0.10, 0.00},
        {379, 0.30, 0.05, 0.50, 0.12, 0.00},
        {390, 0.10, 0.50, 0.50, 0.75, 0.00},
    },
	[391] = {	--Shrine of Two Moons
		{390, 0.55, 0.93, 0.10, 0.10, 9.00}
	},
	[393] = {	--Shrine of Seven Stars
		{390, 0.35, 0.20, 0.10, 0.10, 33.00}
	}
}

local navButtons = {}

-- MAP LOGIC
local function IsPandariaMap(mapID)
    return NAV_LINKS[mapID] ~= nil
end

function PandariaMapFix_OnMapChanged()
    if not WorldMapFrame:IsShown() then return end
    local mapID = WorldMapFrame:GetMapID()
    if mapID and IsPandariaMap(mapID) then
        CreateNavigationButtons(mapID)
    else
        ClearNavigationButtons()
    end
end

function ClearNavigationButtons()
    for _, b in ipairs(navButtons) do
        b:Hide()
        b:SetParent(nil)
    end
    wipe(navButtons)
end

-- BUTTON CREATION / UPDATE
local function GetAreaLabel()
    return _G["WorldMapFrameAreaLabel"] or (WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.TitleText)
end

function CreateNavButton(parent, targetMapID, px, py, w, h, rot)
    local info = NAV_INFO[targetMapID]
    if not info then return end

    local button = CreateFrame("Button", nil, parent)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(WorldMapFrame.ScrollContainer.Child:GetFrameLevel() + 1)
    button.zoneData = { mapID = targetMapID, px = px, py = py, w = w, h = h, rot = rot }

    button.texture = button:CreateTexture(nil, "OVERLAY")
    button.texture:SetAllPoints()
    button.texture:SetColorTexture(1, 0, 0, 0)

    -- Rotation should be cool
    if rot and type(rot) == "number" then
        button.texture:SetRotation(math.rad(rot or 0))
    end

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
             if WorldMapFrame.NavigateToParentMap then
                 WorldMapFrame:NavigateToParentMap()
             end
        else
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            WorldMapFrame:SetMapID(targetMapID)
        end
    end)

    button:SetScript("OnEnter", function()
        local name = info.name or "Unknown"
        local levels = info.levels or ""
        ShowHoverHeader(name, levels)
    end)

    button:SetScript("OnLeave", function()
        HideHoverHeader()
    end)

    button:Show()
    table.insert(navButtons, button)
    return button
end

function CreateNavigationButtons(mapID)
    ClearNavigationButtons()
    local parent = WorldMapFrame.ScrollContainer.Child
    if not parent or not NAV_LINKS[mapID] then return end

    for _, link in ipairs(NAV_LINKS[mapID]) do
		local targetMapID, px, py, w, h, rot = unpack(link)
		CreateNavButton(parent, targetMapID, px, py, w, h, rot)
    end
    PandariaMapFix_UpdatePositions()
end

function PandariaMapFix_UpdatePositions()
    local child = WorldMapFrame.ScrollContainer.Child
    if not child then return end

    local width, height = child:GetSize()
    if width == 0 or height == 0 then return end

	for _, button in ipairs(navButtons) do
		local d = button.zoneData
		if d then
			local bx, by = width * d.px, -height * d.py
			button:ClearAllPoints()
			button:SetSize(width * d.w, height * d.h)
			button:SetPoint("TOPLEFT", child, "TOPLEFT", bx - (width * d.w / 2), by + (height * d.h / 2))
		end
	end
end

-- HOVER HEADER
local hoverHeader = CreateFrame("Frame", "mQoL_PandariaHoverHeader", WorldMapFrame)
hoverHeader:SetFrameStrata("FULLSCREEN_DIALOG")
hoverHeader:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 200)
hoverHeader:SetSize(600, 50)
hoverHeader:SetPoint("TOP", WorldMapFrame, "TOP", 0, -36)
hoverHeader:Hide()

hoverHeader.text = hoverHeader:CreateFontString(nil, "OVERLAY")
hoverHeader.text:SetPoint("CENTER")

local font, size, flags = GameFontNormalHuge:GetFont()
hoverHeader.text:SetFont(font, size + 2, "OUTLINE")
hoverHeader.text:SetTextColor(1, 1, 1)
hoverHeader.text:SetShadowColor(0, 0, 0, 1)
hoverHeader.text:SetShadowOffset(2, -2)

local function ColorizeZoneLevels(levels)
    if not levels or levels == "" then return "" end
    local playerLevel = UnitLevel("player") or 0

    local low, high = levels:match("(%d+)%D+(%d+)")
    if not low then
        local single = levels:match("(%d+)")
        if single then
            low = tonumber(single)
            high = low
        end
    else
        low, high = tonumber(low), tonumber(high)
    end
    if not low or not high then return "(" .. levels .. ")" end

    local zoneLevel = math.floor((low + high) / 2)
    local diff = zoneLevel - playerLevel
    local color

    if diff >= 3 then
        color = "|cffff0000" -- RED
    elseif diff == 2 or diff == 1 then
        color = "|cffff8000" -- ORANGE
    elseif diff == 0 or diff == -1 or diff == -2 then
        color = "|cffffff00" -- YELLOW
    elseif diff >= -5 then
        color = "|cff00ff00" -- GREEN
    else
        color = "|cffaaaaaa" -- GRAY
    end

    return string.format("%s(%s)|r", color, levels)
end

function ShowHoverHeader(zoneName, levels)
    if not (zoneName and hoverHeader.text) then return end
    local text = zoneName
    if levels and levels ~= "" then
        text = text .. " " .. ColorizeZoneLevels(levels)
    end
    hoverHeader.text:SetText(text)
    hoverHeader:Show()
end

function HideHoverHeader()
    hoverHeader:Hide()
end

--FIX WORLD BOSS VISIBILITY ON WORLD MAP (i dont fucking know how blizzard got thunder king world bosses working but regular one not so this stay here until SoO kekw)
local function FixPandariaWorldBossPins()
    if not WorldMapFrame then return end

    local manager = WorldMapFrame.pinFrameLevelsManager
    if not manager or not manager.AddFrameLevel then
        return
    end

    if not manager.frameLevels or not manager.frameLevels["PIN_FRAME_LEVEL_ENCOUNTER"] then
        manager:AddFrameLevel("PIN_FRAME_LEVEL_ENCOUNTER")
    end
end

-- INIT
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    if mQoL_DB and mQoL_DB.BlizzardFixes and mQoL_DB.BlizzardFixes.fixPandariaMap == false then return end
    C_Timer.After(2, function()
        FixPandariaWorldBossPins()
        PandariaMapFix_Initialize()
    end)
end)

local isInitialized = false
function PandariaMapFix_Initialize()
    if isInitialized then return end
    if not WorldMapFrame then return end
    isInitialized = true

    WorldMapFrame:HookScript("OnShow", function()
        C_Timer.After(0.2, PandariaMapFix_OnMapChanged)
    end)
    hooksecurefunc(WorldMapFrame, "SetMapID", function()
        C_Timer.After(0.2, PandariaMapFix_OnMapChanged)
    end)
    WorldMapFrame.ScrollContainer:HookScript("OnMouseWheel", function()
        C_Timer.After(0.05, PandariaMapFix_UpdatePositions)
    end)
    WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function()
        C_Timer.After(0.05, PandariaMapFix_UpdatePositions)
    end)
end
