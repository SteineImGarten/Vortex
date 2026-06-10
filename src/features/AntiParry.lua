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

    -- Dynamic function to climb up the hierarchy until it finds a Model containing a Humanoid
    local function FindCharacterFromInstance(Obj)
        local Current = Obj
        while Current and Current ~= workspace and Current ~= game do
            if Current:IsA("Model") and Current:FindFirstChildOfClass("Humanoid") then
                return Current
            end
            Current = Current.Parent
        end
        return nil
    end

    -- Hook outgoing game events to block damage sent to parrying opponents
    Vortex.Hook(
        "@Network",
        "FireServer",
        "Anti-Hit",
        function(Original, ...)
            local Args = {...}

            if getgenv().AntiParry and Args[2] == "MeleeDamage" then
                local TargetPart = Args[4]
                local PlayerModel = TargetPart and TargetPart.Parent

                if PlayerModel and getgenv().RecentParryPlayers[PlayerModel] then
                    -- Rodux Toast Notification with the actual name of the suppressed player
                    local storeObj = Vortex.Get("RoduxStore")
                    if storeObj then
                        local Message = ("Suppressed %s"):format(PlayerModel.Name)
                        Vortex.Call("@ToastNotificationActionsClient", "add", "success", Message, 5, true, { BypassHook = false })(storeObj.store)
                    end
                    
                    Vortex.Call("@SoundHandler", "playSound", {
                        soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
                        parent = workspace:FindFirstChild("Sounds") or workspace
                    })
                    return
                end
            end

            return Original(table.unpack(Args))
        end,
        { Spy = false }
    )

    -- Hook sound cues to identify target parry triggers
    Vortex.Hook(
        "@SoundHandler",
        "playSound",
        "Anti-Parry",
        function(Original, ...)
            local Args = {...}
            local Data = Args[1]

            if getgenv().AntiParry and Data and Data.soundObject and Data.soundObject.Name == "Parry" then
                local Sound = Data.soundObject
                
                -- Dynamic lookup: looks upward through parents until it finds the character model
                local PlayerModel = Data.parent and FindCharacterFromInstance(Data.parent)

                if Sound and PlayerModel and PlayerModel ~= LocalPlayer.Character then
                    -- Record target parry window state using the instance object as the key
                    getgenv().RecentParryPlayers[PlayerModel] = true

                    -- Reset parry window block state after 200ms
                    task.delay(0.2, function()
                        getgenv().RecentParryPlayers[PlayerModel] = nil
                    end)
                end
            end

            return Original(...)
        end,
        { Spy = false }
    )
end

return AntiParry
