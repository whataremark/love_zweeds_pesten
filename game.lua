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
                if p == net.localId then utils.deselect_all(pl.hand) end
                game.next_turn()
            end

            game.reveal.timer  = 0
            game.reveal.player = nil
            game.reveal.card   = nil
        end
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
        ui.draw_end_screen(game.winner, player.players)
        return
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgCanvas, 0, 0)

    ui.draw_pot(game.pot, ongeldigeZetTimer > 0, toonPotOverlay)
    ui.draw_deck(drawPile)
    ui.draw_all_players(player.players)

    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Ronde: "           .. ronde,                  20, 20)
    love.graphics.print("Kaarten in pot: "  .. #game.pot,             20, 40)
    love.graphics.print("Speler aan zet: "  .. game.currentPlayer,    20, 60)
    love.graphics.print("AI-timer: "        .. string.format("%.2f", game.aiTimer), 20, 80)

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


  ------------------------------------------------------------------
    -- 3.  BLIND‑fase – klik op een faceDown‑kaart
    -----------------------------------------------------------------
    if myPhase == "playingBlind"
       and game.currentPlayer == myId
       and button == 1 then

        local boxY = love.graphics.getHeight() - (160 + 40) - 10
        local yRow = ui.row_faceDown_Y(boxY, myId)
        if y >= yRow and y <= yRow + 160 then
            local kaart = table.remove(player.players[myId].faceDown, 1)
            game.reveal.timer  = 1.0
            game.reveal.card   = kaart
            game.reveal.player = myId
            return
        end
        -- BUITEN de blind-rij? NIET returnen → laat knoppen/andere zaken lopen
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
    if key == "space" and scene == "playing" and game.currentPlayer == net.localId then
        local b = buttons and buttons.play
        if b then
            local cx, cy = b.x + b.w/2, b.y + b.h/2
            game.mousepressed(cx, cy, 1)
        end
    end
end

--------------------------------------------------------------------
-- game.start(mode)  – nieuwe ronde opzetten
--------------------------------------------------------------------
function game.start(mode, aiCount)
    game.aiTimer = 0

    -------------------------------------------------------------- 0
    -- Trekstapel maken en schudden  ➜  **alleen de host doet dit**
    --------------------------------------------------------------
    if mode ~= "multiplayer-client" then
        drawPile.init(game.deckCount)        -- host: deck & shuffle

        ------------------------------------------------------------------
        -- NIEUW: AI-seats uitbreiden zonder MP te breken
        -- - We roepen jouw bestaande player.init(drawPile) aan (zoals nu),
        --   en vullen daarna extra AI-spelers aan tot gewenst aantal.
        ------------------------------------------------------------------
        player.init(drawPile)                -- jouw bestaande uitdelen

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

function game.finalize_setup()
    if not all_open_selected() then return end   -- nog niet klaar

    -- bepaal wie mag beginnen: eerste 4, dan 5, 6, …
    local order = {"4","5","6","7","8","9","10","jack","queen","king","ace"}
    local found
    for _,v in ipairs(order) do
        for pid = 1, game.maxPlayers do
            for _,c in ipairs(player.players[pid].faceUp) do
                if c.waarde==v then
                    game.currentPlayer = pid
                    found = v
                    break
                end
            end
            if found then break end
        end
        if found then break end
    end
    print(found and
          string.format("[INIT] P%d starts with %s", game.currentPlayer, found)
          or "[INIT] no 4/5/… found")

    utils.update_phase_for_player(game, game.currentPlayer)
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
end


--------------------------------------------------------------------
-- game.next_turn()  – speler-wissel + AI-timer + fase-update
--------------------------------------------------------------------
function game.next_turn()
  -- als iemand al ‘finished’ is: winner check in check_winner()
  repeat
    game.currentPlayer = next_seat(game.currentPlayer, game.maxPlayers)
  until true  -- (eventueel overslaan van 'finished' seats)

  utils.update_phase_for_player(game, game.currentPlayer)

  -- AI wachttijd (seconden) bij turn-wissel
  if game.mode == "ai" and player.players[game.currentPlayer].isAI then
    local minDelay, maxDelay = 0.5, 2.3
    local r = love.math.random() -- 0..1 float
    game.aiTimer      = minDelay + (maxDelay - minDelay) * r
    game.waitingForAI = true
    print(("[AI] wacht %.2fs (seat %d)"):format(game.aiTimer, game.currentPlayer))
  else
    game.waitingForAI = false
    game.aiTimer      = 0
  end
end





--------------------------------------------------------------------
-- game.check_winner()  – einde-spel controle
--------------------------------------------------------------------
function game.check_winner()
  for i=1, game.maxPlayers do
    local p = player.players[i]
    if #p.hand==0 and #p.faceUp==0 and #p.faceDown==0 then
      game.winner = i
      return true
    end
  end
  return false
end

return game
