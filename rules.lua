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
            -- ←-- Zet AI-timer alléén als de AI nu echt weer aan zet is
        if game.mode == "ai" and game.currentPlayer == 2 then
            game.waitingForAI = true
            game.aiTimer      = 0.5
        else
            game.waitingForAI = false          -- <-- VOEG DIT TOE
        end
        game.check_winner()
        return
end

    -- 8 gives the player an extra turn
    if kaart.waarde == "8" then
        game.extraTurn = true
    -- ←-- Zet AI-timer alléén als de AI nu echt weer aan zet is
        if game.mode == "ai" and game.currentPlayer == 2 then
            game.waitingForAI = true
            game.aiTimer      = 0.5
        else
            game.waitingForAI = false          -- <-- VOEG DIT TOE
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

--------------------------------------------------------------------
-- Speel alle geselecteerde hand-kaarten (incl. Brunzyn-logica)
--------------------------------------------------------------------
function rules.play_selected_cards(game, playerIndex)
    local speler   = require("player").players[playerIndex]
    local selected = {}

    ----------------------------------------------------------------
    -- 1.  Geselecteerde kaarten verzamelen en uit de hand halen
    ----------------------------------------------------------------
    for i = #speler.hand, 1, -1 do
        if speler.hand[i].selected then
            table.insert(selected, 1, table.remove(speler.hand, i))
        end
    end
    if #selected == 0 then return false end

    ----------------------------------------------------------------
    -- 2.  Basis-validatie: allemaal gelijke waarde + speelbaar
    ----------------------------------------------------------------
    local firstVal = utils.numeric_value(selected[1].waarde)
    for _, k in ipairs(selected) do
        if utils.numeric_value(k.waarde) ~= firstVal
           or not rules.is_speelbaar(k, game.pot, game.nextMustBeUnder7) then
            -- ongeldig → kaarten terug
            for _, c in ipairs(selected) do table.insert(speler.hand, c) end
            return false
        end
    end

    ----------------------------------------------------------------
    -- 3.  Kaarten daadwerkelijk spelen
    --     (we laten  ❰handle_card_effects❱  het werk doen,
    --      dus we stoppen ze níét handmatig in de pot)
    ----------------------------------------------------------------
    for _, k in ipairs(selected) do
        -- advanceTurn = false → geen automatische beurtwissel
        rules.handle_card_effects(game, playerIndex, k, false)
    end

    -- deselect flags opruimen
    for _, k in ipairs(speler.hand) do k.selected = false end

    ----------------------------------------------------------------
    -- 4.  Brunzyn-check: 4 opeenvolgende identieke waardes
    --     3-en tellen niet mee en onderbreken de reeks.
    ----------------------------------------------------------------
    local function consecutive_run(pot)
        local run, topVal = 0, nil
        for i = #pot, 1, -1 do
            local c = pot[i]
            if c.waarde == "3" then break              -- 3 breekt de reeks
            elseif not topVal then                     -- eerste niet-3
                topVal = utils.numeric_value(c.waarde)
                run    = 1
            elseif utils.numeric_value(c.waarde) == topVal then
                run = run + 1
            else
                break
            end
        end
        return run
    end

    if consecutive_run(game.pot) >= 4 then
        utils.transfer_all_cards({}, game.pot)         -- pot legen
        game.extraTurn = true                          -- gratis beurt
        print("[RULES] BRUNZYN! Pot geleegd en extra beurt")
    end

    ----------------------------------------------------------------
    -- 5.  Beurtafhandeling
    ----------------------------------------------------------------
    if game.extraTurn then
        -- speler blijft aan zet; reset vlag na gebruik
        game.extraTurn = false
        utils.update_phase_for_player(game, playerIndex)

        -- AI moet opnieuw denken als hij de extra beurt kreeg
        if game.mode == "ai" and playerIndex == 2 then
            game.waitingForAI = true
            game.aiTimer      = 0.5
        end
    else
        game.next_turn()
    end

    game.check_winner()
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
        print("[ERROR] Geen open kaart geselecteerd")
        return false
    end

    -- 2) zelfde validatie als bij hand-kaarten
    local eersteVal = utils.numeric_value(selected[1].waarde)
    for _, k in ipairs(selected) do
        if utils.numeric_value(k.waarde) ~= eersteVal
           or not rules.is_speelbaar(k, game.pot, game.nextMustBeUnder7) then
            print("[RULES] open-selectie ongeldig → pot pakken")
            -- kaart + pot terug naar hand
            utils.transfer_all_cards(speler.hand, game.pot)
            for _, c in ipairs(selected) do table.insert(speler.hand, c) end
            utils.deselect_all(speler.hand)
            game.next_turn()
            return false
        end
    end

    -- 3) Speel de kaarten
    for _, k in ipairs(selected) do
        rules.handle_card_effects(game, playerIndex, k)
    end
    -- checken of faceup nu leeg is wanneer dezelfde speler aan zet blijft
    if game.currentPlayer == playerIndex then
        utils.update_phase_for_player(game, playerIndex)
    end
    -- 4) reset selectievlaggen in resterende faceUp
    for _, k in ipairs(speler.faceUp) do k.selected = false end
    return true
end


return rules

