-- The catalog owns Auto/Forever state. Shared helpers and libraries have no
-- dependency on this state and have already loaded on every client.
if not (mQoL_VersionDetection and mQoL_VersionDetection:UsesCapabilityChecks()) then return end
mQoL_Auto = {errors=mQoL_Compat.errors,catalog={},byKey={},scanCount=0}
local A=mQoL_Auto
local function Module(key,label)
    local m={key=key,label=label,description=label,versions={"isAuto","isForever"},setupVersion=1,order=(#A.catalog+1)*10,features={},byFeature={}}
    A.catalog[#A.catalog+1]=m; A.byKey[key]=m; return m
end
local function Feature(m,key,label,kind,extra)
    local f={key=key,label=label,kind=kind,events={PLAYER_LOGIN=true}}
    for k,v in pairs(extra or {}) do f[k]=v end
    m.features[#m.features+1]=f; m.byFeature[key]=f; return f
end
local function CVar(m,key,label,cvar,valueType,extra)
    extra=extra or {}; extra.cvar=cvar; extra.valueType=valueType or "boolean"
    extra.savedKey=extra.savedKey or key
    return Feature(m,key,label,"cvar",extra)
end
local m=Module("AccountOverview","Account Overview")
Feature(m,"saved","Saved characters","saved")
Feature(m,"identity","Current character","identity",{events={PLAYER_LOGIN=true,PLAYER_ENTERING_WORLD=true}})
Feature(m,"gold","Character gold","functions",{requires={"GetMoney"},events={PLAYER_LOGIN=true}})
Feature(m,"played","Played time","functions",{requires={"RequestTimePlayed"}})
Feature(m,"specialization","Specialization","specialization",{events={PLAYER_LOGIN=true,PLAYER_SPECIALIZATION_CHANGED=true}})
Feature(m,"professions","Professions","professions",{events={PLAYER_LOGIN=true,TRADE_SKILL_SHOW=true,SKILL_LINES_CHANGED=true}})
Feature(m,"weekly","Weekly rewards data","weekly",{events={PLAYER_LOGIN=true,WEEKLY_REWARDS_UPDATE=true}})
Feature(m,"bank","Account bank gold","bank",{events={PLAYER_LOGIN=true,BANKFRAME_OPENED=true}})
Feature(m,"advancedViewer","Version-specific weekly reward viewer","functions",{requires={"C_WeeklyRewards.GetActivities","C_WeeklyRewards.GetExampleRewardItemHyperlinks"}})
m=Module("GeneralQoL","General QoL")
CVar(m,"autoLoot","Auto loot","autoLootDefault")
CVar(m,"autoQuestTracking","Auto quest tracking","autoQuestWatch")
CVar(m,"showMyName","Show own name","UnitNameOwn")
CVar(m,"showLuaErrors","Lua errors","scriptErrors")
CVar(m,"autoConsolidatedBuffs","Consolidate buffs","consolidateBuffs")
Feature(m,"showHead","Show helm","appearance",{getter="ShowingHelm",setter="ShowHelm",cvar="showHelm",valueType="boolean"})
Feature(m,"showCloak","Show cloak","appearance",{getter="ShowingCloak",setter="ShowCloak",cvar="showCloak",valueType="boolean"})
Feature(m,"fastAutoLoot","Fast auto loot","fastloot",{valueType="boolean"})
m=Module("NameplatesQoL","Nameplates")
for _,v in ipairs({
 {"enemyNameplates","Enemy nameplates","nameplateShowEnemies"},
 {"friendlyNameplates","Friendly nameplates","nameplateShowFriends"},
 {"allNameplates","Always show nameplates","nameplateShowAll"},
 {"enemyPets","Enemy pets","nameplateShowEnemyPets"},
 {"enemyGuardians","Enemy guardians","nameplateShowEnemyGuardians"},
 {"enemyTotems","Enemy totems","nameplateShowEnemyTotems"},
 {"enemyMinions","Enemy minions","nameplateShowEnemyMinions"},
 {"friendlyPets","Friendly pets","nameplateShowFriendlyPets"},
 {"friendlyGuardians","Friendly guardians","nameplateShowFriendlyGuardians"},
 {"friendlyTotems","Friendly totems","nameplateShowFriendlyTotems"},
 {"friendlyMinions","Friendly minions","nameplateShowFriendlyMinions"},
}) do CVar(m,v[1],v[2],v[3]) end
CVar(m,"maxDistance","Maximum distance","nameplateMaxDistance","number")
m=Module("ActionBarsQoL","Action Bars")
CVar(m,"alwaysShowActionBars","Always show action bars","alwaysShowActionBars")
CVar(m,"autoPushSpellToActionBar","Push new spells to action bar","AutoPushSpellToActionBar")
CVar(m,"autoSelfCast","Auto self cast","autoSelfCast")
for bar=2,8 do Feature(m,"showActionBars"..bar,"Action bar "..bar,"actionbar",{bar=bar,valueType="boolean",protected=true,events={PLAYER_LOGIN=true,ADDON_LOADED=true}}) end
m=Module("Mailbox","Mailbox Improvements")
Feature(m,"recipients","Saved recipients and alts","saved")
Feature(m,"gold","Character gold","functions",{requires={"GetMoney"}})
Feature(m,"friends","Friends","friends")
Feature(m,"guild","Guild members","functions",{requires={"GetNumGuildMembers","GetGuildRosterInfo"}})
Feature(m,"fields","Recipient and subject fields","mailfields",{provider="Blizzard_MailUI",events={PLAYER_LOGIN=true,MAIL_SHOW=true,ADDON_LOADED=true}})
Feature(m,"attachments","Choose and attach bag items","containers",{provider="Blizzard_MailUI",protected=true,events={PLAYER_LOGIN=true,MAIL_SHOW=true,ADDON_LOADED=true}})
Feature(m,"quickSend","Quick Send categories (attachments)","containers",{provider="Blizzard_MailUI",protected=true,events={PLAYER_LOGIN=true,MAIL_SHOW=true,ADDON_LOADED=true}})
m=Module("Graphics","Graphics Settings")
CVar(m,"ViewDistance","View distance (farclip)","farclip","number")
CVar(m,"FogDistance","Fog distance (horizonStart)","horizonStart","number")
CVar(m,"graphicsViewDistance","Graphics view distance","graphicsViewDistance","number")
m=Module("BlizzardFixes","Blizzard Fixes")
m.hardlocked=true
Feature(m,"fixes","Version-specific fixes","unsupported",{reason="MoP/BCC fixes are never inherited by Auto or Forever"})
m=Module("EditMode","Edit Mode")
Feature(m,"saved","Saved layout backups","saved")
Feature(m,"layouts","Available layouts","layouts",{provider="Blizzard_EditMode",events={PLAYER_LOGIN=true,ADDON_LOADED=true,EDIT_MODE_LAYOUTS_UPDATED=true}})
Feature(m,"apply","Apply a layout","layoutApply",{protected=true,provider="Blizzard_EditMode",events={PLAYER_LOGIN=true,ADDON_LOADED=true,EDIT_MODE_LAYOUTS_UPDATED=true}})
Feature(m,"export","Export and back up layouts","layoutExport",{provider="Blizzard_EditMode",events={PLAYER_LOGIN=true,ADDON_LOADED=true,EDIT_MODE_LAYOUTS_UPDATED=true}})
Feature(m,"autoSwitch","Automatic layout by specialization","layoutAuto",{protected=true,provider="Blizzard_EditMode",events={PLAYER_LOGIN=true,ADDON_LOADED=true,PLAYER_SPECIALIZATION_CHANGED=true,EDIT_MODE_LAYOUTS_UPDATED=true}})
m=Module("RaidProfiles","Raid Profiles")
Feature(m,"saved","Saved raid profiles","saved")
Feature(m,"capture","Capture compatible raid options","raidRead")
Feature(m,"apply","Apply a matching profile","raidWrite",{protected=true})
Feature(m,"positions","Legacy saved positions","raidPositions",{protected=true})
Feature(m,"autoSwitch","Forced compatible profile","raidWrite",{protected=true})
m=Module("DungeonTeleportsTab","Dungeon Teleports")
Feature(m,"spells","Known teleport spells","teleports",{events={PLAYER_LOGIN=true,SPELLS_CHANGED=true}})
Feature(m,"cast","Teleport buttons","teleportCast",{protected=true,events={PLAYER_LOGIN=true,SPELLS_CHANGED=true,ADDON_LOADED=true}})
Feature(m,"cooldowns","Spell cooldowns","cooldowns",{events={PLAYER_LOGIN=true,SPELLS_CHANGED=true}})
Feature(m,"pveTab","Group Finder tab","pve",{provider="Blizzard_GroupFinder",events={PLAYER_LOGIN=true,ADDON_LOADED=true}})
Feature(m,"popup","Group Finder popup","pve",{provider="Blizzard_GroupFinder",events={PLAYER_LOGIN=true,ADDON_LOADED=true}})
m=Module("MythicPlusListing","Mythic+ Listing Helper")
Feature(m,"ownKey","Own keystone","keystone",{events={PLAYER_LOGIN=true,CHALLENGE_MODE_MAPS_UPDATE=true}})
Feature(m,"group","Party members","functions",{requires={"GetNumGroupMembers","UnitName","UnitClass","GetRealmName","IsInGroup","IsInRaid","UnitExists"}})
Feature(m,"rating","Player rating","functions",{requires={"C_PlayerInfo.GetPlayerMythicPlusRatingSummary"}})
Feature(m,"communication","Party keystone exchange","communication")
Feature(m,"listingRead","Current listing","listingRead",{events={PLAYER_LOGIN=true,ADDON_LOADED=true}})
Feature(m,"integration","Existing LFG entry controller","mythicUI",{provider="Blizzard_GroupFinder",events={PLAYER_LOGIN=true,ADDON_LOADED=true}})
Feature(m,"listingWrite","Fill existing LFG entry form","mythicUI",{provider="Blizzard_GroupFinder",protected=true,events={PLAYER_LOGIN=true,ADDON_LOADED=true}})
-- These probes describe APIs; they do not replace the shared controllers/UI.
-- This is a SPELL CATALOG, not proof of client content or an assumed season.
-- Only records for known spells with a valid localized spell name are displayed.
A.teleportIDs = {131204, 131205, 131206, 131222, 131225, 131228, 131229, 131231, 131232, 159895, 159896, 159897, 159898, 159899, 159900, 159901, 159902, 354462, 354463, 354464, 354465, 354466, 354467, 354468, 354469, 367416, 373190, 373191, 373192, 373262, 373274, 393222, 393256, 393262, 393267, 393273, 393276, 393279, 393283, 393764, 393766, 410071, 410074, 410078, 410080, 424142, 424153, 424163, 424167, 424187, 424197, 432254, 432257, 432258, 445269, 445414, 445416, 445417, 445418, 445424, 445440, 445441, 445443, 445444, 464256, 467553, 467555, 1216786, 1226482, 1237215, 1239155, 1254400, 1254551, 1254555, 1254559, 1254563, 1254572, 1286801, 1286804, 1286807, 1286809, 1286812, 1286828, 1286831}
