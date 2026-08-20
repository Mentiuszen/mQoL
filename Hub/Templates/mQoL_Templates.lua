local addonName, mQoL = ...
mQoL_Templates = mQoL_Templates or {}

-- Frame border - Creates a border around a frame
function mQoL_Templates.CreateFrameBorder(parent, thickness, color)
    thickness = thickness or 1
    color = color or {0.5, 0.5, 0.5, 1}

    local border = CreateFrame("Frame", nil, parent)
    border:SetAllPoints(parent)
    border:SetFrameLevel(parent:GetFrameLevel() + 1)

    border.top = border:CreateTexture(nil, "OVERLAY")
    border.top:SetColorTexture(unpack(color))
    border.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.top:SetHeight(thickness)

    border.bottom = border:CreateTexture(nil, "OVERLAY")
    border.bottom:SetColorTexture(unpack(color))
    border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(thickness)

    border.left = border:CreateTexture(nil, "OVERLAY")
    border.left:SetColorTexture(unpack(color))
    border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(thickness)

    border.right = border:CreateTexture(nil, "OVERLAY")
    border.right:SetColorTexture(unpack(color))
    border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(thickness)

    return border
end

-- Animation polyfill for older clients (Legion 7.3.5 and older)
-- Applies missing SetScaleFrom/SetScaleTo methods to animation objects
function mQoL_Templates.ApplyAnimation(anim)
    if not anim then return end

    -- Polyfill for SetScaleFrom / SetScaleTo
    if not anim.SetScaleFrom then
        anim.SetScaleFrom = function(self, x, y)
            self.scaleFrom = {x = x, y = y}
        end
    end

    if not anim.SetScaleTo then
        anim.SetScaleTo = function(self, x, y)
            self.scaleTo = {x = x, y = y}

            -- Apply delta animation if we have both From and To
            if self.scaleFrom and self.scaleTo then
                local fromX, fromY = self.scaleFrom.x, self.scaleFrom.y
                local toX, toY = self.scaleTo.x, self.scaleTo.y

                -- Avoid division by zero
                if fromX == 0 then fromX = 0.01 end
                if fromY == 0 then fromY = 0.01 end

                local deltaX = toX / fromX
                local deltaY = toY / fromY

                if self.SetScale then
                    self:SetScale(deltaX, deltaY)
                end

                -- We hook OnPlay to set the initial scale of the target regions
                local oldOnPlay = self:GetScript("OnPlay")
                self:SetScript("OnPlay", function(a)
                    if oldOnPlay then oldOnPlay(a) end
                    local target = a:GetRegionParent() or a:GetParent()
                    -- Try to find target
                    if a.GetTarget then target = a:GetTarget() end

                    if target and target.SetScale then
                        target:SetScale(math.max(fromX, fromY))
                    end
                end)
            end
        end
    end

    -- Polyfill for SetFromAlpha / SetToAlpha
    if not anim.SetFromAlpha then
        anim.SetFromAlpha = function(self, alpha)
            self.alphaFrom = alpha
        end
    end

    if not anim.SetToAlpha then
        anim.SetToAlpha = function(self, alpha)
            self.alphaTo = alpha

            if self.alphaFrom and self.alphaTo then
                local change = self.alphaTo - self.alphaFrom
                if self.SetChange then
                    self:SetChange(change)
                end

                -- Hook OnPlay to set initial alpha
                local oldOnPlay = self:GetScript("OnPlay")
                self:SetScript("OnPlay", function(a)
                    if oldOnPlay then oldOnPlay(a) end
                    local target = nil
                     if a.GetTarget then target = a:GetTarget() end
                     if not target then target = a:GetRegionParent() or a:GetParent() end

                    if target and target.SetAlpha then
                        target:SetAlpha(self.alphaFrom)
                    end
                end)
            end
        end
    end

    -- Polyfill for SetOffset (Translation)
    if not anim.SetOffset then
        anim.SetOffset = function(self, x, y)
             if self.SetTranslation then
                 self:SetTranslation(x, y)
             end
        end
    end

    return anim
end

-- Universal backdrop function
function mQoL_Templates.SetBackdrop(frame, backdrop, bgColor, borderColor)
    if not frame then return end

    if not frame.mQoL_bg then
        frame.mQoL_bg = frame:CreateTexture(nil, "BACKGROUND")
        frame.mQoL_bg:SetAllPoints()
    end

    if backdrop and backdrop.bgFile then
        frame.mQoL_bg:SetTexture(backdrop.bgFile)
        if backdrop.tile then
             frame.mQoL_bg:SetHorizTile(backdrop.tile)
             frame.mQoL_bg:SetVertTile(backdrop.tile)
        end
        if bgColor then
            frame.mQoL_bg:SetVertexColor(unpack(bgColor))
        else
            frame.mQoL_bg:SetVertexColor(1,1,1,1)
        end
    else
        -- Solid color background if no bgFile
        if bgColor then
            frame.mQoL_bg:SetColorTexture(unpack(bgColor))
        else
            frame.mQoL_bg:SetColorTexture(0,0,0,0) -- Transparent
        end
    end

    -- Handle Border
    if backdrop and (backdrop.edgeFile or backdrop.edgeSize) then
        local thickness = backdrop.edgeSize or 1
        local bColor = borderColor or {1, 1, 1, 1}
        
        -- Apply insets if provided
        local insets = backdrop.insets or { left=0, right=0, top=0, bottom=0 }
        frame.mQoL_bg:SetPoint("TOPLEFT", insets.left, -insets.top)
        frame.mQoL_bg:SetPoint("BOTTOMRIGHT", -insets.right, insets.bottom)
        
        if not frame.mQoL_borderFrame then
             frame.mQoL_borderFrame = mQoL_Templates.CreateFrameBorder(frame, thickness, bColor)
        else
             -- Update existing border
             local bf = frame.mQoL_borderFrame
             bf.top:SetHeight(thickness)
             bf.bottom:SetHeight(thickness)
             bf.left:SetWidth(thickness)
             bf.right:SetWidth(thickness)
             
             bf.top:SetColorTexture(unpack(bColor))
             bf.bottom:SetColorTexture(unpack(bColor))
             bf.left:SetColorTexture(unpack(bColor))
             bf.right:SetColorTexture(unpack(bColor))
        end
        frame.mQoL_borderFrame:Show()
    else
        -- No border requested
        if frame.mQoL_borderFrame then
            frame.mQoL_borderFrame:Hide()
        end
        -- Reset bg points
        frame.mQoL_bg:ClearAllPoints()
        frame.mQoL_bg:SetAllPoints()
    end
end

-- Create Button
function mQoL_Templates.CreateButton(parent, text, width, height)
    -- Try to use the style library first
    if mQoL_Styles and mQoL_Styles.CreateCustomButton then
        return mQoL_Styles.CreateCustomButton(parent, text, width, height)
    end

    -- Fallback implementation
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 100, height or 24)

    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)

    -- Border using our own SetBackdrop if available
    if mQoL_Templates.SetBackdrop then
        mQoL_Templates.SetBackdrop(btn, {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        }, nil, {0.3, 0.3, 0.3, 1})
    end

    -- Text
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text or "Button")

    -- Scripts
    btn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
            self.text:SetTextColor(1, 1, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
        self.text:SetTextColor(1, 0.82, 0)
    end)
    btn:SetScript("OnDisable", function(self)
        self.text:SetTextColor(0.5, 0.5, 0.5)
    end)
    btn:SetScript("OnEnable", function(self)
        self.text:SetTextColor(1, 0.82, 0)
    end)

    return btn
end

-- Create a standard Close "X" button
function mQoL_Templates.CreateCloseButton(parent, size, onClick)
    size = size or 20
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText("X")
    btn.text:SetTextColor(1, 0.2, 0.2)

    btn:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.4, 0.4) end)
    btn:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 0.2, 0.2) end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    else
        -- Default behavior: Hide parent
        btn:SetScript("OnClick", function() 
            if parent.Hide then parent:Hide() end 
        end)
    end

    return btn
end

-- Create a simple dropdown
function mQoL_Templates.CreateSimpleDropdown(parent, width, onSelect)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 150, 24)

    -- Main Button
    f.btn = CreateFrame("Button", nil, f)
    f.btn:SetAllPoints()

    -- Background
    f.btn.bg = f.btn:CreateTexture(nil, "BACKGROUND")
    f.btn.bg:SetAllPoints()
    f.btn.bg:SetColorTexture(0.1, 0.1, 0.1, 1)

    -- Border
    if mQoL_Templates.SetBackdrop then
        mQoL_Templates.SetBackdrop(f.btn, {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        }, nil, {0.3, 0.3, 0.3, 1})
    end

    -- Arrow
    f.arrow = f.btn:CreateTexture(nil, "OVERLAY")
    f.arrow:SetSize(16, 16)
    f.arrow:SetPoint("RIGHT", -4, 0)
    f.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    f.arrow:SetTexCoord(0.2, 0.8, 0.2, 0.8)

    -- Text
    f.text = f.btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("LEFT", 8, 0)
    f.text:SetPoint("RIGHT", f.arrow, "LEFT", -4, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetText("")

    -- Scripts
    f.btn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    f.btn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.1, 0.1, 0.1, 1) end)

    -- Dropdown List (The popup)
    f.list = CreateFrame("Frame", nil, f)
    f.list:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
    f.list:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -2)
    f.list:SetHeight(1) -- Will be auto-sized
    f.list:SetFrameStrata("DIALOG")
    f.list:SetToplevel(true)
    f.list:Hide()

    if mQoL_Templates.SetBackdrop then
        mQoL_Templates.SetBackdrop(f.list, {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = true, tileSize = 16, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }, {0.05, 0.05, 0.05, 1}, {0.3, 0.3, 0.3, 1})
    end

    f.items = {}
    f.buttons = {}

    local BUTTON_HEIGHT = 20

    -- Function to refresh the list visualization
    function f:Refresh()
        local count = #f.items
        f.list:SetHeight((count * BUTTON_HEIGHT) + 4)

        for i, item in ipairs(f.items) do
            local btn = f.buttons[i]
            if not btn then
                btn = CreateFrame("Button", nil, f.list)
                btn:SetHeight(BUTTON_HEIGHT)
                btn:SetPoint("LEFT", 2, 0)
                btn:SetPoint("RIGHT", -2, 0)

                btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
                btn.hl:SetAllPoints()
                btn.hl:SetColorTexture(1, 0.82, 0, 0.2)

                btn.txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.txt:SetPoint("LEFT", 6, 0)

                btn:SetScript("OnClick", function()
                    f:SetText(item.text)
                    if item.func then item.func() end
                    if onSelect then onSelect(item.value) end
                    f.list:Hide()
                end)

                f.buttons[i] = btn
            end

            btn:SetPoint("TOP", 0, -((i-1) * BUTTON_HEIGHT) - 2)
            btn.txt:SetText(item.text)
            btn:Show()
        end

        -- Hide unused buttons
        for i = count + 1, #f.buttons do
            f.buttons[i]:Hide()
        end
    end

    -- API
    function f:SetText(txt)
        f.text:SetText(txt)
    end

    function f:AddItem(text, func)
        table.insert(f.items, {text = text, func = func})
    end

    function f:ClearItems()
        f.items = {}
        f:Refresh()
    end

    f.btn:SetScript("OnClick", function()
        if f.list:IsShown() then
            f.list:Hide()
        else
            f:Refresh()
            f.list:Show()
        end
    end)

    return f
end

-- Universal Spacing API
mQoL_Templates.Spacing = {
    Standard = -20,
    SectionHeader = -25,
    TopSeparator = -20,
    AfterTitle = -25,
    InfoCollapsedOffset = 25,
    InfoExpandedOffset = 25
}

-- Add a standardized gap or separator to the container
-- type: "Standard", "Additional", "Custom", "BottomSeparator", "WarningSeparator", "MainSeparator", "TopSeparator"
function mQoL_Templates.AddGap(container, gapType, customSize)
    if not container then return end

    local StandardGap = mQoL_Templates.Spacing.Standard
    local TopSeparatorGap = mQoL_Templates.Spacing.TopSeparator

    if gapType == "Standard" then
        container.currentY = container.currentY + StandardGap
        if container._mQoL_LastGapType == "Standard" and container._mQoL_LastGapSize == StandardGap then
            container._mQoL_LastGapCount = (container._mQoL_LastGapCount or 1) + 1
        else
            container._mQoL_LastGapCount = 1
        end
        container._mQoL_LastGapType = "Standard"
        container._mQoL_LastGapSize = StandardGap

    elseif gapType == "Additional" then
        if customSize then
            local sign = StandardGap <= 0 and -1 or 1
            local px = math.abs(customSize)
            container.currentY = container.currentY + (sign * px)
        end
        container._mQoL_LastGapType = "Additional"
        container._mQoL_LastGapSize = customSize
        container._mQoL_LastGapCount = nil

    elseif gapType == "Custom" then
        if customSize then
            local sign = StandardGap <= 0 and -1 or 1
            local px = math.abs(customSize)
            container.currentY = container.currentY + (sign * px)
        end
        container._mQoL_LastGapType = "Custom"
        container._mQoL_LastGapSize = customSize
        container._mQoL_LastGapCount = nil

    elseif gapType == "BottomSeparator" then
        if container._mQoL_LastGapType == "Standard" and container._mQoL_LastGapSize == StandardGap then
            local count = container._mQoL_LastGapCount or 1
            container.currentY = container.currentY - (StandardGap * count)
        end
        container._mQoL_LastGapType = nil
        container._mQoL_LastGapSize = nil
        container._mQoL_LastGapCount = nil

        local opts = type(customSize) == "table" and customSize or nil
        local thickness = (opts and opts.thickness) or 1
        local sign = StandardGap <= 0 and -1 or 1
        local defaultTotalGap = math.abs(StandardGap) + thickness
        local totalGap = defaultTotalGap
        if type(customSize) == "number" then
            totalGap = math.abs(customSize)
        elseif opts and (opts.gap or opts.size) then
            totalGap = math.abs(opts.gap or opts.size)
        end
        if totalGap < thickness then totalGap = thickness end
        local padBefore = math.floor((totalGap - thickness) / 2)
        local padAfter = (totalGap - thickness) - padBefore
        container.currentY = container.currentY + (sign * padBefore)

        local sep = container:CreateTexture(nil, "ARTWORK")
        local color = (opts and opts.color) or { 1, 1, 1, 0.15 }
        sep:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 0.15)
        sep:SetPoint("TOPLEFT", 20, container.currentY)
        sep:SetSize((opts and opts.width) or 770, thickness)

        container.currentY = container.currentY + (sign * (thickness + padAfter))
        container._mQoL_LastGapType = "BottomSeparator"
        container._mQoL_LastGapSize = sign * totalGap
        container._mQoL_LastGapCount = nil

    elseif gapType == "WarningSeparator" then
        if container._mQoL_LastGapType == "Standard" and container._mQoL_LastGapSize == StandardGap then
            local count = container._mQoL_LastGapCount or 1
            container.currentY = container.currentY - (StandardGap * count)
        end
        container._mQoL_LastGapType = nil
        container._mQoL_LastGapSize = nil
        container._mQoL_LastGapCount = nil

        local opts = type(customSize) == "table" and customSize or {}
        local sign = StandardGap <= 0 and -1 or 1

        local topPad = opts.topPad or 15
        container.currentY = container.currentY + (sign * topPad)

        local text = opts.text or opts.label or "Warning"
        local textColor = opts.textColor or { 1, 0.2, 0.2, 1 }
        local fontTemplate = opts.fontTemplate or "GameFontNormal"
        local textGap = opts.textGap or 5

        local warningText = container:CreateFontString(nil, "OVERLAY", fontTemplate)
        warningText:SetPoint("TOPLEFT", 20, container.currentY)
        warningText:SetText(text)
        warningText:SetTextColor(textColor[1] or 1, textColor[2] or 0.2, textColor[3] or 0.2, textColor[4] or 1)

        local textHeight = warningText.GetStringHeight and warningText:GetStringHeight() or 14
        container.currentY = container.currentY + (sign * (textHeight + textGap))

        local thickness = opts.thickness or 1
        local defaultTotalGap = math.abs(StandardGap) + thickness
        local totalGap = math.abs(opts.gap or opts.size or defaultTotalGap)
        if totalGap < thickness then totalGap = thickness end
        local padAfter = totalGap - thickness
        if padAfter < 0 then padAfter = 0 end

        local sep = container:CreateTexture(nil, "ARTWORK")
        local lineColor = opts.lineColor or { 1, 1, 1, 0.15 }
        sep:SetColorTexture(lineColor[1] or 1, lineColor[2] or 1, lineColor[3] or 1, lineColor[4] or 0.15)
        sep:SetPoint("TOPLEFT", 20, container.currentY)
        sep:SetSize(opts.width or 770, thickness)

        container.currentY = container.currentY + (sign * (thickness + padAfter))
        container._mQoL_LastGapType = "WarningSeparator"
        container._mQoL_LastGapSize = sign * totalGap
        container._mQoL_LastGapCount = nil

    elseif gapType == "MainSeparator" or gapType == "TopSeparator" then
        if container._mQoL_LastGapType == "Standard" and container._mQoL_LastGapSize == StandardGap then
            local count = container._mQoL_LastGapCount or 1
            container.currentY = container.currentY - (StandardGap * count)
        end
        container._mQoL_LastGapType = nil
        container._mQoL_LastGapSize = nil
        container._mQoL_LastGapCount = nil

        local thickness = 1
        local baseGap = TopSeparatorGap or StandardGap
        local sign = baseGap <= 0 and -1 or 1
        local totalGap = math.abs(customSize or baseGap)
        if totalGap < thickness then totalGap = thickness end
        local padBefore = math.floor((totalGap - thickness) / 2)
        local padAfter = (totalGap - thickness) - padBefore
        container.currentY = container.currentY + (sign * padBefore)

        local sep = container:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(1, 1, 1, 0.3)
        sep:SetPoint("TOPLEFT", 20, container.currentY)
        sep:SetSize(770, thickness)

        container.currentY = container.currentY + (sign * (thickness + padAfter))
        container._mQoL_LastGapType = gapType
        container._mQoL_LastGapSize = sign * totalGap
        container._mQoL_LastGapCount = nil
    end
end

function mQoL_Templates.CreateScrollPanel(parent, opts)
    opts = opts or {}
    local width = opts.width or 850
    local height = opts.height or 600

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetSize(width, height)
    scrollFrame:SetPoint("CENTER")

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width, height)
    scrollFrame:SetScrollChild(scrollChild)

    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        mQoL_Styles.CreateCustomScrollbar(scrollFrame, scrollChild, {
            thumbWidth = 8,
            buttonSize = 14,
            buttonStep = 20,
        })
    end

    return scrollFrame, scrollChild
end

function mQoL_Templates.PanelStart(panel)
    panel.currentY = -10
end

function mQoL_Templates.PanelTitle(panel, titleText, fontTemplate)
    local title = panel:CreateFontString(nil, "OVERLAY", fontTemplate or "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, panel.currentY)
    title:SetText(titleText or "")
    title:SetTextColor(1, 1, 1)
    panel.currentY = panel.currentY + mQoL_Templates.Spacing.AfterTitle
    return title
end

function mQoL_Templates.PanelInfo(panel, infoOpts)
    if not infoOpts then return panel.currentY end
    if not mQoL_Hub or type(mQoL_Hub.CreateInfoSection) ~= "function" then return panel.currentY end
    local newYOffset, infoButton, explanationFrame = mQoL_Hub.CreateInfoSection(panel, panel.currentY, infoOpts)
    if type(newYOffset) == "number" then
        panel.currentY = newYOffset
    end
    return panel.currentY, infoButton, explanationFrame
end

function mQoL_Templates.CreateContentContainer(panel)
    local contentContainer = CreateFrame("Frame", nil, panel)
    contentContainer:SetPoint("TOPLEFT", 0, panel.currentY)
    contentContainer:SetSize(850, 600 - math.abs(panel.currentY))
    panel.contentContainer = contentContainer
    contentContainer.currentY = 0
    contentContainer.optionsLabels = {}
    panel.optionsLabels = contentContainer.optionsLabels
    return contentContainer
end

function mQoL_Templates.BeginOptions(panel, separatorType)
    local contentContainer = mQoL_Templates.CreateContentContainer(panel)
    mQoL_Templates.AddGap(contentContainer, separatorType or "TopSeparator")
    return contentContainer
end

function mQoL_Templates.UpdateScrollChildHeight(scrollFrame, scrollChild, contentContainer)
    if not (scrollFrame and scrollChild and contentContainer) then return end
    local _, _, _, _, containerYOffset = contentContainer:GetPoint()
    containerYOffset = containerYOffset or 0
    local contentHeight = math.abs(containerYOffset) + math.abs(contentContainer.currentY or 0)
    local minHeight = (scrollFrame and scrollFrame:GetHeight()) or 0
    local totalHeight = math.max(contentHeight, minHeight)
    scrollChild:SetHeight(totalHeight)
    if scrollFrame.scrollbar and scrollFrame.scrollbar.UpdateScrollbar then
        scrollFrame.scrollbar:UpdateScrollbar()
    end
end

function mQoL_Templates.CreateStandardOptionsPanel(parent, titleText, infoOpts, separatorType)
    local scrollFrame, panel = mQoL_Templates.CreateScrollPanel(parent)
    mQoL_Templates.PanelStart(panel)
    if titleText then
        mQoL_Templates.PanelTitle(panel, titleText)
    end
    local infoButton, explanationFrame
    if infoOpts then
        _, infoButton, explanationFrame = mQoL_Templates.PanelInfo(panel, infoOpts)
    end
    local contentContainer = mQoL_Templates.BeginOptions(panel, separatorType)
    return scrollFrame, panel, contentContainer, infoButton, explanationFrame
end
