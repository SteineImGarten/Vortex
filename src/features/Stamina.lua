--[[
    Combat Warriors - Stamina Boost
    Queries local character stamina parameters and configures faster regeneration scaling.
]]

local Stamina = {}

function Stamina.Init(FrameWork)
    -- Retrieve default stamina handler using simplified framework call method
    local DefaultStamina = FrameWork.Call("@DefaultStaminaHandlerClient", "getDefaultStamina")
    if not DefaultStamina then
        warn("[Stamina] DefaultStamina handler instance not found!")
        return
    end

    -- Boost Base Max Stamina & set current stamina level
    FrameWork.Call("@Stamina", "setBaseMaxStamina", DefaultStamina, 150)
    FrameWork.Call("@Stamina", "setStamina", DefaultStamina, 1)

    -- Configure gain delay and rates
    print(("[Stamina] Initial Gain Delay: %s | Gain Rate: %s"):format(tostring(DefaultStamina.gainDelay), tostring(DefaultStamina.gainPerSecond)))
    
    DefaultStamina.gainDelay = 0.25
    DefaultStamina.gainPerSecond = 35
    
    print(("[Stamina] Modified Gain Delay: %s | Gain Rate: %s"):format(tostring(DefaultStamina.gainDelay), tostring(DefaultStamina.gainPerSecond)))
end

return Stamina
