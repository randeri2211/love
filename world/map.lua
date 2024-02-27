
function Map(width,height)
    -- Map Variables
    local map = {}
    map.map = {}
    map.width = width
    map.height = height
    map.center = {x = math.floor(map.width * SPAWN_X) + 1,
                    y = math.floor(map.height * SPAWN_Y) + 1}

    
    -- Map Functions
    function map.emptyMap()
        for x = 1, map.width + 1 do
            map.map[x] = {}
            for y = 1, map.height + 1 do
                map.map[x][y] = nil
            end
        end
    end


    function map.insert(block)
        
        local x, y = block.body:getWorldCenter()


        -- Calculate position on the map
        x = math.floor(x / TILE_SIZE + map.center.x)
        y = math.floor(y / TILE_SIZE + map.center.y)

        
        map.map[x][y] = block
    end

    function map.draw()
        for i, col in pairs(map.map) do
            for j, block in pairs(col) do
                -- local block = map.map[i][j]
                if block ~= nil then
                    local x, y = game_cam:cameraCoords(block.body:getWorldCenter())
                    if x > - CAMERA_RENDER_OFFSET - block.width and x < SCREEN_X + CAMERA_RENDER_OFFSET + block.width and y > - CAMERA_RENDER_OFFSET - block.height and y < SCREEN_Y + CAMERA_RENDER_OFFSET + block.height then
                        block.draw()
                    end
                end
            end
        end
    end

    return map
end


