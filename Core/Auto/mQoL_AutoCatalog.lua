-- The catalog owns Auto/Forever state. Shared helpers and libraries have no
-- dependency on this state and have already loaded on every client.
if not (mQoL_VersionDetection and mQoL_VersionDetection:UsesCapabilityChecks()) then
    return
end

mQoL_Auto = {
    errors = mQoL_Compat.errors,
    catalog = {},
    byKey = {},
    scanCount = 0,
}

local A = mQoL_Auto

local function Module(key, label)
    local module = {
        key = key,
        label = label,
        description = label,
        versions = {"isAuto", "isForever"},
        setupVersion = 1,
        order = (#A.catalog + 1) * 10,
        features = {},
        byFeature = {},
    }

    A.catalog[#A.catalog + 1] = module
    A.byKey[key] = module
    return module
end

local function Feature(module, key, label, kind, extra)
    local feature = {
        key = key,
        label = label,
        kind = kind,
        events = {PLAYER_LOGIN = true},
    }

    for extraKey, value in pairs(extra or {}) do
        feature[extraKey] = value
    end

    module.features[#module.features + 1] = feature
    module.byFeature[key] = feature
    return feature
end

local function CVar(module, key, label, cvar, valueType, extra)
    extra = extra or {}
    extra.cvar = cvar
    extra.valueType = valueType or "boolean"
    extra.savedKey = extra.savedKey or key

    return Feature(module, key, label, "cvar", extra)
end

local module = Module("AccountOverview", "Account Overview")
Feature(module, "saved", "Saved characters", "saved")
Feature(module, "identity", "Current character", "identity", {
    events = {PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true},
})
Feature(module, "gold", "Character gold", "functions", {
    requires = {"GetMoney"},
    events = {PLAYER_LOGIN = true},
})
Feature(module, "played", "Played time", "functions", {
    requires = {"RequestTimePlayed"},
})
Feature(module, "specialization", "Specialization", "specialization", {
    events = {PLAYER_LOGIN = true, PLAYER_SPECIALIZATION_CHANGED = true},
})
Feature(module, "professions", "Professions", "professions", {
    events = {PLAYER_LOGIN = true, TRADE_SKILL_SHOW = true, SKILL_LINES_CHANGED = true},
})
Feature(module, "weekly", "Weekly rewards data", "weekly", {
    events = {PLAYER_LOGIN = true, WEEKLY_REWARDS_UPDATE = true},
})
Feature(module, "bank", "Account bank gold", "bank", {
    events = {PLAYER_LOGIN = true, BANKFRAME_OPENED = true},
})
Feature(module, "advancedViewer", "Version-specific weekly reward viewer", "functions", {
    requires = {
        "C_WeeklyRewards.GetActivities",
        "C_WeeklyRewards.GetExampleRewardItemHyperlinks",
    },
})

module = Module("GeneralQoL", "General QoL")
CVar(module, "autoLoot", "Auto loot", "autoLootDefault")
CVar(module, "autoQuestTracking", "Auto quest tracking", "autoQuestWatch")
CVar(module, "showMyName", "Show own name", "UnitNameOwn")
CVar(module, "showLuaErrors", "Lua errors", "scriptErrors")
CVar(module, "autoConsolidatedBuffs", "Consolidate buffs", "consolidateBuffs")
Feature(module, "showHead", "Show helm", "appearance", {
    getter = "ShowingHelm",
    setter = "ShowHelm",
    cvar = "showHelm",
    valueType = "boolean",
})
Feature(module, "showCloak", "Show cloak", "appearance", {
    getter = "ShowingCloak",
    setter = "ShowCloak",
    cvar = "showCloak",
    valueType = "boolean",
})
Feature(module, "fastAutoLoot", "Fast auto loot", "fastloot", {
    valueType = "boolean",
})

module = Module("NameplatesQoL", "Nameplates")
for _, value in ipairs({
    {"enemyNameplates", "Enemy nameplates", "nameplateShowEnemies"},
    {"friendlyNameplates", "Friendly nameplates", "nameplateShowFriends"},
    {"allNameplates", "Always show nameplates", "nameplateShowAll"},
    {"enemyPets", "Enemy pets", "nameplateShowEnemyPets"},
    {"enemyGuardians", "Enemy guardians", "nameplateShowEnemyGuardians"},
    {"enemyTotems", "Enemy totems", "nameplateShowEnemyTotems"},
    {"enemyMinions", "Enemy minions", "nameplateShowEnemyMinions"},
    {"friendlyPets", "Friendly pets", "nameplateShowFriendlyPets"},
    {"friendlyGuardians", "Friendly guardians", "nameplateShowFriendlyGuardians"},
    {"friendlyTotems", "Friendly totems", "nameplateShowFriendlyTotems"},
    {"friendlyMinions", "Friendly minions", "nameplateShowFriendlyMinions"},
}) do
    CVar(module, value[1], value[2], value[3])
end
CVar(module, "maxDistance", "Maximum distance", "nameplateMaxDistance", "number")

module = Module("ActionBarsQoL", "Action Bars")
CVar(module, "alwaysShowActionBars", "Always show action bars", "alwaysShowActionBars")
CVar(module, "autoPushSpellToActionBar", "Push new spells to action bar", "AutoPushSpellToActionBar")
CVar(module, "autoSelfCast", "Auto self cast", "autoSelfCast")
for bar = 2, 8 do
    Feature(module, "showActionBars" .. bar, "Action bar " .. bar, "actionbar", {
        bar = bar,
        valueType = "boolean",
        protected = true,
        events = {PLAYER_LOGIN = true, ADDON_LOADED = true},
    })
end

module = Module("Mailbox", "Mailbox Improvements")
Feature(module, "recipients", "Saved recipients and alts", "saved")
Feature(module, "gold", "Character gold", "functions", {
    requires = {"GetMoney"},
})
Feature(module, "friends", "Friends", "friends")
Feature(module, "guild", "Guild members", "functions", {
    requires = {"GetNumGuildMembers", "GetGuildRosterInfo"},
})
Feature(module, "fields", "Recipient and subject fields", "mailfields", {
    provider = "Blizzard_MailUI",
    events = {PLAYER_LOGIN = true, MAIL_SHOW = true, ADDON_LOADED = true},
})
Feature(module, "attachments", "Choose and attach bag items", "containers", {
    provider = "Blizzard_MailUI",
    protected = true,
    events = {PLAYER_LOGIN = true, MAIL_SHOW = true, ADDON_LOADED = true},
})
Feature(module, "quickSend", "Quick Send categories (attachments)", "containers", {
    provider = "Blizzard_MailUI",
    protected = true,
    events = {PLAYER_LOGIN = true, MAIL_SHOW = true, ADDON_LOADED = true},
})

module = Module("Graphics", "Graphics Settings")
CVar(module, "ViewDistance", "View distance (farclip)", "farclip", "number")
CVar(module, "FogDistance", "Fog distance (horizonStart)", "horizonStart", "number")
CVar(module, "graphicsViewDistance", "Graphics view distance", "graphicsViewDistance", "number")

module = Module("BlizzardFixes", "Blizzard Fixes")
module.hardlocked = true
Feature(module, "fixes", "Version-specific fixes", "unsupported", {
    reason = "MoP/BCC fixes are never inherited by Auto or Forever",
})

module = Module("EditMode", "Edit Mode")
Feature(module, "saved", "Saved layout backups", "saved")
Feature(module, "layouts", "Available layouts", "layouts", {
    provider = "Blizzard_EditMode",
    events = {PLAYER_LOGIN = true, ADDON_LOADED = true, EDIT_MODE_LAYOUTS_UPDATED = true},
})
Feature(module, "apply", "Apply a layout", "layoutApply", {
    protected = true,
    provider = "Blizzard_EditMode",
    events = {PLAYER_LOGIN = true, ADDON_LOADED = true, EDIT_MODE_LAYOUTS_UPDATED = true},
})
Feature(module, "export", "Export and back up layouts", "layoutExport", {
    provider = "Blizzard_EditMode",
    events = {PLAYER_LOGIN = true, ADDON_LOADED = true, EDIT_MODE_LAYOUTS_UPDATED = true},
})
Feature(module, "autoSwitch", "Automatic layout by specialization", "layoutAuto", {
    protected = true,
    provider = "Blizzard_EditMode",
    events = {
        PLAYER_LOGIN = true,
        ADDON_LOADED = true,
        PLAYER_SPECIALIZATION_CHANGED = true,
        EDIT_MODE_LAYOUTS_UPDATED = true,
    },
})

module = Module("RaidProfiles", "Raid Profiles")
Feature(module, "saved", "Saved raid profiles", "saved")
Feature(module, "capture", "Capture compatible raid options", "raidRead")
Feature(module, "apply", "Apply a matching profile", "raidWrite", {protected = true})
Feature(module, "positions", "Legacy saved positions", "raidPositions", {protected = true})
Feature(module, "autoSwitch", "Forced compatible profile", "raidWrite", {protected = true})

module = Module("DungeonTeleportsTab", "Dungeon Teleports")
Feature(module, "spells", "Known teleport spells", "teleports", {
    events = {PLAYER_LOGIN = true, SPELLS_CHANGED = true},
})
Feature(module, "cast", "Teleport buttons", "teleportCast", {
    protected = true,
    events = {PLAYER_LOGIN = true, SPELLS_CHANGED = true, ADDON_LOADED = true},
})
Feature(module, "cooldowns", "Spell cooldowns", "cooldowns", {
    events = {PLAYER_LOGIN = true, SPELLS_CHANGED = true},
})
Feature(module, "pveTab", "Group Finder tab", "pve", {
    provider = "Blizzard_GroupFinder",
    events = {PLAYER_LOGIN = true, ADDON_LOADED = true},
})
Feature(module, "popup", "Group Finder popup", "pve", {
    provider = "Blizzard_GroupFinder",
    events = {PLAYER_LOGIN = true, ADDON_LOADED = true},
})

module = Module("MythicPlusListing", "Mythic+ Listing Helper")
Feature(module, "ownKey", "Own keystone", "keystone", {
    events = {PLAYER_LOGIN = true, CHALLENGE_MODE_MAPS_UPDATE = true},
})
Feature(module, "group", "Party members", "functions", {
    requires = {
        "GetNumGroupMembers",
        "UnitName",
        "UnitClass",
        "GetRealmName",
        "IsInGroup",
        "IsInRaid",
        "UnitExists",
    },
})
Feature(module, "rating", "Player rating", "functions", {
    requires = {"C_PlayerInfo.GetPlayerMythicPlusRatingSummary"},
})
Feature(module, "communication", "Party keystone exchange", "communication")
Feature(module, "listingRead", "Current listing", "listingRead", {
    events = {PLAYER_LOGIN = true, ADDON_LOADED = true},
})
Feature(module, "integration", "Existing LFG entry controller", "mythicUI", {
    provider = "Blizzard_GroupFinder",
    events = {PLAYER_LOGIN = true, ADDON_LOADED = true},
})
Feature(module, "listingWrite", "Fill existing LFG entry form", "mythicUI", {
    provider = "Blizzard_GroupFinder",
    protected = true,
    events = {PLAYER_LOGIN = true, ADDON_LOADED = true},
})

A.teleportIDs = {
    131204, 131205, 131206, 131222, 131225, 131228, 131229, 131231,
    131232, 159895, 159896, 159897, 159898, 159899, 159900, 159901,
    159902, 354462, 354463, 354464, 354465, 354466, 354467, 354468,
    354469, 367416, 373190, 373191, 373192, 373262, 373274, 393222,
    393256, 393262, 393267, 393273, 393276, 393279, 393283, 393764,
    393766, 410071, 410074, 410078, 410080, 424142, 424153, 424163,
    424167, 424187, 424197, 432254, 432257, 432258, 445269, 445414,
    445416, 445417, 445418, 445424, 445440, 445441, 445443, 445444,
    464256, 467553, 467555, 1216786, 1226482, 1237215, 1239155,
    1254400, 1254551, 1254555, 1254559, 1254563, 1254572, 1286801,
    1286804, 1286807, 1286809, 1286812, 1286828, 1286831,
}
