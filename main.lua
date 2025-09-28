-- main.lua  – dunne router tussen Love2D en de actieve state
local state = require("state")
local menu  = require("menu")

function love.load()
    state.enter(menu)          -- start in het hoofdmenu
end

function love.update(dt)        state.update(dt)        end
function love.draw()            state.draw()            end
function love.keypressed(...)   state.keypressed(...)   end
function love.mousepressed(...) state.mousepressed(...) end
function love.wheelmoved(...)   state.wheelmoved(...)   end

function love.touchpressed(id, x, y, pressure)
  state.touchpressed(id, x, y, pressure)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
  state.touchmoved(id, x, y, dx, dy, pressure)
end

function love.touchreleased(id, x, y, pressure)
  state.touchreleased(id, x, y, pressure)
end



function love.textinput(text)
    state.textinput(text)
end
