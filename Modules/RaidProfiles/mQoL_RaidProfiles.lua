local addonName, _ = ...
mQoL_RaidProfiles = mQoL_RaidProfiles or {}

-- mQoL_Hub TOC DETECTION
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
	return
end

local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local GetClassColor = mQoL_Utils.GetClassColor

-- Styles
local CreateCustomScrollbar = mQoL_Styles.CreateCustomScrollbar
local CreateCustomButton = mQoL_Styles.CreateCustomButton

--Info Box
local CreateInfoSection = mQoL_Hub.CreateInfoSection

-- Helper function for backwards compatibility (used by UI)
local function GetRaidFrameCVars()
    return mQoL_RaidProfiles.VersionAdapters:GetCVars()
end

function mQoL_RaidProfiles:HookSettingsPanelRetail()
    if self.hookedSettings then return end

    if not Settings or not Settings.RegisterVerticalLayoutCategory or not CreateSettingsButtonInitializer then
        return
    end

    local function AddSaveButton()
        if not Settings.INTERFACE_CATEGORY_ID then 
            return false
        end

        local category = Settings.GetCategory(Settings.INTERFACE_CATEGORY_ID)
        if not category then 
            return false
        end

        local layout = SettingsPanel:GetLayout(category)
        if not layout then 
            return false
        end

        local function OnClick()
            if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
                mQoL_Styles.ShowCustomPopup({
                    text = "Enter name for this Raid Profile to save in mQoL:",
                    hasEditBox = true,
                    maxLetters = 32,
                    acceptText = "Save",
                    onAccept = function(editBox)
                         local text = editBox:GetText()
                         if text and text ~= "" then
                            if text:lower() == "none" then
                                 print(addonName .. ": Error: Profile name cannot be 'None'.")
                                 return
                            end
                            mQoL_RaidProfiles:SaveRaidProfile(text)
                        end
                    end
                })
            else
                 -- Fallback if styles missing (unlikely)
                 print(addonName .. ": Error - Styles module not found.")
            end
        end

        local initializer = CreateSettingsButtonInitializer(
            "mQoL Save Profile", 
            "Save Raid Profile to mQoL",
            OnClick, 
            function() Settings.CreateOptionsInitTooltip(nil, "Save Profile", "Save your current Raid Frame settings to mQoL's account-wide storage.", nil) end,
            true
        )

        local inserted = false
        if layout.GetInitializers then
            local initializers = layout:GetInitializers()
            local raidFramesIndex = nil

            for i, init in ipairs(initializers) do
                if init.GetName and init:GetName() == RAID_FRAMES_LABEL then
                    raidFramesIndex = i
                    break
                end
            end

            if raidFramesIndex then
                table.insert(initializers, raidFramesIndex + 1, initializer)
                inserted = true
            end
        end

        if not inserted then
            layout:AddInitializer(initializer)
        end

        return true
    end

    if AddSaveButton() then
        self.hookedSettings = true
    end
end

function mQoL_RaidProfiles:HookSettingsPanelClassic()
    if self.hookedClassicSettings then return end

    if not SettingsPanel or not RaidProfilesMixin or not RaidProfilesMixin.Init then
        return
    end

    local function AttachSaveButton(control)
        if control.mQoLSaveButton then
            return
        end

        local newBtn = control.NewButton
        local deleteBtn = control.DeleteButton
        if not newBtn or not deleteBtn then
            return
        end

        local function OnClick()
            if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
                mQoL_Styles.ShowCustomPopup({
                    text = "Enter name for this Raid Profile to save in mQoL:",
                    hasEditBox = true,
                    maxLetters = 32,
                    acceptText = "Save",
                    onAccept = function(editBox)
                         local text = editBox:GetText()
                         if text and text ~= "" then
                            if text:lower() == "none" then
                                 print(addonName .. ": Error: Profile name cannot be 'None'.")
                                 return
                            end
                            mQoL_RaidProfiles:SaveRaidProfile(text)
                        end
                    end
                })
            else
                 print(addonName .. ": Error - Styles module not found.")
            end
        end

        local btn = CreateFrame("Button", nil, control, "UIPanelButtonTemplate")
        btn:SetSize(130, 22)
        btn:SetText("Save to mQoL")
        btn:SetScript("OnClick", OnClick)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine("Save Raid Profile to mQoL", 1, 0.82, 0)
            GameTooltip:AddLine("Save current Raid Frame settings to mQoL's account-wide storage.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local dropdown = control.Control and control.Control.Dropdown
        if dropdown then
            local spacing = 5
            local newWidth = newBtn:GetWidth()
            local deleteWidth = deleteBtn:GetWidth()
            local saveWidth = btn:GetWidth()

            if newWidth == 0 then newWidth = 100 end
            if deleteWidth == 0 then deleteWidth = 100 end
            if saveWidth == 0 then saveWidth = 130 end

            local totalWidth = newWidth + deleteWidth + saveWidth + (spacing * 2)

            newBtn:ClearAllPoints()
            deleteBtn:ClearAllPoints()
            btn:ClearAllPoints()

            newBtn:SetPoint("TOPLEFT", dropdown, "BOTTOM", -totalWidth / 2, 0)
            deleteBtn:SetPoint("LEFT", newBtn, "RIGHT", spacing, 0)
            btn:SetPoint("LEFT", deleteBtn, "RIGHT", spacing, 0)
        else
            btn:SetPoint("LEFT", deleteBtn, "RIGHT", 5, 0)
        end

        control.mQoLSaveButton = btn
    end

    hooksecurefunc(RaidProfilesMixin, "Init", function(control)
        AttachSaveButton(control)
    end)

    local function DisableAutoActivateSettings()
        if self.classicAutoActivateDisabled then
            return
        end

        if not Settings or not Settings.INTERFACE_CATEGORY_ID then
            return
        end

        local category = Settings.GetCategory(Settings.INTERFACE_CATEGORY_ID)
        if not category then
            return
        end

        local layout = SettingsPanel:GetLayout(category)
        if not layout then
            return
        end

        local targets = {
            PROXY_RAID_AUTO_ACTIVATE = true,
            PROXY_RAID_AUTO_ACTIVATE_2 = true,
            PROXY_RAID_AUTO_ACTIVATE_3 = true,
            PROXY_RAID_AUTO_ACTIVATE_5 = true,
            PROXY_RAID_AUTO_ACTIVATE_10 = true,
            PROXY_RAID_AUTO_ACTIVATE_15 = true,
            PROXY_RAID_AUTO_ACTIVATE_20 = true,
            PROXY_RAID_AUTO_ACTIVATE_40 = true,
        }

        local foundAny = false
        for _, initializer in layout:EnumerateInitializers() do
            if initializer.GetSetting then
                local setting = initializer:GetSetting()
                local variable = setting and setting.GetVariable and setting:GetVariable()
                if variable and targets[variable] then
                    foundAny = true
                    initializer:AddModifyPredicate(function()
                        return false
                    end)
                    initializer:SetSettingIntercept(function()
                        return true
                    end)
                    if initializer.data then
                        initializer.data.tooltip = "Auto-Activation is disabled because mQoL manages Raid Profiles."
                    end
                end
            end
        end

        if foundAny then
            self.classicAutoActivateDisabled = true
        end
    end

    local function AttachToExisting()
        local scrollBox = SettingsPanel.Container 
            and SettingsPanel.Container.SettingsList 
            and SettingsPanel.Container.SettingsList.ScrollBox
        local scrollTarget = scrollBox and scrollBox.ScrollTarget
        if not scrollTarget then
            return
        end

        local children = {scrollTarget:GetChildren()}
        for _, child in ipairs(children) do
            if child.NewButton and child.DeleteButton then
                AttachSaveButton(child)
            end
        end
    end

    SettingsPanel:HookScript("OnShow", function()
        AttachToExisting()
        DisableAutoActivateSettings()
    end)

    if SettingsPanel:IsShown() then
        AttachToExisting()
        DisableAutoActivateSettings()
    end

    self.hookedClassicSettings = true
end

function mQoL_RaidProfiles:HookSettingsPanelBCC()
    if self.hookedBCCSettings then return end

    if not Settings or not Settings.RegisterVerticalLayoutCategory or not CreateSettingsButtonInitializer or not SettingsPanel then
        return
    end

    local function AddSaveButton()
        if not Settings.INTERFACE_CATEGORY_ID then
            return false
        end

        local category = Settings.GetCategory(Settings.INTERFACE_CATEGORY_ID)
        if not category then
            return false
        end

        local layout = SettingsPanel:GetLayout(category)
        if not layout then
            return false
        end

        if layout.GetInitializers then
            local initializers = layout:GetInitializers()
            for _, init in ipairs(initializers) do
                if init.GetName and init:GetName() == "mQoL Save Profile" then
                    return true
                end
            end
        end

        local function OnClick()
            if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
                mQoL_Styles.ShowCustomPopup({
                    text = "Enter name for this Raid Profile to save in mQoL:",
                    hasEditBox = true,
                    maxLetters = 32,
                    acceptText = "Save",
                    onAccept = function(editBox)
                         local text = editBox:GetText()
                         if text and text ~= "" then
                            if text:lower() == "none" then
                                 print(addonName .. ": Error: Profile name cannot be 'None'.")
                                 return
                            end
                            mQoL_RaidProfiles:SaveRaidProfile(text)
                        end
                    end
                })
            else
                 print(addonName .. ": Error - Styles module not found.")
            end
        end

        local initializer = CreateSettingsButtonInitializer(
            "mQoL Save Profile",
            "Save Raid Profile to mQoL",
            OnClick,
            function() Settings.CreateOptionsInitTooltip(nil, "Save Profile", "Save your current Raid Frame settings to mQoL's account-wide storage.", nil) end,
            true
        )

        local inserted = false
        if layout.GetInitializers then
            local initializers = layout:GetInitializers()
            local raidFramesIndex = nil

            for i, init in ipairs(initializers) do
                if init.GetName and init:GetName() == RAID_FRAMES_LABEL then
                    raidFramesIndex = i
                    break
                end
            end

            if raidFramesIndex then
                table.insert(initializers, raidFramesIndex + 1, initializer)
                inserted = true
            end
        end

        if not inserted then
            layout:AddInitializer(initializer)
        end

        return true
    end

    SettingsPanel:HookScript("OnShow", function()
        if AddSaveButton() then
            self.hookedBCCSettings = true
        end
    end)

    if SettingsPanel:IsShown() then
        if AddSaveButton() then
            self.hookedBCCSettings = true
        end
    end
end

function mQoL_RaidProfiles:HookSettingsPanelLegion()
    if self.hookedLegionSettings then return end

    -- CompactUnitFrameProfiles is the frame in Legion (Blizzard_CUFProfiles)
    if not CompactUnitFrameProfiles then return end

    -- Find the Delete button to anchor to
    local deleteBtn = CompactUnitFrameProfilesDeleteButton
    if not deleteBtn then return end

    local btn = CreateFrame("Button", "mQoL_LegionSaveButton", CompactUnitFrameProfiles, "UIPanelButtonTemplate")
    btn:SetSize(110, 22)
    btn:SetText("Save to mQoL")
    btn:SetPoint("LEFT", deleteBtn, "RIGHT", 5, 0)

    btn:SetScript("OnClick", function()
        if mQoL_Styles and mQoL_Styles.ShowCustomPopup then
            mQoL_Styles.ShowCustomPopup({
                text = "Enter name for this Raid Profile to save in mQoL:",
                hasEditBox = true,
                maxLetters = 32,
                acceptText = "Save",
                onAccept = function(editBox)
                        local text = editBox:GetText()
                        if text and text ~= "" then
                        if text:lower() == "none" then
                                print(addonName .. ": Error: Profile name cannot be 'None'.")
                                return
                        end
                        mQoL_RaidProfiles:SaveRaidProfile(text)
                    end
                end
            })
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Save Raid Profile to mQoL", 1, 0.82, 0)
        GameTooltip:AddLine("Save current Raid Frame settings to mQoL's account-wide storage.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.hookedLegionSettings = true
end

function mQoL_RaidProfiles:HookSettingsPanel()
    if clientInfo.isRetail then
        self:HookSettingsPanelRetail()
    elseif clientInfo.isBCC then
        self:HookSettingsPanelBCC()
    elseif clientInfo.isClassic or clientInfo.isEra then
        self:HookSettingsPanelClassic()
    elseif clientInfo.isLegion then
        self:HookSettingsPanelLegion()
    end
end

function mQoL_RaidProfiles:RenameProfile(oldName, newName)
    if not oldName or not newName or oldName == newName then return end

    local s = self.db.settings
    if not s.raidProfiles or not s.raidProfiles[oldName] then return end

    -- 1. Copy data to new profile
    s.raidProfiles[newName] = s.raidProfiles[oldName]

    -- 2. Delete old profile
    s.raidProfiles[oldName] = nil

    -- 3. Update references
    if s.forcedRaidProfile == oldName then
        s.forcedRaidProfile = newName
    end

    if s.simpleSituationalProfiles then
        for k, v in pairs(s.simpleSituationalProfiles) do
            if v == oldName then s.simpleSituationalProfiles[k] = newName end
        end
    end

    if s.advancedClassProfiles then
        for k, v in pairs(s.advancedClassProfiles) do
            if v == oldName then s.advancedClassProfiles[k] = newName end
        end
    end

    if s.advancedSpecProfiles then
        for k, v in pairs(s.advancedSpecProfiles) do
            if v == oldName then s.advancedSpecProfiles[k] = newName end
        end
    end

    if s.advancedSituational then
        for k, situTable in pairs(s.advancedSituational) do
            for sit, v in pairs(situTable) do
                if v == oldName then situTable[sit] = newName end
            end
        end
    end

    print(addonName .. ": Renamed profile '" .. oldName .. "' to '" .. newName .. "'.")

    if self.RefreshSavedProfiles then
        self.RefreshSavedProfiles()
    end
end

function mQoL_RaidProfiles:CreateAdvancedSetupPanel(parent, width)
    local totalWidth = 770
    local gapBetween = 10
    local panelHeight = 270
    local colHeight = 230

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(totalWidth, panelHeight)

    local s = self.db.settings
    local colWidth = (totalWidth - gapBetween) / 2
    local scrollMargin = 18
    local currentDrag = nil
    local dragCursor = nil
    local currentHighlight = nil
    local currentHoverTarget = nil
    local dropTargets = {}
    local specApiDebugShown = false

    local leftCol = CreateFrame("Frame", nil, panel)
    leftCol:SetSize(colWidth, colHeight)
    leftCol:SetPoint("TOPLEFT", 0, -25)
    if mQoL_Templates and mQoL_Templates.CreateFrameBorder then
        mQoL_Templates.CreateFrameBorder(leftCol, 1, {0.2, 0.2, 0.2, 1})
    end

    local leftTitle = leftCol:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftTitle:SetPoint("BOTTOMLEFT", leftCol, "TOPLEFT", 0, 4)
    leftTitle:SetText("Available Profiles")

    local leftScroll = CreateFrame("ScrollFrame", nil, leftCol)
    leftScroll:SetPoint("TOPLEFT", 4, -4)
    leftScroll:SetPoint("BOTTOMRIGHT", -4, 4)
    local leftContent = CreateFrame("Frame", nil, leftScroll)
    leftContent:SetSize(colWidth - 8, colHeight)
    leftScroll:SetScrollChild(leftContent)
    local leftScrollbar
    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        leftScrollbar = mQoL_Styles.CreateCustomScrollbar(leftScroll, leftContent, {thumbWidth=6, buttonSize=10})
    end

    local rightCol = CreateFrame("Frame", nil, panel)
    rightCol:SetSize(colWidth, colHeight)
    rightCol:SetPoint("TOPRIGHT", 0, -25)
    if mQoL_Templates and mQoL_Templates.CreateFrameBorder then
        mQoL_Templates.CreateFrameBorder(rightCol, 1, {0.2, 0.2, 0.2, 1})
    end

    local tabClass = mQoL_Styles.CreateCustomButton(panel, "Class", colWidth/2 - 2, 18)
    tabClass:SetPoint("BOTTOMLEFT", rightCol, "TOPLEFT", 0, 2)
    local tabSpec = mQoL_Styles.CreateCustomButton(panel, "Spec", colWidth/2 - 2, 18)
    tabSpec:SetPoint("BOTTOMRIGHT", rightCol, "TOPRIGHT", 0, 2)

    local function UpdateTabAppearance()
        local mode = s.advancedViewMode or "Class"
        if tabClass.text then 
            if mode == "Class" then
                tabClass.text:SetTextColor(1, 0.82, 0)
            else
                tabClass.text:SetTextColor(0.5, 0.5, 0.5)
            end
        end
        if tabSpec.text then 
            if mode == "Spec" then
                tabSpec.text:SetTextColor(1, 0.82, 0)
            else
                tabSpec.text:SetTextColor(0.5, 0.5, 0.5)
            end
        end
    end

    tabClass:HookScript("OnEnter", function() UpdateTabAppearance() end)
    tabClass:HookScript("OnLeave", function() UpdateTabAppearance() end)
    tabSpec:HookScript("OnEnter", function() UpdateTabAppearance() end)
    tabSpec:HookScript("OnLeave", function() UpdateTabAppearance() end)

    local rightScroll = CreateFrame("ScrollFrame", nil, rightCol)
    rightScroll:SetPoint("TOPLEFT", 4, -4)
    rightScroll:SetPoint("BOTTOMRIGHT", -4, 4)
    local rightContent = CreateFrame("Frame", nil, rightScroll)
    rightContent:SetSize(colWidth - 8, colHeight)
    rightScroll:SetScrollChild(rightContent)
    local rightScrollbar
    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        rightScrollbar = mQoL_Styles.CreateCustomScrollbar(rightScroll, rightContent, {thumbWidth=6, buttonSize=10})
    end

    local RefreshRight
    local toggleStates = {}

    local function CreateDragCursor(text)
        if dragCursor then dragCursor:Hide() end

        dragCursor = CreateFrame("Button", nil, UIParent)
        dragCursor:SetSize(150, 24)
        dragCursor:SetFrameStrata("TOOLTIP")
        dragCursor:SetFrameLevel(100)
        dragCursor:EnableMouse(false)

        local bg = dragCursor:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.5, 0.2, 0.9)

        if mQoL_Templates and mQoL_Templates.CreateFrameBorder then
            mQoL_Templates.CreateFrameBorder(dragCursor, 1, {0.4, 0.8, 0.4, 1})
        end

        local label = dragCursor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER")
        label:SetText(text)
        label:SetTextColor(1, 1, 1)

        dragCursor:ClearAllPoints()
        dragCursor:SetScript("OnUpdate", function(self)
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/scale, y/scale)
        end)

        dragCursor:Show()
        return dragCursor
    end

    local function HideDragCursor()
        if dragCursor then
            dragCursor:Hide()
            dragCursor = nil
        end
        currentDrag = nil
        currentHoverTarget = nil 
    end

    -- Helper function to check if any situational profiles exist for a given ID
    local function HasSituationalProfiles(targetID)
        if s.advancedSituational and s.advancedSituational[targetID] then
            for _, v in pairs(s.advancedSituational[targetID]) do
                if v and v ~= "" then return true end
            end
        end
        return false
    end

    local function ApplyDragToTarget(targetID, situationKey)
        if currentDrag and targetID then
            if situationKey then
                 -- Block setting situational if main profile is already set
                 local mode = s.advancedViewMode or "Class"
                 local mainProfile
                 if mode == "Class" then mainProfile = s.advancedClassProfiles[targetID]
                 else mainProfile = s.advancedSpecProfiles[targetID] end

                 if mainProfile and mainProfile ~= "" then
                     HideDragCursor()
                     return false
                 end

                 if not s.advancedSituational[targetID] then s.advancedSituational[targetID] = {} end
                 s.advancedSituational[targetID][situationKey] = currentDrag
            else
                 -- Block setting main slot if situational profiles are already set
                 if HasSituationalProfiles(targetID) then
                     HideDragCursor()
                     return false
                 end
                 local mode = s.advancedViewMode or "Class"
                 if mode == "Class" then 
                     s.advancedClassProfiles[targetID] = currentDrag 
                 else 
                     s.advancedSpecProfiles[targetID] = currentDrag 
                 end
            end
            HideDragCursor()
            if RefreshRight then RefreshRight() end

            local shouldUpdate = false
            local _, pClass = UnitClass("player")
            if s.advancedViewMode == "Class" then
                 if targetID == pClass then shouldUpdate = true end
            else
                 local getSpecIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
                 local getSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
                 if getSpecIndex and getSpecInfo then
                     local pSpec = getSpecIndex()
                     local pSpecID = pSpec and getSpecInfo(pSpec)
                     if targetID == pSpecID then shouldUpdate = true end
                 end
            end

            if shouldUpdate then
                mQoL_RaidProfiles:UpdateCurrentProfile()
            end
            return true
        end
        return false
    end

    local function CheckDropTargets()
        if not currentDrag then return false end

        for _, target in ipairs(dropTargets) do
            if target.frame and target.frame:IsVisible() and target.frame:IsMouseOver() then
                return ApplyDragToTarget(target.id, target.situationKey)
            end
        end
        return false
    end

    local function RegisterDropTarget(frame, id, situationKey)
        table.insert(dropTargets, {frame = frame, id = id, situationKey = situationKey})
    end

    local function ClearDropTargets()
        wipe(dropTargets)
    end

    local function RefreshLeft()
        local profiles = {}
        if s.raidProfiles then for k in pairs(s.raidProfiles) do table.insert(profiles, k) end end
        table.sort(profiles)
        for _, child in ipairs({leftContent:GetChildren()}) do child:Hide() child:SetParent(nil) end

        local y, rowH = 0, 22
        local textWidth = leftContent:GetWidth() - scrollMargin - 10
        for _, name in ipairs(profiles) do
            local btn = CreateFrame("Button", nil, leftContent)
            btn:SetSize(leftContent:GetWidth() - scrollMargin, rowH)
            btn:SetPoint("TOPLEFT", 0, -y)

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1,1,1,0.03)

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", 4, 0)
            text:SetWidth(textWidth)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            text:SetText(name)

            btn:SetScript("OnEnter", function(self)
                if not currentDrag then
                    bg:SetColorTexture(1,1,1,0.08)
                end
                if text:IsTruncated() then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(name)
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function() 
                if not currentDrag then
                    bg:SetColorTexture(1,1,1,0.03) 
                end
                GameTooltip:Hide() 
            end)

            btn:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then
                    currentDrag = name
                    currentHoverTarget = nil
                    bg:SetColorTexture(0.2, 0.5, 0.2, 0.5)
                    CreateDragCursor(name)
                end
            end)

            btn:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" and currentDrag then
                    bg:SetColorTexture(1,1,1,0.03)
                    if not CheckDropTargets() then
                        HideDragCursor()
                    end
                end
            end)

            y = y + rowH + 1
        end
        leftContent:SetHeight(math.max(y, colHeight - 8))
        if leftScrollbar and leftScrollbar.UpdateScrollbar then leftScrollbar:UpdateScrollbar() end
    end

    RefreshRight = function()
        local mode = s.advancedViewMode or "Class"
        UpdateTabAppearance()

        ClearDropTargets()

        for _, child in ipairs({rightContent:GetChildren()}) do child:Hide() child:SetParent(nil) end

        local items = {}
        local function ShouldIncludeClass(classID)
            if not clientInfo.isEra then return true end
            if not classID then return true end
            if not UnitFactionGroup then return true end
            local faction = UnitFactionGroup("player")
            if faction == "Horde" and classID == 2 then return false end
            if faction == "Alliance" and classID == 7 then return false end
            return true
        end

        local function ForEachAvailableClass(cb)
            for classID = 1, 13 do
                local className, classFile, blizzClassID = GetClassInfo(classID)
                if className and classFile and blizzClassID then
                    cb(className, classFile, blizzClassID)
                end
            end
        end

        if mode == "Class" then
            local seenClassFiles = {}
            ForEachAvailableClass(function(className, classFile, classID)
                if ShouldIncludeClass(classID) and not seenClassFiles[classFile] then
                    seenClassFiles[classFile] = true
                    local color = GetClassColor(classFile, { r = 0.5, g = 0.5, b = 0.5 })
                    table.insert(items, {id=classFile, name=className, color=color, assigned=s.advancedClassProfiles[classFile]})
                end
            end)
        else
            local function GetClassColorOrFallback(classFile)
                return GetClassColor(classFile, { r = 0.5, g = 0.5, b = 0.5 })
            end

            local function TryBuildSpecItemsFromBlizzard()
                local getNumSpecs = GetNumSpecializationsForClassID or (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID)
                local getSpecInfo = GetSpecializationInfoForClassID or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID)
                if not getNumSpecs or not getSpecInfo then
                    return false
                end

                local sex = UnitSex and UnitSex("player")

                local foundAny = false
                ForEachAvailableClass(function(_, _, classID)
                    if foundAny then return end
                    if not ShouldIncludeClass(classID) then return end
                    local specCount = getNumSpecs(classID)
                    if specCount and specCount > 0 then
                        foundAny = true
                    end
                end)
                if not foundAny then
                    return false
                end

                local seenSpecIDs = {}
                ForEachAvailableClass(function(className, classFile, classID)
                    if not ShouldIncludeClass(classID) then return end
                    local specCount = getNumSpecs(classID)
                    if specCount and specCount > 0 then
                        local color = GetClassColorOrFallback(classFile)
                        for j = 1, specCount do
                            local id, specName = getSpecInfo(classID, j, sex)
                            if id and specName and not seenSpecIDs[id] then
                                seenSpecIDs[id] = true
                                table.insert(items, {id=id, name=className..": "..specName, color=color, assigned=s.advancedSpecProfiles[id]})
                            end
                        end
                        
                        local noSpecID = classFile .. "_NoSpec"
                        table.insert(items, {id=noSpecID, name=className .. ": No Specialization", color=color, assigned=s.advancedSpecProfiles[noSpecID]})
                    end
                end)

                return #items > 0
            end

            local apiSuccessful = false
            apiSuccessful = TryBuildSpecItemsFromBlizzard()
            if not apiSuccessful then
                if not specApiDebugShown then
                    specApiDebugShown = true
                    print(addonName .. ": Spec list API unavailable on this client.")
                end
            end
        end

        local y, rowH = 0, 22
        local labelWidth = rightContent:GetWidth() - scrollMargin - 60

        for _, item in ipairs(items) do
             local hasSituational = false
             if s.advancedSituational and s.advancedSituational[item.id] then
                 for _, v in pairs(s.advancedSituational[item.id]) do
                     if v and v ~= "" then hasSituational = true break end
                 end
             end

            local row = CreateFrame("Button", nil, rightContent)
            row:SetSize(rightContent:GetWidth() - scrollMargin, rowH)
            row:SetPoint("TOPLEFT", 0, -y)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            local c = item.color or {r=0.5,g=0.5,b=0.5}
            local origR, origG, origB, origA = c.r*0.15, c.g*0.15, c.b*0.15, 0.5
            bg:SetColorTexture(origR, origG, origB, origA)
            bg.origR, bg.origG, bg.origB, bg.origA = origR, origG, origB, origA

            -- Expander
            local expander = CreateFrame("Button", nil, row)
            expander:SetSize(16, 16)
            expander:SetPoint("LEFT", 2, 0)
            local expText = expander:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            expText:SetPoint("CENTER")
            expText:SetText(toggleStates[item.id] and "-" or "+")
            expander:SetScript("OnClick", function()
                toggleStates[item.id] = not toggleStates[item.id]
                RefreshRight()
            end)

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", 20, 0)
            label:SetWidth(labelWidth)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(item.name)
            if item.color then label:SetTextColor(item.color.r, item.color.g, item.color.b) end

            local deleteBtn = CreateFrame("Button", nil, row)
            deleteBtn:SetSize(14, 14)
            deleteBtn:SetPoint("RIGHT", -5, 0)
            deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
            deleteBtn:SetScript("OnClick", function()
                if hasSituational then
                    -- Clear situational if active logic overrides
                    if s.advancedSituational then s.advancedSituational[item.id] = nil end
                else
                    -- Clear base
                    if mode == "Class" then s.advancedClassProfiles[item.id] = nil else s.advancedSpecProfiles[item.id] = nil end
                end
                RefreshRight()

                -- Conditional Update
                local shouldUpdate = false
                local _, pClass = UnitClass("player")
                if mode == "Class" then
                     if item.id == pClass then shouldUpdate = true end
                else
                     local getSpecIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
                     local getSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
                     if getSpecIndex and getSpecInfo then
                         local pSpec = getSpecIndex()
                         local pSpecID = pSpec and getSpecInfo(pSpec)
                         if item.id == pSpecID then shouldUpdate = true end
                     end
                end
                if shouldUpdate then mQoL_RaidProfiles:UpdateCurrentProfile() end
            end)

            local displayAssigned = item.assigned
            if hasSituational then displayAssigned = "Situational" end

            -- Hide delete button if nothing assigned
            if not displayAssigned and not hasSituational then
                deleteBtn:Hide()
            end

            local assigned = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            assigned:SetPoint("RIGHT", deleteBtn, "LEFT", -5, 0)
            assigned:SetText(displayAssigned or "None")
            assigned:SetTextColor(displayAssigned and 0 or 0.5, displayAssigned and 1 or 0.5, displayAssigned and 0 or 0.5)

            -- Drag handling for main row
            row:SetScript("OnEnter", function(self)
                if currentDrag then
                    -- Show red if situational profiles are set (can't drop to main slot)
                    if hasSituational then
                        bg:SetColorTexture(0.7, 0.2, 0.2, 0.8)
                    else
                        bg:SetColorTexture(0.2, 0.7, 0.2, 0.8)
                    end
                else
                    bg:SetColorTexture(c.r*0.25, c.g*0.25, c.b*0.25, 0.7)
                end
            end)

            row:SetScript("OnLeave", function(self)
                 bg:SetColorTexture(origR, origG, origB, origA)
            end)

            row:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" then
                    -- Reset base (only if no situational profiles)
                    if not hasSituational then
                        if mode == "Class" then s.advancedClassProfiles[item.id] = nil else s.advancedSpecProfiles[item.id] = nil end
                        RefreshRight()
                    end
                elseif button == "LeftButton" and currentDrag then
                    ApplyDragToTarget(item.id, nil)
                end
            end)

            -- Register this row as a drop target (only if no situational profiles)
            if not hasSituational then
                RegisterDropTarget(row, item.id, nil)
            end

            y = y + rowH + 1

            -- Sub-rows if expanded
            if toggleStates[item.id] then
                 local subSituations = {"Party", "Raid", "Arena", "Battleground"}
                 for _, sit in ipairs(subSituations) do
                     local subRow = CreateFrame("Button", nil, rightContent)
                     subRow:SetSize(rightContent:GetWidth() - scrollMargin - 20, 18)
                     subRow:SetPoint("TOPLEFT", 20, -y)

                     local subBg = subRow:CreateTexture(nil, "BACKGROUND")
                     subBg:SetAllPoints()
                     subBg:SetColorTexture(0.1, 0.1, 0.1, 0.3)

                     local subLabel = subRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                     subLabel:SetPoint("LEFT", 4, 0)
                     subLabel:SetText(sit)
                     subLabel:SetTextColor(0.7, 0.7, 0.7)

                     local val = s.advancedSituational[item.id] and s.advancedSituational[item.id][sit]

                     local subDeleteBtn = CreateFrame("Button", nil, subRow)
                     subDeleteBtn:SetSize(14, 14)
                     subDeleteBtn:SetPoint("RIGHT", -5, 0)
                     subDeleteBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                     subDeleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
                     subDeleteBtn:SetScript("OnClick", function()
                         if s.advancedSituational[item.id] then
                             s.advancedSituational[item.id][sit] = nil
                             RefreshRight()

                             -- Conditional Update
                             local shouldUpdate = false
                             local _, pClass = UnitClass("player")
                             local mode = s.advancedViewMode or "Class"
                             if mode == "Class" then
                                  if item.id == pClass then shouldUpdate = true end
                             else
                                  local getSpecIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
                                  local getSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
                                  if getSpecIndex and getSpecInfo then
                                      local pSpec = getSpecIndex()
                                      local pSpecID = pSpec and getSpecInfo(pSpec)
                                      if item.id == pSpecID then shouldUpdate = true end
                                  end
                             end
                             if shouldUpdate then mQoL_RaidProfiles:UpdateCurrentProfile() end
                         end
                     end)
                     if not val then subDeleteBtn:Hide() end

                     local subVal = subRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                     subVal:SetPoint("RIGHT", subDeleteBtn, "LEFT", -5, 0)
                     subVal:SetText(val or "None")
                     subVal:SetTextColor(val and 0 or 0.5, val and 1 or 0.5, val and 0 or 0.5)

                     local mainAssigned = item.assigned and item.assigned ~= ""

                     subRow:SetScript("OnEnter", function()
                         if currentDrag then
                             if mainAssigned then
                                 subBg:SetColorTexture(0.7, 0.2, 0.2, 0.6)
                             else
                                 subBg:SetColorTexture(0.2, 0.7, 0.2, 0.6)
                             end
                         else
                             subBg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
                         end
                     end)
                     subRow:SetScript("OnLeave", function() subBg:SetColorTexture(0.1, 0.1, 0.1, 0.3) end)

                     subRow:SetScript("OnMouseUp", function(self, button)
                        if button == "RightButton" then
                            if s.advancedSituational[item.id] then
                                s.advancedSituational[item.id][sit] = nil
                                RefreshRight()
                            end
                        elseif button == "LeftButton" and currentDrag then
                            if not mainAssigned then
                                ApplyDragToTarget(item.id, sit)
                            end
                        end
                     end)

                     -- Register this subRow as a drop target (only if no main profile assigned)
                     if not mainAssigned then
                         RegisterDropTarget(subRow, item.id, sit)
                     end

                     y = y + 19
                 end
                 y = y + 4 -- Gap after group
            end
        end
        rightContent:SetHeight(math.max(y, colHeight - 8))
        if rightScrollbar and rightScrollbar.UpdateScrollbar then rightScrollbar:UpdateScrollbar() end
    end

    tabClass:SetScript("OnClick", function() s.advancedViewMode = "Class" RefreshRight() end)
    tabSpec:SetScript("OnClick", function() s.advancedViewMode = "Spec" RefreshRight() end)
    panel:SetScript("OnShow", function() RefreshLeft() RefreshRight() end)
    panel.Refresh = function() RefreshLeft() RefreshRight() end
    RefreshLeft()
    RefreshRight()
    return panel
end

function mQoL_RaidProfiles:CreateProfileManagerPopup()
    if self.ProfileManagerPopup then return self.ProfileManagerPopup end

    local popup = CreateFrame("Frame", "mQoL_RaidProfileManager", UIParent)
    popup:SetSize(420, 300)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(50)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:SetClampedToScreen(true)
    popup:EnableKeyboard(true)
    popup:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)

    local function ApplyHubScale()
        local db = _G["mQoL_Database"]
        local hubSettings = db and db.GetSettings and db:GetSettings("Hub") or nil
        local frameScale = hubSettings and hubSettings.display and hubSettings.display.scale or 1.0
        popup:SetScale(frameScale)
    end
    ApplyHubScale()
    popup:HookScript("OnShow", ApplyHubScale)

    popup.bg = popup:CreateTexture(nil, "BACKGROUND")
    popup.bg:SetAllPoints()
    popup.bg:SetColorTexture(0.05, 0.05, 0.05, 1)

    if mQoL_Templates and mQoL_Templates.CreateFrameBorder then
        mQoL_Templates.CreateFrameBorder(popup, 1, {0.25, 0.25, 0.25, 1})
    else
         popup:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    end

    local titleBar = CreateFrame("Frame", nil, popup)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(32)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.1, 0.1, 0.1, 1)

    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() popup:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() popup:StopMovingOrSizing() end)

    popup.title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    popup.title:SetPoint("CENTER", titleBar, "CENTER", 0, -1)
    popup.title:SetText("Manage Raid Profiles")
    popup.title:SetTextColor(1, 0.82, 0)
    popup.title:SetShadowColor(0, 0, 0, 0.8)
    popup.title:SetShadowOffset(1, -1)

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", -10, 0)
    closeBtn.tex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeBtn.tex:SetAllPoints()
    closeBtn.tex:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Cross")
    closeBtn.tex:SetVertexColor(0.6, 0.6, 0.6)
    closeBtn:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1, 0.2, 0.2) end)
    closeBtn:SetScript("OnLeave", function(self) self.tex:SetVertexColor(0.6, 0.6, 0.6) end)
    closeBtn:SetScript("OnClick", function() popup:Hide() end)

    local listContainer = CreateFrame("Frame", nil, popup)
    listContainer:SetPoint("TOPLEFT", 10, -40)
    listContainer:SetPoint("BOTTOMRIGHT", -10, 10)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)

    local scrollbar
    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        scrollbar = mQoL_Styles.CreateCustomScrollbar(scrollFrame, scrollChild, { buttonSize = 16, thumbWidth = 8 })
    else
        scrollbar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
        scrollbar:SetPoint("TOPRIGHT", 0, -16)
        scrollbar:SetPoint("BOTTOMRIGHT", 0, 16)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        local step = 20
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, cur - step))
        else
            self:SetVerticalScroll(math.min(max, cur + step))
        end
        if scrollbar and scrollbar.UpdateScrollbar then
            scrollbar.UpdateScrollbar()
        else
            scrollbar:SetValue(self:GetVerticalScroll())
        end
    end)

    popup.RebuildList = function()
        for _, child in ipairs({scrollChild:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end

        local s = mQoL_RaidProfiles.db.settings
        local savedProfiles = {}
        if s.raidProfiles then
            for name, _ in pairs(s.raidProfiles) do
                table.insert(savedProfiles, name)
            end
        end
        table.sort(savedProfiles)

        local rowWidth = listContainer:GetWidth() - 22 
        local rowHeight = 28

        for i, name in ipairs(savedProfiles) do
            local row = CreateFrame("Frame", nil, scrollChild)
            row:SetSize(rowWidth, rowHeight)
            row:SetPoint("TOPLEFT", 0, -((i-1)*rowHeight))

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            if i % 2 == 0 then
                bg:SetColorTexture(1, 1, 1, 0.03)
            else
                bg:SetColorTexture(1, 1, 1, 0)
            end

            row:SetScript("OnEnter", function() bg:SetColorTexture(1, 1, 1, 0.08) end)
            row:SetScript("OnLeave", function() 
                if i % 2 == 0 then
                    bg:SetColorTexture(1, 1, 1, 0.03)
                else
                    bg:SetColorTexture(0, 0, 0, 0)
                end
            end)

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", 8, 0)
            text:SetText(name)
            text:SetJustifyH("LEFT")
            text:SetPoint("RIGHT", row, "RIGHT", -30, 0)
            text:SetWordWrap(false)

            local delBtn = CreateFrame("Button", nil, row)
            delBtn:SetSize(14, 14)
            delBtn:SetPoint("RIGHT", -6, 0)

            local renameBtn = CreateFrame("Button", nil, row)
            renameBtn:SetSize(14, 14)
            renameBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)

            delBtn.tex = delBtn:CreateTexture(nil, "ARTWORK")
            delBtn.tex:SetAllPoints()
            delBtn.tex:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\Cross")
            delBtn.tex:SetVertexColor(0.5, 0.5, 0.5)

            delBtn:SetScript("OnEnter", function(self) self.tex:SetVertexColor(0.9, 0.2, 0.2) end)
            delBtn:SetScript("OnLeave", function(self) self.tex:SetVertexColor(0.5, 0.5, 0.5) end)

            renameBtn.tex = renameBtn:CreateTexture(nil, "ARTWORK")
            renameBtn.tex:SetAllPoints()
            renameBtn.tex:SetTexture("Interface\\AddOns\\mQoL\\Media\\Textures\\pencil")
            renameBtn.tex:SetVertexColor(0.6, 0.6, 0.6)

            renameBtn:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1, 0.82, 0) end)
            renameBtn:SetScript("OnLeave", function(self) self.tex:SetVertexColor(0.6, 0.6, 0.6) end)

            renameBtn:SetScript("OnClick", function()
                 if mQoL_Styles.ShowCustomPopup then
                     mQoL_Styles.ShowCustomPopup({
                        text = "Rename Profile '" .. name .. "' to:",
                        hasEditBox = true,
                        maxLetters = 32,
                        acceptText = "Rename",
                        onAccept = function(editBox)
                             local newName = editBox:GetText()
                             if newName and newName ~= "" and newName ~= name then
                                if newName:lower() == "none" then
                                     print(addonName .. ": Error: Profile name cannot be 'None'.")
                                     return
                                end
                                mQoL_RaidProfiles:RenameProfile(name, newName)
                                popup.RebuildList()
                            end
                        end
                    })
                 end
            end)

            delBtn:SetScript("OnClick", function()
                 if mQoL_Styles.ShowCustomPopup then
                     mQoL_Styles.ShowCustomPopup({
                        text = "Delete Raid Profile '" .. name .. "'?\nThis cannot be undone.",
                        acceptText = "Delete",
                        cancelText = "Cancel",
                        onAccept = function()
                             s.raidProfiles[name] = nil
                             print(addonName .. ": Deleted profile '" .. name .. "'.")

                             -- Cleanup orphaned references
                             -- 1. Simple Situational
                             if s.simpleSituationalProfiles then
                                 for k, v in pairs(s.simpleSituationalProfiles) do
                                     if v == name then s.simpleSituationalProfiles[k] = "" end
                                 end
                             end
                             -- 2. Forced Profile
                             if s.forcedRaidProfile == name then s.forcedRaidProfile = "" end

                             -- 3. Advanced Assignments
                             if s.advancedClassProfiles then
                                 for k, v in pairs(s.advancedClassProfiles) do
                                     if v == name then s.advancedClassProfiles[k] = nil end
                                 end
                             end
                             if s.advancedSpecProfiles then
                                 for k, v in pairs(s.advancedSpecProfiles) do
                                     if v == name then s.advancedSpecProfiles[k] = nil end
                                 end
                             end
                             if s.advancedSituational then
                                 for k, situTable in pairs(s.advancedSituational) do
                                     for sit, v in pairs(situTable) do
                                         if v == name then situTable[sit] = nil end
                                     end
                                 end
                             end

                             popup.RebuildList()
                             if mQoL_RaidProfiles.RefreshSavedProfiles then
                                  mQoL_RaidProfiles.RefreshSavedProfiles()
                             end
                        end
                     })
                 end
            end)
        end

        local totalHeight = math.max(1, #savedProfiles * rowHeight)
        scrollChild:SetSize(rowWidth, totalHeight)
        if scrollbar and scrollbar.UpdateScrollbar then
             scrollbar:UpdateScrollbar()
        end
    end

    self.ProfileManagerPopup = popup
    return popup
end

function mQoL_RaidProfiles:CreateRaidProfilesPanel(parent)
    local s = self.db.settings
    local scrollFrame, panel, contentContainer, infoButton = mQoL_Templates.CreateStandardOptionsPanel(parent, "Raid Profiles Settings", {
        text = "How Raid Profiles works?",
        textColor = {1, 0.82, 0},
        explanation = "Advanced management for Raid Profiles.\n\n• Choose between using Simple or Advanced mode in Forced Raid Profile Mode.\n• Auto-Load: Force specific profiles for Class, Spec, and for Group Size (Party/Raid/Battleground/Arena).\n• Account-Wide: Save profiles from one character and use them on another.\n• Use the 'Save to mQoL' button in Blizzard's Raid Profiles settings to save a profile to mQoL.\n• Be aware that mQoL needs one free spot in Blizzard's Raid Profiles settings to make a custom profile that the addon will use.\n• The addon |cffff0000WILL NOT|r override any of your profiles in Blizzard settings but will create one custom profile that the addon will use.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "MainSeparator")

    local AddGap = mQoL_Templates.AddGap

    -- Shortcut
    local function AddOptionRow(label, type, opts, extra, applyFunc)
        return mQoL_Hub:AddOptionRow(contentContainer, label, type, opts, extra, applyFunc)
    end

    if self:ShouldHandleUseCompactPartyFrames() then
        AddOptionRow("Use Raid Frames in 5-Man Party", "checkbox", {
            value = GetCVarBool("useCompactPartyFrames"),
            onValueChanged = function(self, val)
                if InCombatLockdown() then
                    print(addonName .. ": Cannot change this setting while in combat.")
                    return
                end

                mQoL_RaidProfiles:ApplyUseCompactPartyFrames(val)
            end
        })
        AddGap(contentContainer, "Standard")
    end

    AddGap(contentContainer, "BottomSeparator")

    local function OpenProfileManager()
        if not self.ProfileManagerPopup then
            self:CreateProfileManagerPopup()
        end
        self.ProfileManagerPopup:Show()
        if self.ProfileManagerPopup.RebuildList then
            self.ProfileManagerPopup.RebuildList()
        end
    end

    local row, _ = mQoL_Hub:AddOptionRow(contentContainer, "Saved Raid Profiles", nil, {}, {})

    local managerBtn
    if mQoL_Styles and mQoL_Styles.CreateCustomButton then
        managerBtn = mQoL_Styles.CreateCustomButton(row, "Manage Profiles", 150, 24)
    else
        managerBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        managerBtn:SetSize(150, 24)
        managerBtn:SetText("Manage Profiles")
    end

    local label = contentContainer.optionsLabels and contentContainer.optionsLabels["Saved Raid Profiles"]
    if label then
        managerBtn:SetPoint("LEFT", label, "RIGHT", 20, 0)
    else
        managerBtn:SetPoint("LEFT", row, "LEFT", 230, 0) 
    end
    managerBtn:SetScript("OnClick", OpenProfileManager)

    AddGap(contentContainer, "Standard")

    local modeItems = {
        { text = "Disabled", value = "Disabled" },
        { text = "Simple", value = "Simple" },
        { text = "Advanced", value = "Advanced" }
    }

    local currentMode = s.raidProfileMode or "Simple"

    local RefreshVisibility = nil

    AddOptionRow("Forced Raid Profile Mode", "dropdown", {
        list = modeItems,
        value = currentMode,
        width = 160,
        onValueChanged = function(value)
            s.raidProfileMode = value
            if RefreshVisibility then RefreshVisibility() end
            self:UpdateCurrentProfile()
        end
    }, nil, nil)
    AddGap(contentContainer, "Standard")

    local SITUATIONAL_MODE_KEY = "Use Situational Instead"

    local function GetSavedDropdownItems()
        local savedProfiles = {}
        if s.raidProfiles then
            for name, _ in pairs(s.raidProfiles) do
                table.insert(savedProfiles, name)
            end
        end
        table.sort(savedProfiles)

        local savedDropdownItems = {}

        if #savedProfiles == 0 then
             table.insert(savedDropdownItems, {
                text = "No profiles found",
                value = "",
             })
        else
            table.insert(savedDropdownItems, {
                text = SITUATIONAL_MODE_KEY,
                value = SITUATIONAL_MODE_KEY,
                underline = true
            })

            for _, name in ipairs(savedProfiles) do
                table.insert(savedDropdownItems, {
                    text = name,
                    value = name
                })
            end
        end
        return savedDropdownItems
    end

    local savedDropdownItems = GetSavedDropdownItems()
    local selectedSavedProfile = s.forcedRaidProfile or ""

    if s.simpleSituational then
        s.simpleSituational = nil
        s.forcedRaidProfile = SITUATIONAL_MODE_KEY
        selectedSavedProfile = SITUATIONAL_MODE_KEY
    end

    local advancedAnchorY = contentContainer.currentY

    local simpleSettingsFrame = CreateFrame("Frame", nil, contentContainer)
    simpleSettingsFrame:SetSize(850, 150)
    simpleSettingsFrame.currentY = 0

    local forceProfileRow, dropdownControl = mQoL_Hub:AddOptionRow(simpleSettingsFrame, "Force Raid Profile", "dropdown", {
        list = savedDropdownItems,
        value = s.forcedRaidProfile or "",
        onValueChanged = function(value)
            s.forcedRaidProfile = value
            if RefreshVisibility then RefreshVisibility() end
            
            if value ~= SITUATIONAL_MODE_KEY then
                s.simpleSituational = nil
                if mQoL_RaidProfiles.LoadRaidProfile then
                    mQoL_RaidProfiles:LoadRaidProfile(value)
                end
            else
                mQoL_RaidProfiles:UpdateCurrentProfile(true)
            end
        end
    }, nil, nil)

    if contentContainer.optionsLabels and simpleSettingsFrame.optionsLabels and simpleSettingsFrame.optionsLabels["Force Raid Profile"] then
        contentContainer.optionsLabels["Force Raid Profile"] = simpleSettingsFrame.optionsLabels["Force Raid Profile"]
    end

    local simpleSitContainer = CreateFrame("Frame", nil, simpleSettingsFrame)
    simpleSitContainer:SetSize(850, 150)
    simpleSitContainer:SetPoint("TOPLEFT", 0, simpleSettingsFrame.currentY - 20)
    simpleSitContainer.currentY = 0

    local sitDropdowns = {}
    local function AddSituationalDropdown(label, key)
        local function GetSitItems() 
            local items = {}
            items[1] = {text="None", value=""}

            local profiles = {}
            if s.raidProfiles then for k in pairs(s.raidProfiles) do table.insert(profiles, k) end end
            table.sort(profiles)

            for _, name in ipairs(profiles) do
                table.insert(items, {text=name, value=name})
            end
            return items 
        end

        local row, dd = mQoL_Hub:AddOptionRow(simpleSitContainer, label, "dropdown", {
            list = GetSitItems(),
            value = s.simpleSituationalProfiles[key] or "",
            width = 160,
            onValueChanged = function(val)
                s.simpleSituationalProfiles[key] = val
                mQoL_RaidProfiles:UpdateCurrentProfile(true)
            end
        })
        AddGap(simpleSitContainer, "Standard")
        sitDropdowns[key] = dd
    end
    
    AddSituationalDropdown("Party (2-5 Players)", "Party")
    AddSituationalDropdown("Raid (6-40 Players)", "Raid")
    AddSituationalDropdown("Arena", "Arena")
    AddSituationalDropdown("Battleground", "Battleground")
    
    local function RefreshSituationalDropdowns()
        local function GetSitItems() 
            local items = {}
            items[1] = {text="None", value=""}
            
            local profiles = {}
            if s.raidProfiles then for k in pairs(s.raidProfiles) do table.insert(profiles, k) end end
            table.sort(profiles)
             
            for _, name in ipairs(profiles) do
                table.insert(items, {text=name, value=name})
            end
            return items 
        end
        local sitItems = GetSitItems()
        
        for key, dd in pairs(sitDropdowns) do
            if dd and dd.SetList then
                dd:SetList(sitItems)
                if dd.SetValue then dd:SetValue(s.simpleSituationalProfiles[key] or "") end
                if dd.text then 
                    local val = s.simpleSituationalProfiles[key]
                    dd.text:SetText((val and val ~= "") and val or "None")
                end
            end
        end
    end

    local advancedPanel = self:CreateAdvancedSetupPanel(contentContainer, 770)
    advancedPanel:SetPoint("TOPLEFT", 20, advancedAnchorY)
    advancedPanel:Hide()

    RefreshVisibility = function()
        local mode = s.raidProfileMode
        local advancedPanelHeight = 270  -- From CreateAdvancedSetupPanel

        if mode == "Simple" then
            simpleSettingsFrame:ClearAllPoints()
            simpleSettingsFrame:SetPoint("TOPLEFT", 0, advancedAnchorY)
            simpleSettingsFrame:Show()
            advancedPanel:Hide()

            if s.forcedRaidProfile == SITUATIONAL_MODE_KEY then
                simpleSitContainer:Show()
                local sitHeight = math.abs(simpleSitContainer.currentY)
                contentContainer.currentY = advancedAnchorY - 30 - sitHeight
                if panel.UpdateScrollChildHeight then panel.UpdateScrollChildHeight() end
            else
                simpleSitContainer:Hide()
                contentContainer.currentY = advancedAnchorY - 30
                if panel.UpdateScrollChildHeight then panel.UpdateScrollChildHeight() end
            end

        elseif mode == "Advanced" then
            simpleSettingsFrame:Hide()
            advancedPanel:ClearAllPoints()
            advancedPanel:SetPoint("TOPLEFT", 20, advancedAnchorY)
            advancedPanel:Show()
            if advancedPanel.Refresh then advancedPanel.Refresh() end
            contentContainer.currentY = advancedAnchorY - advancedPanelHeight - 20
            if panel.UpdateScrollChildHeight then panel.UpdateScrollChildHeight() end
        else
            simpleSettingsFrame:Hide()
            advancedPanel:Hide()
            contentContainer.currentY = advancedAnchorY
            if panel.UpdateScrollChildHeight then panel.UpdateScrollChildHeight() end
        end
    end

    local function RefreshDropdown()
        -- Sync from DB first
        if s.forcedRaidProfile and s.forcedRaidProfile ~= "" then
            selectedSavedProfile = s.forcedRaidProfile
        else
            selectedSavedProfile = ""
        end

        local newItems = GetSavedDropdownItems()

        if dropdownControl and dropdownControl.SetList then
            dropdownControl:SetList(newItems)

            local exists = false
            for _, item in ipairs(newItems) do
                if item.value == selectedSavedProfile then exists = true break end
            end
            if not exists then 
                s.forcedRaidProfile = ""
                selectedSavedProfile = ""
                if dropdownControl.SetValue then dropdownControl:SetValue("") end
                if dropdownControl.text then 
                    if #newItems == 1 and newItems[1].text == "No profiles found" then
                        dropdownControl.text:SetText("No profiles found")
                    else
                        dropdownControl.text:SetText("None")
                    end
                end
            end

            -- Ensure text is updated
            if exists and dropdownControl.SetValue then
                dropdownControl:SetValue(selectedSavedProfile)
                -- Also force text update if SetValue didn't do it for situational key
                if selectedSavedProfile == SITUATIONAL_MODE_KEY and dropdownControl.text then
                    dropdownControl.text:SetText(SITUATIONAL_MODE_KEY)
                end
            end
        end

        if RefreshSituationalDropdowns then RefreshSituationalDropdowns() end

        if advancedPanel and advancedPanel.Refresh then advancedPanel.Refresh() end

        if self.ProfileManagerPopup and self.ProfileManagerPopup:IsShown() and self.ProfileManagerPopup.RebuildList then
            self.ProfileManagerPopup.RebuildList()
        end
    end

    self.RefreshSavedProfiles = RefreshDropdown

    local extraPadding = 10
    contentContainer.currentY = contentContainer.currentY - extraPadding

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
        if scrollFrame and scrollFrame.SetVerticalScroll then
            scrollFrame:SetVerticalScroll(0)
        end
    end
    panel.UpdateScrollChildHeight()
    RefreshVisibility()

    if infoButton then
        infoButton:HookScript("OnClick", function()
            if extraPadding > 0 then
                contentContainer.currentY = contentContainer.currentY + extraPadding
                extraPadding = 0
                panel.UpdateScrollChildHeight()
            end
        end)
    end

    return scrollFrame
end

-- Event Handler
local eventFrame = CreateFrame("Frame")
local lastSituation = nil  -- Track situation (Party/Raid/Arena/Battleground) for change detection
local lastSpecID = nil     -- Track spec ID to detect real spec changes (not level ups)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")  -- Detects Party/Raid/Arena/BG changes

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    -- Skip if module disabled
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("RaidProfiles") then return end

    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            mQoL_RaidProfiles:InitializeDB()
        elseif arg1 == "Blizzard_Settings" or arg1 == "Blizzard_SettingsDefinitions_Frame" or arg1 == "Blizzard_CUFProfiles" then
            mQoL_RaidProfiles:HookSettingsPanel()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        -- Register with Hub
        if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
            mQoL_Hub:RegisterModuleOptions("mQoL_RaidProfiles", "Raid Profiles", function(parent)
                return mQoL_RaidProfiles:CreateRaidProfilesPanel(parent)
            end)
        end

        mQoL_RaidProfiles:HookSettingsPanel()

        -- Initialize tracking
        lastSituation = mQoL_RaidProfiles:GetCurrentSituation()
        if GetSpecialization and GetSpecializationInfo then
            local specIndex = GetSpecialization()
            if specIndex then
                lastSpecID = GetSpecializationInfo(specIndex)
            end
        end

        -- Apply profile on login
        mQoL_RaidProfiles:UpdateCurrentProfile()
        return
    end

    -- PLAYER_SPECIALIZATION_CHANGED: Only update if spec actually changed
    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then
        if GetSpecialization and GetSpecializationInfo then
            local specIndex = GetSpecialization()
            if specIndex then
                local currentSpecID = GetSpecializationInfo(specIndex)
                if currentSpecID and currentSpecID ~= lastSpecID then
                    lastSpecID = currentSpecID
                    mQoL_RaidProfiles:UpdateCurrentProfile()
                end
            end
        end
        return
    end

    -- GROUP_ROSTER_UPDATE: Check for situation changes (Party/Raid/Arena/BG)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Only check if situational mode is enabled
        if not mQoL_RaidProfiles:IsSituationalModeEnabled() then 
            lastSituation = mQoL_RaidProfiles:GetCurrentSituation()
            return 
        end

        local currentSituation = mQoL_RaidProfiles:GetCurrentSituation()

        -- Only update if situation actually changed (nil->Party, Party->Raid, etc.)
        if currentSituation ~= lastSituation then
            lastSituation = currentSituation
            mQoL_RaidProfiles:UpdateCurrentProfile()
        end
        return
    end
end)