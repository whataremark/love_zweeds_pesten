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
    -- Verplaats kaart naar pot
    game.play_card(playerIndex, kaart, pot)

    print("[SPELER " .. playerIndex .. "] Speelt kaart:", kaart.waarde)

    -- Reset altijd eerst flags (fallback)
    game.extraTurn = false
    game.lastCardWas10 = false
    game.nextMustBeUnder7 = false

    -- === Effecten ===
    if kaart.waarde == "10" then
        utils.transfer_all_cards({}, pot) -- pot leegmaken
        game.lastCardWas10 = true
        game.extraTurn = true
        print("[RULES] Kaart is 10 dus Pot leeg en extra beurt")
    elseif kaart.waarde == "8" then
        game.extraTurn = true
        print("[RULES] Kaart is 8 dus Extra beurt")
    elseif kaart.waarde == "7" then
        game.nextMustBeUnder7 = true
        print("[RULES] Kaart is 7 → Volgende kaart moet lager dan 7")
    else
        print("[RULES] Geen speciaal effect")
    end

    print("[STATUS] extraTurn:", game.extraTurn)
    print("[STATUS] nextMustBeUnder7:", game.nextMustBeUnder7)
    print("")
    -- === Volgende beurt ===

    -- AI timer klaarzetten indien nodig
    if game.extraTurn and playerIndex == 2 then
        game.waitingForAI = true
        game.aiTimer = 0.5
    end

    -- Volgende beurt starten als er geen extra beurt is
    if not game.extraTurn then
        game.next_turn()
    end
end
return rules
