-- Modern UI rendering for Zweeds Pesten
-- --- Layout state & constants -------------------------------------------------
local ui = {}

local config = require("config")
local player = require("player")
local net     = require("net")
local rules   = require("rules")
local utils   = require("utils")
local drawPileModule = require("drawpile")

local cardBack = love.graphics.newImage("png/back.png")

local DESIGN_W, DESIGN_H = 1280, 720
local MIN_SCALE, MAX_SCALE = 0.75, 1.2
local DOUBLE_TAP_TIME = 0.30

ui.scale      = 1
ui.pad        = 16
ui.fontBig    = nil
ui.fontSmall  = nil
ui.areas      = {}
ui.buttons    = {}
ui.handView   = nil
ui.faceUpView = nil
ui.drag       = { active = false }
ui.lastTap    = { time = 0, index = nil }
ui.centerState = {}
ui.statusLines = {}
ui.game        = nil

local function clamp(min, value, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function ensureFonts()
    local bigSize   = math.max(18, math.floor(28 * ui.scale))
    local smallSize = math.max(14, math.floor(18 * ui.scale))

    if not ui.fontBig or ui.fontBigSize ~= bigSize then
        ui.fontBig = love.graphics.newFont(bigSize)
        ui.fontBigSize = bigSize
    end
    if not ui.fontSmall or ui.fontSmallSize ~= smallSize then
        ui.fontSmall = love.graphics.newFont(smallSize)
        ui.fontSmallSize = smallSize
    end
end

local function resetInteractionCaches()
    local active = ui.buttons and ui.buttons.active
    local activeId = ui.buttons and ui.buttons.activeId
    ui.buttons = { active = active, activeId = activeId }
    ui.handView = nil
    ui.faceUpView = nil
    ui.centerState = {}
end

function ui.layout(w, h)
    ui.viewportWidth, ui.viewportHeight = w, h

    local ratio = math.min(w / DESIGN_W, h / DESIGN_H)
    ui.scale = clamp(MIN_SCALE, ratio, MAX_SCALE)
    ui.pad   = 16 * ui.scale
    ui.safe  = ui.pad

    ui.cardWidth   = config.cardWidth * ui.scale
    ui.cardHeight  = config.cardHeight * ui.scale
    ui.cardPadding = config.cardPadding * ui.scale
    ui.cardSpace   = ui.cardWidth + ui.cardPadding

    ui.isCompact = w < (config.phoneBreakpoint or 800)

    ensureFonts()
    resetInteractionCaches()

    local hudHeight = ui.fontBig:getHeight() + ui.fontSmall:getHeight() * 1.8
    local hudWidth  = (w - ui.safe * 2) * 0.5 - ui.pad * 0.5

    ui.areas = {
        hudLeftTop  = { x = ui.safe, y = ui.safe, w = hudWidth, h = hudHeight },
        hudRightTop = { x = w - hudWidth - ui.safe, y = ui.safe, w = hudWidth, h = hudHeight },
    }

    local statusH = ui.fontSmall:getHeight() * 1.6 + ui.pad * 0.6
    ui.areas.statusBottom = {
        x = ui.safe,
        y = h - statusH - ui.safe,
        w = w - 2 * ui.safe,
        h = statusH,
    }

    local handHeight = ui.cardHeight * 1.6 + ui.pad * 4
    ui.areas.handBottom = {
        x = ui.safe,
        y = ui.areas.statusBottom.y - handHeight - ui.pad,
        w = w - 2 * ui.safe,
        h = handHeight,
    }

    local topHeight = ui.cardHeight * 0.8 + ui.pad * 2
    ui.areas.topOpponent = {
        x = ui.safe,
        y = ui.areas.hudLeftTop.y + ui.areas.hudLeftTop.h + ui.pad,
        w = w - 2 * ui.safe,
        h = topHeight,
    }

    local centerY = ui.areas.topOpponent.y + ui.areas.topOpponent.h + ui.pad
    local centerHeight = ui.areas.handBottom.y - ui.pad - centerY
    centerHeight = math.max(centerHeight, ui.cardHeight + ui.pad * 2)
    ui.areas.center = {
        x = ui.safe,
        y = centerY,
        w = w - 2 * ui.safe,
        h = centerHeight,
    }

    return ui.areas
end

-- --- Helpers for game state ---------------------------------------------------
local function localPlayerId()
    return net.localId or 1
end

local function isMyTurn(game)
    return (game.currentPlayer or 1) == localPlayerId()
end

local function collectSelected(cards)
    local selected = {}
    for _, card in ipairs(cards) do
        if card.selected then
            table.insert(selected, card)
        end
    end
    return selected
end

local function handSelectionIsLegal(game, pid)
    if game.state ~= "playingHand" then return false end
    local hand = player.players[pid] and player.players[pid].hand or {}
    local selected = collectSelected(hand)
    if #selected == 0 then return false end
    local first = utils.numeric_value(selected[1].waarde)
    for _, card in ipairs(selected) do
        if utils.numeric_value(card.waarde) ~= first then
            return false
        end
        if not rules.is_speelbaar(card, game.pot, game.nextMustBeUnder7) then
            return false
        end
    end
    return true
end

local function openSelectionIsLegal(game, pid)
    if game.state ~= "playingOpen" then return false end
    local openCards = player.players[pid] and player.players[pid].faceUp or {}
    local selected = collectSelected(openCards)
    if #selected == 0 then return false end
    local first = utils.numeric_value(selected[1].waarde)
    for _, card in ipairs(selected) do
        if utils.numeric_value(card.waarde) ~= first then
            return false
        end
        if not rules.is_speelbaar(card, game.pot, game.nextMustBeUnder7) then
            return false
        end
    end
    return true
end

local function buildButtonState(game)
    local mine = localPlayerId()
    local myTurn = isMyTurn(game)
    local buttons = {
        { id = "play",   label = "Speel",  enabled = myTurn and (handSelectionIsLegal(game, mine) or openSelectionIsLegal(game, mine)) },
        { id = "draw",   label = "Pakken", enabled = myTurn and game.state ~= "playingBlind" and not game.waitingForAI },
        { id = "pass",   label = "Pas",    enabled = myTurn and game.extraTurn },
    }
    if game.state == "setupSelectOpen" or game.state == "setupAISelect" then
        for _, btn in ipairs(buttons) do
            btn.enabled = false
        end
    end
    return buttons
end

-- --- Drawing helpers ----------------------------------------------------------
local function drawPanelBackground(area, alpha)
    alpha = alpha or 0.82
    love.graphics.setColor(0, 0, 0, 0.25 * alpha)
    love.graphics.rectangle("fill", area.x, area.y, area.w, area.h, 18 * ui.scale, 18 * ui.scale)
    love.graphics.setColor(1, 1, 1, 0.06 * alpha)
    love.graphics.rectangle("line", area.x, area.y, area.w, area.h, 18 * ui.scale, 18 * ui.scale)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHUDLeftTop(game)
    local area = ui.areas.hudLeftTop
    drawPanelBackground(area, 0.9)

    love.graphics.setFont(ui.fontBig)
    local ronde = game.ronde or 0
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(string.format("Ronde %d", ronde), area.x + ui.pad, area.y + ui.pad)

    love.graphics.setFont(ui.fontSmall)
    local turnText = string.format("Aan zet: Speler %d", game.currentPlayer or 1)
    if net.isMultiplayer() and net.localId and game.currentPlayer == net.localId then
        turnText = turnText .. " (jij)"
    elseif net.localId and game.currentPlayer == net.localId then
        turnText = "Jij bent aan de beurt"
    end
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print(turnText, area.x + ui.pad, area.y + ui.pad + ui.fontBig:getHeight() + ui.pad * 0.2)

    local phaseLabels = {
        playingHand = "Handfase",
        playingOpen = "Open kaarten",
        playingBlind = "Blind pakken",
        setupSelectOpen = "Kies open kaarten",
        setupAISelect = "AI kiest open kaarten",
    }
    local phase = phaseLabels[game.state] or game.state or "?"
    local suffix = game.nextMustBeUnder7 and " · ≤7 verplicht" or ""
    love.graphics.print("Fase: " .. phase .. suffix, area.x + ui.pad, area.y + ui.pad + ui.fontBig:getHeight() + ui.fontSmall:getHeight() + ui.pad * 0.6)

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHUDRightTop(game)
    local area = ui.areas.hudRightTop
    drawPanelBackground(area, 0.9)

    love.graphics.setFont(ui.fontBig)
    local mode
    if net.isHost() then mode = "Host" elseif net.isClient() then mode = "Client" else mode = "Solo" end
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Status", area.x + ui.pad, area.y + ui.pad)

    love.graphics.setFont(ui.fontSmall)
    local infoY = area.y + ui.pad + ui.fontBig:getHeight() + ui.pad * 0.2
    local deckInfo = string.format("Decks: %d", game.deckCount or 1)
    local modeInfo = string.format("Modus: %s", mode)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print(modeInfo, area.x + ui.pad, infoY)
    love.graphics.print(deckInfo, area.x + ui.pad, infoY + ui.fontSmall:getHeight() + ui.pad * 0.4)

    if net.isMultiplayer() then
        local pingText = net.lastPing and string.format("Ping: %d ms", math.floor(net.lastPing * 1000)) or "Verbinding actief"
        love.graphics.print(pingText, area.x + ui.pad, infoY + (ui.fontSmall:getHeight() + ui.pad * 0.4) * 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawCardImage(card, x, y, selected)
    if not card or not card.afbeelding then return end
    local img = card.afbeelding
    local scale = ui.cardHeight / img:getHeight()
    if selected then
        y = y - ui.cardHeight * 0.08
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, x, y, 0, scale, scale)
    if selected then
        love.graphics.setColor(0.93, 0.75, 0.25, 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, ui.cardWidth, ui.cardHeight, 12, 12)
        love.graphics.setLineWidth(1)
    end
end

local function computeHandView(pData)
    if ui.handView then return ui.handView end
    local area = ui.areas.handBottom
    local viewportW = area.w - ui.pad * 2
    local cards = pData.hand or {}
    pData.scrollOffset = pData.scrollOffset or 0

    local contentW
    if #cards == 0 then
        contentW = 0
    else
        contentW = #cards * ui.cardWidth + math.max(0, (#cards - 1)) * ui.cardPadding
    end
    local maxScroll = math.max(0, contentW - viewportW)
    if pData.scrollOffset > maxScroll then pData.scrollOffset = maxScroll end
    if pData.scrollOffset < 0 then pData.scrollOffset = 0 end

    local xStart
    if contentW < viewportW then
        xStart = area.x + (area.w - contentW) / 2
    else
        xStart = area.x + ui.pad - pData.scrollOffset
    end

    ui.handView = {
        xStart = xStart,
        viewportW = viewportW,
        contentW = contentW,
        maxScroll = maxScroll,
        offset = pData.scrollOffset,
        hitboxes = {},
    }
    return ui.handView
end

local function drawOverflowIndicators(area, view)
    if not view then return end
    if view.contentW <= view.viewportW + 1 then return end

    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.rectangle("fill", area.x, area.y, ui.pad, area.h)
    love.graphics.rectangle("fill", area.x + area.w - ui.pad, area.y, ui.pad, area.h)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHandBottom(pData)
    local area = ui.areas.handBottom
    drawPanelBackground(area, 0.95)

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.85)
    local handLabelY = handY - ui.fontSmall:getHeight() - ui.pad * 0.4
    love.graphics.print("Jouw hand", area.x + ui.pad, handLabelY)

    local handY = area.y + ui.pad * 1.2 + ui.cardHeight * 0.45
    local view = computeHandView(pData)

    for index, card in ipairs(pData.hand or {}) do
        local x = view.xStart + (index - 1) * ui.cardSpace
        local y = handY
        drawCardImage(card, x, y, card.selected)
        if not ui.handView.hitboxes[index] then
            ui.handView.hitboxes[index] = { x = x, y = y, w = ui.cardWidth, h = ui.cardHeight }
        end
    end

    drawOverflowIndicators(area, view)

    -- Face-up row directly above hand cards
    local faceUp = pData.faceUp or {}
    if #faceUp > 0 then
        ui.faceUpView = { hitboxes = {} }
        local rowY = handY - ui.cardHeight * 0.55 - ui.pad * 0.6
        local totalW = #faceUp * ui.cardWidth + math.max(0, (#faceUp - 1)) * ui.cardPadding
        local xStart = area.x + (area.w - totalW) / 2
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.print("Open kaarten", area.x + ui.pad, rowY - ui.fontSmall:getHeight() - ui.pad * 0.2)
        for i, card in ipairs(faceUp) do
            local x = xStart + (i - 1) * ui.cardSpace
            drawCardImage(card, x, rowY, card.selected)
            ui.faceUpView.hitboxes[i] = { x = x, y = rowY, w = ui.cardWidth, h = ui.cardHeight }
        end
    end

    -- Face-down cards (blind)
    local faceDown = pData.faceDown or {}
    if #faceDown > 0 then
        local rowY = area.y + ui.pad * 0.6
        local totalW = #faceDown * ui.cardWidth * 0.6 + math.max(0, (#faceDown - 1)) * ui.cardPadding * 0.6
        local scale = (ui.cardHeight * 0.6) / cardBack:getHeight()
        local cardW = cardBack:getWidth() * scale
        local xStart = area.x + (area.w - totalW) / 2
        ui.faceDownView = { x = xStart, y = rowY, w = totalW, h = cardBack:getHeight() * scale }
        love.graphics.setColor(1, 1, 1, 0.75)
        love.graphics.print("Blinde kaarten", area.x + ui.pad, rowY - ui.fontSmall:getHeight() * 0.6)
        for i = 1, #faceDown do
            local x = xStart + (i - 1) * (cardW + ui.cardPadding * 0.6)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cardBack, x, rowY, 0, scale, scale)
        end
    else
        ui.faceDownView = nil
    end

    if not isMyTurn(ui.game) then
        love.graphics.setColor(0, 0, 0, 0.18)
        love.graphics.rectangle("fill", area.x, area.y, area.w, area.h, 18, 18)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("Wachten op andere speler", area.x, area.y + area.h - ui.fontSmall:getHeight() - ui.pad, area.w, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function drawTopOpponent(opponent)
    if not opponent then return end
    local area = ui.areas.topOpponent
    drawPanelBackground(area, 0.75)

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.print("Tegenstander", area.x + ui.pad, area.y + ui.pad * 0.6)

    local cards = opponent.hand or {}
    if #cards == 0 then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("Geen kaarten", area.x, area.y + area.h / 2 - ui.fontSmall:getHeight() / 2, area.w, "center")
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local scale = (ui.cardHeight * 0.65) / cardBack:getHeight()
    local cardW = cardBack:getWidth() * scale
    local totalW = #cards * cardW + math.max(0, (#cards - 1)) * ui.cardPadding * 0.5
    local xStart = area.x + (area.w - totalW) / 2
    local y = area.y + area.h / 2 - cardBack:getHeight() * scale / 2

    for i = 1, #cards do
        local x = xStart + (i - 1) * (cardW + ui.cardPadding * 0.5)
        love.graphics.setColor(1, 1, 1, 0.9 - (i - 1) * 0.02)
        love.graphics.draw(cardBack, x, y, 0, scale, scale)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPileStack(drawPile, x, y)
    local count = drawPile and drawPile.count and drawPile.count() or 0
    local layers = math.min(4, count)
    local scale = ui.cardHeight / cardBack:getHeight()
    for i = 1, layers do
        love.graphics.setColor(1, 1, 1, 0.25 + 0.15 * (i - 1))
        love.graphics.draw(cardBack, x - (i - 1) * ui.scale * 4, y - (i - 1) * ui.scale * 3, 0, scale, scale)
    end
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.printf("Trekstapel\n" .. count, x - ui.cardWidth * 0.2, y + ui.cardHeight + ui.pad * 0.2, ui.cardWidth * 1.4, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPot(pot, rect)
    if not rect then return end
    local x = rect.x
    local y = rect.y
    local top = pot[#pot]
    local prev = pot[#pot - 1]

    if prev and prev.afbeelding then
        love.graphics.setColor(1, 1, 1, 0.4)
        local scale = ui.cardHeight / prev.afbeelding:getHeight()
        love.graphics.draw(prev.afbeelding, x - ui.pad * 0.3, y + ui.pad * 0.3, 0, scale, scale)
    end

    if top and top.afbeelding then
        love.graphics.setColor(1, 1, 1, 1)
        local scale = ui.cardHeight / top.afbeelding:getHeight()
        love.graphics.draw(top.afbeelding, x, y, 0, scale, scale)
    else
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("line", x, y, ui.cardWidth, ui.cardHeight, 14, 14)
    end

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.printf("Aflegstapel\n" .. #pot, x - ui.cardWidth * 0.1, y + ui.cardHeight + ui.pad * 0.2, ui.cardWidth * 1.2, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function ui.button(x, y, w, h, label, enabled, id)
    local pointerX, pointerY = love.mouse.getPosition()
    local hovered = utils.inside(pointerX, pointerY, x, y, w, h)
    local radius = 12 * ui.scale
    local baseColor = {0.16, 0.41, 0.28}
    if id == "play" then baseColor = {0.12, 0.46, 0.32} end
    if not enabled then
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.25)
    elseif hovered then
        love.graphics.setColor(baseColor[1] + 0.08, baseColor[2] + 0.08, baseColor[3] + 0.08, 0.95)
    else
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.85)
    end
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)
    love.graphics.setColor(1, 1, 1, enabled and 0.92 or 0.55)
    love.graphics.setFont(ui.fontBig)
    love.graphics.printf(label, x, y + (h - ui.fontBig:getHeight()) / 2 - ui.scale * 2, w, "center")
    love.graphics.setColor(1, 1, 1, 1)

    ui.buttons[id] = { x = x, y = y, w = w, h = h, enabled = enabled, label = label }
end

local function drawCenterArea(pot, drawPile, buttons)
    local area = ui.areas.center
    drawPanelBackground(area, 0.85)

    local centerX = area.x + area.w / 2
    local centerY = area.y + area.h / 2

    local potRect = {
        x = centerX - ui.cardWidth / 2,
        y = centerY - ui.cardHeight / 2,
        w = ui.cardWidth,
        h = ui.cardHeight,
    }
    ui.centerState.pot = potRect

    local drawX = potRect.x - ui.cardWidth - ui.pad * 2
    local drawY = potRect.y
    ui.centerState.draw = { x = drawX, y = drawY, w = ui.cardWidth, h = ui.cardHeight }
    drawPileStack(drawPile, drawX, drawY)

    drawPot(pot, potRect)

    local buttonHeight = math.max(44 * ui.scale, ui.fontBig:getHeight() + ui.pad)
    local buttonWidth  = math.max(ui.cardWidth * 0.9, 160 * ui.scale)
    local gap          = ui.pad

    if ui.isCompact then
        local totalW = #buttons * buttonWidth + (#buttons - 1) * gap
        local startX = centerX - totalW / 2
        local y = potRect.y + ui.cardHeight + ui.pad * 1.6
        for i, btn in ipairs(buttons) do
            ui.button(startX + (i - 1) * (buttonWidth + gap), y, buttonWidth, buttonHeight, btn.label, btn.enabled, btn.id)
        end
        ui.centerState.buttonRow = { x = startX, y = y, w = totalW, h = buttonHeight }
    else
        local totalH = #buttons * buttonHeight + (#buttons - 1) * gap
        local startY = centerY - totalH / 2
        local x = potRect.x + ui.cardWidth + ui.pad * 2
        for i, btn in ipairs(buttons) do
            ui.button(x, startY + (i - 1) * (buttonHeight + gap), buttonWidth, buttonHeight, btn.label, btn.enabled, btn.id)
        end
        ui.centerState.buttonColumn = { x = x, y = startY, w = buttonWidth, h = totalH }
    end

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.7)
    local hintY = area.y + area.h - ui.fontSmall:getHeight() - ui.pad
    love.graphics.printf("Dubbelklik/tap om te spelen", area.x, hintY, area.w, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawStatusBar(lines)
    local area = ui.areas.statusBottom
    drawPanelBackground(area, 0.9)
    love.graphics.setFont(ui.fontSmall)

    local x = area.x + ui.pad
    local y = area.y + ui.pad * 0.6
    for _, line in ipairs(lines) do
        love.graphics.setColor(line.color[1], line.color[2], line.color[3], line.color[4] or 1)
        love.graphics.print(line.text, x, y)
        y = y + ui.fontSmall:getHeight() + ui.pad * 0.3
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function collectStatusLines(game)
    local lines = {}
    local mine = localPlayerId()
    local turn = isMyTurn(game)
    if game.state == "setupAISelect" then
        table.insert(lines, { text = "AI kiest open kaarten...", color = {1, 1, 1, 0.65} })
        return lines
    end
    if not turn then
        table.insert(lines, { text = string.format("Wachten op speler %d", game.currentPlayer or 1), color = {1, 1, 1, 0.75} })
    else
        table.insert(lines, { text = "Selecteer kaarten en kies 'Speel'", color = {1, 1, 1, 0.85} })
    end

    if game.invalidTimer and game.invalidTimer > 0 then
        table.insert(lines, { text = "Ongeldige zet", color = {0.95, 0.45, 0.45, 0.95} })
    end

    if game.state == "setupSelectOpen" then
        table.insert(lines, { text = "Kies drie open kaarten uit je hand", color = {1, 1, 1, 0.55} })
    elseif game.state == "playingHand" then
        table.insert(lines, { text = "Scroll met wiel of sleep voor meer kaarten", color = {1, 1, 1, 0.55} })
    elseif game.state == "playingBlind" then
        table.insert(lines, { text = "Tik op de blinde kaarten om te pakken", color = {1, 1, 1, 0.55} })
    end

    return lines
end

-- --- Public draw API ----------------------------------------------------------
function ui.draw(game, drawPile)
    ui.game = game
    local buttons = buildButtonState(game)
    drawHUDLeftTop(game)
    drawHUDRightTop(game)

    local opponent
    local myId = localPlayerId()
    for id, data in ipairs(player.players) do
        if id ~= myId then
            opponent = data
            break
        end
    end
    drawTopOpponent(opponent)

    drawCenterArea(game.pot, drawPile, buttons)
    drawHandBottom(player.players[myId] or { hand = {}, faceUp = {}, faceDown = {} })

    ui.statusLines = collectStatusLines(game)
    drawStatusBar(ui.statusLines)

    if game.showPotOverlay then
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, ui.viewportWidth, ui.viewportHeight)
        local overlayW = math.min(ui.viewportWidth - ui.safe * 2, 420 * ui.scale)
        local overlayH = math.min(ui.viewportHeight - ui.safe * 2, 520 * ui.scale)
        local overlayX = (ui.viewportWidth - overlayW) / 2
        local overlayY = (ui.viewportHeight - overlayH) / 2
        love.graphics.setColor(0.08, 0.2, 0.15, 0.92)
        love.graphics.rectangle("fill", overlayX, overlayY, overlayW, overlayH, 22, 22)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(ui.fontBig)
        love.graphics.printf("Aflegstapel", overlayX, overlayY + ui.pad, overlayW, "center")
        love.graphics.setFont(ui.fontSmall)
        local cardY = overlayY + ui.pad * 3 + ui.fontBig:getHeight()
        local col = 3
        local spacing = ui.cardWidth * 0.65
        for i, card in ipairs(game.pot) do
            local row = math.floor((i - 1) / col)
            local colIndex = (i - 1) % col
            local x = overlayX + ui.pad * 1.2 + colIndex * (spacing + ui.pad * 0.5)
            local y = cardY + row * (ui.cardHeight * 0.65 + ui.pad * 0.6)
            local scale = (ui.cardHeight * 0.65) / card.afbeelding:getHeight()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(card.afbeelding, x, y, 0, scale, scale)
        end
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("Klik om te sluiten", overlayX, overlayY + overlayH - ui.fontSmall:getHeight() - ui.pad, overlayW, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- --- Input helpers ------------------------------------------------------------
local function setScrollOffset(delta)
    if not ui.game then return end
    local pid = localPlayerId()
    local pData = player.players[pid]
    if not pData then return end
    computeHandView(pData)
    local newOffset = clamp(0, (pData.scrollOffset or 0) + delta, ui.handView.maxScroll or 0)
    pData.scrollOffset = newOffset
    ui.handView.offset = newOffset
end

local function triggerInvalid()
    if ui.game then
        ui.game.invalidTimer = 1.0
    end
end

local function triggerAction(id)
    local game = ui.game
    if not game then return end
    local mine = localPlayerId()

    if id == "play" then
        if not isMyTurn(game) then return end
        if game.state == "playingHand" then
            if net.isClient() then
                local payload = {}
                for _, card in ipairs(player.players[mine].hand) do
                    if card.selected then
                        table.insert(payload, { kleur = card.kleur, waarde = card.waarde })
                    end
                end
                if #payload > 0 then
                    net.play_from_client(payload)
                    utils.deselect_all(player.players[mine].hand)
                else
                    triggerInvalid()
                end
            else
                local ok = rules.play_selected_cards(game, mine)
                if ok then
                    utils.refill_hand(player.players[mine].hand, drawPileModule, config.CARDS_INHAND)
                    utils.update_phase_for_player(game, mine)
                else
                    triggerInvalid()
                end
            end
        elseif game.state == "playingOpen" then
            local ok = rules.play_selected_open(game, mine)
            if not ok then
                triggerInvalid()
            end
        end
    elseif id == "draw" then
        if not isMyTurn(game) then return end
        if net.isClient() then
            net.pickup_from_client()
        else
            utils.transfer_all_cards(player.players[mine].hand, game.pot)
            utils.deselect_all(player.players[mine].hand)
            game.nextMustBeUnder7 = false
            game.next_turn()
        end
    elseif id == "pass" then
        if not isMyTurn(game) then return end
        if net.isClient() then
            net.pass_from_client()
        else
            if game.extraTurn then
                game.extraTurn = false
                game.next_turn()
            end
        end
    end
end

local function handleButtonPress(x, y)
    for id, btn in pairs(ui.buttons) do
        if type(btn) == "table" and btn.x then
            if utils.inside(x, y, btn.x, btn.y, btn.w, btn.h) then
                if btn.enabled then
                    ui.buttons.active = id
                else
                    ui.buttons.active = nil
                end
                return true
            end
        end
    end
    ui.buttons.active = nil
    return false
end

local function handleButtonRelease(x, y)
    local id = ui.buttons.active
    if not id then return false end
    local btn = ui.buttons[id]
    ui.buttons.active = nil
    if btn and btn.enabled and utils.inside(x, y, btn.x, btn.y, btn.w, btn.h) then
        triggerAction(id)
        return true
    end
    return false
end

local function handlePotClick(x, y)
    local rect = ui.centerState.pot
    if rect and utils.inside(x, y, rect.x, rect.y, rect.w, rect.h) then
        if ui.game then
            ui.game.showPotOverlay = not ui.game.showPotOverlay
        end
        return true
    end
    return false
end

local function handleDrawPileClick(x, y)
    local rect = ui.centerState.draw
    if rect and utils.inside(x, y, rect.x, rect.y, rect.w, rect.h) then
        if ui.buttons.draw and ui.buttons.draw.enabled then
            triggerAction("draw")
        end
        return true
    end
    return false
end

local function handleHandClick(x, y)
    local pid = localPlayerId()
    local pData = player.players[pid]
    if not pData then return false end
    computeHandView(pData)
    if not ui.handView then return false end

    for index = #pData.hand, 1, -1 do
        local hit = ui.handView.hitboxes[index]
        if hit and utils.inside(x, y, hit.x, hit.y - ui.cardHeight * 0.08, hit.w, hit.h + ui.cardHeight * 0.1) then
            player.toggle_select(pData.hand, index, ui.game and ui.game.state)
            local now = love.timer.getTime()
            if ui.lastTap.index == index and now - ui.lastTap.time <= DOUBLE_TAP_TIME then
                triggerAction("play")
                ui.lastTap.index, ui.lastTap.time = nil, 0
            else
                ui.lastTap.index = index
                ui.lastTap.time = now
            end
            return true
        end
    end

    local area = ui.areas.handBottom
    if utils.inside(x, y, area.x, area.y, area.w, area.h) then
        ui.drag = {
            active = true,
            id = "mouse",
            lastX = x,
        }
        return true
    end

    return false
end

local function handleOpenRowClick(x, y)
    if not ui.faceUpView or not ui.game or ui.game.state ~= "playingOpen" then return false end
    if not isMyTurn(ui.game) then return false end
    local pid = localPlayerId()
    local faceUp = player.players[pid].faceUp
    for index = #faceUp, 1, -1 do
        local hit = ui.faceUpView.hitboxes[index]
        if hit and utils.inside(x, y, hit.x, hit.y, hit.w, hit.h) then
            player.toggle_select(faceUp, index, "open")
            return true
        end
    end
    return false
end

local function handleSetupOpenClick(x, y)
    if not ui.game or ui.game.state ~= "setupSelectOpen" then return false end
    local pid = localPlayerId()
    local pData = player.players[pid]
    if not pData then return false end
    computeHandView(pData)
    for index = #pData.hand, 1, -1 do
        local hit = ui.handView.hitboxes[index]
        if hit and utils.inside(x, y, hit.x, hit.y, hit.w, hit.h) then
            if #pData.faceUp >= config.SETUP_OPEN then
                return true
            end
            local card = table.remove(pData.hand, index)
            table.insert(pData.faceUp, card)
            if net.isClient() then
                net.send({
                    cmd = "OPEN_ADD",
                    id = pid,
                    card = { kleur = card.kleur, waarde = card.waarde, naam = card.naam },
                })
            end
            if #pData.faceUp == config.SETUP_OPEN then
                if ui.game.mode == "ai" then
                    ui.game.state = "setupAISelect"
                end
                if ui.game.mode == "multiplayer" and not net.isHost() then
                    net.send({ cmd = "OPEN_DONE", id = pid })
                else
                    ui.game.finalize_setup()
                end
            end
            return true
        end
    end
    return false
end

local function handleBlindClick(x, y)
    if not ui.game or ui.game.state ~= "playingBlind" then return false end
    if not isMyTurn(ui.game) then return false end
    if not ui.faceDownView then return false end
    if not utils.inside(x, y, ui.faceDownView.x, ui.faceDownView.y, ui.faceDownView.w, ui.faceDownView.h + ui.cardHeight * 0.1) then
        return false
    end
    local pid = localPlayerId()
    local stack = player.players[pid].faceDown
    if #stack == 0 then return true end
    local card = table.remove(stack, 1)
    ui.game.reveal.timer = 1.0
    ui.game.reveal.card = card
    ui.game.reveal.player = pid
    return true
end

local function handleOverlayClick()
    if ui.game and ui.game.showPotOverlay then
        ui.game.showPotOverlay = false
        return true
    end
    return false
end

function ui.mousepressed(x, y, button)
    if not ui.game or button ~= 1 then return false end
    if ui.game.reveal and ui.game.reveal.timer and ui.game.reveal.timer > 0 then
        return false
    end
    if not ui.areas or not ui.areas.center then
        ui.layout(love.graphics.getWidth(), love.graphics.getHeight())
    end
    if ui.game and ui.game.is_playing and not ui.game.is_playing() then
        return false
    end
    if handleOverlayClick() then return true end
    if handleButtonPress(x, y) then return true end
    if handlePotClick(x, y) then return true end
    if handleDrawPileClick(x, y) then return true end
    if handleSetupOpenClick(x, y) then return true end
    if handleBlindClick(x, y) then return true end
    if handleOpenRowClick(x, y) then return true end
    if handleHandClick(x, y) then return true end
    return false
end

function ui.mousereleased(x, y, button)
    if button ~= 1 then return false end
    if ui.drag.active then
        ui.drag = { active = false }
    end
    return handleButtonRelease(x, y)
end

function ui.mousemoved(x, y, dx, dy)
    if not ui.game or (ui.game.is_playing and not ui.game.is_playing()) then
        return
    end
    if ui.drag.active then
        setScrollOffset(-dx)
        ui.drag.lastX = x
    end
end

function ui.wheelmoved(dx, dy)
    if not ui.game or (ui.game.is_playing and not ui.game.is_playing()) then
        return false
    end
    if not ui.cardSpace then
        ui.layout(love.graphics.getWidth(), love.graphics.getHeight())
    end
    local factor = ui.cardSpace * 0.5
    if love.keyboard.isDown("lshift", "rshift") then
        factor = factor * 2
    end
    local delta = -(dx + dy) * factor
    if delta ~= 0 then
        setScrollOffset(delta)
        return true
    end
    return false
end

local function convertTouch(x, y)
    local w, h = love.graphics.getDimensions()
    return x * w, y * h
end

function ui.touchpressed(id, x, y)
    if ui.game and ui.game.reveal and ui.game.reveal.timer and ui.game.reveal.timer > 0 then
        return false
    end
    if not ui.areas or not ui.areas.center then
        ui.layout(love.graphics.getWidth(), love.graphics.getHeight())
    end
    if ui.game and ui.game.is_playing and not ui.game.is_playing() then
        return false
    end
    local px, py = convertTouch(x, y)
    if handleOverlayClick() then return true end
    local pressed = handleButtonPress(px, py)
    if pressed then
        if ui.buttons.active then
            ui.buttons.activeId = id
        else
            ui.buttons.activeId = nil
        end
        return true
    end
    if handlePotClick(px, py) then return true end
    if handleDrawPileClick(px, py) then return true end
    if handleSetupOpenClick(px, py) then return true end
    if handleBlindClick(px, py) then return true end
    if handleOpenRowClick(px, py) then return true end
    if handleHandClick(px, py) then
        ui.drag = { active = true, id = id, lastX = px }
        return true
    end
    return false
end

function ui.touchreleased(id, x, y)
    if ui.drag.active and ui.drag.id == id then
        ui.drag = { active = false }
    end
    local px, py = convertTouch(x, y)
    if ui.buttons.activeId == id then
        ui.buttons.activeId = nil
        handleButtonRelease(px, py)
    end
end

function ui.touchmoved(id, x, y, dx)
    if not ui.game or (ui.game.is_playing and not ui.game.is_playing()) then
        return
    end
    if ui.drag.active and ui.drag.id == id then
        local px = x * love.graphics.getWidth()
        local dxPixels = dx * love.graphics.getWidth()
        setScrollOffset(-dxPixels)
        ui.drag.lastX = px
    end
end

function ui.update(dt)
    if ui.game and ui.game.invalidTimer then
        ui.game.invalidTimer = math.max(0, ui.game.invalidTimer - dt)
    end
end

function ui.activate(action)
    triggerAction(action)
end

-- --- Legacy helpers -----------------------------------------------------------
function ui.draw_end_screen(winner, players)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(42))
    love.graphics.printf("Speler " .. winner .. " wint!", 0, h / 2 - 40, w, "center")
    local other = winner == 1 and 2 or 1
    local rest = players[other] and #players[other].hand or 0
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("Tegenstander heeft " .. rest .. " kaarten over", 0, h / 2, w, "center")
end

return ui
