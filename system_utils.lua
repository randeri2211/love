camera = require "libraries.hump.camera"
require "world.map"

function initVars()
    game_cam = camera()
    enemies = {}        -- Global enemies array
    blocks = {}         -- Global blocks array
    map = Map(SCREEN_X - 1, SCREEN_Y - 1)
    map.emptyMap()
    -- Physics init
    love.physics.setMeter(1)
    p_world = love.physics.newWorld(0, GRAVITY, true)

    -- Player init
    player = Player(map.center.x, map.center.y)

    -- World collision callbacks
    p_world:setCallbacks(collisionCallback, nil, nil, nil)

    
    -- tempMap()
end

function initScreen()

end

function collisionCallback(collider1, collider2, contact)
    -- print("collider1: " .. tostring(collider1))
    -- print("collider2: " .. tostring(collider2))
    -- print("contact: " .. tostring(contact))
end

function tempMap()

    for i = 0, map.width do
        for j = 1, 3 do
            local block = Block((i - math.floor(map.width / 2)) * TILE_SIZE , map.center.y + j * TILE_SIZE, TILE_SIZE, TILE_SIZE)
            map.insert(block)
        end
    end

    addEnemy(Enemy1(100,-200))
    addEnemy(Enemy1(200,-200))
    addEnemy(Enemy1(300,-200))
    addEnemy(Enemy(400,-200))
    addEnemy(Enemy(500,-200))
end

-- Enemy Util Functions
function drawEnemies()
    for i, enemy in pairs(enemies) do
        -- print(i)
        -- print(tostring(enemy))
        local x, y = enemy.body:getWorldCenter()
        local x, y = game_cam:cameraCoords(x, y)
        if x > - CAMERA_RENDER_OFFSET and x < SCREEN_X + CAMERA_RENDER_OFFSET and y > - CAMERA_RENDER_OFFSET and y < SCREEN_Y + CAMERA_RENDER_OFFSET then
            enemy.draw()
        end
    end
end

function moveEnemies(x, y)
    for i in pairs(enemies) do
        enemies[i].move(x, y)
        enemies[i].wakeUp()
    end
end

function addEnemy(enemy)
    local arrSize = table.getn(enemies)
    enemies[arrSize + 1] = enemy
end





-- Debug Util Functions
local order = 0
function debugPrint()
    order = 0
    --meant to help debug issues,comment or uncomment any necessary debug function 
    printPosition()
    printVelocity()
    printGravity()
    printAwake()
end

function printPosition()
    local x, y = loveToWorld(player.body:getWorldCenter())
    love.graphics.print("pos:(" .. string.format("%.2f",tostring(x)) .. ","..string.format("%.2f",tostring(y)) .. ")",0,order * 10)
    order = order + 1
end

function printVelocity()
    local x, y = loveToWorld(player.body:getLinearVelocity())
    love.graphics.print("vel:(" .. string.format("%.2f",tostring(x)) .. ","..string.format("%.2f",tostring(y)) .. ")",0,order * 10)
    order = order + 1
end

function printAwake()
    love.graphics.print("awake:" .. tostring(player.body:isAwake()),0,order * 10)
    order = order + 1
end

function printGravity()
    local gravity = player.body:getGravityScale() * GRAVITY
    love.graphics.print("gravity:(" .. gravity .. ")",0,order * 10)
    order = order + 1
end