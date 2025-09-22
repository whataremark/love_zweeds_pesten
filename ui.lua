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

local DOUBLE_TAP_TIME = 0.30

ui.scale      = 1
ui.pad        = 16
ui.safe       = 16
ui.minTap     = config.minTap or 40

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
ui.debug       = false
ui.handRects   = { player = nil, opponent = nil }
ui.handLayout  = { step = 0, visible = 0, viewport = 0 }


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

    local c = config
    local scaleGuess = math.min(w / DESIGN_W, h / DESIGN_H)
    ui.scale = clamp(c.minScale, scaleGuess, c.maxScale)
    ui.safe  = math.floor(c.safePad * ui.scale)
    ui.pad   = math.floor(c.cardPad * ui.scale)
    ui.minTap = math.max(1, math.floor(c.minTap * ui.scale))

    ui.cardW = math.floor(c.cardBaseW * ui.scale)
    ui.cardH = math.floor(c.cardBaseH * ui.scale)

    ui.compact = (w < (c.phoneBP or 800))

    ensureFonts()
    resetInteractionCaches()

    ui.areas = ui.areas or {}
    ui.areas.hudL = {
        x = ui.safe,
        y = ui.safe,
        w = math.max(0, math.floor(w * 0.48) - 2 * ui.safe),
        h = math.max(ui.fontBig:getHeight() + ui.fontSmall:getHeight() + ui.pad, math.floor(h * 0.12))
    }
    ui.areas.hudR = {
        x = math.floor(w * 0.52),
        y = ui.safe,
        w = math.max(0, math.floor(w * 0.48) - ui.safe),
        h = ui.areas.hudL.h
    }

    local midY  = math.floor(h * 0.24)
    local midH  = math.floor(h * 0.36)
    local statusH = math.max(math.floor(ui.fontSmall:getHeight() * 1.6 + ui.pad), ui.minTap)
    ui.areas.statusBottom = {
        x = ui.safe,
        y = h - statusH - ui.safe,
        w = math.max(0, w - 2 * ui.safe),
        h = statusH
    }

    ui.areas.center = { x = ui.safe, y = midY, w = math.max(0, w - 2 * ui.safe), h = math.max(midH, ui.cardH + ui.pad * 2) }

    local bottomTop = midY + midH + ui.pad
    local bottomBottom = ui.areas.statusBottom.y - ui.pad
    local bottomH = math.max(0, bottomBottom - bottomTop)
    ui.areas.bottom = {
        x = ui.safe,
        y = bottomTop,
        w = math.max(0, w - 2 * ui.safe),
        h = bottomH
    }

    -- Hand rectangles derived from bottom area
    local bottom = ui.areas.bottom
    local desiredHandH = math.floor(ui.cardH * 2.2 + ui.pad * 3)
    local available = math.max(0, ui.areas.bottom.h)
    local minHand = math.min(available, ui.cardH + ui.pad)
    local idealHand = math.min(available, math.max(desiredHandH, ui.cardH + 2 * ui.pad))
    local handH = math.max(minHand, idealHand)
    local oppH = math.max(0, bottom.h - handH - ui.pad)
    ui.handRects.player = {
        x = bottom.x,
        y = bottom.y + math.max(0, bottom.h - handH),
        w = bottom.w,
        h = handH
    }
    ui.handRects.opponent = {
        x = bottom.x,
        y = bottom.y,
        w = bottom.w,
        h = oppH
    }

    local viewportW = math.max(1, ui.handRects.player.w - 2 * ui.pad)
    local visible = math.max(6, math.floor(viewportW / math.max(1, ui.cardW * 0.6)))
    local step = math.floor(math.min(ui.cardW, viewportW / math.max(1, visible)))
    if step < 1 then step = 1 end

    ui.handLayout = {
        step = step,
        visible = visible,
        viewport = viewportW,
        hitW = math.max(ui.minTap, step)
    }

    -- compatibility aliases for existing helper code
    ui.areas.hudLeftTop = ui.areas.hudL
    ui.areas.hudRightTop = ui.areas.hudR
    ui.areas.handBottom = ui.handRects.player
    ui.areas.topOpponent = ui.handRects.opponent

    return ui.areas
end

local function scissorRect(rect)
    if rect and rect.w > 0 and rect.h > 0 then
        love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)
    end
end

local function clearScissor()
    love.graphics.setScissor()
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

function ui.drawCard(card, x, y, opts)
    opts = opts or {}
    x, y = math.floor(x), math.floor(y)
    local w, h = ui.cardW, ui.cardH

    local alpha = opts.dimmed and 0.45 or 1
    love.graphics.setColor(1, 1, 1, alpha)

    if opts.back or not card or not card.afbeelding then
        local scale = h / cardBack:getHeight()
        love.graphics.draw(cardBack, x, y, 0, scale, scale)
    else
        local img = card.afbeelding
        local scale = h / img:getHeight()
        love.graphics.draw(img, x, y, 0, scale, scale)
    end

    if opts.selected then
        love.graphics.setColor(0.95, 0.77, 0.3, 0.9)
        love.graphics.setLineWidth(math.max(2, math.floor(2 * ui.scale)))
        love.graphics.rectangle("line", x, y, w, h, math.floor(12 * ui.scale), math.floor(12 * ui.scale))
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function computeHandView(pData)
    if ui.handView then return ui.handView end
    local rect = ui.handRects.player
    if not rect then return nil end
    local viewportW = math.max(1, ui.handLayout.viewport or (rect.w - ui.pad * 2))
    local cards = pData.hand or {}
    pData.scrollOffset = pData.scrollOffset or 0

    local step = math.max(1, ui.handLayout.step or math.floor(ui.cardW * 0.7))
    local contentW = 0
    if #cards > 0 then
        contentW = ui.cardW + (math.max(0, #cards - 1) * step)
    end
    local maxScroll = math.max(0, (#cards * step + ui.pad) - rect.w)
    if pData.scrollOffset > maxScroll then pData.scrollOffset = maxScroll end
    if pData.scrollOffset < 0 then pData.scrollOffset = 0 end

    local xStart
    if contentW <= viewportW then
        xStart = rect.x + (rect.w - contentW) / 2
    else
        xStart = rect.x + ui.pad - pData.scrollOffset
    end

    ui.handView = {
        xStart = xStart,
        viewportW = viewportW,
        contentW = contentW,
        maxScroll = maxScroll,
        offset = pData.scrollOffset,
        hitboxes = {},
        step = step,
        rect = rect
    }
    return ui.handView
end

local function drawOverflowIndicators(rect, view)
    if not rect or not view then return end
    if view.contentW <= view.viewportW + 1 then return end

    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.rectangle("fill", rect.x, rect.y, ui.pad, rect.h)
    love.graphics.rectangle("fill", rect.x + rect.w - ui.pad, rect.y, ui.pad, rect.h)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHandBottom(pData)
    local rect = ui.handRects.player
    if not rect or rect.w <= 0 or rect.h <= 0 then return end

    drawPanelBackground(rect, 0.95)

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("Jouw hand", rect.x + ui.pad, rect.y + ui.pad * 0.35, rect.w - 2 * ui.pad, "left")

    local view = computeHandView(pData)
    if not view then return end

    local cards = pData.hand or {}
    ui.handView.hitboxes = {}

    local yCursor = rect.y + ui.pad * 1.3
    local faceDown = pData.faceDown or {}
    if #faceDown > 0 then
        local scale = 0.65
        local blindH = math.floor(ui.cardH * scale)
        local blindW = math.floor(ui.cardW * scale)
        local gap = math.floor(ui.pad * 0.4)
        local stride = math.floor(blindW * 0.6) + gap
        local totalW = blindW + math.max(0, (#faceDown - 1)) * stride
        local startX = rect.x + (rect.w - totalW) / 2
        ui.faceDownView = { x = startX, y = yCursor, w = totalW, h = blindH }
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("Blind", rect.x + ui.pad, yCursor - ui.fontSmall:getHeight() - ui.pad * 0.2)
        love.graphics.setColor(1, 1, 1, 1)
        local scaleImg = blindH / cardBack:getHeight()
        for i = 1, #faceDown do
            local x = startX + (i - 1) * stride
            love.graphics.draw(cardBack, math.floor(x), math.floor(yCursor), 0, scaleImg, scaleImg)
        end
        yCursor = yCursor + blindH + ui.pad
    else
        ui.faceDownView = nil
    end

    local faceUp = pData.faceUp or {}
    if #faceUp > 0 then
        ui.faceUpView = { hitboxes = {} }
        local gap = math.floor(ui.pad * 0.5)
        local stride = ui.cardW + gap
        local totalW = ui.cardW + math.max(0, (#faceUp - 1)) * stride
        local startX = rect.x + (rect.w - totalW) / 2
        local rowY = math.max(yCursor, rect.y + ui.pad)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("Open kaarten", rect.x + ui.pad, rowY - ui.fontSmall:getHeight() - ui.pad * 0.2)
        love.graphics.setColor(1, 1, 1, 1)
        for i, card in ipairs(faceUp) do
            local x = startX + (i - 1) * stride
            ui.drawCard(card, x, rowY, { selected = card.selected })
            ui.faceUpView.hitboxes[i] = { x = x, y = rowY, w = ui.cardW, h = ui.cardH }
        end
        yCursor = rowY + ui.cardH + ui.pad
    else
        ui.faceUpView = nil
    end

    local baseline = rect.y + rect.h - ui.cardH - ui.pad
    baseline = math.max(yCursor, baseline)
    baseline = math.min(baseline, rect.y + rect.h - ui.cardH)
    local selectedLift = math.floor(ui.pad * 0.75)

    scissorRect(rect)
    local selectedBuffer = {}
    for index, card in ipairs(cards) do
        local cardX = view.xStart + (index - 1) * view.step
        local hitW = ui.handLayout.hitW
        local hitX = cardX - (hitW - ui.cardW) / 2
        hitX = math.max(rect.x, math.min(hitX, rect.x + rect.w - hitW))
        ui.handView.hitboxes[index] = {
            x = hitX,
            y = baseline,
            w = hitW,
            h = ui.cardH,
            cardX = cardX,
            cardY = baseline,
        }

        if cardX + ui.cardW > rect.x and cardX < rect.x + rect.w then
            local drawY = card.selected and (baseline - selectedLift) or baseline
            if card.selected then
                table.insert(selectedBuffer, { card = card, x = cardX, y = drawY })
            else
                ui.drawCard(card, cardX, drawY, { selected = false })
            end
        end
    end

    for _, info in ipairs(selectedBuffer) do
        ui.drawCard(info.card, info.x, info.y, { selected = true })
    end

    drawOverflowIndicators(rect, view)
    clearScissor()

    if not isMyTurn(ui.game) then
        love.graphics.setColor(0, 0, 0, 0.18)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 18, 18)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("Wachten op andere speler", rect.x, rect.y + rect.h - ui.fontSmall:getHeight() - ui.pad, rect.w, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function drawTopOpponent(opponent)
    if not opponent then return end
    local rect = ui.handRects.opponent
    if not rect or rect.w <= 0 or rect.h <= 0 then return end

    drawPanelBackground(rect, 0.75)

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.print("Tegenstander", rect.x + ui.pad, rect.y + ui.pad * 0.6)

    local cards = opponent.hand or {}
    if #cards == 0 then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("Geen kaarten", rect.x, rect.y + rect.h / 2 - ui.fontSmall:getHeight() / 2, rect.w, "center")
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    scissorRect(rect)
    local stride = math.max(1, math.floor((rect.w - 2 * ui.pad) / math.max(1, #cards)))
    stride = math.min(stride, ui.cardW)
    local totalW = ui.cardW + math.max(0, (#cards - 1)) * stride
    local startX = rect.x + (rect.w - totalW) / 2
    local y = rect.y + rect.h / 2 - ui.cardH / 2
    local scaleImg = ui.cardH / cardBack:getHeight()

    for i = 1, #cards do
        local x = startX + (i - 1) * stride
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.draw(cardBack, math.floor(x), math.floor(y), 0, scaleImg, scaleImg)
    end
    clearScissor()
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPileStack(drawPile, x, y)
    local count = drawPile and drawPile.count and drawPile.count() or 0
    local layers = math.min(4, count)
    local scale = ui.cardH / cardBack:getHeight()
    for i = 1, layers do
        love.graphics.setColor(1, 1, 1, 0.25 + 0.15 * (i - 1))
        love.graphics.draw(cardBack, x - (i - 1) * ui.scale * 4, y - (i - 1) * ui.scale * 3, 0, scale, scale)
    end
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.printf("Trekstapel\n" .. count, x - ui.cardW * 0.2, y + ui.cardH + ui.pad * 0.2, ui.cardW * 1.4, "center")
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
        local scale = ui.cardH / prev.afbeelding:getHeight()
        love.graphics.draw(prev.afbeelding, x - ui.pad * 0.3, y + ui.pad * 0.3, 0, scale, scale)
    end

    if top and top.afbeelding then
        love.graphics.setColor(1, 1, 1, 1)
        local scale = ui.cardH / top.afbeelding:getHeight()
        love.graphics.draw(top.afbeelding, x, y, 0, scale, scale)
    else
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("line", x, y, ui.cardW, ui.cardH, 14, 14)
    end

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(ui.fontSmall)
    love.graphics.printf("Aflegstapel\n" .. #pot, x - ui.cardW * 0.1, y + ui.cardH + ui.pad * 0.2, ui.cardW * 1.2, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function ui.button(x, y, w, h, label, enabled, id)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    local pointerX, pointerY = love.mouse.getPosition()
    local hovered = utils.inside(pointerX, pointerY, x, y, w, h)
    local radius = math.floor(12 * ui.scale)
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
    love.graphics.printf(label, x, y + (h - ui.fontBig:getHeight()) / 2, w, "center")
    love.graphics.setColor(1, 1, 1, 1)

    ui.buttons[id] = { x = x, y = y, w = w, h = h, enabled = enabled, label = label }
end

local function drawCenterArea(pot, drawPile, buttons)
    local rect = ui.areas.center
    if not rect then return end
    drawPanelBackground(rect, 0.85)

    scissorRect(rect)
    local colW = math.floor(rect.w / 3)
    local cardY = rect.y + (rect.h - ui.cardH) / 2
    local minCardX = rect.x + ui.pad
    local maxCardX = rect.x + rect.w - ui.cardW - ui.pad
    if maxCardX < minCardX then maxCardX = minCardX end
    local drawX = clamp(minCardX, rect.x + (colW - ui.cardW) / 2, maxCardX)
    local potX = clamp(minCardX, rect.x + colW + (colW - ui.cardW) / 2, maxCardX)
    local btnColX = rect.x + colW * 2 + ui.pad

    ui.centerState.pot = { x = math.floor(potX), y = math.floor(cardY), w = ui.cardW, h = ui.cardH }
    ui.centerState.draw = { x = math.floor(drawX), y = math.floor(cardY), w = ui.cardW, h = ui.cardH }

    drawPileStack(drawPile, ui.centerState.draw.x, ui.centerState.draw.y)
    drawPot(pot, ui.centerState.pot)

    local buttonHeight = math.max(ui.minTap, math.floor(ui.fontBig:getHeight() + ui.pad * 1.1))
    local maxWidth = math.floor(rect.w / 3 - ui.pad * 2)
    local buttonWidth = math.max(ui.minTap * 2, math.min(maxWidth, math.floor(240 * ui.scale)))
    local gap = ui.pad

    if ui.compact then
        local btnY = ui.centerState.pot.y + ui.cardH + ui.pad * 1.5
        btnY = math.min(btnY, rect.y + rect.h - buttonHeight - ui.pad)
        local totalW = #buttons * buttonWidth + math.max(0, #buttons - 1) * gap
        local startX = rect.x + (rect.w - totalW) / 2
        for i, btn in ipairs(buttons) do
            local x = startX + (i - 1) * (buttonWidth + gap)
            ui.button(x, btnY, buttonWidth, buttonHeight, btn.label, btn.enabled, btn.id)
        end
        ui.centerState.buttonRow = { x = math.floor(startX), y = math.floor(btnY), w = math.floor(totalW), h = buttonHeight }
        ui.centerState.buttonColumn = nil
    else
        local totalH = #buttons * buttonHeight + math.max(0, #buttons - 1) * gap
        local startY = rect.y + (rect.h - totalH) / 2
        local maxBtnX = rect.x + rect.w - buttonWidth - ui.pad
        if maxBtnX < rect.x + ui.pad then maxBtnX = rect.x + ui.pad end
        local x = clamp(rect.x + ui.pad, btnColX, maxBtnX)
        ui.centerState.buttonColumn = { x = math.floor(x), y = math.floor(startY), w = buttonWidth, h = totalH }
        ui.centerState.buttonRow = nil
        for i, btn in ipairs(buttons) do
            local y = startY + (i - 1) * (buttonHeight + gap)
            ui.button(x, y, buttonWidth, buttonHeight, btn.label, btn.enabled, btn.id)
        end
    end

    clearScissor()

    love.graphics.setFont(ui.fontSmall)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("Dubbelklik/tap om te spelen", rect.x, rect.y + rect.h - ui.fontSmall:getHeight() - ui.pad, rect.w, "center")
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

local function drawDebugOverlay()
    if not ui.debug then return end
    local outlines = {
        ui.areas and ui.areas.hudL,
        ui.areas and ui.areas.hudR,
        ui.areas and ui.areas.center,
        ui.areas and ui.areas.bottom,
        ui.areas and ui.areas.statusBottom,
        ui.handRects and ui.handRects.player,
        ui.handRects and ui.handRects.opponent,
    }
    love.graphics.setLineWidth(1)
    for _, rect in ipairs(outlines) do
        if rect and rect.w > 0 and rect.h > 0 then
            love.graphics.setColor(1, 0.2, 0.2, 0.5)
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
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

    drawDebugOverlay()

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
        local spacing = ui.cardW * 0.65
        for i, card in ipairs(game.pot) do
            local row = math.floor((i - 1) / col)
            local colIndex = (i - 1) % col
            local x = overlayX + ui.pad * 1.2 + colIndex * (spacing + ui.pad * 0.5)
            local y = cardY + row * (ui.cardH * 0.65 + ui.pad * 0.6)
            local scale = (ui.cardH * 0.65) / card.afbeelding:getHeight()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(card.afbeelding, x, y, 0, scale, scale)
        end
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("Klik om te sluiten", overlayX, overlayY + overlayH - ui.fontSmall:getHeight() - ui.pad, overlayW, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function ui.toggleDebug()
    ui.debug = not ui.debug
end

-- --- Input helpers ------------------------------------------------------------
local function setScrollOffset(delta)
    if not ui.game then return end
    local pid = localPlayerId()
    local pData = player.players[pid]
    if not pData then return end
    local view = computeHandView(pData)
    if not view then return end
    local newOffset = clamp(0, (pData.scrollOffset or 0) + delta, view.maxScroll or 0)
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
        if hit and utils.inside(x, y, hit.x, hit.y - ui.cardH * 0.08, hit.w, hit.h + ui.cardH * 0.1) then
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
    if not utils.inside(x, y, ui.faceDownView.x, ui.faceDownView.y, ui.faceDownView.w, ui.faceDownView.h + ui.cardH * 0.1) then
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
    local step = ui.handLayout and ui.handLayout.step or math.floor(ui.cardW * 0.6)
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
