local addonName = ...

-- This entire module will be rewritten to use the new version detection system in next update
-- For now its only moved out of hub

mQoL_VersionDetection = mQoL_VersionDetection or {}

local version, build, date, tocversion = GetBuildInfo()
tocversion = tonumber(tocversion) or 0

local clientInfo = {
    version = version,
    tocversion = tocversion,
    isRetail = false,
    isClassic = false,
    isLegion = false,
    isPandaria = false,
    isEra = false,
    isBCC = false,
    isClassicToT = false,
}

if tocversion >= 120000 then
    clientInfo.isRetail = true
elseif tocversion >= 50500 and tocversion <= 50505 then
    clientInfo.isClassic = true
    clientInfo.isClassicToT = tocversion <= 50503
elseif tocversion >= 70000 and tocversion <= 70300 then
    clientInfo.isLegion = true
elseif tocversion >= 11300 and tocversion <= 11599 then
    clientInfo.isEra = true
elseif tocversion >= 20500 and tocversion <= 20505 then
	clientInfo.isBCC = true
elseif tocversion >= 50001 and tocversion <= 50400 then
    clientInfo.isPandaria = true
    print("|cff00ff00[mQoL] |cffff4444WARNING|r|cff00ff00 - Mists of Pandaria 5.4 is not yet supported.|r")
else
    print("|cff00ff00[mQoL] |cffff4444WARNING|r|cff00ff00 - unsupported client version: " .. (tocversion or "UNKNOWN") .. "|r")
end

mQoL_VersionDetection.clientInfo = clientInfo