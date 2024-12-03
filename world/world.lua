require "constants"

function loveToWorld(l_x, l_y)
    return l_x / TILE_SIZE / TILES_PER_METER, - l_y / TILE_SIZE / TILES_PER_METER
end

function worldToLove(w_x, w_y)
    return w_x * TILE_SIZE * TILES_PER_METER, w_y * TILE_SIZE * TILES_PER_METER
end

function loveToWorldSingle(num)
    return num / TILE_SIZE / TILES_PER_METER
end

function loveToMap(l_x, l_y)
    local x, y = loveToWorld(l_x, l_y)
    return worldToMap(x, y)
end

function worldToMap(w_x, w_y)
    -- Calculate position on the map(add 1 to account for block size and 0.51 for rounding error)
    return math.floor(w_x + map.center.x + 1.51), math.floor(w_y + map.center.y + 1.51)
end