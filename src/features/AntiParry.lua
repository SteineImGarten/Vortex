--[[
    Combat Warriors - Anti-Parry (Max Speed Optimized)
    Suppresses attack events directed at players who have active parry states.
]]

local AntiParry = {}

function AntiParry.Init(Vortex)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer
    local task_delay = task.delay
    local getgenv = getgenv

    -- Global cache of player character models currently parrying
    getgenv().RecentParryPlayers = getgenv().RecentParryPlayers or {}

    -- Extrem schneller, interner Lua-Cache für alle gegnerischen Charaktere
    local EnemyCharacters = {}

    local function addCharacter(player, character)
        if player ~= LocalPlayer then
            EnemyCharacters[character] = true
        end
    end

    local function removeCharacter(character)
        EnemyCharacters[character] = nil
        getgenv().RecentParryPlayers[character] = nil
    end

    local function monitorPlayer(player)
        if player.Character then addCharacter(player, player.Character) end
        player.CharacterAdded:Connect(function(char) addCharacter(player, char) end)
        player.CharacterRemoving:Connect(removeCharacter)
    end

    -- Bestehende Spieler indizieren
    for _, player in ipairs(Players:GetPlayers()) do
        monitorPlayer(player)
    end
    Players.PlayerAdded:Connect(monitorPlayer)
    Players.PlayerRemoving:Connect(function(player)
        if player.Character then removeCharacter(player.Character) end
    end)

    -- Hook outgoing game events to block damage sent to parrying opponents
    Vortex.Hook(
        "@Network",
        "FireServer",
        "Anti-Hit",
        function(Original, ...)
            local Args = {...}
            local genv = getgenv()

            if genv.AntiParry and Args[2] == "MeleeDamage" then
                local Current = Args[4] -- TargetPart
                local PlayerModel = nil

                -- Findet das Character-Model blitzschnell im Cache, egal wie tief das TargetPart liegt
                while Current do
                    if EnemyCharacters[Current] then
                        PlayerModel = Current
                        break
                    end
                    Current = Current.Parent
                end

                if PlayerModel and genv.RecentParryPlayers[PlayerModel] then
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
            local genv = getgenv()

            if genv.AntiParry and Data and Data.soundObject and Data.soundObject.Name == "Parry" then
                local Current = Data.parent
                local PlayerModel = nil

                -- Findet das Character-Model blitzschnell im Cache, egal wo der Sound abgespielt wird
                while Current do
                    if EnemyCharacters[Current] then
                        PlayerModel = Current
                        break
                    end
                    Current = Current.Parent
                end

                if PlayerModel then
                    local Recent = genv.RecentParryPlayers
                    Recent[PlayerModel] = true

                    task_delay(0.2, function()
                        Recent[PlayerModel] = nil
                    end)
                end
            end

            return Original(...)
        end,
        { Spy = false }
    )
end

return AntiParry
