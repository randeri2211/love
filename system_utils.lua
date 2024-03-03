camera = require "libraries.hump.camera"
require "world.map"

function initVars()
    game_cam = camera()
    enemies = {}        -- Global enemies array
    blocks = {}         -- Global blocks array
    map = Map(MAP_X, MAP_Y)
    map.emptyMap()
    -- Physics init
    love.physics.setMeter(1)
    p_world = love.physics.newWorld(0, GRAVITY, true)

    -- Player init
    player = Player(TILE_SIZE, - TILE_SIZE)
    print(map.center.x)
    -- World collision callbacks
    p_world:setCallbacks(startCollisionCallback, finishCollisionCallback, nil, nil)
end

function initScreen()

end

function startCollisionCallback(fixture1, fixture2, contact)
    if fixture1 == player.fixture or fixture2 == player.fixture then

    end
    -- print("fixture1: " .. tostring(fixture1))
    -- print("fixture2: " .. tostring(fixture2))
    -- print("contact: " .. tostring(contact))
end


function finishCollisionCallback(fixture1, fixture2, contact)
    if player.fixture_check[fixture1] or player.fixture_check[fixture2] then
        player.grounded = false
    end
    -- print("fixture1: " .. tostring(fixture1))
    -- print("fixture2: " .. tostring(fixture2))
    -- print("contact: " .. tostring(contact))
end

-- Ground Check Functions
function groundRay()
    player.grounded = false
    local p_x, p_y = player.body:getWorldCenter()
    p_world:rayCast(p_x, p_y + PLAYER_HEIGHT / 2, p_x, p_y + PLAYER_HEIGHT / 2 + 0.1, groundCallback)
end

function groundCallback(fixture, x, y, xn, yn, fraction)
    for i = 1, #player.fixtures do
        if fixture == player.fixture then
            return 0
        end
    end
    player.grounded = true
    return 0
end

function tempMap()
    for i = 1, map.width do
        for j = 0, 3 do
            local block = Block((i - map.center.x - 1) * TILE_SIZE, j * TILE_SIZE, TILE_SIZE, TILE_SIZE)
            map.insert(block)
        end
    end
    addEnemy(Enemy1(0,-200))
    addEnemy(Enemy1(200,-200))
    addEnemy(Enemy1(300,-200))
    addEnemy(Enemy(-200,-200))
    addEnemy(Enemy(-300,-200))
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
    printGrounded()
    printUp()
    printJumping()
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
    local gravity = loveToWorldSingle(player.body:getGravityScale() * GRAVITY)
    love.graphics.print("gravity:(" .. gravity .. ")",0,order * 10)
    order = order + 1
end

function printGrounded()
    love.graphics.print("grounded:" .. tostring(player.grounded),0,order * 10)
    order = order + 1
end

function printUp()
    love.graphics.print("up:" .. tostring(player.up),0,order * 10)
    order = order + 1
end

function printJumping()
    love.graphics.print("jumping:" .. tostring(player.jumping),0,order * 10)
    order = order + 1
end