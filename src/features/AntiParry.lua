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

    -- Helper to safely resolve a character from any descendant part (handles accessories)
    local function GetCharacterFromPart(Part)
        if not Part then return nil end
        local Player = Players:GetPlayerFromCharacter(Part.Parent)
        if Player then return Part.Parent end
        
        local DoubleParent = Part.Parent and Part.Parent.Parent
        if DoubleParent and Players:GetPlayerFromCharacter(DoubleParent) then
            return DoubleParent
        end
        return nil
    end

    -- Hook outgoing game events to block damage sent to parrying opponents
    Vortex.Hook(
        "@Network",
        "FireServer",
        "Anti-Hit",
        function(Original, Method, ...)
            if getgenv().AntiParry and Method == "MeleeDamage" then
                local Args = {...} 
                local TargetPart = Args[2] 
                local Character = GetCharacterFromPart(TargetPart)

                if Character and getgenv().RecentParryPlayers[Character.Name] then
                    -- Dynamically passes the suppressed player's name into the toast
                    local storeObj = Vortex.Get("RoduxStore")
                    if storeObj then
                        local Message = ("Suppressed %s"):format(Character.Name)
                        Vortex.Call("@ToastNotificationActionsClient", "add", "success", Message, 5, true, { BypassHook = false })(storeObj.store)
                    end
                    
                    Vortex.Call("@SoundHandler", "playSound", {
                        soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
                        parent = workspace:FindFirstChild("Sounds") or workspace
                    })
                    
                    return
                end
            end

            return Original(Method, ...)
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
                local Character = GetCharacterFromPart(Data.parent)
                
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
