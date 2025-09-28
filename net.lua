local json     = require("json")
local drawPile = require("drawpile")
local rules    = require("rules")
local player   = require("player")
local utils    = require("utils")
local config   = require("config")
local socket   = require("socket")
local profile = require("profile")


local net = {}

net.localId     = 1
net.mode        = nil   -- 'host' or 'client'
net.server      = nil
net.conn        = nil
net.client      = nil
net.netGame     = nil
net.started     = false

net.game        = nil     -- wordt later gekoppeld via net.set_game
net.newClients  = {}      -- wachtrij met binnengekomen namen/IP's

----------------------------------------------------------------------
-- Broadcast / discovery (LAN)
----------------------------------------------------------------------
local BCAST_PORT    = 22123
local MAGIC         = "CARDGAME_LOBBY"
local udp           = socket.udp

-- Beacon (host) – hergebruik dezelfde UDP-socket
local beaconSocket  = nil
local lastBeaconTime = 0

-- Scanner (client) – permanente luister-socket
local scanSocket    = nil

-- net.lua (na locals)
do
  local ok, data = pcall(love.filesystem.read, "profile.json")
  if ok and data then
    local t = nil
    pcall(function() t = json.decode(data) end)
    if t and t.name then net.playerName = t.name end
  end
end


-- Bepaal broadcast-doelen: universeel + /24 van je actieve NIC
local function compute_broadcast_targets()
    local list = { "255.255.255.255" }
    local probe = socket.udp()
    probe:settimeout(0)
    -- gebruik een “peer” naar 8.8.8.8 om je lokale NIC te leren kennen
    pcall(function() probe:setpeername("8.8.8.8", 53) end)
    local ip = probe:getsockname()
    if ip and ip:match("^%d+%.%d+%.%d+%.%d+$") then
        local a,b,c,_ = ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
        table.insert(list, string.format("%s.%s.%s.255", a,b,c))
    end
    probe:close()

    -- unique
    local seen, out = {}, {}
    for _,addr in ipairs(list) do
        if not seen[addr] then seen[addr] = true; table.insert(out, addr) end
    end
    return out
end

-- Stuur elke ~2s een beacon met lobby-naam (alleen host)
function net.update_lan(_dt, lobbyName)
    if not net.isHost() then return end

    if not beaconSocket then
        beaconSocket = socket.udp()
        beaconSocket:setoption("broadcast", true)
        beaconSocket:setsockname("0.0.0.0", 0)
    end

    -- gebruik klok i.p.v. dt
    local now = (love.timer and love.timer.getTime()) or os.clock()
    if (now - lastBeaconTime) < 2 then return end
    lastBeaconTime = now

    local payload = MAGIC .. "|" .. (lobbyName or "Lobby")
    local targets = compute_broadcast_targets()

    for _,bc in ipairs(targets) do
        local nbytes, err = beaconSocket:sendto(payload, bc, BCAST_PORT)
        if nbytes then
            print("[beacon]", bc, nbytes)
        else
            -- veel OS'en weigeren 255.255.255.255 → onderdruk die melding
            local e = tostring(err or "")
            if not e:lower():find("permission") then
                print("[beacon]", bc, e)
            end
        end
    end
end

-- Non-blocking scan; roep dit b.v. 4x per seconde in je client-lobby
-- Retourneert lijst { {ip="...", name="..."}, ... } voor wat er dit frame is gezien
function net.scan_lan()
    if not scanSocket then
        scanSocket = socket.udp()
        scanSocket:settimeout(0)
        pcall(function() scanSocket:setoption("reuseaddr", true) end)
        pcall(function() scanSocket:setoption("reuseport", true) end)
        scanSocket:setsockname("0.0.0.0", BCAST_PORT)
    end

    local found = {}
    for _ = 1, 50 do
        local data, ip = scanSocket:receivefrom()
        if not data then break end
        if data:sub(1, #MAGIC) == MAGIC then
            local name = data:match("|(.+)$") or "Server"
            found[ip]  = name
        end
    end

    local list = {}
    for ip,name in pairs(found) do
        table.insert(list, { ip = ip, name = name })
    end
    table.sort(list, function(a,b) return a.ip < b.ip end)
    return list
end

----------------------------------------------------------------------
-- NET-helpers
----------------------------------------------------------------------
function net.isMultiplayer() return net.mode ~= nil end
function net.isHost()        return net.mode == "host" end
function net.isClient()      return net.mode == "client" end

-- Attempt to bind; if it fails we become client
function net.start()
    local srv = socket.bind("*", 22122)
    if srv then
        srv:settimeout(0)
        net.mode    = "host"
        net.server  = srv
        net.localId = 1
        return "multiplayer-host"
    else
        local c = socket.tcp()
        c:settimeout(0)
        c:connect("localhost", 22122)
        net.mode    = "client"
        net.client  = c
        net.localId = 2
        return "multiplayer-client"
    end
end

function net.host()
    local srv, err = socket.bind("*", 22122)
    if not srv then return nil, err end
    srv:settimeout(0)
    net.mode    = "host"
    net.server  = srv
    net.localId = 1
    return "multiplayer-host"
end

function net.connect(ip)
    ip = ip or "localhost"
    local c = socket.tcp()
    c:settimeout(0)
    local ok, err = c:connect(ip, 22122)
    if not ok and err ~= "timeout" then return nil, err end
    net.mode    = "client"
    net.client  = c
    net.localId = 2
    net.identify(net.playerName or ("Speler "..(net.localId or 1)))
    return "multiplayer-client"
end

----------------------------------------------------------------------
-- Kaart helpers (primitives only)
----------------------------------------------------------------------
local imageCache = {}
local function getImage(name)
    if not imageCache[name] then
        imageCache[name] = love.graphics.newImage("png/"..name..".png")
    end
    return imageCache[name]
end

local function slim_card(c)
    return { kleur = c.kleur, waarde = c.waarde, naam = c.naam }
end

local function inflate_card(c)
    local nm = c.naam or (c.kleur .. "_" .. tostring(c.waarde))
    return {
        kleur      = c.kleur,
        waarde     = c.waarde,
        naam       = nm,
        afbeelding = getImage(nm),
    }
end

local function inflate_player(sp)
    local t = { name = sp.name, hand = {}, faceUp = {}, faceDown = {} }
    for _,c in ipairs(sp.hand     or {}) do table.insert(t.hand,     inflate_card(c)) end
    for _,c in ipairs(sp.faceUp   or {}) do table.insert(t.faceUp,   inflate_card(c)) end
    for _,c in ipairs(sp.faceDown or {}) do table.insert(t.faceDown, inflate_card(c)) end
    return t
end

----------------------------------------------------------------------
-- Snapshot import / export
----------------------------------------------------------------------
local function export_state()
    if not net.game then return {} end

    local snap = {
        pot              = {},
        players          = {},
        currentPlayer    = net.game.currentPlayer,
        ronde            = net.game.ronde,
        nextMustBeUnder7 = net.game.nextMustBeUnder7,
        extraTurn        = net.game.extraTurn,
        winner           = net.game.winner,
        finishedOrder = net.game.finishedOrder,   -- deze is niuew
        state            = net.game.state,
        deckCount        = net.game.deckCount,
        drawCount        = #drawPile.cards,
    }

    for _,k in ipairs(net.game.pot) do
        table.insert(snap.pot, slim_card(k))
    end

    for i,sp in ipairs(player.players) do
        local t = { name = sp.name, hand = {}, faceUp = {}, faceDown = {} }
        t.name = sp.name
        for _,k in ipairs(sp.hand)     do table.insert(t.hand,     slim_card(k)) end
        for _,k in ipairs(sp.faceUp)   do table.insert(t.faceUp,   slim_card(k)) end
        for _,k in ipairs(sp.faceDown) do table.insert(t.faceDown, slim_card(k)) end
        snap.players[i] = t
    end

    -- reveal meesturen (zodat clients de overlay zien)
    snap.reveal = nil
    if net.game and net.game.reveal and net.game.reveal.card and (net.game.reveal.timer or 0) > 0 then
        snap.reveal = {
            timer  = net.game.reveal.timer,
            player = net.game.reveal.player,
            card   = slim_card(net.game.reveal.card),
        }
    end
    
    -- FX event (éénmalig doorgeven met oplopende seq)
    if net.game and net.game.fxEmit then
        snap.fx = { name = net.game.fxEmit.name, seq = net.game.fxEmit.seq }
        -- NIET resetten hier; export_state wordt vaak aangeroepen. Client dedupliceert via seq.
    end

    return snap
end

local function import_state(snap)
    local new = {}

    ------------------------------------------------------------------
    -- ❶ UI-ephemera van lokale speler bewaren (selecties + scroll)
    ------------------------------------------------------------------
    local meIdx     = net.localId or 1
    local meOld     = player.players and player.players[meIdx]
    local oldSelHand, oldSelOpen = {}, {}
    local oldScroll = 0

    if meOld then
        -- geselecteerde kaarten in HAND
        for _, c in ipairs(meOld.hand or {}) do
            if c.selected then
                oldSelHand[(c.kleur or "") .. (c.waarde or "")] = true
            end
        end
        -- geselecteerde kaarten in OPEN
        for _, c in ipairs(meOld.faceUp or {}) do
            if c.selected then
                oldSelOpen[(c.kleur or "") .. (c.waarde or "")] = true
            end
        end
        -- huidige scroll
        oldScroll = meOld.scrollOffset or 0
    end

    ------------------------------------------------------------------
    -- ❷ Spelers uit snapshot opbouwen
    ------------------------------------------------------------------
    for i, sp in ipairs(snap.players or {}) do
        new[i] = inflate_player(sp)
    end
    player.players = new

    ------------------------------------------------------------------
    -- ❸ Selecties + scrollOffset terugzetten voor locale speler
    ------------------------------------------------------------------
    local me = player.players[meIdx]
    if me then
        for _, c in ipairs(me.hand or {}) do
            if oldSelHand[(c.kleur or "") .. (c.waarde or "")] then
                c.selected = true
            end
        end
        for _, c in ipairs(me.faceUp or {}) do
            if oldSelOpen[(c.kleur or "") .. (c.waarde or "")] then
                c.selected = true
            end
        end
        me.scrollOffset = oldScroll
    end

    ------------------------------------------------------------------
    -- ❹ Pot reconstrueren
    ------------------------------------------------------------------
    net.game.pot = {}
    for _, c in ipairs(snap.pot or {}) do
        table.insert(net.game.pot, inflate_card(c))
    end

    ------------------------------------------------------------------
    -- ❺ Eenvoudige gamevelden kopiëren
    ------------------------------------------------------------------
    local g = net.game
    g.currentPlayer    = snap.currentPlayer
    g.nextMustBeUnder7 = snap.nextMustBeUnder7
    g.state            = snap.state
    g.ronde            = snap.ronde
    g.maxPlayers       = #new
    g.winner           = snap.winner                 -- ⬅️ NIEUW
    g.finishedOrder    = snap.finishedOrder or {}    -- ⬅️ NIEUW


    ------------------------------------------------------------------
    -- ❻ Trekstapel-maat (voor UI) bijwerken
    ------------------------------------------------------------------
    drawPile.cards = {}
    for i = 1, (snap.drawCount or 0) do
        drawPile.cards[i] = { naam = "back" }
    end

    -- reveal overnemen (client toont overlay; host blijft autoritair)
    local r = snap.reveal
    if r and r.card then
        net.game.reveal.timer  = r.timer or 0
        net.game.reveal.player = r.player
        net.game.reveal.card   = inflate_card(r.card)
    else
        net.game.reveal.timer, net.game.reveal.player, net.game.reveal.card = 0, nil, nil
    end

        -- FX overnemen (dedupe via seq)
    if snap.fx and snap.fx.seq and ( (net.game.fxSeenSeq or 0) < snap.fx.seq ) then
        net.game.fxSeenSeq = snap.fx.seq
        require("utils").dispatch_fx(net.game, snap.fx.name)  -- alleen lokaal afspelen (géén re-emit)
    end


end

function net.set_game(g)
    net.openDone = 0
    net.game = g
    if net.pendingState then
        import_state(net.pendingState)
        net.pendingState = nil
    end
end

----------------------------------------------------------------------
-- Transport
----------------------------------------------------------------------
function net.send(msg)
    local line = json.encode(msg) .. "\n"
    if net.isHost() and net.conn then
        net.conn:send(line)
    elseif net.isClient() and net.client then
        net.client:send(line)
    end
end

function net.send_state()
    if not net.conn or not net.game then return end
    net.send({ cmd = "STATE", game = export_state() })
end

----------------------------------------------------------------------
-- Handlers
----------------------------------------------------------------------
local function handle_host(msg)
    if msg.cmd == "JOIN" then
    local pid  = tonumber(msg.id) or 2
    local name = tostring(msg.name or ("Speler " .. pid))

    -- als de game al bestaat: schrijf naam in de spelerslijst
    if player.players and player.players[pid] then
        player.players[pid].name = name
    end

    -- altijd in wachtrij voor host_lobby UI
    table.insert(net.newClients, name)

    -- alleen snapshotten als er al een game loopt
    if net.game and net.conn then
        net.send_state()
    end

    print(("[net] JOIN seat=%s name=%s"):format(tostring(pid), name))
    return
    end

    ------------------------------------------------------------------
    -- 1) Client legt één face-up kaart (OPEN_ADD)
    ------------------------------------------------------------------
    if msg.cmd == "OPEN_ADD" then
        local p   = player.players[msg.id]; if not p then return end
        local new = inflate_card(msg.card)
        table.insert(p.faceUp, new)

        -- dezelfde kaart uit de hand halen
        for i,k in ipairs(p.hand) do
            if k.kleur == new.kleur and k.waarde == new.waarde then
                table.remove(p.hand, i)
                break
            end
        end

        net.send_state()
        return
    end

        -- Client wil een blind-reveal (alleen host mag uitvoeren)
    if msg.cmd == "BLIND_REVEAL" then
        local pid = msg.id
        local p   = player.players[pid]; if not p then return end

        -- Gate: juiste beurt + juiste fase
        local phase = utils.phase_for_player(pid)
        if net.game.currentPlayer ~= pid or phase ~= "playingBlind" then
            print(("[HOST][BLIND] geweigerd: turn=%s phase=%s"):format(net.game.currentPlayer, phase))
            return
        end

        local card = table.remove(p.faceDown, 1)
        if not card then return end

        -- Zet reveal op de host; clients krijgen overlay via STATE
        net.game.reveal.timer  = 1.0
        net.game.reveal.player = pid
        net.game.reveal.card   = card

        net.send_state()  -- push meteen zodat clients overlay zien
        return
    end

        -------------------------------------------------------------------
    -- 2) Client speelt geselecteerde face-up kaart(en) (OPEN_PLAY)
    --    Ondersteunt:
    --      - msg.indices : { i1, i2, ... }  (aanbevolen, dalend)
    --      - msg.index   : number           (enkele index)
    --      - msg.cards   : { {kleur,waarde,naam?}, ... } (fallback)
    ------------------------------------------------------------------
    if msg.cmd == "OPEN_PLAY" then
        local pid = msg.id
        local p   = player.players[pid]; if not p then return end

        -- gate: juiste beurt + juiste fase
        local phase = utils.phase_for_player(pid)
        if net.game.currentPlayer ~= pid or phase ~= "playingOpen" then
            print(("[HOST][OPEN_PLAY] geweigerd: turn=%s phase=%s"):format(net.game.currentPlayer, phase))
            return
        end

        -- normaliseer naar dalende indices (voorkeur: msg.indices; fallback: msg.index; fallback2: msg.cards)
        local toRemove = {}
        if type(msg.indices) == "table" and #msg.indices > 0 then
            for _,i in ipairs(msg.indices) do table.insert(toRemove, i) end
            table.sort(toRemove, function(a,b) return a > b end)
        elseif type(msg.index) == "number" then
            table.insert(toRemove, msg.index)
        elseif type(msg.cards) == "table" and #msg.cards > 0 then
            local need = {}
            for _,rc in ipairs(msg.cards) do
            table.insert(need, (rc.kleur or "").."|"..tostring(rc.waarde or ""))
            end
            for i = #p.faceUp, 1, -1 do
            local k   = p.faceUp[i]
            local key = (k.kleur or "").."|"..tostring(k.waarde or "")
            for j = #need, 1, -1 do
                if need[j] == key then
                table.remove(need, j)
                table.insert(toRemove, i)
                break
                end
            end
            end
            table.sort(toRemove, function(a,b) return a > b end)
        else
            print("[HOST][OPEN_PLAY] geen indices/index/cards meegegeven")
            return
        end
        if #toRemove == 0 then
            print("[HOST][OPEN_PLAY] niets te spelen")
            return
        end

        -- speel kaarten (host-side authoritative)
        local played = 0
        for _, idx in ipairs(toRemove) do
            local card = table.remove(p.faceUp, idx)
            if card then
            rules.handle_card_effects(net.game, pid, card)
            played = played + 1
            end
        end
        print(("[HOST][OPEN_PLAY] pid=%d played=%d"):format(pid, played))

        utils.update_phase_for_player(net.game, pid)
        -- ✅ meteen winner-check + push naar client
        if net.game.check_winner and net.game:check_winner() then
        net.send_state()
        return
        end

        net.send_state()
        return
        end


    ------------------------------------------------------------------
    -- 3) Client klaar met open kaarten
    ------------------------------------------------------------------
    if msg.cmd == "OPEN_DONE" then
        net.openDone = (net.openDone or 0) + 1
        if net.openDone == 1 then
            net.game.finalize_setup()
            net.send_state()
        end
        return
    end

    ------------------------------------------------------------------
    -- 4) Hand-play / pickup / pass
    ------------------------------------------------------------------
    if msg.cmd == "PLAY" then
        local p = player.players[msg.id]
        if p then
            for _, c in ipairs(p.hand) do c.selected = false end
            for _, rc in ipairs(msg.cards or {}) do
                for _, hc in ipairs(p.hand) do
                    if hc.waarde == rc.waarde and hc.kleur == rc.kleur then
                        hc.selected = true
                    end
                end
            end
            rules.play_selected_cards(net.game, msg.id)
            utils.refill_hand(p.hand, drawPile, config.CARDS_INHAND)
            utils.update_phase_for_player(net.game, msg.id)
        end
        net.send_state()
        return

    elseif msg.cmd == "PICKUP" then
        local p = player.players[msg.id]; if not p then return end
        utils.transfer_all_cards(p.hand, net.game.pot)
        utils.deselect_all(p.hand)
        net.game.nextMustBeUnder7 = false
        net.game.next_turn()
        net.send_state()
        return

    elseif msg.cmd == "PASS" then
        if net.game.currentPlayer == msg.id and net.game.extraTurn then
            net.game.extraTurn = false
            net.game.next_turn()
            net.send_state()
        end
        return
    end
end



-- Client-side message handler (host -> client)
local function handle_client(msg)
  -- 0) Eerste handshake van de host
  if msg.cmd == "HELLO" then
    -- markeer dat we verbonden zijn
    net.started = true
    net.send({ cmd = "JOIN", id = net.localId, name = profile.get_name() })
    -- host kan alvast deckCount doorgeven (komt ook in STATE mee)
    if net.game and msg.deckCount then
      net.game.deckCount = msg.deckCount
    end
    return
  end

  -- 1) Volledige snapshot (autoritatief)
  if msg.cmd == "STATE" then
    if not net.game then
      -- game-object nog niet gekoppeld: parkeer snapshot even
      net.pendingState = msg.game
      net.started      = true
    else
      -- normale weg: importeer direct
      import_state(msg.game)
    end
    return
  end

  -- 2) (Optioneel) eenvoudige ‘banner’ push vanaf host
  if msg.cmd == "BANNER" then
    -- verwacht: { cmd="BANNER", text="...", color={r,g,b}, dur=... }
    if net.game and net.game.push_banner then
      net.game.push_banner(msg.text or "", msg.color, msg.dur)
    end
    return
  end

  -- 3) Debug / fallback
    print("[client] onbekend bericht:", tostring(msg.cmd))
end
----------------------------------------------------------------------
--  Netwerk-update – host- en client-pad strikt gescheiden
----------------------------------------------------------------------
function net.update(dt)
    -- HOST
    if net.isHost() then
        -- 1) Accept nieuwe client (max 1)
        if net.server and not net.conn then
            local c = net.server:accept()
            if c then
                c:settimeout(0)
                net.conn = c
                local dc = (net.game and net.game.deckCount) or 1
                net.send({ cmd="HELLO", seed=os.time(), deckCount = dc })
            end
        end

        -- 2) Inkomende berichten
        if net.conn then
            local line = net.conn:receive("*l")
            while line do
                local ok, msg = pcall(json.decode, line)
                if ok and type(msg)=="table" then
                    handle_host(msg)
                end
                line = net.conn:receive("*l")
            end
        end

        -- 3) Push state
        if net.game and net.conn then
            net.send_state()
        end

        -- 4) LAN-beacon
        net.update_lan(dt, net.lobbyName or "Lobby")
    end

    -- CLIENT
    if net.isClient() and net.client then
        local line, err = net.client:receive("*l")
        while line do
            if line:match("^[%s]*[{%[]") then
                local ok, msg = pcall(json.decode, line)
                if ok and type(msg)=="table" then
                    handle_client(msg)
                end
            end
            line, err = net.client:receive("*l")
        end
    end
end

----------------------------------------------------------------------
-- Client→Host helpers
----------------------------------------------------------------------
function net.play_from_client(cards)
    net.send({cmd="PLAY",   id=net.localId, cards=cards})
end
function net.pickup_from_client()
    net.send({cmd="PICKUP", id=net.localId})
end
function net.pass_from_client()
    net.send({cmd="PASS",   id=net.localId})
end

function net.poll_new_client_name()
    return table.remove(net.newClients, 1)
end

function net.play_open_from_client(indices, cards)
  net.send({
    cmd     = "OPEN_PLAY",
    id      = net.localId,
    indices = indices,   -- {3,2,1} (descending gewenst, maar host sorteert ook)
    cards   = cards      -- {{kleur=..,waarde=..,naam=..}, ...}
  })
end

function net.play_blind_from_client()
    net.send({ cmd = "BLIND_REVEAL", id = net.localId })
end

-- net.lua (ergens onderaan)
function net.identify(name)
  net.playerName = name
  if net.isClient() and net.client then
    net.send({ cmd="JOIN", id=net.localId, name=name })
  elseif net.isHost() then
    -- host zet z'n eigen naam lokaal (seat 1) en broadcast
    if player.players[1] then player.players[1].name = name end
    net.send_state()
  end
  -- cache naar schijf
  local ok, blob = pcall(json.encode, { name = name })
  if ok and blob then love.filesystem.write("profile.json", blob) end
end


return net
