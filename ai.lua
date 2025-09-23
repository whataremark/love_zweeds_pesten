-- ai.lua — Multi-seat AI (werkt voor 2–4 spelers)
local utils    = require("utils")
local rules    = require("rules")
local drawPile = require("drawpile")
local player   = require("player")
local config   = require("config")

local ai = {}

----------------------------------------------------------------------
-- Heuristiek: hogere score = aantrekkelijker om te spelen
----------------------------------------------------------------------
local function get_heuristics(waarde)
    local map = {
        ["4"]=1, ["5"]=2, ["6"]=3,
        ["7"]=4, ["8"]=5, ["9"]=6,
        jack=8, queen=9, king=9,
        ace=10,
        joker=11,
        ["2"]=12,         -- altijd mag → redelijk sterk
        ["3"]=14,         -- doorzichtig, handig als ‘joker’
        ["10"]=15         -- pot leeg + extra beurt
    }
    return map[waarde] or 0
end

-- kies de n beste kaarten uit ‘cards’ o.b.v. heuristiek
local function pick_best(cards, n)
    if type(cards) ~= "table" then return {} end
    table.sort(cards, function(a, b)
        local wa = get_heuristics(a.waarde or "")
        local wb = get_heuristics(b.waarde or "")
        if wa == wb then
            return (a.waarde or "") < (b.waarde or "")
        end
        return wa > wb
    end)
    local out = {}
    for i = 1, math.min(n, #cards) do
        table.insert(out, table.remove(cards, 1))
    end
    return out
end

----------------------------------------------------------------------
-- Kaartkeuze per seat
----------------------------------------------------------------------
local function choose_card(game, pot, seatId)
    local hand = player.players[seatId].hand
    local top  = utils.effective_top_card(pot)
    local topValue = top and utils.numeric_value(top.waarde) or nil

    local legal = {}
    for _, card in ipairs(hand) do
        local v = utils.numeric_value(card.waarde)
        local special = (card.waarde=="2" or card.waarde=="3" or card.waarde=="10")

        if special or not top then
            table.insert(legal, card)
        else
            if game.nextMustBeUnder7 then
                if v <= 7 then table.insert(legal, card) end
            else
                if not topValue or v >= topValue then table.insert(legal, card) end
            end
        end
    end

    if #legal == 0 then return nil end
    table.sort(legal, function(a, b)
        return get_heuristics(a.waarde) < get_heuristics(b.waarde)
    end)
    return legal[1]
end

----------------------------------------------------------------------
-- Speel één volledige beurt voor een specifieke AI-seat
----------------------------------------------------------------------
function ai.play_for(game, pot, seatId)
    local p = player.players[seatId]
    if not p then return end

    ------------------------------------------------------------------
    -- OPEN-fase
    ------------------------------------------------------------------
    if game.state == "playingOpen" and game.currentPlayer == seatId then
        local kaart = p.faceUp[1]  -- simpel: links nemen
        if kaart and rules.is_speelbaar(kaart, game.pot, game.nextMustBeUnder7) then
            table.remove(p.faceUp, 1)
            rules.handle_card_effects(game, seatId, kaart)
        else
            if kaart then table.remove(p.faceUp, 1); table.insert(p.hand, kaart) end
            utils.transfer_all_cards(p.hand, game.pot)
            utils.deselect_all(p.hand)
            game.nextMustBeUnder7, game.extraTurn = false, false
            game.next_turn()
        end
        return
    end

    ------------------------------------------------------------------
    -- BLIND-fase
    ------------------------------------------------------------------
    if game.state == "playingBlind" and game.currentPlayer == seatId then
        local kaart = table.remove(p.faceDown, 1)
        if rules.is_speelbaar(kaart, game.pot, game.nextMustBeUnder7) then
            game.reveal.card   = kaart
            game.reveal.timer  = 0.8
            game.reveal.player = seatId
        else
            table.insert(p.hand, kaart)
            utils.transfer_all_cards(p.hand, game.pot)
            utils.deselect_all(p.hand)
            game.extraTurn = false
            game.next_turn()
        end
        return
    end

    ------------------------------------------------------------------
    -- HAND-fase
    ------------------------------------------------------------------
    if game.currentPlayer ~= seatId then return end

    local choice = choose_card(game, pot, seatId)

    -- Geen legale zet
    if not choice then
        if game.extraTurn then
            game.extraTurn = false
            game.next_turn()
        else
            utils.transfer_all_cards(p.hand, pot)
            utils.deselect_all(p.hand)
            game.extraTurn, game.nextMustBeUnder7 = false, false
            game.next_turn()
        end
        game.waitingForAI = false
        return
    end

    -- Verzamel ALLE kaarten met dezelfde waarde
    local toPlay = {}
    for i = #p.hand, 1, -1 do
        if p.hand[i].waarde == choice.waarde then
            table.insert(toPlay, table.remove(p.hand, i))
        end
    end

    -- Speel ze één voor één (laatste kaart beslist beurt-einde)
    for idx, kaart in ipairs(toPlay) do
        local isLast = (idx == #toPlay)
        rules.handle_card_effects(game, seatId, kaart, isLast)
    end

    utils.refill_hand(p.hand, drawPile, config.CARDS_INHAND)
end

----------------------------------------------------------------------
-- Setup: alle AI’s kiezen hun open kaarten
----------------------------------------------------------------------
local function pick_open_for_all_ai(game)
    local total = #player.players
    for seat = 2, total do
        local p = player.players[seat]
        if p and #p.faceUp < (config.SETUP_OPEN or 3) then
            -- kopie van hand om te sorteren zonder originele indices te breken
            local temp = {}
            for _,k in ipairs(p.hand) do table.insert(temp, k) end
            local chosen = pick_best(temp, config.SETUP_OPEN or 3)

            -- fallback als pick_best te weinig teruggeeft
            while #chosen < (config.SETUP_OPEN or 3) and #p.hand > 0 do
                table.insert(chosen, table.remove(p.hand, 1))
            end

            -- verplaats uit echte hand naar faceUp
            for _,k in ipairs(chosen) do
                -- zoek dezelfde referentie in p.hand en haal ‘m eruit
                for i=#p.hand,1,-1 do
                    if p.hand[i] == k then
                        table.remove(p.hand, i)
                        break
                    end
                end
                table.insert(p.faceUp, k)
            end
        end
    end
end

----------------------------------------------------------------------
-- Orchestrator
----------------------------------------------------------------------
function ai.update(dt, game, pot)
    if game.mode ~= "ai" then return end

    -- Busy met reveal → AI wacht
    if game.reveal and game.reveal.timer > 0 then return end

    ------------------------------------------------------------------
    -- Setup-fase: nadat de speler zijn 3 open kaarten koos
    ------------------------------------------------------------------
    if game.state == "setupAISelect" then
        pick_open_for_all_ai(game)
        -- door naar spelen (game.finalize_setup zet juiste fase voor speler 1)
        game.state = "playingHand"
        if game.finalize_setup then game.finalize_setup() end
        return
    end

    ------------------------------------------------------------------
    -- Timer-gate voor AI's
    ------------------------------------------------------------------
    if game.waitingForAI then
        game.aiTimer = game.aiTimer - dt
        if game.aiTimer > 0 then return end
        game.waitingForAI = false
    end

    local seatId = game.currentPlayer
    local p = player.players[seatId]
    if not p then return end
    if p.isAI then
        -- Zorg dat fase klopt voor deze seat
        if #p.hand > 0 then
            game.state = "playingHand"
        elseif #p.faceUp > 0 then
            game.state = "playingOpen"
        elseif #p.faceDown > 0 then
            game.state = "playingBlind"
        end
        ai.play_for(game, pot, seatId)
    end
end

return ai
