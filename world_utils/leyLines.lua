local ManaShader = require "world_utils.manaShader"

-- Ley lines(see docs/game-design: Mana network): long lines of mana running through the world, rock and sky alike,
-- seen only with the Ley Goggles. A mana network node on a line taps it and fills its network's batteries
-- Lines come in layers(LEY_LAYERS): one across the whole world, and a denser one in a band around the surface, where
-- bases are. Each layer cuts the world into regions of its size, most have a nexus(a point from the seed) and lines
-- join it to the nexuses right, under and down-right of it in gentle bends, each line thin, medium or wide(LEY_LINES)
-- A region is drawn once into a grid of the lines on each tile and kept, so asking about a tile is a table lookup
-- Tile rows grow downward like love coordinates(ty)
local LeyLines = {}

local madeFor = nil     -- The seed the caches are for
local layers = {}       -- Per layer: {def, cells, nexuses, lines}, made again for another seed


local function hash(seed, a, b, salt)
    local v = math.sin((seed % 10007) * 91.345 + a * 47.853 + b * 23.117 + (salt or 0) * 9.173) * 24634.6345
    return v - math.floor(v)
end


local function fresh(seed)
    if madeFor ~= seed then
        madeFor = seed
        layers = {}
        for i, def in ipairs(LEY_LAYERS) do
            layers[i] = {def = def, salt = i * 1000, cells = {}, nexuses = {}, lines = {}}
        end
    end
end


local function nexusOf(layer, seed, rx, ry)
    -- A region's nexus {x, y} in tiles, false when it has none(or the layer doesnt reach that deep or high)
    local key = rx .. "," .. ry
    if layer.nexuses[key] == nil then
        local def, salt = layer.def, layer.salt
        local n = def.region
        local nexus = false
        if hash(seed, rx, ry, salt + 1) < def.nexusChance then
            local x = rx * n + n * (0.1 + 0.8 * hash(seed, rx, ry, salt + 2))
            local y = ry * n + n * (0.1 + 0.8 * hash(seed, rx, ry, salt + 3))
            if y >= (def.top or -math.huge) and y <= (def.bottom or math.huge) then
                nexus = {x = x, y = y}
            end
        end
        layer.nexuses[key] = nexus
    end
    return layer.nexuses[key]
end


local function strength(layer, seed, rx, ry, k)
    -- What kind of line one of a region's lines is: an entry of LEY_LINES, by chance for its track, so a line keeps
    -- its strength along its whole run. Every line going right in a row of regions shares one, every line going down in
    -- a column one, and every diagonal along its diagonal, a branch off it can be another
    local salt = layer.salt
    local roll
    if k == 1 then
        roll = hash(seed, 0, ry, salt + 41)
    elseif k == 2 then
        roll = hash(seed, rx, 0, salt + 42)
    else
        roll = hash(seed, rx - ry, 0, salt + 43)
    end
    local total = 0
    for i, kind in ipairs(LEY_LINES) do
        total = total + kind.chance
        if roll < total then
            return kind
        end
    end
    return LEY_LINES[1]
end


local function ownedLines(layer, seed, rx, ry)
    -- The lines a region owns, each {id, kind, width, rate, points = {x, y, ...}}
    local key = rx .. "," .. ry
    if layer.lines[key] == nil then
        local def, salt = layer.def, layer.salt
        local owned = {}
        local a = nexusOf(layer, seed, rx, ry)
        if a then
            for k, step in ipairs({{1, 0, def.connectChance}, {0, 1, def.connectChance}, {1, 1, def.diagonalChance}}) do
                local b = nexusOf(layer, seed, rx + step[1], ry + step[2])
                if b and hash(seed, rx, ry, salt + 10 + k) < step[3] then
                    local kind = strength(layer, seed, rx, ry, k)
                    local dx, dy = b.x - a.x, b.y - a.y
                    local length = math.sqrt(dx * dx + dy * dy)
                    local px, py = -dy / length, dx / length
                    local wander = math.min(length * 0.15, def.wander)
                    local noiseSalt = hash(seed, rx, ry, salt + 20 + k) * 100
                    local points = {}
                    local steps = math.ceil(length / 2)
                    for s = 0, steps do
                        local t = s / steps
                        local side = (love.math.noise(t * math.max(1.2, length / 120), noiseSalt) * 2 - 1) * wander * math.sin(t * math.pi)
                        table.insert(points, a.x + dx * t + px * side)
                        table.insert(points, a.y + dy * t + py * side)
                    end
                    table.insert(owned, {id = layer.salt .. ":" .. key .. ":" .. k, kind = kind.name, width = kind.width,
                        rate = kind.rate, points = points})
                end
            end
        end
        layer.lines[key] = owned
    end
    return layer.lines[key]
end


local function region(layer, seed, rx, ry)
    -- The line on every tile of a region that has one(the strongest where two cross), made once
    local key = rx .. "," .. ry
    if layer.cells[key] == nil then
        local grid = {}
        local n = layer.def.region
        local x0, y0 = rx * n, ry * n
        -- A line only reaches the regions next to its owner, so the lines of the regions around are drawn in too
        for ox = -1, 1 do
            for oy = -1, 1 do
                for i, line in ipairs(ownedLines(layer, seed, rx + ox, ry + oy)) do
                    local r = line.width / 2
                    for p = 1, #line.points, 2 do
                        local cx, cy = line.points[p], line.points[p + 1]
                        for x = math.max(x0, math.floor(cx - r)), math.min(x0 + n - 1, math.ceil(cx + r)) do
                            for y = math.max(y0, math.floor(cy - r)), math.min(y0 + n - 1, math.ceil(cy + r)) do
                                local ddx, ddy = x + 0.5 - cx, y + 0.5 - cy
                                local index = (x - x0) * n + (y - y0)
                                if ddx * ddx + ddy * ddy <= r * r and (grid[index] == nil or grid[index].rate < line.rate) then
                                    grid[index] = line
                                end
                            end
                        end
                    end
                end
            end
        end
        layer.cells[key] = grid
    end
    return layer.cells[key]
end


function LeyLines.at(tx, ty, seed)
    -- The strongest line on a tile across the layers, nil for none: {id, kind, width, rate}
    fresh(seed)
    local best = nil
    for i, layer in ipairs(layers) do
        local n = layer.def.region
        local rx, ry = math.floor(tx / n), math.floor(ty / n)
        local line = region(layer, seed, rx, ry)[(tx - rx * n) * n + (ty - ry * n)]
        if line ~= nil and (best == nil or line.rate > best.rate) then
            best = line
        end
    end
    return best
end


function LeyLines.seen()
    -- True while the player wears Ley Goggles(a trinket with leySight, see items/trinkets)
    local equipment = player ~= nil and player.equipment
    for i, slot in ipairs({"trinket1", "trinket2"}) do
        local stack = equipment and equipment[slot]
        local item = stack and ITEM_REGISTRY[stack.item]
        if item and item.effect and item.effect.leySight then
            return true
        end
    end
    return false
end


function LeyLines.draw(camX, camY)
    -- World space, over the light, while the goggles are worn: the lines around the camera in the mana effect,
    -- wider lines drawn wider and brighter
    if not LeyLines.seen() then
        return
    end
    local seed = map.seed
    fresh(seed)
    local w, h = love.graphics.getDimensions()
    local x1, x2 = (camX - w / 2) / TILE_SIZE, (camX + w / 2) / TILE_SIZE
    local y1, y2 = (camY - h / 2) / TILE_SIZE, (camY + h / 2) / TILE_SIZE
    love.graphics.push("all")
    for i, layer in ipairs(layers) do
        local n = layer.def.region
        for rx = math.floor(x1 / n) - 1, math.floor(x2 / n) + 1 do
            for ry = math.floor(y1 / n) - 1, math.floor(y2 / n) + 1 do
                for j, line in ipairs(ownedLines(layer, seed, rx, ry)) do
                    -- Drawn half as wide as the tiles it covers, so it marks the line without hiding the world
                    love.graphics.setColor(LEY_COLOR[1], LEY_COLOR[2], LEY_COLOR[3], 0.35 + 0.1 * line.width)
                    local p = line.points
                    -- Short pieces(8 tiles), so the line bends a little at every joint and the joints dont show,
                    -- only the ones near the screen
                    for k = 1, #p - 2, 4 do
                        local last = math.min(k + 4, #p - 1)
                        local ax, ay, bx, by = p[k], p[k + 1], p[last], p[last + 1]
                        if math.max(ax, bx) > x1 - 4 and math.min(ax, bx) < x2 + 4 and math.max(ay, by) > y1 - 4 and math.min(ay, by) < y2 + 4 then
                            ManaShader.beam(ax * TILE_SIZE, ay * TILE_SIZE, bx * TILE_SIZE, by * TILE_SIZE, line.width * TILE_SIZE * 0.5)
                        end
                    end
                end
            end
        end
    end
    love.graphics.pop()
end

return LeyLines
