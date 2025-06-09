--codex-- Core game state without any AI logic. Card effects are handled in rules.lua
local game = {}
local utils    = require("utils")
local drawPile = require("drawpile")
local player = require("player")

-- default mode is against the AI
game.mode = "ai"

game.players = {
    { hand = {}, faceUp = {}, faceDown = {} }, -- Speler 1 (jij)
    { hand = {}, faceUp = {}, faceDown = {} }  -- Speler 2 (AI)
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
game.winner = nil

game.phase = "setup" -- setup: spelers kiezen open kaarten


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
    game.phase = "setup"

    -- setup player 1
    game.players[1].hand = player.hand
    game.players[1].faceDown = {}
    game.players[1].faceUp = {}
    for i = 1, 3 do
        table.insert(game.players[1].faceDown, drawPile.draw())
    end

    -- setup AI player
    game.players[2].hand = {}
    game.players[2].faceDown = {}
    game.players[2].faceUp = {}
    for i = 1, 6 do
        table.insert(game.players[2].hand, drawPile.draw())
    end
    for i = 1, 3 do
        table.insert(game.players[2].faceDown, drawPile.draw())
    end
    table.sort(game.players[2].hand, function(a,b)
        return utils.numeric_value(a.waarde) > utils.numeric_value(b.waarde)
    end)
    for i = 1, 3 do
        table.insert(game.players[2].faceUp, table.remove(game.players[2].hand,1))
    end

    utils.refill_hand(game.players[2].hand, drawPile)
end

function game.finish_setup()
    utils.refill_hand(game.players[1].hand, drawPile)
    game.phase = "playing"

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

function game.check_special_piles(index)
    local p = game.players[index]
    if #p.hand == 0 and drawPile.count() == 0 then
        if #p.faceUp > 0 then
            table.insert(p.hand, table.remove(p.faceUp, 1))
        elseif #p.faceDown > 0 then
            table.insert(p.hand, table.remove(p.faceDown, 1))
        end
    end
end

function game.next_turn()
    -- Advance to the next player and notify the AI when needed
    game.currentPlayer = (game.currentPlayer % #game.players) + 1
    game.check_special_piles(game.currentPlayer)

    if game.mode == "ai" and game.currentPlayer == 2 then
        game.waitingForAI = true
        game.aiTimer = 0.5
    end
end

function game.is_winner(index)
    local p = game.players[index]
    return #p.hand == 0 and #(p.faceUp or {}) == 0 and #(p.faceDown or {}) == 0
end


-- Expose the game state for other modules
return game

