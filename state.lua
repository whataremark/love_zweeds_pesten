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
    "update", "draw", "keypressed",
    "mousepressed", "mousereleased", "wheelmoved",
    "textinput",
} do
    state[cb] = function(...)
        if state.current and state.current[cb] then
            state.current[cb](...)
        end
    end
end


function state.touchpressed(id, x, y, pressure)
  local s = state.current
  if s and s.touchpressed then s.touchpressed(id, x, y, pressure) end
end

function state.touchmoved(id, x, y, dx, dy, pressure)
  local s = state.current
  if s and s.touchmoved then s.touchmoved(id, x, y, dx, dy, pressure) end
end

function state.touchreleased(id, x, y, pressure)
  local s = state.current
  if s and s.touchreleased then s.touchreleased(id, x, y, pressure) end
end

return state
