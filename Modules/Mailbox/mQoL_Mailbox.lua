local addonName, L = ...
mQoL_Mailbox = mQoL_Mailbox or {}

-- Check if Hub is Available
local mQoL_Hub = _G["mQoL_Hub"]
if not mQoL_Hub then
    return
end

-- Check Client Version
local clientInfo = mQoL_VersionDetection.clientInfo

-- Styles
local CreateCustomScrollbar = mQoL_Styles and mQoL_Styles.CreateCustomScrollbar
local CreateCustomButton = mQoL_Styles and mQoL_Styles.CreateCustomButton
local CreateCustomDropdown = mQoL_Styles and mQoL_Styles.CreateCustomDropdown
local CreateCustomSlider = mQoL_Styles and mQoL_Styles.CreateCustomSlider
local CreateCustomInputBox = mQoL_Styles and mQoL_Styles.CreateCustomInputBox
local CreateCustomCheckbox = mQoL_Styles and mQoL_Styles.CreateCustomCheckbox
local CreateFrameBorder = mQoL_Templates and mQoL_Templates.CreateFrameBorder

mQoL_Mailbox.goldBefore = nil
local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000

-- Default Settings -- DO NOT STORE HERE BLIZZARD SETTINGS ONLY FOR CUSTOM FUNCTIONS (Defaults are stored in FirstSetup)
mQoL_Mailbox.defaults = {
    enableMailboxSidePanel = false,
    enableGoldSummary = false,
    autoSubject = "",
}

mQoL_Mailbox.profileDefaults = {
    altsList = {},
    guildList = {},
    friendsList = {},
    lastRecipient = "",
}

-- Ensure global DB exists
mQoL_Mailbox_DB = mQoL_Mailbox_DB or {}

-- Deep copy helper
local function TableCopy(src)
    local dest = {}
    for k, v in pairs(src) do
        if type(v) == "table" then dest[k] = TableCopy(v) else dest[k] = v end
    end
    return dest
end

-- Get server and faction for profile key
local function GetServerAndFaction()
    local realm = GetRealmName() or "UnknownRealm"
    realm = realm:gsub("%s", "")
    local faction = UnitFactionGroup("player") or "Neutral"
    return realm, faction
end

local function GetProfileKeyForClient(realm, faction)
    if clientInfo.isRetail then
        return realm
    end
    return realm .. "-" .. faction
end

local function NormalizeRecipientName(name)
    if type(name) ~= "string" then return nil end
    local trimmed = string.trim and string.trim(name) or name:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return nil end
    return trimmed
end

local function MergeUniqueRecipientLists(...)
    local merged = {}
    local seen = {}

    for i = 1, select("#", ...) do
        local list = select(i, ...)
        if type(list) == "table" then
            for _, name in ipairs(list) do
                local normalized = NormalizeRecipientName(name)
                if normalized then
                    local dedupeKey = normalized:lower()
                    if not seen[dedupeKey] then
                        seen[dedupeKey] = true
                        table.insert(merged, normalized)
                    end
                end
            end
        end
    end

    return merged
end

local function MigrateRetailFactionProfiles(accountDB)
    if not (clientInfo and clientInfo.isRetail) then return false end
    if not accountDB or type(accountDB.profiles) ~= "table" then return false end

    local groupedByRealm = {}
    local legacyKeys = {}

    for profileKey, profileData in pairs(accountDB.profiles) do
        if type(profileKey) == "string" and type(profileData) == "table" then
            local realm, faction = profileKey:match("^(.-)%-(Horde)$")
            if not realm then
                realm, faction = profileKey:match("^(.-)%-(Alliance)$")
            end

            if realm and faction then
                groupedByRealm[realm] = groupedByRealm[realm] or {}
                groupedByRealm[realm][faction] = profileData
                table.insert(legacyKeys, profileKey)
            end
        end
    end

    if next(groupedByRealm) == nil then
        return false
    end

    for realm, factionProfiles in pairs(groupedByRealm) do
        local baseProfile = accountDB.profiles[realm]
        if type(baseProfile) ~= "table" then
            baseProfile = TableCopy(mQoL_Mailbox.profileDefaults)
            accountDB.profiles[realm] = baseProfile
        end

        local hordeProfile = factionProfiles.Horde
        local allianceProfile = factionProfiles.Alliance

        baseProfile.altsList = MergeUniqueRecipientLists(
            baseProfile.altsList,
            hordeProfile and hordeProfile.altsList,
            allianceProfile and allianceProfile.altsList
        )
        baseProfile.guildList = MergeUniqueRecipientLists(
            baseProfile.guildList,
            hordeProfile and hordeProfile.guildList,
            allianceProfile and allianceProfile.guildList
        )
        baseProfile.friendsList = MergeUniqueRecipientLists(
            baseProfile.friendsList,
            hordeProfile and hordeProfile.friendsList,
            allianceProfile and allianceProfile.friendsList
        )

        if not NormalizeRecipientName(baseProfile.lastRecipient) then
            baseProfile.lastRecipient = NormalizeRecipientName(
                (hordeProfile and hordeProfile.lastRecipient) or
                (allianceProfile and allianceProfile.lastRecipient)
            ) or ""
        end
    end

    for _, legacyKey in ipairs(legacyKeys) do
        accountDB.profiles[legacyKey] = nil
    end

    return true
end

-- Get mailbox database (handles migration from old format)
local function GetMailboxDB()
    mQoL_Mailbox_DB = mQoL_Mailbox_DB or {}

    -- Ensure Account exists
    if not mQoL_Mailbox_DB["Account"] then
        mQoL_Mailbox_DB["Account"] = {
            settings = TableCopy(mQoL_Mailbox.defaults),
            profiles = {}
        }
    end

    local accountDB = mQoL_Mailbox_DB["Account"]

    -- Ensure settings structure exists
    if not accountDB.settings then
        accountDB.settings = TableCopy(mQoL_Mailbox.defaults)
    end
    if not accountDB.profiles then
        accountDB.profiles = {}
    end

    -- Ensure all default settings exist
    for key, defaultValue in pairs(mQoL_Mailbox.defaults) do
        if accountDB.settings[key] == nil then
            accountDB.settings[key] = defaultValue
        end
    end

    -- Migration from old mQoL_DB["Mailbox"] (if exists) (its changed for better db structure)
    if mQoL_DB and mQoL_DB["Mailbox"] then
        local oldData = mQoL_DB["Mailbox"]

        -- Migrate settings
        if oldData.settings then
            for key, value in pairs(oldData.settings) do
                if accountDB.settings[key] == nil or accountDB.settings[key] == mQoL_Mailbox.defaults[key] then
                    accountDB.settings[key] = value
                end
            end
        end

        -- Migrate profiles
        if oldData.profiles then
            for profileKey, profileData in pairs(oldData.profiles) do
                if not accountDB.profiles[profileKey] then
                    accountDB.profiles[profileKey] = profileData
                end
            end
        end

        -- Remove old data
        mQoL_DB["Mailbox"] = nil
        print("|cff00ff00[mQoL Mailbox]|r Migrated data to new database format.")
    end

    if MigrateRetailFactionProfiles(accountDB) then
        print("|cff00ff00[mQoL Mailbox]|r Migrated Retail profiles from Realm-Faction to Realm.")
    end

    return accountDB
end

-- Initialize database
function mQoL_Mailbox:InitializeDB()
    local accountDB = GetMailboxDB()
    self.db = { settings = accountDB.settings }

    -- Get/create profile for current server/faction format (Retail uses realm-only key)
    local realm, faction = GetServerAndFaction()
    local profileKey = GetProfileKeyForClient(realm, faction)

    if not accountDB.profiles[profileKey] then
        accountDB.profiles[profileKey] = TableCopy(self.profileDefaults)
    end

    -- Ensure all profile defaults exist
    local profile = accountDB.profiles[profileKey]
    for key, defaultValue in pairs(self.profileDefaults) do
        if profile[key] == nil then
            profile[key] = type(defaultValue) == "table" and TableCopy(defaultValue) or defaultValue
        end
    end

    self.profile = profile
end

function mQoL_Mailbox:ApplySettings()
    local s = self.db and self.db.settings or {}
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
                    if CreateCustomButton then
                        btn = CreateCustomButton(container, "", 114, 20)
                    elseif mQoL_Templates and mQoL_Templates.CreateButton then
                        btn = mQoL_Templates.CreateButton(container, "", 114, 20)
                    else
                        btn = CreateFrame("Button", nil, container)
                        btn:SetSize(114, 20)
                    end
                    btn:SetScript("OnClick", function(self)
                        SendMailNameEditBox:SetText(self.text and self.text:GetText() or self:GetText())
                    end)
                    container.recipientButtons[i] = btn
                end

                if btn.text then
                    btn.text:SetText(name)
                else
                    btn:SetText(name)
                end

                btn:ClearAllPoints()
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
    RefreshContainer(self.sidePanel.guildContainer, profile.guildList)
    RefreshContainer(self.sidePanel.friendsContainer, profile.friendsList)
end

-- Gold Tracking
function mQoL_Mailbox:StartGoldTracking()
    local s = self.db and self.db.settings or {}
    if not s.enableGoldSummary then
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
    local s = self.db and self.db.settings or {}
    if not s.enableGoldSummary then return end
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

    if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC then
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
        if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC then
            slots = C_Container.GetContainerNumSlots(bag)
        else
            slots = GetContainerNumSlots(bag)
        end

        for slot = 1, slots do
            local item
            if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC then
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
        if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC then
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
            if clientInfo.isRetail or clientInfo.isClassic or clientInfo.isEra or clientInfo.isBCC then
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
    return GetProfileKeyForClient(realm, faction)
end

string.trim = string.trim or function(s)
    return s:match("^%s*(.-)%s*$")
end

function mQoL_Mailbox:CreateSidePanel()
    if self.sidePanel then return end
    if not MailFrame then
        return
    end

    self.sidePanel = CreateFrame("Frame", addonName .. "MailboxSidePanel", MailFrame)
	local sidePanel = self.sidePanel
    sidePanel:SetSize(420, 420)
    sidePanel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 10, 0)
    sidePanel:EnableMouse(true)
    sidePanel:Hide()

    -- Background
    sidePanel.bg = sidePanel:CreateTexture(nil, "BACKGROUND")
    sidePanel.bg:SetAllPoints()
    sidePanel.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)

    -- Border
    if CreateFrameBorder then
        sidePanel.border = CreateFrameBorder(sidePanel, 1, {0.2, 0.2, 0.2, 1})
    end

    -- Close Button
    sidePanel.closeBtn = CreateFrame("Button", nil, sidePanel)
    sidePanel.closeBtn:SetSize(20, 20)
    sidePanel.closeBtn:SetPoint("TOPRIGHT", sidePanel, "TOPRIGHT", -5, -5)
    sidePanel.closeBtn.text = sidePanel.closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sidePanel.closeBtn.text:SetPoint("CENTER")
    sidePanel.closeBtn.text:SetText("X")
    sidePanel.closeBtn.text:SetTextColor(1, 0.2, 0.2)
    sidePanel.closeBtn:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.4, 0.4) end)
    sidePanel.closeBtn:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 0.2, 0.2) end)
    sidePanel.closeBtn:SetScript("OnClick", function() mQoL_Mailbox.sidePanel:Hide() end)

    -- Title
    sidePanel.title = sidePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sidePanel.title:SetPoint("TOP", 0, -10)
    sidePanel.title:SetText("mQoL Mailbox")
    sidePanel.title:SetTextColor(1, 0.82, 0)

    local listWidth, listHeight = 124, 150
    local listSpacing = 10
    local startX = 14

	local function CreateRecipientListContainer(posX, title)
		local container = CreateFrame("Frame", nil, sidePanel)
		container:SetSize(listWidth, listHeight)
		container:SetPoint("TOPLEFT", posX, -50)

        -- Container Background
        container.bg = container:CreateTexture(nil, "BACKGROUND")
        container.bg:SetAllPoints()
        container.bg:SetColorTexture(0.12, 0.12, 0.12, 1)

        -- Container Border
        if CreateFrameBorder then
            container.border = CreateFrameBorder(container, 1, {0.3, 0.3, 0.3, 1})
        end

		container.label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		container.label:SetPoint("TOP", 0, -6)
		container.label:SetText(title)
        container.label:SetTextColor(0.8, 0.8, 0.8)

		-- Offset for first button in table
		container.firstButtonYOffset = -25

		return container
	end

    self.sidePanel.altsContainer    = CreateRecipientListContainer(startX + 0 * (listWidth + listSpacing), "Alts")
    self.sidePanel.guildContainer   = CreateRecipientListContainer(startX + 1 * (listWidth + listSpacing), "Guild")
    self.sidePanel.friendsContainer = CreateRecipientListContainer(startX + 2 * (listWidth + listSpacing), "Friends")

    -- Separator
    local separator = sidePanel:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    separator:SetSize(390, 1)
    separator:SetPoint("TOPLEFT", 15, -220)

    -- Quick Send
    local massTitle = sidePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    massTitle:SetPoint("TOPLEFT", 15, -230)
    massTitle:SetText("Quick Send")
    massTitle:SetTextColor(1, 0.82, 0)

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
    local spacing = 35
    local labelHeight = 12
    local iconsPerRow = 5

    for i, cat in ipairs(itemCategories) do
        local iconContainer = CreateFrame("Frame", nil, sidePanel)
        iconContainer:SetSize(iconSize, iconSize + labelHeight)

        local row = math.floor((i - 1) / iconsPerRow)
        local col = (i - 1) % iconsPerRow

        local posX = 60 + col * (iconSize + spacing)
        local posY = -260 - row * (iconSize + spacing + labelHeight + 6)

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
    local s = self.db and self.db.settings or {}
    if shouldShow and s.enableMailboxSidePanel then
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

    -- Create button for opening/closing side panel
    local btn = CreateFrame("Button", nil, MailFrame)
    btn:SetSize(60, 20) -- Compact size
    
    -- Position Left of main mailbox title frame
    local titleRegion = MailFrame.TitleText or MailFrameTitleText
    if titleRegion then
        btn:SetPoint("RIGHT", titleRegion, "LEFT", 60, 0)
    else
        -- Fallback if title text not found
        btn:SetPoint("TOP", MailFrame, "TOP", -60, 0)
    end
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(100)

    -- Background (Dark/Flat style)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    btn.bg = bg

    -- Add a border for better visibility
    if mQoL_Templates and mQoL_Templates.SetBackdrop then
        mQoL_Templates.SetBackdrop(btn, {
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        }, nil, {0.4, 0.4, 0.4, 1})
    end

    -- Text
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetText("mQoL")
    btn.text:SetTextColor(0.9, 0.9, 0.9)

    -- Scripts (Hover & Click)
    btn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
        self.text:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
        self.text:SetTextColor(0.9, 0.9, 0.9)
    end)

    btn:SetScript("OnClick", function()
        if not mQoL_Mailbox.sidePanel then
            mQoL_Mailbox:CreateSidePanel()
        end

        local shown = mQoL_Mailbox.sidePanel:IsShown()
        local s = mQoL_Mailbox.db and mQoL_Mailbox.db.settings or {}
        if shown then
            mQoL_Mailbox.sidePanel:Hide()
            s.enableMailboxSidePanel = false
            btn.text:SetTextColor(0.9, 0.9, 0.9)
        else
            mQoL_Mailbox.sidePanel:Show()
            s.enableMailboxSidePanel = true
            btn.text:SetTextColor(1, 0.82, 0) -- Active color
        end
    end)

    self.ToggleButton = btn
end

function mQoL_Mailbox:CreateOptionsPanel(parent)
    if self.optionsScrollFrame then
        self.optionsScrollFrame:SetParent(parent)
        self.optionsScrollFrame:ClearAllPoints()
        self.optionsScrollFrame:SetAllPoints()
        return self.optionsScrollFrame
    end

    if not self.db or not self.profile then
        self:InitializeDB()
    end

    local scrollFrame, panel, contentContainer = mQoL_Templates.CreateStandardOptionsPanel(parent, "Quality of Life Settings - Mailbox", {
        text = "How Mailbox Enhancement works?",
        textColor = {1, 0.82, 0},
        explanation = "Enhance your mailbox with quick sending and character lists.\n\n• Auto Mailbox Subject allows you to quickly send mail without typing a subject.\n• Track gold collected from the mailbox.\n• For now, the character list can only be filled manually, but in the future, it will be filled automatically.",
        explanationColor = {1, 1, 1},
        width = 770,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        animDuration = 0.25
    }, "MainSeparator")

    self.optionsScrollFrame = scrollFrame

    local AddGap = mQoL_Templates.AddGap

	local s = self.db and self.db.settings or {}
    local profile = self.profile
    profile.altsList = profile.altsList or {}
    profile.friendsList = profile.friendsList or {}
	
    -- Checkbox: Automatically Open Mailbox Side Panel
    mQoL_Hub:AddOptionRow(contentContainer, "Auto Open Mailbox Side Panel", "checkbox", {
        value = s.enableMailboxSidePanel,
        onValueChanged = function(self, value)
            s.enableMailboxSidePanel = value
            mQoL_Mailbox:ApplySettings()
        end
    })
    AddGap(contentContainer, "Standard")

    -- Checkbox: Enable Gold Summary from Mailbox
    mQoL_Hub:AddOptionRow(contentContainer, "Enable Gold Summary from Mailbox", "checkbox", {
        value = s.enableGoldSummary,
        onValueChanged = function(self, value)
            s.enableGoldSummary = value
            mQoL_Mailbox:ApplySettings()
        end
    })
    AddGap(contentContainer, "Standard")
    AddGap(contentContainer, "BottomSeparator")

    -- InputBox: Auto Mailbox Subject
    mQoL_Hub:AddOptionRow(contentContainer, "Auto Mailbox Subject", "inputbox", {
        text = s.autoSubject,
        width = 350,
        onEnterPressed = function(self)
             local text = self:GetText():trim()
             s.autoSubject = text
             mQoL_Mailbox:ApplySettings()
        end
    }, nil, function() end) -- Pass dummy function to enable Apply button
    AddGap(contentContainer, "Standard")

    -- Separator before lists
    AddGap(contentContainer, "BottomSeparator")

    -- Custom Side-by-Side Lists Section
    local function CreateListColumn(parent, xOffset, yOffset, title, listData)
        local maxEntries = 6
        local entryHeight = 22
        local entrySpacing = 3
        local width = 200

        -- Title
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", xOffset, yOffset)
        label:SetText(title)
        label:SetTextColor(1, 0.82, 0)

        parent.optionsLabels = parent.optionsLabels or {}
        parent.optionsLabels[title] = label

        local currentListY = yOffset - 25

        -- Container for editboxes to easily iterate
        local listContainer = CreateFrame("Frame", nil, parent)
        listContainer:SetPoint("TOPLEFT", xOffset, currentListY)
        listContainer:SetSize(width, maxEntries * (entryHeight + entrySpacing))

        local editboxes = {}
        for i = 1, maxEntries do
            local editbox = CreateCustomInputBox(listContainer, width, entryHeight, nil)
            editbox:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, -((i-1)*(entryHeight + entrySpacing)))
            editbox:SetText(listData[i] or "")

            editboxes[i] = editbox
        end

        currentListY = currentListY - (maxEntries * (entryHeight + entrySpacing))

        -- Save Button
        local saveBtn = CreateCustomButton(parent, "Save", 100, 22)
        saveBtn:SetPoint("TOPLEFT", xOffset, currentListY - 5)
        saveBtn:SetScript("OnClick", function()
            -- Update listData from editboxes
            for i, box in ipairs(editboxes) do
                local text = box:GetText():trim()
                if text ~= "" then
                    listData[i] = text
                else
                    listData[i] = nil
                end
            end

            mQoL_Mailbox:RefreshRecipientLists()
        end)

        return math.abs(currentListY - 5 - 22 - yOffset) -- Return total height used
    end

    -- Render Alts List (Left)
    local altsHeight = CreateListColumn(contentContainer, 20, contentContainer.currentY, "Alts List", profile.altsList)
    
    -- Render Guild List (Middle)
    CreateListColumn(contentContainer, 280, contentContainer.currentY, "Guild List", profile.guildList)

    -- Render Friends List (Right) - Offset by 260 pixels (280 + 200 + 60 spacing)
    CreateListColumn(contentContainer, 540, contentContainer.currentY, "Friends List", profile.friendsList)

    -- Update Y for next elements
    contentContainer.currentY = contentContainer.currentY - altsHeight - 20

    panel.UpdateScrollChildHeight = function()
        mQoL_Templates.UpdateScrollChildHeight(scrollFrame, panel, contentContainer)
    end
    panel.UpdateScrollChildHeight()

    return scrollFrame
end

-- Remember Last Recipiant (nice for mass sending dont need fill recipiant again)
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
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("Mailbox") then return end
    mQoL_Mailbox:InitializeDB()
    mQoL_Mailbox:ApplySettings()

    if mQoL_Hub and mQoL_Hub.RegisterModuleOptions then
        mQoL_Hub:RegisterModuleOptions("mQoL_Mailbox", "Mailbox", function(parent)
            return mQoL_Mailbox:CreateOptionsPanel(parent)
        end)
    end
end)

-- Mailbox events
local mailboxFrame = CreateFrame("Frame")
mailboxFrame:RegisterEvent("MAIL_SHOW")
mailboxFrame:RegisterEvent("MAIL_SEND_SUCCESS")
mailboxFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
mailboxFrame:RegisterEvent("MAIL_INBOX_UPDATE")

mailboxFrame:SetScript("OnEvent", function(_, event, ...)
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("Mailbox") then return end
    local s = mQoL_Mailbox.db and mQoL_Mailbox.db.settings or {}
    local profile = mQoL_Mailbox.profile

    if event == "MAIL_SHOW" then
        mQoL_Mailbox:StartGoldTracking()
        C_Timer.After(0.01, function()
            if MailFrameTab2:IsShown() or MailFrame.tab == 2 then
                mQoL_Mailbox:CreateToggleButton()
                mQoL_Mailbox.ToggleButton:Show()

                if s.enableMailboxSidePanel then
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

        if s.autoSubject and s.autoSubject ~= "" then
            SendMailSubjectEditBox:SetText(s.autoSubject)
        end

    elseif event == "MAIL_SEND_SUCCESS" then
        if s.autoSubject and s.autoSubject ~= "" then
            SendMailSubjectEditBox:SetText(s.autoSubject)
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
        if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("Mailbox") then return end
        local s = mQoL_Mailbox.db and mQoL_Mailbox.db.settings or {}

        if tab == MailFrameTab2 then
            mQoL_Mailbox:CreateToggleButton()
            mQoL_Mailbox.ToggleButton:Show()

            if s.enableMailboxSidePanel then
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
