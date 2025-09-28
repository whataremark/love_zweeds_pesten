--informatie over spelers en kaartselectie
local player = {}
local rules = require("rules")
local config = require("config")
local utils = require("utils")


--voor het scrollen van de hand
player.scrollOffset = 0  -- pixels
player.players = {}


function player.init(deck, count)
  count = tonumber(count) or 2
  player.players = {}
  for i = 1, count do
    player.players[i] = { hand = {}, faceUp = {}, faceDown = {}, scrollOffset = 0 }
  end

  local HAND  = (config.HAND_SIZE  or 6)
  local BLIND = (config.BLIND_SIZE or 3)

  for i = 1, HAND do
    for s = 1, count do
      table.insert(player.players[s].hand, deck.draw())
    end
  end
  
  for s = 1, count do
    utils.sort_hand(player.players[s].hand)
  end

  for i = 1, BLIND do
    for s = 1, count do
      table.insert(player.players[s].faceDown, deck.draw())
    end
  end
end
-- tel hoeveel kaarten momenteel geselecteerd zijn

function player.toggle_select(hand, index, phase)
    ----------------------------------------------------------------
    -- Guards
    ----------------------------------------------------------------
    if type(hand) ~= "table" then
        print("[SEL] abort: hand is geen table")
        return
    end
    local kaart = hand[index]
    if not kaart then
        print(("[SEL] abort: geen kaart op index %s"):format(tostring(index)))
        return
    end

    ----------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------
    local p = phase or "playing"   -- default
    local function vstr(k)
        return (k and (tostring(k.waarde or "?") .. (k.kleur and (" "..k.kleur) or ""))) or "?"
    end

    -- Huidige selectie uit deze stapel (alleen dit 'hand' of 'faceUp' table)
    local selected = {}
    for _, k in ipairs(hand) do
        if k.selected then table.insert(selected, k) end
    end

    print((" [SEL] phase=%s  idx=%d  target=%s  al_geselecteerd=%d")
          :format(p, index, vstr(kaart), #selected))

    ----------------------------------------------------------------
    -- Fasen met speciale logica
    ----------------------------------------------------------------
    -- Blind-fase: niets selecteren (klik negeren)
    if p == "playingBlind" or p == "blind" then
        print("  → (blind) selecteren niet toegestaan")
        return
    end

    -- Setup: speler kiest open kaarten uit zijn HAND (max 3)
    if p == "selectFaceUp" then
        local MAX_OPEN = (require("config").SETUP_OPEN or 3)
        if kaart.selected then
            kaart.selected = false
            print("  → deselect (setup open)", vstr(kaart))
        else
            if #selected < MAX_OPEN then
                kaart.selected = true
                print(("  → select (setup open) %s  (%d/%d)"):format(vstr(kaart), #selected+1, MAX_OPEN))
            else
                print(("  → max %d open kaarten al geselecteerd"):format(MAX_OPEN))
            end
        end
        return
    end

    -- Open-fase: kiezen uit FACE-UP; sta alleen gelijke waardes toe.
    -- Speelbaarheid t.o.v. pot wordt pas bij PLAY gecontroleerd.
    if p == "open" or p == "playingOpen" then
        if kaart.selected then
            kaart.selected = false
            print("  → deselect (open)", vstr(kaart))
            return
        end
        if #selected == 0 then
            kaart.selected = true
            print("  → select (open eerste)", vstr(kaart))
            return
        end
        local v0 = selected[1] and selected[1].waarde
        if v0 and kaart.waarde == v0 then
            kaart.selected = true
            print("  → select (openzelfde waarde)", vstr(kaart))
        else
            -- Wissel van groep: deselecteer alles en selecteer deze waarde
            for _, k in ipairs(hand) do k.selected = false end
            kaart.selected = true
            print(("  → switch groep (open) naar waarde %s"):format(tostring(kaart.waarde)))
        end
        return
    end

    ----------------------------------------------------------------
    -- Default: HAND-fase (normaal spelen uit hand)
    -- - je mag gelijke waardes bijselecteren als rules.can_select_for_play OK zegt
    -- - klik op andere waarde → wissel selectie naar die waarde (QoL)
    ----------------------------------------------------------------
    if kaart.selected then
        kaart.selected = false
        print("  → deselect (hand)", vstr(kaart))
        return
    end

    if #selected == 0 then
        kaart.selected = true
        print("  → select (hand eerste)", vstr(kaart))
    else
        local ok = require("rules").can_select_for_play(selected, kaart)
        if ok then
            kaart.selected = true
            print("  → select (handzelfde waarde)", vstr(kaart))
        else
            for _, k in ipairs(hand) do k.selected = false end
            kaart.selected = true
            print(("  → switch groep (hand) naar waarde %s"):format(tostring(kaart.waarde)))
        end
    end

    ----------------------------------------------------------------
    -- Debug: toon uiteindelijke selectie in deze stapel
    ----------------------------------------------------------------
    local after = {}
    local cnt = 0
    for _, k in ipairs(hand) do
        if k.selected then
            cnt = cnt + 1
            after[cnt] = vstr(k)
        end
    end
    print(("  => selectie_na_klik: %d [%s]"):format(cnt, table.concat(after, ", ")))
end

return player

