-- Game rule helper functions
local rules = {}
local utils = require("utils")

function rules.is_speelbaar(kaart, pot, onderZevenGedwongen)
    if not kaart then return false end

    local bovenste = pot[#pot]
    if not bovenste then return true end -- lege pot → altijd toegestaan

    local waarde = utils.numeric_value(kaart.waarde)
    local bovensteWaarde = utils.numeric_value(bovenste.waarde)

    -- Speciale kaarten mogen altijd
    if kaart.waarde == "2" or kaart.waarde == "3" or kaart.waarde == "10" then
        return true
    end

    -- 7 mag alleen als bovenste kaart 7 of lager is
    if kaart.waarde == "7" then
        return bovensteWaarde and bovensteWaarde <= 7
    end

    -- Als vorige kaart een 7 was: dan moet <= 7
    if onderZevenGedwongen then
        return waarde and waarde <= 7
    end

    -- Normale regel: >= vorige kaart
    return waarde and bovensteWaarde and waarde >= bovensteWaarde
    
end

-- Resolve the effect of a played card and advance the game state
function rules.handle_card_effects(game, playerIndex, kaart, pot)
    -- Move the card from the hand to the pot first
    game.play_card(playerIndex, kaart, pot)

    -- 10 clears the discard pile and grants another turn
    if kaart.waarde == "10" then
        utils.transfer_all_cards({}, pot) -- simply clear pot
        game.lastCardWas10 = true
        game.extraTurn = true
        if playerIndex == 2 then
            game.waitingForAI = true
            game.aiTimer = 0.5
        end
        return
    end

    -- 8 gives the player an extra turn
    if kaart.waarde == "8" then
        game.extraTurn = true
        if playerIndex == 2 then
            game.waitingForAI = true
            game.aiTimer = 0.5
        end
        return
    end

    -- 7 enforces that the next card must be lower or equal to 7
    if kaart.waarde == "7" then
        game.nextMustBeUnder7 = true
    else
        game.nextMustBeUnder7 = false
    end

    game.next_turn()
end
return rules
