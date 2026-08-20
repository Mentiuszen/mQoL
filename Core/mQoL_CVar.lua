mQoL_CVar = mQoL_CVar or {}

local function ToBoolean(value, fallback)
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value ~= 0 end
    if type(value) == "string" then
        if value == "1" or value == "true" then return true end
        if value == "0" or value == "false" then return false end
    end
    return fallback
end

function mQoL_CVar:ReadBoolean(cvar, fallback)
    local success, value = pcall(function()
        if type(GetCVarBool) == "function" then
            return ToBoolean(GetCVarBool(cvar), fallback)
        end
        if type(GetCVar) == "function" then
            return ToBoolean(GetCVar(cvar), fallback)
        end
        return fallback
    end)
    return success and value or fallback
end

function mQoL_CVar:ReadNumber(cvar, fallback)
    local success, value = pcall(function()
        return type(GetCVar) == "function" and tonumber(GetCVar(cvar)) or nil
    end)
    return success and value or fallback
end

function mQoL_CVar:ReadSettingBoolean(settingKey, fallback)
    local success, value = pcall(function()
        if Settings and type(Settings.GetValue) == "function" then
            return ToBoolean(Settings.GetValue(settingKey), fallback)
        end
        return fallback
    end)
    return success and value or fallback
end

function mQoL_CVar:Apply(cvar, value)
    if not mQoL_Database or mQoL_Database:IsDisabled(value) then
        return
    end

    if value == true then
        SetCVar(cvar, 1)
    elseif value == false then
        SetCVar(cvar, 0)
    elseif type(value) == "number" then
        SetCVar(cvar, value)
    end
end
