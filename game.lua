-- game.lua  – complete speel-state (data + callbacks)

----------------------------------------------------------------------
-- 0.  Imports
----------------------------------------------------------------------
local game      = {}                     -- module-tabel die we teruggeven
local drawPile  = require("drawpile")
local player    = require("player")
local utils     = require("utils")
local config    = require("config")
local net       = require("net")
local ui        -- later laden voor circular dependency
local rules     -- later laden voor circular dependency
local ai        --- later laden voor circular dependency

--- Kaartvolgorde voor start: 4 (beste), daarna 5, 6, ..., aas
local START_ORDER = {"4","5","6","7","8","9","10","jack","queen","king","ace"}
----------------------------------------------------------------------
-- 1.  Interne variabelen (voorheen globals in main.lua)
----------------------------------------------------------------------
local bgCanvas
local scene             = "playing"       -- "playing" | "gameover"
local ronde             = 0
local ongeldigeZetTimer = 0
local toonPotOverlay    = false
local buttons           = nil             -- actie-knoppen van ui

----------------------------------------------------------------------
-- 2.  Kern-state (onveranderd uit je oude game.lua)
----------------------------------------------------------------------
game.mode              = "ai"
game.pot               = {}
game.deckCount         = 1
game.currentPlayer     = 1
game.maxPlayers        = 2
game.aiTimer           = 0
game.waitingForAI      = false
game.nextMustBeUnder7  = false
game.extraTurn         = false
game.winner            = nil
game.reveal            = { timer = 0, player = nil, card = nil }

game.effects = {}     -- banners
game.fxSeq   = 0      -- event id t.b.v. MP
game.fxEmit  = nil    -- laatst uit te zenden fx event (wordt door net opgepikt)

-- Touch-drag scroll state (alleen mobiel)
game.dragScroll = { active = false, startX = 0, startOffset = 0, touchId = nil }


function game.touchpressed(id, x, y, pressure)
    local myId = net.localId or 1
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    -- bbox van de eigen hand (onderaan), gelijk aan ui.get_card_positions
    local CARD_H = 160
    local boxH   = CARD_H + 40
    local boxY   = h - boxH - 10
    local yCards = boxY + 20

    if y >= yCards and y <= (yCards + CARD_H) then
        local p = player.players[myId]; if not p then return end
        local _, maxScroll = _compute_scroll_bounds_for_local()
        game.dragScroll.active      = true
        game.dragScroll.touchId     = id
        game.dragScroll.startX      = x
        game.dragScroll.startOffset = p.scrollOffset or 0
    end
end

function game.touchmoved(id, x, y, dx, dy, pressure)
    if not (game.dragScroll.active and game.dragScroll.touchId == id) then return end
    local myId = net.localId or 1
    local p = player.players[myId]; if not p then return end
    local _, maxScroll = _compute_scroll_bounds_for_local()
    local delta = x - game.dragScroll.startX
    p.scrollOffset = _clamp(game.dragScroll.startOffset - delta, 0, maxScroll)
end

function game.touchreleased(id, x, y, pressure)
    if game.dragScroll.touchId == id then
        game.dragScroll.active  = false
        game.dragScroll.touchId = nil
    end
end

--voor win scherm---
local function is_empty(p)
  return #p.hand == 0 and #p.faceUp == 0 and #p.faceDown == 0
end

-- markeer seat 'id' als finished als hij écht leeg is
function game._mark_finished_if_empty(id)
    local p = player.players[id]
    if not p or p.finished then return end
    if #p.hand == 0 and #p.faceUp == 0 and #p.faceDown == 0 then
        p.finished = true
        table.insert(game.finishedOrder, id)
        -- optioneel: print(("[OUT] speler %d ligt eruit"):format(id))
    end
end

-- tel actieve spelers en onthoud de laatste actieve seat
local function active_players()
    local cnt, last = 0, nil
    for i = 1, game.maxPlayers do
        local p = player.players[i]
        if p and not p.finished then
            cnt  = cnt + 1
            last = i
        end
    end
    return cnt, last
end


-- wie is “uitgespeeld”?
local function is_finished_seat(id)
  local p = player.players[id]
  return (not p) or (#p.hand==0 and #p.faceUp==0 and #p.faceDown==0)
end

-- update finished / winner; return true als spel echt voorbij is
function game._update_finished_and_maybe_end()
    local alive = {}
    for i = 1, game.maxPlayers do
        if not _is_finished(i) then table.insert(alive, i) end
    end

    -- spel klaar als er 0 of 1 spelers over zijn
    if #alive <= 1 then
        game.winner = alive[1] or 0  -- (0 bij niemand over: theoretisch niet haalbaar)
        -- host pusht meteen de state zodat clients het eindscherm zien
        if net.isHost and net.isHost() and net.send_state then net.send_state() end
        return true
    end
    return false
end
------

-- zelfde geometrie als ui.get_card_positions()
local function _compute_scroll_bounds_for_local()
    local p = player.players[net.localId or 1]
    if not p then return 0, 0 end

    local wScr = love.graphics.getWidth()
    local CARD_H_SRC, CARD_W_SRC = 500, 300
    local CARD_H      = 160
    local SCALE       = CARD_H / CARD_H_SRC
    local CARD_W      = CARD_W_SRC * SCALE
    local PADDING     = 15
    local cardSpace   = CARD_W + PADDING

    local boxW        = wScr - 80
    local minVis      = 6
    local fitVis      = math.floor((boxW - 2 * PADDING) / cardSpace)
    local visible     = math.max(minVis, fitVis)

    local total       = #(p.hand or {})
    local maxScroll   = math.max(0, (total - visible) * cardSpace)
    return cardSpace, maxScroll
end

local function _clamp(v, a, b)
    if v < a then return a elseif v > b then return b else return v end
end

-- NIEUW: generieke rotatie
local function next_seat(i, max) return (i % max) + 1 end

----------------------------------------------------------------------
-- Hulp: fase bepalen
----------------------------------------------------------------------
local function phase_for_player(i)
    return utils.phase_for_player(i)
end

----------------------------------------------------------------------
-- 3.  Initialisatie wanneer de state ge-enterd wordt
----------------------------------------------------------------------
function game.load(cfg)
    ui    = ui    or require("ui")
    rules = rules or require("rules")
    ai    = ai    or require("ai")

    bgCanvas = utils.generate_green_felt_background(
                   love.graphics.getWidth(), love.graphics.getHeight())
    
    game.deckCount = (cfg and cfg.deckCount) or game.deckCount or 1


    -- ⬇︎ voeg aiCount doorgeefluik toe (val terug op 1)
    game.start(cfg and cfg.mode or "ai", cfg and cfg.aiCount or 1)


    scene             = "playing"
    ronde             = 0
    ongeldigeZetTimer = 0
    toonPotOverlay    = false
    buttons           = nil
end

----------------------------------------------------------------------
-- 4.  Hoofd-update (was je oude love.update)
----------------------------------------------------------------------
function game.update(dt)
    if scene ~= "playing" then return end
    utils.update_banners(dt, game)

    -- Netwerk-sync
    if net.isMultiplayer() then
        net.update()
        if net.isHost() then net.send_state() end
    end
    -- A) Ongeldige-zet-timer
    if ongeldigeZetTimer > 0 then
        ongeldigeZetTimer = ongeldigeZetTimer - dt
    end

    -- B) Reveal-timer (blinde kaart)
    if game.reveal.timer > 0 then
        -- In multiplayer: alleen de HOST werkt reveal af; clients wachten op snapshots
        if net.isMultiplayer() and not net.isHost() then
            return
        end

        game.reveal.timer = game.reveal.timer - dt
        if game.reveal.timer <= 0 then
            local p  = game.reveal.player
            local k  = game.reveal.card
            local ok = rules.is_speelbaar(k, game.pot, game.nextMustBeUnder7)

            if ok then
                rules.handle_card_effects(game, p, k)
            else
                local pl = player.players[p]
                utils.transfer_all_cards(pl.hand, game.pot)
                table.insert(pl.hand, k)
                if p == (net.localId or 1) then utils.deselect_all(pl.hand) end
                game.next_turn()
            end

            -- ✅ Reset HIER (binnen het <=0 blok) en vóór de return hieronder
            game.reveal.timer  = 0
            game.reveal.player = nil
            game.reveal.card   = nil

            -- (optioneel) host kan meteen een snapshot sturen
            if net.isMultiplayer() and net.isHost() then
                net.send_state()
            end
        end

        -- verlaat update zolang we in de reveal-flow zitten
        return
    end

    -- C) AI
    utils.update_reveal_logic(dt, game)
    if game.mode == "ai" then
        ai.update(dt, game, game.pot)
    end

    -- D) Winner-check
    if game.winner then
        scene = "gameover"
    end
end

----------------------------------------------------------------------
-- 5.  Hoofd-draw (was je oude love.draw)
----------------------------------------------------------------------
function game.draw()
    love.graphics.setBackgroundColor(0.1, 0.4, 0.1)

    if scene == "gameover" then
        ui.draw_end_screen(game.winner, player.players, game.finishedOrder)  -- ⬅️ geef volgorde mee
        return
    end

    ui.draw_banners(game.effects)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgCanvas, 0, 0)

    ui.draw_pot(game.pot, ongeldigeZetTimer > 0, toonPotOverlay)
    ui.draw_deck(drawPile)
    ui.draw_all_players(player.players)

    if game.state ~= "setupSelectOpen" and game.state ~= "setupAISelect" then
        buttons = ui.draw_action_buttons()
        game._uiButtons = buttons
    else
        buttons = nil
    end
end

----------------------------------------------------------------------
-- 6.  Input-callbacks (uit je oude main.lua)
----------------------------------------------------------------------
function game.mousepressed(x, y, button)
    if game.reveal.timer > 0 then return end
    local myId    = net.localId or 1
    local myPhase = utils.phase_of(game, myId)
    local btns    = buttons or game._uiButtons


    ------------------------------------------------------------------
    -- 1.  SETUP‑fase – kies 3 open kaarten
    ------------------------------------------------------------------
    if game.state == "setupSelectOpen" and button == 1 then
        local faceUp    = player.players[myId].faceUp
        if #faceUp >= config.SETUP_OPEN then return end   -- ← stop na 3
        local hand      = player.players[myId].hand
        local positions = ui.get_card_positions(hand)

        for i = #positions, 1, -1 do
            local p = positions[i]
            if utils.inside(x, y, p.x, p.y, p.w, p.h) then
                -- kaart uit hand naar faceUp verplaatst
                local kaart = table.remove(hand, i)
                table.insert(player.players[myId].faceUp, kaart)
                -- ✱  alleen de multiplayer‑client stuurt dit pakket
                if net.isClient() then
                    net.send({
                        cmd  = "OPEN_ADD",
                        id   = myId,
                        card = { kleur = kaart.kleur,
                                waarde = kaart.waarde,
                                naam   = kaart.naam }      --nieuw
                    })
                end

                if #player.players[myId].faceUp == config.SETUP_OPEN then
                    ------------------------------------------------------
                    -- A. Solo (AI)  → AI moet open kaarten kiezen
                    ------------------------------------------------------
                    if game.mode == "ai" then
                        game.state = "setupAISelect"
                    end

                    ------------------------------------------------------
                    -- B. Multiplayer ‑ host finalizeert, client meldt klaar
                    ------------------------------------------------------
                    local iAmHost = (game.mode == "multiplayer" and net.isHost())

                    if iAmHost or game.mode ~= "multiplayer" then
                        game.finalize_setup()          -- host  of  solo
                    else
                        -- client: laat host weten dat zijn open‑fase klaar is
                        net.send({cmd = "OPEN_DONE", id = myId})
                    end
                end
                return
            end
        end
    end

    ------------------------------------------------------------------
    -- 2.  OPEN‑fase – kaart uit faceUp selecteren
    ------------------------------------------------------------------
    if myPhase == "playingOpen"
        and game.currentPlayer == myId
        and button == 1 then

            local fp = player.players[myId].faceUp
            if #fp > 0 then
                local w = love.graphics.getWidth()
                local TARGET_H, PADDING = 140, 15
                local boxH   = TARGET_H + 40
                local boxY   = love.graphics.getHeight() - boxH - 10
                local yRow   = ui.row_faceUp_Y(boxY, myId)

                -- Alleen afhandelen als klik BINNEN de open-rij valt
                if y >= yRow and y <= yRow + TARGET_H then
                    local first   = fp[1].afbeelding
                    local scale   = TARGET_H / first:getHeight()
                    local cardW   = first:getWidth() * scale
                    local spacing = cardW + PADDING
                    local totalW  = #fp * spacing - PADDING
                    local xStart  = (w - totalW) / 2

                    if x >= xStart and x <= xStart + totalW then
                        local col = math.floor((x - xStart) / spacing) + 1
                        if fp[col] then
                            player.toggle_select(fp, col, "open")
                        end
                        return  -- ✅ alleen returnen als we selectie verwerkt hebben
                    end
                    -- klik lag horizontaal buiten de rij → doorvallen naar knoppen
                end
                -- klik lag verticaal buiten de rij → doorvallen naar knoppen
            end
        end


        -- 3. BLIND-fase – klik op een faceDown-kaart
        if myPhase == "playingBlind"
        and game.currentPlayer == myId
        and button == 1 then

            local boxY = love.graphics.getHeight() - (160 + 40) - 10
            local yRow = ui.row_faceDown_Y(boxY, myId)
            if y >= yRow and y <= yRow + 160 then
                if net.isClient() then
                    -- Client vraagt de host om de blind-reveal te doen
                    require("net").play_blind_from_client()
                else
                    -- Host (of solo): doet de reveal lokaal
                    local kaart = table.remove(player.players[myId].faceDown, 1)
                    game.reveal.timer  = 1.0
                    game.reveal.card   = kaart
                    game.reveal.player = myId
                end
                return
            end
        end
            ------------------------------------------------------------------
    -- 4.  ACTIE‑KNOPPEN + kaartselectie in hand
    ------------------------------------------------------------------
    if button == 1 and btns then
        -- PICK-UP
        local b = btns.pickup
        if b and utils.inside(x, y, b.x, b.y, b.w, b.h) then
            if net.isClient() and game.currentPlayer == myId then
                net.pickup_from_client()
            elseif game.currentPlayer == myId then
                utils.transfer_all_cards(player.players[myId].hand, game.pot)
                utils.deselect_all(player.players[myId].hand)
                game.nextMustBeUnder7 = false  
                utils.sort_hand(hand)
                game.next_turn()
            end
            return
        end

-- PLAY (hand-fase)
        local bp = btns.play
        if bp and utils.inside(x, y, bp.x, bp.y, bp.w, bp.h)
        and myPhase == "playingHand"
        and game.currentPlayer == myId then

            if game.currentPlayer ~= myId then return end
            if net.isClient() then
                local cards = {}
                for _,k in ipairs(player.players[myId].hand) do
                    if k.selected then
                        table.insert(cards, {kleur=k.kleur, waarde=k.waarde})
                    end
                end
                net.play_from_client(cards)
                utils.deselect_all(player.players[myId].hand)
            else
                local ok = rules.play_selected_cards(game, myId)
                if ok then
                    local p = player.players[myId]
                    utils.refill_hand(p.hand, drawPile, config.CARDS_INHAND)
                    utils.update_phase_for_player(game, myId)
                else
                    ongeldigeZetTimer = 1.0
                end
            end
            return
        end
        -- PLAY (open-fase)
    -- PLAY (open-fase)
    do
    local btns = buttons or game._uiButtons
    local bp   = btns and btns.play
    if bp and utils.inside(x, y, bp.x, bp.y, bp.w, bp.h)
        and utils.phase_of(game, myId) == "playingOpen"
        and game.currentPlayer == myId then

        local fp = player.players[myId].faceUp or {}

        -- verzamel geselecteerde open-kaarten → indices DALEND
        local indices, cards = {}, {}
        for i = #fp, 1, -1 do
        if fp[i].selected then
            table.insert(indices, i)
            table.insert(cards, {kleur = fp[i].kleur, waarde = fp[i].waarde, naam = fp[i].naam})
        end
        end

        print(("[CLICK] PLAY(open) seat=%d cur=%d selectedOpen=%d")
            :format(myId, game.currentPlayer, #indices))

        if #indices == 0 then return end

        if net.isClient() then
            -- ✅ stuur naar host; niet lokaal afspelen
            net.play_open_from_client(indices, cards)
            -- (optioneel) direct visueel deselecteren
            for _,k in ipairs(fp) do k.selected = false end
        else
            -- host / solo → lokaal afhandelen
            local ok = rules.play_selected_open(game, myId)
            print("hij denkt dat client host is.")
            print("[PLAY_OPEN][host] result =", ok)
            if not ok then ongeldigeZetTimer = 1.0 end
        end
        return
    end
    end
        --
            -- PASS
            local bpass = btns.pass
            if bpass and utils.inside(x, y, bpass.x, bpass.y, bpass.w, bpass.h) then
                if net.isClient() then
                    net.pass_from_client()
                elseif game.currentPlayer == myId and game.extraTurn then
                    game.extraTurn = false
                    game.next_turn()
                end
                return
            end

            -- BEKIJK POT
            local bv = btns.pot
            if bv and utils.inside(x, y, bv.x, bv.y, bv.w, bv.h) then
                toonPotOverlay = not toonPotOverlay
                return
            end

        -- pot aanklikken
        if button == 1 and game and game.pot and #game.pot > 0 then
            -- pak bounding box van de pot (meestal midden van tafel)
            local potX, potY = love.graphics.getWidth()/2 - 40, love.graphics.getHeight()/2 - 60
            local potW, potH = 80, 120  -- aanpassen aan jouw kaartformaat

            if x >= potX and x <= potX + potW and y >= potY and y <= potY + potH then
                toonPotOverlay = not toonPotOverlay
            end
        end

            -- DESELECT
            local bd = btns.deselect
            if bd and utils.inside(x, y, bd.x, bd.y, bd.w, bd.h) then
                utils.deselect_all(player.players[myId].hand)
                return
            end
        end

------------------------------------------------------------------
    -- 5) Selectie in HAND
    ------------------------------------------------------------------
    if button == 1 then
        local hand      = player.players[myId].hand
        local positions = ui.get_card_positions(hand)
        for i = #positions, 1, -1 do
            local p = positions[i]
            if utils.inside(x, y, p.x, p.y, p.w, p.h) then
                player.toggle_select(hand, i, myPhase)
                return
            end
        end
    end
end


function game.wheelmoved(x, y)
    if player.players[net.localId] then
        local CARD_H_SRC, CARD_W_SRC = 500, 300
        local CARD_H      = 160
        local SCALE       = CARD_H / CARD_H_SRC
        local CARD_W      = CARD_W_SRC * SCALE
        local PADDING     = 15
        local cardSpace   = CARD_W + PADDING

        local p = player.players[net.localId]
        p.scrollOffset = math.max(0, (p.scrollOffset or 0) - y * cardSpace)
    end
end

function game.keypressed(key)
  if key ~= "space" then return end

  -- niet reageren op het eindscherm
  if scene == "gameover" then return end

  local myId    = net.localId or 1
  local myPhase = require("utils").phase_of(game, myId)
  local isMyTurn = (game.currentPlayer == myId)

  -- Alleen in hand-fase en als jij aan de beurt bent
  if not (isMyTurn and myPhase == "playingHand") then return end

  -- Pak de play-knop uit de laatst getekende UI-knoppen
  local btns = game._uiButtons
  local b = btns and btns.play
  if not b then return end

  -- Simuleer een muisklik op de 'Speel' knop
  local cx, cy = b.x + b.w * 0.5, b.y + b.h * 0.5
  game.mousepressed(cx, cy, 1)
end

--------------------------------------------------------------------
-- game.start(mode)  – nieuwe ronde opzetten
--------------------------------------------------------------------
function game.start(mode, aiCount)
    game.aiTimer = 0
    game.finishedOrder = {}
    for i = 1, #player.players do
        player.players[i].finished = false
    end
    -------------------------------------------------------------- 0
    -- Trekstapel maken en schudden  ➜  **alleen de host doet dit**
    --------------------------------------------------------------
    if mode ~= "multiplayer-client" then
    
                -- Host bepaalt aantal seats op basis van aantal TCP-clients
        local seats = 1 + (net.client_count and net.client_count() or 0)
        local MAX = (config.MAX_SEATS or 4)
        if seats < 2 then seats = 2 end
        if seats > MAX then seats = MAX end

        -- deck opzetten en delen
        drawPile.init(game.deckCount)
        player.init(drawPile, seats)

        -- namen vullen
        local profile = require("profile")
        player.players[1].name = profile.get_name()
        for i = 2, seats do
            local nm = (net.clients[i] and net.clients[i].name) or ("Speler " .. i)
            player.players[i].name = nm
        end

        game.maxPlayers = seats

        ------------------------------------------------------------------
        -- NIEUW: AI-seats uitbreiden zonder MP te breken
        -- - We roepen jouw bestaande player.init(drawPile) aan (zoals nu),
        --   en vullen daarna extra AI-spelers aan tot gewenst aantal.
        ------------------------------------------------------------------

        -- Alleen in AI-modus willen we 1..3 extra AI's kunnen hebben
        if mode ~= "multiplayer-host" and mode ~= "multiplayer-client" then
            local desired = 1 + (tonumber(aiCount) or 1)     -- 1 speler + N AI
            if desired < 2 then desired = 2 end              -- min. 1 AI
            if desired > (config.MAX_SEATS or 4) then
                desired = (config.MAX_SEATS or 4)
            end

            -- Zorg dat alle niet-1 seats als AI gemarkeerd zijn
            for i = 2, #player.players do
                player.players[i].isAI = true
            end

            -- Voeg ontbrekende AI-spelers toe en deel kaarten
            while #player.players < desired do
                local p = { hand = {}, faceUp = {}, faceDown = {}, scrollOffset = 0, isAI = true }
                for _ = 1, (config.HAND_SIZE or 6) do
                    table.insert(p.hand, drawPile.draw())
                end
                for _ = 1, (config.BLIND_SIZE or 3) do
                    table.insert(p.faceDown, drawPile.draw())
                end
                table.insert(player.players, p)
            end
        end

        local profile = require("profile")
        -- seat 1 = local player name
        player.players[1].name = profile.get_name()

        -- fill names for the rest
        for i = 2, #player.players do
            local p = player.players[i]
            if not p.name or p.name == "" then
                p.name = p.isAI and ("AI " .. (i - 1)) or ("Speler " .. i)
            end
        end
        game.maxPlayers = #player.players
    else
        -- client wacht op eerste STATE, weet maxPlayers nog niet
        game.maxPlayers = 2                  -- fallback, wordt overschreven
    end

    -------------------------------------------------------------- 1
    -- Basis-status resetten
    --------------------------------------------------------------
    game.mode = (mode == "multiplayer-host" or mode == "multiplayer-client")
                and "multiplayer" or (mode or "ai")

    game.currentPlayer = 1
    game.waitingForAI  = false
    game.extraTurn     = false
    game.winner        = nil
    game.ronde         = 0
    game.state         = "setupSelectOpen"   -- mens kiest open kaarten

    -------------------------------------------------------------- 2
    -- Lege pot & start-speler bepalen  ➜  host alleen
    --------------------------------------------------------------
    game.pot = {}
    game.nextMustBeUnder7 = false

    -------------------------------------------------------------- 3
    -- Netwerk-koppeling
    --------------------------------------------------------------
    if mode == "multiplayer-host" then
        net.set_game(game)
        net.send_state()
    elseif mode == "multiplayer-client" then
        net.set_game(game)     -- snapshot zal alles vullen
    end
end

----------------------------------------------------------------------
-- nadat álle spelers hun 3 open kaarten hebben gekozen
----------------------------------------------------------------------
local function all_open_selected()
    for id = 1, game.maxPlayers do
        if #player.players[id].faceUp < config.SETUP_OPEN then
            return false
        end
    end
    return true
end

-- =========================
-- START-FLOW NA OPEN-SELECT
-- =========================
local function lowest_start_rank_in_hand(hand)
    -- Geeft de laagste rang (1 = "4", 2 = "5", ..., 11 = "ace"), of nil als geen geschikte kaart.
    local best = nil
    -- Maak een reverse lookup: waarde -> rang
    -- (kan ook bovenaan éénmalig gebouwd worden; dit is simpel en snel genoeg)
    local rank = {}
    for i, v in ipairs(START_ORDER) do rank[v] = i end

    for _, c in ipairs(hand) do
        local r = rank[c.waarde]
        if r and (not best or r < best) then
            best = r
            if best == 1 then
                -- kan niet beter dan "4"; direct teruggeven
                return 1
            end
        end
    end
    return best
end

-- ====== VERVANG je huidige finalize_setup door deze ======
function game.finalize_setup()
    -- 1) Wacht tot iedereen z'n faceUp gekozen heeft
    local needed = config.SETUP_OPEN or config.OPEN_SIZE or config.OPEN_COUNT or config.faceUpCount or 3
    for pid = 1, game.maxPlayers do
        if #player.players[pid].faceUp < needed then
            return -- nog niet klaar met setup
        end
    end

    -- 2) Alleen de HOST bepaalt de starter; clients krijgen snapshot
    if net and net.isClient and net.isClient() then
        return
    end

    -- 3) Zoek per speler de laagste startbare kaart in de HAND (niet faceUp!)
    local bestPid, bestRank = nil, nil
    for pid = 1, game.maxPlayers do
        local r = lowest_start_rank_in_hand(player.players[pid].hand)
        if r and (not bestRank or r < bestRank) then
            bestRank = r
            bestPid  = pid
            if bestRank == 1 then break end -- iemand heeft een 4; klaar
        end
    end

    -- 4) Zet de startspeler (fallback: PID 1 als niemand 4..A heeft)
    game.currentPlayer = bestPid or 1

    -- 5) (Optioneel) banner voor duidelijkheid
    if ui and ui.add_banner then
        if bestPid then
            local label = START_ORDER[bestRank] or "?"
            ui.add_banner(("P%d begint (laagste handkaart: %s)"):format(game.currentPlayer, label))
        else
            ui.add_banner(("Niemand had 4..A in de hand — P%d begint"):format(game.currentPlayer))
        end
    end

    -- 6) Fase sync en (MP) state push
    utils.update_phase_for_player(game, game.currentPlayer)
    if net and net.send_state and net.isHost and net.isHost() then
        net.send_state()
    end
end



-- Monotone timestamp
local function __now()
    return love.timer.getTime()
end



--------------------------------------------------------------------
-- game.play_card(playerIndex, kaart)  – kaart van hand naar pot
--------------------------------------------------------------------
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
     utils.sort_hand(hand)
end


--------------------------------------------------------------------
-- game.next_turn()  – speler-wissel + AI-timer + fase-update
--------------------------------------------------------------------
function game.next_turn()
  -- 1) Klaar? Dan eindigen.
  -- (Gebruik game:check_winner() als jouw functie met dubbelepunt is gedefinieerd.)
  if game.check_winner() then
    if net.isHost and net.isHost() then net.send_state() end
    return
  end

  -- 2) Zoek volgende NIET-finished seat
  local tries = 0
  repeat
    game.currentPlayer = (game.currentPlayer % game.maxPlayers) + 1
    tries = tries + 1
  until tries > game.maxPlayers or not is_finished_seat(game.currentPlayer)

  -- 3) Fase sync
  utils.update_phase_for_player(game, game.currentPlayer)

  -- 4) AI-delay (alleen als AI aan zet)
  local curP = player.players[game.currentPlayer]
  if game.mode == "ai" and curP and curP.isAI then
    local minDelay, maxDelay = 0.5, 2.3
    game.aiTimer      = minDelay + (maxDelay - minDelay) * love.math.random()
    game.waitingForAI = true
  else
    game.waitingForAI = false
    game.aiTimer      = 0
  end

  -- 5) Host broadcast
  if net.isMultiplayer and net.isMultiplayer() and net.isHost and net.isHost() then
    net.send_state()
  end
end


--------------------------------------------------------------------
-- game.check_winner()  – einde-spel controle
--------------------------------------------------------------------
function game.check_winner()
  local finished = 0
  for i = 1, game.maxPlayers do
    local p = player.players[i]
    if p and p.finished then finished = finished + 1 end
  end

  if finished >= game.maxPlayers - 1 then
    if game.finishedOrder and game.finishedOrder[1] then
      game.winner = game.finishedOrder[1]
    else
      -- fallback (zou zelden nodig moeten zijn)
      game.winner = game.winner or 1
    end
    return true
  end

  return false
end

return game
