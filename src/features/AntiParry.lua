--[[
    Combat Warriors - Anti-Parry
    Suppresses attack events directed at players who have active parry states (detected via parry sounds).
]]

local AntiParry = {}

function AntiParry.Init(Vortex)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer

    getgenv().RecentParryPlayers = getgenv().RecentParryPlayers or {}

    -- Bulletproof way to find the character model by climbing up the instance tree
    local function GetCharacter(Obj)
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
                local Character = GetCharacter(TargetPart)

                if Character and getgenv().RecentParryPlayers[Character.Name] then
                    local storeObj = Vortex.Get("RoduxStore")
                    if storeObj then
                        local Message = ("Suppressed %s"):format(Character.Name)
                        Vortex.Call("@ToastNotificationActionsClient", "add", "success", Message, 5, true, { BypassHook = false })(storeObj.store)
                    end
                    
                    Vortex.Call("@SoundHandler", "playSound", {
                        soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
                        parent = workspace:FindFirstChild("Sounds") or workspace
                    })
                    
                    return -- Drop the remote call entirely
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
        function(Original, ...)
            local Args = {...}
            local Data = Args[1]

            if getgenv().AntiParry and Data and Data.soundObject and Data.soundObject.Name == "Parry" then
                -- Dynamically resolve character from sound positioning asset parent
                local Character = GetCharacter(Data.parent)
                
                if Character and Character ~= LocalPlayer.Character then
                    local TargetName = Character.Name
                    getgenv().RecentParryPlayers[TargetName] = true

                    task.delay(0.2, function()
                        getgenv().RecentParryPlayers[TargetName] = nil
                    end)
                end
            end

            return Original(...)
        end,
        { Spy = false }
    )
end

return AntiParry
