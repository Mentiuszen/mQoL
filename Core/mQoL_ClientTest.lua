local addonName = ...

mQoL_ClientTest = mQoL_ClientTest or {}

local function SafeCheck(fn)
    local ok, res = pcall(fn)
    return ok and res ~= nil and res ~= false
end

function mQoL_ClientTest:RunTests()
    local results = {
        hasEditMode = SafeCheck(function()
            return (C_EditMode ~= nil) or (EditModeManagerFrame ~= nil)
        end),
        hasCompactRaidFrames = SafeCheck(function()
            return (CompactUnitFrameProfiles ~= nil) or (CompactRaidFrameManager ~= nil)
        end),
        hasWeeklyRewards = SafeCheck(function()
            return C_WeeklyRewards ~= nil
        end),
        hasNameplates = SafeCheck(function()
            return (C_NamePlate ~= nil) or (GetCVar and GetCVar("nameplateShowEnemies") ~= nil)
        end),
        hasActionBars = SafeCheck(function()
            return (MainMenuBar ~= nil) or (ActionButton1 ~= nil)
        end),
        hasMailbox = SafeCheck(function()
            return (InboxFrame ~= nil) or (GetInboxNumItems ~= nil)
        end),
        hasFastAutoloot = SafeCheck(function()
            return (GetNumLootItems ~= nil) and (LootSlot ~= nil)
        end),
        hasGraphicsCVars = SafeCheck(function()
            return GetCVar and (GetCVar("farclip") ~= nil or GetCVar("graphicsViewDistance") ~= nil)
        end),
        hasProfessions = SafeCheck(function()
            return (C_TradeSkillUI ~= nil) or (GetTradeSkillInfo ~= nil) or (GetNumSkillLines ~= nil)
        end),
        hasPVEFrame = SafeCheck(function()
            return (PVEFrame ~= nil) or (LFDParentFrame ~= nil)
        end),
        hasMythicPlus = SafeCheck(function()
            return (C_MythicPlus ~= nil) or (C_LFGList ~= nil)
        end),
    }

    self.results = results
    return results
end

function mQoL_ClientTest:GetResults()
    if not self.results then
        return self:RunTests()
    end
    return self.results
end

function mQoL_ClientTest:IsModuleCompatible(moduleData)
    if not moduleData then return false end
    local key = moduleData.key
    local tests = self:GetResults()

    if key == "AccountOverview" then
        return tests.hasProfessions or true
    elseif key == "GeneralQoL" then
        return true
    elseif key == "NameplatesQoL" then
        return tests.hasNameplates
    elseif key == "ActionBarsQoL" then
        return tests.hasActionBars
    elseif key == "Mailbox" then
        return tests.hasMailbox
    elseif key == "Graphics" then
        return tests.hasGraphicsCVars
    elseif key == "EditMode" then
        return tests.hasEditMode
    elseif key == "RaidProfiles" then
        return tests.hasCompactRaidFrames
    elseif key == "DungeonTeleportsTab" then
        return tests.hasPVEFrame
    elseif key == "MythicPlusListing" then
        return tests.hasMythicPlus
    elseif key == "BlizzardFixes" then
        return false
    end

    return false
end

function mQoL_ClientTest:IsModuleHardlocked(moduleData)
    if not moduleData then return false end
    local key = moduleData.key
    local tests = self:GetResults()

    if key == "BlizzardFixes" then
        return true
    elseif key == "EditMode" and not tests.hasEditMode then
        return true
    elseif key == "DungeonTeleportsTab" and not tests.hasPVEFrame then
        return true
    elseif key == "MythicPlusListing" and not tests.hasMythicPlus then
        return true
    end

    return false
end

function mQoL_ClientTest:PrintReport(autoInfo)
    local toc = autoInfo and autoInfo.tocversion or "UNKNOWN"
    print(string.format("|cff00ff00[mQoL]|r |cff00bfffAuto Mode Active|r - Client TOC: %s. Environment tested successfully.", tostring(toc)))
end

function mQoL_ClientTest:GenerateAutoClientInfo(version, build, date, tocversion)
    local tests = self:RunTests()

    local autoInfo = {
        version = version or "Unknown",
        build = build or "0",
        date = date or "",
        tocversion = tonumber(tocversion) or 0,
        tree = "Auto",
        isRetail = false,
        isClassic = false,
        isLegion = false,
        isPandaria = false,
        isEra = false,
        isBCC = false,
        isMoP = false,
        isVanilla = false,
        isTBC = false,
        isAuto = true,
        tests = tests,
    }

    self:PrintReport(autoInfo)

    return autoInfo
end
