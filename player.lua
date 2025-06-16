--the human player's hand and drag state
local player = {}

--voor het scrollen van de hand
player.scrollOffset = 0  -- pixels

player.players = {
    {
        hand = {},
        faceUp = {},
        faceDown = {}
    },
    {
        hand = {},
        faceUp = {},
        faceDown = {}
    }
}

player.draggingCard = nil
player.dragOffset = { x = 0, y = 0 }

function player.init(deck)
    -- Speler 1
    player.players[1].hand = {}
    player.players[1].faceUp = {}
    player.players[1].faceDown = {}

    -- Speler 2
    player.players[2].hand = {}
    player.players[2].faceUp = {}
    player.players[2].faceDown = {}

    -- Kaarten uitdelen aan speler 1 (bijv. 5 handkaarten)
    for i = 1, 5 do
        table.insert(player.players[1].hand, deck.draw())
    end
end

--codex-- Begin dragging a card from the player's hand
function player.startDrag(x, y)
    local ui = require("ui")
    local positions = ui.get_card_positions(player.players[1].hand)

    for i, pos in ipairs(positions) do
        if x >= pos.x and x <= pos.x + pos.w and y >= pos.y and y <= pos.y + pos.h then
            local kaart = table.remove(player.players[1].hand, i)
            player.draggingCard = kaart
            player.dragOffset.x = x - pos.x
            player.dragOffset.y = y - pos.y
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

