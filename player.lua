--informatie over spelers en kaartselectie
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

-- tel hoeveel kaarten momenteel geselecteerd zijn
function player.count_selected(hand)
    local c = 0
    for _,k in ipairs(hand) do
        if k.selected then c = c + 1 end
    end
    return c
end

-- Toggle de selectie van een kaart uit de hand
function player.toggle_select(hand, index)
    local kaart = hand[index]
    if not kaart then return end
    if kaart.selected then
        kaart.selected = false
    else
        if player.count_selected(hand) < 3 then
            kaart.selected = true
        end
    end
end

return player

