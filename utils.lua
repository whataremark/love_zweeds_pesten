-- Collection of small reusable helper functions
local utils = {}
-- Convert card value names to a numeric ranking.
function utils.numeric_value(value)
    local map = {
        ["4"]=4, ["5"]=5, ["6"]=6, ["7"]=7,
        ["8"]=8, ["9"]=9, ["10"]=10,
        jack = 11, queen = 12, king = 13, ace = 14,
        joker = 15         
    }
    return tonumber(value) or map[value] or -1
end

-- Check if a point lies inside a rectangular area.
function utils.inside(mx, my, x, y, w, h)
    return mx > x and mx < x + w and my > y and my < y + h
end

-- Generate a simple green felt background used by the table.
function utils.generate_green_felt_background(w, h)
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    local centerX, centerY = w / 2, h / 2
    local radius = math.max(w, h) * 0.6
    for i = 1, 100 do
        local alpha = 0.02
        local size = radius * (1 - (i / 100))
        love.graphics.setColor(0.05, 0.3, 0.1, alpha)
        love.graphics.circle("fill", centerX, centerY, size)
    end
    love.graphics.setCanvas()
    return canvas
end

-- Move all items from src to dest in reverse order so indices remain stable
function utils.transfer_all_cards(dest, src)
    for i = #src, 1, -1 do
        table.insert(dest, table.remove(src, i))
    end
end

function utils.effective_top_card(pot)
    for i = #pot, 1, -1 do
        if pot[i].waarde ~= "3" then
            print("[UTILS] effective_top_card: " .. pot[i].waarde)
            return pot[i]
        else
            print("[UTILS] 3 GEDTECTEERDE")
            -- Special case for 3: skip it")
        end
    end
    return nil
end

--codex-- Ensure a hand always has at least `X` cards by drawing from the deck module.
function utils.refill_hand(hand, deck, count)
    count = count or 3
    while #hand < count and deck.count() > 0 do
        table.insert(hand, deck.draw())
        print("[UTILS] Hand aangevuld met kaart: " .. hand[#hand].waarde)
    end
end

function utils.deselect_all(t)
    for _, k in ipairs(t) do k.selected = false end
end

-- Count how many cards are currently selected in a list
function utils.count_selected(cards)
    local c = 0
    for _, k in ipairs(cards) do
        if k.selected then
            c = c + 1
        end
    end
    return c
end


--------------------------------------------------------------------
--  Hulpfunctie: bepaal nieuwe fase voor een speler
--------------------------------------------------------------------
local function phase_for_player_cached(id)
    -- LAZY‑require voorkomt require‑loop
    local playerMod = require("player")

    local p = playerMod.players[id]
    if not p then return "unknown" end

    if #p.hand     > 0 then return "playingHand"
    elseif #p.faceUp   > 0 then return "playingOpen"
    elseif #p.faceDown > 0 then return "playingBlind"
    else                      return "finished"
    end
end

function utils.phase_for_player(id)
    return phase_for_player_cached(id)
end

function utils.update_phase_for_player(game, id)
    game.state = phase_for_player_cached(id)
end


function utils.update_reveal_logic(dt, game)
    if game.reveal.timer > 0 then
        game.reveal.timer = game.reveal.timer - dt
        if game.reveal.timer <= 0 then
            game.reveal.card = nil
            game.reveal.player = nil
        end
    end
end

-- ========================
-- Helpers UI
-- ========================

function utils.detectOrientation(w, h)
    if not w or not h or w == h then
        return "horizontal"
    end
    return (w > h) and "horizontal" or "vertical"
end

function utils.calcCardSize(targetH, aspect)
    aspect = aspect or 0.7
    targetH = math.max(8, math.floor(targetH or 100))
    local targetW = math.floor(targetH * aspect + 0.5)
    return { w = targetW, h = targetH }
end

function utils.centerWithin(outerW, innerW)
    return (outerW - innerW) / 2
end

function utils.gridRow(count, size, gap)
    count = math.max(0, count or 0)
    if count <= 0 then
        return 0, 0
    end
    gap = math.max(0, gap or 0)
    local gapUsed = (count > 1) and gap or 0
    local total = count * size + (count - 1) * gapUsed
    return total, gapUsed
end

function utils.overlaps(x, y, w, h, mx, my)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function utils.makeHitbox(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

function utils.hitboxContains(hitbox, mx, my)
    if not hitbox then return false end
    return utils.overlaps(hitbox.x, hitbox.y, hitbox.w, hitbox.h, mx, my)
end

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function lighten(color, amount)
    amount = amount or 0
    return {
        clamp01(color[1] + amount),
        clamp01(color[2] + amount),
        clamp01(color[3] + amount),
        color[4] or 1
    }
end

function utils.drawCard(card, x, y, opts)
    opts = opts or {}
    local image
    if not opts.back and card then
        image = card.afbeelding or card.image
        if not image and opts.cardImages and card.naam then
            image = opts.cardImages[card.naam]
        end
    end
    image = image or opts.backImage
    if not image then return end

    local imageW, imageH = image:getWidth(), image:getHeight()
    local targetH = opts.height or (opts.cardSize and opts.cardSize.h) or imageH
    local scale = targetH / imageH
    local targetW = imageW * scale
    local rotation = opts.rotation or 0

    local drawX = x
    local drawY = y

    if opts.shadow then
        local shadowOffsetX = opts.shadow.x or 6
        local shadowOffsetY = opts.shadow.y or 8
        local shadowAlpha = opts.shadow.alpha or 0.35
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        love.graphics.rectangle("fill", drawX + shadowOffsetX, drawY + shadowOffsetY, targetW, targetH, 12, 12)
    end

    local ox, oy = imageW / 2, imageH / 2
    local centerX = drawX + targetW / 2
    local centerY = drawY + targetH / 2

    love.graphics.setColor(1, 1, 1, opts.alpha or 1)
    love.graphics.draw(image, centerX, centerY, rotation, scale, scale, ox, oy)

    if opts.selected then
        love.graphics.setColor(opts.selectionColor or {0.96, 0.8, 0.26, 0.9})
        love.graphics.setLineWidth(opts.selectionWidth or 4)
        love.graphics.rectangle("line", drawX, drawY, targetW, targetH, 14, 14)
        love.graphics.setLineWidth(1)
    end

    if opts.outline then
        love.graphics.setColor(opts.outline[1], opts.outline[2], opts.outline[3], opts.outline[4] or 1)
        love.graphics.rectangle("line", drawX, drawY, targetW, targetH, 12, 12)
    end
end

function utils.drawButton(label, rect, state)
    state = state or {}
    local base = state.color or {0.25, 0.55, 0.35, 1}
    local hovered = state.hovered
    local active = state.active
    local disabled = state.disabled

    local fill = {base[1], base[2], base[3], base[4] or 1}
    if hovered and not disabled then
        fill = lighten(base, 0.08)
    end
    if active and not disabled then
        fill = lighten(base, -0.08)
    end
    if disabled then
        fill = {base[1] * 0.4, base[2] * 0.4, base[3] * 0.4, 0.4}
    end

    local radius = state.radius or 14
    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, radius, radius)

    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, radius, radius)

    if label and label ~= "" then
        local font = state.font or love.graphics.getFont()
        if font then love.graphics.setFont(font) end
        love.graphics.setColor(state.textColor or {1, 1, 1, disabled and 0.6 or 1})
        local textY = rect.y + (rect.h - font:getHeight()) / 2
        love.graphics.printf(label, rect.x, textY, rect.w, "center")
    end

    return hovered, active
end

function utils.drawPanelTitle(text, x, y, maxW)
    if not text or text == "" then return end
    love.graphics.printf(text, x, y, maxW or love.graphics.getWidth(), "left")
end

function utils.drawModal(rect, title, closeRect)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(0.07, 0.24, 0.14, 0.95)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)

    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 16, 16)

    if title and title ~= "" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(title, rect.x + 24, rect.y + 16, rect.w - 48, "left")
    end

    if closeRect then
        love.graphics.setColor(0.9, 0.3, 0.3, 0.9)
        love.graphics.rectangle("fill", closeRect.x, closeRect.y, closeRect.w, closeRect.h, 8, 8)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(closeRect.x + 8, closeRect.y + 8, closeRect.x + closeRect.w - 8, closeRect.y + closeRect.h - 8)
        love.graphics.line(closeRect.x + closeRect.w - 8, closeRect.y + 8, closeRect.x + 8, closeRect.y + closeRect.h - 8)
        love.graphics.setLineWidth(1)
    end
end

function utils.stackPositions(centerX, centerY, cardW, cardH, spacing)
    spacing = spacing or cardW * 0.25
    local prev = {
        x = centerX - cardW / 2 - spacing * 0.4,
        y = centerY - cardH / 2 + spacing * 0.25,
        rotation = -math.rad(10)
    }
    local latest = {
        x = centerX - cardW / 2,
        y = centerY - cardH / 2,
        rotation = 0
    }
    return { previous = prev, latest = latest }
end

return utils
