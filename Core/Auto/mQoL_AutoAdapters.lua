-- Small API adapters used by the ORIGINAL panels/controllers. No replacement UI,
-- module registry, initializer ownership, or version-flag impersonation.
if not mQoL_Auto then return end
local A,C,V=mQoL_Auto,mQoL_Compat,mQoL_CVar
local F=C.Function
local function pack(...) return {n=select('#',...),...} end
local function disabled(value) return value==nil or value=='disable' end
A.deferredSettings={}
local function report(key,ok,reason)
    if not ok then C.Report(key,reason) else A.errors[key]=nil end
    return ok,reason
end
function A:ReadActionBar(bar)
    local r=self:GetFeature('ActionBarsQoL','showActionBars'..bar,true)
    if r and r.state=='ready' then return r.data,r.adapter end
    return nil,nil,r and r.reason or 'Unknown action bar'
end
function A:HasExtraActionBars()
    for bar=6,8 do if self:ReadActionBar(bar)~=nil then return true end end
    return false
end
function V:ReadSettingBoolean(key,fallback)
    local bar=tonumber(tostring(key):match('^PROXY_SHOW_ACTIONBAR_(%d+)$'))
    if bar then
        local value=A:ReadActionBar(bar)
        if value~=nil then return value end
    end
    local get=F('Settings.GetValue')
    if get then
        local ok,value=pcall(get,key)
        if ok then local b=A.Boolean(value);if b~=nil then return b end end
    end
    return fallback
end
local function legacyValues()
    local getter=F('GetActionBarToggles')
    if not getter then return nil,'Missing GetActionBarToggles' end
    local values=pack(pcall(getter))
    if not values[1] then return nil,values[2] end
    if values.n<5 then return nil,'Incomplete action bar toggle tuple' end
    local out={}
    for i=1,4 do
        local raw=values[i+1]
        out[i]=A.Boolean(raw)
        if raw==nil then out[i]=false end
        if out[i]==nil then return nil,'Invalid action bar toggle '..i end
    end
    if values.n>=6 then
        out[5]=A.Boolean(values[6]);if values[6]==nil then out[5]=false end
    else out[5]=V:ReadBoolean('alwaysShowActionBars') end
    if out[5]==nil then return nil,'Cannot preserve grid visibility' end
    return out
end
local function legacyWrite(values)
    local previous={}
    for i=1,4 do
        local name='SHOW_MULTI_ACTIONBAR_'..i
        previous[i]=_G[name]
        -- The old FrameXML treats nil as hidden (and the string "0" is truthy).
        _G[name]=values[i] and 1 or nil
    end
    previous[5]=ALWAYS_SHOW_MULTIBARS
    ALWAYS_SHOW_MULTIBARS=values[5] and 1 or nil
    local ok,reason
    if F('InterfaceOptions_UpdateMultiActionBars') then
        -- Historical FrameXML performs SetActionBarToggles + frame updates here.
        ok,reason=C.Write('InterfaceOptions_UpdateMultiActionBars')
    else
        ok,reason=C.Write('SetActionBarToggles',values[1],values[2],values[3],values[4],values[5])
        if ok and F('MultiActionBar_Update') then ok,reason=C.Write('MultiActionBar_Update') end
    end
    if not ok then
        for i=1,4 do _G['SHOW_MULTI_ACTIONBAR_'..i]=previous[i] end
        ALWAYS_SHOW_MULTIBARS=previous[5]
    end
    return ok,reason
end
function A:ApplyActionBar(key,value)
    local errorKey='ActionBars.'..key
    if disabled(value) then self.deferredSettings[key]=nil;return true end
    if type(value)~='boolean' then return report(errorKey,false,'Expected a boolean bar setting') end
    if not mQoL_Modules:ShouldLoadModule('ActionBarsQoL') then return false,'Module disabled' end
    if not F('InCombatLockdown') then return report(errorKey,false,'Missing combat-state API') end
    if C.InCombat() then self.deferredSettings[key]=value;return false,'Deferred until combat ends' end
    self.deferredSettings[key]=nil
    local bar=tonumber(key:match('^showActionBars(%d+)$'))
    if not bar then return report(errorKey,false,'Unknown action bar') end
    local before,adapter,reason=self:ReadActionBar(bar)
    if before==nil then return report(errorKey,false,reason) end
    if before==value then return report(errorKey,true) end
    local ok
    if adapter=='settings-proxy' then
        ok,reason=C.Write('Settings.SetValue','PROXY_SHOW_ACTIONBAR_'..bar,value)
        if ok and F('MultiActionBar_Update') then ok,reason=C.Write('MultiActionBar_Update') end
    elseif adapter=='actionbar-toggles' then
        local values;values,reason=legacyValues()
        if values then values[bar-1]=value;ok,reason=legacyWrite(values) else ok=false end
    else ok=false;reason='No matching action bar adapter' end
    if ok then
        local actual=self:ReadActionBar(bar)
        if actual~=value then ok=false;reason='Bar setter did not retain the requested value' end
    end
    return report(errorKey,ok,reason)
end
function A:ApplyActionBarGrid(value)
    if disabled(value) then self.deferredSettings.alwaysShowActionBars=nil;return true end
    if not F('InCombatLockdown') then return report('ActionBars.grid',false,'Missing combat-state API') end
    if C.InCombat() then self.deferredSettings.alwaysShowActionBars=value;return false,'Deferred until combat ends' end
    self.deferredSettings.alwaysShowActionBars=nil
    local ok,reason=V:Apply('alwaysShowActionBars',value)
    if ok and F('GetActionBarToggles') and F('SetActionBarToggles') then
        ALWAYS_SHOW_MULTIBARS=value and 1 or nil
    end
    if ok and F('MultiActionBar_UpdateGridVisibility') then ok,reason=C.Write('MultiActionBar_UpdateGridVisibility') end
    return report('ActionBars.grid',ok,reason)
end
function A:FlushDeferredSettings()
    if C.InCombat() then return end
    local queued=self.deferredSettings;self.deferredSettings={}
    if not mQoL_Modules:ShouldLoadModule('ActionBarsQoL') then return end
    local current=mQoL_ActionBars and mQoL_ActionBars.db and mQoL_ActionBars.db.settings or {}
    for key,value in pairs(queued) do
        -- Do not replay a setting the user has since disabled or changed.
        if current[key]==value then
            if key=='alwaysShowActionBars' then self:ApplyActionBarGrid(value) else self:ApplyActionBar(key,value) end
        end
    end
end
function A:SyncNameplateAll(np)
    local enemy,friendly=np.showEnemyNameplates,np.showFriendlyNameplates
    if disabled(enemy) and disabled(friendly) then return true end
    if disabled(enemy) then enemy=V:ReadBoolean('nameplateShowEnemies') end
    if disabled(friendly) then friendly=V:ReadBoolean('nameplateShowFriends') end
    -- An unknown counterpart is not proof that all nameplates should be hidden.
    if enemy==true or friendly==true then return V:Apply('nameplateShowAll',true) end
    if enemy==false and friendly==false then return V:Apply('nameplateShowAll',false) end
    return true,'Preserved: incomplete nameplate state'
end
function A:ApplyGraphics(settings)
    if not mQoL_Modules:ShouldLoadModule('Graphics') then return false,'Module disabled' end
    local all=true
    for key,cvar in pairs({ViewDistance='farclip',FogDistance='horizonStart'}) do
        if not disabled(settings[key]) then
            local ok,reason=V:Apply(cvar,settings[key])
            report('Graphics.'..key,ok,reason);all=all and ok
        end
    end
    return all
end
function A:ApplyAppearance(key,value)
    if disabled(value) then return true end
    if not mQoL_Modules:ShouldLoadModule('GeneralQoL') then return false,'Module disabled' end
    local allowed,reason,result=self:CanUse('GeneralQoL',key,true)
    if not allowed then return report('General.'..key,false,reason) end
    local definition=self.byKey.GeneralQoL.byFeature[key]
    if result.adapter=='appearance' then
        local ok,err=C.Write(definition.setter,value==true)
        if ok then
            local read,actual=C.Read(definition.getter)
            ok=read and self.Boolean(actual)==(value==true)
            if not ok then err='Appearance readback did not confirm application' end
        end
        return report('General.'..key,ok,err)
    end
    return V:Apply(definition.cvar,value)
end
-- Optional launcher failure must not interrupt registration of Display/Profiles.
if mQoL_Hub and mQoL_Hub.InitializeMinimap then
    local initialize=mQoL_Hub.InitializeMinimap
    function mQoL_Hub:InitializeMinimap()
        local ok,reason=pcall(initialize,self)
        if not ok then
            A.minimapUnavailable='Minimap launcher failed: '..tostring(reason)
            C.Report('Minimap launcher',reason)
        end
    end
end
-- Existing callers historically ignored CVar setter return values. Keep their
-- UI/controllers, but expose rejected operations instead of reporting success.
local applyCVar=V.Apply
function V:Apply(name,value)
    local ok,reason=applyCVar(self,name,value)
    if not ok then C.Report('CVar.'..name,reason) else A.errors['CVar.'..name]=nil end
    return ok,reason
end
if mQoL_Mailbox and mQoL_Mailbox.AttachItemsByCategory then
    local attach=mQoL_Mailbox.AttachItemsByCategory
    function mQoL_Mailbox:AttachItemsByCategory(category)
        local allowed,reason=A:CanUse('Mailbox','attachments',true)
        if not allowed then return report('Mailbox.attachments',false,reason) end
        if not MailFrame:IsShown() or not SendMailFrame:IsShown() then return report('Mailbox.attachments',false,'Open Send Mail before attaching items.') end
        if C.InCombat() then return report('Mailbox.attachments',false,'Leave combat and click the category again; mail actions are never queued.') end
        local ok,result=pcall(attach,self,category)
        if not ok then self.sendQueue=nil;self.currentAttachment=nil end
        return report('Mailbox.attachments',ok,result)
    end
end
