--[[
    Combat Warriors - Fast Spawn
    Checks character select interfaces on RenderStepped to instantly request client spawn events.
]]

local FastSpawn = {}
local Connected = false

function FastSpawn.Init(FrameWork)
    if Connected then return end
    Connected = true

    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- Connect render frame loop
    RunService.RenderStepped:Connect(function()
        if not getgenv().FastSpawn then return end

        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local RoactUI = PlayerGui and PlayerGui:FindFirstChild("RoactUI")
        local MainMenu = RoactUI and RoactUI:FindFirstChild("MainMenu")

        if MainMenu then
            -- Invoke client spawn method through simplified framework call
            FrameWork.Call("@SpawnHandlerClient", "spawnCharacter", true)
        end
    end)
end

return FastSpawn
