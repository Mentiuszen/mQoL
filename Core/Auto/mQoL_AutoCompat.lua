-- Additive compatibility bootstrap: deliberately defines NOTHING on the established clients.
if not (mQoL_VersionDetection and mQoL_VersionDetection:UsesCapabilityChecks()) then return end
mQoL_Auto = {revision="AM-R3", errors={}, catalog={}, byKey={}, eventHandlers={}, timers={}, scanCount=0}
local A=mQoL_Auto
mQoL_Compat={}
local C=mQoL_Compat
local unpackValues=unpack or table.unpack
function C.Function(path)
    local obj=_G
    for part in tostring(path):gmatch("[^.]+") do
        if type(obj)~="table" and type(obj)~="userdata" then return nil end
        obj=obj[part]
    end
    if type(obj)=="function" then return obj end
end
function C.HasMethods(obj, ...)
    if type(obj)~="table" and type(obj)~="userdata" then return false end
    for i=1,select("#",...) do if type(obj[select(i,...)])~="function" then return false end end
    return true
end
function C.Number(value) return type(value)=="number" and value==value and value>-math.huge and value<math.huge end
function C.Copy(value, seen)
    if type(value)~="table" then return value end
    seen=seen or {}; if seen[value] then return seen[value] end
    local out={}; seen[value]=out
    for k,v in pairs(value) do out[C.Copy(k,seen)]=C.Copy(v,seen) end
    return out
end
function C.Report(key, err)
    local text=tostring(err)
    if A.errors[key]==text then return end
    A.errors[key]=text
    if type(print)=="function" then print("|cffffaa44[mQoL AM-R3]|r "..key..": "..text) end
end
function C.Read(path, ...)
    local fn=type(path)=="function" and path or C.Function(path)
    if not fn then return false, "Missing function: "..tostring(path) end
    return pcall(fn,...)
end
function C.Write(path, ...)
    local ok,result=C.Read(path,...)
    if not ok then return false,result end
    if result==false then return false,"The client rejected the operation" end
    return true,result
end
function C.InCombat()
    if type(InCombatLockdown)~="function" then return false end
    local ok,combat=pcall(InCombatLockdown)
    return not ok or (combat~=nil and combat~=false and combat~=0)
end
function C.SetSolidColor(texture,r,g,b,a)
    if C.HasMethods(texture,"SetColorTexture") then texture:SetColorTexture(r,g,b,a)
    elseif C.HasMethods(texture,"SetTexture","SetVertexColor") then texture:SetTexture("Interface\\Buttons\\WHITE8X8"); texture:SetVertexColor(r,g,b,a) end
end
function C.AddOnState(name)
    local loadedFn=C.Function("C_AddOns.IsAddOnLoaded") or C.Function("IsAddOnLoaded")
    if loadedFn then
        local ok,first,fully=pcall(loadedFn,name)
        if not ok then return "error",tostring(first) end
        if fully==true or (fully==nil and first==true) then return "loaded" end
        if first==true and fully==false then return "loading" end
    end
    local info=C.Function("C_AddOns.GetAddOnInfo") or C.Function("GetAddOnInfo")
    if info then
        local ok,addon=pcall(info,name)
        if not ok then return "error",tostring(addon) end
        if type(addon)=="string" and addon~="" then return "available" end
    end
    return "missing","Provider not present: "..name
end
local nativeAfter=C.Function("C_Timer.After")
local queue, timerFrame={},nil
local function Cancel(task) task.cancelled=true end
local function Run(task)
    if task.cancelled then return end
    task.cancelled=true
    local ok,err=pcall(task.callback)
    if not ok then C.Report(task.key or "timer",err) end
end
function C.After(delay,callback,key)
    if type(callback)~="function" then return nil,"callback must be a function" end
    delay=math.max(tonumber(delay) or 0,0)
    local task={remaining=delay,callback=callback,key=key,Cancel=Cancel}
    if nativeAfter then
        local ok,err=pcall(nativeAfter,delay,function() Run(task) end)
        if ok then return task end
        C.Report("native timer",err)
    end
    if not timerFrame then
        if type(CreateFrame)~="function" then return nil,"No timer or frame API" end
        local ok,frame=pcall(CreateFrame,"Frame")
        if not ok or not C.HasMethods(frame,"SetScript","Show","Hide") then return nil,"No timer frame implementation" end
        timerFrame=frame
    end
    queue[#queue+1]=task
    timerFrame:SetScript("OnUpdate",function(_,elapsed)
        -- Detach the batch: callbacks scheduling After(0) run on a LATER frame.
        local batch=queue; queue={}
        for _,pending in ipairs(batch) do
            if not pending.cancelled then
                pending.remaining=pending.remaining-(tonumber(elapsed) or 0)
                if pending.remaining<=0 then Run(pending) else queue[#queue+1]=pending end
            end
        end
        if #queue==0 then timerFrame:SetScript("OnUpdate",nil); timerFrame:Hide() end
    end)
    timerFrame:Show()
    return task
end
function C.NewTicker(delay,callback,iterations)
    delay=math.max(tonumber(delay) or 0.02,0.01)
    local ticker={Cancel=function(self) self.cancelled=true; if self.task then self.task:Cancel() end end}
    local count=0
    local function step()
        if ticker.cancelled then return end
        count=count+1
        local ok,err=pcall(callback,ticker)
        if not ok then C.Report("ticker",err); ticker:Cancel(); return end
        if not ticker.cancelled and (not iterations or count<iterations) then ticker.task=C.After(delay,step,"ticker") end
    end
    ticker.task=C.After(delay,step,"ticker")
    return ticker
end
A.compat=C

-- Original panels also use timers. Supply only missing methods; never replace
-- a native method, manufacture UI frames, or modify an established client.
C_Timer=C_Timer or {}
if type(C_Timer.After)~="function" then C_Timer.After=function(delay,fn) C.After(delay,fn,"shared UI timer") end end
if type(C_Timer.NewTimer)~="function" then C_Timer.NewTimer=function(delay,fn) return C.After(delay,fn,"shared UI timer") end end
if type(C_Timer.NewTicker)~="function" then C_Timer.NewTicker=C.NewTicker end
