--codex-- Core game state without any AI logic. Card effects are handled in rules.lua
local game = {}
local utils    = require("utils")
local drawPile = require("drawpile")
local player = require("player")
local config = require("config")
local net    = require("net")

-- default mode is against the AI
game.mode = "ai"

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

game.reveal = {
    timer = 0,
    player = nil,
    card = nil
}

--------------------------------------------------------------------
-- Hulp: bepaal in welke fase speler i zit
--------------------------------------------------------------------
local function phase_for_player(i)
    return require("utils").phase_for_player(i)
end



--codex-- Initialize a new round with a chosen play mode
--------------------------------------------------------------------
-- game.start(mode) – start een nieuwe ronde
--------------------------------------------------------------------
function game.start(mode)
    --------------------------------------------------------------
    -- 0.  Config & trekstapel opbouwen
    --------------------------------------------------------------
    local config = require("config")         -- centrale constants
    drawPile.init(game.deckCount)            -- build / shuffle stapel

    --------------------------------------------------------------
    -- 1.  Spelers resetten + kaarten delen
    --------------------------------------------------------------
    player.init(drawPile)                    -- vult hand & faceDown
    -- player.init moet nu  HAND_SIZE  hand-kaarten
    -- en  BLIND_SIZE  faceDown-kaarten uitdelen aan beide spelers

    --------------------------------------------------------------
    -- 2.  Spelstatus resetten
    --------------------------------------------------------------
    if mode == "multiplayer-host" or mode == "multiplayer-client" then
        game.mode = "multiplayer"
    else
        game.mode = mode or "ai"
    end
    game.currentPlayer = 1
    game.waitingForAI  = false
    game.extraTurn     = false
    game.winner        = nil
    game.ronde         = 0

    -- we beginnen in de setup-fase (mens kiest open kaarten)
    game.state         = "setupSelectOpen"

    --------------------------------------------------------------
    -- 3.  Eerste kaart op de pot leggen
    --------------------------------------------------------------
    game.pot = { drawPile.draw() }

    -- 7-regel direct activeren?
    game.nextMustBeUnder7 = (game.pot[1].waarde == "7")
    if game.nextMustBeUnder7 then
        print("[GAME] Eerste kaart is een 7 → 7-regel actief")
    end

    print(string.format(
        "[GAME] Nieuwe ronde gestart: %d decks, hand=%d, blind=%d",
        game.deckCount, config.HAND_SIZE, config.BLIND_SIZE))

    if mode == "multiplayer-host" then
        net.set_game(game)
        net.send_state()
    elseif mode == "multiplayer-client" then
        net.set_game(game)
    end
end




--codex-- Move a card from a player's hand onto the pile
function game.play_card(playerIndex, kaart)
    table.insert(game.pot, kaart)
    local hand = player.players[playerIndex].hand
    for i = 1, #hand do
        local k = hand[i]
        if k.waarde == kaart.waarde and k.kleur == kaart.kleur then
            table.remove(hand, i)
            return
        end
    end
end

function game.next_turn()
    game.currentPlayer = (game.currentPlayer % #player.players) + 1
    game.state        = phase_for_player(game.currentPlayer)

    if game.mode == "ai" and game.currentPlayer == 2 then
        game.waitingForAI = true
        game.aiTimer      = 0.5
    else
        game.waitingForAI = false
        game.aiTimer      = 0
    end
    game.check_winner()
end   

function game.check_winner()
    local playerMod = require("player")

    for i, p in ipairs(playerMod.players) do
        if #p.hand == 0 and #p.faceUp == 0 and #p.faceDown == 0 then
            game.winner = i          -- sla winnaar op
            scene       = "einde"    -- of "end", wat je al gebruikt
            print("[GAME] Speler "..i.." wint!")
            return
        end
    end
end


-- Expose the game state for other modules
return game

