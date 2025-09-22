--- Responsive in-game UI for Zweeds Pesten -------------------------------------
local ui = {}

--- Module dependencies -----------------------------------------------------------
local config         = require("config")
local player         = require("player")
local net            = require("net")
local rules          = require("rules")
local utils          = require("utils")
local drawPileModule = require("drawpile")

--- Assets & constants -----------------------------------------------------------
local cardBack       = love.graphics.newImage("png/back.png")
local DESIGN_W, DESIGN_H = 1280, 720
local SAFE_PAD_BASE      = 16
local DOUBLE_TAP_TIME    = 0.30

--- UI state ---------------------------------------------------------------------
ui.scale        = 1
ui.pad          = math.floor(config.cardPadding or 16)
ui.safe         = SAFE_PAD_BASE
ui.minTap       = 40
ui.cardW        = config.cardWidth or 140
ui.cardH        = config.cardHeight or 200

ui.fontBig      = nil
ui.fontSmall    = nil
ui.fontBigSize  = nil
ui.fontSmallSize= nil

ui.areas        = {}
ui.centerLayout = {}
ui.buttons      = { active = nil, activeId = nil }
ui.handHitboxes = {}
ui.faceUpHitboxes = {}
ui.faceDownRect = nil
ui.handMetrics  = { viewport = 0, visible = 0, step = 0, hitW = 0 }
ui.pointer      = { x = 0, y = 0 }
ui.lastTap      = { index = nil, time = 0 }
ui.statusLines  = {}
ui.compact      = false
ui.game         = nil
ui.debug        = false
ui.overlayRect  = nil
ui.drag         = { active = false }

--- Helpers ----------------------------------------------------------------------
local function clamp(minValue, value, maxValue)
    if maxValue < minValue then
        maxValue = minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ensureFonts()
    local bigSize   = math.max(22, math.floor(28 * ui.scale))
    local smallSize = math.max(16, math.floor(18 * ui.scale))

    if not ui.fontBig or ui.fontBigSize ~= bigSize then
        ui.fontBig = love.graphics.newFont(bigSize)
        ui.fontBigSize = bigSize
    end
    if not ui.fontSmall or ui.fontSmallSize ~= smallSize then
        ui.fontSmall = love.graphics.newFont(smallSize)
        ui.fontSmallSize = smallSize
    end
end

local function scissorRect(rect)
    if rect and rect.w > 0 and rect.h > 0 then
        love.graphics.setScissor(math.floor(rect.x), math.floor(rect.y), math.floor(rect.w), math.floor(rect.h))
    end
end

local function clearScissor()
    love.graphics.setScissor()
end

local function localPlayerId()
    return net.localId or 1
end

local function isMyTurn(game)
    return (game.currentPlayer or 1) == localPlayerId()
end

local function currentPlayerData()
    return player.players[localPlayerId()]
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

local function hasPlayableSelection(game, pid)
    local pData = player.players[pid]
    if not pData then return false end
    local selected = collectSelected(pData.hand)
    if game.state == "playingHand" then
        if #selected == 0 then return false end
        for _, card in ipairs(selected) do
            if not rules.is_speelbaar(card, game.pot, game.nextMustBeUnder7) then
                return false
            end
        end
        local first = utils.numeric_value(selected[1].waarde)
        for i = 2, #selected do
            if utils.numeric_value(selected[i].waarde) ~= first then
                return false
            end
        end
        return true
    elseif game.state == "playingOpen" then
        local openSelected = collectSelected(pData.faceUp)
        if #openSelected == 0 then return false end
        for _, card in ipairs(openSelected) do
            if not rules.is_speelbaar(card, game.pot, game.nextMustBeUnder7) then
                return false
            end
        end
        return true
    end
    return false
end

local function phaseLabel(state)
    local labels = {
        setupSelectOpen = "Kies open kaarten",
        setupAISelect   = "AI kiest open kaarten",
        playingHand     = "Handfase",
        playingOpen     = "Open kaarten",
        playingBlind    = "Blinde stapel",
        finished        = "Klaar",
    }
    return labels[state] or state or "Onbekend"
end

local function hintText(game, isTurn, playable)
    if game.state == "setupSelectOpen" then
        return "Selecteer drie kaarten om open neer te leggen."
    elseif game.state == "playingBlind" then
        return isTurn and "Raak de blinde stapel aan om een kaart te onthullen." or "Wachten op de tegenstander."
    elseif game.state == "playingOpen" then
        if not isTurn then return "De tegenstander is aan de beurt." end
        return playable and "Speel geselecteerde open kaart." or "Selecteer een open kaart om te spelen."
    else
        if not isTurn then return "De tegenstander is aan zet." end
        if playable then return "Speel de geselecteerde kaart(en)." end
        return "Selecteer kaarten met dezelfde waarde om te spelen."
    end
end

local function computeHandView(pData)
    local rect = ui.areas.handBottom
    if not rect or rect.w <= 0 then
        return nil
    end

    local metrics = ui.handMetrics
    local cards = pData.hand or {}
    local contentW = (#cards > 0) and (ui.cardW + (math.max(0, #cards - 1) * metrics.step)) or 0
    local maxScroll = math.max(0, contentW - metrics.viewport)
    local offset = clamp(0, pData.scrollOffset or 0, maxScroll)
    pData.scrollOffset = offset

    local xStart
    if contentW <= metrics.viewport then
        xStart = rect.x + (rect.w - contentW) / 2
    else
        xStart = rect.x + ui.pad - offset
    end

    return {
        xStart = xStart,
        contentW = contentW,
        maxScroll = maxScroll,
        viewport = metrics.viewport,
        step = metrics.step,
        hitW = metrics.hitW,
        rect = rect,
    }
end

local function formatStatusLines(game, isTurn)
    local lines = {}
    local topCard = utils.effective_top_card(game.pot)
    if topCard then
        table.insert(lines, string.format("Bovenste kaart: %s %s", topCard.waarde or "?", topCard.kleur or ""))
    else
        table.insert(lines, "Pot is leeg")
    end

    if game.nextMustBeUnder7 then
        table.insert(lines, "Volgende kaart ≤ 7")
    end

    if game.invalidTimer and game.invalidTimer > 0 then
        table.insert(lines, "Ongeldige zet")
    end

    if isTurn then
        table.insert(lines, "Dubbelklik/tap om direct te spelen")
    else
        table.insert(lines, "Scroll met wiel of sleep om de hand te bekijken")
    end

    return lines
end

local function drawPanelBackground(rect, alpha)
    alpha = alpha or 0.08
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", math.floor(rect.x), math.floor(rect.y), math.floor(rect.w), math.floor(rect.h), 18, 18)
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("line", math.floor(rect.x), math.floor(rect.y), math.floor(rect.w), math.floor(rect.h), 18, 18)
    love.graphics.setColor(1, 1, 1, 1)
end

--- Layout -----------------------------------------------------------------------
function ui.layout(w, h)
    ui.viewportWidth, ui.viewportHeight = w, h

    local scaleGuess = math.min(w / DESIGN_W, h / DESIGN_H)
    ui.scale = clamp(0.7, scaleGuess, 1.2)

    ui.safe   = math.floor(SAFE_PAD_BASE * ui.scale)
    ui.pad    = math.max(4, math.floor((config.cardPadding or 16) * ui.scale))
    ui.cardW  = math.floor((config.cardWidth or 140) * ui.scale)
    ui.cardH  = math.floor((config.cardHeight or 200) * ui.scale)
    ui.minTap = math.max(30, math.floor(40 * ui.scale))
    ui.compact = (w < (config.phoneBreakpoint or config.phoneBP or 900))

    ensureFonts()

    local contentW = math.max(0, w - 2 * ui.safe)
    local hudHeight = math.max(ui.minTap * 1.1, ui.fontBig:getHeight() + ui.fontSmall:getHeight() + ui.pad * 2)

    ui.areas.hudLeftTop = {
        x = ui.safe,
        y = ui.safe,
        w = math.floor((contentW - ui.pad) * 0.5),
        h = hudHeight,
    }

    ui.areas.hudRightTop = {
        x = ui.areas.hudLeftTop.x + ui.areas.hudLeftTop.w + ui.pad,
        y = ui.safe,
        w = contentW - ui.areas.hudLeftTop.w,
        h = hudHeight,
    }

    local statusH = math.max(ui.minTap * 0.75, ui.fontSmall:getHeight() + ui.pad * 1.2)
    ui.areas.statusBottom = {
        x = ui.safe,
        y = h - ui.safe - statusH,
        w = contentW,
        h = statusH,
    }

    local centerY = ui.areas.hudLeftTop.y + hudHeight + ui.pad
    local centerMaxH = ui.areas.statusBottom.y - ui.pad - centerY
    local centerH = math.max(ui.cardH + ui.pad * 2, math.min(math.floor(h * 0.32), centerMaxH))

    ui.areas.center = {
        x = ui.safe,
        y = centerY,
        w = contentW,
        h = centerH,
    }

    local bottomTop = centerY + centerH + ui.pad
    local bottomHeight = ui.areas.statusBottom.y - ui.pad - bottomTop

    local opponentH = 0
    if bottomHeight > 0 then
        opponentH = math.max(0, math.min(math.floor(bottomHeight * 0.4), ui.cardH + ui.pad))
    end

    ui.areas.topOpponent = {
        x = ui.safe,
        y = bottomTop,
        w = contentW,
        h = opponentH,
    }

    local handY = bottomTop + (opponentH > 0 and (opponentH + ui.pad) or 0)
    local handH = math.max(0, ui.areas.statusBottom.y - ui.pad - handY)
    ui.areas.handBottom = {
        x = ui.safe,
        y = handY,
        w = contentW,
        h = handH,
    }

    local rect = ui.areas.handBottom
    local viewport = math.max(1, rect.w - ui.pad * 2)
    local step = math.max(1, math.floor(ui.cardW * 0.6))
    local visible = math.max(1, math.floor(viewport / step))
    local hitW = math.max(ui.minTap, math.floor(step + ui.pad * 0.5))

    local prevButtons = ui.buttons or {}
    ui.handMetrics = {
        viewport = viewport,
        visible = visible,
        step = step,
        hitW = hitW,
    }
    ui.buttons = { active = prevButtons.active, activeId = prevButtons.activeId }
    ui.centerLayout = {}
    ui.handHitboxes = {}
    ui.faceUpHitboxes = {}
    ui.faceDownRect = nil
end

--- Card rendering ----------------------------------------------------------------
function ui.drawCard(card, x, y, opts)
    opts = opts or {}
    x, y = math.floor(x), math.floor(y)

    local targetH = math.floor(opts.height or ui.cardH)
    if targetH < 1 then targetH = 1 end
    local image
    if opts.back or not card or not card.afbeelding then
        image = cardBack
    else
        image = card.afbeelding
    end

    local scale = targetH / image:getHeight()
    local targetW = math.floor(image:getWidth() * scale + 0.5)

    love.graphics.setColor(1, 1, 1, opts.dimmed and 0.4 or 1)
    love.graphics.draw(image, x, y, 0, scale, scale)

    if opts.selected then
        love.graphics.setColor(0.96, 0.78, 0.28, 0.95)
        love.graphics.setLineWidth(math.max(2, math.floor(3 * ui.scale)))
        love.graphics.rectangle("line", x, y, targetW, targetH, math.floor(14 * ui.scale), math.floor(14 * ui.scale))
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

--- HUD rendering -----------------------------------------------------------------
local function drawHUDLeftTop(game)
    local area = ui.areas.hudLeftTop
    if not area or area.w <= 0 or area.h <= 0 then return end

    drawPanelBackground(area, 0.12)

    love.graphics.setFont(ui.fontBig)
    love.graphics.setColor(1, 1, 1, 0.92)
    love.graphics.printf(string.format("Ronde %d", game.ronde or 1), area.x + ui.pad, area.y + ui.pad * 0.6, area.w - ui.pad * 2, "left")

    local turnText
    local turnId = game.currentPlayer or 1
    if turnId == localPlayerId() then
        turnText = "Jij bent aan zet"
    else
        turnText = string.format("Speler %d is aan zet", turnId)
    end

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf(turnText, area.x + ui.pad, area.y + ui.pad + ui.fontBig:getHeight() * 0.7, area.w - ui.pad * 2, "left")

    local phase = phaseLabel(game.state)
    love.graphics.printf(phase, area.x + ui.pad, area.y + ui.pad + ui.fontBig:getHeight() * 0.7 + ui.fontSmall:getHeight() + ui.pad * 0.4, area.w - ui.pad * 2, "left")

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHUDRightTop(game)
    local area = ui.areas.hudRightTop
    if not area or area.w <= 0 or area.h <= 0 then return end

    drawPanelBackground(area, 0.12)

    local mode
    if net.isMultiplayer() then
        mode = net.isHost() and "Host" or "Client"
    else
        mode = "Singleplayer"
    end

    love.graphics.setFont(ui.fontBig)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(mode, area.x + ui.pad, area.y + ui.pad * 0.6, area.w - ui.pad * 2, "right")

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.72)

    if net.isMultiplayer() then
        local id = net.localId or 1
        love.graphics.printf(string.format("Speler %d / %d", id, game.maxPlayers or 2), area.x + ui.pad, area.y + ui.pad + ui.fontBig:getHeight() * 0.7, area.w - ui.pad * 2, "right")
        love.graphics.printf("Verbinding actief", area.x + ui.pad, area.y + ui.pad + ui.fontBig:getHeight() * 0.7 + ui.fontSmall:getHeight() + ui.pad * 0.4, area.w - ui.pad * 2, "right")
    else
        love.graphics.printf("Speel tegen de AI", area.x + ui.pad, area.y + ui.pad + ui.fontBig:getHeight() * 0.7, area.w - ui.pad * 2, "right")
        love.graphics.printf("Kaarten in deck: " .. tostring(drawPileModule.count()), area.x + ui.pad, area.y + ui.pad + ui.fontBig:getHeight() * 0.7 + ui.fontSmall:getHeight() + ui.pad * 0.4, area.w - ui.pad * 2, "right")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--- Buttons ----------------------------------------------------------------------
local function buttonEnabledStates(game)
    local pid = localPlayerId()
    local turn = isMyTurn(game)
    local playable = hasPlayableSelection(game, pid)

    local states = {
        play = turn and playable,
        draw = turn and (game.state == "playingHand" or game.state == "playingOpen"),
        pass = turn and game.extraTurn,
    }

    if game.state == "setupSelectOpen" then
        states.draw = false
        states.pass = false
        states.play = false
    elseif game.state == "playingBlind" then
        states.play = false
        states.draw = false
        states.pass = false
    end

    return states, playable
end

function ui.button(x, y, w, h, label, enabled, id)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    local pointer = ui.pointer
    local hovered = pointer.x >= x and pointer.x <= x + w and pointer.y >= y and pointer.y <= y + h
    local active = ui.buttons.active == id

    local baseColor = {0.14, 0.33, 0.24}
    if id == "play" then baseColor = {0.12, 0.46, 0.32} end
    if not enabled then
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.25)
    elseif hovered then
        love.graphics.setColor(clamp01(baseColor[1] + 0.12), clamp01(baseColor[2] + 0.12), clamp01(baseColor[3] + 0.12), 0.95)
    else
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.85)
    end

    local radius = math.floor(16 * ui.scale)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)

    love.graphics.setFont(ui.fontBig)
    love.graphics.setColor(1, 1, 1, active and 0.95 or (enabled and 0.88 or 0.45))
    love.graphics.printf(label, x + 6, y + (h - ui.fontBig:getHeight()) / 2, w - 12, "center")
    love.graphics.setColor(1, 1, 1, 1)

    ui.buttons[id] = { x = x, y = y, w = w, h = h, enabled = enabled, label = label }
end

local function drawButtonsColumn(area, states)
    local labels = {
        play = "Speel",
        draw = "Pakken",
        pass = "Pas",
    }

    local buttonH = math.max(ui.minTap, math.floor(ui.fontBig:getHeight() + ui.pad))
    local totalH = buttonH * 3 + ui.pad * 2
    local startY = math.max(area.y + ui.pad, area.y + (area.h - totalH) / 2)
    local width = math.max(ui.minTap * 2, area.w - ui.pad * 2)
    local x = area.x + (area.w - width) / 2

    for index, id in ipairs({"play", "draw", "pass"}) do
        local rectY = startY + (index - 1) * (buttonH + ui.pad)
        ui.button(x, rectY, width, buttonH, labels[id], states[id], id)
    end
end

local function drawButtonsRow(area, states)
    local labels = {
        play = "Speel",
        draw = "Pakken",
        pass = "Pas",
    }

    local buttonH = math.max(ui.minTap, math.floor(ui.fontBig:getHeight() + ui.pad))
    local gap = ui.pad
    local buttonCount = 3
    local usableW = area.w - ui.pad * 2 - gap * (buttonCount - 1)
    local width = math.max(ui.minTap * 1.8, usableW / buttonCount)
    local totalW = width * buttonCount + gap * (buttonCount - 1)
    local startX = area.x + (area.w - totalW) / 2
    local y = area.y + (area.h - buttonH) / 2

    for index, id in ipairs({"play", "draw", "pass"}) do
        local rectX = startX + (index - 1) * (width + gap)
        ui.button(rectX, y, width, buttonH, labels[id], states[id], id)
    end
end

--- Center area ------------------------------------------------------------------
local function drawDrawPile(layout, count)
    if not layout then return end
    local layers = math.min(4, count)
    for i = layers, 1, -1 do
        local offset = (i - 1) * math.floor(ui.scale * 4)
        love.graphics.setColor(1, 1, 1, 0.25 + 0.15 * i)
        ui.drawCard(nil, layout.x + offset, layout.y - offset, { back = true })
    end
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.printf(string.format("Deck: %d", count), layout.x - ui.pad, layout.y + ui.cardH + ui.pad * 0.3, ui.cardW + ui.pad * 2, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPot(layout, pot)
    if not layout then return end
    local top = pot[#pot]
    local prev = pot[#pot - 1]

    if prev and prev.afbeelding then
        love.graphics.setColor(1, 1, 1, 0.4)
        ui.drawCard(prev, layout.x - math.floor(ui.pad * 0.3), layout.y + math.floor(ui.pad * 0.3))
    end

    love.graphics.setColor(1, 1, 1, 1)
    if top then
        ui.drawCard(top, layout.x, layout.y)
    else
        ui.drawCard(nil, layout.x, layout.y, { back = true, dimmed = true })
    end
end

local function drawCenterArea(game)
    local area = ui.areas.center
    if not area or area.w <= 0 or area.h <= 0 then return end

    drawPanelBackground(area, 0.16)
    scissorRect(area)

    local states, playable = buttonEnabledStates(game)
    local drawCount = drawPileModule.count()
    local hint = hintText(game, isMyTurn(game), playable)

    if ui.compact then
        local availableW = area.w - ui.pad * 2
        local gap = math.max(ui.pad * 0.5, (availableW - ui.cardW * 2) / 3)
        if gap < 0 then gap = ui.pad * 0.3 end
        local totalW = ui.cardW * 2 + gap
        local startX = area.x + (area.w - totalW) / 2
        local cardY = area.y + math.max(ui.pad, (area.h - ui.cardH - ui.minTap - ui.pad * 2) / 2)

        local drawLayout = { x = startX, y = cardY }
        local potLayout  = { x = startX + ui.cardW + gap, y = cardY }

        drawDrawPile(drawLayout, drawCount)
        drawPot(potLayout, game.pot)

        local rowHeight = math.max(ui.minTap, math.floor(ui.fontBig:getHeight() + ui.pad))
        local rowY = area.y + area.h - rowHeight - ui.pad
        drawButtonsRow({ x = area.x, y = rowY, w = area.w, h = rowHeight }, states)

        ui.centerLayout.draw = { x = drawLayout.x, y = drawLayout.y, w = ui.cardW, h = ui.cardH }
        ui.centerLayout.pot = { x = potLayout.x, y = potLayout.y, w = ui.cardW, h = ui.cardH }
        ui.centerLayout.buttons = { x = area.x, y = rowY, w = area.w, h = rowHeight }
    else
        local colW = math.floor(area.w / 3)
        local cardY = area.y + (area.h - ui.cardH) / 2

        local drawLayout = { x = area.x + (colW - ui.cardW) / 2, y = cardY }
        local potLayout  = { x = area.x + colW + (colW - ui.cardW) / 2, y = cardY }
        local buttonsArea = { x = area.x + colW * 2, y = area.y, w = area.w - colW * 2, h = area.h }

        drawDrawPile(drawLayout, drawCount)
        drawPot(potLayout, game.pot)
        drawButtonsColumn(buttonsArea, states)

        ui.centerLayout.draw = { x = drawLayout.x, y = drawLayout.y, w = ui.cardW, h = ui.cardH }
        ui.centerLayout.pot = { x = potLayout.x, y = potLayout.y, w = ui.cardW, h = ui.cardH }
        ui.centerLayout.buttons = buttonsArea
    end

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.72)
    love.graphics.printf(hint, area.x + ui.pad, area.y + area.h - ui.fontSmall:getHeight() - ui.pad * 0.6, area.w - ui.pad * 2, "center")
    love.graphics.setColor(1, 1, 1, 1)

    clearScissor()
end

local function drawPotOverlay(game)
    if not game.showPotOverlay or #(game.pot or {}) == 0 then
        ui.overlayRect = nil
        return
    end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local overlayW = math.min(ui.cardW * 4 + ui.pad * 4, w * 0.7)
    local overlayH = math.min(ui.cardH * 2 + ui.pad * 5 + ui.fontSmall:getHeight() * 2, h * 0.75)
    local x = (w - overlayW) / 2
    local y = (h - overlayH) / 2
    ui.overlayRect = { x = x, y = y, w = overlayW, h = overlayH }

    love.graphics.setColor(0.1, 0.2, 0.16, 0.92)
    love.graphics.rectangle("fill", x, y, overlayW, overlayH, 22, 22)
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("line", x, y, overlayW, overlayH, 22, 22)

    love.graphics.setFont(ui.fontBig)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("Pot kaarten", x + ui.pad, y + ui.pad, overlayW - ui.pad * 2, "center")

    local cardsPerRow = math.max(1, math.floor((overlayW - ui.pad * 2) / (ui.cardW * 0.9)))
    local scaleH = math.max(math.floor(ui.cardH * 0.85), math.floor(ui.minTap * 1.2))
    local gap = ui.pad * 0.5
    local startY = y + ui.pad * 2 + ui.fontBig:getHeight()
    local pot = game.pot

    for index = #pot, 1, -1 do
        local card = pot[index]
        local pos = #pot - index
        local row = math.floor(pos / cardsPerRow)
        local col = pos % cardsPerRow
        local drawX = x + ui.pad + col * (ui.cardW + gap)
        local drawY = startY + row * (scaleH + gap)
        ui.drawCard(card, drawX, drawY, { height = scaleH })
    end

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("Klik om te sluiten", x + ui.pad, y + overlayH - ui.fontSmall:getHeight() - ui.pad, overlayW - ui.pad * 2, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

--- Hand drawing -----------------------------------------------------------------
local function drawFaceDownRow(pData, startY)
    local rect = ui.areas.handBottom
    local faceDown = pData.faceDown or {}
    if #faceDown == 0 then
        ui.faceDownRect = nil
        return startY
    end

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.printf("Blinde stapel", rect.x, startY - ui.fontSmall:getHeight() - ui.pad * 0.2, rect.w, "center")
    love.graphics.setColor(1, 1, 1, 1)

    local scaleH = math.floor(ui.cardH * 0.65)
    local scaleW = math.floor(ui.cardW * 0.65)
    local gap = math.floor(ui.pad * 0.4)
    local stride = math.floor(scaleW * 0.6) + gap
    local totalW = scaleW + math.max(0, (#faceDown - 1)) * stride
    local xStart = rect.x + (rect.w - totalW) / 2

    for i = 1, #faceDown do
        local x = xStart + (i - 1) * stride
        ui.drawCard(nil, x, startY, { back = true, height = scaleH })
    end

    ui.faceDownRect = { x = xStart, y = startY, w = totalW, h = scaleH }
    return startY + scaleH + ui.pad
end

local function drawFaceUpRow(pData, startY)
    local rect = ui.areas.handBottom
    local faceUp = pData.faceUp or {}
    ui.faceUpHitboxes = {}
    if #faceUp == 0 then
        return startY
    end

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.printf("Open kaarten", rect.x + ui.pad, startY, rect.w - ui.pad * 2, "left")
    love.graphics.setColor(1, 1, 1, 1)

    local rowY = startY + ui.fontSmall:getHeight() + ui.pad * 0.2
    local gap = math.floor(ui.pad * 0.4)
    local stride = ui.cardW + gap
    local totalW = ui.cardW + math.max(0, (#faceUp - 1)) * stride
    local xStart = rect.x + (rect.w - totalW) / 2

    for index, card in ipairs(faceUp) do
        local x = xStart + (index - 1) * stride
        ui.drawCard(card, x, rowY, { selected = card.selected })
        ui.faceUpHitboxes[index] = { x = x, y = rowY, w = ui.cardW, h = ui.cardH }
    end

    return rowY + ui.cardH + ui.pad
end

local function drawOverflowIndicators(rect, view)
    if not view or view.contentW <= view.viewport + 1 then return end
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", rect.x, rect.y, ui.pad, rect.h)
    love.graphics.rectangle("fill", rect.x + rect.w - ui.pad, rect.y, ui.pad, rect.h)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHandBottom(game, pData)
    local rect = ui.areas.handBottom
    if not rect or rect.w <= 0 or rect.h <= 0 then return end

    drawPanelBackground(rect, 0.18)
    scissorRect(rect)

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("Jouw hand", rect.x + ui.pad, rect.y + ui.pad * 0.4, rect.w - ui.pad * 2, "left")
    love.graphics.setColor(1, 1, 1, 1)

    local cursorY = rect.y + ui.pad * 1.4
    cursorY = drawFaceDownRow(pData, cursorY)
    cursorY = drawFaceUpRow(pData, cursorY)

    local view = computeHandView(pData)
    if not view then
        clearScissor()
        return
    end

    local baseline = math.max(cursorY, rect.y + rect.h - ui.cardH - ui.pad)
    baseline = math.min(baseline, rect.y + rect.h - ui.cardH)
    local lift = math.floor(ui.pad * 0.7)

    ui.handHitboxes = {}
    local selectedLater = {}

    for index, card in ipairs(pData.hand or {}) do
        local x = view.xStart + (index - 1) * view.step
        local hitW = view.hitW
        local hitX = x - (hitW - ui.cardW) / 2
        hitX = clamp(rect.x, hitX, rect.x + rect.w - hitW)
        local selected = card.selected
        local drawY = selected and (baseline - lift) or baseline

        ui.handHitboxes[index] = { x = hitX, y = drawY, w = hitW, h = ui.cardH + lift }

        if x + ui.cardW > rect.x and x < rect.x + rect.w then
            if selected then
                table.insert(selectedLater, { card = card, x = x, y = drawY })
            else
                ui.drawCard(card, x, drawY)
            end
        end
    end

    for _, info in ipairs(selectedLater) do
        ui.drawCard(info.card, info.x, info.y, { selected = true })
    end

    drawOverflowIndicators(rect, view)
    clearScissor()

    if not isMyTurn(game) then
        love.graphics.setColor(0, 0, 0, 0.18)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 18, 18)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("Wachten op andere speler", rect.x, rect.y + rect.h - ui.fontSmall:getHeight() - ui.pad, rect.w, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function drawTopOpponent(opponent)
    local rect = ui.areas.topOpponent
    if not rect or rect.w <= 0 or rect.h <= 0 then return end

    drawPanelBackground(rect, 0.12)
    scissorRect(rect)

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.printf("Tegenstander", rect.x + ui.pad, rect.y + ui.pad * 0.4, rect.w - ui.pad * 2, "left")
    love.graphics.setColor(1, 1, 1, 1)

    local cards = opponent and opponent.hand or {}
    if not cards or #cards == 0 then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("Geen kaarten", rect.x, rect.y + rect.h / 2 - ui.fontSmall:getHeight() / 2, rect.w, "center")
        love.graphics.setColor(1, 1, 1, 1)
        clearScissor()
        return
    end

    local available = math.max(0, rect.w - 2 * ui.pad)
    local stride = math.min(ui.cardW, available / #cards)
    local totalW = ui.cardW + math.max(0, (#cards - 1)) * stride
    local startX = rect.x + (rect.w - totalW) / 2
    local y = rect.y + rect.h / 2 - ui.cardH / 2

    for i = 1, #cards do
        local x = startX + (i - 1) * stride
        ui.drawCard(nil, x, y, { back = true })
    end

    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(string.format("%d kaarten", #cards), rect.x, rect.y + rect.h - ui.fontSmall:getHeight() - ui.pad, rect.w, "center")
    love.graphics.setColor(1, 1, 1, 1)

    clearScissor()
end

--- Status bar -------------------------------------------------------------------
local function drawStatusBar(lines)
    local rect = ui.areas.statusBottom
    if not rect or rect.w <= 0 or rect.h <= 0 then return end

    drawPanelBackground(rect, 0.14)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.82)

    local text = table.concat(lines, "  •  ")
    love.graphics.printf(text, rect.x + ui.pad, rect.y + (rect.h - ui.fontSmall:getHeight()) / 2, rect.w - ui.pad * 2, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

--- Debug overlay ----------------------------------------------------------------
local function drawDebugOverlay()
    if not ui.debug then return end
    love.graphics.setColor(1, 0.2, 0.2, 0.6)
    for name, rect in pairs(ui.areas) do
        if rect and rect.w > 0 and rect.h > 0 then
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
            love.graphics.print(name, rect.x + 4, rect.y + 4)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

--- Public draw ------------------------------------------------------------------
function ui.draw(game, drawPile)
    ui.game = game
    local me = currentPlayerData()
    local opponent
    if localPlayerId() == 1 then
        opponent = player.players[2]
    else
        opponent = player.players[1]
    end
    local turn = isMyTurn(game)

    drawHUDLeftTop(game)
    drawHUDRightTop(game)
    drawCenterArea(game)
    drawTopOpponent(opponent)
    if me then
        drawHandBottom(game, me)
    end

    local status = formatStatusLines(game, turn)
    drawStatusBar(status)
    drawPotOverlay(game)
    drawDebugOverlay()
end

--- Interaction helpers ----------------------------------------------------------
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
        if type(id) == "string" and type(btn) == "table" and btn.x and utils.inside(x, y, btn.x, btn.y, btn.w, btn.h) then
            if btn.enabled then
                ui.buttons.active = id
            else
                ui.buttons.active = nil
            end
            return true
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

local function handleOverlayClick(x, y)
    if not ui.game or not ui.game.showPotOverlay then return false end
    ui.game.showPotOverlay = false
    return true
end

local function handlePotClick(x, y)
    local rect = ui.centerLayout.pot
    if rect and utils.inside(x, y, rect.x, rect.y, rect.w, rect.h) then
        ui.game.showPotOverlay = not ui.game.showPotOverlay
        return true
    end
    return false
end

local function handleDrawPileClick(x, y)
    local rect = ui.centerLayout.draw
    if rect and utils.inside(x, y, rect.x, rect.y, rect.w, rect.h) then
        local drawBtn = ui.buttons.draw
        if drawBtn and drawBtn.enabled then
            triggerAction("draw")
        end
        return true
    end
    return false
end

local function handleFaceUpClick(x, y)
    if not ui.game or ui.game.state ~= "playingOpen" then return false end
    if not isMyTurn(ui.game) then return false end
    for index = #ui.faceUpHitboxes, 1, -1 do
        local hit = ui.faceUpHitboxes[index]
        if hit and utils.inside(x, y, hit.x, hit.y, hit.w, hit.h) then
            local faceUp = player.players[localPlayerId()].faceUp
            player.toggle_select(faceUp, index, "open")
            return true
        end
    end
    return false
end

local function handleBlindClick(x, y)
    if not ui.game or ui.game.state ~= "playingBlind" then return false end
    if not isMyTurn(ui.game) then return false end
    if not ui.faceDownRect then return false end
    if not utils.inside(x, y, ui.faceDownRect.x, ui.faceDownRect.y, ui.faceDownRect.w, ui.faceDownRect.h + ui.cardH * 0.1) then
        return false
    end

    local stack = player.players[localPlayerId()].faceDown
    if #stack == 0 then return true end
    local card = table.remove(stack, 1)
    ui.game.reveal = ui.game.reveal or {}
    ui.game.reveal.timer = 1.0
    ui.game.reveal.card = card
    ui.game.reveal.player = localPlayerId()
    return true
end

local function handleSetupOpenClick(x, y)
    if not ui.game or ui.game.state ~= "setupSelectOpen" then return false end
    local pData = currentPlayerData()
    if not pData then return false end
    for index = #ui.handHitboxes, 1, -1 do
        local hit = ui.handHitboxes[index]
        if hit and utils.inside(x, y, hit.x, hit.y - ui.cardH * 0.1, hit.w, hit.h + ui.cardH * 0.2) then
            if #pData.faceUp >= config.SETUP_OPEN then
                return true
            end
            local card = table.remove(pData.hand, index)
            table.insert(pData.faceUp, card)
            if net.isClient() then
                net.send({
                    cmd = "OPEN_ADD",
                    id = localPlayerId(),
                    card = { kleur = card.kleur, waarde = card.waarde, naam = card.naam },
                })
            end
            if #pData.faceUp == config.SETUP_OPEN then
                if ui.game.mode == "ai" then
                    ui.game.state = "setupAISelect"
                end
                if ui.game.mode == "multiplayer" and not net.isHost() then
                    net.send({ cmd = "OPEN_DONE", id = localPlayerId() })
                else
                    ui.game.finalize_setup()
                end
            end
            return true
        end
    end
    return false
end

local function handleHandClick(x, y)
    local pData = currentPlayerData()
    if not pData then return false end
    for index = #ui.handHitboxes, 1, -1 do
        local hit = ui.handHitboxes[index]
        if hit and utils.inside(x, y, hit.x, hit.y - ui.cardH * 0.1, hit.w, hit.h + ui.cardH * 0.2) then
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
    if area and utils.inside(x, y, area.x, area.y, area.w, area.h) then
        ui.drag = { active = true, id = "mouse", lastX = x }
        return true
    end

    return false
end

local function setScrollOffset(delta)
    local pData = currentPlayerData()
    if not pData then return end
    local view = computeHandView(pData)
    if not view then return end
    local newOffset = clamp(0, (pData.scrollOffset or 0) + delta, view.maxScroll)
    pData.scrollOffset = newOffset
end

--- Love callbacks ---------------------------------------------------------------
function ui.mousepressed(x, y, button)
    if button ~= 1 or not ui.game then return false end
    if ui.game.reveal and ui.game.reveal.timer and ui.game.reveal.timer > 0 then
        return false
    end

    if handleOverlayClick(x, y) then return true end
    if handleButtonPress(x, y) then return true end
    if handlePotClick(x, y) then return true end
    if handleDrawPileClick(x, y) then return true end
    if handleSetupOpenClick(x, y) then return true end
    if handleBlindClick(x, y) then return true end
    if handleFaceUpClick(x, y) then return true end
    if handleHandClick(x, y) then return true end
    return false
end

function ui.mousereleased(x, y, button)
    if button ~= 1 then return false end
    if ui.drag and ui.drag.active then
        ui.drag = { active = false }
    end
    return handleButtonRelease(x, y)
end

function ui.mousemoved(x, y, dx, dy)
    ui.pointer.x, ui.pointer.y = x, y
    if ui.drag and ui.drag.active then
        setScrollOffset(-dx)
        ui.drag.lastX = x
    end
end

function ui.wheelmoved(dx, dy)
    if not ui.game then return false end
    local step = ui.handMetrics.step > 0 and ui.handMetrics.step or math.floor(ui.cardW * 0.6)
    local factor = math.max(ui.minTap, step) * 0.5
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
    local px, py = convertTouch(x, y)
    if handleOverlayClick(px, py) then return true end
    if handleButtonPress(px, py) then
        ui.buttons.activeId = id
        return true
    end

    if handlePotClick(px, py) then return true end
    if handleDrawPileClick(px, py) then return true end
    if handleSetupOpenClick(px, py) then return true end
    if handleBlindClick(px, py) then return true end
    if handleFaceUpClick(px, py) then return true end
    if handleHandClick(px, py) then
        ui.drag = { active = true, id = id, lastX = px }
        return true
    end
    return false
end

function ui.touchmoved(id, x, y, dx)
    if ui.drag and ui.drag.active and ui.drag.id == id then
        local screenW = love.graphics.getWidth()
        local dxPixels = dx * screenW
        setScrollOffset(-dxPixels)
    end
end

function ui.touchreleased(id, x, y)
    if ui.drag and ui.drag.active and ui.drag.id == id then
        ui.drag = { active = false }
    end
    if ui.buttons.activeId == id then
        local px, py = convertTouch(x, y)
        ui.buttons.activeId = nil
        handleButtonRelease(px, py)
    end
end

function ui.update(dt)
    if ui.game and ui.game.invalidTimer then
        ui.game.invalidTimer = math.max(0, ui.game.invalidTimer - dt)
    end
    if ui.game and ui.game.reveal and ui.game.reveal.timer then
        ui.game.reveal.timer = math.max(0, ui.game.reveal.timer - dt)
    end
    if ui.game and ui.game.showPotOverlay and ui.game.reveal and ui.game.reveal.timer and ui.game.reveal.timer > 0 then
        ui.game.showPotOverlay = false
    end
end

function ui.activate(action)
    triggerAction(action)
end

function ui.toggleDebug()
    ui.debug = not ui.debug
end

--- Legacy helpers ---------------------------------------------------------------
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

