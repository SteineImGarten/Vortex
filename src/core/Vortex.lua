--[[
    Vortex Framework - Core Engine
    Universal modular script engine with built-in hooking, PsmSignal event-driven design,
    predictive math, and decoupled game adapters.
]]

setthreadidentity(2)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Vortex = {}
Vortex.Adapters = {}
Vortex.Signals = {}

--------------------------------------------------------------------------------
-- 1. PsmSignal Class Implementation
--------------------------------------------------------------------------------
local PsmSignal = {}
PsmSignal.__index = PsmSignal

function PsmSignal.new()
    local self = setmetatable({}, PsmSignal)
    self._connections = {}
    return self
end

function PsmSignal:Connect(callback)
    local connection = {
        Callback = callback,
        Connected = true,
        Disconnect = function(conn)
            conn.Connected = false
            for i, c in ipairs(self._connections) do
                if c == conn then
                    table.remove(self._connections, i)
                    break
                end
            end
        end
    } -- Added the missing closing curly brace '}' here
    table.insert(self._connections, connection)
    return connection
end

function PsmSignal:Once(callback)
    local connection
    connection = self:Connect(function(...)
        if connection then
            connection:Disconnect()
        end
        callback(...)
    end)
    return connection
end

function PsmSignal:Wait()
    local thread = coroutine.running()
    local connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

function PsmSignal:Fire(...)
    local connections = table.clone(self._connections)
    for _, conn in ipairs(connections) do
        if conn.Connected then
            task.spawn(conn.Callback, ...)
        end
    end
end

Vortex.PsmSignal = PsmSignal
Vortex.Signal = PsmSignal

-- Globalize for Script-Ware / general UNC executor compatibility
local globalEnv = getgenv or function() return _G end
globalEnv().PsmSignal = PsmSignal
globalEnv().Signal = PsmSignal

--------------------------------------------------------------------------------
-- 2. Define Framework Core Signals
--------------------------------------------------------------------------------
Vortex.Signals.FeatureToggled = PsmSignal.new()
Vortex.Signals.FrameworkLoaded = PsmSignal.new()

--------------------------------------------------------------------------------
-- 3. HookLoader Implementation (Directly under Vortex)
--------------------------------------------------------------------------------
local GlobalTable = globalEnv()
GlobalTable._LoaderCache = GlobalTable._LoaderCache or {}
GlobalTable._HookRegistry = GlobalTable._HookRegistry or {}

local Debug = false
local SpyEnabled = false
local SpyConfig = {
    Delay = 0,
    LogReturns = true
}

local Folders = {}
local SpyWrapped = {}
local SpyBackups = {}

function Vortex.Debug(State)
    Debug = not not State
end

function Vortex.Folders(List)
    Folders = List or {}
end

function Vortex.Global(Table)
    if type(Table) == "table" then
        GlobalTable = Table
        GlobalTable._HookRegistry = GlobalTable._HookRegistry or {}
    end
end

local function SafeRequire(Module)
    local Ok, Result = pcall(require, Module)
    if not Ok then
        if Debug then
            warn(("[Vortex] Failed to require module '%s': %s"):format(Module:GetFullName(), tostring(Result)))
        end
        return nil
    end
    if typeof(Result) ~= "table" then
        return {}
    end
    return Result
end

local function FormatValue(Value, Depth, Seen)
    Depth = Depth or 0
    Seen = Seen or {}
    local Indent = string.rep("  ", Depth)
    local t = typeof(Value)
    
    if t == "string" then
        return ("\"%s\""):format(Value:gsub("\n", "\\n"))
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(Value)
    elseif t == "table" then
        if Seen[Value] then return "<cycle>" end
        Seen[Value] = true
        local Parts = {}
        local IsArray = true
        local MaxIndex = 0
        
        for k, _ in pairs(Value) do
            if type(k) ~= "number" then
                IsArray = false
                break
            else
                if k > MaxIndex then MaxIndex = k end
            end
        end
        
        if IsArray and MaxIndex > 0 then
            table.insert(Parts, "[")
            for i = 1, MaxIndex do
                local v = Value[i]
                table.insert(Parts, ("\n%s  %s,"):format(Indent, FormatValue(v, Depth + 1, Seen)))
            end
            table.insert(Parts, ("\n%s]"):format(Indent))
            return table.concat(Parts, "")
        else
            table.insert(Parts, "{")
            for k, v in pairs(Value) do
                local KeySTR = tostring(k)
                local ValSTR = FormatValue(v, Depth + 1, Seen)
                table.insert(Parts, ("\n%s  %s = %s,"):format(Indent, KeySTR, ValSTR))
            end
            table.insert(Parts, ("\n%s}"):format(Indent))
            return table.concat(Parts, "")
        end
    else
        return tostring(Value)
    end
end

local function PrintArgs(Args)
    for i = 1, #Args do
        local v = Args[i]
        local t = typeof(v)
        if t == "table" then
            print(("[Vortex] Arg%d (table): %s"):format(i, FormatValue(v, 0, {})))
        else
            print(("[Vortex] Arg%d (%s): %s"):format(i, t, FormatValue(v)))
        end
    end
end

local function PrintReturn(Ret)
    if typeof(Ret) == "table" then
        print(("[Vortex] Return: %s"):format(FormatValue(Ret, 0, {})))
    else
        print(("[Vortex] Return: %s"):format(FormatValue(Ret)))
    end
end

local function isCClosureFunc(f)
    if iscclosure then return iscclosure(f) end
    return debug.info(f, "s") == "[C]"
end

local function WrapWithSpy(ModuleKey, Mod, FuncName)
    local Key = ModuleKey .. "." .. FuncName
    if SpyWrapped[Key] then return end

    local Original = Mod[FuncName]
    if type(Original) ~= "function" then return end

    SpyWrapped[Key] = true
    local lastPrint = 0

    local function spyWrapper(...)
        local now = tick()
        if SpyEnabled and (now - lastPrint >= (SpyConfig.Delay or 0)) then
            lastPrint = now
            print(("=== [SPY] %s -> %s ==="):format(ModuleKey, FuncName))
            PrintArgs({...})
        end

        local results
        if SpyBackups[Key] then
            results = table.pack(SpyBackups[Key](...))
        else
            results = table.pack(Original(...))
        end

        if SpyEnabled and SpyConfig.LogReturns then
            PrintReturn(results.n == 1 and results[1] or results)
        end

        return table.unpack(results, 1, results.n)
    end

    if oth and oth.hook and isCClosureFunc(Original) then
        SpyBackups[Key] = oth.hook(Original, spyWrapper)
    elseif hookfunction then
        local nativeWrapper = newcclosure and newcclosure(spyWrapper) or spyWrapper
        SpyBackups[Key] = hookfunction(Original, nativeWrapper)
    else
        Mod[FuncName] = spyWrapper
    end
end

local function ApplyGlobalSpy()
    for ModuleKey, Mod in pairs(GlobalTable) do
        if type(ModuleKey) == "string" and ModuleKey:sub(1, 1) == "@" and type(Mod) == "table" then
            for FuncName, Value in pairs(Mod) do
                if type(Value) == "function" then
                    WrapWithSpy(ModuleKey, Mod, FuncName)
                end
            end
        end
    end
end

function Vortex.Spy(State, Config)
    SpyEnabled = not not State
    SpyConfig = Config or SpyConfig
    if SpyEnabled then
        ApplyGlobalSpy()
        print("[Vortex] Global Spy ENABLED")
    else
        print("[Vortex] Global Spy DISABLED")
    end
end

function Vortex.Load()
    local Mods = {}
    for _, Folder in ipairs(Folders) do
        for _, Module in ipairs(Folder:GetDescendants()) do
            if Module:IsA("ModuleScript") then
                local Tbl = SafeRequire(Module)
                if Tbl then
                    local Key = "@" .. Module.Name
                    Mods[Key] = Tbl
                    if Debug then
                        print(("[Vortex] Loaded module: %s"):format(Module:GetFullName()))
                    end
                end
            end
        end
    end

    for Key, Val in pairs(Mods) do
        GlobalTable[Key] = Val
    end

    if Debug then
        local Count = 0
        for _ in pairs(Mods) do Count = Count + 1 end
        print("[Vortex] Total modules loaded:", Count)
    end

    GlobalTable.LOAD_FINISHED = true
    return Mods
end

function Vortex.Call(ModuleKey, FunctionName, ...)
    local Args = {...}
    local BypassHook = false

    if #Args > 0 and type(Args[#Args]) == "table" and Args[#Args].BypassHook then
        BypassHook = true
        table.remove(Args, #Args)
        if Debug then PrintArgs(Args) end
    end

    local Mod = GlobalTable[ModuleKey]
    if not Mod then
        warn(("[Vortex] Module '%s' not found"):format(ModuleKey))
        return nil
    end

    local Func
    if BypassHook and Mod._OriginalFunctions and Mod._OriginalFunctions[FunctionName] then
        Func = Mod._OriginalFunctions[FunctionName]
    else
        Func = Mod[FunctionName]
    end

    if typeof(Func) ~= "function" then
        warn(("[Vortex] Function '%s' not found in module '%s'"):format(FunctionName, ModuleKey))
        return nil
    end
    
    return Func(table.unpack(Args))
end

function Vortex.Hook(ModuleKey, FunctionName, HookID, HookFunc, Config)
    if type(HookFunc) ~= "function" and type(HookID) == "function" then
        HookFunc, Config = HookID, HookFunc
        HookID = "Default"
    end

    Config = Config or {}
    HookID = HookID or "Default"

    local Mod = GlobalTable[ModuleKey]
    if not Mod then
        warn(("[Vortex] Module '%s' not found"):format(ModuleKey))
        return nil
    end

    local OrigFunc = Mod[FunctionName]
    if type(OrigFunc) ~= "function" then
        warn(("[Vortex] Function '%s' not found in module '%s'"):format(FunctionName, ModuleKey))
        return nil
    end

    GlobalTable._HookRegistry[ModuleKey] = GlobalTable._HookRegistry[ModuleKey] or {}
    GlobalTable._HookRegistry[ModuleKey][FunctionName] = GlobalTable._HookRegistry[ModuleKey][FunctionName] or {}

    local HookTable = GlobalTable._HookRegistry[ModuleKey][FunctionName]

    if HookTable[HookID] then
        HookTable[HookID].Func = HookFunc
        HookTable[HookID].Config = Config
        HookTable[HookID].Priority = Config.Priority or 0
        HookTable[HookID].Active = true
        return Mod._OriginalFunctions[FunctionName]
    end

    HookTable[HookID] = {
        HookID = HookID,
        Func = HookFunc,
        Active = true,
        Config = Config,
        Priority = Config.Priority or 0
    }

    Mod._OriginalFunctions = Mod._OriginalFunctions or {}
    Mod._HookWrapped = Mod._HookWrapped or {}

    if Mod._HookWrapped[FunctionName] then
        return Mod._OriginalFunctions[FunctionName]
    end

    Mod._HookWrapped[FunctionName] = true

    local function SafeCall(Func, ...)
        local ok, result = pcall(Func, ...)
        if not ok then
            warn(("[Vortex] Hook Error: %s"):format(tostring(result)))
            return nil
        end
        return result
    end

    local LastSpyPrintTime = {}

    local function GetActiveHook()
        local best
        for _, hook in pairs(HookTable) do
            if hook.Active then
                if not best or hook.Priority > best.Priority then
                    best = hook
                end
            end
        end
        return best
    end

    local function Wrapper(...)
        local HookData = GetActiveHook()
        local baseFunc = Mod._OriginalFunctions[FunctionName] or OrigFunc
        
        if not HookData then
            return baseFunc(...)
        end

        local CFG = HookData.Config or {}
        local HookFn = HookData.Func
        local key = ModuleKey .. "." .. FunctionName .. "." .. HookData.HookID

        if CFG.Spy then
            local now = tick()
            local delay = CFG.SpyDelay or 0
            LastSpyPrintTime[key] = LastSpyPrintTime[key] or 0

            if now - LastSpyPrintTime[key] >= delay then
                LastSpyPrintTime[key] = now
                print(("--- Spy Hook: %s -> %s [ID=%s] ---"):format(ModuleKey, FunctionName, HookData.HookID))
                PrintArgs({...})
            end
        end

        return SafeCall(HookFn, baseFunc, ...)
    end

    if oth and oth.hook and isCClosureFunc(OrigFunc) then
        local backup = oth.hook(OrigFunc, Wrapper)
        Mod._OriginalFunctions[FunctionName] = backup
    elseif hookfunction then
        local nativeWrapper = newcclosure and newcclosure(Wrapper) or Wrapper
        local backup = hookfunction(OrigFunc, nativeWrapper)
        Mod._OriginalFunctions[FunctionName] = backup
    else
        Mod._OriginalFunctions[FunctionName] = OrigFunc
        Mod[FunctionName] = Wrapper
    end

    if Debug then
        print(("[Vortex] Hook applied: %s -> %s [ID=%s]"):format(ModuleKey, FunctionName, HookID))
    end

    return Mod._OriginalFunctions[FunctionName]
end

function Vortex.UnHook(ModuleKey, FunctionName, HookID)
    local Mod = GlobalTable[ModuleKey]
    if not Mod or not GlobalTable._HookRegistry[ModuleKey] or not GlobalTable._HookRegistry[ModuleKey][FunctionName] then
        return
    end

    if HookID then
        GlobalTable._HookRegistry[ModuleKey][FunctionName][HookID] = nil
    else
        GlobalTable._HookRegistry[ModuleKey][FunctionName] = {}
    end
end

function Vortex.ViewHookIDs(ModuleKey, FunctionName)
    if not GlobalTable._HookRegistry[ModuleKey] or not GlobalTable._HookRegistry[ModuleKey][FunctionName] then
        print(("[Vortex] No hooks found for %s -> %s"):format(ModuleKey, FunctionName))
        return
    end

    print(("[Vortex] Hooks for %s -> %s:"):format(ModuleKey, FunctionName))
    for HookID, Data in pairs(GlobalTable._HookRegistry[ModuleKey][FunctionName]) do
        local Status = Data.Active and "ACTIVE" or "INACTIVE"
        local ConfigSTR = ""
        if Data.Config and next(Data.Config) then
            local Parts = {}
            for k, v in pairs(Data.Config) do
                table.insert(Parts, ("%s -> %s"):format(k, tostring(v)))
            end
            ConfigSTR = " | Modifies: " .. table.concat(Parts, ", ")
        end
        print(("  ID: %s [%s]%s"):format(HookID, Status, ConfigSTR))
    end
end

function Vortex.ShowFunc(FuncName)
    if type(FuncName) ~= "string" then
        warn("[Vortex] ShowFunc requires a string argument")
        return {}
    end

    local Results = {}
    local Searched = 0

    for Key, Mod in pairs(GlobalTable) do
        if type(Key) == "string" and Key:sub(1, 1) == "@" then
            Searched = Searched + 1
            local Ok, HasFunc = pcall(function()
                return type(Mod) == "table" and typeof(Mod[FuncName]) == "function"
            end)

            if Ok and HasFunc then
                table.insert(Results, Key)
            end
        end
    end

    if #Results == 0 then
        print(("[Vortex] No modules contain a function named '%s' (searched %d modules)"):format(FuncName, Searched))
    else
        print(("[Vortex] Found function '%s' in %d module(s):"):format(FuncName, #Results))
        for _, ModKey in ipairs(Results) do
            print("  →", ModKey)
        end
    end

    return Results
end

function Vortex.Get(Name)
    if type(Name) ~= "string" then
        warn("[Vortex] Get requires a string module name")
        return nil
    end

    local Env = globalEnv()
    local Mod = Env[Name] or Env["@" .. Name]
    if not Mod then
        warn(("[Vortex] Module not found: %s"):format(Name))
        return nil
    end
    return Mod
end

--------------------------------------------------------------------------------
-- 4. Extensible Adapter Registry
--------------------------------------------------------------------------------
function Vortex.RegisterAdapter(name, func)
    Vortex.Adapters[name] = func
end

--------------------------------------------------------------------------------
-- 5. Universal Helper Utilities
--------------------------------------------------------------------------------

-- Returns all parts from other players' characters within a specific radius of a position

function Vortex.GetCharacter(Player)
    Player = Player or Players.LocalPlayer
    return Player and Player.Character
end

function Vortex.IsAlive(Player)
    local Char = Vortex.GetCharacter(Player)
    local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
    local Hrp = Char and Char:FindFirstChild("HumanoidRootPart")
    return not not (Hum and Hrp and Hum.Health > 0)
end

function Vortex.GetTeam(Player)
    Player = Player or Players.LocalPlayer
    return Player and Player.Team
end

function Vortex.IsEnemy(Player)
    local LocalPlayer = Players.LocalPlayer
    if not Player or Player == LocalPlayer then return false end
    
    local LocalTeam = Vortex.GetTeam(LocalPlayer)
    local TargetTeam = Vortex.GetTeam(Player)
    
    if LocalTeam and TargetTeam then
        return LocalTeam ~= TargetTeam
    end
    return true
end

function Vortex.Notify(Type, Title, Text, Duration)
    Type = Type or "success"
    Duration = Duration or 5
    
    local StoreObj = Vortex.Get("RoduxStore")
    if StoreObj then
        pcall(function()
            Vortex.Call("@ToastNotificationActionsClient", "add", Type, Text, Duration, true, { BypassHook = false })(StoreObj.store)
        end)
    else
        print(("[Vortex Notification] [%s] %s: %s"):format(Type:upper(), tostring(Title or ""), tostring(Text)))
    end
end

function Vortex.GetPartsInRange(position, radius, partName)
    local targets = {}
    partName = partName or "Head"
    for _, player in ipairs(Players:GetPlayers()) do
        if player == Players.LocalPlayer then continue end
        local char = player.Character
        local part = char and char:FindFirstChild(partName)
        if part then
            local dist = (part.Position - position).Magnitude
            if dist <= radius then
                table.insert(targets, part)
            end
        end
    end
    return targets
end

-- Get closest player in distance
function Vortex.GetClosestPlayer(maxDistance, checkFunction)
    local localPlayer = Players.LocalPlayer
    local check = checkFunction or function(p)
        local char = p.Character
        return char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0
    end

    maxDistance = maxDistance or math.huge
    local closestDist = maxDistance
    local result = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        if not check(player) then continue end

        local hrp = player.Character.HumanoidRootPart
        local localHrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not localHrp then continue end

        local dist = (hrp.Position - localHrp.Position).Magnitude
        if dist < closestDist then
            closestDist = dist
            result[player.Name] = player.Character.Humanoid.Health
        end
    end
    return result
end

-- Get target sorted/filtered by health
function Vortex.GetHealthTarget(maxDistance, priority, checkFunction)
    local localPlayer = Players.LocalPlayer
    local check = checkFunction or function(p)
        local char = p.Character
        return char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and not char:FindFirstChildOfClass("ForceField")
    end

    maxDistance = maxDistance or math.huge
    local lowestHealth = math.huge
    local closestDist = maxDistance
    local targetObj = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        if not check(player) then continue end

        local hrp = player.Character.HumanoidRootPart
        local localHrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not localHrp then continue end

        local dist = (hrp.Position - localHrp.Position).Magnitude
        local health = player.Character.Humanoid.Health

        if dist <= closestDist then
            if priority == "Health" then
                if health < lowestHealth then
                    lowestHealth = health
                    targetObj = player
                end
            else
                closestDist = dist
                targetObj = player
            end
        end
    end
    return targetObj and { [targetObj.Name] = true } or nil
end

-- Get closest target to mouse inside screen FOV
function Vortex.GetMouseTarget(maxDistance, fov, partName, checkFunction)
    local localPlayer = Players.LocalPlayer
    local mouse = localPlayer:GetMouse()
    local camera = Workspace.CurrentCamera
    partName = partName or "Torso"

    local check = checkFunction or function(p)
        local char = p.Character
        return char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0
    end

    maxDistance = maxDistance or math.huge
    fov = fov or math.huge

    local closestTarget = nil
    local closestScreenDist = fov

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        if not check(player) then continue end

        local char = player.Character
        local targetPart = char:FindFirstChild(partName)
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("HumanoidRootPart")

        if not targetPart then continue end

        local screenPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
        if not onScreen then continue end

        local screenDist = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
        if screenDist < closestScreenDist then
            closestScreenDist = screenDist
            closestTarget = player
        end
    end

    return closestTarget
end

-- Adapter aliases (checks adapters table first for backward compatibility)
function Vortex.MeleeWeapon(player)
    local adapter = Vortex.Adapters.GetMeleeWeapon
    if adapter then
        return adapter(player)
    end
    -- Fallback default
    player = player or Players.LocalPlayer
    local char = player.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                return tool
            end
        end
    end
end

function Vortex.RangedWeapon(player)
    local adapter = Vortex.Adapters.GetRangedWeapon
    if adapter then
        return adapter(player)
    end
    -- Fallback default
    player = player or Players.LocalPlayer
    local char = player.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                return tool
            end
        end
    end
end

function Vortex.PlayerState()
    local adapter = Vortex.Adapters.GetPlayerState
    if adapter then
        return adapter()
    end
    return nil
end

function Vortex.SessionData(player)
    local adapter = Vortex.Adapters.GetSessionData
    if adapter then
        return adapter(player)
    end
    return nil
end

-- Prediction implementation using Kalman Math
local Kalman = import("math/Kalman")
function Vortex.Predict(part, origin, speed, drawLine, gravity)
    return Kalman.Predict(part, origin, speed, drawLine, gravity)
end
Vortex.Kalman = Kalman

-- Backward compatibility aliases
Vortex.ItemData = function(...)
    local adapter = Vortex.Adapters.GetItemData
    if adapter then return adapter(...) end
end
Vortex.ModRanged = function(...)
    local adapter = Vortex.Adapters.ModRanged
    if adapter then return adapter(...) end
end
Vortex.PrintWepStats = function(...)
    local adapter = Vortex.Adapters.PrintWepStats
    if adapter then return adapter(...) end
end
Vortex.ClosestPlayer = Vortex.GetClosestPlayer
Vortex.HealthTarget = Vortex.GetHealthTarget
Vortex.MouseTarget = Vortex.GetMouseTarget

--------------------------------------------------------------------------------
-- 6. Central Keybind Manager & Toggle Handler
--------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    local keybinds = GlobalTable.Keybinds
    if not keybinds then return end
    
    for featureName, keycode in pairs(keybinds) do
        if input.KeyCode == keycode then
            -- Determine state variable in global env
            local stateVar = featureName
            if featureName == "Desync" then
                stateVar = "DesyncEnabled"
            end
            
            local currentState = GlobalTable[stateVar]
            if currentState ~= nil then
                local newState = not currentState
                GlobalTable[stateVar] = newState
                Vortex.Signals.FeatureToggled:Fire(featureName, newState)
            end
        end
    end
end)

-- Register globals
GlobalTable.Vortex = Vortex
GlobalTable.Framework = Vortex
table.insert(GlobalTable._LoaderCache, {Folders = Folders, Loader = Vortex})

return Vortex
