local addonName = ...

local DEBUG_HITBOXES = false

local NAV_INFO = {
}

local NAV_LINKS = {
}

local navButtons = {}
local hoverHeader
local isInitialized = false

local function IsBCCNavigationMap(mapID)
    return NAV_LINKS[mapID] ~= nil
end

local function ClearNavigationButtons()
    for _, button in ipairs(navButtons) do
        button:Hide()
        button:SetParent(nil)
    end
    wipe(navButtons)
end

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
        color = "|cffff0000"
    elseif diff == 2 or diff == 1 then
        color = "|cffff8000"
    elseif diff == 0 or diff == -1 or diff == -2 then
        color = "|cffffff00"
    elseif diff >= -5 then
        color = "|cff00ff00"
    else
        color = "|cffaaaaaa"
    end

    return string.format("%s(%s)|r", color, levels)
end

local function ShowHoverHeader(zoneName, levels)
    if not (zoneName and hoverHeader and hoverHeader.text) then return end

    local text = zoneName
    if levels and levels ~= "" then
        text = text .. " " .. ColorizeZoneLevels(levels)
    end
    hoverHeader.text:SetText(text)
    hoverHeader:Show()
end

local function HideHoverHeader()
    if hoverHeader then
        hoverHeader:Hide()
    end
end

local function GetNavigationTargetInfo(targetMapID)
    return NAV_INFO[targetMapID] or {
        name = "Map ID " .. tostring(targetMapID),
        levels = "",
    }
end

local function CreateNavButton(parent, targetMapID, px, py, w, h, rot)
    local info = GetNavigationTargetInfo(targetMapID)
    local button = CreateFrame("Button", nil, parent)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(WorldMapFrame.ScrollContainer.Child:GetFrameLevel() + 1)
    button.zoneData = { mapID = targetMapID, px = px, py = py, w = w, h = h, rot = rot }

    button.texture = button:CreateTexture(nil, "OVERLAY")
    button.texture:SetAllPoints()
    if DEBUG_HITBOXES then
        button.texture:SetColorTexture(1, 0, 0, 0.35)
    else
        button.texture:SetColorTexture(1, 0, 0, 0)
    end

    if rot and type(rot) == "number" then
        button.texture:SetRotation(math.rad(rot or 0))
    end

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, clickedButton)
        if clickedButton == "RightButton" then
            if WorldMapFrame.NavigateToParentMap then
                WorldMapFrame:NavigateToParentMap()
            end
        else
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            WorldMapFrame:SetMapID(targetMapID)
        end
    end)

    button:SetScript("OnEnter", function()
        ShowHoverHeader(info.name or "Unknown", info.levels or "")
    end)

    button:SetScript("OnLeave", function()
        HideHoverHeader()
    end)

    button:Show()
    table.insert(navButtons, button)
    return button
end

local function BCCMapFix_UpdatePositions()
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

local function CreateNavigationButtons(mapID)
    ClearNavigationButtons()

    local parent = WorldMapFrame.ScrollContainer.Child
    if not parent or not NAV_LINKS[mapID] then return end

    for _, link in ipairs(NAV_LINKS[mapID]) do
        local targetMapID, px, py, w, h, rot = unpack(link)
        CreateNavButton(parent, targetMapID, px, py, w, h, rot)
    end
    BCCMapFix_UpdatePositions()
end

local function BCCMapFix_OnMapChanged()
    if not WorldMapFrame:IsShown() then return end

    local mapID = WorldMapFrame:GetMapID()
    if mapID and IsBCCNavigationMap(mapID) then
        CreateNavigationButtons(mapID)
    else
        ClearNavigationButtons()
    end
end

local function CreateHoverHeader()
    if hoverHeader then return end

    hoverHeader = CreateFrame("Frame", "mQoL_BCCHoverHeader", WorldMapFrame)
    hoverHeader:SetFrameStrata("FULLSCREEN_DIALOG")
    hoverHeader:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 200)
    hoverHeader:SetSize(600, 50)
    hoverHeader:SetPoint("TOP", WorldMapFrame, "TOP", 0, -36)
    hoverHeader:Hide()

    hoverHeader.text = hoverHeader:CreateFontString(nil, "OVERLAY")
    hoverHeader.text:SetPoint("CENTER")

    local font, size = GameFontNormalHuge:GetFont()
    hoverHeader.text:SetFont(font, size + 2, "OUTLINE")
    hoverHeader.text:SetTextColor(1, 1, 1)
    hoverHeader.text:SetShadowColor(0, 0, 0, 1)
    hoverHeader.text:SetShadowOffset(2, -2)
end

local function BCCMapFix_Initialize()
    if isInitialized then return end
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    isInitialized = true

    CreateHoverHeader()

    WorldMapFrame:HookScript("OnShow", function()
        C_Timer.After(0.2, BCCMapFix_OnMapChanged)
    end)
    hooksecurefunc(WorldMapFrame, "SetMapID", function()
        C_Timer.After(0.2, BCCMapFix_OnMapChanged)
    end)
    WorldMapFrame.ScrollContainer:HookScript("OnMouseWheel", function()
        C_Timer.After(0.05, BCCMapFix_UpdatePositions)
    end)
    WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function()
        C_Timer.After(0.05, BCCMapFix_UpdatePositions)
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end

    C_Timer.After(2, function()
        BCCMapFix_Initialize()
    end)
end)
