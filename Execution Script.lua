--[[
    Vortex Framework - Entry Point Loader
    Configures client settings, imports the universal engine, and loads the bootstrapper.
]]

-- 1. Cap FPS Limit (Native Executor Function)
if setfpscap then
    setfpscap(240)
end

-- 2. Define Keybindings
getgenv().Keybinds = {
    Fly = Enum.KeyCode.V,
    Desync = Enum.KeyCode.B,
    SilentAim = Enum.KeyCode.M
}

-- 3. Target configuration settings
getgenv().HitPart = "HumanoidRootPart"
getgenv().FOV = 40
getgenv().HitReach = 25

-- 4. Feature Toggles
getgenv().SilentAim = false
getgenv().NoReloadCancel = false

getgenv().Fly = false
getgenv().FlySpeed = 60

getgenv().DesyncEnabled = false
getgenv().RangeExpander = false
getgenv().AntiParry = true
getgenv().AntiRagdoll = true
getgenv().FastSpawn = false

-- 5. Repository and Workspace Configuration
local owner = "SteineImGarten"
local repo = "CW-Next"
local branch = "main"

-- Auto-detect local path in executor workspace folder
local localPath = "Roblox Framework/src/"
local isLocal = false

if readfile and isfile then
    -- Check preferred new folder name
    local success, exists = pcall(isfile, localPath .. "Main.lua")
    if success and exists then
        isLocal = true
    else
        -- Fallback to legacy folder name
        localPath = "Combat Warriors Project/src/"
        success, exists = pcall(isfile, localPath .. "Main.lua")
        if success and exists then
            isLocal = true
        end
    end
end

local remoteBaseUrl = ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/src/"):format(owner, repo, branch)

-- Save loader metadata into getgenv() for child module scanning
getgenv().import_is_local = isLocal
getgenv().import_local_path = localPath
getgenv().import_repo_owner = owner
getgenv().import_repo_name = repo
getgenv().import_repo_branch = branch

-- Helper utility for secure HTTP network requests
local function HttpRequest(url)
    local req = request or http_request or syn.request
    if not req then
        error("[Vortex] Your executor does not support request/http_request function!")
    end

    local response = req({
        Url = url,
        Method = "GET"
    })

    if response and response.StatusCode == 200 then
        return true, response.Body
    else
        return false, response and tostring(response.StatusCode) or "No response"
    end
end

-- 6. Dynamic Import Function definition
local cache = {}
local function import(path)
    if cache[path] then
        return cache[path]
    end

    local content
    local urlOrPath
    
    if isLocal then
        urlOrPath = localPath .. path .. ".lua"
        local success, data = pcall(readfile, urlOrPath)
        if success then
            content = data
        else
            error("[Vortex] Failed to read local file: " .. urlOrPath .. "\nError: " .. tostring(data))
        end
    else
        urlOrPath = remoteBaseUrl .. path .. ".lua"
        local success, data = HttpRequest(urlOrPath)
        if success then
            content = data
        else
            error("[Vortex] Failed to retrieve remote file: " .. urlOrPath .. "\nError: " .. tostring(data))
        end
    end

    -- Compile retrieved script contents
    local fn, err = loadstring(content)
    if not fn then
        error("[Vortex] Failed to compile module '" .. path .. "' from: " .. urlOrPath .. "\nError: " .. tostring(err))
    end

    -- Run module and store its return values in cache
    local result = fn()
    cache[path] = result
    return result
end

getgenv().import = import

-- Start bootstrap loader
task.spawn(function()
    local success, err = pcall(function()
        import("Main").Start()
    end)
    if not success then
        warn("[Vortex] Bootstrapping failed:", tostring(err))
    end
end)
