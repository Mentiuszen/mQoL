local addonName, L = ...
mQoL_Mailbox = mQoL_Mailbox or {}

-- Check if Hub is Available
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
    return
end

-- Check Client Version
local clientInfo = mQoL_Hub.clientInfo

mQoL_Mailbox.goldBefore = nil
local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000

local function GetServerAndFaction()
    local realmName = GetRealmName():gsub("%s+", "")
    local faction = UnitFactionGroup("player") or "Unknown"
    return realmName, faction
end

-- Default Settings -- DO NOT STORE HERE BLIZZARD SETTINGS ONLY FOR CUSTOM FUNCTIONS (Defaults are stored in FirstSetup)
mQoL_Mailbox.defaults = {
    enableMailboxSidePanel = false,
    enableGoldSummary = false,
    autoSubject = "",
    profiles = true,
}

--Initialize Database
function mQoL_Mailbox:InitializeDB()
    mQoL_Database:MigrateModule("Mailbox", self.defaults)
    self.db = mQoL_Database:GetSettings("Mailbox") 
    self.profile = self:GetActiveProfile()
    
    for key, defaultValue in pairs(self.defaults) do
        if self.db[key] == nil then
            self.db[key] = defaultValue
        end
    end
end

function mQoL_Mailbox:GetActiveProfile()
    local moduleDB = mQoL_Database:MigrateModule("Mailbox", self.defaults)
    moduleDB.profiles = moduleDB.profiles or {}

    local realm, faction = GetServerAndFaction()
    local profileKey = realm .. "-" .. faction

    if not moduleDB.profiles[profileKey] then
        moduleDB.profiles[profileKey] = {
            altsList = {},
            friendsList = {},
            lastRecipient = ""
        }
    end

    local profile = moduleDB.profiles[profileKey]
    profile.altsList = profile.altsList or {}
    profile.friendsList = profile.friendsList or {}
    profile.lastRecipient = profile.lastRecipient or ""

    return profile
end

-- Save Mailbox Server/Faction Profiles for friend/alt list
function mQoL_Mailbox:SaveProfile()
    local moduleDB = mQoL_DB["Mailbox"]
    if not moduleDB then return end

    local realm, faction = GetServerAndFaction()
    local profileKey = realm .. "-" .. faction
    moduleDB.profiles = moduleDB.profiles or {}
    moduleDB.profiles[profileKey] = self.profile
end

function mQoL_Mailbox:ApplySettings()
    local s = self.db
    local profile = self.profile
    
    -- SidePanel
    if not s.enableMailboxSidePanel then
        if self.sidePanel and self.sidePanel:IsShown() then
            self.sidePanel:Hide()
        end
        return
    end

    if SendMailFrame and SendMailFrame:IsShown() then
        if not self.sidePanel then
            self:CreateSidePanel()
        end
        self:UpdateSidePanelVisibility()
        self:RefreshRecipientLists()
    else
        if self.sidePanel and self.sidePanel:IsShown() then
            self.sidePanel:Hide()
        end
    end

    -- Auto subject
    if s.autoSubject and s.autoSubject ~= "" then
        SendMailSubjectEditBox:SetText(s.autoSubject)
    end
end

function mQoL_Mailbox:RefreshRecipientLists()
    if not self.sidePanel then return end
    local profile = self.profile
    if not profile then return end

    local function RefreshContainer(container, data)
        if not container then return end
        container.recipientButtons = container.recipientButtons or {}

        for i, name in ipairs(data or {}) do
            if name and name ~= "" then
                local btn = container.recipientButtons[i]
                if not btn then
                    btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
                    btn:SetSize(110, 20)
                    btn:SetScript("OnClick", function(self)
                        SendMailNameEditBox:SetText(self:GetText())
                    end)
                    container.recipientButtons[i] = btn
                end

                btn:SetText(name)

                if i == 1 then
                    local xOffset = 5
                    local yOffset = container.firstButtonYOffset or -15
                    btn:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset, yOffset)
                else
                    btn:SetPoint("TOPLEFT", container.recipientButtons[i - 1], "BOTTOMLEFT", 0, -2)
                end

                btn:Show()
            end
        end

        -- Hide not used buttons
        for i = (#data or 0) + 1, #container.recipientButtons do
            if container.recipientButtons[i] then
                container.recipientButtons[i]:Hide()
            end
        end
    end

    RefreshContainer(self.sidePanel.altsContainer, profile.altsList)
    RefreshContainer(self.sidePanel.friendsContainer, profile.friendsList)
end

-- Gold Tracking
function mQoL_Mailbox:StartGoldTracking()
    if not self.db.enableGoldSummary then
        return
    end
    self.goldBefore = GetMoney()
end

-- convert gold format
local function FormatNumber(num)
    local formatted = tostring(num)
    while true do
        local k
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        if k == 0 then break end
    end
    return formatted
end

function mQoL_Mailbox:EndGoldTracking()
    if not self.db.enableGoldSummary then return end
    if not self.goldBefore then return end

    local goldAfter = GetMoney()
    local collected = goldAfter - self.goldBefore

    if collected > 0 then
        local gold   = math.floor(collected / COPPER_PER_GOLD)
        local silver = math.floor((collected % COPPER_PER_GOLD) / COPPER_PER_SILVER)
        local copper = collected % COPPER_PER_SILVER

        local goldIcon   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
        local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
        local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"

        print(string.format("|cffFFD700Collected Gold:|r %s%s %02d%s %02d%s",
            FormatNumber(gold), goldIcon, silver, silverIcon, copper, copperIcon))
    end

    self.goldBefore = nil
end

local categoryMap = {
    Cloth        = { classID = 7, subclassID = 5 },
    Leather      = { classID = 7, subclassID = 6 },
    Mining       = { classID = 7, subclassID = 7 },
    Cooking      = { classID = 7, subclassID = 8 },
    Herbs        = { classID = 7, subclassID = 9 },
    Elemental    = { classID = 7, subclassID = 10 },
    Enchanting   = { classID = 7, subclassID = 12 },
    Gems         = { classID = 3, subclassID = -1 },
    Consumables  = { classID = 0, subclassID = -1 },
    ["BoE Gear"] = { bindType = 2 },
}

local function MatchesCategory(itemID, category)
    local def = categoryMap[category]
    if not def then return false end

    local classID, subclassID, bindType

    if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
        classID, subclassID, bindType = select(12, C_Item.GetItemInfo(itemID))
    else
        local _, _, _, _, _, _, _, _, _, _, _, classID_, subclassID_, bindType_ = GetItemInfo(itemID)
        classID, subclassID, bindType = classID_, subclassID_, bindType_
    end

    if not classID then return false end

    if def.bindType then
        return bindType == def.bindType
    elseif def.classID == classID and (def.subclassID == -1 or def.subclassID == subclassID) then
        return true
    end

    return false
end

function mQoL_Mailbox:FindMatchingItems(category)
    local found = {}

    for bag = 0, 5 do
        local slots
        if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
            slots = C_Container.GetContainerNumSlots(bag)
        else
            slots = GetContainerNumSlots(bag)
        end

        for slot = 1, slots do
            local item
            if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
                item = C_Container.GetContainerItemInfo(bag, slot)
            else
                local icon, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bag, slot)
                item = {
                    itemID = itemLink and tonumber(itemLink:match("item:(%d+):")),
                    isLocked = locked,
                }
            end

            if item and item.itemID and not item.isLocked and (item.isBound == nil or not item.isBound) then
                if not self:IsItemAlreadyAttached(item.itemID) and MatchesCategory(item.itemID, category) then
                    table.insert(found, { bag = bag, slot = slot, itemID = item.itemID })
                    if #found >= ATTACHMENTS_MAX_SEND then
                        return found
                    end
                end
            end
        end
    end

    return found
end

function mQoL_Mailbox:IsItemAlreadyAttached(itemID)
    for i = 1, ATTACHMENTS_MAX_SEND do
        local link = GetSendMailItemLink(i)
        if link then
            local attachedID = tonumber(link:match("item:(%d+):"))
            if attachedID and attachedID == itemID then
                return true
            end
        end
    end
    return false
end

function mQoL_Mailbox:AttachItemsByCategory(category)
    local list = self:FindMatchingItems(category)
    if #list == 0 then
        return
    end

    self.sendQueue = list
    self.currentAttachment = 1
    self:ProcessSendQueue(category)
end

function mQoL_Mailbox:ProcessSendQueue(category)
    local attachedCount = 0

    while self.sendQueue and self.currentAttachment <= #self.sendQueue do
        local item = self.sendQueue[self.currentAttachment]

        local itemExists, isLocked
        if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
            local location = ItemLocation:CreateFromBagAndSlot(item.bag, item.slot)
            itemExists = C_Item.DoesItemExist(location)
            isLocked = C_Item.IsLocked(location)
        else
            local _, _, locked = GetContainerItemInfo(item.bag, item.slot)
            itemExists = true
            isLocked = locked
        end

        if not itemExists or isLocked then
            self.currentAttachment = self.currentAttachment + 1
        else
            local freeSlot = nil
            for i = 1, ATTACHMENTS_MAX_SEND do
                if not HasSendMailItem(i) then
                    freeSlot = i
                    break
                end
            end

            if not freeSlot then
                break
            end

            ClearCursor()
            if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
                C_Container.PickupContainerItem(item.bag, item.slot)
            else
                PickupContainerItem(item.bag, item.slot)
            end
            ClickSendMailItemButton(freeSlot)

            attachedCount = attachedCount + 1
            self.currentAttachment = self.currentAttachment + 1
        end
    end

    self.sendQueue = nil
    self.currentAttachment = nil
end

-- Not used
function mQoL_Mailbox:GetProfileKey()
    local realm, faction = GetServerAndFaction()
    return realm .. "-" .. faction
end

string.trim = string.trim or function(s)
    return s:match("^%s*(.-)%s*$")
end

function mQoL_Mailbox:CreateSidePanel()
    if self.sidePanel then return end
    if not MailFrame then
        return
    end

    self.sidePanel = CreateFrame("Frame", addonName .. "MailboxSidePanel", MailFrame, "BasicFrameTemplateWithInset")
	local sidePanel = self.sidePanel
    sidePanel:SetSize(400, 420)
    sidePanel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 10, 0)
    sidePanel:Hide()

    -- Title
    sidePanel.title = sidePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sidePanel.title:SetPoint("TOP", 0, -5)
    sidePanel.title:SetText("Mailbox Sidepanel")

    -- Recipiant
    local recipientLabel = sidePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    recipientLabel:SetPoint("TOPLEFT", 10, -40)
    recipientLabel:SetText("Select Recipient:")

    local listWidth, listHeight = 120, 150
    local listSpacing = 10
    local startX = 10

	local function CreateRecipientListContainer(posX, title)
		local container
		if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBcc then
			container = CreateFrame("Frame", nil, sidePanel, "BackdropTemplate")
			container:SetBackdrop({
				bgFile = "Interface/Tooltips/UI-Tooltip-Background",
				edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 4, right = 4, top = 4, bottom = 4 }
			})
			container:SetBackdropColor(0, 0, 0, 0.5)
		else
			container = CreateFrame("Frame", nil, sidePanel)
			if container.SetBackdrop then
				container:SetBackdrop({
					bgFile = "Interface/Tooltips/UI-Tooltip-Background",
					edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
					tile = true, tileSize = 16, edgeSize = 16,
					insets = { left = 4, right = 4, top = 4, bottom = 4 }
				})
				container:SetBackdropColor(0, 0, 0, 0.5)
			end
		end

		container:SetSize(listWidth, listHeight)
		container:SetPoint("TOPLEFT", posX, -70)

		container.label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		container.label:SetPoint("TOP", 0, -6)
		container.label:SetText(title)

		-- Offset for first button in table
		container.firstButtonYOffset = -15

		return container
	end

    self.sidePanel.altsContainer    = CreateRecipientListContainer(startX + 0 * (listWidth + listSpacing), "Alts")
    self.sidePanel.guildContainer   = CreateRecipientListContainer(startX + 1 * (listWidth + listSpacing), "Guild")
    self.sidePanel.friendsContainer = CreateRecipientListContainer(startX + 2 * (listWidth + listSpacing), "Friends")

    -- Separator
    local separator = sidePanel:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(1, 1, 1, 0.2)
    separator:SetSize(360, 1)
    separator:SetPoint("TOPLEFT", 10, -240)

    -- Mass Send
    local massTitle = sidePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    massTitle:SetPoint("TOPLEFT", 10, -250)
    massTitle:SetText("Item Mass Send")

    local itemCategories = {
        { name = "Cloth", icon = "Interface/Icons/INV_Fabric_Silk_01" },
        { name = "Leather", icon = "Interface/Icons/INV_Misc_LeatherScrap_03" },
        { name = "Mining", icon = "Interface/Icons/INV_Ore_Copper_01" },
        { name = "Cooking", icon = "Interface/Icons/INV_Misc_Food_41" },
        { name = "Herbs", icon = "Interface/Icons/INV_Misc_Herb_03" },
        { name = "Elemental", icon = "Interface/Icons/INV_Elemental_Mote_Fire01" },
        { name = "Gems", icon = "Interface/Icons/INV_Jewelcrafting_Gem_03" },
        { name = "Enchanting", icon = "Interface/Icons/INV_Enchant_EssenceArcaneLarge" },
        { name = "BoE Gear", icon = "Interface/Icons/INV_Chest_Cloth_17" },
        { name = "Consumables", icon = "Interface/Icons/INV_Potion_76" },
    }

    sidePanel.itemIcons = {}

    local iconSize = 32
    local spacing = 30
    local labelHeight = 12
    local iconsPerRow = 5

    for i, cat in ipairs(itemCategories) do
        local iconContainer = CreateFrame("Frame", nil, sidePanel)
        iconContainer:SetSize(iconSize, iconSize + labelHeight)

        local row = math.floor((i - 1) / iconsPerRow)
        local col = (i - 1) % iconsPerRow

        local posX = 30 + col * (iconSize + spacing)
        local posY = -280 - row * (iconSize + spacing + labelHeight + 6)

        iconContainer:SetPoint("TOPLEFT", posX, posY)

        local icon = CreateFrame("Button", nil, iconContainer)
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("BOTTOM", iconContainer, "BOTTOM", 0, 0)

        icon.iconTexture = icon:CreateTexture(nil, "BACKGROUND")
        icon.iconTexture:SetAllPoints()
        icon.iconTexture:SetTexture(cat.icon)

        icon:SetScript("OnClick", function()
            mQoL_Mailbox:AttachItemsByCategory(cat.name)
        end)

        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(cat.name, 1, 1, 1)
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local label = iconContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOM", icon, "TOP", 0, 2)
        label:SetText(cat.name)

        sidePanel.itemIcons[i] = icon
    end
end

function mQoL_Mailbox:UpdateSidePanelVisibility()
    if not self.sidePanel then return end
    
    local shouldShow = SendMailFrame and SendMailFrame:IsShown() and (MailFrameTab2 and MailFrameTab2:IsShown())
    if shouldShow and self.db.enableMailboxSidePanel then
        self.sidePanel:Show()
        if self.ToggleButton then
            self.ToggleButton:SetText("Hide Sidepanel")
            self.ToggleButton:Show()
        end
    else
        self.sidePanel:Hide()
        if self.ToggleButton then
            self.ToggleButton:SetText("Show Sidepanel")
            self.ToggleButton:Hide()
        end
    end
end

function mQoL_Mailbox:CreateToggleButton()
    if self.ToggleButton then return end

    local btn = CreateFrame("Button", nil, SendMailFrame, "UIPanelButtonTemplate")
    btn:SetSize(96, 32)
    btn:SetPoint("TOPRIGHT", SendMailFrame, "TOPRIGHT", -50, 30)
    btn:SetNormalFontObject("GameFontNormalSmall")

	btn:SetScript("OnClick", function()
		if not mQoL_Mailbox.sidePanel then
			mQoL_Mailbox:CreateSidePanel()
		end

		local shown = mQoL_Mailbox.sidePanel:IsShown()
		if shown then
			mQoL_Mailbox.sidePanel:Hide()
			btn:SetText("Show Sidepanel")
			mQoL_Mailbox.db.enableMailboxSidePanel = false
		else
			mQoL_Mailbox.sidePanel:Show()
			btn:SetText("Hide Sidepanel")
			mQoL_Mailbox.db.enableMailboxSidePanel = true
		end
		mQoL_Database:SetSettings("Mailbox", nil, "enableMailboxSidePanel", mQoL_Mailbox.db.enableMailboxSidePanel)
	end)

    self.ToggleButton = btn
end

function mQoL_Mailbox:CreateOptionsPanel(parent)
    if self.optionsPanel then
        return self.optionsPanel
    end

    local panel = CreateFrame("Frame", nil, parent)
    self.optionsPanel = panel
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Quality of Life Settings - Mailbox")
    title:SetTextColor(1, 1, 1)

    -- Separator
    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(1, 1, 1, 0.3)
    separator:SetSize(930, 1)
    separator:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

	local s = self.db
    local profile = self.profile
    profile.altsList = profile.altsList or {}
    profile.friendsList = profile.friendsList or {}
	
	local yOffset = -40
	local spacing = 30

	-- Checkbox helper
	local function CreateCheckbox(label, key)
		local checkbox = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
		checkbox:SetPoint("TOPLEFT", 10, yOffset)
		checkbox:SetChecked(s[key])
		checkbox:SetScript("OnClick", function(self)
			s[key] = self:GetChecked()
			mQoL_Mailbox:ApplySettings()
		end)

		checkbox.label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
		checkbox.label:SetTextColor(1, 0.82, 0)
		checkbox.label:SetText(label)

		yOffset = yOffset - spacing
	end

	-- InputBox helper
	local function CreateInputBox(label, key)
		local container = CreateFrame("Frame", nil, panel)
		container:SetSize(300, 40)
		container:SetPoint("TOPLEFT", 10, yOffset)

		local textLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		textLabel:SetPoint("TOPLEFT", 0, 0)
		textLabel:SetTextColor(1, 0.82, 0)
		textLabel:SetText(label)

		local input = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
		input:SetSize(200, 20)
		input:SetAutoFocus(false)
		input:SetPoint("TOPLEFT", 0, -20)
		input:SetText(s[key] or "")
		input:SetCursorPosition(0)

		input:SetScript("OnEditFocusLost", function(self)
			s[key] = self:GetText():trim()
		end)

		input:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			self:HighlightText(0, 0)
			s[key] = self:GetText():trim()
			mQoL_Database:SetSettings("Mailbox", nil, key, s[key])
			mQoL_Mailbox:ApplySettings()
		end)

		yOffset = yOffset - 50
	end

    -- Editable list helper
    local function CreateEditableList(labelText, key, profileTable, maxEntries, posX, customYOffset)
        local container = CreateFrame("Frame", nil, panel)
        container:SetSize(200, maxEntries * 22 + 40)
        container:SetPoint("TOPLEFT", posX or 10, customYOffset or yOffset)

        local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 0, 0)
        label:SetText(labelText)

        local entryYOffset = -20
        local editboxes = {}

        for i = 1, maxEntries do
            local editbox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
            editbox:SetSize(140, 20)
            editbox:SetAutoFocus(false)
            editbox:SetPoint("TOPLEFT", 0, entryYOffset)
            editbox:SetText(profileTable[key][i] or "")
            editbox:SetCursorPosition(0)

            local function SaveEditboxText(self)
                local text = self:GetText():trim()
                if text ~= "" then
                    profileTable[key][i] = text
                else
                    profileTable[key][i] = nil
                end
            end

            editbox:SetScript("OnEditFocusLost", SaveEditboxText)
            editbox:SetScript("OnEnterPressed", function(self)
                self:ClearFocus()
                self:HighlightText(0, 0)
                SaveEditboxText(self)
                mQoL_Mailbox:ApplySettings()
            end)

            editboxes[i] = editbox
            entryYOffset = entryYOffset - 24
        end

        local applyBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
        applyBtn:SetSize(100, 22)
        applyBtn:SetPoint("TOPLEFT", 0, entryYOffset - 4)
        applyBtn:SetText("Apply")

		applyBtn:SetScript("OnClick", function()
			for i = 1, maxEntries do
				local text = editboxes[i]:GetText():trim()
				if text ~= "" then
					profileTable[key][i] = text
				else
					profileTable[key][i] = nil
				end
				editboxes[i]:ClearFocus()
				editboxes[i]:HighlightText(0, 0)
			end
			-- Zapisanie zmian profilu do DB
			mQoL_Mailbox:SaveProfile()
			mQoL_Mailbox:RefreshRecipientLists()
		end)

        yOffset = yOffset - container:GetHeight() - 5
    end

    -- Panel elements
    CreateCheckbox("Automatically Open Mailbox Side Panel", "enableMailboxSidePanel")
    CreateCheckbox("Enable Gold Summary from Mailbox", "enableGoldSummary")
    CreateInputBox("Auto Mailbox Subject", "autoSubject")

    local baseYOffset = yOffset
    CreateEditableList("Alts List", "altsList", profile, 6, 10, baseYOffset)
    CreateEditableList("Friends List", "friendsList", profile, 6, 200, baseYOffset)

    yOffset = baseYOffset - (6 * 24 + 40 + 10)

    -- Category Debugger
    local ENABLE_DEBUGGER = false -- Change it to true if needed (u can say here item ID and it should return category to with its belongs)
    if ENABLE_DEBUGGER then
        local debugTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        debugTitle:SetPoint("TOPLEFT", 10, yOffset)
        debugTitle:SetText("Item Category Debugger")
        yOffset = yOffset - 20

        local itemIDInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        itemIDInput:SetSize(100, 20)
        itemIDInput:SetAutoFocus(false)
        itemIDInput:SetPoint("TOPLEFT", 10, yOffset)
        itemIDInput:SetNumeric(true)
        itemIDInput:SetMaxLetters(8)

        local checkButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        checkButton:SetSize(80, 22)
        checkButton:SetPoint("LEFT", itemIDInput, "RIGHT", 10, 0)
        checkButton:SetText("Check")

        checkButton:SetScript("OnClick", function()
            local itemID = tonumber(itemIDInput:GetText())
            if not itemID then
                print("|cffff4444[mQoL Mailbox Debugger]|r Invalid itemID.")
                return
            end

            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
                local itemLink = item:GetItemLink()
                if not itemLink then
                    print("|cffff4444[mQoL Mailbox Debugger]|r Failed to load itemID:", itemID)
                    return
                end

                local itemName, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
                print("Debug item:", itemLink)
                print("Type:", itemType or "N/A")
                print("SubType:", itemSubType or "N/A")

                local matchedCategories = {}
                local categoryNames = {
                    "Cloth", "Leather", "Mining", "Cooking", "Herbs",
                    "Elemental", "Gems", "Enchanting", "BoE Gear", "Consumables"
                }

                for _, category in ipairs(categoryNames) do
                    if MatchesCategory(itemLink, category) then
                        table.insert(matchedCategories, category)
                    end
                end

                if #matchedCategories > 0 then
                    print(string.format("|cff00ff00[%s]|r matches categories: %s", itemLink, table.concat(matchedCategories, ", ")))
                else
                    print(string.format("|cffffff00[%s]|r does not match any category.", itemLink))
                end
            end)
        end)

        yOffset = yOffset - 40
    end

    return panel
end

-- Remember Last Recipiant (nice for mass sending)
local lastRecipient = nil

hooksecurefunc("SendMail", function(name, ...)
    if name and name ~= "" then
        lastRecipient = name
    end
end)

-- Event Handler
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    mQoL_Mailbox:InitializeDB()
    mQoL_Mailbox:ApplySettings()
end)

-- Mailbox events
local mailboxFrame = CreateFrame("Frame")
mailboxFrame:RegisterEvent("MAIL_SHOW")
mailboxFrame:RegisterEvent("MAIL_SEND_SUCCESS")
mailboxFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
mailboxFrame:RegisterEvent("MAIL_INBOX_UPDATE")

mailboxFrame:SetScript("OnEvent", function(_, event, ...)
    local db = mQoL_Mailbox.db
    local profile = mQoL_Mailbox.profile
    
    if event == "MAIL_SHOW" then
        mQoL_Mailbox:StartGoldTracking()
        C_Timer.After(0.01, function()
            if MailFrameTab2:IsShown() or MailFrame.tab == 2 then
                mQoL_Mailbox:CreateToggleButton()
                mQoL_Mailbox.ToggleButton:Show()

                if db.enableMailboxSidePanel then
                    mQoL_Mailbox:CreateSidePanel()
                    mQoL_Mailbox:UpdateSidePanelVisibility()
                elseif mQoL_Mailbox.sidePanel then
                    mQoL_Mailbox.sidePanel:Hide()
                    mQoL_Mailbox.ToggleButton:SetText("Show Sidepanel")
                end

                mQoL_Mailbox:RefreshRecipientLists()
            else
                if mQoL_Mailbox.ToggleButton then mQoL_Mailbox.ToggleButton:Hide() end
                if mQoL_Mailbox.sidePanel then mQoL_Mailbox.sidePanel:Hide() end
            end
        end)

        if db.autoSubject and db.autoSubject ~= "" then
            SendMailSubjectEditBox:SetText(db.autoSubject)
        end

    elseif event == "MAIL_SEND_SUCCESS" then
        if db.autoSubject and db.autoSubject ~= "" then
            SendMailSubjectEditBox:SetText(db.autoSubject)
        end
        if lastRecipient and lastRecipient ~= "" then
            SendMailNameEditBox:SetText(lastRecipient)
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if interactionType == Enum.PlayerInteractionType.MailInfo then
            mQoL_Mailbox:EndGoldTracking()
        end
    end
end)

-- Hook for tab change
hooksecurefunc("MailFrameTab_OnClick", function(tab)
    C_Timer.After(0.01, function()
        local db = mQoL_Mailbox.db

        if tab == MailFrameTab2 then
            mQoL_Mailbox:CreateToggleButton()
            mQoL_Mailbox.ToggleButton:Show()

            if db.enableMailboxSidePanel then
                mQoL_Mailbox:CreateSidePanel()
                mQoL_Mailbox:UpdateSidePanelVisibility()
                mQoL_Mailbox:RefreshRecipientLists()
            else
                if mQoL_Mailbox.sidePanel then
                    mQoL_Mailbox.sidePanel:Hide()
                end
                mQoL_Mailbox.ToggleButton:SetText("Show Sidepanel")
            end
        else
            if mQoL_Mailbox.ToggleButton then mQoL_Mailbox.ToggleButton:Hide() end
            if mQoL_Mailbox.sidePanel then mQoL_Mailbox.sidePanel:Hide() end
        end
    end)
end)

-- Register options panel in Hub
if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
    mQoL_Hub:RegisterModuleOptions("mQoL_Mailbox", "Mailbox", function(parent)
        return mQoL_Mailbox:CreateOptionsPanel(parent)
    end)
end