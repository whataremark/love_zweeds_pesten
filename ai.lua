--codex-- Basic computer opponent behaviour
local utils = require("utils")
local rules = require("rules")
local drawPile = require("drawpile")
local player = require("player")
local ai = {}
local config = require("config")
local game = require("game")    



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

--------------------------------------------------------------------
-- Kies de n beste kaarten (o.b.v. heuristics) uit de lijst 'cards'
--------------------------------------------------------------------
local function pick_best(cards, n)
    if type(cards) ~= "table" then return {} end   -- veiligheid

    table.sort(cards, function(a, b)
        local wa = get_heuristics(a.waarde) or 0
        local wb = get_heuristics(b.waarde) or 0
        if wa == wb then return math.random() < 0.5 end
        return wa > wb
    end)

    local chosen = {}                              -- ← expliciet initialiseren
    for i = 1, math.min(n, #cards) do
        local card = table.remove(cards, 1)        -- neem beste uit de kop
        if card then table.insert(chosen, card) end
    end
    return chosen
end


-- Select the best playable card for the AI or nil when none is possible
--codex-- Pick the most attractive playable card from the AI hand
local function choose_card(game, pot)
    local hand = player.players[2].hand
    print("AI heeft de volgende Kaarten:")
    for i, card in ipairs(hand) do
    print(i, card.waarde, card.kleur)    -- pas velden aan aan je card‐struct
    end
    print("----------------")
    
    --omdat ik deze functie heb verplaats naar utils.lua
    local top = utils.effective_top_card(pot)
    
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

--------------------------------------------------------------------
--  AI speelt een volledige beurt
--------------------------------------------------------------------
function ai.play(game, pot)
    local p = player.players[2]

    --------------------------------------------------------------
    -- 1. FACE-UP fase
    --------------------------------------------------------------
    if game.state == "playingOpen" then
        local kaart = p.faceUp[1]                     -- altijd links pakken
        if kaart and rules.is_speelbaar(kaart, game.pot, game.nextMustBeUnder7) then
            table.remove(p.faceUp, 1)
            rules.handle_card_effects(game, 2, kaart)
            -- geen game.next_turn(): card-effect (of extraTurn) handelt dat af
        else
            -- ongeldig → pot pakken + kaart terug in hand
            table.remove(p.faceUp, 1)
            utils.transfer_all_cards(p.hand, game.pot)
            table.insert(p.hand, kaart)
            utils.deselect_all(p.hand)   -- deselecteer alles
            game.next_turn()
        end
        return
    end

    --------------------------------------------------------------
    -- 2. FACE-DOWN fase
    --------------------------------------------------------------
    if game.state == "playingBlind" then
        local kaart = table.remove(p.faceDown, 1)     -- bovenste rug
        ---table.insert(game.pot, kaart)

        if rules.is_speelbaar(kaart, game.pot, game.nextMustBeUnder7) then
            rules.handle_card_effects(game, 2, kaart)
            -- effecten (of extraTurn) regelen beurtwissel
        else
            -- ongeldig → hele pot + kaart in hand
            utils.transfer_all_cards(p.hand, game.pot)
            table.insert(p.hand, kaart)
            utils.deselect_all(p.hand)   -- deselecteer alles
            game.next_turn()
        end
        return
    end

    --------------------------------------------------------------
    -- 3. HAND-fase  (standaard)
    --------------------------------------------------------------
    local choice = choose_card(game, pot)
    if not choice then
        if game.extraTurn then            -- passeer extra beurt
            game.extraTurn = false
            game.next_turn()
        else                              -- pak pot
            utils.transfer_all_cards(p.hand, pot)
            game.next_turn()
        end
        return
    end

    -- speel gekozen kaart
    rules.handle_card_effects(game, 2, choice)
    utils.refill_hand(p.hand, drawPile, config.CARDS_INHAND)
    -- rules.handle_card_effects regelt zelf extraTurn / next_turn
end

--codex-- Timer helper + setup-fase voor de AI
function ai.update(dt, game, pot)
    ----------------------------------------------------------------
    -- A)  Per beurt fase bepalen voor de AI DIT IS NIEUW MISS WEG
    ----------------------------------------------------------------
    if game.mode == "ai" and game.currentPlayer == 2 then
        local p = player.players[2]
        if #p.hand > 0 then
            game.state = "playingHand"
        elseif #p.faceUp > 0 then
            game.state = "playingOpen"
        elseif #p.faceDown > 0 then
            game.state = "playingBlind"
        end
    end
        
    
    ----------------------------------------------------------------
    -- 0.  Eénmalige setup: AI kiest zijn 3 open kaarten
    ----------------------------------------------------------------
    if game.state == "setupAISelect" then
        local aiHand  = player.players[2].hand
        local chosen  = pick_best(aiHand, config.SETUP_OPEN)   -- pak beste(n)

        -- als pick_best minder dan 3 teruggeeft, vul aan met willekeurige kaarten
        while #chosen < config.SETUP_OPEN and #aiHand > 0 do
            table.insert(chosen, table.remove(aiHand, 1))
        end

        -- zet in faceUp
        for _, k in ipairs(chosen) do
            table.insert(player.players[2].faceUp, k)
        end

        -- veilige debug-print
        local vals = {}
        for i, k in ipairs(chosen) do vals[i] = k.waarde end
        print("[AI] kiest open kaarten: "..table.concat(vals, ", "))

        game.state = "playingHand"   -- setup klaar
        return
    end

    ----------------------------------------------------------------
    -- 1.  Gewone timer-logica voor beurten
    ----------------------------------------------------------------
    if game.mode == "ai"
       and game.currentPlayer == 2
       and game.waitingForAI then

        game.aiTimer = game.aiTimer - dt
        if game.aiTimer <= 0 then
            game.waitingForAI = false
            ai.play(game, pot)
        end
    end
end



return ai
