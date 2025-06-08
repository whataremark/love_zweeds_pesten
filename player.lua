local player = {}

player.hand = {}
player.dragging = nil
player.draggingIndex = nil
player.dragOffset = { x = 0, y = 0 }

function player.init(deck)
    player.hand = {}
    for i = 1, 7 do
        table.insert(player.hand, deck.draw())
    end
end

function player.startDrag(x, y)
    local padding = 15
    local kaart_hoogte = 120
    local schaal = kaart_hoogte / 500 -- schatting voor alle kaarten
    local kaart_breedte = 300 * schaal
    local w = love.graphics.getWidth()
    local x_start = (w - (#player.hand * (kaart_breedte + padding))) / 2
    local y_start = love.graphics.getHeight() - kaart_hoogte - 50

    for i, kaart in ipairs(player.hand) do
        local cx = x_start + (i - 1) * (kaart_breedte + padding)
        local cy = y_start

        if x > cx and x < cx + kaart_breedte and y > cy and y < cy + kaart_hoogte then
            player.dragging = kaart
            player.draggingIndex = i
            player.dragOffset.x = x - cx
            player.dragOffset.y = y - cy
            table.remove(player.hand, i)
            break
        end
    end
end

function player.updateDragging()
    if not player.draggingCard then return end

    local mx, my = love.mouse.getPosition()
    player.draggingCard.x = mx - player.draggingCard.offsetX
    player.draggingCard.y = my - player.draggingCard.offsetY
end

function player.stopDrag()
    local kaart = player.dragging
    player.dragging = nil
    player.draggingIndex = nil
    return kaart
end

return player
