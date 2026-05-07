local addonName, _ = ...
mQoL_EditMode = mQoL_EditMode or {}

local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then return end

local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
if not (clientInfo.isRetail or clientInfo.isBCC or clientInfo.isClassic) then return end
local DeepCopy = mQoL_Utils.DeepCopy
local GetClassColor = mQoL_Utils.GetClassColor

local CLASSIC_EDIT_MODE_MIN_TOCVERSION = 50504
local CLASSIC_EDIT_MODE_AVAILABLE_VERSION = "5.5.4"

local function IsClassicEditModePending()
    return clientInfo.isClassic and ((tonumber(clientInfo.tocversion) or 0) < CLASSIC_EDIT_MODE_MIN_TOCVERSION)
end

local SITUATIONAL_MODE_KEY = "Use Situational Instead"

mQoL_EditMode.defaults = {
    editModeProfileMode = "Disabled",
    forcedProfile = "",
    advancedClassProfiles = {},
    advancedSpecProfiles = {},
    advancedViewMode = "Class",
    advancedSituational = {},
    simpleSituationalProfiles = {
        Party = "",
        Raid = "",
        Arena = "",
        Battleground = ""
    }
}

mQoL_EditMode_DB = mQoL_EditMode_DB or {}

local function EnsureDefaults(settings, defaults)
    for key, defaultValue in pairs(defaults) do
        if settings[key] == nil then
            settings[key] = type(defaultValue) == "table" and DeepCopy(defaultValue) or defaultValue
        end
    end
    for key in pairs(settings) do
        if defaults[key] == nil then
            settings[key] = nil
        end
    end
end

local function GetAccountEditModeDB()
    mQoL_EditMode_DB = mQoL_EditMode_DB or {}

    if not mQoL_EditMode_DB["Account"] then
        mQoL_EditMode_DB["Account"] = DeepCopy(mQoL_EditMode.defaults)
    end

    local accountDB = mQoL_EditMode_DB["Account"]

    local keysToRemove = {}
    for key, data in pairs(mQoL_EditMode_DB) do
        if key ~= "Account" and key ~= "ProfileBackups" and type(data) == "table" then
            for k, v in pairs(data) do
                if accountDB[k] == nil then
                    accountDB[k] = v
                end
            end
            table.insert(keysToRemove, key)
        end
    end
    for _, key in ipairs(keysToRemove) do
        mQoL_EditMode_DB[key] = nil
    end

    local function MigrateForcedProfile(profileName)
        if not profileName or profileName == "" then return end
        if not accountDB.forcedProfile or accountDB.forcedProfile == "" then
            accountDB.forcedProfile = profileName
            accountDB.editModeProfileMode = "Simple"
        end
    end

    if mQoL_DB and mQoL_DB["EditMode"] and mQoL_DB["EditMode"].settings then
        MigrateForcedProfile(mQoL_DB["EditMode"].settings.forcedProfile)
        mQoL_DB["EditMode"] = nil
    end

    if mQoL_DB and mQoL_DB["MainQoL"] and mQoL_DB["MainQoL"].settings and mQoL_DB["MainQoL"].settings.general then
        local oldProfile = mQoL_DB["MainQoL"].settings.general.forcedEditModeProfile
        MigrateForcedProfile(oldProfile)
        mQoL_DB["MainQoL"].settings.general.forcedEditModeProfile = nil
    end

    EnsureDefaults(accountDB, mQoL_EditMode.defaults)
    return accountDB
end

function mQoL_EditMode:InitializeDB()
    self.db = { settings = GetAccountEditModeDB() }
    local s = self.db.settings
    if not s.advancedClassProfiles then s.advancedClassProfiles = {} end
    if not s.advancedSpecProfiles then s.advancedSpecProfiles = {} end
    if not s.advancedSituational then s.advancedSituational = {} end
    if not s.simpleSituationalProfiles then s.simpleSituationalProfiles = DeepCopy(self.defaults.simpleSituationalProfiles) end
end

function mQoL_EditMode:GetEditModeProfiles()
    if IsClassicEditModePending() then
        return {}
    end

    if not EditModeManagerFrame or not EditModeManagerFrame.GetLayouts then
        return {}
    end
    local layouts = EditModeManagerFrame:GetLayouts()
    local names = {}
    for _, layout in ipairs(layouts) do
        if layout and layout.layoutName then
            table.insert(names, layout.layoutName)
        end
    end
    table.sort(names)
    return names
end

local function GetPlayerSpecID()
    local getSpecIndex = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not getSpecIndex or not getSpecInfo then return nil end
    local specIndex = getSpecIndex()
    if not specIndex then return nil end
    local specID = getSpecInfo(specIndex)
    if specID and specID ~= 0 then return specID end
    return nil
end

local function IsBlizzardDefaultLayoutName(layoutName)
    if type(layoutName) ~= "string" then return false end
    return layoutName == "Classic" or layoutName == "Modern"
end

local function GetLayoutsForBackup()
    local layouts = nil

    if C_EditMode and C_EditMode.GetLayouts then
        local ok, layoutInfo = pcall(C_EditMode.GetLayouts)
        if ok and layoutInfo then
            if layoutInfo.layouts then
                layouts = layoutInfo.layouts
            elseif type(layoutInfo) == "table" and #layoutInfo > 0 then
                layouts = layoutInfo
            end
        end
    end

    if not layouts and EditModeManagerFrame and EditModeManagerFrame.GetLayouts then
        local ok, layoutInfo = pcall(function()
            return EditModeManagerFrame:GetLayouts()
        end)
        if ok and layoutInfo then
            if layoutInfo.layouts then
                layouts = layoutInfo.layouts
            elseif type(layoutInfo) == "table" and #layoutInfo > 0 then
                layouts = layoutInfo
            end
        end
    end

    return layouts or {}
end

local function ExportLayoutString(layout, fallbackIndex)
    if not (layout and C_EditMode and C_EditMode.ConvertLayoutInfoToString) then
        return nil
    end

    if C_EditMode.GetLayoutInfo then
        local identifier = layout.layoutIdentifier or layout.layoutIndex or fallbackIndex
        if identifier ~= nil then
            local okInfo, layoutInfo = pcall(C_EditMode.GetLayoutInfo, identifier)
            if okInfo and layoutInfo then
                local okExport, exportString = pcall(C_EditMode.ConvertLayoutInfoToString, layoutInfo)
                if okExport and type(exportString) == "string" and exportString ~= "" then
                    return exportString
                end
            end
        end
    end

    local okExport, exportString = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
    if okExport and type(exportString) == "string" and exportString ~= "" then
        return exportString
    end

    return nil
end

function mQoL_EditMode:BackupPlayerProfiles(force)
    if IsClassicEditModePending() then
        return
    end

    if self._backupDoneThisSession and not force then return end
    if not force then
        self._backupDoneThisSession = true
    end

    mQoL_EditMode_DB = mQoL_EditMode_DB or {}
    mQoL_EditMode_DB.ProfileBackups = mQoL_EditMode_DB.ProfileBackups or {}
    local backupStore = mQoL_EditMode_DB.ProfileBackups

    -- Migrate old character-keyed backup format to profile-keyed version history.
    local now = (GetServerTime and GetServerTime()) or time()

    for key, value in pairs(backupStore) do
        if type(value) == "table" and type(value.profiles) == "table" then
            for profileName, oldEntry in pairs(value.profiles) do
                if type(profileName) == "string" and type(oldEntry) == "table" and type(oldEntry.exportString) == "string" and oldEntry.exportString ~= "" then
                    local profileBucket = backupStore[profileName]
                    if type(profileBucket) ~= "table" then
                        profileBucket = { versions = {} }
                        backupStore[profileName] = profileBucket
                    end
                    profileBucket.versions = profileBucket.versions or {}
                    local versions = profileBucket.versions
                    local latest = versions[#versions]
                    if not latest or latest.exportString ~= oldEntry.exportString then
                        table.insert(versions, {
                            exportString = oldEntry.exportString,
                            savedAt = oldEntry.updatedAt or now
                        })
                        while #versions > 5 do
                            table.remove(versions, 1)
                        end
                    end
                end
            end
            backupStore[key] = nil
        end
    end

    local layouts = GetLayoutsForBackup()

    for index, layout in ipairs(layouts) do
        local layoutName = layout and layout.layoutName
        if layoutName and layoutName ~= "" and not IsBlizzardDefaultLayoutName(layoutName) then
            local exportString = ExportLayoutString(layout, index)
            if exportString then
                local profileBucket = backupStore[layoutName]
                if type(profileBucket) ~= "table" then
                    profileBucket = { versions = {} }
                    backupStore[layoutName] = profileBucket
                end
                profileBucket.versions = profileBucket.versions or {}
                local versions = profileBucket.versions
                local latest = versions[#versions]

                if not latest or latest.exportString ~= exportString then
                    table.insert(versions, {
                        exportString = exportString,
                        savedAt = now
                    })
                    while #versions > 5 do
                        table.remove(versions, 1)
                    end
                end
            end
        end
    end
end

function mQoL_EditMode:GetCurrentSituation()
    local _, instanceType = IsInInstance()
    if instanceType == "arena" then return "Arena" end
    if instanceType == "pvp" then return "Battleground" end
    if IsInRaid() then return "Raid" end
    if IsInGroup() then return "Party" end
    return nil
end

local function SetupCombatEventFrame()
    if mQoL_EditMode.combatEventFrame then return end
    mQoL_EditMode.combatEventFrame = CreateFrame("Frame")
    mQoL_EditMode.combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    mQoL_EditMode.combatEventFrame:SetScript("OnEvent", function()
        if mQoL_EditMode.pendingProfileLoad then
            local pending = mQoL_EditMode.pendingProfileLoad
            mQoL_EditMode.pendingProfileLoad = nil
            mQoL_EditMode:ForceEditModeProfile(pending)
        end
    end)
end

function mQoL_EditMode:ForceEditModeProfile(profileName)
    if IsClassicEditModePending() then
        return false
    end

    if not profileName or profileName == "" then return false end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingProfileLoad = profileName
        SetupCombatEventFrame()
        return false
    end

    -- Use C_EditMode directly to avoid tainting EditModeManagerFrame
    if C_EditMode and C_EditMode.SetActiveLayout then
        local layouts = nil
        if C_EditMode.GetLayouts then
            local layoutInfo = C_EditMode.GetLayouts()
            if layoutInfo and layoutInfo.layouts then
                layouts = layoutInfo.layouts
            end
        end
        
        if not layouts and EditModeManagerFrame and EditModeManagerFrame.GetLayouts then
             local layoutInfo = EditModeManagerFrame:GetLayouts()
             if layoutInfo and layoutInfo.layouts then
                 layouts = layoutInfo.layouts
             elseif layoutInfo and #layoutInfo > 0 then
                 layouts = layoutInfo
             end
        end
        
        if layouts then
            for i, layout in ipairs(layouts) do
                if layout and layout.layoutName == profileName then
                    if layout.layoutIdentifier then
                        C_EditMode.SetActiveLayout(layout.layoutIdentifier)
                        return true
                    end
                end
            end
        end
    end

    -- Legacy Fallback (Only used if C_EditMode fails or layout not found)
    if EditModeManagerFrame and EditModeManagerFrame.GetLayouts and EditModeManagerFrame.SelectLayout then
        local layouts = EditModeManagerFrame:GetLayouts()
        for i, layout in ipairs(layouts) do
            if layout and layout.layoutName == profileName then
                EditModeManagerFrame:SelectLayout(i)
                return true
            end
        end
    end
    return false
end

function mQoL_EditMode:IsSituationalModeEnabled()
    local s = self.db and self.db.settings
    if not s then return false end
    local mode = s.editModeProfileMode or "Disabled"
    if mode == "Simple" then
        return (s.forcedProfile == SITUATIONAL_MODE_KEY)
    elseif mode == "Advanced" then
        return true
    end
    return false
end

function mQoL_EditMode:UpdateCurrentProfile(immediate)
    if IsClassicEditModePending() then
        return
    end

    if self.updateTimer then self.updateTimer:Cancel() end

    local function Update()
        local s = self.db and self.db.settings
        if not s then return end

        local mode = s.editModeProfileMode or "Disabled"
        if mode == "Disabled" then return end

        local situation = self:GetCurrentSituation()
        local profileToLoad = nil

        if mode == "Simple" then
            if s.forcedProfile == SITUATIONAL_MODE_KEY and situation then
                local sitProfile = s.simpleSituationalProfiles and s.simpleSituationalProfiles[situation]
                if sitProfile and sitProfile ~= "" then
                    profileToLoad = sitProfile
                end
            end

            if not profileToLoad and s.forcedProfile and s.forcedProfile ~= "" and s.forcedProfile ~= SITUATIONAL_MODE_KEY then
                profileToLoad = s.forcedProfile
            end

        elseif mode == "Advanced" then
            local _, classFile = UnitClass("player")
            local specID = GetPlayerSpecID()
            
            -- Check if specID is a valid main spec (handles Initial Spec / low level cases)
            local isValidSpec = false
            if specID then
                local getNum = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations) or GetNumSpecializations
                local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
                if getNum and getInfo then
                    for i = 1, (getNum() or 0) do
                        local id = getInfo(i)
                        if id == specID then
                            isValidSpec = true
                            break
                        end
                    end
                end
            end

            if not isValidSpec and classFile then
                specID = classFile .. "_NoSpec"
            end

            local specProfile = specID and s.advancedSpecProfiles and s.advancedSpecProfiles[specID]
            local classProfile = classFile and s.advancedClassProfiles and s.advancedClassProfiles[classFile]

            if situation and s.advancedSituational then
                if specID and s.advancedSituational[specID] then
                    local sitProfile = s.advancedSituational[specID][situation]
                    if sitProfile and sitProfile ~= "" then
                        profileToLoad = sitProfile
                    end
                end
                if not profileToLoad and classFile and s.advancedSituational[classFile] then
                    local sitProfile = s.advancedSituational[classFile][situation]
                    if sitProfile and sitProfile ~= "" then
                        profileToLoad = sitProfile
                    end
                end
            end

            if not profileToLoad then
                profileToLoad = specProfile or classProfile
            end
        end

        if profileToLoad and profileToLoad ~= "" then
            self:ForceEditModeProfile(profileToLoad)
        end
    end

    if immediate then
        Update()
    else
        self.updateTimer = C_Timer.NewTimer(0.5, Update)
    end
end

function mQoL_EditMode:CreateAdvancedSetupPanel(parent, width)
    local module = self
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
    local currentHoverTarget = nil
    local dropTargets = {}

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
            tabClass.text:SetTextColor(mode == "Class" and 1 or 0.5, mode == "Class" and 0.82 or 0.5, mode == "Class" and 0 or 0.5)
        end
        if tabSpec.text then
            tabSpec.text:SetTextColor(mode == "Spec" and 1 or 0.5, mode == "Spec" and 0.82 or 0.5, mode == "Spec" and 0 or 0.5)
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
                local viewMode = s.advancedViewMode or "Class"
                local mainProfile = (viewMode == "Class") and s.advancedClassProfiles[targetID] or s.advancedSpecProfiles[targetID]
                if mainProfile and mainProfile ~= "" then
                    HideDragCursor()
                    return false
                end
                if not s.advancedSituational[targetID] then s.advancedSituational[targetID] = {} end
                s.advancedSituational[targetID][situationKey] = currentDrag
            else
                if HasSituationalProfiles(targetID) then
                    HideDragCursor()
                    return false
                end
                local viewMode = s.advancedViewMode or "Class"
                if viewMode == "Class" then
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
                local pSpecID = GetPlayerSpecID()
                if targetID == pSpecID then shouldUpdate = true end
            end
            if shouldUpdate then module:UpdateCurrentProfile() end
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
        local profiles = module:GetEditModeProfiles()
        for _, child in ipairs({leftContent:GetChildren()}) do child:Hide() child:SetParent(nil) end

        local y, rowH = 0, 22
        local textWidth = leftContent:GetWidth() - scrollMargin - 10
        for _, name in ipairs(profiles) do
            local btn = CreateFrame("Button", nil, leftContent)
            btn:SetSize(leftContent:GetWidth() - scrollMargin, rowH)
            btn:SetPoint("TOPLEFT", 0, -y)

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", 4, 0)
            text:SetWidth(textWidth)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            text:SetText(name)

            btn:SetScript("OnEnter", function(self)
                if not currentDrag then
                    bg:SetColorTexture(1, 1, 1, 0.08)
                end
                if text:IsTruncated() then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(name)
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function()
                if not currentDrag then
                    bg:SetColorTexture(1, 1, 1, 0.03)
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
                    bg:SetColorTexture(1, 1, 1, 0.03)
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
        local viewMode = s.advancedViewMode or "Class"
        UpdateTabAppearance()
        ClearDropTargets()

        for _, child in ipairs({rightContent:GetChildren()}) do child:Hide() child:SetParent(nil) end

        local items = {}

        local function ForEachAvailableClass(cb)
            for classID = 1, 13 do
                local className, classFile, blizzClassID = GetClassInfo(classID)
                if className and classFile and blizzClassID then
                    cb(className, classFile, blizzClassID)
                end
            end
        end

        if viewMode == "Class" then
            local seen = {}
            ForEachAvailableClass(function(className, classFile)
                if not seen[classFile] then
                    seen[classFile] = true
                    local color = GetClassColor(classFile, { r = 0.5, g = 0.5, b = 0.5 })
                    table.insert(items, {id=classFile, name=className, color=color, assigned=s.advancedClassProfiles[classFile]})
                end
            end)
        else
            local getNumSpecs = GetNumSpecializationsForClassID or (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID)
            local getSpecInfo = GetSpecializationInfoForClassID or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID)
            if getNumSpecs and getSpecInfo then
                local sex = UnitSex and UnitSex("player")
                local seenSpecIDs = {}
                ForEachAvailableClass(function(className, classFile, classID)
                    local specCount = getNumSpecs(classID)
                    if specCount and specCount > 0 then
                        local color = GetClassColor(classFile, { r = 0.5, g = 0.5, b = 0.5 })
                        for j = 1, specCount do
                            local id, specName = getSpecInfo(classID, j, sex)
                            if id and specName and not seenSpecIDs[id] then
                                seenSpecIDs[id] = true
                                table.insert(items, {id=id, name=className .. ": " .. specName, color=color, assigned=s.advancedSpecProfiles[id]})
                            end
                        end
                        
                        local noSpecID = classFile .. "_NoSpec"
                        table.insert(items, {id=noSpecID, name=className .. ": No Specialization", color=color, assigned=s.advancedSpecProfiles[noSpecID]})
                    end
                end)
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
            local c = item.color or {r=0.5, g=0.5, b=0.5}
            local origR, origG, origB, origA = c.r*0.15, c.g*0.15, c.b*0.15, 0.5
            bg:SetColorTexture(origR, origG, origB, origA)

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
                    if s.advancedSituational then s.advancedSituational[item.id] = nil end
                else
                    if viewMode == "Class" then s.advancedClassProfiles[item.id] = nil else s.advancedSpecProfiles[item.id] = nil end
                end
                RefreshRight()

                local shouldUpdate = false
                local _, pClass = UnitClass("player")
                if viewMode == "Class" then
                    if item.id == pClass then shouldUpdate = true end
                else
                    local pSpecID = GetPlayerSpecID()
                    if item.id == pSpecID then shouldUpdate = true end
                end
                if shouldUpdate then module:UpdateCurrentProfile() end
            end)

            local displayAssigned = item.assigned
            if hasSituational then displayAssigned = "Situational" end
            if not displayAssigned and not hasSituational then
                deleteBtn:Hide()
            end

            local assigned = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            assigned:SetPoint("RIGHT", deleteBtn, "LEFT", -5, 0)
            assigned:SetText(displayAssigned or "None")
            assigned:SetTextColor(displayAssigned and 0 or 0.5, displayAssigned and 1 or 0.5, displayAssigned and 0 or 0.5)

            row:SetScript("OnEnter", function(self)
                if currentDrag then
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
                    if not hasSituational then
                        if viewMode == "Class" then s.advancedClassProfiles[item.id] = nil else s.advancedSpecProfiles[item.id] = nil end
                        RefreshRight()
                    end
                elseif button == "LeftButton" and currentDrag then
                    ApplyDragToTarget(item.id, nil)
                end
            end)

            if not hasSituational then
                RegisterDropTarget(row, item.id, nil)
            end

            y = y + rowH + 1

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
                            local shouldUpdate = false
                            local _, pClass = UnitClass("player")
                            local currentView = s.advancedViewMode or "Class"
                            if currentView == "Class" then
                                if item.id == pClass then shouldUpdate = true end
                            else
                                local pSpecID = GetPlayerSpecID()
                                if item.id == pSpecID then shouldUpdate = true end
                            end
                            if shouldUpdate then module:UpdateCurrentProfile() end
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

                    if not mainAssigned then
                        RegisterDropTarget(subRow, item.id, sit)
                    end

                    y = y + 19
                end
                y = y + 4
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

function mQoL_EditMode:CreateClassicEditModeNoticePanel(parent)
    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Edit Mode Settings", nil, "TopSeparator")
    local currentVersion = clientInfo.version or "unknown"
    local currentTocVersion = tonumber(clientInfo.tocversion) or 0

    local message = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    message:SetPoint("TOPLEFT", 20, contentContainer.currentY)
    message:SetWidth(770)
    message:SetJustifyH("LEFT")
    message:SetText(string.format(
        "|cffffd100Edit Mode will be available in version %s.|r\n\nCurrent Classic client: %s (%d).",
        CLASSIC_EDIT_MODE_AVAILABLE_VERSION,
        currentVersion,
        currentTocVersion
    ))

    contentContainer.currentY = contentContainer.currentY - ((message.GetStringHeight and message:GetStringHeight()) or 42) - 24

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

function mQoL_EditMode:CreateEditModePanel(parent)
    if IsClassicEditModePending() then
        return self:CreateClassicEditModeNoticePanel(parent)
    end

    local module = self
    local s = self.db.settings

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Edit Mode Settings", {
        text = "How does this work?",
        textColor = {1, 0.82, 0},
        explanation = "Ensure your preferred UI layout is always active.\n\n• Profile Force will load a specific Edit Mode profile upon login.\n• Profiles available here are the ones you have created in the Edit Mode interface.\n• This will force the profile even in blocked areas like the Forbidden Reach.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "TopSeparator")

    local AddGap = mQoL_Templates.AddGap

    local function AddOptionRow(label, type, opts, extra, applyFunc)
        return mQoL_Hub:AddOptionRow(contentContainer, label, type, opts, extra, applyFunc)
    end

    local modeItems = {
        { text = "Disabled", value = "Disabled" },
        { text = "Simple", value = "Simple" },
        { text = "Advanced", value = "Advanced" }
    }

    local RefreshVisibility = nil

    local _, modeDropdown = AddOptionRow("Edit Mode Profile Mode", "dropdown", {
        list = modeItems,
        value = s.editModeProfileMode or "Disabled",
        width = 160,
        onValueChanged = function(value)
            s.editModeProfileMode = value
            if RefreshVisibility then RefreshVisibility() end
            module:UpdateCurrentProfile(true)
        end
    })
    AddGap(contentContainer, "Standard")

    local function GetForcedProfileDropdownItems()
        local items = {}
        table.insert(items, { text = SITUATIONAL_MODE_KEY, value = SITUATIONAL_MODE_KEY, underline = true })
        for _, name in ipairs(module:GetEditModeProfiles()) do
            table.insert(items, { text = name, value = name })
        end
        return items
    end

    local function GetSituationalProfileDropdownItems()
        local items = {}
        table.insert(items, { text = "None", value = "" })
        for _, name in ipairs(module:GetEditModeProfiles()) do
            table.insert(items, { text = name, value = name })
        end
        return items
    end

    local function ValueExists(list, value)
        for _, item in ipairs(list) do
            if item.value == value then return true end
        end
        return false
    end

    local advancedAnchorY = contentContainer.currentY

    local simpleSettingsFrame = CreateFrame("Frame", nil, contentContainer)
    simpleSettingsFrame:SetSize(850, 150)
    simpleSettingsFrame:SetPoint("TOPLEFT", 0, advancedAnchorY)
    simpleSettingsFrame.currentY = 0

    if (s.forcedProfile == nil or s.forcedProfile == "") and (s.editModeProfileMode == "Simple") then
        s.editModeProfileMode = "Disabled"
    end

    local forceProfileRow, dropdownControl = mQoL_Hub:AddOptionRow(simpleSettingsFrame, "Force Edit Mode Profile", "dropdown", {
        list = GetForcedProfileDropdownItems(),
        value = s.forcedProfile or SITUATIONAL_MODE_KEY,
        width = 220,
        onValueChanged = function(value)
            s.forcedProfile = value
            if RefreshVisibility then RefreshVisibility() end
            module:UpdateCurrentProfile(true)
        end
    })

    if contentContainer.optionsLabels and simpleSettingsFrame.optionsLabels and simpleSettingsFrame.optionsLabels["Force Edit Mode Profile"] then
        contentContainer.optionsLabels["Force Edit Mode Profile"] = simpleSettingsFrame.optionsLabels["Force Edit Mode Profile"]
    end

    local simpleSitContainer = CreateFrame("Frame", nil, simpleSettingsFrame)
    simpleSitContainer:SetSize(850, 150)
    simpleSitContainer:SetPoint("TOPLEFT", 0, simpleSettingsFrame.currentY - 20)
    simpleSitContainer.currentY = 0

    local sitDropdowns = {}
    local function AddSituationalDropdown(label, key)
        local row, dd = mQoL_Hub:AddOptionRow(simpleSitContainer, label, "dropdown", {
            list = GetSituationalProfileDropdownItems(),
            value = s.simpleSituationalProfiles[key] or "",
            width = 220,
            onValueChanged = function(val)
                s.simpleSituationalProfiles[key] = val
                module:UpdateCurrentProfile(true)
            end
        })
        AddGap(simpleSitContainer, "Standard")
        sitDropdowns[key] = dd
    end

    AddSituationalDropdown("Party (2-5 Players)", "Party")
    AddSituationalDropdown("Raid (6-40 Players)", "Raid")
    AddSituationalDropdown("Arena", "Arena")
    AddSituationalDropdown("Battleground", "Battleground")

    local advancedPanel = self:CreateAdvancedSetupPanel(contentContainer, 770)
    advancedPanel:SetPoint("TOPLEFT", 20, advancedAnchorY)
    advancedPanel:Hide()

    RefreshVisibility = function()
        local mode = s.editModeProfileMode or "Disabled"
        local advancedPanelHeight = 270

        if mode == "Simple" then
            simpleSettingsFrame:ClearAllPoints()
            simpleSettingsFrame:SetPoint("TOPLEFT", 0, advancedAnchorY)
            simpleSettingsFrame:Show()
            advancedPanel:Hide()

            if s.forcedProfile == SITUATIONAL_MODE_KEY then
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

    local function RefreshDropdowns()
        local forced = s.forcedProfile or ""
        local forcedItems = GetForcedProfileDropdownItems()
        local existsForced = (forced == SITUATIONAL_MODE_KEY) or ValueExists(forcedItems, forced)
        if not existsForced then
            s.forcedProfile = nil
            forced = ""
            s.editModeProfileMode = "Disabled"
        end
        if dropdownControl and dropdownControl.SetList then
            dropdownControl:SetList(forcedItems)
            if dropdownControl.SetValue then dropdownControl:SetValue(forced ~= "" and forced or SITUATIONAL_MODE_KEY) end
            if dropdownControl.text then
                dropdownControl.text:SetText((forced and forced ~= "") and forced or SITUATIONAL_MODE_KEY)
            end
        end

        local sitItems = GetSituationalProfileDropdownItems()
        for key, dd in pairs(sitDropdowns) do
            if dd and dd.SetList then
                dd:SetList(sitItems)
                local val = s.simpleSituationalProfiles[key] or ""
                local exists = (val == "") or ValueExists(sitItems, val)
                if not exists then
                    s.simpleSituationalProfiles[key] = ""
                    val = ""
                end
                if dd.SetValue then dd:SetValue(val) end
                if dd.text then dd.text:SetText((val and val ~= "") and val or "None") end
            end
        end

        if modeDropdown and modeDropdown.SetValue then
            modeDropdown:SetValue(s.editModeProfileMode or "Disabled")
        end
        if modeDropdown and modeDropdown.text then
            modeDropdown.text:SetText(s.editModeProfileMode or "Disabled")
        end

        if advancedPanel and advancedPanel.Refresh then advancedPanel.Refresh() end
        RefreshVisibility()
    end

    panel:SetScript("OnShow", function()
        RefreshDropdowns()
    end)

    RefreshVisibility()

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
        if scrollFrame and scrollFrame.SetVerticalScroll then
            scrollFrame:SetVerticalScroll(0)
        end
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

-- Event Handler
local eventFrame = CreateFrame("Frame")
local lastSituation = nil
local lastSpecID = nil

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("EditMode") then return end

    if event == "ADDON_LOADED" and arg1 == addonName then
        mQoL_EditMode:InitializeDB()
        return
    end

    if event == "PLAYER_LOGIN" then
        if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
            mQoL_Hub:RegisterModuleOptions("mQoL_EditMode", "Edit Mode", function(parent)
                return mQoL_EditMode:CreateEditModePanel(parent)
            end)
        end

        if IsClassicEditModePending() then
            return
        end

        lastSituation = mQoL_EditMode:GetCurrentSituation()
        lastSpecID = GetPlayerSpecID()

        C_Timer.After(1, function()
            mQoL_EditMode:BackupPlayerProfiles()
            mQoL_EditMode:UpdateCurrentProfile(true)
        end)
        return
    end

    if IsClassicEditModePending() then
        return
    end

    if event == "PLAYER_LOGOUT" then
        mQoL_EditMode:BackupPlayerProfiles(true)
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then
        local currentSpecID = GetPlayerSpecID()
        if currentSpecID and currentSpecID ~= lastSpecID then
            lastSpecID = currentSpecID
            mQoL_EditMode:UpdateCurrentProfile()
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if not mQoL_EditMode:IsSituationalModeEnabled() then
            lastSituation = mQoL_EditMode:GetCurrentSituation()
            return
        end

        local currentSituation = mQoL_EditMode:GetCurrentSituation()
        if currentSituation ~= lastSituation then
            lastSituation = currentSituation
            mQoL_EditMode:UpdateCurrentProfile()
        end
        return
    end
end)