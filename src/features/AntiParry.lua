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

    -- Hook outgoing game events to block damage sent to parrying opponents
    Vortex.Hook(
        "@Network",
        "FireServer",
        "Anti-Hit",
        function(Original, ...)
            -- UNTOUCHED: This is your exact original condition statement
            if getgenv().AntiParry and select(2, ...) == "MeleeDamage" then
                local TargetPart = select(4, ...)
                local PlayerModel = TargetPart and TargetPart.Parent

                if PlayerModel then
                    -- 1. Immediate check: if already parrying, drop instantly
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

                    -- 2. Delay Execution: Save the parameters exactly as they are right now
                    local Args = {Original, ...} 
                    
                    task.delay(0.1, function()
                        -- Re-verify if they managed to parry within the 100ms window
                        if getgenv().AntiParry and getgenv().RecentParryPlayers[PlayerModel] then
                            local storeObj = Vortex.Get("RoduxStore")
                            if storeObj then
                                local Message = ("Late Suppression on %s"):format(PlayerModel.Name)
                                Vortex.Call("@ToastNotificationActionsClient", "add", "success", Message, 5, true, { BypassHook = false })(storeObj.store)
                            end
                            return -- Block the delayed hit from firing
                        end
                        
                        -- Execute the original function with its pristine parameters
                        local OrigFunc = Args[1]
                        OrigFunc(unpack(Args, 2))
                    end)

                    return -- Stop the original immediate fire execution
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

                    local storeObj = Vortex.Get("RoduxStore")
                    if storeObj then
                        local Message = ("Suppressed in Exclusion List %s"):format(PlayerModel.Name)
                        Vortex.Call("@ToastNotificationActionsClient", "add", "success", Message, 5, true, { BypassHook = false })(storeObj.store)
                    end
                    
                    Vortex.Call("@SoundHandler", "playSound", {
                        soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
                        parent = workspace:FindFirstChild("Sounds") or workspace
                    })

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
