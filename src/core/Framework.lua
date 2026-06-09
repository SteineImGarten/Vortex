--[[
    Combat Warriors - Framework Adapter
    Registers Combat Warriors specific functions and metadata handlers as adapters on the universal Vortex framework.
]]

local Vortex = import("core/Vortex")
local HL = Vortex -- Since HookLoader functions are now directly on Vortex

local Players = game:GetService("Players")

local UtilityIds = {}
local WeaponIds = {}
local WeaponOrder = {}
local AllItemsDefault = {}

-- Retrieve metadata for weapons and utilities
local function ItemData(ItemName, ItemId)
    local Key = ItemName and ItemName:lower():gsub("%s+", "")
    if Key and not WeaponIds[Key] and not UtilityIds[Key] then return end

    if Key and WeaponIds[Key] then
        return HL.Get("WeaponMetadata")[WeaponIds[Key]]
    elseif Key and UtilityIds[Key] then
        return HL.Get("UtilityMetadata")[UtilityIds[Key]]
    else
        return HL.Get("WeaponMetadata")[ItemId] or HL.Get("UtilityMetadata")[ItemId]
    end
end

-- Asynchronously wait and pre-load items lists
task.spawn(function()
    repeat task.wait(0.05) until getgenv().LOAD_FINISHED

    -- Populate IDs from HookLoader's cached game objects
    local utilIds = HL.Get("UtilityIds")
    if utilIds then
        for Key, Value in pairs(utilIds) do
            UtilityIds[Key:lower()] = Value
        end
    end

    local weaponIds = HL.Get("WeaponIds")
    if weaponIds then
        for Key, Value in pairs(weaponIds) do
            WeaponIds[Key:lower()] = Value
        end
    end

    local weaponsInOrder = HL.Get("WeaponsInOrder")
    if weaponsInOrder then
        for _, v in pairs(weaponsInOrder) do
            WeaponOrder[v.id] = v
        end
    end

    local weaponMeta = HL.Get("WeaponMetadata")
    if weaponMeta then
        for Key, Id in pairs(WeaponIds) do
            local Meta = weaponMeta[Id]
            if Meta then
                table.insert(AllItemsDefault, { Name = Key, OG = table.clone(Meta) })
            end
        end
    end

    local utilMeta = HL.Get("UtilityMetadata")
    if utilMeta then
        for Key, Id in pairs(UtilityIds) do
            local Meta = utilMeta[Id]
            if Meta then
                table.insert(AllItemsDefault, { Name = Key, OG = table.clone(Meta) })
            end
        end
    end
end)

local function NormalizeKey(str)
    return str:lower():gsub("%s+", "")
end

local function WaitForItems()
    repeat task.wait(0.05) until #AllItemsDefault > 0
end

-- Get character's currently equipped melee tool and object reference
local function MeleeWeapon(Player)
    Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    for _, Tool in ipairs(Character:GetChildren()) do
        if Tool:IsA("Tool") and Tool:GetAttribute("ItemType") == "weapon" then
            local itemId = Tool:GetAttribute("ItemId")
            local weaponMeta = HL.Get("WeaponMetadata")
            local meta = weaponMeta and weaponMeta[itemId]
            if meta and meta.class:lower():match("melee") then
                local clientObj = HL.Get("MeleeWeaponClient")
                return Tool, clientObj and clientObj.getObj(Tool)
            end
        end
    end
end

-- Get character's currently equipped ranged tool and object reference
local function RangedWeapon(Player)
    Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    for _, Tool in ipairs(Character:GetChildren()) do
        if Tool:IsA("Tool") and Tool:GetAttribute("ItemType") == "weapon" then
            local itemId = Tool:GetAttribute("ItemId")
            local weaponMeta = HL.Get("WeaponMetadata")
            local meta = weaponMeta and weaponMeta[itemId]
            if meta and meta.class:lower():match("ranged") then
                local clientObj = HL.Get("RangedWeaponClient")
                return Tool, clientObj and clientObj.getObj(Tool)
            end
        end
    end
end

-- Modify range properties across all default items
local function ModRanged(Name, Value)
    for _, v in ipairs(AllItemsDefault) do
        local Meta = ItemData(v.Name)
        if Meta and Meta[Name] then
            Meta[Name] = Value
        end
    end
end

-- Utility printer for nested tables
local function PrintTable(tbl, indent)
    indent = indent or ""
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            print(indent .. tostring(key) .. " :")
            PrintTable(value, indent .. "  ")
        else
            print(indent .. tostring(key) .. " : " .. tostring(value))
        end
    end
end

-- Display properties of currently equipped weapon in log console
local function PrintWepStats(Player)
    WaitForItems()

    Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    local Tool
    for _, item in ipairs(Character:GetChildren()) do
        if item:IsA("Tool") and item:GetAttribute("ItemType") == "weapon" then
            Tool = item
            break
        end
    end

    if not Tool then
        warn("[Framework] No weapon equipped!")
        return
    end

    local WeaponKey = NormalizeKey(Tool.Name)
    print("[Framework] Stats for currently held weapon: " .. Tool.Name)

    for _, item in ipairs(AllItemsDefault) do
        if NormalizeKey(item.Name) == WeaponKey then
            PrintTable(item.OG, "  ")
            return
        end
    end

    warn("[Framework] Weapon stats not found in AllItemsDefault: " .. Tool.Name)
end

-- Get state from Rodux Store
local function PlayerState()
    local storeObj = HL.Get("RoduxStore")
    return storeObj and storeObj.store:getState()
end

-- Get player session data
local function SessionData(Player)
    Player = Player or Players.LocalPlayer
    local dataHandler = HL.Get("DataHandler")
    return dataHandler and dataHandler.getSessionDataRoduxStoreForPlayer(Player)
end

-- Register Adapters on Vortex
Vortex.RegisterAdapter("GetMeleeWeapon", MeleeWeapon)
Vortex.RegisterAdapter("GetRangedWeapon", RangedWeapon)
Vortex.RegisterAdapter("GetPlayerState", PlayerState)
Vortex.RegisterAdapter("GetSessionData", SessionData)
Vortex.RegisterAdapter("GetItemData", ItemData)
Vortex.RegisterAdapter("ModRanged", ModRanged)
Vortex.RegisterAdapter("PrintWepStats", PrintWepStats)

return Vortex
