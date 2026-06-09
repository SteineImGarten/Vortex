--[[
    Combat Warriors - Settings Configurator
    Safely initialises default settings variables in the global environment (getgenv).
]]

local Settings = {}

function Settings.LoadDefaults()
    local defaults = {
        Keybinds = {
            Fly = Enum.KeyCode.V,
            Desync = Enum.KeyCode.B,
            SilentAim = Enum.KeyCode.M
        },
        HitPart = "HumanoidRootPart",
        FOV = 40,
        NoReloadCancel = false,
        SilentAim = false,
        Fly = false,
        DesyncEnabled = false,
        FlySpeed = 60,
        RangeExpander = false,
        HitReach = 25,
        AntiParry = false,
        FastSpawn = false,
        AntiRagdoll = false
    }

    -- Set default keys if they don't exist yet
    for key, val in pairs(defaults) do
        if getgenv()[key] == nil then
            getgenv()[key] = val
        elseif type(val) == "table" and type(getgenv()[key]) == "table" then
            -- Deep copy/merge first level for sub-tables like Keybinds
            for subKey, subVal in pairs(val) do
                if getgenv()[key][subKey] == nil then
                    getgenv()[key][subKey] = subVal
                end
            end
        end
    end
end

return Settings
