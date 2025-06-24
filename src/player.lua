--informatie over spelers en kaartselectie
local player = {}
local rules = require("src.rules")

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

function player.toggle_select(hand, index, phase)
    local kaart = hand[index]
    if not kaart then return end

    -- Zorg dat we altijd een fase hebben: default = "playing"
    local p = phase or "playing"
    -- Debug print
    print(("toggle_select: fase=%s, kaart=%s"):format(p, kaart.waarde))

    -- Verzamel huidige selectie
    local selected = {}
    for _, k in ipairs(hand) do
        if k.selected then
            table.insert(selected, k)
        end
    end
    print("  reeds geselecteerd:", #selected)

    if kaart.selected then
        kaart.selected = false
        print("  → deselect", kaart.waarde)
    else
        if p == "selectFaceUp" then
            if #selected < 3 then
                kaart.selected = true
                print("  → select (blind)", kaart.waarde)
            end

        else  -- speel-fase
            if #selected == 0 then
                kaart.selected = true
                print("  → select eerste kaart", kaart.waarde)
            elseif rules.can_select_for_play(selected, kaart) then
                kaart.selected = true
                print("  → select extra gelijkwaardige kaart", kaart.waarde)
            else
                print("  → mag niet selecteren:", kaart.waarde)
            end
        end
    end
end

return player

