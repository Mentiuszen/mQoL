local addonName, _ = ...
mQoL_Graphics = mQoL_Graphics or {}

-- mQoL_Hub TOC DETECTION
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
	return
end

-- ToC Detection
local clientInfo = mQoL_VersionDetection.clientInfo

-- Styles
local CreateCustomButton = mQoL_Styles.CreateCustomButton
local CreateCustomDropdown = mQoL_Styles.CreateCustomDropdown
local CreateCustomSlider = mQoL_Styles.CreateCustomSlider
local CreateCustomInputBox = mQoL_Styles.CreateCustomInputBox
local CreateCustomCheckbox = mQoL_Styles.CreateCustomCheckbox

-- Defaults
mQoL_Graphics.defaults = {
    Graphics = {
        --dont store here default values (blizzard cvars are handled by FirstSetup and DatabaseSafety)
    }
}

-- Initialize DB
function mQoL_Graphics:InitializeDB()
	self.db = mQoL_Database:MigrateModule("Graphics", self.defaults)
end

-- Apply Settings
function mQoL_Graphics:ApplySettings()
    local s = self.db.settings.Graphics
    if not s then return end

    if s.ViewDistance then
        SetCVar("farclip", s.ViewDistance)
    end

    if s.FogDistance then
        SetCVar("horizonStart", s.FogDistance)
    end
end

function mQoL_Graphics:SetupCheckpointSlider(slider, editBox, checkpoints, onApply, initialValue)
    assert(type(checkpoints) == "table" and #checkpoints > 0, "Checkpoints table must not be empty")

    local function FindClosestIndex(value)
        local closestIndex, minDiff = 1, math.huge
        for i, v in ipairs(checkpoints) do
            local diff = math.abs(v - value)
            if diff < minDiff then
                minDiff = diff
                closestIndex = i
            end
        end
        return closestIndex
    end

    local function FindClosestValue(value)
        return checkpoints[FindClosestIndex(value)]
    end

    local function UpdateSliderAndInput(val)
        local closest = FindClosestValue(val)
        if editBox then
            editBox:SetText(tostring(closest))
        end
        if slider then
            slider:SetValue(FindClosestIndex(closest))
            if slider.UpdateThumb then slider:UpdateThumb() end
        end
        if onApply then
            onApply(closest)
        end
    end

    local function ApplyButtonPressed()
        if editBox then
            local val = tonumber(editBox:GetText()) or checkpoints[1]
            UpdateSliderAndInput(val)
        end
    end

    if initialValue then
        UpdateSliderAndInput(initialValue)
    end

    if editBox then
        editBox:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            local cleanText = text:gsub("[^0-9]", "")
            if cleanText ~= text then
                self:SetText(cleanText)
            end
        end)

        editBox:SetScript("OnEnterPressed", function(self)
            ApplyButtonPressed()
            self:ClearFocus()
        end)
    end

    if slider then
        slider:SetScript("OnValueChanged", function(self, index)
            local value = checkpoints[index] or checkpoints[1]
            if editBox then
                editBox:SetText(tostring(value))
            end
            if slider.UpdateThumb then slider:UpdateThumb() end
        end)
    end

    return ApplyButtonPressed
end

function mQoL_Graphics:CreateGraphicsPanel(parent)
    local s = self.db.settings.Graphics or {}
    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Graphics Settings", {
        text = "How Graphics Settings works?",
        textColor = {1, 0.82, 0},
        explanation = "Graphics Settings allow you to change settings that Blizzard removed from the options panel.\n\n• View Distance, which is missing in the Blizzard options panel, can be changed here.\n• Max Range in different game versions is shown by markers on the sliders.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "TopSeparator")

    local AddGap = mQoL_Templates.AddGap

    local function AddOptionRow(panel, label, type, opts, extra, applyFunc)
        return mQoL_Hub:AddOptionRow(panel, label, type, opts, extra, applyFunc)
    end

    -- Checkpoints
    local viewDistances = {600,1200,2112,3000,4000,5108,7000,9000,11000,13000,15000,17000,19600}
    local fogDistances = {400,600,777,1000,1277,1500,2000,3000,4000,5600}

    -- Get Start Index Function
    local function GetStartIndex(db, defaults, key, checkpoints, cvarName)
        local cvarValue
        if cvarName then
            cvarValue = tonumber(GetCVar(cvarName))
        end
        local val = cvarValue or (db and db[key]) or (defaults and defaults[key]) or checkpoints[1]
        -- Find closest index
        local closestIndex, minDiff = 1, math.huge
        for i, v in ipairs(checkpoints) do
            local diff = math.abs(v - val)
            if diff < minDiff then
                minDiff = diff
                closestIndex = i
            end
        end
        return closestIndex
    end

    -- VIEW DISTANCE (Farclip)
    local viewEditBox = CreateCustomInputBox(contentContainer)
    viewEditBox:SetSize(60,28)

    local viewStartIndex = GetStartIndex(s, mQoL_Graphics.defaults.Graphics, "ViewDistance", viewDistances, "farclip")

    local viewApplyFunc -- Declarate variable for Apply function

    local _, viewSlider = AddOptionRow(contentContainer, "View Distance", "slider", {
        min = 1,
        max = #viewDistances,
        step = 1,
        value = viewStartIndex,
        hasMarkers = true,
        markers = {
            realValues = viewDistances,
            positions = { {position=6, text="Max Classic+", color={1,0.82,0}} }
        },
        onValueChanged = function(_, index)
            viewEditBox:SetText(tostring(viewDistances[index]))
        end,
        applyLabel = "Apply View",
        applyWidth = 120
    }, {viewEditBox}, function()
        viewApplyFunc()
    end)

    viewApplyFunc = mQoL_Graphics:SetupCheckpointSlider(viewSlider, viewEditBox, viewDistances, function(val)
        s.ViewDistance = val
        mQoL_Graphics:ApplySettings()
    end, viewDistances[viewStartIndex])

    -- FOG DISTANCE (HorizonStart)
    local fogEditBox = CreateCustomInputBox(contentContainer)
    fogEditBox:SetSize(60,28)

    local fogStartIndex = GetStartIndex(s, mQoL_Graphics.defaults.Graphics, "FogDistance", fogDistances, "horizonStart")

    local fogApplyFunc -- Declare variable for Apply function

    local _, fogSlider = AddOptionRow(contentContainer, "Fog Distance", "slider", {
        min = 1,
        max = #fogDistances,
        step = 1,
        value = fogStartIndex,
        hasMarkers = true,
        markers = {
            realValues = fogDistances,
            positions = {
                {position=5, text="Max Classic+", color={1,0.82,0}},
                {position=#fogDistances, text="Max Wrath+", color={1,0.82,0}}
            }
        },
        onValueChanged = function(_, index)
            fogEditBox:SetText(tostring(fogDistances[index]))
        end,
        applyLabel = "Apply Fog",
        applyWidth = 120
    }, {fogEditBox}, function()
        fogApplyFunc()
    end)

    fogApplyFunc = mQoL_Graphics:SetupCheckpointSlider(fogSlider, fogEditBox, fogDistances, function(val)
        s.FogDistance = val
        mQoL_Graphics:ApplySettings()
    end, fogDistances[fogStartIndex])

    AddGap(contentContainer, "Additional", 40)

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self,event,arg1)
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("Graphics") then return end

    if event=="ADDON_LOADED" and arg1==addonName then
        mQoL_Graphics:InitializeDB()
    elseif event=="PLAYER_LOGIN" then
        if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
            mQoL_Hub:RegisterModuleOptions("mQoL_Graphics","Graphics",function(parent)
                return mQoL_Graphics:CreateGraphicsPanel(parent)
            end)
        end
        if mQoL_Graphics.db and mQoL_Graphics.db.settings and mQoL_Graphics.db.settings.Graphics then
            mQoL_Graphics:ApplySettings()
        end
    end
end)