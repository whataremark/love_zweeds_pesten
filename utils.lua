-- Collection of small reusable helper functions

local utils = {}

-- Convert card value names to a numeric ranking.
function utils.numeric_value(value)
    local map = {
        ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5,
        ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9,
        ["10"] = 10, jack = 11, queen = 12,
        king = 13, ace = 14
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

return utils
