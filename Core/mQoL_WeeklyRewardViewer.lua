mQoL_WeeklyRewardViewer = mQoL_WeeklyRewardViewer or {}

local WeeklyRewardViewer = mQoL_WeeklyRewardViewer
local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local WeeklyRewardUtils = mQoL_WeeklyRewardUtils or {}
local Utils = mQoL_Utils or {}
local FormatTimestamp = Utils.FormatTimestamp

local DEFAULT_SYNC_TEXT = "Snapshot data from Account Overview"
local DEFAULT_TOOLTIP_TITLE = "Great Vault"
local SELECTION_STATE_HIDDEN = 1

local FALLBACK_GROUP_ORDER = {
    { key = "raid", label = "Raid", total = 3, defaultThresholds = { 2, 4, 6 } },
    { key = "mythicPlus", label = DUNGEONS or "Dungeons", total = 3, defaultThresholds = { 1, 4, 8 } },
    { key = "world", label = "World", total = 3, defaultThresholds = { 2, 4, 8 } },
}

local GROUP_VISUALS = {
    raid = {
        title = RAIDS or "Raids",
        atlas = "evergreen-weeklyrewards-category-raids",
        anchorY = -149,
        rewardType = Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Raid or 3,
    },
    mythicPlus = {
        title = DUNGEONS or "Dungeons",
        atlas = "evergreen-weeklyrewards-category-dungeons",
        anchorY = -307,
        rewardType = Enum and Enum.WeeklyRewardChestThresholdType and (Enum.WeeklyRewardChestThresholdType.Activities or Enum.WeeklyRewardChestThresholdType.MythicPlus) or 1,
    },
    world = {
        title = WORLD or "World",
        atlas = "evergreen-weeklyrewards-category-world",
        anchorY = -470,
        rewardType = Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.World or 6,
    },
}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result1, result2, result3 = pcall(func, ...)
    if not ok then
        return nil
    end

    return result1, result2, result3
end

local function ClampNumber(value)
    local numeric = tonumber(value)
    if not numeric or numeric <= 0 then
        return 0
    end

    return math.floor(numeric)
end

local function NormalizeOptionalText(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    return value
end

local function SafeFormatText(template, ...)
    if type(template) ~= "string" or template == "" then
        return nil
    end

    local ok, text = pcall(string.format, template, ...)
    if ok and type(text) == "string" and text ~= "" then
        return text
    end

    return template
end

local function Notify(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    if UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
        UIErrorsFrame:AddMessage(message, 1, 0.2, 0.2)
        return
    end

    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[mQoL]|r %s", message))
    end
end

local function GetRetailGroupOrder()
    if WeeklyRewardUtils and type(WeeklyRewardUtils.GetRetailGroupOrder) == "function" then
        local groups = WeeklyRewardUtils.GetRetailGroupOrder()
        if type(groups) == "table" and #groups > 0 then
            return groups
        end
    end

    return FALLBACK_GROUP_ORDER
end

local function NormalizeSnapshot(rawValue)
    if WeeklyRewardUtils and type(WeeklyRewardUtils.NormalizeSnapshot) == "function" then
        return WeeklyRewardUtils.NormalizeSnapshot(rawValue)
    end

    return rawValue
end

local function BuildCharacterLabel(characterData)
    local name = type(characterData) == "table" and characterData.name or nil
    local realm = type(characterData) == "table" and characterData.realm or nil

    if type(name) == "string" and name ~= "" and type(realm) == "string" and realm ~= "" then
        return string.format("%s - %s", name, realm)
    end

    if type(name) == "string" and name ~= "" then
        return name
    end

    return "Saved character"
end

local function FormatSyncText(snapshot)
    if type(snapshot) ~= "table" or ClampNumber(snapshot.lastSync) <= 0 then
        return DEFAULT_SYNC_TEXT
    end

    if type(FormatTimestamp) == "function" then
        return string.format("%s    Last sync: %s", DEFAULT_SYNC_TEXT, FormatTimestamp(snapshot.lastSync))
    end

    return string.format("%s    Last sync: %s", DEFAULT_SYNC_TEXT, date("%Y-%m-%d %H:%M", snapshot.lastSync))
end

local function GetGroupVisual(groupKey)
    return GROUP_VISUALS[groupKey] or {
        title = DEFAULT_TOOLTIP_TITLE,
        atlas = "evergreen-weeklyrewards-category-world",
        anchorY = -470,
        rewardType = 0,
    }
end

local function GetRewardTypeForGroup(groupKey)
    return ClampNumber(GetGroupVisual(groupKey).rewardType)
end

local function AddFrameToEscapeList(frame)
    local frameName = frame and type(frame.GetName) == "function" and frame:GetName() or nil
    if type(frameName) ~= "string" or frameName == "" or type(UISpecialFrames) ~= "table" then
        return
    end

    for _, value in ipairs(UISpecialFrames) do
        if value == frameName then
            return
        end
    end

    table.insert(UISpecialFrames, frameName)
end

local function HideNativeWeeklyRewardsFrame()
    if WeeklyRewardExpirationWarningDialog and WeeklyRewardExpirationWarningDialog:IsShown() then
        WeeklyRewardExpirationWarningDialog:Hide()
    end

    if WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown() then
        if HideUIPanel then
            pcall(HideUIPanel, WeeklyRewardsFrame)
        end
        WeeklyRewardsFrame:Hide()
    end
end

local function EnsureTemplatesLoaded()
    if not clientInfo.isRetail then
        return false
    end

    if not WeeklyRewardsFrame and UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_WeeklyRewards")
    end

    if not WeeklyRewardsFrame and LoadAddOn then
        pcall(LoadAddOn, "Blizzard_WeeklyRewards")
    end

    return type(WeeklyRewardsActivityMixin) == "table"
end

local function GetColorRGB(colorObject, fallbackR, fallbackG, fallbackB)
    if colorObject and type(colorObject.GetRGB) == "function" then
        return colorObject:GetRGB()
    end

    return fallbackR, fallbackG, fallbackB
end

local function SetTooltipTitle(tooltip, text)
    if GameTooltip_SetTitle then
        GameTooltip_SetTitle(tooltip, text)
        return
    end

    tooltip:AddLine(text, 1, 0.82, 0)
end

local function BuildThresholdText(activityInfo, groupKey)
    local threshold = ClampNumber(activityInfo and activityInfo.threshold)
    if threshold <= 0 then
        return nil
    end

    local template
    if groupKey == "raid" then
        template = NormalizeOptionalText(activityInfo and activityInfo.raidString) or NormalizeOptionalText(WEEKLY_REWARDS_THRESHOLD_RAID)
    elseif groupKey == "mythicPlus" then
        template = NormalizeOptionalText(WEEKLY_REWARDS_THRESHOLD_DUNGEONS)
    elseif groupKey == "world" then
        template = NormalizeOptionalText(WEEKLY_REWARDS_THRESHOLD_WORLD)
    end

    if template then
        return SafeFormatText(template, threshold)
    end

    if groupKey == "raid" then
        return threshold == 1 and "Defeat 1 Boss" or string.format("Defeat %d Bosses", threshold)
    end

    if groupKey == "mythicPlus" then
        return threshold == 1
            and "Complete 1 Heroic, Mythic, or Timewalking Dungeon"
            or string.format("Complete %d Heroic, Mythic, or Timewalking Dungeons", threshold)
    end

    return threshold == 1
        and "Complete 1 Delve or World Activity"
        or string.format("Complete %d Delves or World Activities", threshold)
end

local function ResolveSavedProgressText(slotData, groupKey)
    local progressText = NormalizeOptionalText(slotData and slotData.progressText)
    if progressText then
        return progressText
    end

    local level = ClampNumber(slotData and slotData.level)
    if groupKey == "raid" and level > 0 and DifficultyUtil and type(DifficultyUtil.GetDifficultyName) == "function" then
        return NormalizeOptionalText(SafeCall(DifficultyUtil.GetDifficultyName, level))
    end

    if groupKey == "mythicPlus" then
        local heroicDifficultyID = DifficultyUtil and DifficultyUtil.ID and ClampNumber(DifficultyUtil.ID.DungeonHeroic) or 0
        local difficultyID = ClampNumber(
            SafeCall(C_WeeklyRewards and C_WeeklyRewards.GetDifficultyIDForActivityTier, slotData and slotData.activityTierID)
        )

        if heroicDifficultyID > 0 and difficultyID == heroicDifficultyID then
            return NormalizeOptionalText(WEEKLY_REWARDS_HEROIC) or "Heroic"
        end

        if level > 0 then
            return SafeFormatText(WEEKLY_REWARDS_MYTHIC, level) or string.format("Mythic %d", level)
        end
    elseif groupKey == "world" and level > 0 then
        return SafeFormatText(GREAT_VAULT_WORLD_TIER, level) or string.format("Tier %d", level)
    end

    local itemLevel = ClampNumber(slotData and slotData.itemLevel)
    if type(slotData) == "table" and slotData.unlocked and itemLevel > 0 then
        return SafeFormatText(ITEM_LEVEL, itemLevel) or string.format("%d item level", itemLevel)
    end

    return nil
end

local function BuildSyntheticActivityInfo(groupInfo, slotData, slotIndex)
    local threshold = ClampNumber(slotData and slotData.threshold)
    if threshold <= 0 then
        threshold = ClampNumber(groupInfo and groupInfo.defaultThresholds and groupInfo.defaultThresholds[slotIndex])
    end

    local progress = ClampNumber(slotData and slotData.progress)
    if type(slotData) == "table" and slotData.unlocked and progress <= 0 then
        progress = threshold > 0 and threshold or 1
    end

    local info = {
        id = ClampNumber(slotData and slotData.activityID),
        index = ClampNumber(slotData and slotData.index),
        type = GetRewardTypeForGroup(groupInfo and groupInfo.key),
        threshold = threshold,
        progress = progress,
        level = ClampNumber(slotData and slotData.level),
        activityTierID = ClampNumber(slotData and slotData.activityTierID),
        raidString = NormalizeOptionalText(slotData and slotData.raidString),
        rewards = {},
        progressText = ResolveSavedProgressText(slotData, groupInfo and groupInfo.key),
    }

    if info.index <= 0 then
        info.index = ClampNumber(slotIndex)
    end

    if info.id <= 0 then
        info.id = info.index
    end

    return info
end

local function IsHeroicMythicPlusSlot(slotData)
    local heroicDifficultyID = DifficultyUtil and DifficultyUtil.ID and ClampNumber(DifficultyUtil.ID.DungeonHeroic) or 0
    local difficultyID = ClampNumber(
        SafeCall(C_WeeklyRewards and C_WeeklyRewards.GetDifficultyIDForActivityTier, slotData and slotData.activityTierID)
    )

    return heroicDifficultyID > 0 and difficultyID == heroicDifficultyID
end

local function AddTooltipLine(tooltip, text, r, g, b)
    if type(text) ~= "string" or text == "" then
        return
    end

    tooltip:AddLine(text, r or 1, g or 1, b or 1, true)
end

local function GetVaultRewardOrdinalText(index)
    if ClampNumber(index) == 2 then
        return "second"
    end

    if ClampNumber(index) == 3 then
        return "third"
    end

    return "first"
end

local function BuildCurrentRewardBasisText(slotData, groupKey)
    local level = ClampNumber(slotData and slotData.level)
    if groupKey == "mythicPlus" then
        if IsHeroicMythicPlusSlot(slotData) then
            return "currently Heroic"
        end

        if level > 0 then
            return string.format("currently Mythic level %d", level)
        end

        return nil
    end

    if groupKey == "world" and level > 0 then
        return string.format("currently Tier %d", level)
    end

    return nil
end

local function BuildUnlockedRewardTooltipLines(activityInfo, slotData, groupInfo)
    local lines = {}
    local itemLevel = ClampNumber(slotData and slotData.itemLevel)
    local level = ClampNumber(slotData and slotData.level)

    lines[#lines + 1] = {
        text = NormalizeOptionalText(WEEKLY_REWARDS_CURRENT_REWARD) or "Current Reward",
        color = { 1, 1, 1 },
        title = true,
    }

    if groupInfo.key == "raid" then
        local difficultyName = ResolveSavedProgressText(slotData, groupInfo.key) or NormalizeOptionalText(RAID)
        lines[#lines + 1] = {
            text = SafeFormatText(WEEKLY_REWARDS_ITEM_LEVEL_RAID, itemLevel, difficultyName)
                or string.format("Item Level %d - %s", itemLevel, difficultyName or "Raid"),
            color = { 1, 0.82, 0 },
        }
    elseif groupInfo.key == "mythicPlus" then
        if IsHeroicMythicPlusSlot(slotData) then
            lines[#lines + 1] = {
                text = SafeFormatText(WEEKLY_REWARDS_ITEM_LEVEL_HEROIC, itemLevel)
                    or string.format("Item Level %d - Heroic", itemLevel),
                color = { 1, 0.82, 0 },
            }
        else
            lines[#lines + 1] = {
                text = SafeFormatText(WEEKLY_REWARDS_ITEM_LEVEL_MYTHIC, itemLevel, level)
                    or string.format("Item Level %d - Mythic (Level %d)", itemLevel, level),
                color = { 1, 0.82, 0 },
            }
        end
    elseif groupInfo.key == "world" then
        lines[#lines + 1] = {
            text = SafeFormatText(WEEKLY_REWARDS_ITEM_LEVEL_WORLD, itemLevel, level)
                or string.format("Item Level %d - Tier %d", itemLevel, level),
            color = { 1, 0.82, 0 },
        }
    end

    lines[#lines + 1] = {
        blank = true,
    }
    lines[#lines + 1] = {
        text = NormalizeOptionalText(WEEKLY_REWARDS_MAXED_REWARD) or "Reward at Highest Item Level",
        color = { 0.2, 1, 0.2 },
    }

    return lines
end

local function BuildIncompleteTooltipLines(activityInfo, slotData, groupInfo)
    if type(activityInfo) ~= "table" or type(groupInfo) ~= "table" then
        return {}
    end

    local remaining = math.max(0, ClampNumber(activityInfo.threshold) - ClampNumber(activityInfo.progress))
    local thresholdText = BuildThresholdText(activityInfo, groupInfo.key)
    local lines = {
        {
            text = NormalizeOptionalText(WEEKLY_REWARDS_UNLOCK_REWARD) or "Unlock Reward",
            color = { 1, 1, 1 },
            title = true,
        },
    }

    if groupInfo.key == "raid" then
        lines[#lines + 1] = {
            text = thresholdText and string.format("%s this week to unlock this reward.", thresholdText)
                or string.format("Defeat %d bosses this week to unlock this reward.", remaining),
            color = { 1, 0.82, 0 },
        }
        lines[#lines + 1] = { blank = true }
        lines[#lines + 1] = {
            text = "The item level of this reward will be based on the difficulty of the raid.",
            color = { 1, 0.82, 0 },
        }
        return lines
    end

    if groupInfo.key == "mythicPlus" then
        local rewardOrdinal = GetVaultRewardOrdinalText(activityInfo.index)
        local dungeonWord = remaining == 1 and "dungeon" or "dungeons"
        local firstSentence

        if ClampNumber(activityInfo.index) == 1 then
            firstSentence = string.format(
                "Complete %d max level Heroic or Mythic %s this week to unlock a Great Vault reward. Timewalking dungeons count as Heroic.",
                math.max(1, remaining),
                dungeonWord
            )
        else
            firstSentence = string.format(
                "Complete %d more Heroic or Mythic max level %s this week to unlock a %s Great Vault reward. Timewalking dungeons count as Heroic.",
                remaining,
                dungeonWord,
                rewardOrdinal
            )
        end

        local currentBasis = BuildCurrentRewardBasisText(slotData, groupInfo.key)
        local basisText = string.format(
            "The item level of this reward will be based on the lowest of your top %d runs this week",
            ClampNumber(activityInfo.threshold)
        )
        if currentBasis then
            basisText = string.format("%s (%s).", basisText, currentBasis)
        else
            basisText = basisText .. "."
        end

        lines[#lines + 1] = { text = firstSentence, color = { 1, 0.82, 0 } }
        lines[#lines + 1] = { blank = true }
        lines[#lines + 1] = { text = basisText, color = { 1, 0.82, 0 } }
        return lines
    end

    local rewardOrdinal = GetVaultRewardOrdinalText(activityInfo.index)
    local activityWord = remaining == 1 and "activity" or "activities"
    local worldText

    if ClampNumber(activityInfo.index) == 1 then
        worldText = string.format(
            "Complete %d more delve or world %s this week to unlock a Great Vault reward. World activities count as Tier 1. Prey counts as Tier 1, 5, 7 or 8 based on difficulty.",
            math.max(1, remaining),
            activityWord
        )
    else
        worldText = string.format(
            "Complete %d more delves or world %s this week to unlock a %s Great Vault reward. World activities count as Tier 1. Prey counts as Tier 1, 5, 7 or 8 based on difficulty.",
            remaining,
            activityWord,
            rewardOrdinal
        )
    end

    local currentBasis = BuildCurrentRewardBasisText(slotData, groupInfo.key)
    local basisText = string.format(
        "The item level of your reward will be based on the lowest of your top %d runs this week",
        ClampNumber(activityInfo.threshold)
    )
    if currentBasis then
        basisText = string.format("%s (%s).", basisText, currentBasis)
    else
        basisText = basisText .. "."
    end

    lines[#lines + 1] = { text = worldText, color = { 1, 0.82, 0 } }
    lines[#lines + 1] = { blank = true }
    lines[#lines + 1] = { text = basisText, color = { 1, 0.82, 0 } }
    return lines
end

local function BuildDefaultSlot(groupInfo, slotIndex)
    return {
        index = ClampNumber(slotIndex),
        progress = 0,
        threshold = ClampNumber(groupInfo and groupInfo.defaultThresholds and groupInfo.defaultThresholds[slotIndex]),
        unlocked = false,
        itemLevel = 0,
        activityID = 0,
        level = 0,
        activityTierID = 0,
        raidString = nil,
        progressText = nil,
    }
end

local function BuildSlotTooltip(activityFrame)
    local activityInfo = activityFrame and activityFrame.snapshotActivityInfo or nil
    local slotData = activityFrame and activityFrame.snapshotSlotData or nil
    local groupInfo = activityFrame and activityFrame.snapshotGroupInfo or nil
    if type(activityInfo) ~= "table" or type(groupInfo) ~= "table" then
        return
    end

    GameTooltip:SetOwner(activityFrame, "ANCHOR_RIGHT", -7, -11)

    if type(slotData) == "table" and slotData.unlocked then
        for _, line in ipairs(BuildUnlockedRewardTooltipLines(activityInfo, slotData, groupInfo)) do
            if line.blank then
                if GameTooltip_AddBlankLineToTooltip then
                    GameTooltip_AddBlankLineToTooltip(GameTooltip)
                else
                    GameTooltip:AddLine(" ")
                end
            elseif line.title then
                SetTooltipTitle(GameTooltip, line.text)
            else
                local color = line.color or { 1, 1, 1 }
                AddTooltipLine(GameTooltip, line.text, color[1], color[2], color[3])
            end
        end
    else
        for _, line in ipairs(BuildIncompleteTooltipLines(activityInfo, slotData, groupInfo)) do
            if line.blank then
                if GameTooltip_AddBlankLineToTooltip then
                    GameTooltip_AddBlankLineToTooltip(GameTooltip)
                else
                    GameTooltip:AddLine(" ")
                end
            elseif line.title then
                SetTooltipTitle(GameTooltip, line.text)
            else
                local color = line.color or { 1, 1, 1 }
                AddTooltipLine(GameTooltip, line.text, color[1], color[2], color[3])
            end
        end
    end

    GameTooltip:Show()
end

local function HideSelectionState(activityFrame)
    if type(activityFrame.SetSelectionState) == "function" then
        activityFrame:SetSelectionState(SELECTION_STATE_HIDDEN)
        return
    end

    if activityFrame.SelectedTexture then
        activityFrame.SelectedTexture:Hide()
    end

    if activityFrame.SelectionGlow then
        activityFrame.SelectionGlow:Hide()
    end

    if activityFrame.UnselectedFrame then
        activityFrame.UnselectedFrame:Hide()
    end
end

local NormalizeActivityVisualLayers

local function ApplyActivityFrameData(activityFrame, groupInfo, slotData, slotIndex)
    local activityInfo = BuildSyntheticActivityInfo(groupInfo, slotData, slotIndex)

    activityFrame.snapshotGroupInfo = groupInfo
    activityFrame.snapshotSlotData = slotData
    activityFrame.snapshotActivityInfo = activityInfo

    if type(activityFrame.Refresh) == "function" then
        activityFrame:Refresh(activityInfo)
    end

    NormalizeActivityVisualLayers(activityFrame, activityFrame:GetFrameLevel())

    HideSelectionState(activityFrame)

    if activityInfo.progressText and type(activityFrame.SetProgressText) == "function" then
        activityFrame:SetProgressText(activityInfo.progressText)
    end

    if activityFrame.ItemFrame then
        activityFrame.ItemFrame:Hide()
    end

    activityFrame:Show()
end

local function SetFrameLayering(target, strata, level)
    if not target then
        return
    end

    if strata and type(target.SetFrameStrata) == "function" then
        target:SetFrameStrata(strata)
    end

    if level and type(target.SetFrameLevel) == "function" then
        target:SetFrameLevel(level)
    end
end

NormalizeActivityVisualLayers = function(card, baseLevel)
    if not card then
        return
    end

    local strata = card:GetFrameStrata()
    SetFrameLayering(card, strata, baseLevel)
    SetFrameLayering(card.RewardGenerated, strata, baseLevel + 30)
    SetFrameLayering(card.RewardGenerated and card.RewardGenerated.Sparkles, strata, baseLevel + 31)
    SetFrameLayering(card.RewardGenerated and card.RewardGenerated.BurstFX, strata, baseLevel + 32)
    SetFrameLayering(card.RewardGenerated and card.RewardGenerated.Overlay, strata, baseLevel + 33)
    SetFrameLayering(card.ItemFrame, strata, baseLevel + 40)
    SetFrameLayering(card.UnselectedFrame, strata, baseLevel + 45)
    SetFrameLayering(card.SelectionGlow, strata, baseLevel + 50)
    SetFrameLayering(card.SelectionGlow and card.SelectionGlow.SideGlows, strata, baseLevel + 51)
    SetFrameLayering(card.SelectionGlow and card.SelectionGlow.EdgeGlow, strata, baseLevel + 52)
end

local function CreateAtlasTexture(parent, layer, atlas, textureSubLevel, useAtlasSize)
    local texture = parent:CreateTexture(nil, layer, nil, textureSubLevel)
    texture:SetAtlas(atlas, useAtlasSize and true or false)
    return texture
end

local function CreateActivityWidgets(frame, groupInfo)
    local visual = GetGroupVisual(groupInfo.key)
    local state = {}
    local baseFrameLevel = math.max(ClampNumber(frame and frame:GetFrameLevel()), 1)

    state.typeFrame = CreateFrame("Frame", nil, frame, "WeeklyRewardActivityTypeTemplate")
    state.typeFrame:SetFrameStrata(frame:GetFrameStrata())
    state.typeFrame:SetFrameLevel(baseFrameLevel + 120)
    state.typeFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 68, visual.anchorY)
    state.typeFrame.Name:SetText(visual.title)
    state.typeFrame.Background:SetAtlas(visual.atlas, true)
    if state.typeFrame.Border then
        state.typeFrame.Border:Hide()
    end

    state.cards = {}
    local previousCard
    for slotIndex = 1, ClampNumber(groupInfo.total) do
        local card = CreateFrame("Frame", nil, frame, "WeeklyRewardActivityTemplate")
        card:SetFrameStrata(frame:GetFrameStrata())
        card:SetFrameLevel(baseFrameLevel + 200 + slotIndex)
        if type(card.Refresh) ~= "function" and type(WeeklyRewardsActivityMixin) == "table" then
            Mixin(card, WeeklyRewardsActivityMixin)
        end

        card.type = GetRewardTypeForGroup(groupInfo.key)
        card.index = slotIndex

        if previousCard then
            card:SetPoint("LEFT", previousCard, "RIGHT", 9, 0)
        else
            card:SetPoint("LEFT", state.typeFrame, "RIGHT", 44, 3)
        end

        card:SetScript("OnMouseUp", function()
        end)
        card:SetScript("OnEnter", function(self)
            BuildSlotTooltip(self)
        end)
        card:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        HideSelectionState(card)
        NormalizeActivityVisualLayers(card, baseFrameLevel + 200 + slotIndex)

        state.cards[slotIndex] = card
        previousCard = card
    end

    frame.groupFrames[groupInfo.key] = state
end

local function PlayOpenSound()
    if SOUNDKIT and SOUNDKIT.UI_WEEKLY_REWARD_OPEN_WINDOW and PlaySound then
        PlaySound(SOUNDKIT.UI_WEEKLY_REWARD_OPEN_WINDOW)
    end
end

local function PlayCloseSound()
    if SOUNDKIT and SOUNDKIT.UI_WEEKLY_REWARD_CLOSE_WINDOW and PlaySound then
        PlaySound(SOUNDKIT.UI_WEEKLY_REWARD_CLOSE_WINDOW)
    end
end

local function ClearActiveState()
    WeeklyRewardViewer.activeSnapshot = nil
    WeeklyRewardViewer.activeCharacter = nil
    GameTooltip:Hide()
end

local function CreateViewerFrame()
    local frame = CreateFrame("Frame", "mQoL_WeeklyRewardSnapshotFrame", UIParent)
    frame:SetSize(1165, 657)
    frame:SetPoint("CENTER")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    frame:Hide()

    local baseFrameLevel = math.max(frame:GetFrameLevel(), 1)

    AddFrameToEscapeList(frame)

    frame.Background = CreateAtlasTexture(frame, "BACKGROUND", "evergreen-weeklyrewards-frame-back")
    frame.Background:SetPoint("TOPLEFT", 10, -8)
    frame.Background:SetPoint("BOTTOMRIGHT", -10, 8)

    frame.BorderShadow = CreateAtlasTexture(frame, "BORDER", "evergreen-weeklyrewards-frame-back-shadow")
    frame.BorderShadow:SetPoint("TOPLEFT", 10, -8)
    frame.BorderShadow:SetPoint("BOTTOMRIGHT", -10, 8)

    frame.Divider1 = CreateAtlasTexture(frame, "BORDER", "evergreen-weeklyrewards-divider", nil, true)
    frame.Divider1:SetPoint("TOP", 0, -291)

    frame.Divider2 = CreateAtlasTexture(frame, "BORDER", "evergreen-weeklyrewards-divider", nil, true)
    frame.Divider2:SetPoint("TOP", 0, -446)

    frame.HeaderFrame = CreateFrame("Frame", nil, frame)
    frame.HeaderFrame:SetSize(1056, 85)
    frame.HeaderFrame:SetPoint("TOP", 0, -34)
    frame.HeaderFrame:SetFrameStrata(frame:GetFrameStrata())
    frame.HeaderFrame:SetFrameLevel(baseFrameLevel + 300)

    frame.HeaderFrame.Text = frame.HeaderFrame:CreateFontString(nil, "ARTWORK", "SystemFont_Large")
    frame.HeaderFrame.Text:SetPoint("CENTER", frame.HeaderFrame, "CENTER", 0, -3)
    frame.HeaderFrame.Text:SetTextColor(GetColorRGB(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
    if type(frame.HeaderFrame.Text.SetSpacing) == "function" then
        frame.HeaderFrame.Text:SetSpacing(2)
    end

    frame.HeaderFrame.HeaderDivider = CreateAtlasTexture(frame.HeaderFrame, "ARTWORK", "evergreen-weeklyrewards-header", nil, true)
    frame.HeaderFrame.HeaderDivider:SetPoint("TOP", frame.HeaderFrame.Text, "BOTTOM", 0, -14)

    frame.InfoFrame = CreateFrame("Frame", nil, frame)
    frame.InfoFrame:SetAllPoints(frame)
    frame.InfoFrame:SetFrameStrata(frame:GetFrameStrata())
    frame.InfoFrame:SetFrameLevel(baseFrameLevel + 300)

    frame.CharacterText = frame.InfoFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.CharacterText:SetPoint("BOTTOM", frame.HeaderFrame.HeaderDivider, "TOP", 0, 1)
    frame.CharacterText:SetWidth(900)
    frame.CharacterText:SetJustifyH("CENTER")

    frame.SyncText = frame.InfoFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.SyncText:SetPoint("TOP", frame.CharacterText, "BOTTOM", 0, -1)
    frame.SyncText:SetWidth(900)
    frame.SyncText:SetJustifyH("CENTER")

    frame.ModelScene = CreateFrame("ModelScene", nil, frame, "ScriptAnimatedModelSceneTemplate")
    frame.ModelScene:SetAllPoints()
    frame.ModelScene:SetFrameStrata(frame:GetFrameStrata())
    frame.ModelScene:SetFrameLevel(baseFrameLevel + 260)

    frame.BorderContainer = CreateFrame("Frame", nil, frame)
    frame.BorderContainer:SetAllPoints()
    frame.BorderContainer:SetFrameStrata(frame:GetFrameStrata())
    frame.BorderContainer:SetFrameLevel(baseFrameLevel + 1000)

    frame.BorderContainer.Border = CreateAtlasTexture(frame.BorderContainer, "OVERLAY", "evergreen-weeklyrewards-frame", 4)
    frame.BorderContainer.Border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 4)
    frame.BorderContainer.Border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -4)

    frame.BorderContainer.TopDecor = CreateAtlasTexture(frame.BorderContainer, "OVERLAY", "evergreen-weeklyrewards-frame-topdecor", 5, true)
    frame.BorderContainer.TopDecor:SetPoint("CENTER", frame, "TOP", 0, -16)

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", -10, -8)
    frame.CloseButton:SetFrameStrata(frame:GetFrameStrata())
    frame.CloseButton:SetFrameLevel(baseFrameLevel + 2000)
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.groupFrames = {}
    for _, groupInfo in ipairs(GetRetailGroupOrder()) do
        CreateActivityWidgets(frame, groupInfo)
    end

    frame:SetScript("OnShow", function()
        PlayOpenSound()
    end)
    frame:SetScript("OnHide", function()
        PlayCloseSound()
        ClearActiveState()
    end)

    WeeklyRewardViewer.frame = frame
    return frame
end

local function EnsureViewerFrame()
    if WeeklyRewardViewer.frame then
        return WeeklyRewardViewer.frame
    end

    if not EnsureTemplatesLoaded() then
        return nil
    end

    return CreateViewerFrame()
end

local function ApplySnapshotToFrame(frame, snapshot, characterData)
    frame.HeaderFrame.Text:SetText(BuildCharacterLabel(characterData))
    frame.CharacterText:SetText(FormatSyncText(snapshot))
    frame.SyncText:SetText("")

    local groupOrder = GetRetailGroupOrder()
    for _, groupInfo in ipairs(groupOrder) do
        local groupState = frame.groupFrames[groupInfo.key]
        local groupData = type(snapshot.groups) == "table" and snapshot.groups[groupInfo.key] or nil
        local groupSlots = type(groupData) == "table" and type(groupData.slots) == "table" and groupData.slots or {}
        local visual = GetGroupVisual(groupInfo.key)

        if groupState and groupState.typeFrame then
            groupState.typeFrame.Name:SetText(visual.title)
            groupState.typeFrame.Background:SetAtlas(visual.atlas, true)
        end

        if groupState and type(groupState.cards) == "table" then
            for slotIndex = 1, ClampNumber(groupInfo.total) do
                local slotData = type(groupSlots[slotIndex]) == "table" and groupSlots[slotIndex] or BuildDefaultSlot(groupInfo, slotIndex)
                ApplyActivityFrameData(groupState.cards[slotIndex], groupInfo, slotData, slotIndex)
            end
        end
    end
end

function WeeklyRewardViewer.OpenSnapshot(rawValue, characterData)
    if not clientInfo.isRetail then
        Notify("Vault viewer is only available on Retail.")
        return false
    end

    local snapshot = NormalizeSnapshot(rawValue)
    if type(snapshot) ~= "table" or snapshot.kind ~= "great_vault" then
        Notify("No saved Great Vault snapshot is available for this character.")
        return false
    end

    local frame = EnsureViewerFrame()
    if not frame then
        Notify("Could not load Blizzard Weekly Rewards templates.")
        return false
    end

    HideNativeWeeklyRewardsFrame()

    WeeklyRewardViewer.activeSnapshot = snapshot
    WeeklyRewardViewer.activeCharacter = characterData

    ApplySnapshotToFrame(frame, snapshot, characterData)
    frame:Show()
    frame:Raise()
    return true
end