local addonName = ...
mQoL_FastAutoloot = mQoL_FastAutoloot or {}

local FastAutoloot = mQoL_FastAutoloot
FastAutoloot.frame = FastAutoloot.frame or CreateFrame("Frame")
FastAutoloot.closeCheckQueued = false
FastAutoloot.pendingClose = false
FastAutoloot.isEnabled = false
FastAutoloot.initialAutoLootState = nil
FastAutoloot.lastLootCount = nil
FastAutoloot.lootTicker = nil
FastAutoloot.currentLootSlot = nil

FastAutoloot.defaults = {
    FastAutoLootEnabled = false,
    FastAutoLootSpeed = 0.02,
    FastAutoLootMinSpeed = 0.01,
    FastAutoLootMaxSpeed = 0.10,
}

local function GetGeneralSettings()
    mQoL_DB = mQoL_DB or {}
    mQoL_DB["MainQoL"] = mQoL_DB["MainQoL"] or {}
    mQoL_DB["MainQoL"].settings = mQoL_DB["MainQoL"].settings or {}
    mQoL_DB["MainQoL"].settings.general = mQoL_DB["MainQoL"].settings.general or {}
    return mQoL_DB["MainQoL"].settings.general
end

local function IsGeneralQoLModuleEnabled()
    if not mQoL_Modules or type(mQoL_Modules.ShouldLoadModule) ~= "function" then
        return true
    end

    return mQoL_Modules:ShouldLoadModule("GeneralQoL")
end

local function GetLegacyFastLootValue(value)
    local numericValue = tonumber(value)
    if numericValue ~= nil then
        return numericValue > 0
    end

    if value == nil then
        return FastAutoloot.defaults.FastAutoLootEnabled
    end

    return value == true
end

local function GetSavedFastAutoLootValue()
    local general = GetGeneralSettings()

    if general.fastAutoLoot == nil then
        return FastAutoloot.defaults.FastAutoLootEnabled
    end

    return general.fastAutoLoot == true
end

local function ClampFastAutoLootSpeed(value)
    value = tonumber(value) or FastAutoloot.defaults.FastAutoLootSpeed
    return math.max(FastAutoloot.defaults.FastAutoLootMinSpeed, math.min(FastAutoloot.defaults.FastAutoLootMaxSpeed, value))
end

local function GetSavedFastAutoLootSpeed()
    local general = GetGeneralSettings()
    return ClampFastAutoLootSpeed(general.fastAutoLootSpeed)
end

local function ResolveAutoLootState(autoLoot)
    if type(autoLoot) == "boolean" then
        return autoLoot
    end

    local autoLootDefault = GetCVarBool("autoLootDefault")
    local modifierHeld = type(IsModifiedClick) == "function" and IsModifiedClick("AUTOLOOTTOGGLE") or false
    return autoLootDefault ~= modifierHeld
end

local function IsEmptyLootSlot(slot)
    if type(GetLootSlotType) ~= "function" then
        return false
    end

    local slotType = GetLootSlotType(slot)
    if slotType == nil then
        return false
    end

    if Enum and Enum.LootSlotType and Enum.LootSlotType.None ~= nil then
        return slotType == Enum.LootSlotType.None
    end

    return slotType == 0
end

function FastAutoloot:CancelLootTicker()
    if self.lootTicker then
        self.lootTicker:Cancel()
        self.lootTicker = nil
    end

    self.currentLootSlot = nil
end

function FastAutoloot:ResetLootState()
    self:CancelLootTicker()
    self.closeCheckQueued = false
    self.pendingClose = false
    self.initialAutoLootState = nil
    self.lastLootCount = nil
end

function FastAutoloot:TryCloseLoot()
    if not self.pendingClose then
        return
    end

    if self.lootTicker then
        return
    end

    if type(GetNumLootItems) == "function" and GetNumLootItems() > 0 then
        return
    end

    self.pendingClose = false
    self.lastLootCount = nil

    if type(CloseLoot) == "function" and LootFrame and LootFrame:IsShown() then
        CloseLoot()
    end
end

function FastAutoloot:ScheduleCloseCheck()
    if self.closeCheckQueued then
        return
    end

    self.closeCheckQueued = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            FastAutoloot.closeCheckQueued = false
            FastAutoloot:TryCloseLoot()
        end)
        return
    end

    self.closeCheckQueued = false
    self:TryCloseLoot()
end

function FastAutoloot:LootSingleSlot(slot)
    if type(LootSlot) ~= "function" then
        return
    end

    if IsEmptyLootSlot(slot) then
        return
    end

    LootSlot(slot)
end

function FastAutoloot:StartLootTicker(lootCount)
    self:CancelLootTicker()
    self.currentLootSlot = lootCount
    self.pendingClose = true

    if C_Timer and C_Timer.NewTicker then
        self.lootTicker = C_Timer.NewTicker(GetSavedFastAutoLootSpeed(), function()
            if not FastAutoloot.currentLootSlot or FastAutoloot.currentLootSlot < 1 then
                FastAutoloot:CancelLootTicker()
                FastAutoloot:ScheduleCloseCheck()
                return
            end

            FastAutoloot:LootSingleSlot(FastAutoloot.currentLootSlot)
            FastAutoloot.currentLootSlot = FastAutoloot.currentLootSlot - 1
        end)
        return
    end

    for slot = lootCount, 1, -1 do
        self:LootSingleSlot(slot)
    end

    self:ScheduleCloseCheck()
end

function FastAutoloot:HandleLootReady(autoLoot)
    if not self.isEnabled or not IsGeneralQoLModuleEnabled() then
        return
    end

    if self.initialAutoLootState == nil then
        self.initialAutoLootState = ResolveAutoLootState(autoLoot)
    end

    if self.initialAutoLootState ~= true or type(GetNumLootItems) ~= "function" then
        return
    end

    local lootCount = GetNumLootItems()
    if lootCount <= 0 then
        self:ScheduleCloseCheck()
        return
    end

    if self.lootTicker or self.lastLootCount == lootCount then
        return
    end

    self.lastLootCount = lootCount
    self:StartLootTicker(lootCount)
end

function FastAutoloot:UpdateEventRegistration()
    if self.isEnabled and IsGeneralQoLModuleEnabled() then
        self.frame:RegisterEvent("LOOT_READY")
        self.frame:RegisterEvent("LOOT_OPENED")
        self.frame:RegisterEvent("LOOT_SLOT_CLEARED")
        self.frame:RegisterEvent("LOOT_CLOSED")
        return
    end

    self.frame:UnregisterEvent("LOOT_READY")
    self.frame:UnregisterEvent("LOOT_OPENED")
    self.frame:UnregisterEvent("LOOT_SLOT_CLEARED")
    self.frame:UnregisterEvent("LOOT_CLOSED")
    self:ResetLootState()
end

function FastAutoloot:SetEnabled(value)
    if value == nil then
        self.isEnabled = FastAutoloot.defaults.FastAutoLootEnabled
    else
        self.isEnabled = value == true
    end

    self:UpdateEventRegistration()
end

function FastAutoloot:GetSpeed()
    return GetSavedFastAutoLootSpeed()
end

function FastAutoloot:SetSpeed(value)
    local general = GetGeneralSettings()
    general.fastAutoLootSpeed = ClampFastAutoLootSpeed(value)
    return general.fastAutoLootSpeed
end

function FastAutoloot:MigrateSettings()
    local general = GetGeneralSettings()

    if general.fastAutoLoot == nil then
        general.fastAutoLoot = GetLegacyFastLootValue(general.autoLootRate)
    end

    general.fastAutoLootSpeed = ClampFastAutoLootSpeed(general.fastAutoLootSpeed)
    general.autoLootRate = nil
    self:SetEnabled(GetSavedFastAutoLootValue())
end

FastAutoloot.frame:RegisterEvent("ADDON_LOADED")
FastAutoloot.frame:RegisterEvent("PLAYER_LOGIN")
FastAutoloot.frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        FastAutoloot:MigrateSettings()
        return
    end

    if event == "PLAYER_LOGIN" then
        FastAutoloot:SetEnabled(GetSavedFastAutoLootValue())
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        FastAutoloot:HandleLootReady(arg1)
    elseif event == "LOOT_SLOT_CLEARED" then
        FastAutoloot:ScheduleCloseCheck()
    elseif event == "LOOT_CLOSED" then
        FastAutoloot:ResetLootState()
    end
end)