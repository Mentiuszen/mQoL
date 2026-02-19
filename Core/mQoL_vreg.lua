local addonName, ns = ...

_G.vreg = _G.vreg or {}
local vreg = _G.vreg

local function vf9(t)
    local s = ""
    for i = 1, #t do
      s = s .. string.char(t[i])
    end
    return s
end

local n1 = {
    {77,101,110,116,105,117,115,122,101,110},
    {65,114,105,107,97},
    {84,121,115,104,105,97},
}

local s1 = {
    {75,117,108,84,105,114,97,115},
    {78,111,114,117,115,104,101,110},
    {83,104,101,107,39,122,101,101,114},
    {91,69,78,93,69,118,101,114,109,111,111,110},
}

function vreg.vf1()
    local n, r = UnitName("player"), GetRealmName()
    r = (r or ""):gsub("%s+", "")
    return n .. "-" .. r
end

function vreg.NormalizeName(n)
    if not n:find("-") then
        local r = GetRealmName():gsub("%s+", "")
        return n .. "-" .. r
    end
    return n
end

function vreg.GetCurrentRegion()
    if GetCurrentRegion then
        local id = GetCurrentRegion()
        local regions = { "US","KR","EU","TW","CN" }
        return regions[id] or "UNKNOWN"
    end
    return "UNKNOWN"
end

function vreg.vf4(n)
    local nn, rr = strsplit("-", n or UnitName("player"))
    if not rr then rr = GetRealmName():gsub("%s+", "") end
    return nn .. "-" .. rr
end

local function vf2()
    local L = {}
    local rn = { n1[1], n1[2], n1[3] }
    local rr = s1[1]
    for _, t in ipairs(rn) do
        L[vf9(t) .. "-" .. vf9(rr)] = true
    end
    L[vf9(n1[1]) .. "-" .. vf9(s1[2])] = true
    L[vf9(n1[2]) .. "-" .. vf9(s1[2])] = true
    L[vf9(n1[1]) .. "-" .. vf9(s1[3])] = true
    L[vf9(n1[1]) .. "-" .. vf9(s1[4])] = true
    L[vf9(n1[3]) .. "-" .. vf9(s1[4])] = true
    return L
end

vreg.lists = vf2()

function vreg.hasmark(name)
    return vreg.lists[name] or false
end

function vreg.decorate(name, display)
    display = display or name
    if vreg.hasmark(name) then
        return "|TInterface\\AddOns\\mQoL\\Media\\Textures\\mark:20|t " .. display
    end
    return display
end