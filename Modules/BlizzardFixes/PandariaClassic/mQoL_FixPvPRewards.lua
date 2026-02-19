local addonName = ...

-- DEBUG
local DEBUG = {
    GLOBAL = false,
    REWARDS = false,    -- spam alot spam
    BATTLES = false,
    ERRORS = false,
    UI = false,
    LOGS = true,        -- save arena/bg/rbg logs
}

function DebugPrint(category, msg, color, data)
    if not DEBUG or not DEBUG[category] then return end

    local prefix = string.format("|cffaaaaaa[%s]|r", category or "DEBUG")
    local fullMsg = string.format("%s %s", prefix, tostring(msg))

    local r, g, b = 1, 1, 1
    if color == "red" then r, g, b = 1, 0.2, 0.2
    elseif color == "green" then r, g, b = 0.2, 1, 0.2
    elseif color == "blue" then r, g, b = 0.2, 0.6, 1
    end

    DEFAULT_CHAT_FRAME:AddMessage(fullMsg, r, g, b)
end

local function LogPvPResult(result, pvpType, playerTeam, winner)
    if not DEBUG or not DEBUG.LOGS then return end

    local db = GetPlayerPvPDB()
    if not db or not db.logs then return end

    local zoneName = GetRealZoneText() or "UNKNOWN_MAP"

    local entry = {
        result = result,
        type = pvpType,
        playerTeam = playerTeam,
        winner = winner,
        zone = zoneName,
        msg = string.format(
            "PvP Result: %s (%s - %s, playerTeam=%s, winner=%s)",
            result,
            pvpType,
            zoneName,
            tostring(playerTeam),
            tostring(winner)
        ),
        time = date("%Y-%m-%d %H:%M:%S"),
        cat = "BATTLES",
    }

    table.insert(db.logs, entry)
    if #db.logs > 50 then table.remove(db.logs, 1) end
end

-- REWARDS / CONFIG
local REWARDS = {
    Honor = {
        [90] = { Bg = { first = 540, next = 270 }, },
        [89] = { Bg = { first = 90, next = 45 }, },
    },
    Conquest = {
        [90] = {
            Bg = { first = 150, next = 0 },
            Arena = { first = 250, next = 250 },
            Rbg = { first = 750, next = 750 },
        },
        [89] = {
            Bg = { first = 0, next = 0 },
            Arena = { first = 0, next = 0 },
            Rbg = { first = 0, next = 0 },
        },
    },
}

local function GetRewardAmount(rewardType, index, pvpType)
    if not rewardType or not pvpType then
        DebugPrint("ERRORS", "GetRewardAmount: missing params")
        return 0
    end

    local playerLevel = UnitLevel("player") or 0
    local byLevel = REWARDS[rewardType]
    if not byLevel then return 0 end

    local chosenLevel = nil
    for lvl, _ in pairs(byLevel) do
        lvl = tonumber(lvl)
        if lvl and lvl <= playerLevel then
            if not chosenLevel or lvl > chosenLevel then chosenLevel = lvl end
        end
    end
    if not chosenLevel then
        -- fallback minimal defined level
        local minL = math.huge
        for lvl, _ in pairs(byLevel) do
            lvl = tonumber(lvl)
            if lvl and lvl < minL then minL = lvl end
        end
        chosenLevel = (minL ~= math.huge) and minL or nil
    end
    if not chosenLevel then return 0 end

    local rewards = byLevel[chosenLevel]
    if not rewards then return 0 end
    local entry = rewards[pvpType]
    if not entry then return 0 end
    local amount = (index == 1) and (entry.first or 0) or (entry.next or 0)
    DebugPrint("REWARDS", string.format("GetRewardAmount -> %d (type=%s index=%d)", amount, pvpType, index))
    return amount
end

-- PER CHARACTER DB and RESET
mQoL_PvPRewards_DB = mQoL_PvPRewards_DB or {}

local function GetPlayerKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "UnknownRealm")
end

function GetPlayerPvPDB()
    local playerKey = (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "UnknownRealm")

    -- check for db
    mQoL_PvPRewards_DB = mQoL_PvPRewards_DB or {}

    -- if record dont exist create one
    if not mQoL_PvPRewards_DB[playerKey] then
        mQoL_PvPRewards_DB[playerKey] = {
            firstWinUsed = { Bg = false, Rbg = false, Arena = false },
            logs = {},
            lastBGTime = date("%Y-%m-%d %H:%M:%S"),
            lastResetTime = GetServerTime(),
        }
    end

    return mQoL_PvPRewards_DB[playerKey]
end

local function ServerTimeToString(ts)
    ts = ts or GetServerTime()
    local t = date("*t", ts)
    return string.format("%04d.%02d.%02d.%02d.%02d.%02d", t.year, t.month, t.day, t.hour, t.min, t.sec)
end

local function StringToServerTime(str)
    if not str then return 0 end
    local y,mo,d,h,m,s = str:match("(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+)%.(%d+)")
    if not y then return 0 end
    return time({year=tonumber(y), month=tonumber(mo), day=tonumber(d), hour=tonumber(h), min=tonumber(m), sec=tonumber(s)})
end

local function GetPvPResetTimestamp()
    local questResetTime = GetQuestResetTime()
    if not questResetTime then
        DebugPrint("ERRORS", "GetQuestResetTime() returned nil")
        return 0
    end
    local serverTime = GetServerTime()
    -- questResetTime = seconds UNTIL next reset
    local secondsSinceLastReset = 86400 - questResetTime
    local lastReset = serverTime - secondsSinceLastReset
    return lastReset
end

local UpdateBonusFrameRewardLabel, UpdateConquestRewardLabels

local function ResetDailyIfNeeded()
    local db = GetPlayerPvPDB()
    local lastReset = GetPvPResetTimestamp()
    local lastBGTS = StringToServerTime(db.lastBGTime) or 0

    if not lastReset or lastReset <= 0 then
        DebugPrint("ERRORS", "ResetDailyIfNeeded: invalid lastReset value")
        return
    end

    local needsReset = false
    if lastBGTS > 0 and lastBGTS < lastReset then
        needsReset = true
    elseif db.lastResetTime and db.lastResetTime < lastReset then
        needsReset = true
    end

    if needsReset then
        db.firstWinUsed = { Arena = false, Rbg = false, Bg = false }
        db.lastBGTime = "0000-00-00 0:00:00"
        db.lastResetTime = GetServerTime()
        if UpdateBonusFrameRewardLabel then pcall(UpdateBonusFrameRewardLabel) end
        if UpdateConquestRewardLabels then pcall(UpdateConquestRewardLabels) end
        DebugPrint("GLOBAL", "Daily PvP rewards reset for character")
    end
end

local function MarkFirstWinUsed(subType)
    if not subType then return end
    local db = GetPlayerPvPDB()
    if db.firstWinUsed[subType] == false then
        db.firstWinUsed[subType] = true
        db.lastBGTime = ServerTimeToString(GetServerTime())
        DebugPrint("BATTLES", "MarkFirstWinUsed: " .. tostring(subType))
    else
        DebugPrint("BATTLES", "MarkFirstWinUsed: already used " .. tostring(subType))
    end
end

local function GetWinIndex(subType)
    local db = GetPlayerPvPDB()
    if not subType then return 1 end
    local isFirst = not db.firstWinUsed[subType]
    local idx = isFirst and 1 or 2
    DebugPrint("REWARDS", string.format("GetWinIndex(%s)=%d", tostring(subType), idx))
    return idx
end

-- PvP Detection / State
local PVP_TYPES = { RANDOM_BG = "Bg", CALL_TO_ARMS = "Bg", RATED_BG = "Rbg", ARENA = "Arena" }

local function DetectPvPType()
    local isInstance, instanceType = IsInInstance()
    DebugPrint("BATTLES", string.format("DetectPvPType: isInstance=%s instanceType=%s", tostring(isInstance), tostring(instanceType)))
    if instanceType == "arena" then
        return PVP_TYPES.ARENA
    end
    if instanceType ~= "pvp" then
        return nil
    end
    local maxSlots = GetMaxBattlefieldID() or 0
    DebugPrint("BATTLES", "DetectPvPType: checking battlefield slots: " .. tostring(maxSlots))
    for i = 1, maxSlots do
        local status, mapName, instanceID, _, queueType, _, _, isRated = GetBattlefieldStatus(i)
        status = status or "none"
        mapName = mapName or "Unknown"
        instanceID = instanceID or 0
        local queueTypeStr = tostring(queueType or "Unknown")
        local queueId = tonumber(queueType)
        DebugPrint("BATTLES", string.format("Slot %d: status=%s map=%s instanceID=%s queueType=%s isRated=%s",
            i, tostring(status), tostring(mapName), tostring(instanceID), queueTypeStr, tostring(isRated)
        ))
        if status == "active" then
            if isRated then
                DebugPrint("BATTLES", "DetectPvPType -> RATED (isRated=true)")
                return PVP_TYPES.RATED_BG
            end
            local qlow = queueTypeStr:lower()
            if qlow:find("rated") or qlow:find("rbg") then
                DebugPrint("BATTLES", "DetectPvPType -> RATED (queueType string match)")
                return PVP_TYPES.RATED_BG
            end
            if qlow:find("arena") then
                DebugPrint("BATTLES", "DetectPvPType -> ARENA (queueType string match)")
                return PVP_TYPES.ARENA
            end
            if qlow:find("holiday") or qlow:find("calltoarms") or qlow:find("call_to_arms") then
                DebugPrint("BATTLES", "DetectPvPType -> CALL_TO_ARMS (queueType string match)")
                return PVP_TYPES.CALL_TO_ARMS
            end
            if queueId then
                if queueId == 31 then
                    DebugPrint("BATTLES", "DetectPvPType -> RATED (queueId match 31)")
                    return PVP_TYPES.RATED_BG
                elseif queueId == 30 or queueId == 32 then
                    DebugPrint("BATTLES", "DetectPvPType -> ARENA (queueId match)")
                    return PVP_TYPES.ARENA
                else
                    DebugPrint("BATTLES", "DetectPvPType -> RANDOM (queueId numeric fallback: " .. tostring(queueId) .. ")")
                    return PVP_TYPES.RANDOM_BG
                end
            end
            local mapLower = (mapName or ""):lower()
            if mapLower:find("silvershard") or mapLower:find("deepwind") or mapLower:find("gilneas") then
                DebugPrint("BATTLES", "DetectPvPType -> RANDOM (map name heuristic): " .. tostring(mapName))
                return PVP_TYPES.RANDOM_BG
            end
            DebugPrint("BATTLES", "DetectPvPType -> DEFAULT RANDOM (no match)")
            return PVP_TYPES.RANDOM_BG
        end
    end
    DebugPrint("BATTLES", "DetectPvPType: in pvp instance but no active slot -> RANDOM")
    return PVP_TYPES.RANDOM_BG
end

local currentBGState = {
    isInBG = false,
    bgStartTime = 0,
    currentMap = nil,
    hasProcessedResult = false,
    bgInstanceID = nil,
    currentType = nil,
    playerTeam = nil,
    lastBGEndTime = 0,
}

-- Arena teams
local function IsInArena()
    return IsActiveBattlefieldArena()
end

local ArenaTeams = { myTeam = {}, enemyTeam = {}, isActive = false, isInitialized = false }
local function ResetArena()
    ArenaTeams.myTeam = {}
    ArenaTeams.enemyTeam = {}
    ArenaTeams.isActive = false
    ArenaTeams.isInitialized = false
end

local function AddPlayerToTeam(team, unit)
    if UnitExists(unit) then
        table.insert(team, { name = UnitName(unit), unit = unit, class = select(2, UnitClass(unit)), alive = true, health = UnitHealth(unit) })
    end
end

local function UpdateTeam(team)
    for _, p in ipairs(team) do
        if UnitExists(p.unit) then
            p.health = UnitHealth(p.unit)
            p.alive = (p.health or 0) > 0
        else
            p.health = 0; p.alive = false
        end
    end
end

local function InitializeArenaTeams()
    if not IsInArena() then ResetArena(); return false end
    ResetArena(); ArenaTeams.isActive = true; ArenaTeams.isInitialized = true
    AddPlayerToTeam(ArenaTeams.myTeam, "player")
    for i = 1, 4 do AddPlayerToTeam(ArenaTeams.myTeam, "party"..i) end
    for i = 1, 5 do
        local unit = "arena"..i
        if UnitExists(unit) and UnitIsEnemy("player", unit) then AddPlayerToTeam(ArenaTeams.enemyTeam, unit) end
    end
    return (#ArenaTeams.myTeam > 0 and #ArenaTeams.enemyTeam > 0)
end

local function UpdateAllTeams()
    if not ArenaTeams.isInitialized then return end
    UpdateTeam(ArenaTeams.myTeam); UpdateTeam(ArenaTeams.enemyTeam)
end

local function CheckArenaWinner()
    if not ArenaTeams.isInitialized then return nil end
    UpdateAllTeams()
    local myAlive, enemyAlive = 0,0
    for _,p in ipairs(ArenaTeams.myTeam) do if p.alive then myAlive = myAlive + 1 end end
    for _,p in ipairs(ArenaTeams.enemyTeam) do if p.alive then enemyAlive = enemyAlive + 1 end end
    if myAlive > 0 and enemyAlive == 0 then return "myTeam" end
    if enemyAlive > 0 and myAlive == 0 then return "enemyTeam" end
    return nil
end

-- Player team detection
local function HasBuff(unit, spellID)
    for i = 1, 40 do
        local name,_,_,_,_,_,_,_,_, id = UnitBuff(unit, i)
        if not name then break end
        if id == spellID then return true end
    end
    return false
end

local function GetPlayerTeamByPvPType(pvpType)
    if pvpType == "Arena" then
        if not ArenaTeams.isInitialized then InitializeArenaTeams() end
        return "Arena"
    end
    local ALLIANCE_BUFF = {81748}
    local HORDE_BUFF = {81744}
    for _, id in ipairs(ALLIANCE_BUFF) do if HasBuff("player", id) then return "Alliance" end end
    for _, id in ipairs(HORDE_BUFF) do if HasBuff("player", id) then return "Horde" end end
    local faction = UnitFactionGroup("player") or "Unknown"
    if faction == "Horde" or faction == "Alliance" then return faction end
    return "Unknown"
end

-- Match processing
local function GetCurrentBGIdentifier()
    local mapName = GetRealZoneText() or "Unknown"
    local id = currentBGState.bgInstanceID or "Unknown"
    return mapName .. "_" .. id .. "_" .. tostring(currentBGState.bgStartTime)
end

local function ShouldProcessBGResult()
    if currentBGState.hasProcessedResult then return false end
    local db = GetPlayerPvPDB()
    local id = GetCurrentBGIdentifier()
    if db.lastProcessedBG == id then return false end
    return true
end

local function MarkBGAsProcessed()
    local db = GetPlayerPvPDB()
    db.lastProcessedBG = GetCurrentBGIdentifier()
    currentBGState.hasProcessedResult = true
end

local function GetBattlefieldWinnerFaction()
    local winnerIndex = GetBattlefieldWinner()
    if not winnerIndex then return nil end
    winnerIndex = tonumber(winnerIndex)
    if winnerIndex == 1 then return "Alliance"
    elseif winnerIndex == 2 then return "Horde" end
    return nil
end

local function ProcessPvPVictory()
    local db = GetPlayerPvPDB()
    db.lastBGTime = date("%Y-%m-%d %H:%M:%S")

    local now = GetServerTime()
    if db._lastPvPLog and (now - db._lastPvPLog < 10) then
        DebugPrint("BATTLES", "ProcessPvPVictory: Skipped (cooldown active)")
        return
    end
    db._lastPvPLog = now

    if not ShouldProcessBGResult() then
        DebugPrint("BATTLES", "ProcessPvPVictory: Skipped (ShouldProcessBGResult=false)")
        return
    end

    ResetDailyIfNeeded()

    local pvpType = currentBGState.currentType or "UNKNOWN"
    local zone = GetRealZoneText() or "Unknown"
    local winner, playerTeam
    if pvpType == "Arena" then
        local myTeamIndex = GetBattlefieldArenaFaction()
        local w = GetBattlefieldWinner()

        playerTeam = "myTeam"

        if w == nil then
            winner = nil
        elseif w == myTeamIndex then
            winner = "myTeam"
        else
            winner = "enemyTeam"
        end
    else
        playerTeam = currentBGState.playerTeam or (UnitFactionGroup("player") or "Unknown")
        local w = GetBattlefieldWinner()
        if w == 1 then
            winner = "Alliance"
        elseif w == 0 or w == 2 then
            winner = "Horde"
        else
            winner = nil
        end
    end

    if not winner then
        DebugPrint("BATTLES", "ProcessPvPVictory: No winner detected → marking as processed.")
        MarkBGAsProcessed()
        return
    end

    local isWinner = (pvpType == "Arena" and winner == "myTeam") or (playerTeam == winner)
    local result = isWinner and "WIN" or "LOSS"

    DebugPrint("BATTLES", string.format(
        "PvP Result: %s (%s - %s, playerTeam=%s, winner=%s)",
        result, pvpType, zone, tostring(playerTeam), tostring(winner)
    ), isWinner and "green" or "red")

    -- save to db
    LogPvPResult(result, pvpType, playerTeam, winner)

    if isWinner and not db.firstWinUsed[pvpType] then
        MarkFirstWinUsed(pvpType)
    end

    MarkBGAsProcessed()
    if UpdateBonusFrameRewardLabel then pcall(UpdateBonusFrameRewardLabel) end
    if UpdateConquestRewardLabels then pcall(UpdateConquestRewardLabels) end
end

local function CheckPvPMatchResult(retries)
    retries = retries or 0
    local winner = GetBattlefieldWinner()

    DebugPrint("BATTLES", string.format("CheckPvPMatchResult [%d] → winner: %s", retries, tostring(winner)))

    if winner then
        DebugPrint("BATTLES", "BG Result detected! Winner: " .. tostring(winner))
        ProcessPvPVictory()
        return
    end

    if retries >= 8 then
        DebugPrint("BATTLES", "Max retries reached, marking BG as processed.")
        MarkBGAsProcessed()
        return
    end

    local delay = (retries < 4) and 0.25 or 0.5
    C_Timer.After(delay, function() CheckPvPMatchResult(retries + 1) end)
end

-- UI Helpers
local function GetFactionIcons()
    local faction = UnitFactionGroup("player")
    if faction == "Horde" then
        return "|Tinterface\\pvpframe\\pvpcurrency-honor-horde:24:24:-10:0|t", "|Tinterface\\pvpframe\\pvpcurrency-conquest-horde:24:24:-10:0|t"
    else
        return "|Tinterface\\pvpframe\\pvpcurrency-honor-alliance:24:24:-10:0|t", "|Tinterface\\pvpframe\\pvpcurrency-conquest-alliance:24:24:-10:0|t"
    end
end

local function CreateBonusFrameRewardLabel()
    if not HonorQueueFrame or not HonorQueueFrame.BonusFrame then return end
    local bf = HonorQueueFrame.BonusFrame
    if not bf.RewardHeaderLabelSmall then
        bf.RewardHeaderLabelSmall = bf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        bf.RewardHeaderLabelSmall:SetPoint("TOPRIGHT", bf, "TOPRIGHT", -40, -52)
        bf.RewardHeaderLabelSmall:SetJustifyH("RIGHT")
        bf.RewardHeaderLabelSmall:SetText("Reward for Win")
		bf.RewardHeaderLabelSmall:SetTextColor(1, 1, 1)
    end
    if not bf.RewardHeaderLabelLarge then
        bf.RewardHeaderLabelLarge = bf:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        bf.RewardHeaderLabelLarge:SetPoint("TOPRIGHT", bf.RewardHeaderLabelSmall, "BOTTOMRIGHT", 14, 6)
        bf.RewardHeaderLabelLarge:SetJustifyH("RIGHT")
        bf.RewardHeaderLabelLarge:SetText("")
    end
end

UpdateBonusFrameRewardLabel = function()
    if not HonorQueueFrame or not HonorQueueFrame.BonusFrame then return end
    local bf = HonorQueueFrame.BonusFrame
    local honorIcon, conquestIcon = GetFactionIcons()
    local idx = GetWinIndex("Bg")
    local h = GetRewardAmount("Honor", idx, "Bg")
    local c = GetRewardAmount("Conquest", idx, "Bg")
    if bf.RewardHeaderLabelLarge then
        bf.RewardHeaderLabelLarge:SetText(string.format("|cFFFFFFFF%d%s %d%s|r", h, honorIcon, c, conquestIcon))
    end
end

local function CreateConquestRewardLabels()
    if not ConquestQueueFrame then return end
    local cqf = ConquestQueueFrame
    if not cqf.ArenaRewardSmall then
        cqf.ArenaRewardSmall = cqf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        cqf.ArenaRewardSmall:SetPoint("TOPRIGHT", cqf, "TOPRIGHT", -15, -45)
        cqf.ArenaRewardSmall:SetJustifyH("RIGHT")
        cqf.ArenaRewardSmall:SetText("Reward for Win")
		cqf.ArenaRewardSmall:SetTextColor(1, 1, 1)
    end
    if not cqf.ArenaRewardLarge then
        cqf.ArenaRewardLarge = cqf:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        cqf.ArenaRewardLarge:SetPoint("TOPRIGHT", cqf.ArenaRewardSmall, "BOTTOMRIGHT", 14, 6)
        cqf.ArenaRewardLarge:SetJustifyH("RIGHT")
    end
    if not cqf.RatedBGRewardSmall then
        cqf.RatedBGRewardSmall = cqf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        cqf.RatedBGRewardSmall:SetPoint("TOPRIGHT", cqf, "TOPRIGHT", -15, -275)
        cqf.RatedBGRewardSmall:SetJustifyH("RIGHT")
        cqf.RatedBGRewardSmall:SetText("Reward for Win")
		cqf.RatedBGRewardSmall:SetTextColor(1, 1, 1)
    end
    if not cqf.RatedBGRewardLarge then
        cqf.RatedBGRewardLarge = cqf:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        cqf.RatedBGRewardLarge:SetPoint("TOPRIGHT", cqf.RatedBGRewardSmall, "BOTTOMRIGHT", 14, 6)
        cqf.RatedBGRewardLarge:SetJustifyH("RIGHT")
    end
end

UpdateConquestRewardLabels = function()
    if not ConquestQueueFrame then return end
    local _, conquestIcon = GetFactionIcons()
    local arenaIdx = GetWinIndex("Arena")
    local rbgIdx = GetWinIndex("Rbg")
    local arenaPoints = GetRewardAmount("Conquest", arenaIdx, "Arena")
    local rbgPoints = GetRewardAmount("Conquest", rbgIdx, "Rbg")
    if ConquestQueueFrame.ArenaRewardLarge then
        ConquestQueueFrame.ArenaRewardLarge:SetText(string.format("|cFFFFFFFF%d %s|r", arenaPoints, conquestIcon))
    end
    if ConquestQueueFrame.RatedBGRewardLarge then
        ConquestQueueFrame.RatedBGRewardLarge:SetText(string.format("|cFFFFFFFF%d %s|r", rbgPoints, conquestIcon))
    end
end

-- Hooks and Events
local battlefieldStatusCache = {}
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

f:SetScript("OnEvent", function(_, event, ...)
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    DebugPrint("GLOBAL", "Event: " .. tostring(event))
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ResetDailyIfNeeded()
        local inInst, instType = IsInInstance()
        instType = instType or "none"
        local isPvp = (instType == "pvp" or instType == "arena")
        if isPvp then
			C_Timer.After(1.5, function()
				local ok, err = pcall(function()
					if not currentBGState.isInBG then
						currentBGState.isInBG = true
						currentBGState.currentType = DetectPvPType() or PVP_TYPES.RANDOM_BG
						currentBGState.playerTeam = GetPlayerTeamByPvPType(currentBGState.currentType)
						currentBGState.bgStartTime = GetTime()
						currentBGState.currentMap = GetRealZoneText() or "Unknown"
						currentBGState.hasProcessedResult = false
						DebugPrint("GLOBAL", "Entered PvP zone: " .. tostring(currentBGState.currentMap))
					end
				end)
				if not ok then
					DebugPrint("ERRORS", "Timer failed: " .. tostring(err))
				end
			end)
        end
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        local foundActive = false
        local maxSlots = GetMaxBattlefieldID() or 5
        for i = 1, maxSlots do
            local status, mapName, instanceID, _, queueType = GetBattlefieldStatus(i)
            status = status or "none"
            mapName = mapName or "Unknown"
            instanceID = instanceID or "Unknown"
            if status == "active" then
                foundActive = true
                if not currentBGState.isInBG then
                    currentBGState.isInBG = true
                    currentBGState.currentType = DetectPvPType() or PVP_TYPES.RANDOM_BG
                    currentBGState.playerTeam = GetPlayerTeamByPvPType(currentBGState.currentType)
                    currentBGState.bgStartTime = GetTime()
                    currentBGState.currentMap = mapName
                    currentBGState.bgInstanceID = tostring(instanceID)
                    currentBGState.hasProcessedResult = false
                end
            end
			DebugPrint("GLOBAL", ("Slot %d: %s → %s"):format(i, tostring(battlefieldStatusCache[i]), tostring(status)))
            if status ~= battlefieldStatusCache[i] then
                if battlefieldStatusCache[i] == "active" and (status == "complete" or status == "none") then
                    currentBGState.bgInstanceID = tostring(instanceID)
                    currentBGState.lastBGEndTime = GetTime()
                    currentBGState.isInBG = false
                    CheckPvPMatchResult()
                end
                battlefieldStatusCache[i] = status
            end
        end
        if not foundActive and currentBGState.isInBG then
            currentBGState.isInBG = false
            currentBGState.lastBGEndTime = GetTime()
            CheckPvPMatchResult()
        end
    end
end)

local ArenaTracker = CreateFrame("Frame")
ArenaTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
ArenaTracker:RegisterEvent("ARENA_OPPONENT_UPDATE")
ArenaTracker:RegisterEvent("UNIT_HEALTH")
ArenaTracker:RegisterEvent("UNIT_MAXHEALTH")

ArenaTracker:SetScript("OnEvent", function(_, event, arg1)
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    if not IsInArena() then
        if ArenaTeams.isActive then
            ResetArena()
        end
        return
    end
    if not ArenaTeams.isActive then
        ArenaTeams.isActive = true
        ArenaTeams.isInitialized = false
        C_Timer.After(3, InitializeArenaTeams)
        return
    end
    if event == "ARENA_OPPONENT_UPDATE" then
        if not ArenaTeams.isInitialized then
            C_Timer.After(1, function()
                local ok = InitializeArenaTeams()
            end)
        end
        return
    end
    if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") then
        if not ArenaTeams.isInitialized or not ArenaTeams.isActive then
            return
        end
        if arg1 and (string.find(arg1, "player") or string.find(arg1, "party") or string.find(arg1, "arena")) then
            UpdateAllTeams()
            if #ArenaTeams.myTeam == 0 or #ArenaTeams.enemyTeam == 0 then
                return
            end
            local winner = CheckArenaWinner()
            if winner then
                if winner == "myTeam" then
                    DebugPrint("BATTLES", "Arena Victory detected!")
					ProcessPvPVictory()
                elseif winner == "enemyTeam" then
                    DebugPrint("BATTLES", "Arena Defeat detected!")
                end
                C_Timer.After(5, ResetArena)
            end
        end
    end
end)

local f2 = CreateFrame("Frame")
f2:RegisterEvent("ADDON_LOADED")
f2:SetScript("OnEvent", function(_, _, addon)
    if mQoL_Modules and not mQoL_Modules:ShouldLoadModule("BlizzardFixes") then return end
    if mQoL_DB and mQoL_DB.BlizzardFixes and mQoL_DB.BlizzardFixes.fixPvPRewards == false then return end
    if addon == "Blizzard_PVPUI" then
        pcall(CreateBonusFrameRewardLabel)
        pcall(CreateConquestRewardLabels)
        if HonorQueueFrame and HonorQueueFrame.BonusFrame then
            hooksecurefunc("HonorQueueFrameBonusFrame_Update", UpdateBonusFrameRewardLabel)
            UpdateBonusFrameRewardLabel()
        end
        if ConquestQueueFrame then
            hooksecurefunc("ConquestQueueFrame_Update", UpdateConquestRewardLabels)
            UpdateConquestRewardLabels()
        end
    end
end)

-- export
mQoL_FixPvPRewards = mQoL_FixPvPRewards or {}
mQoL_FixPvPRewards.DebugResetInfo = function()
    local serverTime = GetServerTime()
    local questResetTime = GetQuestResetTime()
    local lastReset = GetPvPResetTimestamp()
    local db = GetPlayerPvPDB()
    DebugPrint("GLOBAL", string.format("ServerTime=%d lastReset=%d lastBG=%s", serverTime, lastReset, tostring(db.lastBGTime)))
end

mQoL_FixPvPRewards.CheckResetStatus = function() return (StringToServerTime(GetPlayerPvPDB().lastBGTime) < GetPvPResetTimestamp()) end

DebugPrint("GLOBAL", "mQoL FixPvPRewards loaded (fixed)", "00FF00")