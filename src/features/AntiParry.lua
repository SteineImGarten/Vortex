--[[
    Combat Warriors - Anti-Parry
    Suppresses attack events directed at players who have active parry states (detected via parry sounds).
]]

local AntiParry = {}

function AntiParry.Init(Vortex)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer

    -- Global cache of player character models currently parrying
    getgenv().RecentParryPlayers = getgenv().RecentParryPlayers or {}

    -- Hook outgoing game events to block or delay damage sent to parrying opponents
    Vortex.Hook(
        "@Network",
        "FireServer",
        "Anti-Hit",
        function(Original, ...)
            local Args = {...}
            
            if getgenv().AntiParry and Args[1] == "MeleeDamage" then
                local TargetPart = Args[3] -- Shifted index based on FireServer(self, RemoteName, ...)
                local PlayerModel = TargetPart and TargetPart.Parent

                if PlayerModel then
                    -- If they are already parrying, suppress the hit completely right away
                    if getgenv().RecentParryPlayers[PlayerModel] then
                        local storeObj = Vortex.Get("RoduxStore")
                        if storeObj then
                            local Message = ("Suppressed %s"):format(PlayerModel.Name)
                            Vortex.Call("@ToastNotificationActionsClient", "add", "success", Message, 5, true, { BypassHook = false })(storeObj.store)
                        end
                        
                        Vortex.Call("@SoundHandler", "playSound", {
                            soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
                            parent = workspace:FindFirstChild("Sounds") or workspace
                        })
                        return -- Block hit remote completely
                    end

                    -- If they aren't parrying yet, delay the hit event by 100ms
                    -- This gives the SoundHandler hook a window to detect a late parry and add them to the exclusion list
                    task.delay(0.1, function()
                        -- Double check if they managed to parry within that 100ms window
                        if getgenv().AntiParry and getgenv().RecentParryPlayers[PlayerModel] then
                            local storeObj = Vortex.Get("RoduxStore")
                            if storeObj then
                                local Message = ("Late Suppression on %s"):format(PlayerModel.Name)
                                Vortex.Call("@ToastNotificationActionsClient", "add", "success", Message, 5, true, { BypassHook = false })(storeObj.store)
                            end
                            return -- Block the delayed hit from firing
                        end
                        
                        -- Otherwise, fire the original remote safely
                        Original(unpack(Args))
                    end)

                    return -- Prevent the immediate default fire execution
                end
            end

            return Original(...)
        end,
        { Spy = false }
    )

    -- Hook sound cues to identify target parry triggers
    Vortex.Hook(
        "@SoundHandler",
        "playSound",
        "Anti-Parry",
        function(Original, Data, ...)
            if getgenv().AntiParry and Data and Data.soundObject and Data.soundObject.Name == "Parry" then
                -- Restored your original exact parent walk
                local PlayerModel = Data.parent and Data.parent.Parent and Data.parent.Parent.Parent

                if PlayerModel and PlayerModel ~= LocalPlayer.Character then
                    getgenv().RecentParryPlayers[PlayerModel] = true
                    
                    task.delay(0.2, function()
                        getgenv().RecentParryPlayers[PlayerModel] = nil
                    end)
                end
            end

            return Original(Data, ...)
        end,
        { Spy = false }
    )
end

return AntiParry
