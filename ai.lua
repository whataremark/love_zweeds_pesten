local utils = require("utils")
-- AI rules 
-- Functie om een kaartwaarde om te zetten naar een getal
-- wordt gebruikt om te bepalen of een kaart speelbaar is
local function get_heuristics(waarde)
    local map = {
        ["2"] = 11, ["3"] = 14, ["4"] = 1, ["5"] = 2,
        ["6"] = 3, ["7"] = 4, ["8"] = 5, ["9"] = 6,
        ["10"] = 13, ["jack"] = 8, ["queen"] = 9,
        ["king"] = 9, ["ace"] = 10
    }
    return map[waarde] or 0
end
-- Function for the AI's turn logic
function ai_turn(game,pot)

    -- assign player idx (AI is always player 2)
    local ai = game.players[2]

    -- Print AI's turn and hand
    print("\n=== AI-TURN ===")
    print("AI-hand (" .. #ai.hand .. " kaarten):")
    for i, c in ipairs(ai.hand) do
        print(string.format("  [%d] %s of %s", i, c.waarde, c.kleur))
    end

    -- Get the top card from the pot, considering special rules (e.g., 3's effect)
    local topCard = utils.get_effective_top_card(pot)
    local topValue = topCard and utils.get_numeric_value(topCard.waarde) or 0
    print("Bovenste (effectieve dus met 3 meegedacht) kaart in pot: " .. 
    (topCard and (topCard.waarde .. " of " .. topCard.kleur) or "∅"))

    -- Build a list of legal cards the AI can play
    local legal = {}
    for _, card in ipairs(ai.hand) do
        local v = utils.get_numeric_value(card.waarde)
        -- Special cards are always legal; otherwise, check game rules for legal moves
        local special = card.waarde == "2" or card.waarde == "3" or card.waarde == "10"
        if special or not topCard or (game.nextMustBeUnder7 and v <= topValue) or 
        (not game.nextMustBeUnder7 and v >= topValue) then
            table.insert(legal, card)
        end
    end

    -- If no legal cards, AI must pick up the pot
    if #legal == 0 then
        print("AI kan niets spelen → pakt pot op (" .. #pot .. " kaarten)")
        for i = #pot, 1, -1 do
            table.insert(ai.hand, table.remove(pot, i))
        end
        print("AI heeft nu " .. #ai.hand .. " kaarten na oppakken")
        game.next_turn()
        return
    end

    -- Sort legal cards: prioritize special cards (2, 3, 10), then by value
    table.sort(legal, function(a, b)
        -- local prio = {["2"] = 1, ["3"] = 1, ["10"] = 1}
        -- local pa = prio[a.waarde] or 2
        -- local pb = prio[b.waarde] or 2
        -- if pa ~= pb then return pa < pb end
        return get_heuristics(a.waarde) < get_heuristics(b.waarde)
    end)

    -- Choose the best card to play (first in sorted list)
    local choice = legal[1]
    print("AI speelt: " .. choice.waarde .. " of " .. choice.kleur)
    utils.handle_card_effects(game, 2, choice, pot)
end

return {
    ai_turn = ai_turn
}