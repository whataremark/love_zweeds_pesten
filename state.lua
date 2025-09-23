-- state.lua  – simpele dispatcher (±25 regels)
local state = { current = nil }

local gameState = require("game")
local ui        = require("ui")

local unpack = table.unpack or unpack

local uiCallbacks = {
    mousepressed  = "mousepressed",
    mousereleased = "mousereleased",
    mousemoved    = "mousemoved",
    wheelmoved    = "wheelmoved",
    touchpressed  = "touchpressed",
    touchreleased = "touchreleased",
    touchmoved    = "touchmoved",
}

function state.enter(new_state, ...)
    if state.current and state.current.leave then
        state.current.leave()
    end
    state.current = new_state
    if state.current and state.current.load then
        state.current.load(...)
    end
end

-- Genereer dunne wrappers voor de belangrijkste Love-callbacks
for _, cb in ipairs{
    "update", "draw", "keypressed",
    "mousepressed", "mousereleased", "mousemoved",
    "wheelmoved",
    "touchpressed", "touchreleased", "touchmoved",
    "textinput",
} do
    state[cb] = function(...)
        if state.current and state.current[cb] then
            state.current[cb](...)
        end
        local uiName = uiCallbacks[cb]
        if uiName and state.current == gameState and ui[uiName] then
            local args = { ... }
            table.insert(args, gameState.uiState)
            ui[uiName](unpack(args))
        end
    end
end

return state
