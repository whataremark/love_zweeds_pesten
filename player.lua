--codex-- Utility fo
 --the human player's hand and drag state
local player = {}

player.hand = {}
player.draggingCard = nil
player.dragOffset = { x = 0, y = 0 }

function player.init(deck)
    player.hand = {}
    for i = 1, 5 do
        table.insert(player.hand, deck.draw())
    end
end

--codex-- Begin dragging a card from the player's hand
function player.startDrag(x, y)
    local config = require("config")
    local padding = config.cardPadding
    local kaartHoogte = config.cardHeight
    local schaal = config.scale
    local kaartBreedte = config.cardWidth

    local w = love.graphics.getWidth()
    local x_start = (w - (#player.hand * (kaartBreedte + padding))) / 2
    local y_start = love.graphics.getHeight() - kaartHoogte - 50

    for i, kaart in ipairs(player.hand) do
        local cx = x_start + (i - 1) * (kaartBreedte + padding)
        local cy = y_start

        if x > cx and x < cx + kaartBreedte and y > cy and y < cy + kaartHoogte then
            player.draggingCard = kaart
            player.dragOffset.x = x - cx
            player.dragOffset.y = y - cy
            table.remove(player.hand, i)
            break
        end
    end
end

--codex-- Update drag offsets (UI queries mouse position directly)
function player.updateDragging()
    -- geen xy-opslag nodig; UI berekent dat live
end

--codex-- Finish dragging and return the selected card
function player.stopDrag()
    local kaart = player.draggingCard
    player.draggingCard = nil
    return kaart
end

return player

