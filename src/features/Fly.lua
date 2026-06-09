--[[
    Combat Warriors - Flight Mechanic
    Features WASD movement using customized body mover linear velocity vectors.
]]

local Fly = {}

function Fly.Init(FrameWork)
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera

    local FlyEnabled = false

    local function UpdateFlightState()
        local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")  
        if not HRP then return end  

        if FlyEnabled then
            if not HRP:FindFirstChild("flyVel") then  
                local Attachment = Instance.new("Attachment")
                Attachment.Parent = HRP
                
                -- Call AntiCheatHandler via simplified framework method
                local LinearVelocity = FrameWork.Call("@AntiCheatHandler", "createBodyMover", "LinearVelocity")  
                if LinearVelocity then
                    LinearVelocity.Name = "flyVel"  
                    LinearVelocity.Attachment0 = Attachment  
                    LinearVelocity.VectorVelocity = Vector3.new(0, 0, 0)  
                    LinearVelocity.MaxForce = 1e8  
                    LinearVelocity.Parent = HRP  
                end
            end
        else
            local flyVel = HRP:FindFirstChild("flyVel")
            if flyVel then
                flyVel:Destroy()
            end
            local attachment = HRP:FindFirstChildOfClass("Attachment")
            if attachment and attachment.Name == "Attachment" then
                attachment:Destroy()
            end
        end  
    end

    -- Listen to the central FeatureToggled signal
    FrameWork.Signals.FeatureToggled:Connect(function(featureName, state)
        if featureName == "Fly" then
            FlyEnabled = state
            UpdateFlightState()
        end
    end)

    -- Auto re-enable flight on respawn if active
    LocalPlayer.CharacterAdded:Connect(function(char)
        if FlyEnabled then
            task.wait(0.5)
            UpdateFlightState()
        end
    end)

    -- Hook movement tick
    RunService.RenderStepped:Connect(function()
        if not FlyEnabled then return end

        local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if HRP and HRP:FindFirstChild("flyVel") then
            local move = Vector3.new()
            
            -- Accumulate vector direction based on key inputs
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
            
            if move.Magnitude > 0 then 
                move = move.Unit * (getgenv().FlySpeed or 60) 
            end
            
            pcall(function()
                HRP.flyVel.VectorVelocity = move
            end)
        end
    end)
end

return Fly
