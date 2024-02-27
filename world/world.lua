require "constants"

function loveToWorld(l_x, l_y)
    return l_x / TILE_SIZE / TILES_PER_METER, - l_y / TILE_SIZE / TILES_PER_METER
end

function worldToLove(w_x, w_y)
    return w_x * TILE_SIZE * TILES_PER_METER, w_y * TILE_SIZE * TILES_PER_METER
end