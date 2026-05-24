local addonName, _ = ...
local clientInfo = mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
local utils = mQoL_Utils
local IsInCombat = utils.IsInCombat
local ShallowCopyTable = utils.ShallowCopy
local GetSecondsUntilWeeklyReset = utils.GetSecondsUntilWeeklyReset
local GetSecondsUntilDailyReset = utils.GetSecondsUntilDailyReset
local ParseYMD = utils.ParseYMD
local YMDToEpochDays = utils.YMDToEpochDays
local EpochDaysToYMD = utils.EpochDaysToYMD
local ShiftYMDByDays = utils.ShiftYMDByDays
local DetectRegionForWeeklyReset = utils.DetectRegionForWeeklyReset
local ConvertEUWeeklyYMDToCurrentRegion = utils.ConvertEUWeeklyYMDToCurrentRegion
local GetNextResetTimestamp = utils.GetNextResetTimestamp
local GetYMDTimestampAtReset = utils.GetYMDTimestampAtReset
local GetTodayYMD = utils.GetTodayYMD
local FormatRemainingDuration = utils.FormatRemainingDuration

local function GetSpellCooldownWrapper(spellID)
    -- Use C_Spell.GetSpellCooldown and handle protected secret numbers
    if _G.GetSpellCooldown then
         return _G.GetSpellCooldown(spellID)
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime, info.duration
        end
    end
    return 0, 0
end

local function GetSpellNameWrapper(spellID)
    if not spellID or spellID <= 0 then
        return nil
    end

    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(spellID)
        if name then
            return name
        end
    end

    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name then
            return name
        end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then
            return info.name
        end
    end

    if _G.GetSpellLink then
        local link = _G.GetSpellLink(spellID)
        if link then
            local name = link:match("%[(.-)%]")
            if name and name ~= "" then
                return name
            end
        end
    end

    return nil
end

local function ClearTeleportButtonAction(btn)
    if not btn then
        return
    end

    btn:SetAttribute("type", nil)
    btn:SetAttribute("type1", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("spell1", nil)
end

local function ShouldUseActionButtonKeyDown()
    if _G.GetCVarBool then
        return _G.GetCVarBool("ActionButtonUseKeyDown")
    end
    if _G.GetCVar then
        return tostring(_G.GetCVar("ActionButtonUseKeyDown")) == "1"
    end
    return false
end

local function ConfigureTeleportButtonClicks(btn)
    if not btn or not btn.RegisterForClicks then
        return false
    end

    -- SecureActionButton click registration is protected in combat.
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if ShouldUseActionButtonKeyDown() then
        btn:RegisterForClicks("LeftButtonDown")
    else
        btn:RegisterForClicks("LeftButtonUp")
    end
    return true
end

local function SetTeleportButtonSpellAction(btn, spellID)
    if not btn or not spellID or spellID <= 0 then
        ClearTeleportButtonAction(btn)
        return false
    end

    -- Prefer localized spell name but always fallback to spellID token.
    local spellToken = GetSpellNameWrapper(spellID) or spellID
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("type1", "spell")
    btn:SetAttribute("spell", spellToken)
    btn:SetAttribute("spell1", spellToken)
    return true
end

local function RefreshButtonCooldown(btn)
    if not btn or not btn.cooldown then return end
    if not btn.isKnown or not btn.currentSpellID or btn.currentSpellID <= 0 then
        btn.cooldown:Hide()
        return
    end

    local start, duration = GetSpellCooldownWrapper(btn.currentSpellID)
    if start and duration then
        -- Avoid numeric comparisons here because C_Spell can return protected secret numbers
        btn.cooldown:SetCooldown(start, duration)
        btn.cooldown:Show()
    else
        btn.cooldown:Hide()
    end
end

local function IsTeleportSpellKnown(spellID)
    if not spellID or spellID <= 0 then
        return false
    end

    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then
        return true
    end

    if IsPlayerSpell and IsPlayerSpell(spellID) then
        return true
    end

    if IsSpellKnown and IsSpellKnown(spellID) then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known then
            return true
        end
    end

    return false
end

local function IsAchievementCompletedWrapper(achievementID)
    if not achievementID or achievementID <= 0 then
        return false
    end

    if _G.GetAchievementInfo then
        local ok, _, _, _, completed = pcall(_G.GetAchievementInfo, achievementID)
        if ok and completed ~= nil then
            return completed and true or false
        end
    end

    if C_AchievementInfo and C_AchievementInfo.GetAchievementInfo then
        local ok, info = pcall(C_AchievementInfo.GetAchievementInfo, achievementID)
        if ok and info then
            if info.completed ~= nil then
                return info.completed and true or false
            end
            if info.isCompleted ~= nil then
                return info.isCompleted and true or false
            end
        end
    end

    if C_AchievementInfo and C_AchievementInfo.IsAchievementCompleted then
        local ok, completed = pcall(C_AchievementInfo.IsAchievementCompleted, achievementID)
        if ok and completed ~= nil then
            return completed and true or false
        end
    end

    if C_AchievementInfo and C_AchievementInfo.IsAchievementComplete then
        local ok, completed = pcall(C_AchievementInfo.IsAchievementComplete, achievementID)
        if ok and completed ~= nil then
            return completed and true or false
        end
    end

    return false
end

local function GetTeleportAchievementIDs(entry)
    local achievementIDs = {}
    if type(entry) ~= "table" then
        return achievementIDs
    end

    if type(entry.achievementID) == "number" and entry.achievementID > 0 then
        table.insert(achievementIDs, entry.achievementID)
    end

    if type(entry.achievementIDs) == "table" then
        for _, achievementID in ipairs(entry.achievementIDs) do
            if type(achievementID) == "number" and achievementID > 0 then
                table.insert(achievementIDs, achievementID)
            end
        end
    end

    return achievementIDs
end

local function HasRetailTeleportAchievementUnlock(entry)
    if not clientInfo.isRetail then
        return false
    end

    for _, achievementID in ipairs(GetTeleportAchievementIDs(entry)) do
        if IsAchievementCompletedWrapper(achievementID) then
            return true
        end
    end

    return false
end

local function GetRetailRenownLevel(reputationID)
    if not clientInfo.isRetail or not reputationID or reputationID <= 0 then
        return nil
    end

    if C_MajorFactions and C_MajorFactions.GetCurrentRenownLevel then
        local ok, renownLevel = pcall(C_MajorFactions.GetCurrentRenownLevel, reputationID)
        if ok and type(renownLevel) == "number" and renownLevel >= 0 then
            return renownLevel
        end
    end

    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
        local ok, data = pcall(C_MajorFactions.GetMajorFactionData, reputationID)
        if ok and type(data) == "table" then
            if type(data.renownLevel) == "number" then
                return data.renownLevel
            end
            if type(data.level) == "number" then
                return data.level
            end
        end
    end

    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, data = pcall(C_Reputation.GetFactionDataByID, reputationID)
        if ok and type(data) == "table" then
            if type(data.renownLevel) == "number" then
                return data.renownLevel
            end
            if type(data.currentLevel) == "number" then
                return data.currentLevel
            end
        end
    end

    return nil
end

local function HasRetailTeleportReputationUnlock(entry)
    if not clientInfo.isRetail or type(entry) ~= "table" then
        return false
    end

    local reputationID = entry.reputationID
    local requiredRenown = entry.renownLevel
    if type(reputationID) ~= "number" or reputationID <= 0 then
        return false
    end
    if type(requiredRenown) ~= "number" or requiredRenown <= 0 then
        return false
    end

    local currentRenown = GetRetailRenownLevel(reputationID)
    return type(currentRenown) == "number" and currentRenown >= requiredRenown
end

local function HasRetailTeleportUnlock(entry)
    return HasRetailTeleportAchievementUnlock(entry) or HasRetailTeleportReputationUnlock(entry)
end

local function GetRetailTeleportRequiredLevel(entry)
    if type(entry) == "table" and type(entry.requiredLevel) == "number" and entry.requiredLevel > 0 then
        return entry.requiredLevel
    end

    return 80
end

local function GetRetailTeleportUnavailableReason(entry)
    local playerLevel = UnitLevel and UnitLevel("player") or nil
    local requiredLevel = GetRetailTeleportRequiredLevel(entry)

    if playerLevel and requiredLevel and playerLevel < requiredLevel then
        return string.format("This character must reach level %d to use this portal.", requiredLevel)
    end

    return "This character does not currently meet the requirements to use this portal."
end

local function GetSeasonEndTimestampForDisplay(endsYMD)
    local regionEndsYMD = ConvertEUWeeklyYMDToCurrentRegion(endsYMD)
    local endsNumber = tonumber(regionEndsYMD)
    if not endsNumber then
        return nil
    end

    if endsNumber == GetTodayYMD() then
        local nextDaily = GetNextResetTimestamp("daily")
        if nextDaily then
            return nextDaily
        end
    end

    return GetYMDTimestampAtReset(regionEndsYMD, "weekly")
end

local function GetPostSeasonEndTimestamp(postEndsYMD)
    return GetYMDTimestampAtReset(ConvertEUWeeklyYMDToCurrentRegion(postEndsYMD), "weekly")
end

local function GetSeasonStartTimestamp(startsYMD)
    if not startsYMD then
        return nil
    end
    return GetYMDTimestampAtReset(ConvertEUWeeklyYMDToCurrentRegion(startsYMD), "weekly")
end

local function ResolveObtainableState(obtainable, startsYMD, endsYMD, postEndsYMD)
    if obtainable == false then
        return false
    end

    local now = GetServerTime()
    local startTimestamp = GetSeasonStartTimestamp(startsYMD)
    if startTimestamp and now < startTimestamp then
        return "starts"
    end

    local endTimestamp = endsYMD and GetSeasonEndTimestampForDisplay(endsYMD) or nil
    local postEndTimestamp = postEndsYMD and GetPostSeasonEndTimestamp(postEndsYMD) or nil

    if endTimestamp then
        if now < endTimestamp then
            return "ends"
        end
        if postEndTimestamp and now < postEndTimestamp then
            return "ends"
        end
        return false
    end

    if postEndTimestamp then
        if now < postEndTimestamp then
            return "ends"
        end
        return false
    end

    if obtainable == "starts" or obtainable == "ends" then
        return true
    end

    return obtainable
end

-- Teleport Data Structure
local TeleportCategories = {
    { text = "Midnight Season 1", value = "MID_S1" },
    --{ text = "Midnight Season 2", value = "MID_S2" },
    { separator = true },
    { text = "Midnight", value = "Midnight" },
    { text = "The War Within", value = "The War Within" },
    { text = "Dragonflight", value = "Dragonflight" },
    { text = "Shadowlands", value = "Shadowlands" },
    { text = "Battle for Azeroth", value = "Battle for Azeroth" },
    { text = "Legion", value = "Legion" },
    { text = "Warlords of Draenor", value = "Warlords of Draenor" },
    { text = "Mists of Pandaria", value = "Mists of Pandaria" },
    { text = "Cataclysm", value = "Cataclysm" },
    { text = "Wrath of the Lich King", value = "Wrath of the Lich King" }
}

local TeleportData = {
    ["MID_S1"] = {
        obtainable = "starts",
        starts = 20260325,
        --ends = 20260723, most likely July 2026 (date is speculative)
        --postEnds = 20260806, most likely August 2026 (date is speculative)
        ids = { 658, 1209, 1753, 2526, 2805, 2811, 2874, 2915, },
    },
    ["MID_S2"] = {
        obtainable = false,
        --starts = 20260806, (date is speculative)
        --ends = UNKNOWN,
        --postEnds = UNKNOWN,
        ids = { 2813, 2825, 2859, 2923, },
    },

    ["Midnight"] = {
        { id = 2805, name = "Windrunner Spire", texture = 7464939, artOffsetY = -0.10, spellID = 1254400, achievementID = 61262, requiredLevel = 90, location = "Eversong Woods", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2811, name = "Magisters' Terrace", texture = 7467176, artOffsetY = 0.20, spellID = 1254572, achievementID = 61267, requiredLevel = 90, location = "Eversong Woods", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2874, name = "Maisara Caverns", texture = 7478532, artOffsetY = -0.20, spellID = 1254559, achievementID = 61269, requiredLevel = 90, location = "Zul'Aman", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2915, name = "Nexus-Point Xenas", texture = 7570499, artOffsetY = -0.10, spellID = 1254563, achievementID = 61268, requiredLevel = 90, location = "Voidstorm", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2813, name = "Murder Row", texture = 7467177, spellID = 0, achievementID = 0, requiredLevel = 90, location = "Eversong Woods", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." }, --Not Added Yet
        { id = 2825, name = "Den of Nalorakk", texture = 7478533, spellID = 0, achievementID = 0, requiredLevel = 90, location = "Zul'Aman", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." }, --Not Added Yet
        { id = 2859, name = "The Blinding Vale", texture = 7478531, spellID = 0, achievementID = 0, requiredLevel = 90, location = "Harandar", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." }, --Not Added Yet
        { id = 2923, name = "Voidscar Arena", texture = 7479111, spellID = 0, achievementID = 0, requiredLevel = 90, location = "Voidstorm", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." }, --Not Added Yet
        --{ id = 2912, name = "The Voidspire", texture = 7507134, spellID = 0, achievementID = 0, location = "	Voidstorm", source = "Unknown" }, --Unconfirmed
        --{ id = 2939, name = "The Dreamrift", texture = 7570500, spellID = 0, achievementID = 0, location = "Harandar", source = "Unknown" }, --Unconfirmed
        --{ id = 2913, name = "March on Quel'Danas", texture = 7480125, spellID = 0, achievementID = 0, location = "Eversong Woods", source = "Unknown" }, --Unconfirmed
    },
    ["The War Within"] = {
        { id = 2660, name = "Ara-Kara, City of Echoes", texture = 5912537, artOffsetY = -0.05, spellID = 445417, achievementID = 20586, requiredLevel = 80, location = "Azj-Kahet", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2661, name = "Cinderbrew Meadery", texture = 5912538, artOffsetY = 0.20, spellID = 445440, achievementID = 20583, requiredLevel = 80, location = "Isle of Dorn", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2669, name = "City of Threads", texture = 5912539, artOffsetY = 0.0, spellID = 445416, achievementID = 20582, requiredLevel = 80, location = "Azj-Kahet", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2651, name = "Darkflame Cleft", texture = 5912540, artOffsetY = 0.20, spellID = 445441, achievementID = 20584, requiredLevel = 80, location = "Ringing Deeps", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2649, name = "Priory of the Sacred Flame", texture = 5912542, artOffsetY = -0.10, spellID = 445444, achievementID = 20581, requiredLevel = 80, location = "Hallowfall", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2662, name = "The Dawnbreaker", texture = 5912543, artOffsetY = -0.10, spellID = 445414, achievementID = 20585, requiredLevel = 80, location = "Hallowfall", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2648, name = "The Rookery", texture = 5912544, artOffsetY = 0.0, spellID = 445443, achievementID = 20579, requiredLevel = 80, location = "Isle of Dorn", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2652, name = "The Stonevault", texture = 5912545, artOffsetY = 0.0, spellID = 445269, achievementID = 20580, requiredLevel = 80, location = "Ringing Deeps", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2773, name = "Operation: Floodgate", texture = 6422410, artOffsetY = 0.10, spellID = 1216786, achievementID = 41348, requiredLevel = 80, location = "Ringing Deeps", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2830, name = "Eco-Dome Al'dani", texture = 7074041, artOffsetY = 0.10, spellID = 1237215, achievementID = 42173, requiredLevel = 80, location = "K'aresh", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2769, name = "Liberation of Undermine", texture = 6422409, artOffsetY = 0.0, spellID = 1226482, reputationID = 2685, renownLevel = 20, requiredLevel = 80, location = "Undermine", source = "Reach Renown 20 with Gallagio Loyalty Rewards Club.", obtainable = true },
        { id = 2810, name = "Manaforge Omega", texture = 7049313, artOffsetY = 0.0, spellID = 1239155, reputationID = 2736, renownLevel = 15, requiredLevel = 80, location = "K'aresh", source = "Reach Renown 15 with Manaforge Vandals.", obtainable = true },
    },
    ["Dragonflight"] = {
        { id = 2526, name = "Algeth'ar Academy", texture = 4742939, artOffsetY = 0.0, spellID = 393273, achievementID = 16643, requiredLevel = 80, location = "Thaldraszus", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2520, name = "Brackenhide Hollow", texture = 4742933, artOffsetY = 0.15, spellID = 393267, achievementID = 16642, requiredLevel = 80, location = "Azure Span", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2527, name = "Halls of Infusion", texture = 4742936, artOffsetY = 0.15, spellID = 393283, achievementID = 16646, requiredLevel = 80, location = "Thaldraszus", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2519, name = "Neltharus", texture = 4742938, artOffsetY = 0.0, spellID = 393276, achievementID = 16644, requiredLevel = 80, location = "Waking Shores", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2521, name = "Ruby Life Pools", texture = 4742937, artOffsetY = 0.0, spellID = 393256, achievementID = 16640, requiredLevel = 80, location = "Waking Shores", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2515, name = "The Azure Vault", texture = 4742932, artOffsetY = 0.0, spellID = 393279, achievementID = 16645, requiredLevel = 80, location = "Azure Span", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2516, name = "The Nokhud Offensive", texture = 4742934, artOffsetY = 0.0, spellID = 393262, achievementID = 16641, requiredLevel = 80, location = "Ohn'ahran Plains", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2451, name = "Uldaman: Legacy of Tyr", texture = 4742940, artOffsetY = 0.0, spellID = 393222, achievementID = 16639, requiredLevel = 80, location = "Badlands", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2579, name = "Dawn of the Infinite", texture = 5222376, artOffsetY = 0.0, spellID = 424197, achievementID = 19088, requiredLevel = 80, location = "Thaldraszus", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2522, name = "Vault of the Incarnates", texture = 4742941, artOffsetY = 0.0, spellID = 432254, achievementID = 19576, requiredLevel = 80, location = "Thaldraszus", source = "Complete Achievement Mythic: Awakening the Dragonflight Raids" },
        { id = 2569, name = "Aberrus, the Shadowed Crucible", texture = 5149417, artOffsetY = -0.10, spellID = 432257, achievementID = 19576, requiredLevel = 80, location = "Zaralek Cavern", source = "Complete Achievement Mythic: Awakening the Dragonflight Raids" },
        { id = 2549, name = "Amirdrassil, the Dream's Hope", texture = 5409262, artOffsetY = 0.0, spellID = 432258, achievementID = 19576, requiredLevel = 80, location = "Emerald Dream", source = "Complete Achievement Mythic: Awakening the Dragonflight Raids" },
    },
    ["Shadowlands"] = {
        { id = 2286, name = "The Necrotic Wake", texture = 3759920, artOffsetY = -0.20, spellID = 354462, achievementID = 15045, requiredLevel = 80, location = "Bastion", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2289, name = "Plaguefall", texture = 3759921, artOffsetY = 0.10, spellID = 354463, achievementID = 15046, requiredLevel = 80, location = "Maldraxxus", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2290, name = "Mists of Tirna Scithe", texture = 3759919, artOffsetY = 0.10, spellID = 354464, achievementID = 15047, requiredLevel = 80, location = "Ardenweald", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2287, name = "Halls of Atonement", texture = 3759918, artOffsetY = 0.0, spellID = 354465, achievementID = 15048, requiredLevel = 80, location = "Revendreth", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2293, name = "Theater of Pain", texture = 3759924, artOffsetY = 0.20, spellID = 354467, achievementID = 15050, requiredLevel = 80, location = "Maldraxxus", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2291, name = "De Other Side", texture = 3759925, artOffsetY = 0.0, spellID = 354468, achievementID = 15051, requiredLevel = 80, location = "Ardenweald", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2285, name = "Spires of Ascension", texture = 3759923, artOffsetY = 0.10, spellID = 354466, achievementID = 15049, requiredLevel = 80, location = "Bastion", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2284, name = "Sanguine Depths", texture = 3759922, artOffsetY = 0.10, spellID = 354469, achievementID = 15052, requiredLevel = 80, location = "Revendreth", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2441, name = "Tazavesh, the Veiled Market", texture = 4182024, artOffsetY = 0.10, spellID = 367416, achievementID = 15500, requiredLevel = 80, location = "Tazavesh", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 2296, name = "Castle Nathria", texture = 3759916, artOffsetY = 0.20, spellID = 373190, achievementID = 15687, requiredLevel = 80, location = "Revendreth", source = "Complete Achievement Mythic: Fates of the Shadowlands Raids" },
        { id = 2450, name = "Sanctum of Domination", texture = 4182023, artOffsetY = 0.0, spellID = 373191, achievementID = 15687, requiredLevel = 80, location = "The Maw", source = "Complete Achievement Mythic: Fates of the Shadowlands Raids" },
        { id = 2481, name = "Sepulcher of the First Ones", texture = 4425895, artOffsetY = 0.0, spellID = 373192, achievementID = 15687, requiredLevel = 80, location = "Zereth Mortis", source = "Complete Achievement Mythic: Fates of the Shadowlands Raids" },
    },
    ["Battle for Azeroth"] = {
        { id = 1763, name = "Atal'Dazar", texture = 1778890, artOffsetY = 0.0, spellID = 424187, achievementID = 19087, requiredLevel = 80, location = "Zuldazar", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1754, name = "Freehold", texture = 1778891, artOffsetY = 0.0, spellID = 410071, achievementID = 17848, requiredLevel = 80, location = "Tiragarde Sound", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1822, name = "Siege of Boralus", texture = 2177726, artOffsetY = 0.20, spellIDHorde = 464256, spellIDAlly = 445418, achievementID = 20587, requiredLevel = 80, location = "Tiragarde Sound", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 1594, name = "The Motherlode!!", texture = 2177728, artOffsetY = 0.25, spellIDHorde = 467555, spellIDAlly = 467553, achievementID = 40965, requiredLevel = 80, location = "Zuldazar", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
        { id = 1841, name = "The Underrot", texture = 2177729, artOffsetY = 0.10, spellID = 410074, achievementID = 17849, requiredLevel = 80, location = "Nazmir", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1862, name = "Waycrest Manor", texture = 2177732, artOffsetY = 0.0, spellID = 424167, achievementID = 19086, requiredLevel = 80, location = "Drustvar", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 2097, name = "Operation: Mechagon", texture = 3025327, artOffsetY = 0.20, spellID = 373274, achievementIDs = { 15693, 40966 }, requiredLevel = 80, location = "Mechagon Island", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
    },
    ["Legion"] = {
        { id = 1501, name = "Black Rook Hold", texture = 1411847, artOffsetY = -0.10, spellID = 424153, achievementID = 19084, requiredLevel = 80, location = "Val'sharah", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1571, name = "Court of Stars", texture = 1498152, artOffsetY = 0.10, spellID = 393766, achievementID = 16658, requiredLevel = 80, location = "Suramar", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1466, name = "Darkheart Thicket", texture = 1411849, artOffsetY = 0.20, spellID = 424163, achievementID = 19085, requiredLevel = 80, location = "Val'sharah", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1477, name = "Halls of Valor", texture = 1498154, artOffsetY = -0.10, spellID = 393764, achievementID = 16659, requiredLevel = 80, location = "Stormheim", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1458, name = "Neltharion's Lair", texture = 1450572, artOffsetY = 0.20, spellID = 410078, achievementID = 17850, requiredLevel = 80, location = "Highmountain", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1651, name = "Return to Karazhan", texture = 1537281, artOffsetY = 0.10, spellID = 373262, achievementID = 15692, requiredLevel = 80, location = "Deadwind Pass", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1753, name = "Seat of the Triumvirate", texture = 1718205, artOffsetY = 0.10, spellID=1254551, achievementID = 61270, requiredLevel=90, location="Mac'Aree / Eredar", source="Complete Mythic Keystone on Level 10 or higher within the time limit." },
    },
    ["Warlords of Draenor"] = {
        { id = 1175, name = "Bloodmaul Slag Mines", texture = 1041984, artOffsetY = -0.10, spellID = 159895, achievementID = 8878,  requiredLevel = 80, location = "Frostfire Ridge", source = "Challenge Mode: Gold (Legacy)" },
        { id = 1208, name = "Grimrail Depot", texture = 1041986, artOffsetY = -0.10, spellID = 159900, achievementIDs = { 8890, 15695 }, requiredLevel = 80, location = "Gorgrond", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1195, name = "Iron Docks", texture = 1060546, artOffsetY = -0.10, spellID = 159896, achievementIDs = { 9000, 15694 }, requiredLevel = 80, location = "Gorgrond", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1182, name = "Auchindoun", texture = 1041982, artOffsetY = -0.20, spellID = 159897, achievementID = 8882, requiredLevel = 80, location = "Talador", source = "Challenge Mode: Gold (Legacy)" },
        { id = 1279, name = "The Everbloom", texture = 1060545, spellID = 159901, achievementIDs = { 9004, 19083 }, requiredLevel = 80, location = "Gorgrond", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1176, name = "Shadowmoon Burial Grounds", texture = 1041988, artOffsetY = 0.10, spellID = 159899, achievementIDs = { 8886, 16660 }, requiredLevel = 80, location = "Shadowmoon Valley", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 1358, name = "Upper Blackrock Spire", texture = 1041990, spellID = 159902, achievementID = 8894, requiredLevel = 80, location = "Blackrock Mountain", source = "Challenge Mode: Gold (Legacy)"},
        { id = 1209, name = "Skyreach", texture = 1041989, artOffsetY = -0.20, spellID = 159898, achievementIDs = { 8874, 61272 }, requiredLevel=90, location = "Spires of Arak", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 10 or higher within the time limit." },
    },
    ["Mists of Pandaria"] = {
        { id = 960, name = "Temple of the Jade Serpent", texture = 632283, artOffsetY = 0.10, spellID = 131204, achievementIDs = { 6887, 16661 }, requiredLevel = 80, location = "Jade Forest", source = "Challenge Mode: Gold (Legacy) or Complete Mythic Keystone on Level 20 or higher within the time limit.", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
        { id = 961, name = "Stormstout Brewery", texture = 632282, artOffsetY = 0.0, spellID = 131205, achievementID = 6891, requiredLevel = 80, location = "Valley of the Four Winds", source = "Challenge Mode: Gold (Legacy)", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
        { id = 959, name = "Shado-Pan Monastery", texture = 632281, artOffsetY = -0.10, spellID = 131206, achievementID = 6904, requiredLevel = 80, location = "Kun-Lai Summit", source = "Challenge Mode: Gold (Legacy)", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
        { id = 994, name = "Mogu'shan Palace", texture = 632279, artOffsetY = 0.20, spellID = 131222, achievementID = 6901, requiredLevel = 80, location = "Vale of Eternal Blossoms", source = "Challenge Mode: Gold (Legacy)", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
        { id = 962, name = "Gate of the Setting Sun", texture = 632277, artOffsetY = 0.10, spellID = 131225, achievementID = 6907, requiredLevel = 80, location = "Vale of Eternal Blossoms", source = "Challenge Mode: Gold (Legacy)", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
        { id = 1011, name = "Siege of Niuzao Temple", texture = 643266, artOffsetY = 0.10, spellID = 131228, achievementID = 6919, requiredLevel = 80, location = "Townlong Steppes", source = "Challenge Mode: Gold (Legacy)", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
        { id = 1001, name = "Scarlet Halls", texture = 643265, artOffsetY = 0.0, spellID = 131231, achievementID = 6910, requiredLevel = 80, location = "Tirisfal Glades", source = "Challenge Mode: Gold (Legacy)", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
        { id = 1004, name = "Scarlet Monastery", texture = 608253, artOffsetY = 0.10, spellID = 131229, achievementID = 6913, requiredLevel = 80, location = "Tirisfal Glades", source = "Challenge Mode: Gold (Legacy)", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
        { id = 1007, name = "Scholomance", texture = 608254, artOffsetY = 0.10, spellID = 131232, achievementID = 6916, requiredLevel = 80, location = "Western Plaguelands", source = "Challenge Mode: Gold (Legacy)", sourceClassic = "Complete this dungeon on Challenge Mode with a Gold rating or better.", obtainableClassic = true },
    },
    ["Cataclysm"] = {
        { id = 657, name = "Vortex Pinnacle", texture = 526414, artOffsetY = -0.20, spellID = 410080, achievementID = 17847, requiredLevel = 80, location = "Uldum", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 643, name = "Throne of the Tides", texture = 526413, artOffsetY = 0.10, spellID = 424142, achievementID = 19082, requiredLevel = 80, location = "Vashj'ir", source = "Complete Mythic Keystone on Level 20 or higher within the time limit." },
        { id = 670, name = "Grim Batol", texture = 526406, artOffsetY = 0.20, spellID = 445424, achievementID = 20588, requiredLevel = 80, location = "Twilight Highlands", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
    },
    ["Wrath of the Lich King"] = {
        { id = 658, name = "Pit of Saron", texture = 608249, spellID = 1254555, achievementID = 61271, requiredLevel = 90, location = "Icecrown", source = "Complete Mythic Keystone on Level 10 or higher within the time limit." },
    }
}

local function IsFullTeleportDefinition(entry)
    if type(entry) ~= "table" then
        return false
    end

    return entry.name ~= nil
        or entry.texture ~= nil
        or entry.spellID ~= nil
        or entry.spellIDHorde ~= nil
        or entry.spellIDAlly ~= nil
end

local function IsSeasonCategory(categoryValue)
    if type(categoryValue) ~= "string" then
        return false
    end
    return categoryValue:match("_S%d+$") ~= nil
end

local function FindTeleportDefinitionByIdInCategory(categoryValue, teleportID)
    local categoryData = TeleportData[categoryValue]
    if type(categoryData) ~= "table" then
        return nil
    end

    local entries = categoryData.ids or categoryData
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.id == teleportID and IsFullTeleportDefinition(entry) then
            return entry
        end
    end

    return nil
end

local function GetCategoryEntriesAndMeta(categoryValue)
    local categoryData = TeleportData[categoryValue]
    if type(categoryData) ~= "table" then
        return nil, nil
    end

    if type(categoryData.ids) == "table" then
        return categoryData.ids, {
            obtainable = categoryData.obtainable,
            starts = categoryData.starts,
            ends = categoryData.ends,
            postEnds = categoryData.postEnds,
        }
    end

    return categoryData, nil
end

local function GetTeleportIdFromEntry(entry)
    if type(entry) == "number" then
        return entry
    end
    if type(entry) == "table" then
        return entry.id
    end
    return nil
end

local function MergeTeleportEntry(baseEntry, overrideEntry)
    local merged = ShallowCopyTable(baseEntry)
    if type(overrideEntry) ~= "table" then
        return merged
    end

    for key, value in pairs(overrideEntry) do
        if key ~= "refCategory" then
            merged[key] = value
        end
    end
    return merged
end

local function ApplySeasonMeta(entry, seasonMeta)
    if type(entry) ~= "table" or type(seasonMeta) ~= "table" then
        return entry
    end

    local merged = ShallowCopyTable(entry)

    -- manual obtainable flag on TeleportData always prior
    if merged.obtainable ~= nil then
        return merged
    end

    if seasonMeta.obtainable ~= nil then
        merged.obtainable = seasonMeta.obtainable
        merged.starts = seasonMeta.starts
        merged.ends = seasonMeta.ends
        merged.postEnds = seasonMeta.postEnds
    end

    return merged
end

local function ApplyClientEntryOverrides(entry)
    if type(entry) ~= "table" then
        return entry
    end

    local merged = ShallowCopyTable(entry)

    if clientInfo.isClassic then
        if merged.sourceClassic ~= nil then
            merged.source = merged.sourceClassic
        end
        if merged.obtainableClassic ~= nil then
            merged.obtainable = merged.obtainableClassic
        end
    end

    return merged
end

local function GetSeasonMetaForTeleportId(teleportID)
    if not teleportID then
        return nil
    end

    for _, category in ipairs(TeleportCategories) do
        if category.value and not category.separator and IsSeasonCategory(category.value) then
            local ids, meta = GetCategoryEntriesAndMeta(category.value)
            if type(ids) == "table" and type(meta) == "table" and meta.obtainable ~= nil then
                for _, seasonEntry in ipairs(ids) do
                    local seasonId = GetTeleportIdFromEntry(seasonEntry)
                    if seasonId == teleportID then
                        return meta
                    end
                end
            end
        end
    end

    return nil
end

local function FindTeleportDefinitionById(teleportID, preferredCategory)
    if preferredCategory then
        local preferred = FindTeleportDefinitionByIdInCategory(preferredCategory, teleportID)
        if preferred then
            return preferred
        end
    end

    for _, category in ipairs(TeleportCategories) do
        if category.value and not category.separator and not IsSeasonCategory(category.value) and category.value ~= preferredCategory then
            local entry = FindTeleportDefinitionByIdInCategory(category.value, teleportID)
            if entry then
                return entry
            end
        end
    end

    return nil
end

local function ResolveTeleportEntry(categoryValue, entry, seasonMeta)
    local entryType = type(entry)
    if entryType ~= "number" and entryType ~= "table" then
        return nil
    end

    local resolved
    local teleportID = GetTeleportIdFromEntry(entry)

    if entryType == "number" then
        resolved = FindTeleportDefinitionById(entry)
    elseif IsFullTeleportDefinition(entry) then
        resolved = ShallowCopyTable(entry)
    else
        local refId = entry.id
        local refCategory = entry.refCategory or categoryValue
        if not refId or not refCategory then
            return nil
        end

        local sourceEntry = FindTeleportDefinitionById(refId, refCategory)
        if not sourceEntry then
            return nil
        end

        resolved = MergeTeleportEntry(sourceEntry, entry)
    end

    if not resolved then
        return nil
    end

    local effectiveSeasonMeta = seasonMeta
    if effectiveSeasonMeta == nil then
        effectiveSeasonMeta = GetSeasonMetaForTeleportId(teleportID or resolved.id)
    end

    return ApplyClientEntryOverrides(ApplySeasonMeta(resolved, effectiveSeasonMeta))
end

local function GetDungeonTeleportsTabConfig()
    local isClassicLayout = clientInfo.isClassic and true or false

    return {
        isClassicLayout = isClassicLayout,
        usesNativePVEPanelTabState = not isClassicLayout,
        tabName = isClassicLayout and "DungeonTeleportsClassicTab" or "PVEFrameTab4",
        tabTemplate = isClassicLayout and (_G.PVEFrameTabTemplate and "PVEFrameTabTemplate" or "CharacterFrameTabButtonTemplate") or "PanelTabButtonTemplate",
        tabID = isClassicLayout and 0 or 4,
        tabOffsetX = isClassicLayout and -16 or 6,
        selectedCategoryValue = isClassicLayout and "Mists of Pandaria" or "MID_S1",
        selectedCategoryText = isClassicLayout and "Mists of Pandaria" or "Midnight Season 1",
    }
end

local TELEPORT_IMAGE_CROP_LEFT = 0.05
local TELEPORT_IMAGE_CROP_RIGHT = 0.70
local TELEPORT_IMAGE_CROP_TOP = 0.00
local TELEPORT_IMAGE_CROP_BOTTOM = 0.70
local TELEPORT_CARD_IMAGE_HEIGHT = 63
local TELEPORT_CARD_INFO_HEIGHT = 38
local TELEPORT_CARD_HEIGHT = TELEPORT_CARD_IMAGE_HEIGHT + TELEPORT_CARD_INFO_HEIGHT

-- Per-entry artOffsetY moves the crop window vertically without changing zoom.
local function GetTeleportArtValue(info, fieldName, fallbackFieldName)
    if type(info) ~= "table" then
        return nil
    end

    local value = info[fieldName]
    if type(value) ~= "number" and fallbackFieldName then
        value = info[fallbackFieldName]
    end

    if type(value) == "number" then
        return value
    end

    return nil
end

local function ApplyTeleportImageTexture(btn, info, targetWidth, targetHeight)
    local textureID = info and info.texture
    if not btn or not btn.imageArea or not textureID or textureID <= 0 then
        return
    end

    btn.imageArea:ClearAllPoints()
    btn.imageArea:SetAllPoints(btn.imageContainer)
    btn.imageArea:SetTexture(textureID)

    local left = TELEPORT_IMAGE_CROP_LEFT
    local right = TELEPORT_IMAGE_CROP_RIGHT
    local top = TELEPORT_IMAGE_CROP_TOP
    local bottom = TELEPORT_IMAGE_CROP_BOTTOM

    if targetWidth and targetHeight and targetWidth > 0 and targetHeight > 0 then
        local targetAspect = targetWidth / targetHeight
        local cropWidth = right - left
        local cropHeight = bottom - top
        local cropAspect = cropWidth / cropHeight

        if targetAspect > cropAspect then
            local newHeight = cropWidth / targetAspect
            local offset = (cropHeight - newHeight) * 0.5
            top = top + offset
            bottom = bottom - offset
        elseif targetAspect < cropAspect then
            local newWidth = cropHeight * targetAspect
            local offset = (cropWidth - newWidth) * 0.5
            left = left + offset
            right = right - offset
        end

        local artOffsetY = GetTeleportArtValue(info, "artOffsetY", "artoffsety") or GetTeleportArtValue(info, "artY", "arty")
        if artOffsetY and artOffsetY ~= 0 then
            local height = bottom - top
            local offset = height * artOffsetY
            top = top + offset
            bottom = bottom + offset

            if top < 0 then
                bottom = bottom - top
                top = 0
            elseif bottom > 1 then
                top = top - (bottom - 1)
                bottom = 1
            end
        end
    end

    btn.imageArea:SetTexCoord(left, right, top, bottom)
end

local LISTED_DUNGEON_HIGHLIGHT_TEXTURE = "Interface\\Tooltips\\UI-Tooltip-Border"
local LISTED_DUNGEON_HIGHLIGHT_STRONG_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local LISTED_DUNGEON_HIGHLIGHT_COLOR = { 1.00, 0.82, 0.00, 0.95 }
local LISTED_DUNGEON_TOOLTIP_COLOR = { 1.00, 0.82, 0.00 }
local TELEPORT_POPUP_WIDTH = 360
local TELEPORT_POPUP_HEIGHT = 260
local TELEPORT_POPUP_IMAGE_HEIGHT = 108

local function AddListedDungeonHighlightTooltipLine()
    GameTooltip:AddLine("Your group is listed for this dungeon.", LISTED_DUNGEON_TOOLTIP_COLOR[1], LISTED_DUNGEON_TOOLTIP_COLOR[2], LISTED_DUNGEON_TOOLTIP_COLOR[3], true)
end

local listedDungeonHighlightState = {
    activeTeleportID = nil,
    activeSignature = nil,
    activeSpellIDs = nil,
    activeInfo = nil,
    groupGUID = nil,
    joinedGroupInfo = nil,
    joinedGroupInfoExpires = nil,
    suppressedSignature = nil,
    wasInGroup = false,
    ignoreActiveEntryUntilClear = false,
}

local listedDungeonHighlightListeners = {}
local BuildTeleportSpellIDLookup

local function NotifyListedDungeonHighlightChanged()
    for _, listener in ipairs(listedDungeonHighlightListeners) do
        listener()
    end
end

local function RegisterListedDungeonHighlightListener(listener)
    if type(listener) ~= "function" then
        return
    end

    table.insert(listedDungeonHighlightListeners, listener)
    listener()
end

local function EnsureListedDungeonHighlight(btn)
    if not btn or btn.listedDungeonHighlight then
        return
    end

    local highlight = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    highlight:SetPoint("TOPLEFT", -4, 4)
    highlight:SetPoint("BOTTOMRIGHT", 4, -4)
    highlight:SetFrameLevel(math.max(btn.border and (btn.border:GetFrameLevel() or 0) or 0, btn:GetFrameLevel() or 0) + 2)
    highlight:SetBackdrop({
        edgeFile = LISTED_DUNGEON_HIGHLIGHT_TEXTURE,
        edgeSize = 16,
    })
    highlight:SetBackdropBorderColor(unpack(LISTED_DUNGEON_HIGHLIGHT_COLOR))

    local strongBorder = CreateFrame("Frame", nil, highlight, "BackdropTemplate")
    strongBorder:SetPoint("TOPLEFT", 3, -3)
    strongBorder:SetPoint("BOTTOMRIGHT", -3, 3)
    strongBorder:SetBackdrop({
        edgeFile = LISTED_DUNGEON_HIGHLIGHT_STRONG_TEXTURE,
        edgeSize = 2,
    })
    strongBorder:SetBackdropBorderColor(unpack(LISTED_DUNGEON_HIGHLIGHT_COLOR))
    strongBorder:EnableMouse(false)
    highlight.strongBorder = strongBorder

    highlight:EnableMouse(false)
    highlight:Hide()

    btn.listedDungeonHighlight = highlight
end

local GetCurrentInstanceMapID

local function IsSpellCooldownActive(spellID)
    spellID = tonumber(spellID) or 0
    if spellID <= 0 then
        return false
    end

    local start, duration = GetSpellCooldownWrapper(spellID)
    local ok, isActive = pcall(function()
        start = tonumber(start) or 0
        duration = tonumber(duration) or 0
        return start > 0 and duration > 1.5
    end)

    return ok and isActive
end

local function IsAnyListedDungeonTeleportSpellOnCooldown(primarySpellID)
    if IsSpellCooldownActive(primarySpellID) then
        return true
    end

    for spellID in pairs(listedDungeonHighlightState.activeSpellIDs or {}) do
        if spellID ~= primarySpellID and IsSpellCooldownActive(spellID) then
            return true
        end
    end

    return false
end

local function IsTeleportHighlightedForListedDungeon(teleportID, spellID)
    teleportID = tonumber(teleportID) or 0
    if teleportID <= 0 then
        return false
    end

    local state = listedDungeonHighlightState
    if state.activeTeleportID ~= teleportID
        or state.activeSignature == nil
        or state.activeSignature == state.suppressedSignature then
        return false
    end

    if GetCurrentInstanceMapID and GetCurrentInstanceMapID() == teleportID then
        return false
    end

    if IsAnyListedDungeonTeleportSpellOnCooldown(spellID) then
        return false
    end

    return true
end

local function ApplyListedDungeonHighlight(btn)
    if not btn then
        return
    end

    local isHighlighted = IsTeleportHighlightedForListedDungeon(btn.teleportID, btn.currentSpellID)
    btn.isListedDungeonHighlightActive = isHighlighted

    if btn.listedDungeonHighlight then
        if isHighlighted then
            btn.listedDungeonHighlight:Show()
        else
            btn.listedDungeonHighlight:Hide()
        end
    end
end

BuildTeleportSpellIDLookup = function(teleportID)
    local lookup = {}
    local entry = FindTeleportDefinitionById(teleportID)
    if type(entry) ~= "table" then
        return lookup
    end

    entry = ApplyClientEntryOverrides(entry)

    local function AddSpellID(spellID)
        spellID = tonumber(spellID) or 0
        if spellID > 0 then
            lookup[spellID] = true
        end
    end

    AddSpellID(entry.spellID)
    AddSpellID(entry.spellIDHorde)
    AddSpellID(entry.spellIDAlly)

    return lookup
end

local listedDungeonTeleportPopup
local listedDungeonTeleportPopupKey
local listedDungeonTeleportPopupDeclinedKey

local function GetListedDungeonTeleportPopupKey(info, signature)
    if type(info) ~= "table" then
        return signature
    end

    if info.groupGUID then
        return tostring(signature or "") .. ":" .. tostring(info.groupGUID)
    end

    if info.activityID then
        return tostring(signature or "") .. ":" .. tostring(info.activityID)
    end

    return signature
end

local function GetListedDungeonTeleportPopupTitle(PopupInfo)
    if PopupInfo and PopupInfo == listedDungeonHighlightState.joinedGroupInfo then
        return "You joined a group for"
    end

    return "Your group is listed for"
end

local function GetTeleportSpellIDForPlayer(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if entry.spellIDHorde and entry.spellIDAlly then
        local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
        if faction == "Horde" then
            return entry.spellIDHorde
        end
        return entry.spellIDAlly
    end

    return entry.spellID
end

local function SetTeleportPopupButtonText(button, text)
    if not button then
        return
    end

    if button.text then
        button.text:SetText(text or "")
    elseif button.SetText then
        button:SetText(text or "")
    end
end

local function CreateTeleportPopupButton(parent, text, isSecure)
    local template = isSecure and "SecureActionButtonTemplate" or nil
    local button = CreateFrame("Button", nil, parent, template)
    button:SetSize(132, 24)
    button:EnableMouse(true)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.15, 0.15, 0.15, 1)

    button.border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.border:SetAllPoints()
    button.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button.border:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("CENTER")
    button.text:SetTextColor(0.9, 0.9, 0.9)
    SetTeleportPopupButtonText(button, text)

    button:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.22, 0.22, 0.22, 1)
        self.border:SetBackdropBorderColor(1, 0.82, 0, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
        self.border:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
    end)

    return button
end

local function EnsureListedDungeonTeleportPopup()
    if listedDungeonTeleportPopup then
        return listedDungeonTeleportPopup
    end

    local frame = CreateFrame("Frame", "mQoL_DungeonTeleportPopup", UIParent, "BackdropTemplate")
    frame:SetSize(TELEPORT_POPUP_WIDTH, TELEPORT_POPUP_HEIGHT)
    frame:SetPoint("CENTER", 0, 160)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
    frame:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)

    frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.titleText:SetPoint("TOPLEFT", 10, -10)
    frame.titleText:SetPoint("TOPRIGHT", -10, -10)
    frame.titleText:SetJustifyH("CENTER")
    frame.titleText:SetText("Your group is listed for")

    frame.imageContainer = CreateFrame("Frame", nil, frame)
    frame.imageContainer:SetPoint("TOPLEFT", 10, -32)
    frame.imageContainer:SetPoint("TOPRIGHT", -10, -32)
    frame.imageContainer:SetHeight(TELEPORT_POPUP_IMAGE_HEIGHT)

    frame.imageBg = frame.imageContainer:CreateTexture(nil, "BACKGROUND")
    frame.imageBg:SetAllPoints()
    frame.imageBg:SetColorTexture(0.05, 0.05, 0.05, 1)

    frame.imageArea = frame.imageContainer:CreateTexture(nil, "ARTWORK")
    frame.imageArea:SetAllPoints(frame.imageContainer)

    frame.infoBg = frame:CreateTexture(nil, "ARTWORK")
    frame.infoBg:SetPoint("TOPLEFT", frame.imageContainer, "BOTTOMLEFT", 0, 0)
    frame.infoBg:SetPoint("TOPRIGHT", frame.imageContainer, "BOTTOMRIGHT", 0, 0)
    frame.infoBg:SetHeight(38)
    frame.infoBg:SetColorTexture(0.15, 0.15, 0.15, 0.86)

    frame.nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.nameText:SetPoint("TOPLEFT", frame.infoBg, "TOPLEFT", 8, -5)
    frame.nameText:SetPoint("TOPRIGHT", frame.infoBg, "TOPRIGHT", -8, -5)
    frame.nameText:SetJustifyH("LEFT")
    frame.nameText:SetMaxLines(1)

    frame.locationText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.locationText:SetPoint("BOTTOMLEFT", frame.infoBg, "BOTTOMLEFT", 8, 5)
    frame.locationText:SetPoint("BOTTOMRIGHT", frame.infoBg, "BOTTOMRIGHT", -8, 5)
    frame.locationText:SetJustifyH("LEFT")
    frame.locationText:SetTextColor(0.7, 0.7, 0.7)
    frame.locationText:SetMaxLines(1)

    frame.popupText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.popupText:SetPoint("TOPLEFT", frame.infoBg, "BOTTOMLEFT", 8, -12)
    frame.popupText:SetPoint("TOPRIGHT", frame.infoBg, "BOTTOMRIGHT", -8, -12)
    frame.popupText:SetJustifyH("CENTER")
    frame.popupText:SetText("Do you want to teleport to this dungeon?")

    frame.teleportButton = CreateTeleportPopupButton(frame, "YES", true)
    frame.teleportButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -6, 14)
    ConfigureTeleportButtonClicks(frame.teleportButton)
    frame.teleportButton:SetScript("PostClick", function(self)
        self:GetParent():Hide()
    end)

    frame.cancelButton = CreateTeleportPopupButton(frame, "NO", false)
    frame.cancelButton:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 6, 14)
    frame.cancelButton:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        listedDungeonTeleportPopupDeclinedKey = parent.PopupKey
        parent:Hide()
    end)

    frame:SetScript("OnHide", function(self)
        if not InCombatLockdown or not InCombatLockdown() then
            ClearTeleportButtonAction(self.teleportButton)
        end
    end)
    frame:Hide()

    listedDungeonTeleportPopup = frame
    return frame
end

local function HideListedDungeonTeleportPopup(signature)
    local frame = listedDungeonTeleportPopup
    if not frame or not frame:IsShown() then
        return
    end

    if not signature or frame.signature == signature then
        frame:Hide()
    end
end

local function ShowListedDungeonTeleportPopup(entry, spellID, signature, PopupKey, titleText)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    local frame = EnsureListedDungeonTeleportPopup()
    frame.signature = signature
    frame.PopupKey = PopupKey
    frame.teleportID = entry.id
    frame.spellID = spellID

    frame.nameText:SetText(entry.name or "Dungeon Teleport")
    frame.locationText:SetText(entry.location or "Unknown Location")
    frame.titleText:SetText(titleText or "Your group is listed for")
    frame.popupText:SetText("Do you want to teleport to this dungeon?")
    ApplyTeleportImageTexture(frame, entry, TELEPORT_POPUP_WIDTH - 20, TELEPORT_POPUP_IMAGE_HEIGHT)

    ConfigureTeleportButtonClicks(frame.teleportButton)
    if not SetTeleportButtonSpellAction(frame.teleportButton, spellID) then
        return false
    end

    frame:Show()
    return true
end

local function MaybeShowListedDungeonTeleportPopup()
    local state = listedDungeonHighlightState
    local PopupInfo = state.joinedGroupInfo or state.activeInfo
    local signature = state.activeSignature
    local teleportID = state.activeTeleportID

    if type(PopupInfo) ~= "table" or not signature or not teleportID then
        HideListedDungeonTeleportPopup()
        return
    end
    if PopupInfo.signature ~= signature then
        return
    end
    local PopupKey = GetListedDungeonTeleportPopupKey(PopupInfo, signature)
    if signature == state.suppressedSignature or PopupKey == listedDungeonTeleportPopupDeclinedKey then
        HideListedDungeonTeleportPopup(signature)
        return
    end
    if PopupKey == listedDungeonTeleportPopupKey then
        return
    end

    local entry = FindTeleportDefinitionById(teleportID)
    if type(entry) ~= "table" then
        return
    end
    entry = ApplyClientEntryOverrides(entry)

    local spellID = GetTeleportSpellIDForPlayer(entry)
    if not IsTeleportSpellKnown(spellID) or not IsTeleportHighlightedForListedDungeon(teleportID, spellID) then
        return
    end

    if ShowListedDungeonTeleportPopup(entry, spellID, signature, PopupKey, GetListedDungeonTeleportPopupTitle(PopupInfo)) then
        listedDungeonTeleportPopupKey = PopupKey
    end
end

local function IsDungeonListingActivity(activityInfo)
    if type(activityInfo) ~= "table" then
        return false
    end

    local dungeonCategoryID = GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2
    return activityInfo.categoryID == dungeonCategoryID
        or activityInfo.isMythicPlusActivity
        or activityInfo.isMythicActivity
end

local function BuildListedDungeonInfoFromActivity(activityID, questID, groupGUID)
    if not C_LFGList or not C_LFGList.GetActivityInfoTable then
        return nil
    end

    activityID = tonumber(activityID) or 0
    if activityID <= 0 then
        return nil
    end

    local okActivity, activityInfo = pcall(C_LFGList.GetActivityInfoTable, activityID, questID)
    if not okActivity or not IsDungeonListingActivity(activityInfo) then
        return nil
    end

    local teleportID = tonumber(activityInfo.mapID) or 0
    if teleportID <= 0 or not FindTeleportDefinitionById(teleportID) then
        return nil
    end

    return {
        teleportID = teleportID,
        activityID = activityID,
        groupGUID = groupGUID,
        signature = tostring(teleportID),
    }
end

local function BuildListedDungeonInfoFromActivityIDs(activityIDs, questID, groupGUID)
    if type(activityIDs) ~= "table" then
        local activityID = tonumber(activityIDs)
        activityIDs = activityID and { activityID } or nil
    end
    if type(activityIDs) ~= "table" then
        return nil
    end

    for _, activityID in ipairs(activityIDs) do
        local info = BuildListedDungeonInfoFromActivity(activityID, questID, groupGUID)
        if info then
            return info
        end
    end

    return nil
end

local function GetActiveListedDungeonInfo()
    if not C_LFGList or not C_LFGList.GetActiveEntryInfo or not C_LFGList.GetActivityInfoTable then
        return nil, false
    end

    if C_LFGList.HasActiveEntryInfo then
        local okHasActive, hasActive = pcall(C_LFGList.HasActiveEntryInfo)
        if okHasActive and not hasActive then
            return nil, false
        end
    end

    local okEntry, activeEntryInfo = pcall(C_LFGList.GetActiveEntryInfo)
    if not okEntry or type(activeEntryInfo) ~= "table" then
        return nil, false
    end

    local activityIDs = activeEntryInfo.activityIDs
    if type(activityIDs) ~= "table" then
        local activityID = tonumber(activeEntryInfo.activityID)
        activityIDs = activityID and { activityID } or nil
    end
    if type(activityIDs) ~= "table" then
        return nil, true
    end

    local info = BuildListedDungeonInfoFromActivityIDs(activityIDs, activeEntryInfo.questID, activeEntryInfo.partyGUID)
    if info then
        return info, true
    end

    return nil, true
end

local function GetSearchResultListedDungeonInfo(searchResultID)
    if not C_LFGList or not C_LFGList.GetSearchResultInfo then
        return nil
    end

    searchResultID = tonumber(searchResultID) or 0
    if searchResultID <= 0 then
        return nil
    end

    if C_LFGList.HasSearchResultInfo then
        local okHasInfo, hasInfo = pcall(C_LFGList.HasSearchResultInfo, searchResultID)
        if okHasInfo and not hasInfo then
            return nil
        end
    end

    local okResult, searchResultInfo = pcall(C_LFGList.GetSearchResultInfo, searchResultID)
    if not okResult or type(searchResultInfo) ~= "table" then
        return nil
    end

    return BuildListedDungeonInfoFromActivityIDs(
        searchResultInfo.activityIDs or searchResultInfo.activityID,
        searchResultInfo.questID,
        searchResultInfo.partyGUID
    )
end

local function CaptureJoinedListedDungeonInfo(searchResultID)
    local info = GetSearchResultListedDungeonInfo(searchResultID)
    if info then
        listedDungeonHighlightState.joinedGroupInfo = info
        listedDungeonHighlightState.joinedGroupInfoExpires = (GetTime and GetTime() or 0) + 180
        return true
    end

    return false
end

local inactiveApplicationStatuses = {
    cancelled = true,
    failed = true,
    declined = true,
    declined_full = true,
    declined_delisted = true,
    timedout = true,
    invitedeclined = true,
}

local joinedApplicationStatuses = {
    invited = true,
    inviteaccepted = true,
}

local function ResetListedDungeonHighlightState(keepSuppressedSignature, keepJoinedGroupInfo)
    local hadState = listedDungeonHighlightState.activeSignature ~= nil
        or listedDungeonHighlightState.activeInfo ~= nil
        or listedDungeonHighlightState.groupGUID ~= nil
        or (not keepJoinedGroupInfo and listedDungeonHighlightState.joinedGroupInfo ~= nil)
        or (not keepSuppressedSignature and listedDungeonHighlightState.suppressedSignature ~= nil)

    listedDungeonHighlightState.activeTeleportID = nil
    listedDungeonHighlightState.activeSignature = nil
    listedDungeonHighlightState.activeSpellIDs = nil
    listedDungeonHighlightState.activeInfo = nil
    listedDungeonHighlightState.groupGUID = nil
    if not keepJoinedGroupInfo then
        listedDungeonHighlightState.joinedGroupInfo = nil
        listedDungeonHighlightState.joinedGroupInfoExpires = nil
    end
    if not keepSuppressedSignature then
        listedDungeonHighlightState.suppressedSignature = nil
    end

    return hadState
end

local function SetActiveListedDungeonHighlight(info)
    if type(info) ~= "table" or not info.teleportID or not info.signature then
        return ResetListedDungeonHighlightState()
    end

    local state = listedDungeonHighlightState
    local changed = false

    if info.groupGUID and state.groupGUID and info.groupGUID ~= state.groupGUID then
        state.suppressedSignature = nil
        changed = true
    elseif state.suppressedSignature and state.suppressedSignature ~= info.signature then
        state.suppressedSignature = nil
        changed = true
    end

    if state.activeTeleportID ~= info.teleportID then
        state.activeTeleportID = info.teleportID
        changed = true
    end

    if state.activeSignature ~= info.signature then
        state.activeSignature = info.signature
        changed = true
    end

    if state.groupGUID ~= info.groupGUID then
        state.groupGUID = info.groupGUID
        changed = true
    end

    state.activeInfo = info

    if changed or not state.activeSpellIDs then
        state.activeSpellIDs = BuildTeleportSpellIDLookup(info.teleportID)
    end

    return changed
end

local function IsPlayerInAnyGroup()
    if not IsInGroup then
        return false
    end

    if LE_PARTY_CATEGORY_HOME then
        return IsInGroup(LE_PARTY_CATEGORY_HOME)
    end

    return IsInGroup()
end

local function UpdateListedDungeonHighlightState()
    local state = listedDungeonHighlightState
    local isInGroup = IsPlayerInAnyGroup()
    local changed = false
    local now = GetTime and GetTime() or 0

    if state.joinedGroupInfoExpires and now > state.joinedGroupInfoExpires then
        state.joinedGroupInfo = nil
        state.joinedGroupInfoExpires = nil
    end

    if state.wasInGroup and not isInGroup then
        state.ignoreActiveEntryUntilClear = true
        changed = ResetListedDungeonHighlightState() or changed
        state.wasInGroup = false
        if changed then
            NotifyListedDungeonHighlightChanged()
        end
        return
    end
    state.wasInGroup = isInGroup
    if isInGroup then
        state.ignoreActiveEntryUntilClear = false
    end

    local info, hasActiveEntry = GetActiveListedDungeonInfo()
    if state.ignoreActiveEntryUntilClear then
        if hasActiveEntry then
            changed = ResetListedDungeonHighlightState() or changed
            if changed then
                NotifyListedDungeonHighlightChanged()
            end
            return
        end
        state.ignoreActiveEntryUntilClear = false
    end

    if info then
        changed = SetActiveListedDungeonHighlight(info) or changed
    elseif isInGroup and state.joinedGroupInfo then
        changed = SetActiveListedDungeonHighlight(state.joinedGroupInfo) or changed
    elseif not isInGroup then
        changed = ResetListedDungeonHighlightState(nil, true) or changed
    end

    if changed then
        NotifyListedDungeonHighlightChanged()
    end
end

GetCurrentInstanceMapID = function()
    if IsInInstance then
        local inInstance = IsInInstance()
        if not inInstance then
            return nil
        end
    end

    if not GetInstanceInfo then
        return nil
    end

    local _, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    instanceMapID = tonumber(instanceMapID) or 0
    if instanceMapID <= 0 or instanceType == "none" then
        return nil
    end

    return instanceMapID
end

local function SuppressListedDungeonHighlightForCurrentInstance()
    local state = listedDungeonHighlightState
    local instanceMapID = GetCurrentInstanceMapID()
    if not instanceMapID or not state.activeTeleportID or not state.activeSignature then
        return
    end

    if instanceMapID ~= state.activeTeleportID then
        return
    end

    if state.suppressedSignature ~= state.activeSignature then
        state.suppressedSignature = state.activeSignature
        NotifyListedDungeonHighlightChanged()
    end
end

local function SuppressListedDungeonHighlightForSpell(spellID)
    spellID = tonumber(spellID) or 0
    local state = listedDungeonHighlightState
    if spellID <= 0 or not state.activeSignature or not state.activeSpellIDs or not state.activeSpellIDs[spellID] then
        return
    end

    if state.suppressedSignature ~= state.activeSignature then
        state.suppressedSignature = state.activeSignature
        NotifyListedDungeonHighlightChanged()
    end
end

local function ExtractSpellIDFromSpellcastEvent(...)
    for index = select("#", ...), 1, -1 do
        local value = select(index, ...)
        if type(value) == "number" and value > 0 then
            return value
        end
    end

    return nil
end

local listedDungeonHighlightEventFrame = CreateFrame("Frame")
local function RegisterListedDungeonHighlightEvent(eventName)
    pcall(listedDungeonHighlightEventFrame.RegisterEvent, listedDungeonHighlightEventFrame, eventName)
end

RegisterListedDungeonHighlightEvent("PLAYER_ENTERING_WORLD")
RegisterListedDungeonHighlightEvent("ZONE_CHANGED_NEW_AREA")
RegisterListedDungeonHighlightEvent("GROUP_ROSTER_UPDATE")
RegisterListedDungeonHighlightEvent("PARTY_LEADER_CHANGED")
RegisterListedDungeonHighlightEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
RegisterListedDungeonHighlightEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
RegisterListedDungeonHighlightEvent("LFG_LIST_JOINED_GROUP")
RegisterListedDungeonHighlightEvent("UNIT_SPELLCAST_SUCCEEDED")
RegisterListedDungeonHighlightEvent("PLAYER_REGEN_ENABLED")

listedDungeonHighlightEventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit == "player" then
            SuppressListedDungeonHighlightForSpell(ExtractSpellIDFromSpellcastEvent(...))
            HideListedDungeonTeleportPopup(listedDungeonHighlightState.activeSignature)
        end
        return
    end

    if event == "LFG_LIST_JOINED_GROUP" then
        CaptureJoinedListedDungeonInfo(...)
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local searchResultID, newStatus = ...
        if joinedApplicationStatuses[newStatus] then
            CaptureJoinedListedDungeonInfo(searchResultID)
        elseif inactiveApplicationStatuses[newStatus] then
            listedDungeonHighlightState.joinedGroupInfo = nil
            listedDungeonHighlightState.joinedGroupInfoExpires = nil
        end
    end

    UpdateListedDungeonHighlightState()
    SuppressListedDungeonHighlightForCurrentInstance()
    if not IsPlayerInAnyGroup() and not listedDungeonHighlightState.activeSignature then
        listedDungeonTeleportPopupKey = nil
        listedDungeonTeleportPopupDeclinedKey = nil
    end
    MaybeShowListedDungeonTeleportPopup()
end)

UpdateListedDungeonHighlightState()
SuppressListedDungeonHighlightForCurrentInstance()

local function InitDungeonTeleportsTabClassic()
    local config = GetDungeonTeleportsTabConfig()
    if _G[config.tabName] then return end
    if not PVEFrame or not PVEFrameTab3 then return end

    local tabName = config.tabName
    local isClassicLayout = config.isClassicLayout
    local usesNativePVEPanelTabState = config.usesNativePVEPanelTabState
    local pendingCategoryValue
    local pendingCategoryText
    local pendingHideAfterCombat = false
    local isClassicCombatSuspended = false
    local selectedCategoryValue = config.selectedCategoryValue
    local selectedCategoryText = config.selectedCategoryText
    local availableCategories = {}
    local dropdown
    local InitializeDropdown

    local function GetCategoryTextByValue(value, categories, useDynamicText)
        local source = categories or availableCategories
        for _, cat in ipairs(source) do
            if cat.value == value then
                if useDynamicText and cat.dynamicText then
                    return cat.dynamicText
                end
                return cat.text
            end
        end
        return tostring(value or "")
    end

    local function GetSeasonCategoryBaseName(cat)
        local text = tostring(cat and cat.text or "")
        text = text:gsub("%s+[Pp]ost%-?[Ss]eason%s+%d+.*$", "")
        text = text:gsub("%s+[Ss]eason%s+%d+.*$", "")
        text = text:match("^%s*(.-)%s*$")
        if text and text ~= "" then
            return text
        end

        local value = tostring(cat and cat.value or "")
        local fallback = value:match("^(.-)_S%d+$")
        if fallback and fallback ~= "" then
            return fallback
        end
        return value
    end

    local function BuildSeasonCategoryState(cat)
        if not cat or not cat.value or not IsSeasonCategory(cat.value) then
            return true, cat and cat.text
        end

        local seasonNumber = tostring(cat.value):match("_S(%d+)$") or "?"
        local seasonName = GetSeasonCategoryBaseName(cat)
        local _, seasonMeta = GetCategoryEntriesAndMeta(cat.value)
        if type(seasonMeta) ~= "table" then
            return true, string.format("%s Season %s", seasonName, seasonNumber)
        end

        local now = GetServerTime()
        local state = ResolveObtainableState(seasonMeta.obtainable, seasonMeta.starts, seasonMeta.ends, seasonMeta.postEnds)

        if state == "starts" then
            local startsText = "Start date unavailable"
            if seasonMeta.starts then
                local startTimestamp = GetSeasonStartTimestamp(seasonMeta.starts)
                if startTimestamp then
                    local remaining = startTimestamp - now
                    if remaining > 0 then
                        startsText = "Starts in " .. FormatRemainingDuration(remaining)
                    else
                        startsText = "Started"
                    end
                end
            end

            return true, string.format("%s Season %s - %s", seasonName, seasonNumber, startsText)
        end

        if state == "ends" then
            local endTimestamp = seasonMeta.ends and GetSeasonEndTimestampForDisplay(seasonMeta.ends) or nil
            local postEndTimestamp = seasonMeta.postEnds and GetPostSeasonEndTimestamp(seasonMeta.postEnds) or nil

            if endTimestamp and endTimestamp > now then
                return true, string.format("%s Season %s - Ends in %s", seasonName, seasonNumber, FormatRemainingDuration(endTimestamp - now))
            end

            if postEndTimestamp and postEndTimestamp > now then
                return true, string.format("%s Post-Season %s - Ends in %s", seasonName, seasonNumber, FormatRemainingDuration(postEndTimestamp - now))
            end

            return false, nil
        end

        if state == false then
            return false, nil
        end

        return true, string.format("%s Season %s", seasonName, seasonNumber)
    end

    local function BuildVisibleCategories()
        if isClassicLayout then
            return {
                { text = "Mists of Pandaria", dynamicText = "Mists of Pandaria", value = "Mists of Pandaria" },
            }
        end

        local result = {}

        for _, cat in ipairs(TeleportCategories) do
            if cat.separator then
                table.insert(result, { separator = true })
            else
                local isVisible, dynamicText = BuildSeasonCategoryState(cat)
                if isVisible then
                    table.insert(result, { text = cat.text, dynamicText = dynamicText or cat.text, value = cat.value })
                end
            end
        end

        local cleaned = {}
        local previousWasSeparator = true
        for _, cat in ipairs(result) do
            if cat.separator then
                if not previousWasSeparator then
                    table.insert(cleaned, cat)
                    previousWasSeparator = true
                end
            else
                table.insert(cleaned, cat)
                previousWasSeparator = false
            end
        end

        if #cleaned > 0 and cleaned[#cleaned].separator then
            table.remove(cleaned, #cleaned)
        end

        return cleaned
    end

    local function GetFirstSelectableCategory(categories)
        for _, cat in ipairs(categories or {}) do
            if not cat.separator and cat.value then
                return cat.value
            end
        end
        return nil
    end

    local function IsCategoryAvailable(value, categories)
        for _, cat in ipairs(categories or {}) do
            if not cat.separator and cat.value == value then
                return true
            end
        end
        return false
    end

    local function RefreshCategoryOptions(preferredValue)
        local rebuilt = BuildVisibleCategories()
        availableCategories = rebuilt

        if preferredValue and IsCategoryAvailable(preferredValue, availableCategories) then
            selectedCategoryValue = preferredValue
        elseif not IsCategoryAvailable(selectedCategoryValue, availableCategories) then
            selectedCategoryValue = GetFirstSelectableCategory(availableCategories) or selectedCategoryValue
        end
        selectedCategoryText = GetCategoryTextByValue(selectedCategoryValue, availableCategories, true)

        if dropdown then
            if dropdown.SetList then
                dropdown:SetList(availableCategories)
                dropdown:SetValue(selectedCategoryValue)
            elseif UIDropDownMenu_Initialize and InitializeDropdown then
                UIDropDownMenu_Initialize(dropdown, InitializeDropdown)
                UIDropDownMenu_SetText(dropdown, GetCategoryTextByValue(selectedCategoryValue, availableCategories, false))
            end
        end
    end

    -- Create the new tab
    local tab = CreateFrame("Button", tabName, PVEFrame, config.tabTemplate)
    tab:SetID(config.tabID)
    tab:SetText("Dungeon Teleports")
    if PanelTemplates_TabResize then
        PanelTemplates_TabResize(tab, 0)
    end
    tab:SetPoint("LEFT", PVEFrameTab3, "RIGHT", config.tabOffsetX, 0)
    tab:Show()
    if PanelTemplates_DeselectTab then
        PanelTemplates_DeselectTab(tab)
    end

    -- Create the content frame
    local contentFrame = CreateFrame("Frame", "DungeonTeleportsFrame", PVEFrame)
    contentFrame:SetAllPoints(PVEFrame)
    contentFrame:Hide()

    if isClassicLayout then
        local referenceFrame = GroupFinderFrame or PVPQueueFrame or ChallengesFrame or PVEFrame
        if referenceFrame then
            contentFrame:SetFrameStrata(referenceFrame:GetFrameStrata())
            contentFrame:SetFrameLevel(math.max((referenceFrame:GetFrameLevel() or 3) - 2, 1))
        end
    end

    -- Title
    local title = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 70, -35)
    title:SetText(selectedCategoryText)

    -- Background Inset
    local inset = CreateFrame("Frame", "$parentInset", contentFrame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", inset)
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 10)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(inset:GetWidth()-30, 500)
    scrollFrame:SetScrollChild(scrollChild)
    contentFrame.scrollChild = scrollChild
    contentFrame.buttons = {}
    contentFrame.cooldownRefreshPending = false
    RegisterListedDungeonHighlightListener(function()
        for _, btn in pairs(contentFrame.buttons) do
            ApplyListedDungeonHighlight(btn)
        end
    end)

    local classicCombatBlocker
    if isClassicLayout then
        classicCombatBlocker = CreateFrame("Frame", nil, inset)
        classicCombatBlocker:SetAllPoints(scrollFrame)
        classicCombatBlocker:EnableMouse(true)
        classicCombatBlocker:SetFrameStrata(scrollFrame:GetFrameStrata())
        classicCombatBlocker:SetFrameLevel(scrollFrame:GetFrameLevel() + 20)
        classicCombatBlocker:Hide()
    end

    -- Custom Scrollbar (from mQoL Addon Styles)
    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        mQoL_Styles.CreateCustomScrollbar(scrollFrame, scrollChild)
    end

    local function OnButtonEnter(self)
        self.border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        if self.teleportName then
            GameTooltip:AddLine(self.teleportName, 1, 1, 1)
        end
        if self.teleportLocation then
            GameTooltip:AddLine(self.teleportLocation, 0.7, 0.7, 0.7)
        end
        if self.isListedDungeonHighlightActive then
            AddListedDungeonHighlightTooltipLine()
        end

        if not self.isKnown then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("How to obtain:", 1, 0.82, 0)
            local tooltipObtainable = ResolveObtainableState(self.teleportObtainable, self.teleportStarts, self.teleportEnds, self.teleportPostEnds)

            if tooltipObtainable == false then
                GameTooltip:AddLine("NOT CURRENTLY OBTAINABLE", 1, 0, 0)
            elseif tooltipObtainable == "starts" then
                local startTimestamp = GetSeasonStartTimestamp(self.teleportStarts)
                if startTimestamp then
                    local remaining = startTimestamp - GetServerTime()
                    if remaining > 0 then
                        GameTooltip:AddLine("Season starts in " .. FormatRemainingDuration(remaining), 1, 1, 0)
                    else
                        GameTooltip:AddLine("Season Started", 0, 1, 0)
                    end
                else
                    GameTooltip:AddLine("Season start date unavailable", 1, 0.5, 0.25)
                end
            elseif tooltipObtainable == "ends" then
                local text = "Season ends in"
                local endTimestamp = self.teleportEnds and GetSeasonEndTimestampForDisplay(self.teleportEnds) or nil
                local postEndTimestamp = self.teleportPostEnds and GetPostSeasonEndTimestamp(self.teleportPostEnds) or nil
                local currentTime = GetServerTime()
                local remaining = endTimestamp and (endTimestamp - currentTime) or nil
                if remaining and remaining > 0 then
                    text = text .. " " .. FormatRemainingDuration(remaining)
                else
                    local postRemaining = postEndTimestamp and (postEndTimestamp - currentTime) or nil
                    if postRemaining and postRemaining > 0 then
                        text = "Post-season ends in " .. FormatRemainingDuration(postRemaining)
                    else
                        text = "NOT CURRENTLY OBTAINABLE"
                    end
                end
                GameTooltip:AddLine(text, 1, 0, 0)
            end

            if self.teleportSource then
                GameTooltip:AddLine(self.teleportSource, 1, 1, 1, true)
            else
                GameTooltip:AddLine("Complete Mythic Keystone on Level 10 or higher within the time limit.", 1, 1, 1, true)
            end
        end

        GameTooltip:Show()
    end

    local function OnButtonLeave(self)
        self.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        GameTooltip:Hide()
    end

    local function RefreshVisibleButtonCooldowns()
        if not contentFrame:IsShown() then
            return
        end
        for _, btn in pairs(contentFrame.buttons) do
            if btn:IsShown() then
                RefreshButtonCooldown(btn)
            end
        end
    end

    local function QueueCooldownRefresh()
        if contentFrame.cooldownRefreshPending then
            return
        end

        contentFrame.cooldownRefreshPending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                contentFrame.cooldownRefreshPending = false
                RefreshVisibleButtonCooldowns()
            end)
        else
            contentFrame.cooldownRefreshPending = false
            RefreshVisibleButtonCooldowns()
        end
    end

    -- Functions
    local function UpdateTeleportList(categoryValue)
        if IsInCombat() then
            return false
        end

        -- Clear existing buttons
        for _, btn in pairs(contentFrame.buttons) do
            btn:Hide()
        end

        local data, seasonMeta = GetCategoryEntriesAndMeta(categoryValue)
        if not data then return true end

        local resolvedData = {}
        for _, entry in ipairs(data) do
            local resolvedEntry = ResolveTeleportEntry(categoryValue, entry, seasonMeta)
            if resolvedEntry then
                table.insert(resolvedData, resolvedEntry)
            end
        end

        -- Card Style Layout
        local availableWidth = scrollChild:GetWidth() or 520
        local cols = 3
        local marginX = 10
        local marginY = 10
        local startX = 10
        local startY = -10

        local btnWidth = (availableWidth - (cols - 1) * marginX - 2 * startX) / cols
        local btnHeight = TELEPORT_CARD_HEIGHT
        local imageHeight = TELEPORT_CARD_IMAGE_HEIGHT

        for i, info in ipairs(resolvedData) do
            if not contentFrame.buttons[i] then
                local btn = CreateFrame("Button", nil, scrollChild, "SecureActionButtonTemplate")
                btn:SetSize(btnWidth, btnHeight)
                ConfigureTeleportButtonClicks(btn)

                -- Card Background
                btn.bg = btn:CreateTexture(nil, "BACKGROUND")
                btn.bg:SetAllPoints()
                btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

                -- Border
                btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
                btn.border:SetAllPoints()
                btn.border:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                btn.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                EnsureListedDungeonHighlight(btn)

                -- Image Section
                btn.imageContainer = btn:CreateTexture(nil, "BACKGROUND")
                btn.imageContainer:SetPoint("TOPLEFT", 0, 0)
                btn.imageContainer:SetPoint("TOPRIGHT", 0, 0)
                btn.imageContainer:SetHeight(imageHeight)
                btn.imageContainer:SetColorTexture(0.05, 0.05, 0.05, 1)

                btn.imageArea = btn:CreateTexture(nil, "ARTWORK")
                btn.imageArea:SetPoint("CENTER", btn.imageContainer, "CENTER")
                btn.imageArea:SetSize(imageHeight, imageHeight)
                btn.imageArea:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                -- Info Section (Instance Name and Location)
                btn.infoBg = btn:CreateTexture(nil, "ARTWORK")
                btn.infoBg:SetPoint("TOPLEFT", 0, -imageHeight)
                btn.infoBg:SetPoint("BOTTOMRIGHT", 0, 0)
                btn.infoBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

                -- Name
                btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                btn.nameText:SetPoint("TOPLEFT", btn.infoBg, "TOPLEFT", 5, -5)
                btn.nameText:SetPoint("TOPRIGHT", btn.infoBg, "TOPRIGHT", -5, -5)
                btn.nameText:SetJustifyH("LEFT")
                btn.nameText:SetJustifyV("TOP")
                btn.nameText:SetWordWrap(false)
                btn.nameText:SetMaxLines(1)

                -- Location
                btn.locText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.locText:SetPoint("BOTTOMLEFT", btn.infoBg, "BOTTOMLEFT", 5, 5)
                btn.locText:SetPoint("BOTTOMRIGHT", btn.infoBg, "BOTTOMRIGHT", -5, 5)
                btn.locText:SetJustifyH("LEFT")
                btn.locText:SetTextColor(0.7, 0.7, 0.7)
                btn.locText:SetMaxLines(1)

                -- Hover Effect
                btn:SetScript("OnEnter", OnButtonEnter)
                btn:SetScript("OnLeave", OnButtonLeave)

                contentFrame.buttons[i] = btn
            end

            local btn = contentFrame.buttons[i]

            -- Ensure cooldown frame exists
            if not btn.cooldown then
                btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                btn.cooldown:SetAllPoints(btn)
                btn.cooldown:SetDrawEdge(false)
                if btn.cooldown.SetDrawBling then
                    btn.cooldown:SetDrawBling(false)
                end
                if btn.cooldown.EnableMouse then
                    btn.cooldown:EnableMouse(false)
                end
                btn.cooldown:SetHideCountdownNumbers(false)

                for _, region in ipairs({btn.cooldown:GetRegions()}) do
                    if region:GetObjectType() == "FontString" then
                        region:SetTextColor(1, 0.82, 0)
                    end
                end
            end

            -- Update Size
            btn:SetSize(btnWidth, btnHeight)
            btn.imageContainer:SetHeight(imageHeight)
            btn.infoBg:SetPoint("TOPLEFT", 0, -imageHeight)

            -- Grid Position
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", startX + (col * (btnWidth + marginX)), startY - (row * (btnHeight + marginY)))
            btn:Show()

            btn.nameText:SetText(info.name)
            btn.locText:SetText(info.location or "Unknown Location")

            btn.teleportName = info.name
            btn.teleportLocation = info.location
            btn.teleportSource = info.source
            btn.teleportID = info.id
            local effectiveObtainable = info.obtainable
            if effectiveObtainable == nil then
                effectiveObtainable = false
            end
            effectiveObtainable = ResolveObtainableState(effectiveObtainable, info.starts, info.ends, info.postEnds)
            btn.teleportObtainable = effectiveObtainable
            btn.teleportStarts = info.starts
            btn.teleportEnds = info.ends
            btn.teleportPostEnds = info.postEnds

            -- Setup click and visual state
            local isKnown = false
            local spellToUse = nil

            -- Determine player faction for faction specific spell ID selection (if applicable)
            local faction = UnitFactionGroup("player")

            -- Determine which spell ID to use based on faction (for few dungeons that have different IDs for Horde/Ally due to faction specific entrance)
            if info.spellIDHorde and info.spellIDAlly then
                if faction == "Horde" then
                    spellToUse = info.spellIDHorde
                else
                    spellToUse = info.spellIDAlly
                end
            else
                spellToUse = info.spellID
            end

            isKnown = IsTeleportSpellKnown(spellToUse)

            if isKnown then
                btn:Enable()
                btn:SetAlpha(1)
                btn.imageArea:SetDesaturated(false)
                btn.nameText:SetTextColor(1, 0.82, 0)
                if not SetTeleportButtonSpellAction(btn, spellToUse) then
                    -- Keep enabled for tooltip, but visual disable
                    btn:SetAlpha(0.5)
                    btn.imageArea:SetDesaturated(true)
                    btn.nameText:SetTextColor(0.5, 0.5, 0.5)
                end
            else -- Not known, visual disable only
                btn:Enable()
                btn:SetAlpha(0.5) -- Grayed out
                btn.imageArea:SetDesaturated(true)
                btn.nameText:SetTextColor(0.5, 0.5, 0.5)
                ClearTeleportButtonAction(btn)
            end

            -- Store current spell ID for tooltip
            btn.currentSpellID = spellToUse
            btn.isKnown = isKnown
            ApplyListedDungeonHighlight(btn)

            -- Update Cooldown immediately
            if contentFrame:IsShown() then
                RefreshButtonCooldown(btn)
            else
                btn.cooldown:Hide()
            end

            -- Set Texture using texture FileID
            if info.texture and info.texture > 0 then
                ApplyTeleportImageTexture(btn, info, btnWidth, imageHeight)
            end
        end

        local totalRows = math.ceil(#resolvedData / cols)
        local totalHeight = math.abs(startY) + (totalRows * btnHeight) + (math.max(totalRows - 1, 0) * marginY) + math.abs(startY)
        scrollChild:SetHeight(totalHeight)
        if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar and scrollFrame.scrollbar and scrollFrame.scrollbar.UpdateScrollbar then
             scrollFrame.scrollbar.UpdateScrollbar()
        end

        return true
    end

    local function RequestCategoryUpdate(categoryValue, categoryText)
        RefreshCategoryOptions(categoryValue)
        selectedCategoryText = categoryText or GetCategoryTextByValue(selectedCategoryValue, availableCategories, true)

        if IsInCombat() then
            pendingCategoryValue = selectedCategoryValue
            pendingCategoryText = selectedCategoryText
            contentFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return false
        end

        if UpdateTeleportList(selectedCategoryValue) then
            title:SetText(selectedCategoryText)
        end

        pendingCategoryValue = nil
        pendingCategoryText = nil
        contentFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return true
    end

    -- Event Handler for cooldowns and deferred secure updates
    contentFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "SPELL_UPDATE_COOLDOWN" then
            QueueCooldownRefresh()
        elseif event == "SPELLS_CHANGED" then
            RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        elseif event == "CVAR_UPDATE" then
            local cvarName = tostring(arg1 or ""):gsub("_", ""):lower()
            if cvarName == "actionbuttonusekeydown" and not IsInCombat() then
                for _, btn in pairs(contentFrame.buttons) do
                    ConfigureTeleportButtonClicks(btn)
                end
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            for _, btn in pairs(contentFrame.buttons) do
                if btn and btn:IsShown() then
                    ConfigureTeleportButtonClicks(btn)
                end
            end
            if pendingCategoryValue then
                RequestCategoryUpdate(pendingCategoryValue, pendingCategoryText)
            else
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            end
        end
    end)
    contentFrame:SetScript("OnShow", function(self)
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("CVAR_UPDATE")
        RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        for _, btn in pairs(self.buttons) do
            if btn:IsShown() then
                ConfigureTeleportButtonClicks(btn)
                RefreshButtonCooldown(btn)
            end
        end
        QueueCooldownRefresh()
    end)
    contentFrame:SetScript("OnHide", function(self)
        self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        self:UnregisterEvent("SPELLS_CHANGED")
        self:UnregisterEvent("CVAR_UPDATE")
        self.cooldownRefreshPending = false
    end)

    -- Dropdown
    if mQoL_Styles and mQoL_Styles.CreateCustomDropdown then
        RefreshCategoryOptions()
        dropdown = mQoL_Styles.CreateCustomDropdown(contentFrame, 160, availableCategories, selectedCategoryValue, function(value)
            RequestCategoryUpdate(value)
        end)
        dropdown:HookScript("OnMouseDown", function()
            RefreshCategoryOptions(selectedCategoryValue)
        end)
        dropdown:SetPoint("TOPRIGHT", -5, -30)
    end

    local UpdateDungeonTeleportsTabTextColor
    local isDungeonTeleportsTabForceDisabled = false
    local isInternalTabSwitch = false

    local function GetFallbackPVEFrameName()
        if isClassicLayout then
            return "GroupFinderFrame"
        end
        return "ChallengesFrame"
    end

    local function GetFallbackPVEFrameTab()
        if isClassicLayout and PVEFrameTab1 then
            return PVEFrameTab1
        end
        if PVEFrameTab3 then
            return PVEFrameTab3
        end
        return PVEFrameTab1
    end

    local function SelectClassicFallbackTabVisual()
        local fallbackTab = GetFallbackPVEFrameTab()
        if fallbackTab and PanelTemplates_SelectTab then
            PanelTemplates_SelectTab(fallbackTab)
        end
    end

    local function SwitchToFallbackPVEFrame()
        local fallbackTab = GetFallbackPVEFrameTab()
        if PVEFrame_ShowFrame then
            PVEFrame_ShowFrame(GetFallbackPVEFrameName())
        elseif PVEFrame_TabOnClick and fallbackTab then
            PVEFrame_TabOnClick(fallbackTab)
        end
    end

    local function HideBuiltInPVEPanels()
        if GroupFinderFrame then GroupFinderFrame:Hide() end
        if PVPUIFrame then PVPUIFrame:Hide() end
        if PVPQueueFrame then PVPQueueFrame:Hide() end
        if ChallengesFrame then ChallengesFrame:Hide() end
    end

    local function DeselectBuiltInPVETabs()
        if not PanelTemplates_DeselectTab then
            return
        end

        if PVEFrameTab1 then PanelTemplates_DeselectTab(PVEFrameTab1) end
        if PVEFrameTab2 then PanelTemplates_DeselectTab(PVEFrameTab2) end
        if PVEFrameTab3 then PanelTemplates_DeselectTab(PVEFrameTab3) end
    end

    local function SelectDungeonTeleportsTab()
        DeselectBuiltInPVETabs()

        if PanelTemplates_SelectTab then
            PanelTemplates_SelectTab(tab)
        end
    end

    local function RestoreBuiltInPVEChrome()
        if PVEFrame_ShowLeftInset then
            PVEFrame_ShowLeftInset()
            return
        end

        if PVEFrameLeftInset then PVEFrameLeftInset:Show() end
        if PVEFrameBlueBg then PVEFrameBlueBg:Show() end
        if PVEFrameTLCorner then PVEFrameTLCorner:Show() end
        if PVEFrameTRCorner then PVEFrameTRCorner:Show() end
        if PVEFrameBRCorner then PVEFrameBRCorner:Show() end
        if PVEFrameBLCorner then PVEFrameBLCorner:Show() end
        if PVEFrameLLVert then PVEFrameLLVert:Show() end
        if PVEFrameRLVert then PVEFrameRLVert:Show() end
        if PVEFrameBottomLine then PVEFrameBottomLine:Show() end
        if PVEFrameTopLine then PVEFrameTopLine:Show() end
        if PVEFrameTopFiligree then PVEFrameTopFiligree:Show() end
        if PVEFrameBottomFiligree then PVEFrameBottomFiligree:Show() end
        if PVEFrame and PVEFrame.shadows then
            PVEFrame.shadows:Show()
        end
    end

    local function IsClassicFallbackFrameShown()
        return (GroupFinderFrame and GroupFinderFrame:IsShown())
            or (PVPUIFrame and PVPUIFrame:IsShown())
            or (PVPQueueFrame and PVPQueueFrame:IsShown())
            or (ChallengesFrame and ChallengesFrame:IsShown())
    end

    local function SetClassicDungeonTeleportsCombatSuspended(isSuspended)
        if usesNativePVEPanelTabState or not contentFrame then
            return
        end

        isClassicCombatSuspended = isSuspended and true or false

        local targetAlpha = isSuspended and 0 or 1
        contentFrame:SetAlpha(1)

        if title then
            title:SetAlpha(targetAlpha)
        end
        if inset then
            inset:SetAlpha(targetAlpha)
        end
        if scrollFrame then
            scrollFrame:SetAlpha(targetAlpha)
        end
        if scrollChild then
            scrollChild:SetAlpha(targetAlpha)
        end
        if scrollFrame and scrollFrame.scrollbar then
            scrollFrame.scrollbar:SetAlpha(targetAlpha)
            if scrollFrame.scrollbar.EnableMouse then
                scrollFrame.scrollbar:EnableMouse(not isSuspended)
            end
        end
        if dropdown then
            dropdown:SetAlpha(targetAlpha)
            if dropdown.EnableMouse then
                dropdown:EnableMouse(not isSuspended)
            end
        end
        if classicCombatBlocker then
            if isSuspended then
                classicCombatBlocker:Show()
            else
                classicCombatBlocker:Hide()
            end
        end

        if isSuspended then
            RestoreBuiltInPVEChrome()
        elseif contentFrame:IsShown() then
            if PVEFrame_HideLeftInset then
                PVEFrame_HideLeftInset()
            elseif PVEFrameLeftInset then
                PVEFrameLeftInset:Hide()
            end
        end
    end

    local function HideDungeonTeleportsFrame(allowInCombat)
        if IsInCombat() and allowInCombat ~= true then
            pendingHideAfterCombat = true
            return false
        end

        pendingHideAfterCombat = false
        if contentFrame then
            contentFrame:Hide()
        end
        SetClassicDungeonTeleportsCombatSuspended(false)
        if isClassicLayout then
            RestoreBuiltInPVEChrome()
        end
        if PanelTemplates_DeselectTab then
            PanelTemplates_DeselectTab(tab)
        end
        if UpdateDungeonTeleportsTabTextColor then
            UpdateDungeonTeleportsTabTextColor()
        end
        return true
    end

    local function SwitchToFallbackTab()
        if not PVEFrame or not PVEFrame:IsShown() or isInternalTabSwitch then
            return
        end

        isInternalTabSwitch = true
        SwitchToFallbackPVEFrame()
        if not usesNativePVEPanelTabState then
            SelectClassicFallbackTabVisual()
        end
        isInternalTabSwitch = false
    end

    local function ShowDungeonTeleportsFrame()
        if IsInCombat() then
            return
        end

        if not PVEFrame:IsShown() then
            ShowUIPanel(PVEFrame)
        end

        SelectDungeonTeleportsTab()

        HideBuiltInPVEPanels()

        if PVEFrame_HideLeftInset then
            PVEFrame_HideLeftInset()
        elseif PVEFrameLeftInset then
            PVEFrameLeftInset:Hide()
        end

        RefreshCategoryOptions()
        pendingHideAfterCombat = false
        SetClassicDungeonTeleportsCombatSuspended(false)
        contentFrame:Show()
        RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        PVEFrame:SetTitle("Dungeon Teleports")
        if PVEFrame.SetPortraitToAsset then
            PVEFrame:SetPortraitToAsset("Interface\\Icons\\Spell_Arcane_TeleportDalaran")
        elseif PortraitFrame_SetPortraitToAsset then
            PortraitFrame_SetPortraitToAsset(PVEFrame, "Interface\\Icons\\Spell_Arcane_TeleportDalaran")
        end
        if not isClassicLayout then
            PVEFrame:SetWidth(PVE_FRAME_BASE_WIDTH or 563)
            if UpdateUIPanelPositions then
                UpdateUIPanelPositions(PVEFrame)
            end
        end
        if UpdateDungeonTeleportsTabTextColor then
            UpdateDungeonTeleportsTabTextColor()
        end
    end

    UpdateDungeonTeleportsTabTextColor = function()
        local text = tab.Text or _G[tab:GetName() .. "Text"]
        if not text then
            return
        end

        if isDungeonTeleportsTabForceDisabled then
            text:SetTextColor(0.5, 0.5, 0.5)
            return
        end

        local selectedTabID = usesNativePVEPanelTabState and PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(PVEFrame) or nil
        local isNativeTabActive = usesNativePVEPanelTabState
            and (
                selectedTabID == tab:GetID()
                or (contentFrame and contentFrame:IsShown())
            )
        local isClassicTabActive = not usesNativePVEPanelTabState
            and contentFrame
            and contentFrame:IsShown()
            and not isClassicCombatSuspended
            and not IsClassicFallbackFrameShown()
        local isActive = isNativeTabActive or isClassicTabActive
        local isHovered = tab:IsMouseOver()

        if isActive or isHovered then
            text:SetTextColor(1, 1, 1)
        else
            text:SetTextColor(1, 0.82, 0)
        end
    end

    local function SetDungeonTeleportsTabDisabled(isDisabled)
        isDungeonTeleportsTabForceDisabled = isDisabled and true or false
        tab:SetEnabled(not isDisabled)
        tab:SetAlpha(1)
        UpdateDungeonTeleportsTabTextColor()
    end

    local function UpdateDungeonTeleportsTabState()
        local inCombat = IsInCombat()
        if inCombat then
            if not usesNativePVEPanelTabState and PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                pendingHideAfterCombat = true
                if not IsClassicFallbackFrameShown() then
                    SwitchToFallbackTab()
                end
                SetClassicDungeonTeleportsCombatSuspended(true)
            end
            if usesNativePVEPanelTabState and PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                pendingHideAfterCombat = true
                SwitchToFallbackTab()
            end
            if usesNativePVEPanelTabState and PanelTemplates_DisableTab then
                PanelTemplates_DisableTab(PVEFrame, 4)
            else
                tab:Disable()
            end
            if (not usesNativePVEPanelTabState and isClassicCombatSuspended) or not contentFrame:IsShown() then
                if PanelTemplates_DeselectTab then
                    PanelTemplates_DeselectTab(tab)
                end
            end
        else
            local selectedTabID = usesNativePVEPanelTabState and PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(PVEFrame) or nil
            local didHideAfterCombat = false

            if not usesNativePVEPanelTabState and pendingHideAfterCombat and contentFrame and contentFrame:IsShown() then
                if HideDungeonTeleportsFrame() then
                    didHideAfterCombat = true
                    if PVEFrame and PVEFrame:IsShown() then
                        SwitchToFallbackTab()
                    end
                end
            end

            SetClassicDungeonTeleportsCombatSuspended(false)

            if usesNativePVEPanelTabState and contentFrame and contentFrame:IsShown() and selectedTabID ~= 4 then
                HideDungeonTeleportsFrame()
            end
            if not didHideAfterCombat and not usesNativePVEPanelTabState and contentFrame and contentFrame:IsShown() then
                if GroupFinderFrame and GroupFinderFrame:IsShown() then
                    HideDungeonTeleportsFrame()
                elseif PVPUIFrame and PVPUIFrame:IsShown() then
                    HideDungeonTeleportsFrame()
                elseif PVPQueueFrame and PVPQueueFrame:IsShown() then
                    HideDungeonTeleportsFrame()
                elseif ChallengesFrame and ChallengesFrame:IsShown() then
                    HideDungeonTeleportsFrame()
                end
            end
            if usesNativePVEPanelTabState and pendingHideAfterCombat and PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                if HideDungeonTeleportsFrame() then
                    SwitchToFallbackPVEFrame()
                end
            end
            if usesNativePVEPanelTabState and PanelTemplates_EnableTab then
                PanelTemplates_EnableTab(PVEFrame, 4)
            else
                tab:Enable()
            end
            if contentFrame:IsShown() then
                SelectDungeonTeleportsTab()
            elseif PanelTemplates_DeselectTab then
                PanelTemplates_DeselectTab(tab)
            end
        end

        SetDungeonTeleportsTabDisabled(inCombat)
        UpdateDungeonTeleportsTabTextColor()
    end

    tab:HookScript("OnEnter", UpdateDungeonTeleportsTabTextColor)
    tab:HookScript("OnLeave", UpdateDungeonTeleportsTabTextColor)

    tab:SetScript("OnClick", function()
        if IsInCombat() then
            return
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowDungeonTeleportsFrame()
    end)

    -- Initial Load
    RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)

    hooksecurefunc("PVEFrame_TabOnClick", function(clickedTab)
        if isInternalTabSwitch then
            return
        end
        UpdateDungeonTeleportsTabState()
    end)

    hooksecurefunc("PVEFrame_ShowFrame", function(sidePanelName)
        if isInternalTabSwitch then
            return
        end
        UpdateDungeonTeleportsTabState()
    end)

    PVEFrame:HookScript("OnHide", function()
        HideDungeonTeleportsFrame()
    end)
    PVEFrame:HookScript("OnShow", function()
        UpdateDungeonTeleportsTabState()
    end)

    local tabStateFrame = CreateFrame("Frame")
    tabStateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    tabStateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    tabStateFrame:SetScript("OnEvent", UpdateDungeonTeleportsTabState)
    UpdateDungeonTeleportsTabState()
end

local function InitDungeonTeleportsTabRetail()
    if _G["PVEFrameTab4"] then return end
    if not PVEFrame or not PVEFrameTab3 then return end

    local pendingCategoryValue
    local pendingCategoryText
    local pendingHideAfterCombat = false
    local selectedCategoryValue = "MID_S1"
    local selectedCategoryText = "Midnight Season 1"
    local availableCategories = {}
    local dropdown
    local InitializeDropdown

    local function GetCategoryTextByValue(value, categories, useDynamicText)
        local source = categories or availableCategories
        for _, cat in ipairs(source) do
            if cat.value == value then
                if useDynamicText and cat.dynamicText then
                    return cat.dynamicText
                end
                return cat.text
            end
        end
        return tostring(value or "")
    end

    local function GetSeasonCategoryBaseName(cat)
        local text = tostring(cat and cat.text or "")
        text = text:gsub("%s+[Pp]ost%-?[Ss]eason%s+%d+.*$", "")
        text = text:gsub("%s+[Ss]eason%s+%d+.*$", "")
        text = text:match("^%s*(.-)%s*$")
        if text and text ~= "" then
            return text
        end

        local value = tostring(cat and cat.value or "")
        local fallback = value:match("^(.-)_S%d+$")
        if fallback and fallback ~= "" then
            return fallback
        end
        return value
    end

    local function BuildSeasonCategoryState(cat)
        if not cat or not cat.value or not IsSeasonCategory(cat.value) then
            return true, cat and cat.text
        end

        local seasonNumber = tostring(cat.value):match("_S(%d+)$") or "?"
        local seasonName = GetSeasonCategoryBaseName(cat)
        local _, seasonMeta = GetCategoryEntriesAndMeta(cat.value)
        if type(seasonMeta) ~= "table" then
            return true, string.format("%s Season %s", seasonName, seasonNumber)
        end

        local now = GetServerTime()
        local state = ResolveObtainableState(seasonMeta.obtainable, seasonMeta.starts, seasonMeta.ends, seasonMeta.postEnds)

        if state == "starts" then
            local startsText = "Start date unavailable"
            if seasonMeta.starts then
                local startTimestamp = GetSeasonStartTimestamp(seasonMeta.starts)
                if startTimestamp then
                    local remaining = startTimestamp - now
                    if remaining > 0 then
                        startsText = "Starts in " .. FormatRemainingDuration(remaining)
                    else
                        startsText = "Started"
                    end
                end
            end

            return true, string.format("%s Season %s - %s", seasonName, seasonNumber, startsText)
        end

        if state == "ends" then
            local endTimestamp = seasonMeta.ends and GetSeasonEndTimestampForDisplay(seasonMeta.ends) or nil
            local postEndTimestamp = seasonMeta.postEnds and GetPostSeasonEndTimestamp(seasonMeta.postEnds) or nil

            if endTimestamp and endTimestamp > now then
                return true, string.format("%s Season %s - Ends in %s", seasonName, seasonNumber, FormatRemainingDuration(endTimestamp - now))
            end

            if postEndTimestamp and postEndTimestamp > now then
                return true, string.format("%s Post-Season %s - Ends in %s", seasonName, seasonNumber, FormatRemainingDuration(postEndTimestamp - now))
            end

            return false, nil
        end

        if state == false then
            return false, nil
        end

        return true, string.format("%s Season %s", seasonName, seasonNumber)
    end

    local function BuildVisibleCategories()
        local result = {}

        for _, cat in ipairs(TeleportCategories) do
            if cat.separator then
                table.insert(result, { separator = true })
            else
                local isVisible, dynamicText = BuildSeasonCategoryState(cat)
                if isVisible then
                    table.insert(result, { text = cat.text, dynamicText = dynamicText or cat.text, value = cat.value })
                end
            end
        end

        local cleaned = {}
        local previousWasSeparator = true
        for _, cat in ipairs(result) do
            if cat.separator then
                if not previousWasSeparator then
                    table.insert(cleaned, cat)
                    previousWasSeparator = true
                end
            else
                table.insert(cleaned, cat)
                previousWasSeparator = false
            end
        end

        if #cleaned > 0 and cleaned[#cleaned].separator then
            table.remove(cleaned, #cleaned)
        end

        return cleaned
    end

    local function GetFirstSelectableCategory(categories)
        for _, cat in ipairs(categories or {}) do
            if not cat.separator and cat.value then
                return cat.value
            end
        end
        return nil
    end

    local function IsCategoryAvailable(value, categories)
        for _, cat in ipairs(categories or {}) do
            if not cat.separator and cat.value == value then
                return true
            end
        end
        return false
    end

    local function RefreshCategoryOptions(preferredValue)
        local rebuilt = BuildVisibleCategories()
        availableCategories = rebuilt

        if preferredValue and IsCategoryAvailable(preferredValue, availableCategories) then
            selectedCategoryValue = preferredValue
        elseif not IsCategoryAvailable(selectedCategoryValue, availableCategories) then
            selectedCategoryValue = GetFirstSelectableCategory(availableCategories) or selectedCategoryValue
        end
        selectedCategoryText = GetCategoryTextByValue(selectedCategoryValue, availableCategories, true)

        if dropdown then
            if dropdown.SetList then
                dropdown:SetList(availableCategories)
                dropdown:SetValue(selectedCategoryValue)
            elseif UIDropDownMenu_Initialize and InitializeDropdown then
                UIDropDownMenu_Initialize(dropdown, InitializeDropdown)
                UIDropDownMenu_SetText(dropdown, GetCategoryTextByValue(selectedCategoryValue, availableCategories, false))
            end
        end
    end

    local tab = CreateFrame("Button", "PVEFrameTab4", PVEFrame, "PanelTabButtonTemplate")
    tab:SetID(4)
    tab:SetText("Dungeon Teleports")
    if PanelTemplates_TabResize then
        PanelTemplates_TabResize(tab, 0)
    end
    tab:SetPoint("LEFT", PVEFrameTab3, "RIGHT", 6, 0)
    tab:Show()
    if PanelTemplates_DeselectTab then
        PanelTemplates_DeselectTab(tab)
    end

    local contentFrame = CreateFrame("Frame", "DungeonTeleportsFrame", PVEFrame)
    contentFrame:SetAllPoints(PVEFrame)
    contentFrame:Hide()

    local title = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 70, -35)
    title:SetText(selectedCategoryText)

    local inset = CreateFrame("Frame", "$parentInset", contentFrame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", -4, 4)

    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", inset)
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 10)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(inset:GetWidth()-30, 500)
    scrollFrame:SetScrollChild(scrollChild)
    contentFrame.scrollChild = scrollChild
    contentFrame.buttons = {}
    contentFrame.cooldownRefreshPending = false
    RegisterListedDungeonHighlightListener(function()
        for _, btn in pairs(contentFrame.buttons) do
            ApplyListedDungeonHighlight(btn)
        end
    end)

    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        mQoL_Styles.CreateCustomScrollbar(scrollFrame, scrollChild)
    end

    local function OnButtonEnter(self)
        self.border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        if self.teleportName then
            GameTooltip:AddLine(self.teleportName, 1, 1, 1)
        end
        if self.teleportLocation then
            GameTooltip:AddLine(self.teleportLocation, 0.7, 0.7, 0.7)
        end
        if self.isListedDungeonHighlightActive then
            AddListedDungeonHighlightTooltipLine()
        end

        if not self.isKnown then
            GameTooltip:AddLine(" ")
            if self.isAccountWideUnlocked then
                GameTooltip:AddLine("Unlocked on your account", 0.2, 1, 0.2)
                GameTooltip:AddLine(self.teleportUnavailableReason or "This character cannot use this portal yet.", 1, 0.82, 0, true)
            else
                GameTooltip:AddLine("How to obtain:", 1, 0.82, 0)
                local tooltipObtainable = ResolveObtainableState(self.teleportObtainable, self.teleportStarts, self.teleportEnds, self.teleportPostEnds)

                if tooltipObtainable == false then
                    GameTooltip:AddLine("NOT CURRENTLY OBTAINABLE", 1, 0, 0)
                elseif tooltipObtainable == "starts" then
                    local startTimestamp = GetSeasonStartTimestamp(self.teleportStarts)
                    if startTimestamp then
                        local remaining = startTimestamp - GetServerTime()
                        if remaining > 0 then
                            GameTooltip:AddLine("Season starts in " .. FormatRemainingDuration(remaining), 1, 1, 0)
                        else
                            GameTooltip:AddLine("Season Started", 0, 1, 0)
                        end
                    else
                        GameTooltip:AddLine("Season start date unavailable", 1, 0.5, 0.25)
                    end
                elseif tooltipObtainable == "ends" then
                    local text = "Season ends in"
                    local endTimestamp = self.teleportEnds and GetSeasonEndTimestampForDisplay(self.teleportEnds) or nil
                    local postEndTimestamp = self.teleportPostEnds and GetPostSeasonEndTimestamp(self.teleportPostEnds) or nil
                    local currentTime = GetServerTime()
                    local remaining = endTimestamp and (endTimestamp - currentTime) or nil
                    if remaining and remaining > 0 then
                        text = text .. " " .. FormatRemainingDuration(remaining)
                    else
                        local postRemaining = postEndTimestamp and (postEndTimestamp - currentTime) or nil
                        if postRemaining and postRemaining > 0 then
                            text = "Post-season ends in " .. FormatRemainingDuration(postRemaining)
                        else
                            text = "NOT CURRENTLY OBTAINABLE"
                        end
                    end
                    GameTooltip:AddLine(text, 1, 0, 0)
                end

                if self.teleportSource then
                    GameTooltip:AddLine(self.teleportSource, 1, 1, 1, true)
                else
                    GameTooltip:AddLine("Complete Mythic Keystone on Level 10 or higher within the time limit.", 1, 1, 1, true)
                end
            end
        end

        GameTooltip:Show()
    end

    local function OnButtonLeave(self)
        self.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        GameTooltip:Hide()
    end

    local function RefreshVisibleButtonCooldowns()
        if not contentFrame:IsShown() then
            return
        end
        for _, btn in pairs(contentFrame.buttons) do
            if btn:IsShown() then
                RefreshButtonCooldown(btn)
            end
        end
    end

    local function QueueCooldownRefresh()
        if contentFrame.cooldownRefreshPending then
            return
        end

        contentFrame.cooldownRefreshPending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                contentFrame.cooldownRefreshPending = false
                RefreshVisibleButtonCooldowns()
            end)
        else
            contentFrame.cooldownRefreshPending = false
            RefreshVisibleButtonCooldowns()
        end
    end

    local function UpdateTeleportList(categoryValue)
        if IsInCombat() then
            return false
        end

        for _, btn in pairs(contentFrame.buttons) do
            btn:Hide()
        end

        local data, seasonMeta = GetCategoryEntriesAndMeta(categoryValue)
        if not data then return true end

        local resolvedData = {}
        for _, entry in ipairs(data) do
            local resolvedEntry = ResolveTeleportEntry(categoryValue, entry, seasonMeta)
            if resolvedEntry then
                table.insert(resolvedData, resolvedEntry)
            end
        end

        local availableWidth = scrollChild:GetWidth() or 520
        local cols = 3
        local marginX = 10
        local marginY = 10
        local startX = 10
        local startY = -10

        local btnWidth = (availableWidth - (cols - 1) * marginX - 2 * startX) / cols
        local btnHeight = TELEPORT_CARD_HEIGHT
        local imageHeight = TELEPORT_CARD_IMAGE_HEIGHT

        for i, info in ipairs(resolvedData) do
            if not contentFrame.buttons[i] then
                local btn = CreateFrame("Button", nil, scrollChild, "SecureActionButtonTemplate")
                btn:SetSize(btnWidth, btnHeight)
                ConfigureTeleportButtonClicks(btn)

                btn.bg = btn:CreateTexture(nil, "BACKGROUND")
                btn.bg:SetAllPoints()
                btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

                btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
                btn.border:SetAllPoints()
                btn.border:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                btn.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                EnsureListedDungeonHighlight(btn)

                btn.imageContainer = btn:CreateTexture(nil, "BACKGROUND")
                btn.imageContainer:SetPoint("TOPLEFT", 0, 0)
                btn.imageContainer:SetPoint("TOPRIGHT", 0, 0)
                btn.imageContainer:SetHeight(imageHeight)
                btn.imageContainer:SetColorTexture(0.05, 0.05, 0.05, 1)

                btn.imageArea = btn:CreateTexture(nil, "ARTWORK")
                btn.imageArea:SetPoint("CENTER", btn.imageContainer, "CENTER")
                btn.imageArea:SetSize(imageHeight, imageHeight)
                btn.imageArea:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                btn.infoBg = btn:CreateTexture(nil, "ARTWORK")
                btn.infoBg:SetPoint("TOPLEFT", 0, -imageHeight)
                btn.infoBg:SetPoint("BOTTOMRIGHT", 0, 0)
                btn.infoBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

                btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                btn.nameText:SetPoint("TOPLEFT", btn.infoBg, "TOPLEFT", 5, -5)
                btn.nameText:SetPoint("TOPRIGHT", btn.infoBg, "TOPRIGHT", -5, -5)
                btn.nameText:SetJustifyH("LEFT")
                btn.nameText:SetJustifyV("TOP")
                btn.nameText:SetWordWrap(false)
                btn.nameText:SetMaxLines(1)

                btn.locText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.locText:SetPoint("BOTTOMLEFT", btn.infoBg, "BOTTOMLEFT", 5, 5)
                btn.locText:SetPoint("BOTTOMRIGHT", btn.infoBg, "BOTTOMRIGHT", -5, 5)
                btn.locText:SetJustifyH("LEFT")
                btn.locText:SetTextColor(0.7, 0.7, 0.7)
                btn.locText:SetMaxLines(1)

                btn:SetScript("OnEnter", OnButtonEnter)
                btn:SetScript("OnLeave", OnButtonLeave)

                contentFrame.buttons[i] = btn
            end

            local btn = contentFrame.buttons[i]

            if not btn.cooldown then
                btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                btn.cooldown:SetAllPoints(btn)
                btn.cooldown:SetDrawEdge(false)
                if btn.cooldown.SetDrawBling then
                    btn.cooldown:SetDrawBling(false)
                end
                if btn.cooldown.EnableMouse then
                    btn.cooldown:EnableMouse(false)
                end
                btn.cooldown:SetHideCountdownNumbers(false)

                for _, region in ipairs({btn.cooldown:GetRegions()}) do
                    if region:GetObjectType() == "FontString" then
                        region:SetTextColor(1, 0.82, 0)
                    end
                end
            end

            btn:SetSize(btnWidth, btnHeight)
            btn.imageContainer:SetHeight(imageHeight)
            btn.infoBg:SetPoint("TOPLEFT", 0, -imageHeight)

            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", startX + (col * (btnWidth + marginX)), startY - (row * (btnHeight + marginY)))
            btn:Show()

            btn.nameText:SetText(info.name)
            btn.locText:SetText(info.location or "Unknown Location")

            btn.teleportName = info.name
            btn.teleportLocation = info.location
            btn.teleportSource = info.source
            btn.teleportID = info.id
            local effectiveObtainable = info.obtainable
            if effectiveObtainable == nil then
                effectiveObtainable = false
            end
            effectiveObtainable = ResolveObtainableState(effectiveObtainable, info.starts, info.ends, info.postEnds)
            btn.teleportObtainable = effectiveObtainable
            btn.teleportStarts = info.starts
            btn.teleportEnds = info.ends
            btn.teleportPostEnds = info.postEnds
            btn.isAccountWideUnlocked = false
            btn.teleportUnavailableReason = nil

            local isKnown = false
            local isAccountWideUnlocked = false
            local spellToUse = nil
            local faction = UnitFactionGroup("player")

            if info.spellIDHorde and info.spellIDAlly then
                if faction == "Horde" then
                    spellToUse = info.spellIDHorde
                else
                    spellToUse = info.spellIDAlly
                end
            else
                spellToUse = info.spellID
            end

            isKnown = IsTeleportSpellKnown(spellToUse)
            if not isKnown then
                isAccountWideUnlocked = HasRetailTeleportUnlock(info)
            end
            btn.isAccountWideUnlocked = isAccountWideUnlocked
            if isAccountWideUnlocked then
                btn.teleportUnavailableReason = GetRetailTeleportUnavailableReason(info)
            end

            if isKnown then
                btn:Enable()
                btn:SetAlpha(1)
                btn.imageArea:SetDesaturated(false)
                btn.nameText:SetTextColor(1, 0.82, 0)
                if not SetTeleportButtonSpellAction(btn, spellToUse) then
                    btn:SetAlpha(0.5)
                    btn.imageArea:SetDesaturated(true)
                    btn.nameText:SetTextColor(0.5, 0.5, 0.5)
                end
            else
                btn:Enable()
                btn:SetAlpha(0.5)
                btn.imageArea:SetDesaturated(true)
                btn.nameText:SetTextColor(0.5, 0.5, 0.5)
                ClearTeleportButtonAction(btn)
            end

            btn.currentSpellID = spellToUse
            btn.isKnown = isKnown
            ApplyListedDungeonHighlight(btn)

            if contentFrame:IsShown() then
                RefreshButtonCooldown(btn)
            else
                btn.cooldown:Hide()
            end

            if info.texture and info.texture > 0 then
                ApplyTeleportImageTexture(btn, info, btnWidth, imageHeight)
            end
        end

        local totalRows = math.ceil(#resolvedData / cols)
        local totalHeight = math.abs(startY) + (totalRows * btnHeight) + (math.max(totalRows - 1, 0) * marginY) + math.abs(startY)
        scrollChild:SetHeight(totalHeight)
        if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar and scrollFrame.scrollbar and scrollFrame.scrollbar.UpdateScrollbar then
             scrollFrame.scrollbar.UpdateScrollbar()
        end

        return true
    end

    local function RequestCategoryUpdate(categoryValue, categoryText)
        RefreshCategoryOptions(categoryValue)
        selectedCategoryText = categoryText or GetCategoryTextByValue(selectedCategoryValue, availableCategories, true)

        if IsInCombat() then
            pendingCategoryValue = selectedCategoryValue
            pendingCategoryText = selectedCategoryText
            contentFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return false
        end

        if UpdateTeleportList(selectedCategoryValue) then
            title:SetText(selectedCategoryText)
        end

        pendingCategoryValue = nil
        pendingCategoryText = nil
        contentFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return true
    end

    contentFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "SPELL_UPDATE_COOLDOWN" then
            QueueCooldownRefresh()
        elseif event == "SPELLS_CHANGED" then
            RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        elseif event == "CVAR_UPDATE" then
            local cvarName = tostring(arg1 or ""):gsub("_", ""):lower()
            if cvarName == "actionbuttonusekeydown" and not IsInCombat() then
                for _, btn in pairs(contentFrame.buttons) do
                    ConfigureTeleportButtonClicks(btn)
                end
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            for _, btn in pairs(contentFrame.buttons) do
                if btn and btn:IsShown() then
                    ConfigureTeleportButtonClicks(btn)
                end
            end
            if pendingCategoryValue then
                RequestCategoryUpdate(pendingCategoryValue, pendingCategoryText)
            else
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            end
        end
    end)
    contentFrame:SetScript("OnShow", function(self)
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("CVAR_UPDATE")
        RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        for _, btn in pairs(self.buttons) do
            if btn:IsShown() then
                ConfigureTeleportButtonClicks(btn)
                RefreshButtonCooldown(btn)
            end
        end
        QueueCooldownRefresh()
    end)
    contentFrame:SetScript("OnHide", function(self)
        self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        self:UnregisterEvent("SPELLS_CHANGED")
        self:UnregisterEvent("CVAR_UPDATE")
        self.cooldownRefreshPending = false
    end)

    if mQoL_Styles and mQoL_Styles.CreateCustomDropdown then
        RefreshCategoryOptions()
        dropdown = mQoL_Styles.CreateCustomDropdown(contentFrame, 160, availableCategories, selectedCategoryValue, function(value)
            RequestCategoryUpdate(value)
        end)
        dropdown:HookScript("OnMouseDown", function()
            RefreshCategoryOptions(selectedCategoryValue)
        end)
        dropdown:SetPoint("TOPRIGHT", -5, -30)
    end

    local UpdateDungeonTeleportsTabTextColor
    local isDungeonTeleportsTabForceDisabled = false
    local isInternalTabSwitch = false

    local function HideDungeonTeleportsFrame()
        if IsInCombat() then
            pendingHideAfterCombat = true
            return false
        end

        pendingHideAfterCombat = false
        if contentFrame then
            contentFrame:Hide()
        end
        if PanelTemplates_DeselectTab then
            PanelTemplates_DeselectTab(tab)
        end
        if UpdateDungeonTeleportsTabTextColor then
            UpdateDungeonTeleportsTabTextColor()
        end
        return true
    end

    local function SwitchToMythicPlusTab()
        if not PVEFrame or not PVEFrame:IsShown() or isInternalTabSwitch then
            return
        end

        isInternalTabSwitch = true
        if PVEFrame_ShowFrame then
            PVEFrame_ShowFrame("ChallengesFrame")
        elseif PVEFrame_TabOnClick and PVEFrameTab3 then
            PVEFrame_TabOnClick(PVEFrameTab3)
        end
        isInternalTabSwitch = false
    end

    local function ShowDungeonTeleportsFrame()
        if IsInCombat() then
            return
        end

        if not PVEFrame:IsShown() then
            ShowUIPanel(PVEFrame)
        end

        if PanelTemplates_DeselectTab then
            if PVEFrameTab1 then PanelTemplates_DeselectTab(PVEFrameTab1) end
            if PVEFrameTab2 then PanelTemplates_DeselectTab(PVEFrameTab2) end
            if PVEFrameTab3 then PanelTemplates_DeselectTab(PVEFrameTab3) end
        end
        if PanelTemplates_SelectTab then
            PanelTemplates_SelectTab(tab)
        end

        if GroupFinderFrame then GroupFinderFrame:Hide() end
        if PVPUIFrame then PVPUIFrame:Hide() end
        if ChallengesFrame then ChallengesFrame:Hide() end

        if PVEFrame_HideLeftInset then
            PVEFrame_HideLeftInset()
        elseif PVEFrameLeftInset then
            PVEFrameLeftInset:Hide()
        end

        RefreshCategoryOptions()
        contentFrame:Show()
        RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        PVEFrame:SetTitle("Dungeon Teleports")
        if PVEFrame.SetPortraitToAsset then
            PVEFrame:SetPortraitToAsset("Interface\\Icons\\Spell_Arcane_TeleportDalaran")
        elseif PortraitFrame_SetPortraitToAsset then
            PortraitFrame_SetPortraitToAsset(PVEFrame, "Interface\\Icons\\Spell_Arcane_TeleportDalaran")
        end
        PVEFrame:SetWidth(PVE_FRAME_BASE_WIDTH or 563)
        if UpdateUIPanelPositions then
            UpdateUIPanelPositions(PVEFrame)
        end
        if UpdateDungeonTeleportsTabTextColor then
            UpdateDungeonTeleportsTabTextColor()
        end
    end

    UpdateDungeonTeleportsTabTextColor = function()
        local text = tab.Text or _G[tab:GetName() .. "Text"]
        if not text then
            return
        end

        if isDungeonTeleportsTabForceDisabled then
            text:SetTextColor(0.5, 0.5, 0.5)
            return
        end

        local selectedTabID = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(PVEFrame) or nil
        local isActive = selectedTabID == tab:GetID() or (contentFrame and contentFrame:IsShown())
        local isHovered = tab:IsMouseOver()

        if isActive or isHovered then
            text:SetTextColor(1, 1, 1)
        else
            text:SetTextColor(1, 0.82, 0)
        end
    end

    local function SetDungeonTeleportsTabDisabled(isDisabled)
        isDungeonTeleportsTabForceDisabled = isDisabled and true or false
        tab:SetEnabled(not isDisabled)
        tab:SetAlpha(1)
        UpdateDungeonTeleportsTabTextColor()
    end

    local function UpdateDungeonTeleportsTabState()
        local inCombat = IsInCombat()
        if inCombat then
            if PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                pendingHideAfterCombat = true
                SwitchToMythicPlusTab()
            end
            if PanelTemplates_DisableTab then
                PanelTemplates_DisableTab(PVEFrame, 4)
            else
                tab:Disable()
            end
            if not contentFrame:IsShown() and PanelTemplates_DeselectTab then
                PanelTemplates_DeselectTab(tab)
            end
        else
            local selectedTabID = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(PVEFrame) or nil
            if contentFrame and contentFrame:IsShown() and selectedTabID ~= 4 then
                HideDungeonTeleportsFrame()
            end
            if pendingHideAfterCombat and PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                if HideDungeonTeleportsFrame() then
                    if PVEFrame_TabOnClick and PVEFrameTab3 then
                        PVEFrame_TabOnClick(PVEFrameTab3)
                    elseif PVEFrame_ShowFrame then
                        PVEFrame_ShowFrame("ChallengesFrame")
                    end
                end
            end
            if PanelTemplates_EnableTab then
                PanelTemplates_EnableTab(PVEFrame, 4)
            else
                tab:Enable()
            end
            if contentFrame:IsShown() and PanelTemplates_SelectTab then
                PanelTemplates_SelectTab(tab)
            elseif PanelTemplates_DeselectTab then
                PanelTemplates_DeselectTab(tab)
            end
        end

        SetDungeonTeleportsTabDisabled(inCombat)
        UpdateDungeonTeleportsTabTextColor()
    end

    tab:HookScript("OnEnter", UpdateDungeonTeleportsTabTextColor)
    tab:HookScript("OnLeave", UpdateDungeonTeleportsTabTextColor)

    tab:SetScript("OnClick", function()
        if IsInCombat() then
            return
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowDungeonTeleportsFrame()
    end)

    RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)

    hooksecurefunc("PVEFrame_TabOnClick", function(clickedTab)
        if isInternalTabSwitch then
            return
        end
        UpdateDungeonTeleportsTabState()
    end)

    hooksecurefunc("PVEFrame_ShowFrame", function(sidePanelName)
        if isInternalTabSwitch then
            return
        end
        UpdateDungeonTeleportsTabState()
    end)

    PVEFrame:HookScript("OnHide", HideDungeonTeleportsFrame)
    PVEFrame:HookScript("OnShow", UpdateDungeonTeleportsTabState)

    local tabStateFrame = CreateFrame("Frame")
    tabStateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    tabStateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    tabStateFrame:SetScript("OnEvent", UpdateDungeonTeleportsTabState)
    UpdateDungeonTeleportsTabState()
end

local frame = CreateFrame("Frame")
local isInitialized = false

local function IsGroupFinderLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder")
    end

    if _G.IsAddOnLoaded then
        return _G.IsAddOnLoaded("Blizzard_GroupFinder")
    end

    return false
end

local function TryInitialize(self)
    if isInitialized then
        return
    end
    if not IsGroupFinderLoaded() then
        return
    end
    if IsInCombat() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if clientInfo.isClassic then
        InitDungeonTeleportsTabClassic()
    else
        InitDungeonTeleportsTabRetail()
    end
    UpdateListedDungeonHighlightState()
    SuppressListedDungeonHighlightForCurrentInstance()
    isInitialized = true
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("ADDON_LOADED")
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "Blizzard_GroupFinder" then
            TryInitialize(self)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        TryInitialize(self)
    end
end)

TryInitialize(frame)