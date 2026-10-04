local addonName = ...
mQoL_VersionDetection = mQoL_VersionDetection or {}
local D = mQoL_VersionDetection
local ACTIVE_TREE = {
    {key="Retail", name="Retail", flag="isRetail", minToc=120000, maxToc=999999, aliases={}},
    {key="MoP", name="Mists of Pandaria Classic", flag="isMoP", minToc=50500, maxToc=50505, aliases={}},
    {key="Vanilla", name="Classic Era (Vanilla)", flag="isVanilla", minToc=11300, maxToc=11599, aliases={"isEra"}},
    {key="TBC", name="Burning Crusade Classic", flag="isTBC", minToc=20500, maxToc=20506, aliases={"isBCC"}},
    {key="Forever", name="Forever", flag="isForever", minToc=16000, maxToc=16001, aliases={}},
}
local LEGACY_TREE = {
    {key="Legion", name="Legion", flag="isLegion", minToc=70000, maxToc=70300, aliases={}},
}
local FLAGS = {"isRetail","isMoP","isLegion","isEra","isVanilla","isBCC","isTBC","isForever","isAuto"}
local function ValidTOC(n)
    return type(n)=="number" and n==n and n>0 and n<math.huge and n%1==0
end
local function Register(tree, def)
    if D.locked then return false, "Client identity is locked for this session; register before module startup" end
    if type(def)~="table" or type(def.key)~="string" or def.key=="" or type(def.flag)~="string" or not def.flag:match("^is%a[%w_]*$") then
        return false, "Definition requires a non-empty key and an is-prefixed flag"
    end
    if def.key=="Auto" or def.flag=="isAuto" then return false, "Auto is reserved" end
    local lo, hi = def.toc or def.minToc, def.toc or def.maxToc or def.minToc
    if not ValidTOC(lo) or not ValidTOC(hi) or lo>hi or def.match~=nil
        or (def.toc and (def.minToc or def.maxToc)) then return false, "Use one exact TOC or a finite, ordered TOC range" end
    if def.aliases~=nil and type(def.aliases)~="table" then return false, "aliases must be a table" end
    local reserved = {}
    for _, list in ipairs({ACTIVE_TREE,LEGACY_TREE}) do
        for _, existing in ipairs(list) do
            if existing.key==def.key or (lo<=existing.maxToc and hi>=existing.minToc) then return false, "Duplicate or overlapping client definition" end
            reserved[existing.flag]=true
            for _, alias in ipairs(existing.aliases) do reserved[alias]=true end
        end
    end
    if reserved[def.flag] then return false, "Client flag is already assigned" end
    local aliases, seen = {}, {[def.flag]=true}
    for _, alias in ipairs(def.aliases or {}) do
        if type(alias)~="string" or not alias:match("^is%a[%w_]*$") or alias=="isAuto" or reserved[alias] or seen[alias] then return false, "Conflicting alias" end
        aliases[#aliases+1]=alias; seen[alias]=true
    end
    table.insert(tree,1,{key=def.key,name=def.name or def.key,flag=def.flag,minToc=lo,maxToc=hi,aliases=aliases})
    return true
end
function D:RegisterActiveVersion(def) return Register(ACTIVE_TREE,def) end
function D:RegisterLegacyVersion(def) return Register(LEGACY_TREE,def) end
function D:TranslateVersionKey(key) return key end
function D:Lock() self.locked=true end
function D:Detect()
    if self.locked then return self.clientInfo, "Client identity is locked for this session" end
    local version, build, date, raw, reason
    if type(GetBuildInfo)=="function" then
        local ok, a,b,c,d=pcall(GetBuildInfo)
        if ok then version,build,date,raw=a,b,c,d else reason="GetBuildInfo failed: "..tostring(a) end
    else reason="GetBuildInfo is unavailable" end
    local toc=tonumber(raw)
    if not ValidTOC(toc) then toc=0; reason=reason or "Invalid TOC (expected a positive finite integer)" end
    local ci={version=version or "Unknown",build=build or "0",date=date or "",rawTOC=raw,tocversion=toc,tree="Auto",versionKey="Auto",detectionReason=reason}
    for _, flag in ipairs(FLAGS) do ci[flag]=false end
    self.ActiveClientInfo,self.LegacyClientInfo,self.AutoClientInfo=nil,nil,nil
    local found=false
    if toc>0 then
        for _, branch in ipairs({{name="Active",defs=ACTIVE_TREE},{name="Legacy",defs=LEGACY_TREE}}) do
            for _, def in ipairs(branch.defs) do
                if toc>=def.minToc and toc<=def.maxToc then
                    ci.tree,ci.versionKey,ci.name=branch.name,def.key,def.name
                    ci[def.flag]=true
                    for _, alias in ipairs(def.aliases) do ci[alias]=true end
                    found=true; break
                end
            end
            if found then break end
        end
    end
    if not found then ci.isAuto=true; ci.detectionReason=reason or "TOC is outside the explicit Active and Legacy ranges" end
    self[ci.tree.."ClientInfo"]=ci; self.clientInfo=ci
    return ci
end
function D:IsActive() return self.clientInfo and self.clientInfo.tree=="Active" end
function D:IsLegacy() return self.clientInfo and self.clientInfo.tree=="Legacy" end
function D:IsAuto() return self.clientInfo and self.clientInfo.tree=="Auto" end
function D:GetTree() return self.clientInfo and self.clientInfo.tree or "Unknown" end
function D:GetClientInfo() return self.clientInfo end
function D:UsesCapabilityChecks()
    local ci=self.clientInfo
    return ci and (ci.isAuto==true or ci.isForever==true) or false
end
D:Detect()
