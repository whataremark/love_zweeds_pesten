local game = {}
game.mode = "ai"

game.players = {
    { hand = {} }, -- Speler 1 (jij)
    { hand = {} }  -- Speler 2 (AI)
}

game.currentPlayer = 1
game.ronde = 0
game.aiTimer = 0
game.waitingForAI = false

game.nextMustBeUnder7 = false



function game.next_turn()
    game.currentPlayer = (game.currentPlayer % #game.players) + 1


    -- Reset 7-regel na beurtwissel
    game.nextMustBeUnder7 = false

    -- alleen AI-timer starten als we in AI-modus zitten
    if game.mode=="ai" and game.currentPlayer==2 then
        game.waitingForAI = true
        game.aiTimer      = 0.5
    end

end

function game.play_card(playerIndex, kaart, pot)
    table.insert(pot, kaart)
    local hand = game.players[playerIndex].hand
    for i, k in ipairs(hand) do
        if k == kaart then
            table.remove(hand, i)
            break
        end
    end
end

function get_numeric_value(waarde)
    local map = {
        ace = 14,
        king = 13,
        queen = 12,
        jack = 11
    }
    if tonumber(waarde) then
        return tonumber(waarde)
    else
        return map[waarde] or -1
    end
end


function game.ai_turn(pot)
    local ai = game.players[2]
    local bovenste = pot[#pot]
    local bovenste_waarde = bovenste and get_numeric_value(bovenste.waarde) or 0

    -- AI probeert eerste geldige kaart te spelen
    for _, kaart in ipairs(ai.hand) do
        local kaart_waarde = get_numeric_value(kaart.waarde)

        -- Speciale kaarten mogen altijd
        if kaart.waarde == "2" or kaart.waarde == "3" or kaart.waarde == "10" then
            game.play_card(2, kaart, pot)
            if kaart.waarde ~= "8" then
                game.next_turn()
            end

             if kaart.waarde == "7" then
                 game.nextMustBeUnder7 = true
        end

            if kaart.waarde == "10" then
            for i = #pot, 1, -1 do
                    table.remove(pot, i)
            -- AI mag nog een keer
            return
            end
            return
        end
    end

        -- Normale kaarten
        if kaart_waarde >= bovenste_waarde then
            game.play_card(2, kaart, pot)
            if kaart.waarde ~= "8" then
                game.next_turn()
            end
            return
        end
    end

    -- Geen geldige kaart → pak pot
    for _, kaart in ipairs(pot) do
        table.insert(ai.hand, kaart)
    end
    for i = #pot, 1, -1 do
        table.remove(pot, i)
    end

    game.next_turn()
end


function game.update(dt, pot)
    if game.mode=="ai" and game.waitingForAI then
        game.aiTimer = game.aiTimer - dt
        if game.aiTimer <= 0 then
            game.waitingForAI = false
            game.ai_turn(pot)
        end
    end
end

return game
