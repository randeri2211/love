require "entities.enemies"
Map = {}

function Map:new(width,height)
    map = {}
    setmetatable(map,self)
    self.__index = self
    map.map = {}
    map.width = width
    map.height = height
    map:emptyMap()
    map.center = {x = math.floor(map.width * SPAWN_X + 0.5),
                    y = math.floor(map.height * SPAWN_Y + 0.5)}
    return map
end


-- Map Functions
function Map:emptyMap()
    self.enemies = Enemies:new()
    -- Empty the map
    for x = 1, self.width do
        self.map[x] = {}
        for y = 1, self.height do
            self.map[x][y] = nil
        end
    end
end


function Map:insert(block)
    -- Convert to map coordinates
    x, y = loveToMap(block.x, block.y)
    self.map[x][y] = block
end

function Map:draw()
    -- Only draw blocks around the player to not waste time
    local x_diff = math.floor(loveToWorldSingle(SCREEN_X / 2) + CAMERA_RENDER_OFFSET)
    local y_diff = math.floor(loveToWorldSingle(SCREEN_Y / 2) + CAMERA_RENDER_OFFSET)
    local p_x,p_y = loveToMap(player.body:getWorldCenter())
    for x = p_x - x_diff,p_x + x_diff do
        for y = p_y - y_diff,p_y + y_diff do
            if x > 0 and x <= self.width and y > 0 and y <= self.height then
                local block = self.map[x][y]
                if block ~= nil then
                    block:draw()
                end
            end
        end
    end

    map.enemies:drawEnemies()
end

