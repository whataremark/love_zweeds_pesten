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
game.extraTurn = false


--helper functie om de bovenste kaart in de pot te vinden
local function get_effective_top_card(pot)
    for i = #pot, 1, -1 do
        if pot[i].waarde ~= "3" then
            return pot[i]
        end
    end
    return nil
end

local function get_numeric_value(waarde)
    local map = {
        ace = 14,
        king = 13,
        queen = 12,
        jack = 11
    }
    return tonumber(waarde) or map[waarde] or -1
end

function game.play_card(playerIndex, kaart, pot)
    table.insert(pot, kaart)
    local hand = game.players[playerIndex].hand
    for i = 1, #hand do
        local k = hand[i]
        if k.waarde == kaart.waarde and k.kleur == kaart.kleur then
            table.remove(hand, i)
            return
        end
    end
end

function game.next_turn()
    game.currentPlayer = (game.currentPlayer % #game.players) + 1
    --game.nextMustBeUnder7 = false

    if game.mode == "ai" and game.currentPlayer == 2 then
        game.waitingForAI = true
        game.aiTimer = 0.5
    end
end



---CARD EFFECTS---
function game.handle_card_effects(playerIndex, kaart, pot)
    game.play_card(playerIndex, kaart, pot)

    if kaart.waarde == "10" then
        print("Kaart was 10 → pot volledig wissen")
        for i = #pot, 1, -1 do
            table.remove(pot, i)
        end
        game.lastCardWas10 = true
        if playerIndex == 2 then
            game.waitingForAI = true
            game.aiTimer = 0.5
        end
        return
    end

    if kaart.waarde == "8" then
        print("Kaart was 8 → speler mag nog een keer")
        if playerIndex == 2 then
            game.waitingForAI = true
            game.aiTimer = 0.5
        end
        return
    end

    if kaart.waarde == "7" then
        game.nextMustBeUnder7 = true
    else
        game.nextMustBeUnder7 = false
    end
    game.next_turn()
end



---AI SHIT----

function game.ai_turn(pot)
    local ai = game.players[2]
    print("\n=== AI-TURN ===")
    print("AI-hand (" .. #ai.hand .. " kaarten):")
    for i, c in ipairs(ai.hand) do
        print(string.format("  [%d] %s of %s", i, c.waarde, c.kleur))
    end

    local topCard = get_effective_top_card(pot)
    local topValue = topCard and get_numeric_value(topCard.waarde) or 0
    print("Bovenste (effectieve dus met 3 meegedacht) kaart in pot: " .. (topCard and (topCard.waarde .. " of " .. topCard.kleur) or "∅"))

    local legal = {}
    for _, card in ipairs(ai.hand) do
        local v = get_numeric_value(card.waarde)
        local special = card.waarde == "2" or card.waarde == "3" or card.waarde == "10"
       if special or not topCard or (game.nextMustBeUnder7 and v <= topValue) or (not game.nextMustBeUnder7 and v >= topValue) then
            table.insert(legal, card)
        end
    end

    if #legal == 0 then
        print("AI kan niets spelen → pakt pot op (" .. #pot .. " kaarten)")
        for i = #pot, 1, -1 do
            table.insert(ai.hand, table.remove(pot, i))
        end
        print("AI heeft nu " .. #ai.hand .. " kaarten na oppakken")
        game.next_turn()
        return
    end

    table.sort(legal, function(a, b)
        local prio = {["2"] = 1, ["3"] = 1, ["10"] = 1}
        local pa = prio[a.waarde] or 2
        local pb = prio[b.waarde] or 2
        if pa ~= pb then return pa < pb end
        return get_numeric_value(a.waarde) < get_numeric_value(b.waarde)
    end)

    local choice = legal[1]
    print("AI speelt: " .. choice.waarde .. " of " .. choice.kleur)
    game.handle_card_effects(2, choice, pot)
end

function game.update(dt, pot)
    if game.mode == "ai" and game.waitingForAI then
        game.aiTimer = game.aiTimer - dt
        if game.aiTimer <= 0 then
            game.waitingForAI = false
            game.ai_turn(pot)
        end
    end
end

return game
