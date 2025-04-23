function loveToWorld(l_x, l_y)
    -- Converts love default coordinates into game world coordinates
    return l_x / TILE_SIZE / TILES_PER_METER, - l_y / TILE_SIZE / TILES_PER_METER
end

function worldToLove(w_x, w_y)
    -- Converts game world coordinates back into love coordinates
    return w_x * TILE_SIZE * TILES_PER_METER, w_y * TILE_SIZE * TILES_PER_METER
end

function loveToWorldSingle(num)
    -- Converts a single number from love coordinates to world coordinates
    return num / TILE_SIZE / TILES_PER_METER
end

function loveToMap(l_x, l_y)
    -- Converts love coordinates to map coordinates (rounded down for use in map)
    local x, y = loveToWorld(l_x, l_y)
    return worldToMap(x, y)
end


function loveToMapSmooth(l_x,l_y)
    -- Converts love coordinates to map coordinates
    local x, y = loveToWorld(l_x, l_y)
    return worldToMapSmooth(x, y)
end


function worldToMapSmooth(w_x, w_y)
    -- Calculate position on the map(i dont even remember why 1 and 1.5 work for x and y...)
    local x, y = w_x + map.center.x + 1, w_y + map.center.y + 1
    return x, y
end


function worldToMap(w_x, w_y)
    -- Calculate position on the map(add + 1 cause lua starts array with 1 ffs)
    local x, y = math.floor(w_x + map.center.x + 1), math.floor(w_y + map.center.y + 1.5)
    return x, y
end

function mouseToLove()
    local mx, my = love.mouse.getPosition()
    mx, my = game_cam:worldCoords(mx, my)
    return mx, my
end

function mouseToWorld()
    local mx, my = mouseToLove()
    return loveToWorld(mx, my)
end

function mouseToMap()
    local mx, my = mouseToWorld()
    mx = math.floor(mx)
    my = math.floor(my) + 1
    mx, my = worldToMap(mx, my)
    return mx, my
end

function distance(x1, y1, x2, y2)
    return math.sqrt((x1 - x2)^2 + (y1 - y2)^2)
end