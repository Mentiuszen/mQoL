local addonName = ...

mQoL_Setup = mQoL_Setup or {}

local setupFrame
local session

local function GetSetupState()
    mQoL_DB = mQoL_DB or {}
    mQoL_DB.Setup = mQoL_DB.Setup or {}

    local setup = mQoL_DB.Setup
    setup.seenModules = setup.seenModules or {}
    return setup
end

local function CreateButton(parent, text, width, height)
    if mQoL_Templates and mQoL_Templates.CreateButton then
        return mQoL_Templates.CreateButton(parent, text, width, height)
    end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 110, height or 26)
    button:SetText(text)
    return button
end

local function CreateCheckbox(parent)
    if mQoL_Styles and mQoL_Styles.CreateCustomCheckbox then
        return mQoL_Styles.CreateCustomCheckbox(parent)
    end

    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox.SetValue = function(self, value) self:SetChecked(value == true) end
    checkbox.GetValue = function(self) return self:GetChecked() == true end
    checkbox:SetScript("OnClick", function(self)
        if self.OnValueChanged then
            self:OnValueChanged(self:GetChecked() == true)
        end
    end)
    return checkbox
end

local function CreateSetupFrame()
    if setupFrame then return setupFrame end

    local frame = CreateFrame("Frame", "mQoLSetupFrame", UIParent)
    frame:SetSize(560, 360)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if mQoL_Templates and mQoL_Templates.SetBackdrop then
        mQoL_Templates.SetBackdrop(frame,
            {edgeSize = 1},
            {0, 0, 0, 0.95},
            {0.5, 0.5, 0.5, 1})
    else
        frame.background = frame:CreateTexture(nil, "BACKGROUND")
        frame.background:SetAllPoints()
        frame.background:SetColorTexture(0.04, 0.04, 0.04, 0.95)
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -24)
    frame.title:SetTextColor(1, 0.82, 0)

    frame.progress = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.progress:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
    frame.progress:SetTextColor(0.65, 0.65, 0.65)

    frame.description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.description:SetPoint("TOP", frame.progress, "BOTTOM", 0, -22)
    frame.description:SetWidth(480)
    frame.description:SetJustifyH("CENTER")
    frame.description:SetJustifyV("TOP")

    frame.moduleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.moduleLabel:SetPoint("TOP", frame.description, "BOTTOM", 0, -22)
    frame.moduleLabel:SetTextColor(1, 0.82, 0)

    frame.moduleDescription = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.moduleDescription:SetPoint("TOP", frame.moduleLabel, "BOTTOM", 0, -10)
    frame.moduleDescription:SetWidth(440)
    frame.moduleDescription:SetJustifyH("CENTER")
    frame.moduleDescription:SetJustifyV("TOP")

    frame.checkbox = CreateCheckbox(frame)
    frame.checkbox:SetPoint("BOTTOM", frame, "BOTTOM", -90, 78)

    frame.checkboxLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.checkboxLabel:SetPoint("LEFT", frame.checkbox, "RIGHT", 8, 0)
    frame.checkboxLabel:SetText("Activate this module")

    frame.backButton = CreateButton(frame, "Back", 110, 28)
    frame.backButton:SetPoint("BOTTOMLEFT", 36, 28)

    frame.nextButton = CreateButton(frame, "Next", 110, 28)
    frame.nextButton:SetPoint("BOTTOMRIGHT", -36, 28)

    setupFrame = frame
    return frame
end

local function GetCurrentModule()
    if not session or session.page < 1 or session.page > #session.modules then
        return nil
    end
    return session.modules[session.page]
end

local function GetSummaryText()
    local enabledModules = {}

    for _, module in ipairs(session.modules) do
        if session.selected[module.key] then
            table.insert(enabledModules, "• " .. module.label)
        end
    end

    if #enabledModules == 0 then
        return "No new modules will be activated. You can enable them later from Hub Modules Tab."
    end

    return "The following modules will be activated after reload:\n\n" .. table.concat(enabledModules, "\n")
end

function mQoL_Setup:RefreshFrame()
    local frame = CreateSetupFrame()
    local pageCount = #session.modules
    local currentModule = GetCurrentModule()

    frame.checkbox:Hide()
    frame.checkboxLabel:Hide()
    frame.moduleLabel:Hide()
    frame.moduleDescription:Hide()
    frame.backButton:Show()
    frame.nextButton:Show()

    if session.page == 0 then
        frame.title:SetText(session.mode == "first" and "Welcome to mQoL" or "New modules available")
        frame.progress:SetText(session.mode == "first" and "Module setup" or "Update setup")
        frame.description:SetText(session.mode == "first"
            and "mQoL starts with only its Hub active. On the next pages, choose the modules you want to use. You can change your selection later in Hub Modules Tab."
            or "This update includes modules that are available for your game client. Review them and choose what you want to activate.")
        frame.backButton:Hide()
        frame.nextButton:SetText("Start")
    elseif currentModule then
        frame.title:SetText(currentModule.label)
        frame.progress:SetText(string.format("Module %d of %d", session.page, pageCount))
        frame.description:SetText("Choose whether this module should be active. It can be changed later from Hub Modules Tab.")
        frame.moduleLabel:SetText(currentModule.label)
        frame.moduleDescription:SetText(currentModule.description or "")
        frame.moduleLabel:Show()
        frame.moduleDescription:Show()
        frame.checkbox:SetValue(session.selected[currentModule.key] == true)
        frame.checkbox:Show()
        frame.checkboxLabel:Show()
        frame.nextButton:SetText(session.page == pageCount and "Review" or "Next")
    else
        frame.title:SetText("Setup summary")
        frame.progress:SetText("Ready to finish")
        frame.description:SetText(GetSummaryText())
        frame.nextButton:SetText("Finish")
    end

    frame.backButton:SetScript("OnClick", function()
        if session.page > 0 then
            session.page = session.page - 1
            mQoL_Setup:RefreshFrame()
        end
    end)

    frame.nextButton:SetScript("OnClick", function()
        if session.page <= pageCount then
            session.page = session.page + 1
            mQoL_Setup:RefreshFrame()
        else
            mQoL_Setup:Finish()
        end
    end)

    if currentModule then
        frame.checkbox.OnValueChanged = function(_, value)
            session.selected[currentModule.key] = value == true
        end
    end
end

function mQoL_Setup:Finish()
    if not session then return end

    local selectionChanged = false
    local failedModules = {}
    self.lastErrors = {}
    for _, module in ipairs(session.modules) do
        local enabled = session.selected[module.key] == true
        local wasEnabled = mQoL_Modules:IsModuleEnabled(module.key)
        local success = mQoL_Modules:SetModuleEnabled(module.key, enabled)

        if success then
            if wasEnabled ~= mQoL_Modules:IsModuleEnabled(module.key) then
                selectionChanged = true
            end
            mQoL_Modules:MarkModuleSeen(module.key)
        else
            local errorMessage = module.label .. " could not initialize its settings. It will be offered again on the next login."
            self.lastErrors[module.key] = errorMessage
            table.insert(failedModules, module.label)
            print("|cffff4444[mQoL Setup]|r " .. errorMessage)
        end
    end

    local setup = GetSetupState()
    setup.completed = true
    setup.pendingReload = selectionChanged

    if setupFrame then
        setupFrame:Hide()
    end
    session = nil

    if #failedModules > 0 and mQoL_Styles and mQoL_Styles.ShowCustomPopup then
        local function ContinueAfterError()
            if selectionChanged then
                -- ShowCustomPopup hides its shared frame after running the
                -- callback. Defer the next popup so it is not hidden by the
                -- error popup's click handler.
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        mQoL_Modules:ShowReloadPopup()
                    end)
                else
                    mQoL_Modules:ShowReloadPopup()
                end
            end
        end
        mQoL_Styles.ShowCustomPopup({
            text = "Some modules could not initialize and remain disabled:\n\n- " .. table.concat(failedModules, "\n- ") .. "\n\nThey will be offered again on the next login.",
            acceptText = selectionChanged and "Continue" or "OK",
            cancelText = "Close",
            onAccept = ContinueAfterError,
            onCancel = ContinueAfterError,
            width = 500,
            height = 240,
        })
    elseif selectionChanged then
        mQoL_Modules:ShowReloadPopup()
    end
end

function mQoL_Setup:Open(mode, modules)
    if not mQoL_Modules or not modules or #modules == 0 then return end

    session = {
        mode = mode,
        modules = modules,
        selected = {},
        page = 0,
    }

    for _, module in ipairs(modules) do
        session.selected[module.key] = mQoL_Modules:IsModuleEnabled(module.key)
    end

    local frame = CreateSetupFrame()
    self:RefreshFrame()
    frame:Show()
end

function mQoL_Setup:OpenIfNeeded()
    if not mQoL_Modules then return end

    local setup = GetSetupState()
    if not setup.completed then
        self:Open("first", mQoL_Modules:GetCompatibleModules())
        return
    end

    local newModules = mQoL_Modules:GetUnseenCompatibleModules()
    if #newModules > 0 then
        self:Open("update", newModules)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- Let Hub and its style templates finish their login initialization first.
    C_Timer.After(1, function()
        mQoL_Setup:OpenIfNeeded()
    end)
end)
