-- Auto is an availability layer on the ORIGINAL addon. It does not construct
-- another Hub, replace the module registry, or gate runtime on aggregate state.
if not mQoL_Auto then return end
local A,C,T,M=mQoL_Auto,mQoL_Compat,mQoL_ClientTest,mQoL_Modules
local addonName=...
A.route="SHARED_UI"
A.pendingHooks={}

function A:GetFeature(moduleKey,featureKey,refresh)
    local definition=self.byKey[moduleKey] and self.byKey[moduleKey].byFeature[featureKey]
    if not definition then return nil end
    local result=T:EvaluateModule(moduleKey)
    if refresh or not result then
        local probe=T:Probe(definition,"action")
        if result then result.features[featureKey]=probe end
        return probe
    end
    return result.features[featureKey]
end
function A:CanUse(moduleKey,featureKey,write)
    local r=self:GetFeature(moduleKey,featureKey,true)
    if not r then return true end -- no definition is not proof of missing API
    return r.state=="ready" and (not write or r.canWrite~=false),r.reason,r
end
function A:Refresh(phase,provider)
    -- Read only. In particular no SetCVar, setting capture, initializer replay,
    -- migrations, frame replacement, or changes to module selections here.
    local result=T:Refresh(phase or "manual",provider)
    self:RefreshLegacyResults()
    if self.RefreshOptionRows then self:RefreshOptionRows() end
    return result
end
function A:RefreshLegacyResults()
    local ci=mQoL_VersionDetection.clientInfo
    local function any(moduleKey,features)
        for _,key in ipairs(features) do
            local r=self:GetFeature(moduleKey,key)
            if r and (r.state=="ready" or r.state=="pending") then return true end
        end
        return false
    end
    local result=T.results
    result.hasEditMode=C.Function("C_EditMode.GetLayouts")~=nil
    result.hasCompactRaidFrames=any("RaidProfiles",{"capture","apply"})
    result.hasWeeklyRewards=any("AccountOverview",{"weekly"})
    result.hasNameplates=any("NameplatesQoL",{"enemyNameplates","friendlyNameplates","maxDistance"})
    result.hasActionBars=any("ActionBarsQoL",{"alwaysShowActionBars","autoSelfCast","showActionBars2","showActionBars3","showActionBars4","showActionBars5"})
    result.hasMailbox=C.Function("GetInboxNumItems")~=nil or C.HasMethods(MailFrame,"IsShown")
    result.hasFastAutoloot=any("GeneralQoL",{"fastAutoLoot"})
    result.hasGraphicsCVars=any("Graphics",{"ViewDistance","FogDistance"})
    result.hasProfessions=any("AccountOverview",{"professions"})
    result.hasPVEFrame=C.HasMethods(PVEFrame,"HookScript") or C.HasMethods(LFDParentFrame,"HookScript")
    result.hasMythicPlus=any("MythicPlusListing",{"ownKey","listingRead"})
    ci.tests=result
end

-- Capabilities describe actual API, not a reduced set of AM-R2 replacements.
function T:IsModuleCompatible(module)
    if not module then return false end
    local key=module.key
    local r=self:EvaluateModule(key)
    if key=="BlizzardFixes" then return false end
    if key=="EditMode" then
        return C.Function("C_EditMode.GetLayouts")~=nil
    end
    if key=="MythicPlusListing" then
        -- The shared module remains Retail-only. Exposing an API in diagnostics
        -- does not invent an integration or masquerade as Retail.
        return false
    end
    if key=="DungeonTeleportsTab" then
        return (C.HasMethods(PVEFrame,"HookScript") and C.HasMethods(PVEFrameTab3,"GetID"))
            or C.AddOnState("Blizzard_GroupFinder")=="available"
    end
    return r and (r.state=="ready" or r.state=="partial" or r.state=="pending") or false
end
function T:IsModuleHardlocked(module) return not module or module.key=="BlizzardFixes" end
function T:RunTests() A:Refresh("manual"); return self.results end
function T:PrintReport() A:PrintReport() end

-- Forever has its own identity, but uses the same availability checks as Auto.
-- The original registry object and its runtime method are left in place.
local baseCompatible,baseHardlocked=M.IsModuleCompatible,M.IsModuleHardlocked
function M:IsModuleCompatible(module) return T:IsModuleCompatible(module) end
function M:IsModuleHardlocked(module) return T:IsModuleHardlocked(module) end
A.originalCompatible,A.originalHardlocked=baseCompatible,baseHardlocked
A.originalShouldLoad=M.ShouldLoadModule
function M:GetCompatibleModules()
    -- The ORIGINAL Module Manager shows the same modules. Unavailable entries
    -- are annotated/guarded individually, not silently removed from the Hub.
    local result={}
    for _,module in ipairs(self.AvailableModules) do result[#result+1]=module end
    table.sort(result,function(a,b) return (a.order or 0)<(b.order or 0) end)
    return result
end
local baseSet=M.SetModuleEnabled
function M:SetModuleEnabled(key,enabled,allowUnsupported)
    if not enabled and self:GetModule(key) then
        mQoL_DB=mQoL_DB or {};mQoL_DB.Modules=mQoL_DB.Modules or {}
        mQoL_DB.Modules[key]=false
        return true
    end
    return baseSet(self,key,enabled,allowUnsupported)
end

-- There is no automatic conversion of profiles or account history. Only
-- explicitly equivalent scalar settings are copied, and only into empty keys.
-- Existing shared/legacy values win; all AM-R2 data stays intact.
local scalarMaps={
    GeneralQoL={autoLoot="autoLoot",autoQuestTracking="autoQuestTracking",showMyName="showMyName",showLuaErrors="showLuaErrors",fastAutoLoot="fastAutoLoot",showHead="showHead",showCloak="showCloak",autoConsolidatedBuffs="autoConsolidatedBuffs"},
    NameplatesQoL={enemyNameplates="showEnemyNameplates",friendlyNameplates="showFriendlyNameplates",maxDistance="nameplateMaxDistance",enemyPets="showEnemyPets",enemyGuardians="showEnemyGuardians",enemyTotems="showEnemyTotems",enemyMinions="showEnemyMinions",friendlyPets="showFriendlyPets",friendlyGuardians="showFriendlyGuardians",friendlyTotems="showFriendlyTotems",friendlyMinions="showFriendlyMinions"},
    ActionBarsQoL={alwaysShowActionBars="alwaysShowActionBars",autoPushSpellToActionBar="autoPushSpellToActionBar",autoSelfCast="autoSelfCast",showActionBars2="showActionBars2",showActionBars3="showActionBars3",showActionBars4="showActionBars4",showActionBars5="showActionBars5",showActionBars6="showActionBars6",showActionBars7="showActionBars7",showActionBars8="showActionBars8"},
    Graphics={ViewDistance="ViewDistance",FogDistance="FogDistance"},
}
function A:ImportEquivalentR2Settings()
    if self.importChecked then return end
    self.importChecked=true
    if type(mQoL_AutoDB)~="table" or type(mQoL_AutoDB.settings)~="table" or type(mQoL_DB)~="table" then return end
    local legacySection={GeneralQoL="general",NameplatesQoL="nameplates",ActionBarsQoL="actionBars"}
    self.importedSettings=0
    for moduleKey,map in pairs(scalarMaps) do
        local source=mQoL_AutoDB.settings[moduleKey]
        if type(source)=="table" then
            local module=mQoL_DB[moduleKey]
            if module==nil then module={};mQoL_DB[moduleKey]=module end
            if type(module)=="table" and (module.settings==nil or type(module.settings)=="table") then
                if module.settings==nil then
                    local legacy=mQoL_DB.MainQoL and mQoL_DB.MainQoL.settings
                    module.settings=C.Copy(type(legacy)=="table" and legacy[legacySection[moduleKey]] or {})
                    if type(module.settings)~="table" then module.settings={} end
                end
                local target=module.settings
                if moduleKey=="Graphics" then
                    if target.Graphics==nil then target.Graphics={} end
                    target=target.Graphics
                end
                if type(target)=="table" then
                    for from,to in pairs(map) do
                        local value=source[from]
                        if target[to]==nil and (type(value)=="boolean" or C.Number(value) or value=="disable") then
                            target[to]=value;self.importedSettings=self.importedSettings+1
                        end
                    end
                end
            end
        end
    end
end

function A.HookWhenAvailable(name,callback)
    if type(name)~="string" or type(callback)~="function" then return false end
    local entry={name=name,callback=callback}
    A.pendingHooks[#A.pendingHooks+1]=entry
    A:InstallPendingHooks()
    return entry.installed==true
end
function A:InstallPendingHooks()
    if type(hooksecurefunc)~="function" then return end
    for _,entry in ipairs(self.pendingHooks) do
        if not entry.installed and C.Function(entry.name) then
            local ok,err=pcall(hooksecurefunc,entry.name,entry.callback)
            if ok then entry.installed=true else C.Report("Hook "..entry.name,err) end
        end
    end
end
function A:PrintReport()
    local ci=mQoL_VersionDetection.clientInfo
    print("[mQoL AM-R3] "..ci.tree.." / "..ci.versionKey.." | TOC "..tostring(ci.tocversion).." | shared original Hub")
    print("Auto checks availability only. Module runtime follows the original selection; partial is NOT a module/UI gate.")
    for _,module in ipairs(self.catalog) do
        local r=T:EvaluateModule(module.key)
        if r then
            print(module.key..": API "..r.state.." | selected="..tostring(M:IsModuleEnabled(module.key)))
            for _,f in ipairs(module.features) do
                local v=r.features[f.key]
                if v and v.state~="ready" then print("  "..f.key..": "..v.state.." — "..tostring(v.reason)) end
            end
        end
    end
    print("MythicPlusListing: original Retail-only implementation; API results are not a new Auto integration.")
    for key,err in pairs(self.errors) do print("ERROR "..key..": "..err) end
end

A:Refresh("startup")
SlashCmdList=SlashCmdList or {}
SLASH_MQOL_AUTO1="/mqolauto"
SlashCmdList.MQOL_AUTO=function(text)
    if (text or ""):match("^%s*refresh%s*$") then A:Refresh("manual") end
    A:PrintReport()
end
-- No /mqol registration here: the original Hub exclusively owns that command.
local eventFrame=CreateFrame("Frame")
A.eventFrame=eventFrame
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","MAIL_SHOW","SPELLS_CHANGED","PLAYER_SPECIALIZATION_CHANGED","SKILL_LINES_CHANGED","TRADE_SKILL_SHOW","WEEKLY_REWARDS_UPDATE","BANKFRAME_OPENED","EDIT_MODE_LAYOUTS_UPDATED","CHALLENGE_MODE_MAPS_UPDATE","PLAYER_REGEN_ENABLED"}) do
    local ok,err=pcall(eventFrame.RegisterEvent,eventFrame,event)
    if not ok then A.unsupportedEvents=A.unsupportedEvents or {};A.unsupportedEvents[event]=tostring(err) end
end
eventFrame:SetScript("OnEvent",function(_,event,name)
    local ok,err=pcall(function()
        if event=="ADDON_LOADED" and name==(addonName or "mQoL") then A:ImportEquivalentR2Settings() end
        if event=="ADDON_LOADED" or event=="MAIL_SHOW" then A:InstallPendingHooks() end
        if event=="PLAYER_REGEN_ENABLED" and A.FlushDeferredSettings then A:FlushDeferredSettings() end
        A:Refresh(event,name)
    end)
    if not ok then C.Report("Availability "..event,err) end
end)
mQoL_VersionDetection:Lock()
