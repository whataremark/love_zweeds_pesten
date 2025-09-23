local ui = {}

local utils = require("utils")

local COLORS = {
    background    = {0.06, 0.21, 0.13},
    backgroundTop = {0.09, 0.28, 0.16},
    panelFill     = {0.08, 0.26, 0.16, 0.92},
    panelOutline  = {0.18, 0.4, 0.24, 0.7},
    textPrimary   = {0.92, 0.96, 0.92},
    textSecondary = {0.72, 0.82, 0.75},
    potFill       = {0.45, 0.28, 0.16},
    potOutline    = {0.67, 0.49, 0.32},
    buttonPot     = {0.18, 0.42, 0.75},
    overlay       = {0, 0, 0, 0.55},
}

local BUTTON_DEFS = {
    { id = "draw", label = "Pak",   event = "ui:pak",   color = {0.62, 0.27, 0.24}, actionKey = "canDraw" },
    { id = "play", label = "Speel", event = "ui:speel", color = {0.22, 0.55, 0.33}, actionKey = "canPlay" },
    { id = "pass", label = "Pas",   event = "ui:pas",   color = {0.74, 0.66, 0.21}, actionKey = "canPass" },
}

ui.assets = {}
ui.fonts = {}
ui.metrics = {}
ui.layout = {}
ui.buttons = {}
ui.buttonMap = {}
ui.hitboxes = {}
ui.pointer = { x = 0, y = 0 }
ui.currentState = nil
ui.orientation = "horizontal"
ui.cardSize = { w = 140, h = 200 }
ui.viewport = { w = 0, h = 0 }
ui.activeButton = nil
ui.modalRect = nil

local function copyButtons()
    ui.buttons = {}
    ui.buttonMap = {}
    for _, def in ipairs(BUTTON_DEFS) do
        local button = {
            id = def.id,
            label = def.label,
            event = def.event,
            color = def.color,
            actionKey = def.actionKey,
            rect = { x = 0, y = 0, w = 0, h = 0 },
        }
        table.insert(ui.buttons, button)
        ui.buttonMap[button.id] = button
    end
end

local function ensureCardBack(assets)
    if assets and assets.cards and assets.cards.back then
        ui.assets.cardBack = assets.cards.back
        return ui.assets.cardBack
    end
    if ui.assets.cardBack and ui.assets.cardBack:typeOf("Image") then
        return ui.assets.cardBack
    end
    ui.assets.cardBack = love.graphics.newImage("png/back.png")
    return ui.assets.cardBack
end

local function ensureFonts()
    local h = ui.viewport.h > 0 and ui.viewport.h or love.graphics.getHeight()
    local titleSize = math.max(28, math.floor(h * 0.035))
    local bodySize  = math.max(20, math.floor(h * 0.024))
    local smallSize = math.max(16, math.floor(h * 0.020))

    ui.fonts.title = love.graphics.newFont(titleSize)
    ui.fonts.body  = love.graphics.newFont(bodySize)
    ui.fonts.small = love.graphics.newFont(smallSize)
end

local function computeMetrics(w, h)
    local pad = math.max(16, math.floor(math.min(w, h) * 0.02))
    local gap = math.floor(pad * 0.75)
    local buttonH = math.max(70, math.floor(h * 0.08))
    return {
        pad = pad,
        gap = gap,
        buttonH = buttonH,
    }
end

local function layoutRow(rect, count, cardW, gap)
    if count <= 0 then return {} end
    local totalW, gapUsed = utils.gridRow(count, cardW, gap)
    local startX = rect.x + utils.centerWithin(rect.w, totalW)
    local baseY = rect.y + rect.h - ui.cardSize.h
    local positions = {}
    for i = 1, count do
        positions[i] = {
            x = startX + (i - 1) * (cardW + gapUsed),
            y = baseY,
        }
    end
    return positions
end

local function layoutColumn(rect, count, cardH, gap)
    if count <= 0 then return {} end
    local totalH, gapUsed = utils.gridRow(count, cardH, gap)
    local startY = rect.y + utils.centerWithin(rect.h, totalH)
    local baseX = rect.x + utils.centerWithin(rect.w, ui.cardSize.w)
    local positions = {}
    for i = 1, count do
        positions[i] = {
            x = baseX,
            y = startY + (i - 1) * (cardH + gapUsed),
        }
    end
    return positions
end

local function buildHorizontalLayout(w, h)
    local pad = ui.metrics.pad
    local gap = ui.metrics.gap
    local cardW = ui.cardSize.w
    local cardH = ui.cardSize.h

    local buttonsBar = {
        x = pad,
        y = h - pad - ui.metrics.buttonH,
        w = w - pad * 2,
        h = ui.metrics.buttonH,
    }

    local handRect = {
        x = pad,
        y = buttonsBar.y - pad - cardH,
        w = w - pad * 2,
        h = cardH,
    }

    local stackHeight = cardH * 1.35
    local stackRect = {
        x = pad,
        y = handRect.y - pad - stackHeight,
        w = w - pad * 2,
        h = stackHeight,
    }

    local topHandRect = {
        x = pad,
        y = pad,
        w = w - pad * 2,
        h = cardH,
    }

    local topStackRect = {
        x = pad,
        y = topHandRect.y + cardH + math.floor(gap * 0.4),
        w = w - pad * 2,
        h = cardH * 1.15,
    }

    local centerTop = topStackRect.y + topStackRect.h + pad
    local centerBottom = stackRect.y - pad
    local centerY = centerTop + math.max(0, (centerBottom - centerTop - cardH)) / 2

    local playedRect = {
        x = w / 2 - cardW / 2,
        y = centerY,
        w = cardW,
        h = cardH,
    }

    local potRect = {
        x = playedRect.x - cardW - gap,
        y = playedRect.y + cardH * 0.08,
        w = cardW,
        h = cardH,
    }

    local potButtonHeight = math.max(48, math.floor(ui.metrics.buttonH * 0.65))
    local potButtonWidth = math.max(160, math.floor(cardW * 1.1))
    local potButtonRect = {
        x = potRect.x + cardW + gap,
        y = potRect.y + cardH / 2 - potButtonHeight / 2,
        w = potButtonWidth,
        h = potButtonHeight,
    }

    local infoRect = {
        x = potButtonRect.x + potButtonRect.w + gap,
        y = playedRect.y - pad,
        w = math.min(w - pad - (potButtonRect.x + potButtonRect.w + gap), cardW * 2.6),
        h = cardH + pad * 2,
    }

    local sideWidth = cardW + pad * 1.6
    local sideTop = centerTop
    local sideBottom = centerBottom
    local sideHeight = math.max(cardH * 2.6, sideBottom - sideTop)

    local leftHandRect = {
        x = pad,
        y = sideTop,
        w = sideWidth,
        h = sideHeight * 0.55,
    }

    local leftStackRect = {
        x = pad,
        y = leftHandRect.y + leftHandRect.h + math.floor(gap * 0.4),
        w = sideWidth,
        h = cardH * 1.2,
    }

    local rightHandRect = {
        x = w - pad - sideWidth,
        y = sideTop,
        w = sideWidth,
        h = sideHeight * 0.55,
    }

    local rightStackRect = {
        x = w - pad - sideWidth,
        y = rightHandRect.y + rightHandRect.h + math.floor(gap * 0.4),
        w = sideWidth,
        h = cardH * 1.2,
    }

    return {
        buttonsBar = buttonsBar,
        myHand = handRect,
        myStack = stackRect,
        infoPanel = infoRect,
        center = {
            playedRect = playedRect,
            potRect = potRect,
            potButtonRect = potButtonRect,
        },
        opponents = {
            top = { hand = topHandRect, stack = topStackRect },
            left = { hand = leftHandRect, stack = leftStackRect },
            right = { hand = rightHandRect, stack = rightStackRect },
        },
    }
end

local function buildVerticalLayout(w, h)
    local pad = ui.metrics.pad
    local gap = ui.metrics.gap
    local cardW = ui.cardSize.w
    local cardH = ui.cardSize.h

    local buttonsBar = {
        x = pad,
        y = h - pad - ui.metrics.buttonH,
        w = w - pad * 2,
        h = ui.metrics.buttonH,
    }

    local handRect = {
        x = pad,
        y = buttonsBar.y - pad - cardH,
        w = w - pad * 2,
        h = cardH,
    }

    local stackHeight = cardH * 1.35
    local stackRect = {
        x = pad,
        y = handRect.y - pad - stackHeight,
        w = w - pad * 2,
        h = stackHeight,
    }

    local infoHeight = math.max(cardH * 0.9, math.floor(ui.metrics.buttonH * 0.75))
    local potButtonWidth = math.max(150, math.floor(cardW * 1.2))
    local potButtonHeight = math.floor(infoHeight * 0.65)
    local infoY = stackRect.y - pad - infoHeight

    local infoRect = {
        x = pad,
        y = infoY,
        w = w - potButtonWidth - pad * 3,
        h = infoHeight,
    }

    local potButtonRect = {
        x = infoRect.x + infoRect.w + pad,
        y = infoY + (infoHeight - potButtonHeight) / 2,
        w = potButtonWidth,
        h = potButtonHeight,
    }

    local playedRect = {
        x = w / 2 - cardW / 2,
        y = infoRect.y - cardH - pad,
        w = cardW,
        h = cardH,
    }

    local potRect = {
        x = playedRect.x - cardW - gap,
        y = playedRect.y + cardH * 0.08,
        w = cardW,
        h = cardH,
    }

    local topHandRect = {
        x = pad,
        y = pad,
        w = w - pad * 2,
        h = cardH,
    }

    local topStackRect = {
        x = pad,
        y = topHandRect.y + cardH + math.floor(gap * 0.4),
        w = w - pad * 2,
        h = cardH * 1.1,
    }

    local sideAreaBottom = playedRect.y - pad
    local sideHeight = math.max(cardH * 2.4, sideAreaBottom - pad)
    local sideWidth = cardW + pad * 1.4

    local leftHandRect = {
        x = pad,
        y = pad + cardH * 0.3,
        w = sideWidth,
        h = sideHeight * 0.55,
    }

    local leftStackRect = {
        x = pad,
        y = leftHandRect.y + leftHandRect.h + math.floor(gap * 0.4),
        w = sideWidth,
        h = cardH * 1.1,
    }

    local rightHandRect = {
        x = w - pad - sideWidth,
        y = pad + cardH * 0.3,
        w = sideWidth,
        h = sideHeight * 0.55,
    }

    local rightStackRect = {
        x = w - pad - sideWidth,
        y = rightHandRect.y + rightHandRect.h + math.floor(gap * 0.4),
        w = sideWidth,
        h = cardH * 1.1,
    }

    return {
        buttonsBar = buttonsBar,
        myHand = handRect,
        myStack = stackRect,
        infoPanel = infoRect,
        center = {
            playedRect = playedRect,
            potRect = potRect,
            potButtonRect = potButtonRect,
        },
        opponents = {
            top = { hand = topHandRect, stack = topStackRect },
            left = { hand = leftHandRect, stack = leftStackRect },
            right = { hand = rightHandRect, stack = rightStackRect },
        },
    }
end
local function assignButtons()
    local bar = ui.layout.buttonsBar
    if not bar then return end
    local spacing = ui.metrics.pad
    local usable = bar.w - spacing * (#ui.buttons - 1)
    local width = usable / #ui.buttons
    for index, button in ipairs(ui.buttons) do
        button.rect.x = bar.x + (index - 1) * (width + spacing)
        button.rect.y = bar.y
        button.rect.w = width
        button.rect.h = bar.h
    end
end

local function gatherOpponents(state)
    local players = state.players or {}
    local me = state.me or 1
    if #players <= 1 then return {} end
    local ordered = {}
    for offset = 1, #players - 1 do
        local idx = ((me - 1 + offset) % #players) + 1
        table.insert(ordered, players[idx])
    end
    return ordered
end

local function mapOpponents(state)
    local slots = { top = nil, left = nil, right = nil }
    local opponents = gatherOpponents(state)
    if #opponents == 1 then
        slots.top = opponents[1]
    elseif #opponents == 2 then
        slots.top = opponents[1]
        slots.right = opponents[2]
    elseif #opponents >= 3 then
        slots.top = opponents[1]
        slots.right = opponents[2]
        slots.left = opponents[3]
    end
    return slots
end

local function dispatchEvent(state, eventName, payload)
    if not state or not eventName then return end
    if type(state.emit) == "function" then
        state:emit(eventName, payload)
        return
    end
    if type(state.onUIEvent) == "function" then
        state.onUIEvent(state, eventName, payload)
    elseif type(state.events) == "table" then
        table.insert(state.events, { name = eventName, payload = payload })
    end
    if state.game and type(state.game.handleUIEvent) == "function" then
        state.game.handleUIEvent(eventName, payload)
    end
end

local function toggleModal(state, modalType, forceClose)
    if not state then return end
    state.ui = state.ui or {}
    if forceClose then
        state.ui.modal = nil
    elseif state.ui.modal and state.ui.modal.type == modalType then
        state.ui.modal = nil
    else
        state.ui.modal = { type = modalType }
    end
    if state.game then
        state.game.showPotOverlay = state.ui.modal and state.ui.modal.type == modalType or false
    end
end

local function drawBackground(w, h)
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(COLORS.backgroundTop)
    love.graphics.rectangle("fill", 0, 0, w, h * 0.25)
end

local function drawPanel(rect)
    love.graphics.setColor(COLORS.panelFill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 18, 18)
    love.graphics.setColor(COLORS.panelOutline)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 18, 18)
end

local function drawInfoPanel(state)
    local rect = ui.layout.infoPanel
    if not rect then return end
    drawPanel(rect)

    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(COLORS.textPrimary)
    utils.drawPanelTitle("Info", rect.x + ui.metrics.pad * 0.6, rect.y + ui.metrics.pad * 0.4, rect.w - ui.metrics.pad)

    local lines = state.turnInfo or {}
    local y = rect.y + ui.metrics.pad * 1.4 + ui.fonts.title:getHeight()
    love.graphics.setFont(ui.fonts.body)
    for _, line in ipairs(lines) do
        love.graphics.setColor(COLORS.textSecondary)
        love.graphics.printf(line, rect.x + ui.metrics.pad, y, rect.w - ui.metrics.pad * 2, "left")
        y = y + ui.fonts.body:getHeight() + 6
    end
end

local function drawButtons(state)
    ui.hitboxes.buttons = {}
    for _, button in ipairs(ui.buttons) do
        local disabled = state.actions and state.actions[button.actionKey] == false
        local hovered = utils.hitboxContains(button.rect, ui.pointer.x, ui.pointer.y)
        utils.drawButton(
            button.label,
            button.rect,
            {
                color = button.color,
                hovered = hovered,
                active = ui.activeButton == button.id,
                disabled = disabled,
                font = ui.fonts.body,
                textColor = COLORS.textPrimary,
            }
        )
        local hb = utils.makeHitbox(button.rect.x, button.rect.y, button.rect.w, button.rect.h)
        hb.disabled = disabled
        hb.event = button.event
        ui.hitboxes.buttons[button.id] = hb
    end
end

local function addHandHitbox(list, index, x, y)
    list[#list + 1] = {
        x = x,
        y = y,
        w = ui.cardSize.w,
        h = ui.cardSize.h,
        index = index,
    }
end

local function drawPlayerHand(player)
    local rect = ui.layout.myHand
    local hand = player and player.hand or {}
    local count = type(hand) == "table" and #hand or 0
    ui.hitboxes.hand = {}
    if count == 0 then return end

    local positions = layoutRow(rect, count, ui.cardSize.w, ui.metrics.gap)
    for i, card in ipairs(hand) do
        local pos = positions[i]
        if pos then
            utils.drawCard(card, pos.x, pos.y, {
                cardSize = ui.cardSize,
                backImage = ui.assets.cardBack,
                selected = card.selected,
                shadow = { x = 4, y = 6, alpha = 0.3 },
            })
            addHandHitbox(ui.hitboxes.hand, i, pos.x, pos.y)
            ui.hitboxes.hand[#ui.hitboxes.hand].card = card
        end
    end
end

local function drawStack(rect, cards, opts)
    local list = {}
    if type(cards) == "table" then
        for _, card in ipairs(cards) do
            table.insert(list, card)
        end
    elseif type(cards) == "number" then
        for _ = 1, cards do
            table.insert(list, nil)
        end
    end
    local count = math.min(3, #list)
    if count == 0 then return {} end
    local positions = layoutRow(rect, count, ui.cardSize.w, ui.metrics.gap)
    for i = 1, count do
        local card = list[i]
        local pos = positions[i]
        utils.drawCard(card, pos.x, pos.y, {
            cardSize = ui.cardSize,
            back = opts.back,
            backImage = ui.assets.cardBack,
            shadow = opts.shadow,
        })
    end
    return positions
end

local function drawPlayerStacks(player)
    local rect = ui.layout.myStack
    if not rect then return end
    ui.hitboxes.faceDown = {}
    ui.hitboxes.faceUp = {}

    local faceDown = player and player.faceDown or {}
    local downCount = type(faceDown) == "table" and #faceDown or (tonumber(faceDown) or 0)
    local downPositions = drawStack(rect, faceDown, { back = true, shadow = { x = 3, y = 5, alpha = 0.25 } })
    for index, pos in ipairs(downPositions) do
        local hb = utils.makeHitbox(pos.x, pos.y, ui.cardSize.w, ui.cardSize.h)
        hb.index = index
        hb.type = "faceDown"
        table.insert(ui.hitboxes.faceDown, hb)
    end

    local faceUp = player and player.faceUp or {}
    local openCount = type(faceUp) == "table" and #faceUp or (tonumber(faceUp) or 0)
    if openCount > 0 then
        local display = math.min(3, openCount)
        local openPositions = layoutRow(rect, display, ui.cardSize.w, ui.metrics.gap)
        local lift = ui.cardSize.h * 0.45
        for i = 1, display do
            local card = type(faceUp) == "table" and faceUp[i] or nil
            local pos = openPositions[i]
            if pos then
                utils.drawCard(card, pos.x, pos.y - lift, {
                    cardSize = ui.cardSize,
                    backImage = ui.assets.cardBack,
                    shadow = { x = 2, y = 4, alpha = 0.2 },
                })
                local hb = utils.makeHitbox(pos.x, pos.y - lift, ui.cardSize.w, ui.cardSize.h)
                hb.index = i
                hb.type = "faceUp"
                hb.card = card
                table.insert(ui.hitboxes.faceUp, hb)
            end
        end
    end
end
local function drawCenter(state)
    local center = ui.layout.center
    if not center then return end

    local played = center.playedRect
    if played then
        local stack = utils.stackPositions(
            played.x + ui.cardSize.w / 2,
            played.y + ui.cardSize.h / 2,
            ui.cardSize.w,
            ui.cardSize.h,
            ui.metrics.gap
        )

        local prevCard = state.center and (state.center.previous or state.center.prevCard)
        if prevCard then
            utils.drawCard(prevCard, stack.previous.x, stack.previous.y, {
                cardSize = ui.cardSize,
                rotation = stack.previous.rotation,
                backImage = ui.assets.cardBack,
                shadow = { x = 2, y = 4, alpha = 0.25 },
            })
        end

        local topCard = state.center and (state.center.latest or state.center.lastCard)
        if topCard then
            utils.drawCard(topCard, stack.latest.x, stack.latest.y, {
                cardSize = ui.cardSize,
                rotation = stack.latest.rotation,
                backImage = ui.assets.cardBack,
                shadow = { x = 3, y = 5, alpha = 0.35 },
            })
        else
            love.graphics.setColor(1, 1, 1, 0.08)
            love.graphics.rectangle("fill", played.x, played.y, ui.cardSize.w, ui.cardSize.h, 16, 16)
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.rectangle("line", played.x, played.y, ui.cardSize.w, ui.cardSize.h, 16, 16)
        end
    end

    local potRect = center.potRect
    if potRect then
        love.graphics.setColor(COLORS.potFill)
        love.graphics.rectangle("fill", potRect.x, potRect.y, potRect.w, potRect.h, 14, 14)
        love.graphics.setColor(COLORS.potOutline)
        love.graphics.rectangle("line", potRect.x, potRect.y, potRect.w, potRect.h, 14, 14)
        love.graphics.setColor(COLORS.textPrimary)
        love.graphics.setFont(ui.fonts.small)
        local count = #(state.pot or {})
        love.graphics.printf("Pot: " .. count, potRect.x, potRect.y + potRect.h + 8, potRect.w, "center")
    end

    local buttonRect = center.potButtonRect
    if buttonRect then
        local hovered = utils.hitboxContains(buttonRect, ui.pointer.x, ui.pointer.y)
        utils.drawButton(
            "Bekijk pot",
            buttonRect,
            {
                color = COLORS.buttonPot,
                hovered = hovered,
                font = ui.fonts.body,
                textColor = COLORS.textPrimary,
            }
        )
        ui.hitboxes.potButton = utils.makeHitbox(buttonRect.x, buttonRect.y, buttonRect.w, buttonRect.h)
    end
end

local function opponentHandCount(hand)
    if type(hand) == "table" then
        return #hand
    end
    return tonumber(hand) or 0
end

local function opponentLabel(opponent)
    if not opponent then
        return "Tegenstander"
    end
    if opponent.name and opponent.name ~= "" then
        return opponent.name
    end
    if opponent.id then
        return "Speler " .. tostring(opponent.id)
    end
    return "Tegenstander"
end

local function drawOpponentStacks(layout, opponent)
    if not layout or not layout.stack then return end
    local rect = layout.stack
    local faceDown = opponent and opponent.faceDown or {}
    drawStack(rect, faceDown, { back = true, shadow = { x = 2, y = 3, alpha = 0.2 } })

    local faceUp = opponent and opponent.faceUp or {}
    local openCount = type(faceUp) == "table" and #faceUp or (tonumber(faceUp) or 0)
    if openCount > 0 then
        local display = math.min(3, openCount)
        local positions = layoutRow(rect, display, ui.cardSize.w, ui.metrics.gap)
        local lift = ui.cardSize.h * 0.45
        for i = 1, display do
            local card = type(faceUp) == "table" and faceUp[i] or nil
            local pos = positions[i]
            if pos then
                utils.drawCard(card, pos.x, pos.y - lift, {
                    cardSize = ui.cardSize,
                    backImage = ui.assets.cardBack,
                    shadow = { x = 2, y = 3, alpha = 0.18 },
                })
            end
        end
    end
end

local function drawOpponentHorizontal(layout, opponent)
    if not layout or not layout.hand then return end
    local rect = layout.hand
    local count = opponentHandCount(opponent and opponent.hand)
    if count > 0 then
        local positions = layoutRow(rect, count, ui.cardSize.w, ui.metrics.gap)
        for _, pos in ipairs(positions) do
            utils.drawCard(nil, pos.x, pos.y, {
                cardSize = ui.cardSize,
                back = true,
                backImage = ui.assets.cardBack,
                shadow = { x = 2, y = 3, alpha = 0.2 },
            })
        end
    end
    drawOpponentStacks(layout, opponent)
    love.graphics.setFont(ui.fonts.small)
    love.graphics.setColor(COLORS.textSecondary)
    love.graphics.printf(opponentLabel(opponent), rect.x, rect.y - ui.fonts.small:getHeight() - 4, rect.w, "center")
end

local function drawOpponentVertical(layout, opponent)
    if not layout or not layout.hand then return end
    local rect = layout.hand
    local count = opponentHandCount(opponent and opponent.hand)
    if count > 0 then
        local positions = layoutColumn(rect, count, ui.cardSize.h, ui.metrics.gap)
        for _, pos in ipairs(positions) do
            utils.drawCard(nil, pos.x, pos.y, {
                cardSize = ui.cardSize,
                back = true,
                backImage = ui.assets.cardBack,
                shadow = { x = 2, y = 3, alpha = 0.2 },
            })
        end
    end
    drawOpponentStacks(layout, opponent)
    love.graphics.setFont(ui.fonts.small)
    love.graphics.setColor(COLORS.textSecondary)
    love.graphics.printf(opponentLabel(opponent), rect.x, rect.y - ui.fonts.small:getHeight() - 4, rect.w, "center")
end

local function drawOpponents(state)
    local slots = mapOpponents(state)
    if slots.top then
        drawOpponentHorizontal(ui.layout.opponents.top, slots.top)
    end
    if slots.left then
        drawOpponentVertical(ui.layout.opponents.left, slots.left)
    end
    if slots.right then
        drawOpponentVertical(ui.layout.opponents.right, slots.right)
    end
end

local function drawPotModal(state)
    if not state.ui or not state.ui.modal or state.ui.modal.type ~= "pot" then
        ui.hitboxes.modalClose = nil
        ui.hitboxes.modalRect = nil
        return
    end

    local w, h = ui.viewport.w, ui.viewport.h
    local modalW = math.min(w * 0.7, 820)
    local modalH = math.min(h * 0.75, 560)
    local x = (w - modalW) / 2
    local y = (h - modalH) / 2

    ui.modalRect = utils.makeHitbox(x, y, modalW, modalH)
    local closeSize = 36
    local closeRect = utils.makeHitbox(x + modalW - closeSize - 16, y + 16, closeSize, closeSize)
    utils.drawModal(ui.modalRect, "Pot", closeRect)
    ui.hitboxes.modalClose = closeRect
    ui.hitboxes.modalRect = ui.modalRect

    love.graphics.setFont(ui.fonts.body)
    love.graphics.setColor(COLORS.textPrimary)
    local count = #(state.pot or {})
    love.graphics.printf("Kaarten in pot: " .. count, x + 24, y + 64, modalW - 48, "left")

    local cardH = ui.cardSize.h * 0.7
    local cardW = ui.cardSize.w * 0.7
    local gap = ui.metrics.gap * 0.7
    local rowWidth = modalW - 48
    local perRow = math.max(1, math.floor((rowWidth + gap) / (cardW + gap)))
    local startX = x + 24
    local startY = y + 110
    local pot = state.pot or {}
    for index, card in ipairs(pot) do
        local row = math.floor((index - 1) / perRow)
        local col = (index - 1) % perRow
        local drawX = startX + col * (cardW + gap)
        local drawY = startY + row * (cardH + gap)
        if drawY + cardH <= y + modalH - 24 then
            utils.drawCard(card, drawX, drawY, {
                height = cardH,
                backImage = ui.assets.cardBack,
                shadow = { x = 2, y = 3, alpha = 0.2 },
            })
        end
    end

    if #pot == 0 then
        love.graphics.setFont(ui.fonts.body)
        love.graphics.setColor(COLORS.textSecondary)
        love.graphics.printf("Pot is leeg", startX, startY, modalW - 48, "left")
    end
end
local function resetHitboxes()
    ui.hitboxes = {
        buttons = {},
        hand = {},
        faceDown = {},
        faceUp = {},
        potButton = nil,
        modalClose = nil,
        modalRect = nil,
    }
end

function ui.load(assets, state)
    ui.currentState = state or ui.currentState
    ensureCardBack(assets)
    copyButtons()
    ui.viewport.w = love.graphics.getWidth()
    ui.viewport.h = love.graphics.getHeight()
    ui.metrics = computeMetrics(ui.viewport.w, ui.viewport.h)
    local aspect = ui.assets.cardBack and (ui.assets.cardBack:getWidth() / ui.assets.cardBack:getHeight()) or 0.7
    ui.cardSize = utils.calcCardSize(math.floor(ui.viewport.h * 0.22), aspect)
    ensureFonts()
    ui.orientation = utils.detectOrientation(ui.viewport.w, ui.viewport.h)
    ui.layout = (ui.orientation == "horizontal") and buildHorizontalLayout(ui.viewport.w, ui.viewport.h) or buildVerticalLayout(ui.viewport.w, ui.viewport.h)
    assignButtons()
    resetHitboxes()
    ui.pointer.x, ui.pointer.y = love.mouse.getPosition()
end

function ui.resize(w, h)
    ui.viewport.w = w
    ui.viewport.h = h
    ui.metrics = computeMetrics(w, h)
    local aspect = ui.assets.cardBack and (ui.assets.cardBack:getWidth() / ui.assets.cardBack:getHeight()) or 0.7
    local targetH = (utils.detectOrientation(w, h) == "horizontal") and math.floor(h * 0.22) or math.floor(h * 0.19)
    ui.cardSize = utils.calcCardSize(targetH, aspect)
    ui.metrics.gap = math.max(ui.metrics.gap, math.floor(ui.cardSize.w * 0.25))
    ensureFonts()
    ui.orientation = utils.detectOrientation(w, h)
    ui.layout = (ui.orientation == "horizontal") and buildHorizontalLayout(w, h) or buildVerticalLayout(w, h)
    assignButtons()
    resetHitboxes()
end

function ui.update(dt, state)
    if state then
        ui.currentState = state
    end
    ui.pointer.x, ui.pointer.y = love.mouse.getPosition()
end

function ui.draw(state)
    ui.currentState = state or ui.currentState
    local data = ui.currentState
    if not data then return end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if w ~= ui.viewport.w or h ~= ui.viewport.h then
        ui.resize(w, h)
    end

    ui.pointer.x, ui.pointer.y = love.mouse.getPosition()
    resetHitboxes()

    drawBackground(w, h)
    drawOpponents(data)
    drawInfoPanel(data)
    drawCenter(data)

    local meIndex = data.me or 1
    local players = data.players or {}
    local player = players[meIndex]
    drawPlayerStacks(player)
    drawPlayerHand(player)

    drawButtons(data)
    drawPotModal(data)

    love.graphics.setColor(1, 1, 1, 1)
end

local function handleModalClick(x, y, state)
    if not state or not state.ui or not state.ui.modal then
        return false
    end
    if ui.hitboxes.modalClose and utils.hitboxContains(ui.hitboxes.modalClose, x, y) then
        toggleModal(state, state.ui.modal.type, true)
        return true
    end
    if ui.hitboxes.modalRect and not utils.hitboxContains(ui.hitboxes.modalRect, x, y) then
        toggleModal(state, state.ui.modal.type, true)
        return true
    end
    return true
end

function ui.mousepressed(x, y, button, state)
    if button ~= 1 then return end
    ui.pointer.x, ui.pointer.y = x, y
    local data = state or ui.currentState
    if not data then return end

    if data.ui and data.ui.modal then
        if handleModalClick(x, y, data) then
            return
        end
    end

    if ui.hitboxes.potButton and utils.hitboxContains(ui.hitboxes.potButton, x, y) then
        toggleModal(data, "pot")
        return
    end

    for id, hb in pairs(ui.hitboxes.buttons or {}) do
        if not hb.disabled and utils.hitboxContains(hb, x, y) then
            ui.activeButton = id
            return
        end
    end

    for _, hb in ipairs(ui.hitboxes.hand or {}) do
        if utils.overlaps(hb.x, hb.y, hb.w, hb.h, x, y) then
            if hb.card then
                hb.card.selected = not hb.card.selected
            end
            dispatchEvent(data, "ui:hand-card", { index = hb.index, card = hb.card })
            return
        end
    end

    for _, hb in ipairs(ui.hitboxes.faceUp or {}) do
        if utils.overlaps(hb.x, hb.y, hb.w, hb.h, x, y) then
            dispatchEvent(data, "ui:faceup-slot", { index = hb.index })
            return
        end
    end

    for _, hb in ipairs(ui.hitboxes.faceDown or {}) do
        if utils.overlaps(hb.x, hb.y, hb.w, hb.h, x, y) then
            dispatchEvent(data, "ui:facedown-slot", { index = hb.index })
            return
        end
    end
end

function ui.mousereleased(x, y, button, state)
    if button ~= 1 then return end
    ui.pointer.x, ui.pointer.y = x, y
    local data = state or ui.currentState
    if not data then return end

    if ui.activeButton then
        local hb = ui.hitboxes.buttons and ui.hitboxes.buttons[ui.activeButton]
        if hb and not hb.disabled and utils.hitboxContains(hb, x, y) then
            dispatchEvent(data, hb.event, {})
        end
        ui.activeButton = nil
    end
end

function ui.mousemoved(x, y, dx, dy, state)
    ui.pointer.x, ui.pointer.y = x, y
end

function ui.wheelmoved(dx, dy, state)
    local data = state or ui.currentState
    if not data then return end
    if math.abs(dy) > 0.1 then
        dispatchEvent(data, "ui:wheel", { dx = dx, dy = dy })
    end
end

function ui.draw_end_screen(winner, players)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    drawBackground(w, h)
    love.graphics.setColor(COLORS.textPrimary)
    love.graphics.setFont(ui.fonts.title or love.graphics.newFont(48))
    local message = winner and ("Winnaar: " .. tostring(winner)) or "Spel afgelopen"
    love.graphics.printf(message, 0, h / 2 - 40, w, "center")
end

function ui.activate(action) end
function ui.toggleDebug() end
function ui.touchpressed(...) end
function ui.touchreleased(...) end
function ui.touchmoved(...) end

return ui
