local socket = require("socket")
local json   = require("json")
local drawPile = require("drawpile")
local rules  = require("rules")
local player = require("player")
local utils  = require("utils")
local config = require("config")
local game --empty for circular dependency

local net = {}

net.mode   = nil -- 'host' or 'client'
net.server = nil
net.conn   = nil
net.client = nil
net.netGame = nil

local imageCache = {}
local function getImage(name)
    if not imageCache[name] then
        imageCache[name] = love.graphics.newImage("png/"..name..".png")
    end
    return imageCache[name]
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

function net.set_game(g)
    net.netGame = g
    game = g
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


local function slim_card(c)
    return {kleur=c.kleur, waarde=c.waarde, naam=c.naam}
end

local function inflate_card(c)
    return {kleur=c.kleur, waarde=c.waarde, naam=c.naam, afbeelding=getImage(c.naam)}
end

local function export_state()
    local state = {
        pot={},
        players={},
        currentPlayer=game.currentPlayer,
        ronde=game.ronde,
        nextMustBeUnder7=game.nextMustBeUnder7,
        extraTurn=game.extraTurn,
        winner=game.winner,
        state=game.state,
        deckCount=game.deckCount
    }
    for _,k in ipairs(game.pot) do table.insert(state.pot, slim_card(k)) end
    for i,p in ipairs(player.players) do
        local t={hand={},faceUp={},faceDown={}}
        for _,k in ipairs(p.hand) do table.insert(t.hand, slim_card(k)) end
        for _,k in ipairs(p.faceUp) do table.insert(t.faceUp, slim_card(k)) end
        for _,k in ipairs(p.faceDown) do table.insert(t.faceDown, slim_card(k)) end
        state.players[i]=t
    end
    return state
end

local function import_state(state)
    local players={}
    for i,sp in ipairs(state.players) do
        local t={hand={},faceUp={},faceDown={}}
        for _,k in ipairs(sp.hand) do table.insert(t.hand, inflate_card(k)) end
        for _,k in ipairs(sp.faceUp) do table.insert(t.faceUp, inflate_card(k)) end
        for _,k in ipairs(sp.faceDown) do table.insert(t.faceDown, inflate_card(k)) end
        players[i]=t
    end
    player.players = players
    game.pot              = {}
    for _,k in ipairs(state.pot) do table.insert(game.pot, inflate_card(k)) end
    game.currentPlayer    = state.currentPlayer
    game.ronde            = state.ronde
    game.nextMustBeUnder7 = state.nextMustBeUnder7
    game.extraTurn        = state.extraTurn
    game.winner           = state.winner
    game.state            = state.state
    game.deckCount        = state.deckCount
    net.netGame           = state
end

function net.send(msg)
    local line = json.encode(msg).."\n"
    if net.isHost() and net.conn then
        net.conn:send(line)
    elseif net.isClient() and net.client then
        net.client:send(line)
    end
end

function net.send_state()
    if net.isHost() and net.conn then
        net.send({cmd="STATE", game=export_state()})
    end
end

local function handle_host(msg)
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
    if msg.cmd=="STATE" then
        import_state(msg.game)
    end
end

function net.update()
    if net.isHost() then
        if net.server and not net.conn then
            local c = net.server:accept()
            if c then
                c:settimeout(0)
                net.conn=c
                net.send({cmd="HELLO", seed=os.time(), deckCount=game.deckCount})
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
    elseif net.isClient() then
        if net.client then
            local line = net.client:receive()
            while line do
                local msg = json.decode(line)
                handle_client(msg)
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

return net
