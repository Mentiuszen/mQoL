local addonName, L = ...
mQoL_Graphics = mQoL_Graphics or {}

-- Check if Hub is Available
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
    return
end

-- Check Client Version
local clientInfo = mQoL_Hub.clientInfo

-- View and Fog Distance Map
local viewDistances = {
    600, 1200, 2112, 3000, 4000, 5108, 7000, 9000, 11000, 13000, 15000, 17000, 19600
}
local fogDistances = {
    400, 600, 777, 1000, 1277, 1500, 2000, 3000, 4000, 5600
}

local farclipMap = {}
for i, val in ipairs(viewDistances) do
    farclipMap[i] = val
end

-- Defaults -- DO NOT STORE HERE BLIZZARD SETTINGS ONLY FOR CUSTOM FUNCTIONS (Defaults are stored in FirstSetup)
mQoL_Graphics.defaults = {
    Graphics = {
		--LEAVE EMPTY!
    }
}

-- Initialize Database
function mQoL_Graphics:InitializeDB()
    mQoL_Database:MigrateModule("Graphics", self.defaults)
    self.db = mQoL_Database:GetSettings("Graphics")
end

function mQoL_Graphics:CreateGraphicsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)

    local s = mQoL_Database:GetSettings("Graphics")

    -- ViewDistance index
    local currentDistance = tonumber(GetCVar("farclip")) or 600
    local currentIndex = s.ViewDistance or 1
    for i, val in ipairs(viewDistances) do
        if currentDistance <= val then
            currentIndex = i
            break
        end
    end

    -- FogDistance index
    local currentFog = tonumber(GetCVar("horizonStart")) or 400
    local currentFogIndex = s.FogDistance or 1
    for i, val in ipairs(fogDistances) do
        if currentFog <= val then
            currentFogIndex = i
            break
        end
    end

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Advanced Settings - Graphics")
    title:SetTextColor(1, 1, 1)

    -- Separator
    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(1, 1, 1, 0.3)
    separator:SetSize(930, 1)
    separator:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    -- VIEW DISTANCE
    local sliderWidthVD = 250
    local labelVD = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelVD:SetPoint("TOPLEFT", 10, -50)
    labelVD:SetText("View Distance:")
    labelVD:SetTextColor(1, 0.82, 0)

    local sliderTemplate = "OptionsSliderTemplate"
    if clientInfo.isBcc then
        sliderTemplate = "OptionsSliderTemplate, BackdropTemplate"
    end

    local sliderVD = CreateFrame("Slider", addonName .. "_ViewDistanceSlider", panel, sliderTemplate)
    sliderVD:SetPoint("TOPLEFT", 10, -75)
    
    if clientInfo.isBcc then
        sliderVD:SetHeight(17)
        sliderVD:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 }
        })
    end
    sliderVD:SetMinMaxValues(1, #viewDistances)
    sliderVD:SetValueStep(1)
    sliderVD:SetObeyStepOnDrag(true)
    sliderVD:SetWidth(sliderWidthVD)
    sliderVD:SetValue(currentIndex)

    local lowTextVD = _G[sliderVD:GetName().."Low"]
    local highTextVD = _G[sliderVD:GetName().."High"]
    if lowTextVD then lowTextVD:SetText("") end
    if highTextVD then highTextVD:SetText("") end

    local valueTextVD = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueTextVD:SetPoint("LEFT", sliderVD, "RIGHT", 10, 0)
    valueTextVD:SetText(viewDistances[currentIndex])

    -- Classic marker
    local classicPosVD = 6
    local markXVD = ((sliderWidthVD - 19) / (#viewDistances - 1)) * (classicPosVD - 1) + 10

    local lineVD = sliderVD:CreateTexture(nil, "OVERLAY")
    lineVD:SetColorTexture(1, 0.82, 0, 0.8)
    lineVD:SetSize(2, 10)
    lineVD:SetPoint("BOTTOMLEFT", sliderVD, "BOTTOMLEFT", markXVD, -2)

    local classicMarkVD = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classicMarkVD:SetPoint("BOTTOM", lineVD, "TOP", 0, -25)
    classicMarkVD:SetTextColor(1, 0.82, 0)
    classicMarkVD:SetText("Max Classic")

    -- Apply button
    local applyButtonVD = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyButtonVD:SetSize(80, 24)
    applyButtonVD:SetPoint("TOPLEFT", sliderVD, "BOTTOMRIGHT", 50, 20)
    applyButtonVD:SetText("Apply")

    applyButtonVD:SetScript("OnClick", function()
        local vdIndex = math.floor(sliderVD:GetValue() + 0.5)
        local vdValue = viewDistances[vdIndex]
        SetCVar("farclip", vdValue)
        valueTextVD:SetText(vdValue)
        s.ViewDistance = vdIndex
    end)

    sliderVD:SetScript("OnValueChanged", function(self, value)
        local index = math.floor(value + 0.5)
        sliderVD:SetValue(index)
        valueTextVD:SetText(viewDistances[index])
    end)

    --FOG DISTANCE
    local sliderWidthFD = 250
    local labelFD = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelFD:SetPoint("TOPLEFT", 10, -130)
    labelFD:SetText("Fog Distance:")
    labelFD:SetTextColor(1, 0.82, 0)

    local sliderFD = CreateFrame("Slider", addonName .. "_FogDistanceSlider", panel, sliderTemplate)
    sliderFD:SetPoint("TOPLEFT", 10, -155)
    
    if clientInfo.isBcc then
        sliderFD:SetHeight(17)
        sliderFD:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 }
        })
    end
    sliderFD:SetMinMaxValues(1, #fogDistances)
    sliderFD:SetValueStep(1)
    sliderFD:SetObeyStepOnDrag(true)
    sliderFD:SetWidth(sliderWidthFD)
    sliderFD:SetValue(currentFogIndex)

    local lowTextFD = _G[sliderFD:GetName().."Low"]
    local highTextFD = _G[sliderFD:GetName().."High"]
    if lowTextFD then lowTextFD:SetText("") end
    if highTextFD then highTextFD:SetText("") end

    local valueTextFD = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueTextFD:SetPoint("LEFT", sliderFD, "RIGHT", 10, 0)
    valueTextFD:SetText(fogDistances[currentFogIndex])

    -- Classic marker
    local classicPosFD = 5
    local markXFD = ((sliderWidthFD - 19) / (#fogDistances - 1)) * (classicPosFD - 1) + 10

    local lineFD = sliderFD:CreateTexture(nil, "OVERLAY")
    lineFD:SetColorTexture(1, 0.82, 0, 0.8)
    lineFD:SetSize(2, 10)
    lineFD:SetPoint("BOTTOMLEFT", sliderFD, "BOTTOMLEFT", markXFD, -2)

    local classicMarkFD = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classicMarkFD:SetPoint("BOTTOM", lineFD, "TOP", 0, -25)
    classicMarkFD:SetTextColor(1, 0.82, 0)
    classicMarkFD:SetText("Max Classic Zones")

    -- Pandaria marker
    local pandariaPosFD = #fogDistances
    local markXPandariaFD = ((sliderWidthFD - 27) / (#fogDistances - 1)) * (pandariaPosFD - 1) + 10

    local linePandariaFD = sliderFD:CreateTexture(nil, "OVERLAY")
    linePandariaFD:SetColorTexture(1, 0.82, 0, 0.8)
    linePandariaFD:SetSize(2, 10)
    linePandariaFD:SetPoint("BOTTOMLEFT", sliderFD, "BOTTOMLEFT", markXPandariaFD, -2)

    local pandariaMarkFD = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pandariaMarkFD:SetPoint("BOTTOM", linePandariaFD, "TOP", 0, -25)
    pandariaMarkFD:SetTextColor(1, 0.82, 0)
    pandariaMarkFD:SetText("Max Pandaria Zones")

    -- Apply button
    local applyButtonFD = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyButtonFD:SetSize(80, 24)
    applyButtonFD:SetPoint("TOPLEFT", sliderFD, "BOTTOMRIGHT", 50, 20)
    applyButtonFD:SetText("Apply")

    applyButtonFD:SetScript("OnClick", function()
        local fdIndex = math.floor(sliderFD:GetValue() + 0.5)
        local fdValue = fogDistances[fdIndex]
        SetCVar("horizonStart", fdValue)
        valueTextFD:SetText(fdValue)
        s.FogDistance = fdIndex
    end)

    sliderFD:SetScript("OnValueChanged", function(self, value)
        local index = math.floor(value + 0.5)
        sliderFD:SetValue(index)
        valueTextFD:SetText(fogDistances[index])
    end)

    return panel
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        mQoL_Graphics:InitializeDB()

    elseif event == "PLAYER_LOGIN" then
        if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
            mQoL_Hub:RegisterModuleOptions("mQoL_Graphics", "Graphics", function(parent)
                return mQoL_Graphics:CreateGraphicsPanel(parent)
            end)
        end

        local s = mQoL_Database:GetSettings("Graphics")
        if s then
            -- ViewDistance
            if s.ViewDistance then
                local vdValue = farclipMap[s.ViewDistance] or 2112 --fix b91 was 1000 idk why
                SetCVar("farclip", vdValue)
            end
            -- FogDistance
            if s.FogDistance then
                local fdValue = fogDistances[s.FogDistance] or 777
                SetCVar("horizonStart", fdValue)
            end
        end
    end
end)