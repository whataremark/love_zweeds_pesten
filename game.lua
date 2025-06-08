-- Core game state without any AI logic. The AI behaviour lives in ai.lua.
local game = {}
local utils = require("utils")

-- default mode is against the AI
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




function game.play_card(playerIndex, kaart, pot)
    -- Move the card from a player's hand to the discard pile
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
    -- Advance to the next player and notify the AI when needed
    game.currentPlayer = (game.currentPlayer % #game.players) + 1

    if game.mode == "ai" and game.currentPlayer == 2 then
        game.waitingForAI = true
        game.aiTimer = 0.5
    end
end



---CARD EFFECTS---
function game.handle_card_effects(playerIndex, kaart, pot)
    -- Apply card to the pile and resolve any special effects
    game.play_card(playerIndex, kaart, pot)

    if kaart.waarde == "10" then
        print("Kaart was 10 → pot volledig wissen")
        for i = #pot, 1, -1 do
            table.remove(pot, i)
        end
        game.lastCardWas10 = true
        game.extraTurn = true
        if playerIndex == 2 then
            game.waitingForAI = true
            game.aiTimer = 0.5
        end
        return
    end

    if kaart.waarde == "8" then
        print("Kaart was 8 → speler mag nog een keer")
        game.extraTurn = true
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

-- Expose the game state for other modules
return game
