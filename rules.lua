--codex-- Game rule helper functions
local rules = {}
local utils = require("utils")

--codex-- Check if a card can legally be played on the pile
function rules.is_speelbaar(kaart, pot, onderZevenGedwongen)
    if not kaart then return false end

    local bovenste = utils.effective_top_card(pot)
    if not bovenste then return true end -- lege pot → altijd toegestaan

    local waarde = utils.numeric_value(kaart.waarde)
    local bovensteWaarde = utils.numeric_value(bovenste.waarde)

    -- Speciale kaarten mogen altijd
    if kaart.waarde == "2" or kaart.waarde == "3" or kaart.waarde == "10" then
        return true
    end

    -- 7 mag alleen als bovenste kaart 7 of lager is ## dit is mischien onndodig bedenk ik me
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

--codex-- Resolve card effects and update turn state
function rules.handle_card_effects(game, playerIndex, kaart, advanceTurn)
    if advanceTurn == nil then advanceTurn = true end  -- default
    --codex-- Add the card to the pile then resolve its effect
    local hadExtraTurn = game.extraTurn
    game.play_card(playerIndex, kaart)

    -- 10 clears the discard pile and grants another turn
    if kaart.waarde == "10" then
        utils.transfer_all_cards({}, game.pot) -- simply clear pot
        game.lastCardWas10 = true
        game.extraTurn = true
        game.nextMustBeUnder7 = false
        if playerIndex == 2 then
            game.waitingForAI = true
            game.aiTimer = 0.5
        end
        game.check_winner()
        return
    end

    -- 8 gives the player an extra turn
    if kaart.waarde == "8" then
        game.extraTurn = true
        if playerIndex == 2 then
            game.waitingForAI = true
            game.aiTimer = 0.5
        end
        game.check_winner()
        return
    end

    -- 7 enforces that the next card must be lower or equal to 7
    if kaart.waarde == "7" then
        game.nextMustBeUnder7 = true
        print("[RULES] ZEVEN regel ACTIEF")
    elseif kaart.waarde ~= "3" then
        -- 3 is 'doorzichtig' en heft de 7-regel niet op
        print("[RULES] ZEVEN regel INACTIEF")
        game.nextMustBeUnder7 = false
    end
    -- Was er al een extra beurt actief? Dan is die nu opgebruikt,
    -- tenzij deze kaart wéér een 8 of 10 was.
    if game.extraTurn and kaart.waarde ~= "8" and kaart.waarde ~= "10" then
        game.extraTurn = false
    end 
  -- Verplaats beurt alleen als dat mag én we niet midden in een batch zitten
     if advanceTurn and not game.extraTurn then
        game.next_turn()
    end
    game.check_winner()
end


-- Bepaalt of je tijdens de normale speel-fase een kaart mag toevoegen
function rules.can_select_for_play(selectedCards, newCard)
    -- eerste kaart mag altijd
    if #selectedCards == 0 then
        return true
    end
    -- vergelijk numerieke waarden
    local eersteWaarde = utils.numeric_value(selectedCards[1].waarde)
    local nieuweWaarde = utils.numeric_value(newCard.waarde)
    return eersteWaarde == nieuweWaarde
end

function rules.play_selected_cards(game, playerIndex)
    local speler   = require("player").players[playerIndex]
    local selected = {}

    -- 1) Verzamelen en uit hand halen (backwards)
    for i = #speler.hand, 1, -1 do
        if speler.hand[i].selected then
            table.insert(selected, 1, table.remove(speler.hand, i))
        end
    end

    if #selected == 0 then
        print("Er zijn geen kaarten geselecteerd.")
        return false
    end

    -- 2) BRUNZYN (vier gelijke)
    if #selected == 4 then
        local eersteVal = utils.numeric_value(selected[1].waarde)
        -- Check of ze allemaal gelijk zijn
        for _, k in ipairs(selected) do
            if utils.numeric_value(k.waarde) ~= eersteVal then
                -- Niet allemaal gelijk: ongeldige zet
                for _, c in ipairs(selected) do table.insert(speler.hand, c) end
                return false
            end
        end
        -- Check speelbaarheid per kaart
        for _, k in ipairs(selected) do
            if not rules.is_speelbaar(k, game.pot, game.nextMustBeUnder7) then
                print("Niet alle geselecteerde kaarten mogen nu gespeeld worden.")
                for _, c in ipairs(selected) do table.insert(speler.hand, c) end
                return false
            end
        end
        -- Leg ze in pot
        for _, k in ipairs(selected) do
            table.insert(game.pot, k)
        end
        -- Leeg pot, extra beurt
        utils.transfer_all_cards({}, game.pot)
        game.extraTurn = true
        print("[RULES] BRUNZYN! Pot geleegd en extra beurt")
        game.check_winner()
        return true
    end

    -- 3) Normale meervoud-selectie: check equal value én speelbaarheid
    local eersteVal = utils.numeric_value(selected[1].waarde)
    for _, k in ipairs(selected) do
        if utils.numeric_value(k.waarde) ~= eersteVal
           or not rules.is_speelbaar(k, game.pot, game.nextMustBeUnder7) then
            print("INCORRECTE SELECTIE")
            for _, c in ipairs(selected) do table.insert(speler.hand, c) end
            return false
        end
    end

    -- 4) Speel alle geselecteerde kaarten (één voor één, met effecten)
    for i, k in ipairs(selected) do
        local isLast = (i == #selected)           -- alleen true bij de laatste kaart
        rules.handle_card_effects(game, playerIndex, k, isLast)
    end

    -- 5) Reset selectie-flags
    for _, k in ipairs(speler.hand) do
        k.selected = false
    end

    return true
end

--------------------------------------------------------------------
-- Speel alle Geselecteerde kaarten uit faceUp-stapel speler i
--------------------------------------------------------------------
function rules.play_selected_open(game, playerIndex)
    local speler   = require("player").players[playerIndex]
    local selected = {}

    -- 1) verzamel geselecteerden, haal ze uit faceUp
    for i = #speler.faceUp, 1, -1 do
        if speler.faceUp[i].selected then
            table.insert(selected, 1, table.remove(speler.faceUp, i))
        end
    end
    if #selected == 0 then
        print("Geen open kaart geselecteerd")
        return false
    end

    -- 2) zelfde validatie als bij hand-kaarten
    local eersteVal = utils.numeric_value(selected[1].waarde)
    for _, k in ipairs(selected) do
        if utils.numeric_value(k.waarde) ~= eersteVal
           or not rules.is_speelbaar(k, game.pot, game.nextMustBeUnder7) then
            print("Open-selectie ongeldig → pot pakken")
            -- kaart + pot terug naar hand
            utils.transfer_all_cards(speler.hand, game.pot)
            for _, c in ipairs(selected) do table.insert(speler.hand, c) end
            return false
        end
    end

    -- 3) Speel de kaarten
    for _, k in ipairs(selected) do
        rules.handle_card_effects(game, playerIndex, k)
    end
    -- checken of faceup nu leeg is.
    utils.update_phase_for_player(game, playerIndex)
    -- 4) reset selectievlaggen in resterende faceUp
    for _, k in ipairs(speler.faceUp) do k.selected = false end
    return true
end


return rules

