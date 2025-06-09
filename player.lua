-- Utility for the human player's hand and drag state
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

function player.startDrag(x, y)
    local padding = 15
    local kaartHoogte = 160
    local schaal = kaartHoogte / 500
    local kaartBreedte = 300 * schaal

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

function player.updateDragging()
    -- geen xy-opslag nodig; UI berekent dat live
end

function player.stopDrag()
    local kaart = player.draggingCard
    player.draggingCard = nil
    return kaart
end

return player
