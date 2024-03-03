

function Map(width,height)
    -- Map Variables
    local map = {}
    map.map = {}
    map.width = width
    map.height = height
    map.center = {x = math.floor(map.width * SPAWN_X + 0.5),
                    y = math.floor(map.height * SPAWN_Y + 0.5)}

    
    -- Map Functions
    function map.emptyMap()
        -- Empty the map
        for x = 1, map.width do
            map.map[x] = {}
            for y = 1, map.height do
                map.map[x][y] = nil
            end
        end
    end


    function map.insert(block)
        local x, y = loveToWorld(block.fixture:getBoundingBox())
        x, y = worldToMap(x, y)

        map.map[x][y] = block
    end

    function map.draw()
        -- Only draw blocks around the player to not waste time
        local x, y = loveToWorld(player.body:getWorldCenter())
        local x_diff = loveToWorldSingle(SCREEN_X / 2 + CAMERA_RENDER_OFFSET)
        local y_diff = loveToWorldSingle(SCREEN_Y / 2 + CAMERA_RENDER_OFFSET)
        local p_x,p_y = loveToMap(player.body:getWorldCenter())
        
        for row = p_x - x_diff,p_x +x_diff do
            for col = p_y - y_diff,p_y + y_diff do
                if row > 0 and row <= map.width and col > 0 and col <= map.height then
                    block = map.map[row][col]
                    if block ~= nil then
                        block.draw()
                    end
                end
            end
        end
    end


    function map.update()
        -- Set every block close to the player to awake, sets blocks in a distance of turnOffDistance out of the update distance to sleep
        local x, y = loveToWorld(player.body:getWorldCenter())
        local x_diff = loveToWorldSingle(SCREEN_X / 2 + CAMERA_RENDER_OFFSET)
        local y_diff = loveToWorldSingle(SCREEN_Y / 2 + CAMERA_RENDER_OFFSET)
        local turnOffDistance = 3

        local p_x,p_y = loveToMap(player.body:getWorldCenter())
        for row = p_x - x_diff - turnOffDistance,p_x +x_diff + turnOffDistance do
            for col = p_y - y_diff - turnOffDistance,p_y + y_diff + turnOffDistance do
                if row > 0 and row <= map.width and col > 0 and col <= map.height then
                    block = map.map[row][col]
                    if block ~= nil then
                        if row < p_x - x_diff or row > p_x +x_diff or col < p_y - y_diff or col > p_y + y_diff then
                            if block.body:isAwake() == true then
                                block.body:setAwake(false)
                            end
                        else
                            if block.body:isAwake() == false then
                                block.body:setAwake(true)
            
                            end
                        end
                    end
                end
            end
        end
    end

    return map
end


