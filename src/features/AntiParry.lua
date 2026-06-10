--[[
    Combat Warriors - Anti-Parry
    Suppresses attack events directed at players who have active parry states (detected via parry sounds).
]]

local AntiParry = {}

function AntiParry.Init(Vortex)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- Global cache of player character models currently parrying
    getgenv().RecentParryPlayers = getgenv().RecentParryPlayers or {}

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
                    print(("[AntiParry] Suppressed hit registry on parrying target: %s"):format(PlayerModel.Name))
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
                local PlayerModel = Data.parent and Data.parent.Parent and Data.parent.Parent.Parent

                if Sound and PlayerModel and PlayerModel ~= LocalPlayer.Character then
                    -- Record target parry window state
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
