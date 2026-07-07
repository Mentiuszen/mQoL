local addonName = ...

local function ShouldLoadBlizzardFixes()
    return not (mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes"))
end

-- better consolidated buffs display
local RAID_BUFFS = {
    { name = "Attack Power", icon = 6673, spells = {57330, 19506, 6673} },
    { name = "Crit Chance", icon = 1459, spells = {17007, 90309, 1459, 116781, 126309, 24604} },
    { name = "Mastery", icon = 19740, spells = {93435, 19740, 116956, 128997} },
    { name = "Physical Haste", icon = 55610, spells = {55610, 128432, 113742, 30809, 128433} },
    { name = "Spell Haste", icon = 24907, spells = {24907, 49868, 15473, 51470} },
    { name = "Spell Power", icon = 1459, spells = {126309, 1459, 77747, 109773, 61316} },
    { name = "Stamina", icon = 21562, spells = {90364, 21562, 109773, 469, 72590, 96175, 111923} },
    { name = "Stats", icon = 1126, spells = {1126, 90363, 115921, 20217, 72586, 117666} },
}

-- CONFIG
local FONT_PATH = "Fonts\\FRIZQT__.TTF"
local BASE_FONT_SIZE = 12
local INFINITE_FONT_SIZE = BASE_FONT_SIZE + 9
local UPDATE_INTERVAL = 0.5

-- SAFE API WRAPPERS
local function GetSpellTexture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    elseif _G.GetSpellTexture then
        return _G.GetSpellTexture(spellID)
    end
    return nil
end

local function GetUnitBuff(unitToken, index)
    if UnitBuff then
        return UnitBuff(unitToken, index)
    elseif C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        local auraData = C_UnitAuras.GetBuffDataByIndex(unitToken, index)
        if auraData then
            if AuraUtil and AuraUtil.UnpackAuraData then
                return AuraUtil.UnpackAuraData(auraData)
            else
                return auraData.name, auraData.icon, auraData.applications, auraData.dispelName, auraData.duration, auraData.expirationTime, auraData.sourceUnit, auraData.isStealable, auraData.nameplateShowPersonal, auraData.spellId, auraData.canApplyAura, auraData.isBossAura, auraData.castByPlayer, auraData.nameplateShowAll, auraData.timeMod
            end
        end
    end
    return nil
end


-- BUFF FRAME CREATION
local function CreateBuffFrame(parent, category, size)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    frame:EnableMouse(true)

    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(GetSpellTexture(category.icon))
    frame.icon = icon

    -- Label
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    label:SetText(category.name)
    frame.text = label

    -- Timer
    local timer = frame:CreateFontString(nil, "OVERLAY")
    timer:SetFont(FONT_PATH, BASE_FONT_SIZE, "OUTLINE")
    timer:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    timer:SetText("")
    frame.timer = timer

    return frame
end

-- BUFF CHECK FUNCTION
local function GetCategoryBuffInfo(category)
    local i = 1
    while true do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId = GetUnitBuff("player", i)
        if not name then break end
        for _, id in ipairs(category.spells) do
            if spellId == id then
                local remaining = 0
                local infinite = false
                if expirationTime and type(expirationTime) == "number" and expirationTime > 0 then
                    remaining = expirationTime - GetTime()
                    if remaining < 0 then remaining = 0 end
                elseif duration == 0 or not duration or expirationTime == 0 then
                    infinite = true
                end
                return true, GetSpellTexture(spellId), remaining, infinite, i, name, spellId
            end
        end
        i = i + 1
    end
    return false, GetSpellTexture(category.icon), 0, false, nil, nil, nil
end

local function InitConsolidatedBuffs()
    if mQoL_DB and mQoL_DB.BlizzardFixes and mQoL_DB.BlizzardFixes.fixConsolidatedBuffs == false then return end
    local ConsolidatedBuffs = BuffFrame and BuffFrame.ConsolidatedBuffs
    if not ConsolidatedBuffs then return end

    local baseIconSize = 32
    local iconSize = baseIconSize * 1.1
    local spacing = 32
    local paddingTop = 30
    local paddingLeft = 20
    local textHeight = 18
    local rows = 2
    local cols = 4

    local contentWidth = cols * iconSize + (cols - 1) * spacing
    local contentHeight = rows * iconSize + (rows - 1) * spacing + textHeight * 2

    local tooltipWidth = (contentWidth + paddingLeft * 2) * 1.1
    local tooltipHeight = contentHeight + paddingTop + 12

    local tooltip = _G.mQoLConsolidatedTooltip
    if not tooltip then
        tooltip = CreateFrame("Frame", "mQoLConsolidatedTooltip", UIParent)
        tooltip:SetSize(tooltipWidth, tooltipHeight)
        tooltip:SetFrameStrata("DIALOG")
        tooltip:SetPoint("TOPRIGHT", ConsolidatedBuffs, "BOTTOMLEFT", 0, 0)
        tooltip:Hide()

        if mQoL_Templates and mQoL_Templates.SetBackdrop then
            mQoL_Templates.SetBackdrop(tooltip, {
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 2,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            }, {0, 0, 0, 0.55}, {0.35, 0.35, 0.35, 0.9})
        end
    else
        tooltip:SetSize(tooltipWidth, tooltipHeight)
        tooltip:ClearAllPoints()
        tooltip:SetPoint("TOPRIGHT", ConsolidatedBuffs, "BOTTOMLEFT", 0, 0)
    end

    tooltip:SetFrameLevel(ConsolidatedBuffs:GetFrameLevel() + 2)
    tooltip.buffs = tooltip.buffs or {}

    local function UpdateBuffDisplay()
        local anyActive = false
        for i, category in ipairs(RAID_BUFFS) do
            local active, texture, remaining, infinite = GetCategoryBuffInfo(category)
            local frame = tooltip.buffs[i]

            if frame then
                frame.icon:SetTexture(texture or GetSpellTexture(category.icon))
                frame.icon:SetDesaturated(not active)

                if active then
                    anyActive = true
                    if infinite then
                        frame.timer:SetFont(FONT_PATH, INFINITE_FONT_SIZE, "OUTLINE")
                        frame.timer:SetText("∞")
                        frame.timer:ClearAllPoints()
                        frame.timer:SetPoint("TOP", frame, "BOTTOM", 0, 0)
                    elseif remaining and remaining > 0 then
                        frame.timer:SetFont(FONT_PATH, BASE_FONT_SIZE, "OUTLINE")
                        frame.timer:SetTextColor(1, 1, 1)
                        frame.timer:ClearAllPoints()
                        frame.timer:SetPoint("TOP", frame, "BOTTOM", 0, -4)

                        if remaining < 60 then
                            frame.timer:SetText(math.floor(remaining) .. "s")
                        elseif remaining < 3600 then
                            frame.timer:SetText(math.floor(remaining / 60) .. "m")
                        else
                            frame.timer:SetText(math.floor(remaining / 3600) .. "h")
                        end
                    else
                        frame.timer:SetFont(FONT_PATH, BASE_FONT_SIZE, "OUTLINE")
                        frame.timer:SetText("—")
                        frame.timer:SetTextColor(1, 1, 1)
                        frame.timer:ClearAllPoints()
                        frame.timer:SetPoint("TOP", frame, "BOTTOM", 0, -4)
                    end
                else
                    frame.timer:SetFont(FONT_PATH, BASE_FONT_SIZE, "OUTLINE")
                    frame.timer:SetText("—")
                    frame.timer:SetTextColor(1, 1, 1)
                    frame.timer:ClearAllPoints()
                    frame.timer:SetPoint("TOP", frame, "BOTTOM", 0, -4)
                end
            end
        end

        if not anyActive then
            tooltip:Hide()
        end

        return anyActive
    end

    tooltip.UpdateBuffDisplay = UpdateBuffDisplay

    if not tooltip.__mQoLBuffsCreated then
        local offsetX = (tooltipWidth - contentWidth) / 2
        local offsetY = -paddingTop

        for i, category in ipairs(RAID_BUFFS) do
            local row = math.floor((i - 1) / cols) + 1
            local col = ((i - 1) % cols) + 1

            local frame = CreateBuffFrame(tooltip, category, iconSize)
            tooltip.buffs[i] = frame

            local rowOffset = (row - 1) * (iconSize + spacing + textHeight)
            if row == 2 then
                rowOffset = rowOffset - 6
            end

            frame:SetPoint("TOPLEFT", tooltip, "TOPLEFT",
                offsetX + (col - 1) * (iconSize + spacing),
                offsetY - rowOffset
            )

            frame.category = category

            frame:SetScript("OnEnter", function(self)
                local active, _, _, _, auraIndex = GetCategoryBuffInfo(self.category)
                if active and auraIndex then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetUnitAura("player", auraIndex, "HELPFUL")
                    GameTooltip:Show()
                else
                    GameTooltip:Hide()
                end
            end)

            frame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            frame:SetScript("OnMouseUp", function(self, button)
                if button ~= "RightButton" then return end
                local active, _, _, infinite, auraIndex = GetCategoryBuffInfo(self.category)
                if not (active and auraIndex) then return end
                if infinite then return end

                if CancelUnitBuff then
                    CancelUnitBuff("player", auraIndex)
                elseif CancelUnitAura then
                    CancelUnitAura("player", auraIndex)
                end
                GameTooltip:Hide()
                tooltip.UpdateBuffDisplay()
            end)
        end

        tooltip.__mQoLBuffsCreated = true
        
        -- Only update when mouse is over the tooltip
        tooltip.elapsedSinceUpdate = 0
        tooltip:SetScript("OnUpdate", function(self, elapsed)
            self.elapsedSinceUpdate = self.elapsedSinceUpdate + elapsed
            if self.elapsedSinceUpdate >= UPDATE_INTERVAL then
                self.UpdateBuffDisplay()
                self.elapsedSinceUpdate = 0
            end
        end)
    end

    local function IsConsolidatedTooltipOwner(frame)
        if not frame then return false end
        if frame == ConsolidatedBuffs or frame == tooltip then
            return true
        end
        local p = frame
        while p do
            if p == tooltip then
                return true
            end
            p = p:GetParent()
        end
        return false
    end

    local function HideGameTooltipIfOwnedByConsolidated()
        if not GameTooltip or not GameTooltip.GetOwner then return end
        local owner = GameTooltip:GetOwner()
        if IsConsolidatedTooltipOwner(owner) then
            GameTooltip:Hide()
        end
    end

    local function ScheduleConsolidatedTooltipHide()
        if not C_Timer or not C_Timer.After then
            if not ConsolidatedBuffs:IsMouseOver() and not tooltip:IsMouseOver() then
                tooltip:Hide()
                HideGameTooltipIfOwnedByConsolidated()
            end
            return
        end

        C_Timer.After(0.2, function()
            if not ConsolidatedBuffs:IsMouseOver() and not tooltip:IsMouseOver() then
                tooltip:Hide()
                HideGameTooltipIfOwnedByConsolidated()
            end
        end)
    end

    ConsolidatedBuffs:SetScript("OnEnter", function()
        GameTooltip:Hide()
        local hasBuffs = tooltip.UpdateBuffDisplay()
        if hasBuffs then
            tooltip:Show()
        else
            tooltip:Hide()
        end
    end)

    ConsolidatedBuffs:SetScript("OnLeave", function()
        ScheduleConsolidatedTooltipHide()
    end)

    tooltip:SetScript("OnEnter", function()
        tooltip:Show()
    end)
    tooltip:SetScript("OnLeave", function()
        ScheduleConsolidatedTooltipHide()
    end)

    if ConsolidatedBuffsTooltip then
        ConsolidatedBuffsTooltip:UnregisterAllEvents()
        ConsolidatedBuffsTooltip:Hide()
    end

    -- Override UpdateAuras on BuffFrame
    if BuffFrame then
        local function GetSpellIdForBuffIndex(index)
            if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
                local auraData = C_UnitAuras.GetBuffDataByIndex("player", index)
                return auraData and auraData.spellId
            elseif UnitBuff then
                local _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", index)
                return spellId
            end
            return nil
        end

        local function NewUpdateAuras(self)
            if AuraFrameEditModeMixin and AuraFrameEditModeMixin.UpdateAuras then
                AuraFrameEditModeMixin.UpdateAuras(self)
            end

            self.numHideableBuffs = 0
            if self.UpdateTemporaryEnchantmentBuffs then
                self:UpdateTemporaryEnchantmentBuffs(GetWeaponEnchantInfo())
            end
            if self.UpdatePlayerBuffs then
                self:UpdatePlayerBuffs()
            end

            local numHideable = 0
            if self.auraInfo then
                for _, info in ipairs(self.auraInfo) do
                    local isRaidBuff = false
                    if info.auraType == "Buff" and info.index then
                        local spellId = GetSpellIdForBuffIndex(info.index)
                        if spellId then
                            for _, category in ipairs(RAID_BUFFS) do
                                for _, id in ipairs(category.spells) do
                                    if spellId == id then
                                        isRaidBuff = true
                                        break
                                    end
                                end
                                if isRaidBuff then break end
                            end
                        end
                    end

                    if isRaidBuff then
                        info.hideUnlessExpanded = true
                        numHideable = numHideable + 1
                    else
                        info.hideUnlessExpanded = false
                    end
                end
            end
            self.numHideableBuffs = numHideable

            if self.SyncToConsolidatedBuffs then
                self:SyncToConsolidatedBuffs()
            end

            local onUpdateScript = (self.HasHiddenBuffs and self:HasHiddenBuffs()) and self.OnUpdate or nil
            self:SetScript("OnUpdate", onUpdateScript)
            if self.ResetHiddenBuffUpdateTimer then
                self:ResetHiddenBuffUpdateTimer()
            end
        end

        BuffFrame.UpdateAuras = NewUpdateAuras

        if BuffFrame.Update then
            BuffFrame:Update()
        end
    end
end

local f_buffs = CreateFrame("Frame")
f_buffs:RegisterEvent("PLAYER_ENTERING_WORLD")
f_buffs:SetScript("OnEvent", function()
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    InitConsolidatedBuffs()
    f_buffs:UnregisterAllEvents()
end)

-- Fix for corpse texture on map
local CorpseFix = CreateFrame("Frame")
CorpseFix:RegisterEvent("PLAYER_ENTERING_WORLD")

local function FixCorpseTexture()
    if not WorldMapFrame then return end
    
    for pin in WorldMapFrame:EnumeratePinsByTemplate("CorpsePinTemplate") do
        local regions = {pin:GetRegions()}
        for i, region in ipairs(regions) do
            if region:GetObjectType() == "Texture" then
                region:SetTexCoord(0.5625, 0.632812, 0.0, 0.035156)
            end
        end
    end
end

CorpseFix:SetScript("OnEvent", function()
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    if mQoL_DB and mQoL_DB.BlizzardFixes and mQoL_DB.BlizzardFixes.fixCorpseMap == false then return end
    local originalAcquire = WorldMapFrame.AcquirePin
    WorldMapFrame.AcquirePin = function(self, template, ...)
        local pin = originalAcquire(self, template, ...)
        if template == "CorpsePinTemplate" then
            C_Timer.After(0.05, FixCorpseTexture)
        end
        return pin
    end
    hooksecurefunc(WorldMapFrame, "OnShow", FixCorpseTexture)
    hooksecurefunc(WorldMapFrame, "OnMapChanged", FixCorpseTexture)
    C_Timer.After(1, FixCorpseTexture)
end)

-- Fix Raid Minimap Difficulty
local function GetFixedInstanceGroupSize()
    local _, instanceType, _, _, maxPlayers, _, _, _, instanceGroupSize = GetInstanceInfo()

    if instanceType == "raid" and (instanceGroupSize == nil or instanceGroupSize == 0) then
        return maxPlayers
    end

    if IS_GUILD_GROUP and (instanceGroupSize == nil or instanceGroupSize == 0) then
        return maxPlayers
    end

    return instanceGroupSize or maxPlayers
end

local function FixedMiniMapInstanceDifficulty_Update()
    local _, instanceType, difficulty, _, maxPlayers, playerDifficulty, isDynamicInstance = GetInstanceInfo()
    local _, _, isHeroic, isChallengeMode = GetDifficultyInfo(difficulty)

    local instanceGroupSize = GetFixedInstanceGroupSize()

    if IS_GUILD_GROUP then
        if instanceGroupSize == 0 then
            GuildInstanceDifficultyText:SetText("")
            GuildInstanceDifficultyDarkBackground:SetAlpha(0)
            GuildInstanceDifficulty.emblem:SetPoint("TOPLEFT", 12, -16)
        else
            GuildInstanceDifficultyText:SetText(instanceGroupSize)
            GuildInstanceDifficultyDarkBackground:SetAlpha(0.7)
            GuildInstanceDifficulty.emblem:SetPoint("TOPLEFT", 12, -10)
        end

        GuildInstanceDifficultyText:ClearAllPoints()

        if isHeroic or isChallengeMode then
            local symbolTexture
            if isChallengeMode then
                symbolTexture = GuildInstanceDifficultyChallengeModeTexture
                GuildInstanceDifficultyHeroicTexture:Hide()
            else
                symbolTexture = GuildInstanceDifficultyHeroicTexture
                GuildInstanceDifficultyChallengeModeTexture:Hide()
            end

            if instanceGroupSize < 10 then
                symbolTexture:SetPoint("BOTTOMLEFT", 11, 7)
                GuildInstanceDifficultyText:SetPoint("BOTTOMLEFT", 23, 8)
            elseif instanceGroupSize > 19 then
                symbolTexture:SetPoint("BOTTOMLEFT", 8, 7)
                GuildInstanceDifficultyText:SetPoint("BOTTOMLEFT", 20, 8)
            else
                symbolTexture:SetPoint("BOTTOMLEFT", 8, 7)
                GuildInstanceDifficultyText:SetPoint("BOTTOMLEFT", 19, 8)
            end
            symbolTexture:Show()
        else
            GuildInstanceDifficultyHeroicTexture:Hide()
            GuildInstanceDifficultyChallengeModeTexture:Hide()
            GuildInstanceDifficultyText:SetPoint("BOTTOM", 2, 8)
        end

        MiniMapInstanceDifficulty:Hide()
        SetSmallGuildTabardTextures("player", GuildInstanceDifficulty.emblem, GuildInstanceDifficulty.background, GuildInstanceDifficulty.border)
        GuildInstanceDifficulty:Show()
        MiniMapChallengeMode:Hide()

    elseif isChallengeMode then
        MiniMapChallengeMode:Show()
        MiniMapInstanceDifficulty:Hide()
        GuildInstanceDifficulty:Hide()

    elseif instanceType == "raid" or isHeroic then
        MiniMapInstanceDifficultyText:SetText(instanceGroupSize)

        local xOffset = 0
        if instanceGroupSize >= 10 and instanceGroupSize <= 19 then
            xOffset = -1
        end

        if isHeroic then
            MiniMapInstanceDifficultyTexture:SetTexCoord(0, 0.25, 0.0703125, 0.4140625)
            MiniMapInstanceDifficultyText:SetPoint("CENTER", xOffset, -9)
        else
            MiniMapInstanceDifficultyTexture:SetTexCoord(0, 0.25, 0.5703125, 0.9140625)
            MiniMapInstanceDifficultyText:SetPoint("CENTER", xOffset, 5)
        end

        MiniMapInstanceDifficulty:Show()
        GuildInstanceDifficulty:Hide()
        MiniMapChallengeMode:Hide()
    else
        MiniMapInstanceDifficulty:Hide()
        GuildInstanceDifficulty:Hide()
        MiniMapChallengeMode:Hide()
    end
end

local f2 = CreateFrame("Frame")
f2:RegisterEvent("PLAYER_ENTERING_WORLD")
f2:SetScript("OnEvent", function()
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    hooksecurefunc("MiniMapInstanceDifficulty_Update", FixedMiniMapInstanceDifficulty_Update)
end)

-- Fix Raid Difficulty Change Update (this will auto reset instances on difficulty change if not in instance)
local lastRaidDifficulty = nil
local waitingForResetCheck = false

local function AutoResetInstances()
    if IsInInstance() then
        return
    end

    if not IsInGroup() or UnitIsGroupLeader("player") then
        waitingForResetCheck = true
        ResetInstances()
    end
end

local function CheckDifficultyChange()
    local currentDifficulty = GetRaidDifficultyID()
    
    if not lastRaidDifficulty then
        lastRaidDifficulty = currentDifficulty
        return
    end

    if currentDifficulty ~= lastRaidDifficulty and not IsInInstance() then
        C_Timer.After(0.1, AutoResetInstances)
        lastRaidDifficulty = currentDifficulty
    end
end

local function HookRaidDifficultyUI()
    hooksecurefunc("SetRaidDifficultyID", function(difficultyID)
        if not IsInInstance() then
            C_Timer.After(0.1, CheckDifficultyChange)
        end
    end)

    if SetRaidDifficulty then
        hooksecurefunc("SetRaidDifficulty", function(difficulty)
            if not IsInInstance() then
                C_Timer.After(0.1, CheckDifficultyChange)
            end
        end)
    end
end

local f3 = CreateFrame("Frame")
f3:RegisterEvent("PLAYER_LOGIN")
f3:SetScript("OnEvent", function(self, event)
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    if event == "PLAYER_LOGIN" then
        lastRaidDifficulty = GetRaidDifficultyID()
        C_Timer.After(1, HookRaidDifficultyUI)
    end
end)

--Fix Journal Buttons
hooksecurefunc("ShowUIPanel", function(frame)
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    if mQoL_DB and mQoL_DB.BlizzardFixes and mQoL_DB.BlizzardFixes.fixJournalTabs == false then return end
    if frame == EncounterJournal then
        C_Timer.After(0.05, function()
            if EncounterJournal and EncounterJournal.selectedTab then
                EJ_ContentTab_Select(EncounterJournal.selectedTab)
            end
        end)
    end
end)

--Remove obsolete checkboxes in blizzard options ui
local hiddenDisplayProxySettings = {
    PROXY_SHOW_HELM = true,
    PROXY_SHOW_CLOAK = true,
}

local function GetSettingVariable(setting)
    if not setting or type(setting.GetVariable) ~= "function" then
        return nil
    end

    if type(securecallfunction) == "function" then
        return securecallfunction(setting.GetVariable, setting)
    end

    return setting:GetVariable()
end

local function IsHiddenDisplayProxySetting(setting)
    local variable = GetSettingVariable(setting)
    return variable and hiddenDisplayProxySettings[variable] == true
end

local function RemoveHiddenDisplayInitializersFromLayout(layout)
    if not layout or type(layout.GetInitializers) ~= "function" then
        return false
    end

    local initializers = layout:GetInitializers()
    if type(initializers) ~= "table" then
        return false
    end

    local removed = false
    for i = #initializers, 1, -1 do
        local initializer = initializers[i]
        local setting = initializer and type(initializer.GetSetting) == "function" and initializer:GetSetting()
        if IsHiddenDisplayProxySetting(setting) then
            table.remove(initializers, i)
            removed = true
        end
    end

    return removed
end

local function RemoveExistingHiddenDisplaySettings()
    if not SettingsPanel or type(SettingsPanel.GetSetting) ~= "function" or type(SettingsPanel.GetLayout) ~= "function" then
        return false
    end

    local removed = false
    local prunedLayouts = {}
    for variable in pairs(hiddenDisplayProxySettings) do
        local setting = SettingsPanel:GetSetting(variable)
        local category = setting and SettingsPanel.settings and SettingsPanel.settings[setting]
        local layout = category and SettingsPanel:GetLayout(category)
        if layout and not prunedLayouts[layout] then
            removed = RemoveHiddenDisplayInitializersFromLayout(layout) or removed
            prunedLayouts[layout] = true
        end
    end

    if removed then
        if SettingsInbound and type(SettingsInbound.RepairDisplay) == "function" then
            SettingsInbound.RepairDisplay()
        elseif type(SettingsPanel.RepairDisplay) == "function" then
            SettingsPanel:RepairDisplay()
        end
    end

    return removed
end

local function OnSettingsCheckboxCreated(category, setting)
    if not IsHiddenDisplayProxySetting(setting) then
        return
    end

    local layout = SettingsPanel and type(SettingsPanel.GetLayout) == "function" and SettingsPanel:GetLayout(category)
    if RemoveHiddenDisplayInitializersFromLayout(layout) then
        if SettingsInbound and type(SettingsInbound.RepairDisplay) == "function" then
            SettingsInbound.RepairDisplay()
        elseif SettingsPanel and type(SettingsPanel.RepairDisplay) == "function" then
            SettingsPanel:RepairDisplay()
        end
    end
end

local function InstallPandariaDisplayOptionsFix()
    if not ShouldLoadBlizzardFixes() then
        return true
    end

    if not Settings or type(Settings.CreateCheckbox) ~= "function" or type(Settings.CreateCheckboxWithOptions) ~= "function" then
        return false
    end

    if not Settings.__mQoLHiddenDisplayOptionsHooked then
        hooksecurefunc(Settings, "CreateCheckboxWithOptions", OnSettingsCheckboxCreated)
        Settings.__mQoLHiddenDisplayOptionsHooked = true
    end

    RemoveExistingHiddenDisplaySettings()
    return true
end

local f_display_options = CreateFrame("Frame")
f_display_options:RegisterEvent("ADDON_LOADED")
f_display_options:RegisterEvent("PLAYER_LOGIN")
f_display_options:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED"
        and arg1 ~= addonName
        and arg1 ~= "Blizzard_Settings_Shared"
        and arg1 ~= "Blizzard_SettingsDefinitions_Frame" then
        return
    end

    if InstallPandariaDisplayOptionsFix() then
        self:UnregisterAllEvents()
    end
end)
if InstallPandariaDisplayOptionsFix() then
    f_display_options:UnregisterAllEvents()
end