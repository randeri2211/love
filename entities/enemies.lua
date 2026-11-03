local Hud = require "ui.hud"
local EnemyCasting = require "magic.enemyCasting"

local Enemies = {}

function Enemies:new()
    local enemies = {}
    setmetatable(enemies, self)
    self.__index = self

    enemies.enemies = {}

    return enemies
end


function Enemies:update(dt)
    for i, enemy in pairs(self.enemies) do
        enemy:update(dt)
    end
end


function Enemies:draw()
    for i, enemy in pairs(self.enemies) do
        local x, y = enemy.body:getWorldCenter()
        local x, y = game_cam:cameraCoords(x, y)
        if x > - CAMERA_RENDER_OFFSET and x < SCREEN_X + CAMERA_RENDER_OFFSET and y > - CAMERA_RENDER_OFFSET and y < SCREEN_Y + CAMERA_RENDER_OFFSET then
            enemy:draw()
            -- The same hp bar as the player hud, small over the head(the hud keeps the trail per enemy)
            -- Dead enemies drop their bar
            if not enemy.dying then
                enemy.hud = enemy.hud or Hud:new(enemy)
                local ex, ey = enemy.body:getWorldCenter()
                enemy.hud:drawOverhead(ex, ey - (enemy.height or 0) / 2)
            end
        end
    end
end

function Enemies:drawCasting()
    -- Cast circles of enemies building a spell, drawn after the time of day light like the spells(see main)
    for i, enemy in pairs(self.enemies) do
        if enemy.casting ~= nil then
            EnemyCasting.draw(enemy)
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
    table.insert(self.enemies, enemy)
end

function Enemies:removeEnemy(enemy)
    for i, e in ipairs(self.enemies) do
        if e == enemy then
            table.remove(self.enemies, i)
            return true
        end
    end
    return false
end


function Enemies:getEnemyByFixture(fixture)
    for i, enemy in pairs(self.enemies) do
        if enemy:isFixture(fixture) then
            return enemy
        end
    end
end

return Enemies