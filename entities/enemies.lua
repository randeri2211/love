Enemies = {}

function Enemies:new()
    local enemies = {}
    setmetatable(enemies, self)
    self.__index = self

    enemies.enemies = {}

    return enemies
end


function Enemies:drawEnemies()
    for i, enemy in pairs(self.enemies) do
        -- print(i)
        -- print(tostring(enemy))
        local x, y = enemy.body:getWorldCenter()
        local x, y = game_cam:cameraCoords(x, y)
        if x > - CAMERA_RENDER_OFFSET and x < SCREEN_X + CAMERA_RENDER_OFFSET and y > - CAMERA_RENDER_OFFSET and y < SCREEN_Y + CAMERA_RENDER_OFFSET then
            enemy:draw()
        end
    end
end

function Enemies:moveEnemies(x, y)
    for i, enemy in pairs(self.enemies) do
        enemy.move(x, y)
        enemy.wakeUp()
    end
end

function Enemies:addEnemy(enemy)
    local arrSize = #self.enemies
    self.enemies[arrSize + 1] = enemy
end
