--codex-- Core game state without any AI logic. Card effects are handled in rules.lua
local game = {}
local utils    = require("utils")
local drawPile = require("drawpile")
local player = require("player")

-- default mode is against the AI
game.mode = "ai"

game.players = {
    { hand = {} }, -- Speler 1 (jij)
    { hand = {} }  -- Speler 2 (AI)
}

--codex-- Central discard pile and number of full decks used
game.pot = {}
game.deckCount = 1 --codex-- Selected number of decks to use

game.currentPlayer = 1
game.ronde = 0
game.aiTimer = 0
game.waitingForAI = false
game.nextMustBeUnder7 = false
game.extraTurn = false

--codex-- Initialize a new round with a chosen play mode
function game.start(mode)
    drawPile.init(game.deckCount)
    player.init(drawPile)

    game.mode = mode or "ai"
    game.currentPlayer = 1
    game.waitingForAI = false
    game.nextMustBeUnder7 = false
    game.extraTurn = false

    game.pot = { drawPile.draw() }
    game.ronde = 0

    game.players[1].hand = player.hand
    game.players[2].hand = {}
    for i = 1, 5 do
        table.insert(game.players[2].hand, drawPile.draw())
    end
end




--codex-- Move a card from a player's hand onto the pile
function game.play_card(playerIndex, kaart)
    table.insert(game.pot, kaart)
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


-- Expose the game state for other modules
return game

