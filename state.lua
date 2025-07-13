-- state.lua  – simpele dispatcher (±25 regels)
local state = { current = nil }

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
    "update", "draw", "keypressed", "mousepressed",
    "mousereleased", "wheelmoved",          -- ← al aanwezig
    "textinput"                             -- ← nieuw, één woord erbij
} do
    state[cb] = function(...)
        if state.current and state.current[cb] then
            state.current[cb](...)
        end
    end
end

return state
