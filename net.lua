local json   = require("json")
local drawPile = require("drawpile")
local rules  = require("rules")
local player = require("player")
local utils  = require("utils")
local config = require("config")
local game --empty for circular dependency

local net = {}

local import_state

net.mode   = nil -- 'host' or 'client'
net.server = nil
net.conn   = nil
net.client = nil
net.netGame = nil
net.started = false

net.game        = nil     -- wordt later gekoppeld via net.set_game
net.newClients  = {}      -- wachtrij met binnengekomen namen/IP's


-- roept elke  ~2s  net.update_lan(dt)  aan als je host bent
---------------------------------------------------------------------------
-- net.update_lan(dt, lobbyName)
--  ⏱️  Wordt door de host-lobby elke ~2 s aangeroepen om op het LAN
--     een UDP-broadcast te sturen zodat Join-clients de server kunnen zien.
---------------------------------------------------------------------------
local BCAST_PORT  = 22123
local MAGIC       = "CARDGAME_LOBBY"
local socket       = require("socket")
local udp = socket.udp         -- ❶ nodig voor scan_lan()

local beaconSocket = nil        -- hergebruik dezelfde socket telkens
local lastBeacon   = 0

function net.update_lan(dt, lobbyName)
    if not net.isHost() then return end         -- alleen host zendt uit

    -------------------------------------------------------------------
    -- 1.  Socket aanmaken (één keer) en correct binden
    -------------------------------------------------------------------
    if not beaconSocket then
        beaconSocket = socket.udp()
        beaconSocket:setoption("broadcast", true)      -- uitzend-flag
        beaconSocket:setsockname("0.0.0.0", 0)         -- bind aan willekeurige poort
    end

    -------------------------------------------------------------------
    -- 2.  Om de ±2 seconden een pakket uitsturen
    -------------------------------------------------------------------
    lastBeacon = lastBeacon + dt
    if lastBeacon < 2 then return end
    lastBeacon = 0

    local payload = MAGIC .. "|" .. (lobbyName or "Lobby")

    -------------------------------------------------------------------
    -- 3.  Stuur naar universeel én subnet-broadcast (bv. 192.168.178.255)
    -------------------------------------------------------------------
    local targets = {
        "255.255.255.255",
        "192.168.178.255",   -- ← vervang dit adres door jouw eigen subnet
    }

    for _,bc in ipairs(targets) do
        local ok, err = beaconSocket:sendto(payload, bc, BCAST_PORT)
        print("[beacon]", bc, ok and #payload or err)
    end
end

-- geeft lijst { {ip="...", name="..."}, … }
function net.scan_lan()
    local s      = udp()
    s:settimeout(0)
    s:setsockname("*", BCAST_PORT)
    local hosts  = {}
    for _ = 1,50 do      -- max 50 pakketten lezen
        local data, ip = s:receivefrom()
        if not data then break end
        if data:sub(1, #MAGIC) == MAGIC then
            local name = data:match("|(.+)$") or "Server"
            hosts[ip]  = name
        end
    end
    s:close()
    local list = {}
    for ip, name in pairs(hosts) do table.insert(list, {ip=ip, name=name}) end
    table.sort(list, function(a,b) return a.ip < b.ip end)
    return list
end


-- NET-BEGIN helper
function net.isMultiplayer()
    return net.mode ~= nil
end
function net.isHost() return net.mode == "host" end
function net.isClient() return net.mode == "client" end
-- NET-END helper

-- Attempt to bind; if it fails we become client
function net.start()
    local srv = socket.bind("*", 22122)
    if srv then
        srv:settimeout(0)
        net.mode = "host"
        net.server = srv
        return "multiplayer-host"
    else
        local c = socket.tcp()
        c:settimeout(0)
        c:connect("localhost", 22122)
        net.mode = "client"
        net.client = c
        return "multiplayer-client"
    end
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

local function slim_card(c)      -- voor export_state
    return { kleur = c.kleur, waarde = c.waarde, naam = c.naam }
end

local function inflate_card(c)   -- voor import_state
    return {
        kleur = c.kleur,
        waarde = c.waarde,
        naam = c.naam,
        afbeelding = getImage(c.naam),
    }
end

----------------------------------------------------------------------
-- 2.  Herstel snapshot aan client-kant
----------------------------------------------------------------------
local function import_state(snap)
    -- spelers
    local players = {}
    for i,sp in ipairs(snap.players or {}) do
        local t = { hand = {}, faceUp = {}, faceDown = {} }
        for _,k in ipairs(sp.hand)     do table.insert(t.hand,     inflate_card(k)) end
        for _,k in ipairs(sp.faceUp)   do table.insert(t.faceUp,   inflate_card(k)) end
        for _,k in ipairs(sp.faceDown) do table.insert(t.faceDown, inflate_card(k)) end
        players[i] = t
    end
    player.players = players

    -- pot
    net.game.pot = {}
    for _,k in ipairs(snap.pot or {}) do
        table.insert(net.game.pot, inflate_card(k))
    end

    -- overige velden
    net.game.currentPlayer    = snap.currentPlayer
    net.game.ronde            = snap.ronde
    net.game.nextMustBeUnder7 = snap.nextMustBeUnder7
    net.game.extraTurn        = snap.extraTurn
    net.game.winner           = snap.winner
    net.game.state            = snap.state
    net.game.deckCount        = snap.deckCount
end


function net.set_game(g)
    net.game = g
    -- ❷  Toegepast bij eerste binnenkomst van de echte game-state
    if net.pendingState then
        import_state(net.pendingState)
        net.pendingState = nil
    end
end


function net.host()
    -- probeer te binden; lukt het niet dan nil + error
    local srv, err = socket.bind("*", 22122)
    if not srv then return nil, err end
    srv:settimeout(0)
    net.mode   = "host"
    net.server = srv
    return "multiplayer-host"
end

function net.connect(ip)
    ip = ip or "localhost"
    local c = socket.tcp()
    c:settimeout(0)
    local ok, err = c:connect(ip, 22122)
    if not ok and err ~= "timeout" then return nil, err end
    net.mode   = "client"
    net.client = c
    return "multiplayer-client"
end



local function inflate_card(c)
    return {kleur=c.kleur, waarde=c.waarde, naam=c.naam, afbeelding=getImage(c.naam)}
end



----------------------------------------------------------------------
-- 1.  Maak een plat snapshot voor JSON
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
        state            = net.game.state,
        deckCount        = net.game.deckCount,
    }

    -- pot
    for _,k in ipairs(net.game.pot) do
        table.insert(snap.pot, slim_card(k))
    end

    -- spelers
    for i,sp in ipairs(player.players) do
        local t = { hand = {}, faceUp = {}, faceDown = {} }
        for _,k in ipairs(sp.hand)     do table.insert(t.hand,     slim_card(k)) end
        for _,k in ipairs(sp.faceUp)   do table.insert(t.faceUp,   slim_card(k)) end
        for _,k in ipairs(sp.faceDown) do table.insert(t.faceDown, slim_card(k)) end
        snap.players[i] = t
    end

    return snap
end



function net.send(msg)
    local line = json.encode(msg).."\n"
    if net.isHost() and net.conn then
        net.conn:send(line)
    elseif net.isClient() and net.client then
        net.client:send(line)
    end
end


-- wordt aangeroepen zodra er een geldig game-object is gekoppeld
function net.send_state()
    if not net.conn or not net.game then return end
    -- stuur een plat snapshot, geen functies
    net.send({ cmd = "STATE", game = export_state() })
    print("[net] STATE sent, pot=", #net.game.pot)
end


local function handle_host(msg)
    if msg.cmd == "HELLO" then
        table.insert(hosts, "Client")   -- later naam mee-sturen
        print("[net] client connected")
    return
    end
    if msg.cmd=="PLAY" then
        local p = player.players[msg.id]
        if p then
            for _,c in ipairs(p.hand) do c.selected=false end
            for _,rc in ipairs(msg.cards or {}) do
                for _,hc in ipairs(p.hand) do
                    if hc.waarde==rc.waarde and hc.kleur==rc.kleur then
                        hc.selected=true
                    end
                end
            end
            rules.play_selected_cards(game, msg.id)
            utils.refill_hand(p.hand, drawPile, config.CARDS_INHAND)
            utils.update_phase_for_player(game, msg.id)
        end
    elseif msg.cmd=="PICKUP" then
        local p=player.players[msg.id]
        utils.transfer_all_cards(p.hand, game.pot)
        utils.deselect_all(p.hand)
        game.nextMustBeUnder7=false
        game.next_turn()
    elseif msg.cmd=="PASS" then
        if game.currentPlayer==msg.id and game.extraTurn then
            game.extraTurn=false
            game.next_turn()
        end
    end
    net.send_state()
end

local function handle_client(msg)
    if msg.cmd == "STATE" then
        -- ❶  Spaar snapshot op als game nog niet bestaat
        if not net.game then
            net.pendingState = msg.game      -- tijdelijk bewaren
            net.started      = true          -- client_lobby mag doorgaan
        else
            import_state(msg.game)           -- normale update
        end
    end
end

function net.update()
    if net.isHost() then
        if net.server and not net.conn then
            local c = net.server:accept()
            if c then
                c:settimeout(0)
                net.conn = c
            
                --tijdens accept
            local dc = (net.game and net.game.deckCount) or 1
            net.send({cmd="HELLO", seed=os.time(), deckCount = dc})

            -- voeg vlak eronder toe:
            table.insert(net.newClients, "Client")          -- of een echte naam
            end
            ------------------------------------------------------------------
            -- 4.  Blijf de spel­status pushen zolang er een game is
            ------------------------------------------------------------------
            if net.game and net.conn then
                net.send_state()
            end
        end
        
        if net.conn then
            local line = net.conn:receive()
            while line do
                local msg = json.decode(line)
                handle_host(msg)
                line = net.conn:receive()
            end
        end

        ----------------------------------------------------------------------
        --  CLIENT – lees alle binnenkomende regels veilig
        ----------------------------------------------------------------------
        if net.isClient() and net.client then
            local line = net.client:receive()
            while line do
                -- Pak alleen regels die eruit zien als JSON
                if line:match("^[%s]*[{%[]") then
                    local ok, msg = pcall(json.decode, line)
                    if ok and type(msg) == "table" then
                        handle_client(msg)        -- zet net.started zodra STATE komt
                    else
                        print("[net]  ⚠  kon JSON niet decoden, skip")
                    end
                end
                -- Lees evt. meerdere regels die al in de buffer zitten
                line = net.client:receive()
            end
        end
    end
end


function net.play_from_client(cards)
    net.send({cmd="PLAY", id=1, cards=cards})
end
function net.pickup_from_client()
    net.send({cmd="PICKUP", id=1})
end
function net.pass_from_client()
    net.send({cmd="PASS", id=1})
end

function net.poll_new_client_name()
    return table.remove(net.newClients, 1)
end



return net