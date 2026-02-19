local addonName = ...

----------------------------------------------------------
-- better consolidated buffs
----------------------------------------------------------

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

local UpdateBuffDisplay

-- BUFF FRAME CREATION
local function CreateBuffFrame(parent, category, size)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    frame:EnableMouse(true)

    -- Ikona
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(GetSpellTexture(category.icon))
    frame.icon = icon

    -- Label nad ikoną
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    label:SetText(category.name)
    frame.text = label

    -- timer
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
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId = UnitBuff("player", i)
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

-- TOOLTIP FRAME
local baseIconSize = 32
local iconSize = baseIconSize * 1.1
local spacing = 32
local paddingTop = 30
local paddingLeft = 20
local textHeight = 18
local rows = 2
local cols = 4

local contentWidth = cols*iconSize + (cols-1)*spacing
local contentHeight = rows*iconSize + (rows-1)*spacing + textHeight*2

local tooltipWidth = (contentWidth + paddingLeft*2) * 1.1
local tooltipHeight = contentHeight + paddingTop + 12

local tooltip = CreateFrame("Frame", "mQoLConsolidatedTooltip", UIParent, "BackdropTemplate")
tooltip:SetSize(tooltipWidth, tooltipHeight)
tooltip:SetFrameStrata("DIALOG")
tooltip:SetFrameLevel(ConsolidatedBuffs:GetFrameLevel() + 2)
tooltip:SetPoint("TOPRIGHT", ConsolidatedBuffs, "BOTTOMLEFT", 0, 0)
tooltip:Hide()

tooltip:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
tooltip:SetBackdropColor(0, 0, 0, 0.55)
tooltip:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

tooltip.buffs = {}

-- Center grid
local offsetX = (tooltipWidth - contentWidth) / 2
local offsetY = -paddingTop

-- Create frames
for i, category in ipairs(RAID_BUFFS) do
    local row = math.floor((i-1)/cols) + 1
    local col = ((i-1) % cols) + 1

    local frame = CreateBuffFrame(tooltip, category, iconSize)
    tooltip.buffs[i] = frame

    local rowOffset = (row - 1) * (iconSize + spacing + textHeight)
    if row == 2 then
        rowOffset = rowOffset - 6
    end

    frame:SetPoint("TOPLEFT", tooltip, "TOPLEFT",
        offsetX + (col-1)*(iconSize+spacing),
        offsetY - rowOffset
    )

    frame.category = category

    frame:SetScript("OnEnter", function(self)
        local active, texture, remaining, infinite, auraIndex = GetCategoryBuffInfo(self.category)
        if active and auraIndex then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetUnitBuff("player", auraIndex)
            GameTooltip:Show()
        else
            GameTooltip:Hide()
        end
    end)

    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    frame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            local active, texture, remaining, infinite, auraIndex = GetCategoryBuffInfo(self.category)
            if active and auraIndex then
                if not infinite then
                    if CancelUnitBuff then
                        CancelUnitBuff("player", auraIndex)
                    elseif CancelUnitAura then
                        CancelUnitAura("player", auraIndex)
                    end
                    GameTooltip:Hide()
                    UpdateBuffDisplay()
                end
            end
        end
    end)
end

function UpdateBuffDisplay()
    local anyActive = false
    for i, category in ipairs(RAID_BUFFS) do
        local active, texture, remaining, infinite = GetCategoryBuffInfo(category)
        local frame = tooltip.buffs[i]

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
                frame.timer:SetTextColor(1,1,1)
                frame.timer:ClearAllPoints()
                frame.timer:SetPoint("TOP", frame, "BOTTOM", 0, -4)
        
                if remaining < 60 then
                    frame.timer:SetText(math.floor(remaining).."s")
                elseif remaining < 3600 then
                    frame.timer:SetText(math.floor(remaining/60).."m")
                else
                    frame.timer:SetText(math.floor(remaining/3600).."h")
                end
            else
                frame.timer:SetFont(FONT_PATH, BASE_FONT_SIZE, "OUTLINE")
                frame.timer:SetText("—")
                frame.timer:SetTextColor(1,1,1)
                frame.timer:ClearAllPoints()
                frame.timer:SetPoint("TOP", frame, "BOTTOM", 0, -4)
            end
        else
            frame.timer:SetFont(FONT_PATH, BASE_FONT_SIZE, "OUTLINE")
            frame.timer:SetText("—")
            frame.timer:SetTextColor(1,1,1)
            frame.timer:ClearAllPoints()
            frame.timer:SetPoint("TOP", frame, "BOTTOM", 0, -4)
        end
    end

    if not anyActive then
        tooltip:Hide()
    end

    return anyActive
end

local updateFrame = CreateFrame("Frame")
local elapsedSinceUpdate = 0
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate >= UPDATE_INTERVAL then
        UpdateBuffDisplay()
        elapsedSinceUpdate = 0
    end
end)

local function ScheduleConsolidatedTooltipHide()
    if not C_Timer or not C_Timer.After then
        if not ConsolidatedBuffs:IsMouseOver() and not tooltip:IsMouseOver() then
            tooltip:Hide()
            GameTooltip:Hide()
        end
        return
    end

    C_Timer.After(0.2, function()
        if not ConsolidatedBuffs:IsMouseOver() and not tooltip:IsMouseOver() then
            tooltip:Hide()
            GameTooltip:Hide()
        end
    end)
end

-- HOVER HANDLERS
ConsolidatedBuffs:SetScript("OnEnter", function()
    GameTooltip:Hide()
    local hasBuffs = UpdateBuffDisplay()
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

-- Hide Blizzard tooltip
if ConsolidatedBuffsTooltip then
    ConsolidatedBuffsTooltip:UnregisterAllEvents()
    ConsolidatedBuffsTooltip:Hide()
end
----------------------------------------------------------
-- Fix for corpse texture on map
----------------------------------------------------------

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

----------------------------------------------------------
-- Fix Raid Minimap Difficulty
----------------------------------------------------------

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
    hooksecurefunc("MiniMapInstanceDifficulty_Update", FixedMiniMapInstanceDifficulty_Update)
end)

----------------------------------------------------------
-- Fix Raid Difficulty Change Update
-- changing instance difficulty not always works
----------------------------------------------------------

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
    if event == "PLAYER_LOGIN" then
        lastRaidDifficulty = GetRaidDifficultyID()
        C_Timer.After(1, HookRaidDifficultyUI)
    end
end)

--------------------------------------------
--Fix Journal Buttons
--------------------------------------------

hooksecurefunc("ShowUIPanel", function(frame)
    if frame == EncounterJournal then
        C_Timer.After(0.05, function()
            if EncounterJournal and EncounterJournal.selectedTab then
                EJ_ContentTab_Select(EncounterJournal.selectedTab)
            end
        end)
    end
end)