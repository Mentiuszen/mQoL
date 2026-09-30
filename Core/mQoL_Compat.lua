-- Shared helpers, not a capability scanner. No Blizzard global is replaced.
mQoL_Compat=mQoL_Compat or {}
local C=mQoL_Compat
C.errors=C.errors or {}
function C.Function(path)
    local object=_G
    for part in tostring(path):gmatch('[^.]+') do
        if type(object)~='table' and type(object)~='userdata' then return nil end
        object=object[part]
    end
    if type(object)=='function' then return object end
end
function C.HasMethods(object,...)
    if type(object)~='table' and type(object)~='userdata' then return false end
    for i=1,select('#',...) do if type(object[select(i,...)])~='function' then return false end end
    return true
end
function C.Number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
function C.Copy(value,seen)
    if type(value)~='table' then return value end
    seen=seen or {};if seen[value] then return seen[value] end
    local out={};seen[value]=out
    for key,v in pairs(value) do out[C.Copy(key,seen)]=C.Copy(v,seen) end
    return out
end
function C.Report(key,err)
    local text=tostring(err)
    if C.errors[key]==text then return end
    C.errors[key]=text
    if type(print)=='function' then print('|cffffaa44[mQoL]|r '..key..': '..text) end
end
function C.Read(path,...)
    local fn=type(path)=='function' and path or C.Function(path)
    if not fn then return false,'Missing function: '..tostring(path) end
    return pcall(fn,...)
end
function C.Write(path,...)
    local ok,result=C.Read(path,...)
    if not ok then return false,result end
    if result==false then return false,'The client rejected the operation' end
    return true,result
end
function C.InCombat()
    if type(InCombatLockdown)~='function' then return false end
    local ok,v=pcall(InCombatLockdown)
    return not ok or (v~=nil and v~=false and v~=0)
end
function C.SetSolidColor(texture,r,g,b,a)
    if C.HasMethods(texture,'SetColorTexture') then texture:SetColorTexture(r,g,b,a)
    elseif C.HasMethods(texture,'SetTexture','SetVertexColor') then
        texture:SetTexture('Interface\\Buttons\\WHITE8X8');texture:SetVertexColor(r,g,b,a or 1)
    end
end
function C.RegisterEvent(frame,event)
    if not C.HasMethods(frame,'RegisterEvent') then return false end
    return pcall(frame.RegisterEvent,frame,event)
end
function C.CleanupFrame(frame,seen)
    if not frame then return end
    seen=seen or {};if seen[frame] then return end;seen[frame]=true
    if C.HasMethods(frame,'GetChildren') then
        local children={frame:GetChildren()}
        for _,child in ipairs(children) do C.CleanupFrame(child,seen) end
    end
    if C.HasMethods(frame,'SetScript') then
        for _,script in ipairs({'OnUpdate','OnShow','OnHide','OnEvent'}) do pcall(frame.SetScript,frame,script,nil) end
    end
    if C.HasMethods(frame,'UnregisterAllEvents') then frame:UnregisterAllEvents() end
    if C.HasMethods(frame,'Hide') then frame:Hide() end
    if C.HasMethods(frame,'SetParent') then frame:SetParent(nil) end
    local name=C.HasMethods(frame,'GetName') and frame:GetName()
    if type(name)=='string' and name:match('^mQoL_') and _G[name]==frame then _G[name]=nil end
end
function C.SpecAdapter()
    if C.Function('C_SpecializationInfo.GetSpecialization') and C.Function('C_SpecializationInfo.GetSpecializationInfo') then
        return C_SpecializationInfo.GetSpecialization,C_SpecializationInfo.GetSpecializationInfo
    end
    if type(GetSpecialization)=='function' and type(GetSpecializationInfo)=='function' then return GetSpecialization,GetSpecializationInfo end
end
function C.IsInRaid()
    if type(IsInRaid)=='function' then return IsInRaid() end
    return type(GetNumRaidMembers)=='function' and GetNumRaidMembers()>0 or false
end
function C.IsInGroup()
    if type(IsInGroup)=='function' then return IsInGroup() end
    return C.IsInRaid() or (type(GetNumPartyMembers)=='function' and GetNumPartyMembers()>0) or false
end
function C.AddOnState(name)
    local loaded=C.Function('C_AddOns.IsAddOnLoaded') or C.Function('IsAddOnLoaded')
    if loaded then
        local ok,first,fully=pcall(loaded,name)
        if not ok then return 'error',tostring(first) end
        if fully==true or (fully==nil and first==true) then return 'loaded' end
        if first==true and fully==false then return 'loading' end
    end
    local info=C.Function('C_AddOns.GetAddOnInfo') or C.Function('GetAddOnInfo')
    if info then
        local ok,addon=pcall(info,name)
        if not ok then return 'error',tostring(addon) end
        if type(addon)=='string' and addon~='' then return 'available' end
    end
    return 'missing','Provider not present: '..name
end
local queue,frame={},nil
local function run(task)
    if task.cancelled then return end
    task.cancelled=true
    local ok,err=pcall(task.callback,task)
    if not ok then C.Report(task.key or 'timer',err) end
end
function C.After(delay,callback,key)
    if type(callback)~='function' then return nil,'callback must be a function' end
    delay=tonumber(delay) or 0
    if not C.Number(delay) then return nil,'delay must be finite' end
    local task={remaining=math.max(delay,0),callback=callback,key=key,Cancel=function(self) self.cancelled=true end}
    local native=C.Function('C_Timer.After')
    if native then
        local ok,err=pcall(native,task.remaining,function() run(task) end)
        if ok then return task end
        C.Report('Native timer',err)
    end
    if not frame then
        local ok,f=C.Read('CreateFrame','Frame')
        if not ok or not C.HasMethods(f,'SetScript','Show','Hide') then return nil,'No timer frame implementation' end
        frame=f
    end
    queue[#queue+1]=task
    frame:SetScript('OnUpdate',function(_,elapsed)
        local batch=queue;queue={}
        for _,pending in ipairs(batch) do
            if not pending.cancelled then
                pending.remaining=pending.remaining-(tonumber(elapsed) or 0)
                if pending.remaining<=0 then run(pending) else queue[#queue+1]=pending end
            end
        end
        if #queue==0 then frame:SetScript('OnUpdate',nil);frame:Hide() end
    end)
    frame:Show()
    return task
end
function C.NewTicker(delay,callback,iterations)
    local native=C.Function('C_Timer.NewTicker')
    if native then return native(delay,callback,iterations) end
    if type(callback)~='function' then return nil,'callback must be a function' end
    delay=math.max(tonumber(delay) or 0.02,0.01)
    local ticker={Cancel=function(self) self.cancelled=true;if self.task then self.task:Cancel() end end}
    local count=0
    local function step()
        if ticker.cancelled then return end
        count=count+1
        local ok,err=pcall(callback,ticker)
        if not ok then C.Report('ticker',err);ticker:Cancel();return end
        if not ticker.cancelled and (not iterations or count<iterations) then ticker.task=C.After(delay,step,'ticker') end
    end
    ticker.task=C.After(delay,step,'ticker')
    return ticker
end
C.Timer={After=C.After,NewTimer=function(delay,callback)
    local native=C.Function('C_Timer.NewTimer')
    if native then return native(delay,callback) end
    return C.After(delay,callback)
end,NewTicker=C.NewTicker}
