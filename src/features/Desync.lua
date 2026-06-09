--[[
    Combat Warriors - Desync Engine
    Simulates high replication latency via specific Roblox client FFlag toggles.
]]

local Desync = {}

function Desync.Init(FrameWork)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")

    -- Connect to the central FeatureToggled signal
    FrameWork.Signals.FeatureToggled:Connect(function(featureName, state)
        if featureName == "Desync" then
            if state then
                -- Play sound and UI notification
                local storeObj = getgenv()["@RoduxStore"] or FrameWork.Get("RoduxStore")
                if storeObj then
                    FrameWork.Call("@ToastNotificationActionsClient", "add", "success", "Desynced", 5, true, { BypassHook = false })(storeObj.store)
                end
                
                FrameWork.Call("@SoundHandler", "playSound", {
                    soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
                    parent = Workspace.Sounds
                })
                
                -- Alter Roblox Replicator Fast Flag to trigger latency simulation
                setfflag("NextGenReplicatorEnabledWrite4", "True")
            else
                -- Disable latency simulation
                setfflag("NextGenReplicatorEnabledWrite4", "False")
            end
        end
    end)
end

return Desync
