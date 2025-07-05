--informatie over spelers en kaartselectie
local player = {}
local rules = require("rules")
local config = require("config")


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
    -- velden aanmaken
    for i = 1, 2 do
        player.players[i].hand     = {}
        player.players[i].faceUp   = {}
        player.players[i].faceDown = {}
    end

    -- hand-kaarten
    for i = 1, config.HAND_SIZE do
        table.insert(player.players[1].hand, deck.draw())
        table.insert(player.players[2].hand, deck.draw())
    end

    -- blinde kaarten
    for i = 1, config.BLIND_SIZE do
        table.insert(player.players[1].faceDown, deck.draw())
        table.insert(player.players[2].faceDown, deck.draw())
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

