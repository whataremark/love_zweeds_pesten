--codex-- Basic computer opponent behaviour
local utils = require("utils")
local rules = require("rules")
local drawPile = require("drawpile")
local ai = {}

--codex-- Determine the effective top card while skipping any '3' values
local function effective_top_card(pot)
    for i = #pot, 1, -1 do
        if pot[i].waarde ~= "3" then
            return pot[i]
        end
    end
    return nil
end

--codex-- Ranking used by the AI to choose between playable cards
local function get_heuristics(waarde)
    local map = {
        ["2"] = 11, ["3"] = 14, ["4"] = 1, ["5"] = 2,
        ["6"] = 3, ["7"] = 4, ["8"] = 5, ["9"] = 6,
        ["10"] = 13, ["jack"] = 8, ["queen"] = 9,
        ["king"] = 9, ["ace"] = 10
    }
    return map[waarde] or 0
end


-- Select the best playable card for the AI or nil when none is possible
--codex-- Pick the most attractive playable card from the AI hand
local function choose_card(game, pot)
    local hand = game.players[2].hand
    local top = effective_top_card(pot)
    local topValue = top and utils.numeric_value(top.waarde) or 0

    local legal = {}
    for _, card in ipairs(hand) do
        local v = utils.numeric_value(card.waarde)
        local special = card.waarde == "2" or card.waarde == "3" or card.waarde == "10"
        if special or not top or
           (game.nextMustBeUnder7 and v <= topValue) or
           (not game.nextMustBeUnder7 and v >= topValue) then
            table.insert(legal, card)
        end
    end

    if #legal == 0 then return nil end
    table.sort(legal, function(a, b)
        return get_heuristics(a.waarde) < get_heuristics(b.waarde)
    end)
    return legal[1]
end

-- Execute the AI's turn
-- ...existing code...

--codex-- Execute the AI's turn by choosing or picking up cards
function ai.play(game, pot)
    local choice = choose_card(game, pot)
    if not choice then
        if game.extraTurn then
            -- No card during an extra turn means pass
            game.extraTurn = false
            game.next_turn()
        else
            -- Pick up the pot when no card can be played
            utils.transfer_all_cards(game.players[2].hand, pot)
            -- Do NOT refill here!
            game.next_turn()
        end
        return
    end
    rules.handle_card_effects(game, 2, choice)
    utils.refill_hand(game.players[2].hand, drawPile) -- refill after a successful play
end

-- ...existing code...

-- Simple timer based update used to delay the AI's move
--codex-- Timer helper so the AI waits a bit before acting
function ai.update(dt, game, pot)
    if game.mode == "ai" and game.waitingForAI then
        game.aiTimer = game.aiTimer - dt
        if game.aiTimer <= 0 then
            game.waitingForAI = false
            ai.play(game, pot)
        end
    end
end

return ai
