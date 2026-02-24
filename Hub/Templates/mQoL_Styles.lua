local addonName, mQoL = ...
mQoL_Styles = mQoL_Styles or {}

-- Scrollbar - Custom scrollbar with modern look
function mQoL_Styles.CreateCustomScrollbar(scrollFrame, scrollChild, opts)
    opts = opts or {}
    local baseWidth = opts.thumbWidth or 8
    local buttonSize = opts.buttonSize or math.max(baseWidth + 6, 14)
    local buttonStep = opts.buttonStep or 20
    local activeBg = { 0.1, 0.1, 0.1, 0.8 }
    local dimBg = { 0.08, 0.08, 0.08, 0.9 }

    -- Visual State - Set button enabled state
    local function SetButtonEnabled(btn, enabled)
        if enabled then
            btn:SetAlpha(1)
            btn:EnableMouse(true)
            btn.bg:SetColorTexture(0.12, 0.12, 0.12, 0.95)
            btn.arrow:SetVertexColor(0.9, 0.9, 0.9, 1)
        else
            btn:SetAlpha(0.35)
            btn:EnableMouse(false)
            btn.bg:SetColorTexture(0.08, 0.08, 0.08, 0.9)
            btn.arrow:SetVertexColor(0.55, 0.55, 0.55, 0.7)
        end
    end

    -- Visual State - Create arrow button
    local function CreateArrowButton(anchorPoint, offsetY, arrow)
        local btn = CreateFrame("Button", nil, scrollFrame)
        btn:SetSize(buttonSize, buttonSize)
        btn:SetPoint(anchorPoint, scrollFrame, anchorPoint, -2, offsetY)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.12, 0.12, 0.12, 0.95)

        btn.border = btn:CreateTexture(nil, "BORDER")
        btn.border:SetPoint("TOPLEFT", 0, 0)
        btn.border:SetPoint("BOTTOMRIGHT", 0, 0)
        btn.border:SetColorTexture(0.25, 0.25, 0.25, 1)

        btn.arrow = btn:CreateTexture(nil, "OVERLAY")
        btn.arrow:SetSize(buttonSize - 6, buttonSize - 6)
        btn.arrow:SetPoint("CENTER")
        btn.arrow:SetTexture(arrow)
        btn.arrow:SetVertexColor(0.85, 0.85, 0.85, 1)

        btn:SetScript("OnEnter", function(self)
            if self:GetAlpha() < 1 then return end
            self.bg:SetColorTexture(0.18, 0.18, 0.18, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0.12, 0.12, 0.12, 0.95)
        end)

        return btn
    end

    local upBtn, downBtn, scrollbar

    upBtn = CreateArrowButton("TOPRIGHT", -2, "Interface\\AddOns\\mQoL\\Media\\Textures\\Up")
    downBtn = CreateArrowButton("BOTTOMRIGHT", 2, "Interface\\AddOns\\mQoL\\Media\\Textures\\Down")

    scrollbar = CreateFrame("Slider", nil, scrollFrame)
    local trackWidth = buttonSize - 2
    scrollbar:SetPoint("TOPRIGHT", upBtn, "BOTTOMRIGHT", 0, -2)
    scrollbar:SetPoint("BOTTOMRIGHT", downBtn, "TOPRIGHT", 0, 2)
    scrollbar:SetWidth(trackWidth)

    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValueStep(1)
    scrollbar:SetValue(0)

    -- Set scrollbar background color
    scrollbar.bg = scrollbar:CreateTexture(nil, "BACKGROUND")
    scrollbar.bg:SetAllPoints()
    scrollbar.bg:SetColorTexture(unpack(activeBg))

    -- Set scrollbar thumb textures
    scrollbar.thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    scrollbar.thumb:SetSize(trackWidth - 2, 30)
    scrollbar.thumb:SetColorTexture(0.6, 0.6, 0.6, 0.9)

    scrollbar.thumb:SetPoint("TOPLEFT", scrollbar, "TOPLEFT", 0, 0)
    scrollbar.thumb:SetPoint("TOPRIGHT", scrollbar, "TOPRIGHT", 0, 0)

    -- Update scrollbar geometry
    local function UpdateGeometry()
        local available = scrollFrame:GetWidth() or buttonSize
        local newBtn = math.max(12, math.min(buttonSize, available - 2))
        local newTrack = math.max(12, math.min(buttonSize, available - 4))

        upBtn:SetSize(newBtn, newBtn)
        downBtn:SetSize(newBtn, newBtn)
        local arrowSize = math.max(10, newBtn - 6)
        upBtn.arrow:SetSize(arrowSize, arrowSize)
        downBtn.arrow:SetSize(arrowSize, arrowSize)

        upBtn:ClearAllPoints()
        downBtn:ClearAllPoints()
        upBtn:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -2)
        downBtn:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 2)

        scrollbar:ClearAllPoints()
        scrollbar:SetPoint("TOPRIGHT", upBtn, "BOTTOMRIGHT", 0, -2)
        scrollbar:SetPoint("BOTTOMRIGHT", downBtn, "TOPRIGHT", 0, 2)
        scrollbar:SetWidth(newTrack)

        scrollbar.thumb:SetWidth(newTrack - 2)
    end

    local function SetThumbActive(active)
        if active then
            scrollbar.thumb:SetColorTexture(0.65, 0.65, 0.65, 0.9)
            scrollbar.thumb:SetAlpha(1)
        else
            scrollbar.thumb:SetAlpha(0)
        end
    end

    local function SetButtonsActive(active)
        SetButtonEnabled(upBtn, active)
        SetButtonEnabled(downBtn, active)
    end

    local function UpdateEdgeButtons(currentScroll, min, max)
        if scrollbar.noScroll then
            SetButtonEnabled(upBtn, false)
            SetButtonEnabled(downBtn, false)
            return
        end
        local upEnabled = currentScroll > min
        local downEnabled = currentScroll < max
        SetButtonEnabled(upBtn, upEnabled)
        SetButtonEnabled(downBtn, downEnabled)
    end

    -- Create thumb frame to handle mouse dragCursor
    local thumbFrame = CreateFrame("Frame", nil, scrollbar)
    thumbFrame:SetPoint("TOPLEFT", scrollbar.thumb, "TOPLEFT")
    thumbFrame:SetPoint("BOTTOMRIGHT", scrollbar.thumb, "BOTTOMRIGHT")
    thumbFrame:EnableMouse(true)

    -- Store drag offset to maintain thumb position
    local dragOffset = 0

    -- Update thumb position on dragCursor (only run when dragging)
    local function OnDragUpdate(self)
        if not self.isDragging or self.noScroll then return end
        
        local _, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        cursorY = cursorY / scale

        local top = self:GetTop()
        local height = self:GetHeight()
        local thumbHeight = self.thumb:GetHeight()

        -- Calculate new position relative to thumb top
        local relativeY = top - cursorY + dragOffset
        relativeY = math.max(0, math.min(height - thumbHeight, relativeY))

        local min, max = self:GetMinMaxValues()
        if max <= min then
            self:SetValue(min)
            return
        end

        local range = max - min
        local newValue = (relativeY / (height - thumbHeight)) * range
        self:SetValue(newValue)
    end

    thumbFrame:SetScript("OnMouseDown", function()
        if scrollbar.noScroll then return end
        scrollbar.isDragging = true
        scrollbar.thumb:SetColorTexture(0.9, 0.9, 0.9, 1)

        -- Calculate drag offset relative to thumb top
        local _, cursorY = GetCursorPosition()
        local scale = scrollbar:GetEffectiveScale()
        cursorY = cursorY / scale

        local top = scrollbar.thumb:GetTop()
        dragOffset = cursorY - top  -- Store offset relative to thumb top
        
        -- Start drag update
        scrollbar:SetScript("OnUpdate", OnDragUpdate)
    end)

    thumbFrame:SetScript("OnMouseUp", function()
        if scrollbar.noScroll then
            scrollbar.isDragging = false
            SetThumbActive(false)
            scrollbar:SetScript("OnUpdate", nil) -- Stop drag update
            return
        end
        scrollbar.isDragging = false
        scrollbar.thumb:SetColorTexture(0.7, 0.7, 0.7, 0.8)
        scrollbar:SetScript("OnUpdate", nil) -- Stop drag update
    end)

    thumbFrame:SetScript("OnEnter", function()
        if scrollbar.noScroll then return end
        scrollbar.thumb:SetColorTexture(0.85, 0.85, 0.85, 1.0)
    end)
    thumbFrame:SetScript("OnLeave", function()
        if scrollbar.noScroll then
            SetThumbActive(false)
        elseif not scrollbar.isDragging then
            scrollbar.thumb:SetColorTexture(0.7, 0.7, 0.7, 0.8)
        end
    end)

    -- Update thumb position when scroll value changes
    scrollbar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)

        local min, max = self:GetMinMaxValues()
        local trackHeight = self:GetHeight()
        local thumbHeight = self.thumb:GetHeight()
        local range = max - min
        if range <= 0 then range = 1 end

        local posY = 0
        if max > min then
            posY = (value / range) * (trackHeight - thumbHeight)
        end
        self.thumb:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -posY)
        self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -posY)

        UpdateEdgeButtons(value, min, max)
    end)

    -- Handle scroll wheel input
    scrollFrame:EnableMouse(true)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        if scrollbar.noScroll then return end
        local current = self:GetVerticalScroll()
        local min, max = scrollbar:GetMinMaxValues()
        local newValue = math.max(min, math.min(max, current - delta * buttonStep))
        self:SetVerticalScroll(newValue)
        scrollbar:SetValue(newValue)
    end)

    local function Nudge(delta)
        if scrollbar.noScroll then return end
        local current = scrollFrame:GetVerticalScroll()
        local min, max = scrollbar:GetMinMaxValues()
        local newValue = math.max(min, math.min(max, current + delta * buttonStep))
        scrollFrame:SetVerticalScroll(newValue)
        scrollbar:SetValue(newValue)
    end

    upBtn:SetScript("OnClick", function() Nudge(-1) end)
    downBtn:SetScript("OnClick", function() Nudge(1) end)

    -- Update scrollbar geometry when content or frame size changes
    local function UpdateScrollbar()
        if not scrollChild or not scrollFrame then return end
        UpdateGeometry()

        local contentHeight = scrollChild:GetHeight()
        local frameHeight = scrollFrame:GetHeight()
        local scrollMax = math.max(0, contentHeight - frameHeight)

        local trackHeight = scrollbar:GetHeight()

        -- Calculate thumb height based on scrollable content (min 12px)
        local thumbHeight = trackHeight
        if scrollMax > 0 then
            local ratio = frameHeight / contentHeight
            thumbHeight = math.max(12, trackHeight * ratio)
        end
        scrollbar.thumb:SetHeight(thumbHeight)

        if scrollMax < 2 then
            scrollbar:Show()
            upBtn:Show()
            downBtn:Show()

            scrollbar.thumb:Hide()
            SetButtonEnabled(upBtn, false)
            SetButtonEnabled(downBtn, false)
            scrollbar:EnableMouse(false)

            scrollbar.noScroll = true
            scrollFrame:SetVerticalScroll(0)
            scrollbar:SetValue(0)
        else
            scrollbar:Show()
            upBtn:Show()
            downBtn:Show()

            scrollbar.thumb:Show()
            SetButtonEnabled(upBtn, true)
            SetButtonEnabled(downBtn, true)
            scrollbar:EnableMouse(true)

            scrollbar.bg:SetColorTexture(unpack(activeBg))
            scrollbar.noScroll = false
            
            scrollbar:SetMinMaxValues(0, scrollMax)
            scrollbar:SetValueStep(1)

            local currentScroll = scrollFrame:GetVerticalScroll()
            if currentScroll > scrollMax then
                currentScroll = scrollMax
            elseif currentScroll < 0 then
                currentScroll = 0
            end
            
            scrollFrame:SetVerticalScroll(currentScroll)
            scrollbar:SetValue(currentScroll)

            SetThumbActive(true)
            SetButtonsActive(true)
            UpdateEdgeButtons(currentScroll, 0, scrollMax)
        end
    end

    scrollbar.UpdateScrollbar = UpdateScrollbar
    UpdateScrollbar()

    -- Store reference on scrollFrame for external access
    scrollFrame.scrollbar = scrollbar

    return scrollbar
end

-- Button - Custom button with modern style
function mQoL_Styles.CreateCustomButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 100, height or 24)

    -- Background texture
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)

    -- Border frame
    btn.border = CreateFrame("Frame", nil, btn)
    btn.border:SetAllPoints()

    if mQoL_Templates and mQoL_Templates.SetBackdrop then
        mQoL_Templates.SetBackdrop(btn.border, {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        }, nil, {0.25, 0.25, 0.25, 1})
    end

    -- Button text
    btn.text = btn:CreateFontString(nil, "OVERLAY")
    btn.text:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text or "Button")
    btn.text:SetTextColor(0.9, 0.9, 0.9)

    -- Button hover effects
    btn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.20, 0.20, 0.20, 1)
        self.text:SetTextColor(1, 1, 1)
    end)

    btn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
        self.text:SetTextColor(0.9, 0.9, 0.9)
    end)

    return btn
end

-- Dropdown - Custom dropdown menu with modern style
mQoL_Styles.dropdownCounter = 0
function mQoL_Styles.CreateCustomDropdown(parent, width, items, selectedValue, onSelect)
    mQoL_Styles._openDropdownLists = mQoL_Styles._openDropdownLists or {}
    mQoL_Styles.dropdownCounter = mQoL_Styles.dropdownCounter + 1

    local dropdown = CreateFrame("Frame", nil, parent)
    dropdown:SetSize(width or 140, 26)

    -- Background texture
    dropdown.bg = dropdown:CreateTexture(nil, "BACKGROUND")
    dropdown.bg:SetAllPoints()
    dropdown.bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)

    -- Text of selected option
    dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropdown.text:SetPoint("LEFT", 8, 0)
    dropdown.text:SetJustifyH("LEFT")
	dropdown.text:SetWidth((width or 140) - 32)
	dropdown.text:SetWordWrap(false)

    local selectedText = nil
    for _, item in ipairs(items) do
        if type(item) == "table" and item.value == selectedValue then
            selectedText = item.text or tostring(item.value)
            break
        end
    end
    dropdown.text:SetText(selectedText or "Select")
    dropdown.value = selectedValue

    -- Dropdown arrow texture
    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Down")

    -- List of options (hidden by default)
    local listName = "mQoL_DropdownList_" .. mQoL_Styles.dropdownCounter
    local list = CreateFrame("Frame", listName, UIParent)
    list:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetFrameLevel(100)
    list:EnableMouse(true)
    list:Hide()
    
    if _G.UISpecialFrames then
        table.insert(_G.UISpecialFrames, listName)
    end

    list.bg = list:CreateTexture(nil, "BACKGROUND")
    list.bg:SetAllPoints()
    list.bg:SetColorTexture(0, 0, 0, 0.9)

    list.border = CreateFrame("Frame", nil, list)
    list.border:SetAllPoints()
    list.border.tex = list.border:CreateTexture(nil, "BORDER")
    list.border.tex:SetAllPoints()
    list.border.tex:SetColorTexture(0.4, 0.4, 0.4, 1)

    list:SetScript("OnShow", function()
        mQoL_Styles._openDropdownLists[list] = true
    end)
    list:SetScript("OnHide", function()
        mQoL_Styles._openDropdownLists[list] = nil
    end)

    local function SyncListScale()
        local desiredEffective = dropdown.GetEffectiveScale and dropdown:GetEffectiveScale() or 1
        local parentEffective = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        if not desiredEffective or desiredEffective <= 0 then desiredEffective = 1 end
        if not parentEffective or parentEffective <= 0 then parentEffective = 1 end
        local localScale = desiredEffective / parentEffective
        if not localScale or localScale <= 0 then localScale = 1 end
        list:SetScale(localScale)
        list:SetWidth(dropdown:GetWidth())
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    end

    -- Fade animations
    local fadeDuration = 0.15
    local mouseWatcher -- Forward declaration for HideList/ShowList access

	local function HideList()
		if not list or not list:IsShown() then return end

		if list.fadeGroup then
			list.fadeGroup:Stop()
		end

		list.fadeGroup = UIFrameFadeOut(list, fadeDuration, 1, 0)
		arrow:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Down")

		C_Timer.After(fadeDuration, function()
			if list and list.Hide and list:IsShown() then
				list:Hide()
                if mouseWatcher then mouseWatcher:Hide() end -- Stop watching
			end
		end)
	end

    local function ShowList()
        SyncListScale()
        list:SetAlpha(0)
        list:Show()
        if mouseWatcher then mouseWatcher:Show() end -- Start watching
        if list.fadeGroup then list.fadeGroup:Stop() end
        list.fadeGroup = UIFrameFadeIn(list, fadeDuration, 0, 1)
        arrow:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Up")
    end
    
    dropdown:SetScript("OnHide", function()
        HideList()
    end)

    -- Hide dropdown when clicking outside
	mouseWatcher = CreateFrame("Frame", nil, dropdown)
    mouseWatcher:Hide()
	mouseWatcher:SetScript("OnUpdate", function()
		if list:IsShown() and not MouseIsOver(dropdown) and not MouseIsOver(list) and IsMouseButtonDown() then
			HideList()
		end
	end)

    dropdown:SetScript("OnMouseDown", function()
        if list:IsShown() then
            HideList()
        else
            ShowList()
        end
    end)

    -- Options list
    local itemHeight = 20
    local buttons = {}
    local highlightR, highlightG, highlightB = 1, 0.82, 0

    local function GetItemColorField(item, field)
        if type(item) ~= "table" then return nil end
        local c = item[field]
        if type(c) ~= "table" then return nil end
        local r = c.r or c[1]
        local g = c.g or c[2]
        local b = c.b or c[3]
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b
        end
        return nil
    end

    local function IsSeparatorItem(item)
        return type(item) == "table" and (item.separator == true or item.isSeparator == true or item.type == "separator")
    end

    local function ApplyBaseTextColor(btn)
        if not btn or not btn.text then return end
        local item = btn.mQoL_item
        local isSelected = item and item.value ~= nil and item.value == dropdown.value
        if isSelected then
            local sr, sg, sb = GetItemColorField(item, "selectedColor")
            if sr then
                btn.text:SetTextColor(sr, sg, sb)
            else
                btn.text:SetTextColor(highlightR, highlightG, highlightB)
            end
            return
        end
        local r, g, b = GetItemColorField(item, "color")
        if r then
            btn.text:SetTextColor(r, g, b)
        else
            btn.text:SetTextColor(1, 1, 1)
        end
    end

    local function RebuildButtons()
        for _, btn in ipairs(buttons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        buttons = {}

        SyncListScale()

        local yOffset = 0
        local sepHeight = 10

        for _, item in ipairs(items) do
            if IsSeparatorItem(item) then
                local sep = CreateFrame("Frame", nil, list)
                sep:SetSize(dropdown:GetWidth(), sepHeight)
                sep:SetPoint("TOPLEFT", 0, -yOffset)
                sep:SetFrameLevel(list:GetFrameLevel() + 2)

                local line = sep:CreateTexture(nil, "ARTWORK")
                line:SetColorTexture(1, 1, 1, 0.50)
                line:SetHeight(1)
                line:SetPoint("LEFT", sep, "LEFT", 8, 0)
                line:SetPoint("RIGHT", sep, "RIGHT", -8, 0)
                line:SetPoint("CENTER", sep, "CENTER", 0, 0)
                sep.line = line

                yOffset = yOffset + sepHeight
                table.insert(buttons, sep)
            else
                local btn = CreateFrame("Button", nil, list)
                btn:SetSize(dropdown:GetWidth(), itemHeight)
                btn:SetPoint("TOPLEFT", 0, -yOffset)

                btn.bg = btn:CreateTexture(nil, "BACKGROUND")
                btn.bg:SetAllPoints()
                btn.bg:SetColorTexture(0.1, 0.1, 0.1, 1)

                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                btn.text:SetPoint("LEFT", 8, 0)
                btn.text:SetText(item.text or tostring(item.value))

                btn.mQoL_item = item
                ApplyBaseTextColor(btn)

                if type(item) == "table" and item.underline == true then
                    local underline = btn:CreateTexture(nil, "OVERLAY")
                    underline:SetColorTexture(1, 1, 1, 0.55)
                    underline:SetPoint("TOPLEFT", btn.text, "BOTTOMLEFT", 0, -1)
                    underline:SetPoint("TOPRIGHT", btn.text, "BOTTOMRIGHT", 0, -1)
                    underline:SetHeight(1)
                    btn.mQoL_underline = underline
                end

                btn:SetScript("OnEnter", function(self)
                    if self.text then
                        local hr, hg, hb = GetItemColorField(self.mQoL_item, "hoverColor")
                        if hr then
                            self.text:SetTextColor(hr, hg, hb)
                        else
                            self.text:SetTextColor(highlightR, highlightG, highlightB)
                        end
                    end
                end)

                btn:SetScript("OnLeave", function(self)
                    ApplyBaseTextColor(self)
                end)

                btn:SetScript("OnClick", function()
                    dropdown.text:SetText(item.text or tostring(item.value))
                    dropdown.value = item.value

                    for _, otherBtn in ipairs(buttons) do
                        if otherBtn and otherBtn.text then
                            ApplyBaseTextColor(otherBtn)
                        end
                    end

                    if item.onSelect then
                        item.onSelect(item.value)
                    elseif onSelect then
                        onSelect(item.value)
                    end

                    HideList()
                end)

                table.insert(buttons, btn)
                yOffset = yOffset + itemHeight
            end
        end

        list:SetHeight(math.max(1, yOffset))
    end

    C_Timer.After(0, function()
        RebuildButtons()
    end)

    function dropdown:SetList(newItems)
        items = newItems or {}
        RebuildButtons()
    end

    function dropdown:SetValue(value)
        for _, item in ipairs(items) do
            if type(item) == "table" and item.value == value then
                dropdown.text:SetText(item.text or tostring(item.value))
                dropdown.value = item.value
                return
            elseif item == value then
                dropdown.text:SetText(tostring(item))
                dropdown.value = item
                return
            end
        end
        dropdown.text:SetText(tostring(value))
        dropdown.value = value
    end

    return dropdown
end

function mQoL_Styles.HideAllDropdownLists()
    if not mQoL_Styles._openDropdownLists then return end
    for list in pairs(mQoL_Styles._openDropdownLists) do
        if list and list.fadeGroup and list.fadeGroup.Stop then
            list.fadeGroup:Stop()
        end
        if list and list.Hide and list.IsShown and list:IsShown() then
            list:Hide()
        end
    end
end

-- Slider - Custom Slider with markers support
function mQoL_Styles.CreateCustomSlider(parent, labelText, minValue, maxValue, step, width, sliderHeight, markers)
    local function NormalizeValue(v)
        if math.floor(v) == v then return string.format("%.1f", v) else return tostring(v) end
    end

    sliderHeight = sliderHeight or 5
    local thumbWidth = 3
    local thumbMultiplier = 0.8
    local thumbHeight = sliderHeight + sliderHeight * thumbMultiplier
    local gap = 4

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width or 200, sliderHeight)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    slider:GetThumbTexture():SetAlpha(0)

    -- FillBar
    slider.fillBar = CreateFrame("StatusBar", nil, slider)
    slider.fillBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    slider.fillBar:SetStatusBarColor(0.6,0.6,0.6,1)

    -- BgBar
    slider.bgBar = slider:CreateTexture(nil, "BACKGROUND")
    slider.bgBar:SetColorTexture(0.15,0.15,0.15,1)

    -- Thumb
    slider.thumb = slider:CreateTexture(nil, "OVERLAY")
    slider.thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    slider.thumb:SetColorTexture(0.6,0.6,0.6,1)
    slider.thumb:SetSize(thumbWidth, thumbHeight)

    -- Label
    slider.label = slider:CreateFontString(nil,"OVERLAY")
    slider.label:SetFont("Fonts\\FRIZQT__.TTF",13)
    slider.label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT",0,16)
    slider.label:SetText(labelText or "Slider")
    slider.label:SetTextColor(1,0.82,0)

    -- Min/Max text
    if not markers then
        slider.lowText = slider:CreateFontString(nil,"OVERLAY")
        slider.lowText:SetFont("Fonts\\FRIZQT__.TTF",12)
        slider.lowText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT",0,-6)
        slider.lowText:SetText(NormalizeValue(minValue))
        slider.lowText:SetTextColor(1,1,1)

        slider.highText = slider:CreateFontString(nil,"OVERLAY")
        slider.highText:SetFont("Fonts\\FRIZQT__.TTF",12)
        slider.highText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT",0,-6)
        slider.highText:SetText(NormalizeValue(maxValue))
        slider.highText:SetTextColor(1,1,1)
    end

    -- Markers
    slider.markersSpec = markers
    slider.markerContainer = CreateFrame("Frame", nil, slider)
    slider.markerContainer:SetPoint("TOPLEFT", slider, "BOTTOMLEFT",0, markers and -5 or -20)
    slider.markerContainer:SetSize(slider:GetWidth(),20)
    slider.markerLabels = {}

    -- Function to calculate position of marker
    function slider:CalculatePosition(value)
        local min,max = self:GetMinMaxValues()
        local percent = (value - min) / (max - min)
        local available = self:GetWidth() - 2*gap - thumbWidth
        return gap + thumbWidth/2 + percent*available
    end

	function slider:UpdateThumb()
		local x = self:CalculatePosition(self:GetValue())

		-- Thumb position
		self.thumb:SetPoint("CENTER", self, "LEFT", x, 0)

		-- Fillbar position
		self.fillBar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.fillBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
		self.fillBar:SetWidth(x - thumbWidth/2 - gap)

		-- BgBar position
		local bgX = x + thumbWidth/2 + gap
		local bgWidth = self:GetWidth() - bgX
		
		-- Hide bgBar if width is less then 1px
		if bgWidth < 1 then
			self.bgBar:Hide()
		else
			self.bgBar:Show()
			self.bgBar:SetPoint("TOPLEFT", self, "TOPLEFT", bgX, 0)
			self.bgBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", bgX, 0)
			self.bgBar:SetWidth(bgWidth)
		end
	end

    function slider:UpdateMarkers()
        for _, f in ipairs(self.markerLabels) do f:Hide() end
        self.markerLabels = {}
        if not self.markersSpec then return end

        for _, mark in ipairs(self.markersSpec.positions or self.markersSpec) do
            local v = mark.value or mark.position or self:GetMinMaxValues()
            local x = self:CalculatePosition(v)

            local line = self.markerContainer:CreateTexture(nil,"OVERLAY")
            line:SetSize(mark.CustomWidth or 3,12)
            line:SetColorTexture(unpack(mark.color or {1,0.82,0}))
            line:SetPoint("CENTER", self.markerContainer, "LEFT", x, -2)
            table.insert(self.markerLabels,line)

            local text = self.markerContainer:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            text:SetText(mark.text or tostring(v))
            text:SetTextColor(unpack(mark.color or {1,0.82,0}))
            text:SetPoint("TOP", line, "BOTTOM",0,-2)
            table.insert(self.markerLabels,text)
        end
    end

    slider:SetScript("OnValueChanged", function(self) self:UpdateThumb() end)
    slider:SetScript("OnShow", function(self) self:UpdateThumb(); self:UpdateMarkers() end)
    slider:SetScript("OnSizeChanged", function(self) self:UpdateThumb(); self:UpdateMarkers() end)

    slider:UpdateThumb()
    slider:UpdateMarkers()

    return slider
end

-- Input Box - Custom modern Input Box
function mQoL_Styles.CreateCustomInputBox(parent, width, height, onEnterCallback)
    local editBox = CreateFrame("EditBox", nil, parent)
    editBox:SetSize(width or 60, height or 20)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    
    -- Background
    editBox.bg = editBox:CreateTexture(nil, "BACKGROUND")
    editBox.bg:SetAllPoints()
    editBox.bg:SetColorTexture(0.15, 0.15, 0.15, 1)

    -- Pixel-perfect border 1px
    local borderColor = {0.25, 0.25, 0.25, 1}
    local thickness = 1

    editBox.borderTop = editBox:CreateTexture(nil, "BORDER")
    editBox.borderTop:SetColorTexture(unpack(borderColor))
    editBox.borderTop:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, 0)
    editBox.borderTop:SetPoint("TOPRIGHT", editBox, "TOPRIGHT", 0, 0)
    editBox.borderTop:SetHeight(thickness)

    editBox.borderBottom = editBox:CreateTexture(nil, "BORDER")
    editBox.borderBottom:SetColorTexture(unpack(borderColor))
    editBox.borderBottom:SetPoint("BOTTOMLEFT", editBox, "BOTTOMLEFT", 0, 0)
    editBox.borderBottom:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 0, 0)
    editBox.borderBottom:SetHeight(thickness)

    editBox.borderLeft = editBox:CreateTexture(nil, "BORDER")
    editBox.borderLeft:SetColorTexture(unpack(borderColor))
    editBox.borderLeft:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, -thickness)
    editBox.borderLeft:SetPoint("BOTTOMLEFT", editBox, "BOTTOMLEFT", 0, thickness)
    editBox.borderLeft:SetWidth(thickness)

    editBox.borderRight = editBox:CreateTexture(nil, "BORDER")
    editBox.borderRight:SetColorTexture(unpack(borderColor))
    editBox.borderRight:SetPoint("TOPRIGHT", editBox, "TOPRIGHT", 0, -thickness)
    editBox.borderRight:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 0, thickness)
    editBox.borderRight:SetWidth(thickness)

    -- Text inset
    editBox:SetTextInsets(4, 4, 2, 2)
    editBox:SetJustifyH("LEFT")

    -- Esc and Enters
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        if onEnterCallback then
            onEnterCallback(self)
        end
        self:ClearFocus()
    end)

    return editBox
end

-- Checkbox - Custom modern Checkbox
function mQoL_Styles.CreateCustomCheckbox(parent, labelText)
    local wrapper = CreateFrame("Button", nil, parent)
    wrapper:SetSize(16, 16)

    -- checkbox background
    wrapper.bg = wrapper:CreateTexture(nil, "BACKGROUND")
    wrapper.bg:SetAllPoints()
    wrapper.bg:SetColorTexture(0.15, 0.15, 0.15, 1)

    -- checkbox border
    local borderThickness = 1
    local borderColor = {0.25, 0.25, 0.25, 1}
    wrapper.border = mQoL_Templates.CreateFrameBorder(wrapper, borderThickness, borderColor)

    -- checkbox cross
    wrapper.cross = wrapper:CreateTexture(nil, "ARTWORK")
    wrapper.cross:SetSize(12, 12)
    wrapper.cross:SetPoint("CENTER", 0, 0)
    wrapper.cross:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Cross")
    wrapper.cross:SetAlpha(0)

    wrapper._value = false

    -- checkbox cross fade-in/out
    local function FadeIn(tex)
        if tex then
            UIFrameFadeIn(tex, 0.15, tex:GetAlpha() or 0, 1)
        end
    end

    local function FadeOut(tex)
        if tex then
            UIFrameFadeOut(tex, 0.15, tex:GetAlpha() or 1, 0)
        end
    end

    function wrapper:UpdateVisual()
        if self._value then
            FadeIn(self.cross)
        else
            FadeOut(self.cross)
        end
    end

    function wrapper:SetValue(value)
        self._value = not not value
        self:UpdateVisual()
    end

    function wrapper:GetValue()
        return self._value
    end

    wrapper:SetScript("OnClick", function(self)
        self._value = not self._value
        self:UpdateVisual()
        if self.OnValueChanged then
            self:OnValueChanged(self._value)
        end
    end)

    wrapper:SetValue(false)

    if labelText then
        wrapper.label = wrapper:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        wrapper.label:SetPoint("LEFT", wrapper, "RIGHT", 4, 0)
        wrapper.label:SetText(labelText)
        wrapper.label:SetTextColor(1, 0.82, 0)
    end

    return wrapper
end

-- Popup - Custom modern popup
function mQoL_Styles.ShowCustomPopup(opts)
    opts = opts or {}
    
    if not mQoL_Styles.globalPopup then
        local f = CreateFrame("Frame", "mQoL_CustomPopup", UIParent)
        f:SetSize(450, 200)
        f:SetPoint("CENTER", 0, 200)
        f:SetFrameStrata("FULLSCREEN")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:EnableKeyboard(true)
        f:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                if self.currentCancelCallback then
                    self.currentCancelCallback()
                end
                self:Hide()
            end
        end)

        -- Popup background
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints()
        f.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)

        -- Popup border
        f.border = CreateFrame("Frame", nil, f)
        f.border:SetAllPoints()
        if mQoL_Templates and mQoL_Templates.SetBackdrop then
            mQoL_Templates.SetBackdrop(f.border, {
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            }, nil, {0.4, 0.4, 0.4, 1})
        end

        -- Popup text
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.text:SetPoint("TOP", 0, -40)
        f.text:SetWidth(410)
        f.text:SetJustifyH("CENTER")

        -- Popup buttons
        local btnWidth = 120
        local btnHeight = 24

        f.acceptBtn = mQoL_Styles.CreateCustomButton(f, "Accept", btnWidth, btnHeight)
        f.acceptBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", -10 - btnWidth, 30)

        f.cancelBtn = mQoL_Styles.CreateCustomButton(f, "Cancel", btnWidth, btnHeight)
        f.cancelBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 10, 30)

        -- Blizzard Style Buttons (Lazy load)
        f.GetBlizzardButtons = function()
            if not f.blizzAcceptBtn then
                f.blizzAcceptBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                f.blizzAcceptBtn:SetSize(btnWidth, btnHeight)
                f.blizzAcceptBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -5, 30)

                f.blizzCancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                f.blizzCancelBtn:SetSize(btnWidth, btnHeight)
                f.blizzCancelBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 5, 30)
            end
            return f.blizzAcceptBtn, f.blizzCancelBtn
        end

        -- EditBox (Lazy load)
        f.GetEditBox = function()
            if not f.editBox then
                f.editBox = mQoL_Styles.CreateCustomInputBox(f, 200, 26, function(self)
                     if f.currentAcceptCallback then f.currentAcceptCallback(self) end
                     f:Hide()
                end)
                f.editBox:SetPoint("CENTER", 0, 0)
                f.editBox:SetScript("OnEscapePressed", function()
                    if f.currentCancelCallback then
                        f.currentCancelCallback()
                    end
                    f:Hide()
                end)
            end
            return f.editBox
        end

        mQoL_Styles.globalPopup = f
    end

    local f = mQoL_Styles.globalPopup
    if opts.width then f:SetWidth(opts.width) end
    if opts.height then f:SetHeight(opts.height) end
    if f.text then f.text:SetWidth(f:GetWidth() - 40) end

    f.text:SetText(opts.text or "Are you sure?")

    -- Setup Buttons based on style preference
    local acceptBtn, cancelBtn

    if opts.useBlizzardButtons then
        -- Hide custom buttons
        f.acceptBtn:Hide()
        f.cancelBtn:Hide()

        -- Show Blizzard buttons
        local bAccept, bCancel = f.GetBlizzardButtons()
        bAccept:Show()
        bCancel:Show()
        acceptBtn, cancelBtn = bAccept, bCancel
    else
        -- Hide Blizzard buttons if exist
        if f.blizzAcceptBtn then f.blizzAcceptBtn:Hide() end
        if f.blizzCancelBtn then f.blizzCancelBtn:Hide() end

        -- Show custom buttons
        f.acceptBtn:Show()
        f.cancelBtn:Show()
        acceptBtn, cancelBtn = f.acceptBtn, f.cancelBtn
    end

    -- Update buttons text
    acceptBtn:SetText(opts.acceptText or "Accept")
    cancelBtn:SetText(opts.cancelText or "Cancel")

    if acceptBtn.Enable then acceptBtn:Enable() end
    if cancelBtn.Enable then cancelBtn:Enable() end

    -- Handle EditBox
    if opts.hasEditBox then
        local eb = f.GetEditBox()
        eb:Show()
        eb:SetWidth(opts.editBoxWidth or (f:GetWidth() - 60))
        eb:SetText("")
        eb:SetMaxLetters(opts.maxLetters or 32)
        eb:SetFocus()

        -- Adjust layout
        f.text:SetPoint("TOP", 0, -30)
        eb:SetPoint("TOP", f.text, "BOTTOM", 0, -20)
    else
        if f.editBox then
            f.editBox:SetScript("OnTextChanged", nil)
            f.editBox:SetScript("OnEnterPressed", function(self)
                if f.currentAcceptCallback then f.currentAcceptCallback(self) end
                f:Hide()
            end)
            f.editBox:SetScript("OnEscapePressed", function()
                if f.currentCancelCallback then
                    f.currentCancelCallback()
                end
                f:Hide()
            end)
            f.editBox:Hide()
        end
        f.text:SetPoint("TOP", 0, -40)
    end

    -- Store callback for EditBox enter press
    f.currentAcceptCallback = opts.onAccept
    f.currentCancelCallback = opts.onCancel

    -- Callbacks
    acceptBtn:SetScript("OnClick", function()
        if opts.onAccept then 
            if opts.hasEditBox and f.editBox then
                 opts.onAccept(f.editBox)
            else
                 opts.onAccept() 
            end
        end
        f:Hide()
    end)

    cancelBtn:SetScript("OnClick", function()
        if opts.onCancel then opts.onCancel() end
        f:Hide()
    end)

    f:Show()
    if opts.hasEditBox and f.editBox then
        f.editBox:SetFocus()
        if f.editBox.HighlightText then
            f.editBox:HighlightText()
        end
    end
    return f
end