if not mQoL_Auto then return end
local A,C=mQoL_Auto,mQoL_Compat
local F=C.Function
local function Result(state,reason,adapter,data)
    return {state=state,reason=reason,adapter=adapter,data=data}
end
local function Ready(adapter,data) return Result("ready",nil,adapter,data) end
local function Missing(symbol) return Result("missing","Missing compatible API: "..symbol) end
local function Error(reason) return Result("error",tostring(reason)) end
local function Functions(paths)
    for _,p in ipairs(paths) do if not F(p) then return Missing(p) end end
    return Ready("functions")
end
local function Bool(v)
    if type(v)=="boolean" then return v end
    if v==1 or v=="1" or v=="true" then return true end
    if v==0 or v=="0" or v=="false" then return false end
end
A.Boolean=Bool
mQoL_CVar=mQoL_CVar or {}
local V=mQoL_CVar
function V:CanRead(name)
    local get=F("C_CVar.GetCVar") or F("GetCVar")
    if not get then return false,"Missing CVar getter" end
    local ok,value=pcall(get,name)
    if not ok then return false,tostring(value),"error" end
    if value==nil or value=="" then return false,"CVar not exposed: "..name end
    if type(value)~="string" and type(value)~="number" and type(value)~="boolean" then return false,"Unexpected CVar data: "..name,"error" end
    return true,value
end
function V:CanWrite(name)
    local ok,reason,state=self:CanRead(name)
    if not ok then return false,reason,state end
    if not (F("C_CVar.SetCVar") or F("SetCVar")) then return false,"Missing CVar setter" end
    return true
end
function V:ReadBoolean(name,fallback)
    local ok,value=self:CanRead(name)
    if ok then local b=Bool(value); if b~=nil then return b end end
    return fallback
end
function V:ReadNumber(name,fallback)
    local ok,value=self:CanRead(name)
    if ok then local n=tonumber(value); if C.Number(n) then return n end end
    return fallback
end
function V:Apply(name,value)
    if value==nil or value=="disable" then return true,"Not managed" end
    local ok,reason=self:CanWrite(name)
    if not ok then return false,reason end
    if type(value)=="boolean" then value=value and 1 or 0 end
    if type(value)~="number" and type(value)~="string" then return false,"Unsupported CVar value" end
    if type(value)=="number" and not C.Number(value) then return false,"Non-finite CVar value" end
    local set=F("C_CVar.SetCVar") or F("SetCVar")
    ok,reason=C.Write(set,name,value)
    if not ok then return false,reason end
    local read,actual=self:CanRead(name)
    if not read then return false,"Cannot verify CVar after write: "..tostring(actual) end
    local same=tostring(actual)==tostring(value)
    if tonumber(actual) and tonumber(value) then same=math.abs(tonumber(actual)-tonumber(value))<0.00001 end
    if type(actual)=="boolean" then same=actual==Bool(value) end
    if not same then return false,"Client rejected or clamped "..name.." (requested "..tostring(value)..", read "..tostring(actual)..")" end
    return true
end
local function ProbeCVar(f)
    local ok,value,state=V:CanRead(f.cvar)
    if not ok then return Result(state or "missing",value) end
    if f.valueType=="boolean" then value=Bool(value); if value==nil then return Error("Non-boolean CVar: "..f.cvar) end
    elseif f.valueType=="number" then value=tonumber(value); if not C.Number(value) then return Error("Non-numeric CVar: "..f.cvar) end end
    local r=Ready("cvar",value); r.canWrite=V:CanWrite(f.cvar); if not r.canWrite then r.reason="Read only: missing setter" end
    return r
end
local function SpecAdapter()
    if F("C_SpecializationInfo.GetSpecialization") and F("C_SpecializationInfo.GetSpecializationInfo") then return "C_SpecializationInfo.GetSpecialization","C_SpecializationInfo.GetSpecializationInfo" end
    if F("GetSpecialization") and F("GetSpecializationInfo") then return "GetSpecialization","GetSpecializationInfo" end
end
A.SpecAdapter=SpecAdapter
local function Layouts()
    local get=F("C_EditMode.GetLayouts")
    if not get then return Missing("C_EditMode.GetLayouts") end
    local ok,info=pcall(get)
    if not ok then return Error(info) end
    if info==nil then return Result("pending","Layout data not ready","editmode-v1") end
    -- Do not infer index-based Retail structures from an arbitrary array.
    if type(info)~="table" or type(info.layouts)~="table" or type(info.activeLayout)~="number" then return Error("Expected EditModeLayouts { layouts, activeLayout }") end
    for _,layout in ipairs(info.layouts) do
        if type(layout)~="table" or type(layout.layoutName)~="string" or type(layout.layoutType)~="number" then return Error("Malformed EditMode layout record") end
    end
    return Ready("editmode-v1",info)
end
A.ReadLayouts=Layouts
A.raidCVars={"raidFramesDisplayIncomingHeals","raidFramesDisplayPowerBars","raidFramesDisplayAggroHighlight","raidFramesDisplayClassColor","raidOptionDisplayPets","raidOptionDisplayMainTankAndAssist","raidFramesDisplayOnlyDispellableDebuffs","raidFramesHealthText","raidOptionShowBorders","raidFramesHeight","raidFramesWidth"}
A.raidOptions={"useClassColors","displayPets","displayMainTankAndAssist","displayHealPrediction","displayOnlyDispellableDebuffs","healthText","displayBorder","displayPowerBar","displayAggroHighlight","keepGroupsTogether","sortBy","horizontalGroups","frameHeight","frameWidth"}
local function RaidRead()
    if F("GetActiveRaidProfile") and F("GetRaidProfileOption") then
        local ok,name=pcall(GetActiveRaidProfile)
        if not ok then return Error(name) end
        if type(name)=="string" and name~="" then
            local values={}
            for _,key in ipairs(A.raidOptions) do
                local read,value=pcall(GetRaidProfileOption,name,key)
                if not read then return Error(value) end
                if value~=nil and (type(value)=="boolean" or type(value)=="string" or C.Number(value)) then values[key]=value end
            end
            if next(values) then return Ready("raid-options-v1",{name=name,values=values}) end
        end
    end
    local values={}
    for _,name in ipairs(A.raidCVars) do local ok,value=V:CanRead(name); if ok then values[name]=value end end
    if not next(values) then return Missing("raid profile getters or supported raid CVars") end
    return Ready("raid-cvars-v1",{values=values})
end
A.ReadRaid=RaidRead
local function MailFields()
    if C.HasMethods(MailFrame,"IsShown") and C.HasMethods(SendMailFrame,"IsShown") and C.HasMethods(SendMailNameEditBox,"SetText","GetText") and C.HasMethods(SendMailSubjectEditBox,"SetText","GetText") then return Ready("mail-fields") end
    return Missing("MailFrame, SendMailFrame, SendMailNameEditBox, SendMailSubjectEditBox methods")
end
local modernMailFunctions={"C_Container.GetContainerNumSlots","C_Container.GetContainerItemInfo","C_Container.PickupContainerItem","C_Item.GetItemInfo","C_Item.DoesItemExist","C_Item.IsLocked","ItemLocation.CreateFromBagAndSlot"}
local legacyMailFunctions={"GetContainerNumSlots","GetContainerItemInfo","PickupContainerItem","GetItemInfo"}
function A:UseModernMailboxAPI()
    for _,path in ipairs(modernMailFunctions) do if not F(path) then return false end end
    return true
end
local function Container()
    local fields=MailFields(); if fields.state~="ready" then return fields end
    local modern=A:UseModernMailboxAPI()
    local functions=Functions(modern and modernMailFunctions or legacyMailFunctions)
    if functions.state~="ready" then return functions end
    local common=Functions({"GetSendMailItemLink","HasSendMailItem","ClearCursor","ClickSendMailItemButton"})
    if common.state~="ready" then return common end
    if not C.Number(NUM_BAG_SLOTS) or NUM_BAG_SLOTS<0 or NUM_BAG_SLOTS%1~=0 or NUM_BAG_SLOTS>20 then return Missing("NUM_BAG_SLOTS limit") end
    if not C.Number(ATTACHMENTS_MAX_SEND) or ATTACHMENTS_MAX_SEND<1 or ATTACHMENTS_MAX_SEND>100 or ATTACHMENTS_MAX_SEND%1~=0 then return Missing("ATTACHMENTS_MAX_SEND limit") end
    return Ready(modern and "container-table" or "container-tuple",{namespace=modern and "C_Container." or "",bags=NUM_BAG_SLOTS,attachments=ATTACHMENTS_MAX_SEND})
end
A.ContainerProbe=Container
local function Teleports()
    local known=F("IsSpellKnownOrOverridesKnown") or F("IsPlayerSpell") or F("IsSpellKnown") or F("C_SpellBook.IsSpellKnown")
    local name=F("C_Spell.GetSpellName") or F("GetSpellInfo")
    if not known or not name then return Missing("known-spell query and localized spell-name getter") end
    local spells={}
    for _,id in ipairs(A.teleportIDs) do
        local ok,isKnown=pcall(known,id)
        if not ok then return Error(isKnown) end
        if isKnown~=nil and type(isKnown)~="boolean" then return Error("Known-spell query must return boolean") end
        if isKnown then
            local good,label=pcall(name,id)
            if not good then return Error(label) end
            if type(label)=="string" and label~="" then spells[#spells+1]={id=id,name=label} end
        end
    end
    return Ready("known-spells",spells)
end
A.ReadTeleports=Teleports
local probes={}
probes.saved=function() return Ready("saved-data") end
probes.unsupported=function(f) return Result("missing",f.reason) end
probes.functions=function(f) return Functions(f.requires) end
probes.cvar=ProbeCVar
probes.identity=function()
    local r=Functions({"UnitName","GetRealmName"}); if r.state~="ready" then return r end
    local ok,name=pcall(UnitName,"player"); local good,realm=pcall(GetRealmName)
    if not ok or not good then return Error(not ok and name or realm) end
    if name==nil or realm==nil or name=="" or realm=="" then return Result("pending","Waiting for player identity") end
    if type(name)~="string" or type(realm)~="string" then return Error("Invalid player identity") end
    return Ready("character",{name=name,realm=realm})
end
probes.specialization=function()
    local get,info=SpecAdapter(); if not get then return Missing("complete specialization getter pair") end
    local ok,index=C.Read(get); if not ok then return Error(index) end
    if index==nil or index==0 then return Ready("specialization",{getter=get,info=info}) end
    if not C.Number(index) then return Error("Specialization index is not numeric") end
    local good,id,name=C.Read(info,index); if not good then return Error(id) end
    if id~=nil and not C.Number(id) then return Error("Invalid specialization identifier") end
    return Ready("specialization",{getter=get,info=info,id=id,name=name})
end
probes.professions=function()
    if F("GetProfessions") and F("GetProfessionInfo") then return Ready("profession-slots") end
    if F("GetNumSkillLines") and F("GetSkillLineInfo") then return Ready("skill-lines") end
    return Missing("GetProfessions + GetProfessionInfo or skill-line getters")
end
probes.weekly=function()
    if not F("C_WeeklyRewards.GetActivities") then return Missing("C_WeeklyRewards.GetActivities") end
    local ok,data=C.Read("C_WeeklyRewards.GetActivities"); if not ok then return Error(data) end
    if data==nil then return Result("pending","Weekly activities are not ready") end
    if type(data)~="table" then return Error("Weekly activities must be a table") end
    for _,v in ipairs(data) do
        if type(v)~="table" or not C.Number(v.type) or not C.Number(v.index) or not C.Number(v.progress) or not C.Number(v.threshold) then return Error("Invalid weekly activity record") end
    end
    return Ready("weekly-activities",data)
end
probes.bank=function()
    if not F("C_Bank.FetchDepositedMoney") or not (type(Enum)=="table" and type(Enum.BankType)=="table" and C.Number(Enum.BankType.Account)) then return Missing("C_Bank.FetchDepositedMoney + Enum.BankType.Account") end
    return Ready("account-bank",{bankType=Enum.BankType.Account})
end
probes.appearance=function(f)
    if F(f.getter) and F(f.setter) then
        local ok,v=C.Read(f.getter); if not ok then return Error(v) end
        local b=Bool(v); if b==nil then return Error("Invalid appearance state") end
        local r=Ready("appearance",b); r.canWrite=true; return r
    end
    return ProbeCVar(f)
end
probes.fastloot=function()
    local r=Functions({"GetNumLootItems","LootSlot","CloseLoot","IsModifiedClick"}); if r.state~="ready" then return r end
    if V:ReadBoolean("autoLootDefault")==nil then return Missing("autoLootDefault boolean") end
    return Ready("bounded-loot",false)
end
probes.actionbar=function(f)
    if F("Settings.GetValue") and F("Settings.SetValue") then
        local ok,v=C.Read("Settings.GetValue","PROXY_SHOW_ACTIONBAR_"..f.bar)
        if ok and Bool(v)~=nil then local r=Ready("settings-proxy",Bool(v)); r.canWrite=true; return r end
    end
    if f.bar<=5 and F("GetActionBarToggles") and F("SetActionBarToggles") and (F("InterfaceOptions_UpdateMultiActionBars") or F("MultiActionBar_Update")) then
        local function pack(...) return {n=select("#",...),...} end
        local values=pack(pcall(GetActionBarToggles))
        if not values[1] then return Error(values[2]) end
        -- Historical getters can represent a disabled bar as nil. Require the
        -- full four-return signature rather than guessing from an empty call.
        if values.n>=5 then
            local raw=values[f.bar]
            local v=Bool(raw)
            if raw==nil then v=false end
            if v~=nil then local r=Ready("actionbar-toggles",v); r.canWrite=true; return r end
        end
    end
    return Missing("compatible getter/setter for action bar "..f.bar)
end
probes.friends=function()
    if F("C_FriendList.GetNumFriends") and F("C_FriendList.GetFriendInfoByIndex") then return Ready("friends-table") end
    if F("GetNumFriends") and F("GetFriendInfo") then return Ready("friends-tuple") end
    return Missing("complete friends getter pair")
end
probes.mailfields=MailFields
probes.containers=Container
probes.layouts=Layouts
probes.layoutApply=function()
    local r=Layouts(); if r.state~="ready" then return r end
    if not F("C_EditMode.SetActiveLayout") then return Missing("C_EditMode.SetActiveLayout") end
    for _,layout in ipairs(r.data.layouts) do if not C.Number(layout.layoutIdentifier) then return Missing("explicit layoutIdentifier for layout application") end end
    return r
end
probes.layoutExport=function()
    local r=Layouts(); if r.state~="ready" then return r end
    if not F("C_EditMode.ConvertLayoutInfoToString") then return Missing("C_EditMode.ConvertLayoutInfoToString") end
    return r
end
probes.layoutAuto=function()
    local r=probes.layoutApply(); if r.state~="ready" then return r end
    if not SpecAdapter() then return Missing("specialization getters for auto-switching") end
    return r
end
probes.raidRead=RaidRead
probes.raidWrite=function()
    local r=RaidRead(); if r.state~="ready" then return r end
    if r.adapter=="raid-options-v1" then
        local funcs=Functions({"SetRaidProfileOption","SetActiveRaidProfile","CompactUnitFrameProfiles_ApplyCurrentSettings"}); if funcs.state~="ready" then return funcs end
    elseif not (F("C_CVar.SetCVar") or F("SetCVar")) then return Missing("CVar setter") end
    return r
end
probes.raidPositions=function()
    local r=RaidRead(); if r.state~="ready" then return r end
    if r.adapter~="raid-options-v1" then return Missing("legacy raid options adapter") end
    local funcs=Functions({"GetRaidProfileSavedPosition","SetRaidProfileSavedPosition","CompactRaidFrameManager_ResizeFrame_LoadPosition"})
    if funcs.state~="ready" then return funcs end
    if not CompactRaidFrameManager then return Missing("CompactRaidFrameManager") end
    return r
end
probes.pve=function()
    if not C.HasMethods(PVEFrame,"HookScript","GetWidth") then return Missing("PVEFrame") end
    if not C.HasMethods(PVEFrameTab3,"GetID","GetPoint") then return Missing("PVEFrameTab3") end
    return Ready("shared-pve-frame")
end
probes.teleports=Teleports
probes.teleportCast=function()
    local r=Teleports(); if r.state~="ready" then return r end
    if not F("CreateFrame") or not F("SecureActionButton_OnClick") then return Missing("SecureActionButton template implementation") end
    return r
end
probes.cooldowns=function()
    if F("C_Spell.GetSpellCooldown") then return Ready("cooldown-table") end
    if F("GetSpellCooldown") then return Ready("cooldown-tuple") end
    return Missing("spell cooldown getter")
end
probes.keystone=function()
    local r=Functions({"C_MythicPlus.GetOwnedKeystoneChallengeMapID","C_MythicPlus.GetOwnedKeystoneLevel"}); if r.state~="ready" then return r end
    local ok,map=C.Read("C_MythicPlus.GetOwnedKeystoneChallengeMapID"); local good,level=C.Read("C_MythicPlus.GetOwnedKeystoneLevel")
    if not ok or not good then return Error(not ok and map or level) end
    if (map~=nil and not C.Number(map)) or (level~=nil and not C.Number(level)) then return Error("Invalid keystone identifiers") end
    return Ready("owned-keystone",{mapID=map,level=level})
end
probes.communication=function()
    local r=Functions({"C_ChatInfo.RegisterAddonMessagePrefix","C_ChatInfo.SendAddonMessage","GetNumGroupMembers","IsInRaid","UnitName"})
    if r.state~="ready" then return r end
    return Ready("mqol-auto-key-v1")
end
probes.listingRead=function()
    local r=Functions({"C_LFGList.GetActiveEntryInfo"}); if r.state~="ready" then return r end
    local ok,data=C.Read("C_LFGList.GetActiveEntryInfo"); if not ok then return Error(data) end
    if data~=nil and type(data)~="table" then return Error("Invalid active LFG listing") end
    return Ready("active-entry",data)
end
mQoL_ClientTest=mQoL_ClientTest or {}
mQoL_ClientTest.results={modules={}}
mQoL_ClientTest.generation=0
local T=mQoL_ClientTest
function T:Probe(f,phase)
    local fn=probes[f.kind]
    local ok,r=pcall(fn or function() return Missing("unimplemented probe "..f.kind) end,f)
    if not ok then r=Error(r) end
    if f.protected and r.state=="ready" and not F("InCombatLockdown") then r=Missing("InCombatLockdown for protected operation") end
    if f.provider and r.state=="missing" then
        local state,reason=C.AddOnState(f.provider)
        if state=="loading" or state=="available" then r.state="pending"; r.reason="Waiting for "..f.provider..": "..tostring(r.reason)
        elseif state=="error" then r=Error(reason) end
    end
    r.phase=phase; return r
end
function T:Refresh(phase,providerName)
    phase=phase or "manual"; self.generation=self.generation+1; A.scanCount=A.scanCount+1
    for _,m in ipairs(A.catalog) do
        local old=self.results.modules[m.key]; local features=old and old.features or {}
        for _,f in ipairs(m.features) do
            local refresh=phase=="startup" or phase=="manual" or phase=="PLAYER_LOGIN" or features[f.key]==nil or (f.events and f.events[phase])
            if phase=="ADDON_LOADED" and f.provider and providerName~=f.provider then refresh=false end
            if refresh then features[f.key]=self:Probe(f,phase) end
        end
        local count={ready=0,pending=0,missing=0,error=0}
        for _,r in pairs(features) do count[r.state]=count[r.state]+1 end
        local state="unavailable"
        if count.ready>0 then state=(count.missing+count.pending+count.error>0) and "partial" or "ready"
        elseif count.pending>0 then state="pending" elseif count.error>0 then state="error" end
        if m.hardlocked then state="unavailable" end
        self.results.modules[m.key]={state=state,features=features,counts=count,phase=phase}
    end
    self.results.generation=self.generation; self.results.phase=phase
    return self.results
end
function T:GetResults() return self.results end
function T:EvaluateModule(m) return self.results.modules[type(m)=="table" and m.key or m] end
function T:IsModuleCompatible(m)
    local r=self:EvaluateModule(m); return r and (r.state=="ready" or r.state=="partial" or r.state=="pending") or false
end
function T:IsModuleHardlocked(m) return m and (m.key=="BlizzardFixes" or m.hardlocked==true) or false end

-- The original registry performs an initial legacy migration when its file is
-- loaded. Make observations available before that; do not initialize modules.
T:Refresh("startup")
