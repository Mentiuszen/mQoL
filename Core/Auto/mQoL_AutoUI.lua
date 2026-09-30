-- Availability annotations and operation guards for the shared Hub's controls.
if not mQoL_Auto then return end
local A,C,H=mQoL_Auto,mQoL_Compat,mQoL_Hub
A.optionRows={}
local rows={
    ['Enable LUA Errors']={'GeneralQoL','showLuaErrors'},
    ['Enable Autoloot']={'GeneralQoL','autoLoot'},
    ['Fast Auto Loot']={'GeneralQoL','fastAutoLoot'},
    ['Fast Auto Loot Speed']={'GeneralQoL','fastAutoLoot'},
    ['Enable Auto Quest Tracking']={'GeneralQoL','autoQuestTracking'},
    ['My Name']={'GeneralQoL','showMyName'},
    ['Enable Consolidated Buffs']={'GeneralQoL','autoConsolidatedBuffs'},
    ['Show Head']={'GeneralQoL','showHead'},
    ['Show Cloak']={'GeneralQoL','showCloak'},
    ['Enemy Nameplates']={'NameplatesQoL','enemyNameplates'},
    ['Friendly Nameplates']={'NameplatesQoL','friendlyNameplates'},
    ['Max Nameplate Distance']={'NameplatesQoL','maxDistance'},
    ['Always Show Action Bars']={'ActionBarsQoL','alwaysShowActionBars'},
    ['Auto Push Spell To Action Bar']={'ActionBarsQoL','autoPushSpellToActionBar'},
    ['Auto Self Cast']={'ActionBarsQoL','autoSelfCast'},
    ['View Distance']={'Graphics','ViewDistance'},
    ['Fog Distance']={'Graphics','FogDistance'},
    ['Edit Mode Profile Mode']={'EditMode','apply'},
    ['Force Edit Mode Profile']={'EditMode','apply'},
    ['Forced Raid Profile Mode']={'RaidProfiles','apply'},
    ['Force Raid Profile']={'RaidProfiles','apply'},
}
for bar=2,8 do rows['Action Bar '..bar]={'ActionBarsQoL','showActionBars'..bar} end
local moduleLabels={}
for _,module in ipairs(mQoL_Modules.AvailableModules) do moduleLabels[module.label]=module end
local localChecks={
    ['Hide Minimap Button']=function()
        local icon
        if LibStub and type(LibStub.GetLibrary)=='function' then icon=LibStub:GetLibrary('LibDBIcon-1.0',true) end
        local ready=C.HasMethods(icon,'Hide','Show') and type(icon.objects)=='table' and icon.objects.mQoL_Hub~=nil
        return ready,ready and nil or 'Minimap launcher not registered. The standard Hub remains available through /mqol.'
    end,
}
local function evaluate(entry,fresh)
    if entry.localCheck then return entry.localCheck() end
    if entry.module then
        local allowed=mQoL_Modules:IsModuleCompatible(entry.module)
        return allowed,allowed and nil or 'No currently available implementation. A selected module can still be disabled.'
    end
    local result=A:GetFeature(entry.feature[1],entry.feature[2],fresh)
    if not result then return true end
    return result.state=='ready' and result.canWrite~=false,result.reason or result.state
end
local function tooltip(entry)
    if not GameTooltip or not C.HasMethods(GameTooltip,'SetOwner','SetText','Show') then return end
    GameTooltip:SetOwner(entry.row,'ANCHOR_RIGHT')
    GameTooltip:SetText(entry.name)
    if C.HasMethods(GameTooltip,'AddLine') then
        if entry.allowed then GameTooltip:AddLine('Setting available.',1,1,1,true)
        else GameTooltip:AddLine(tostring(entry.reason),1,0.8,0.3,true) end
    end
    GameTooltip:Show()
end
local function restore(entry)
    if entry.control and type(entry.control.SetValue)=='function' and entry.value~=nil then
        entry.restoring=true
        local ok,reason=pcall(entry.control.SetValue,entry.control,entry.value)
        entry.restoring=false
        if not ok then C.Report('Restore option '..entry.name,reason) end
    end
end
function A:GuardOption(entry,fn,explicitValue,hasExplicitValue)
    if type(fn)~='function' then return fn end
    return function(...)
        if entry.restoring then return end
        local value=explicitValue
        if not hasExplicitValue then value=select(2,...);if value==nil then value=select(1,...) end end
        local allowed,reason=evaluate(entry,true)
        if entry.feature and not mQoL_Modules:ShouldLoadModule(entry.feature[1]) then allowed=false;reason='Module disabled' end
        -- Users must always be able to stop managing a setting or turn a
        -- selected module off even when an API has disappeared.
        if value=='disable' or (entry.module and value==false) then allowed=true end
        if not allowed then
            restore(entry)
            C.Report('Option '..entry.name,reason)
            return false,reason
        end
        local results={fn(...)}
        if value~=nil and (type(value)=='boolean' or type(value)=='number' or value=='disable') then entry.value=value end
        A.errors['Option '..entry.name]=nil
        return (unpack or table.unpack)(results)
    end
end
local originalRow=H.AddOptionRow
A.originalAddOptionRow=originalRow
function H:AddOptionRow(parent,name,controlType,params,extra,applyFunc)
    local feature=rows[name]
    local module=controlType=='checkbox' and moduleLabels[name] or nil
    local localCheck=localChecks[name]
    if not feature and not module and not localCheck then return originalRow(self,parent,name,controlType,params,extra,applyFunc) end
    local entry={name=name,feature=feature,module=module,localCheck=localCheck,value=params and params.value}
    -- Copy descriptors, not WoW frame objects. Never mutate a shared list.
    local options={}
    for key,value in pairs(params or {}) do options[key]=value end
    options.onValueChanged=A:GuardOption(entry,options.onValueChanged)
    options.onEnterPressed=A:GuardOption(entry,options.onEnterPressed)
    if options.list then
        local list={}
        for index,item in ipairs(options.list) do
            if type(item)=='table' then
                local copy={};for key,value in pairs(item) do copy[key]=value end
                copy.onSelect=A:GuardOption(entry,copy.onSelect,copy.value,true);list[index]=copy
            else list[index]=item end
        end
        options.list=list
    end
    local row,control=originalRow(self,parent,name,controlType,options,extra,A:GuardOption(entry,applyFunc))
    entry.row,entry.control=row,control
    row.mQoLAvailability=entry
    if control then control.mQoLAvailability=entry end
    for _,frame in ipairs(extra or {}) do frame.mQoLAvailability=entry end
    A.optionRows[#A.optionRows+1]=entry
    row:EnableMouse(true)
    row:HookScript('OnEnter',function() tooltip(entry) end)
    row:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    if control and type(control.HookScript)=='function' then
        control:HookScript('OnEnter',function() tooltip(entry) end)
        control:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    end
    A:RefreshOptionRows()
    return row,control
end
function A:RefreshOptionRows()
    for _,entry in ipairs(self.optionRows) do
        entry.allowed,entry.reason=evaluate(entry,false)
        -- Keep the original control and its Disable selection. Guard callbacks
        -- instead of destroying/rebuilding panels or changing saved values.
        if entry.control then entry.control:SetAlpha(entry.allowed and 1 or 0.45) end
    end
    for _,item in ipairs(H.searchIndex or {}) do
        local feature=rows[item.label]
        if feature then
            local r=self:GetFeature(feature[1],feature[2],false)
            -- Keep a search result for the existing panel, with availability
            -- attached for diagnostics; do not erase functioning sibling rows.
            item.autoState=r and r.state or 'unknown'
            item.autoReason=r and r.reason
            item.available=true
        end
    end
end
local numberInput=H.SetupNumberInputBox
function H:SetupNumberInputBox(box,...)
    local apply=numberInput(self,box,...)
    local entry=box.mQoLAvailability
    if entry then
        local onEnter=box:GetScript('OnEnterPressed')
        if onEnter then box:SetScript('OnEnterPressed',A:GuardOption(entry,onEnter)) end
        return A:GuardOption(entry,apply)
    end
    return apply
end
if mQoL_Graphics and mQoL_Graphics.SetupCheckpointSlider then
    local setup=mQoL_Graphics.SetupCheckpointSlider
    function mQoL_Graphics:SetupCheckpointSlider(slider,box,...)
        local apply=setup(self,slider,box,...)
        local entry=box and box.mQoLAvailability
        if entry then
            local onEnter=box:GetScript('OnEnterPressed')
            if onEnter then box:SetScript('OnEnterPressed',A:GuardOption(entry,onEnter)) end
            return A:GuardOption(entry,apply)
        end
        return apply
    end
end
A:RefreshOptionRows()
-- An optional animation must never leave the existing Home content hidden.
-- Recovery reveals the SAME content frame, not an alternative Hub.
if H.RunHomeIntro then
    local runIntro=H.RunHomeIntro
    function H:RunHomeIntro(parent,content)
        local function recover(reason,expected)
            local active=parent.mQoLActiveIntro
            if expected and active and active~=expected then return end
            if active then active:SetScript('OnUpdate',nil);active:Hide();parent.mQoLActiveIntro=nil end
            content:SetAlpha(1);content:Show()
            if reason then C.Report('Home intro',reason) end
        end
        local ok,reason=pcall(runIntro,self,parent,content)
        if not ok then recover(reason);return end
        local intro=parent.mQoLActiveIntro
        local update=intro and intro:GetScript('OnUpdate')
        if update then
            intro:SetScript('OnUpdate',function(...)
                local good,err=pcall(update,...)
                if not good then recover(err,intro) end
            end)
        end
        C.After(5,function()
            if parent.mQoLActiveIntro==intro and intro and (not content:IsShown() or content:GetAlpha()<1) then
                recover('Animation did not reveal Home content; animation stopped.',intro)
            end
        end,'Home intro recovery')
    end
end
