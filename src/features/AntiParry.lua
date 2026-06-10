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
            -- Match your original exact parameter indexing via select()
            if getgenv().AntiParry and select(2, ...) == "MeleeDamage" then
                local TargetPart = select(4, ...)
                local PlayerModel = TargetPart and TargetPart.Parent

                if PlayerModel then
                    -- If they are already parrying, drop the hit instantly
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
                        return -- Drop the call
                    end

                    -- Pack the tuple so it can be safely deferred inside the task thread
                    local PackedArgs = table.pack(...)

                    -- Defer the event fire execution by 100ms
                    task.delay(0.1, function()
                        -- Re-verify their parry state after the 100ms window has completed
                        if getgenv().AntiParry and getgenv().RecentParryPlayers[PlayerModel] then
                            local storeObj = Vortex.Get("RoduxStore")
                            if storeObj then
                                local Message = ("Late Suppression on %s"):format(PlayerModel.Name)
                                Vortex.Call("@ToastNotificationActionsClient", "add", "success", Message, 5, true, { BypassHook = false })(storeObj.store)
                            end
                            return -- Block the delayed hit from firing
                        end
                        
                        -- Fire the original remote function with all original arguments intact
                        Original(table.unpack(PackedArgs, 1, PackedArgs.n))
                    end)

                    return -- Intercept and prevent the immediate default execution loop
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
