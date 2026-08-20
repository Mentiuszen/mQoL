local addonName = ...

mQoL_Main = mQoL_Main or {}

function mQoL_Main:SyncCompatibilityState()
    self.db = {
        settings = {
            general = mQoL_General and mQoL_General.db and mQoL_General.db.settings or {},
            nameplates = mQoL_Nameplates and mQoL_Nameplates.db and mQoL_Nameplates.db.settings or {},
            actionBars = mQoL_ActionBars and mQoL_ActionBars.db and mQoL_ActionBars.db.settings or {},
        },
        barsChecksums = mQoL_ActionBars and mQoL_ActionBars.db and mQoL_ActionBars.db.barsChecksums or {},
    }

    self.ApplySetting = {
        General = mQoL_General and mQoL_General.ApplySetting and mQoL_General.ApplySetting.General or {},
        Nameplates = mQoL_Nameplates and mQoL_Nameplates.ApplySetting and mQoL_Nameplates.ApplySetting.Nameplates or {},
        ActionBars = mQoL_ActionBars and mQoL_ActionBars.ApplySetting and mQoL_ActionBars.ApplySetting.ActionBars or {},
    }
end

function mQoL_Main:InitializeDB()
    if mQoL_General then mQoL_General:InitializeDB() end
    if mQoL_Nameplates then mQoL_Nameplates:InitializeDB() end
    if mQoL_ActionBars then mQoL_ActionBars:InitializeDB() end

    self:SyncCompatibilityState()
end

function mQoL_Main:ApplySettings()
    if mQoL_General and mQoL_General.db then
        mQoL_General:ApplySettings(mQoL_General.db.settings)
    end
    if mQoL_Nameplates and mQoL_Nameplates.db then
        C_Timer.After(0.5, function()
            mQoL_Nameplates:ApplySettings(mQoL_Nameplates.db.settings)
        end)
    end
    if mQoL_ActionBars and mQoL_ActionBars.db then
        mQoL_ActionBars:ApplyVisibilitySettings(mQoL_ActionBars.db.settings)
        mQoL_ActionBars:ApplySettings(mQoL_ActionBars.db.settings)
    end
    self:SyncCompatibilityState()
end

function mQoL_Main:ApplyGeneralSettings(settings)
    if mQoL_General then
        mQoL_General:ApplySettings(settings)
    end
end

function mQoL_Main:ApplyNameplateSettings(settings)
    if mQoL_Nameplates then
        mQoL_Nameplates:ApplySettings(settings)
    end
end

function mQoL_Main:ApplyActionBarVisibilitySettings(settings)
    if mQoL_ActionBars then
        mQoL_ActionBars:ApplyVisibilitySettings(settings)
    end
end

function mQoL_Main:ApplyActionBarSettings(settings)
    if mQoL_ActionBars then
        mQoL_ActionBars:ApplySettings(settings)
    end
end

function mQoL_Main:CreateGeneralPanel(parent)
    return mQoL_General and mQoL_General:CreatePanel(parent)
end

function mQoL_Main:CreateNameplatesPanel(parent)
    return mQoL_Nameplates and mQoL_Nameplates:CreatePanel(parent)
end

function mQoL_Main:CreateActionBarsPanel(parent)
    return mQoL_ActionBars and mQoL_ActionBars:CreatePanel(parent)
end

function mQoL_Main:Legion_ForceUpdateGridVisibility(show)
    if mQoL_ActionBars then
        return mQoL_ActionBars:Legion_ForceUpdateGridVisibility(show)
    end
end

function mQoL_Main:IsActionBarChecksumEnabled()
    return mQoL_ActionBars and mQoL_ActionBars:IsActionBarChecksumEnabled() or false
end

-- Kept for addons that used the old global helper.
function IsActionBarChecksumEnabled()
    return mQoL_Main:IsActionBarChecksumEnabled()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == addonName then
        mQoL_Main:InitializeDB()
    elseif event == "PLAYER_LOGIN" then
        if not mQoL_Main.db then
            mQoL_Main:InitializeDB()
        else
            mQoL_Main:SyncCompatibilityState()
        end
    end
end)
