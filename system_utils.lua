camera = require "libraries.hump.camera"
require "world.map"
require "blocks.block2"
function initVars()
    game_cam = camera()
    map = Map:new(MAP_X, MAP_Y)
    map:emptyMap()
    -- Physics init
    love.physics.setMeter(1)
    p_world = love.physics.newWorld(0, GRAVITY, true)

    -- Player init
    player = Player:new(TILE_SIZE, - TILE_SIZE)

    -- World collision callbacks
    p_world:setCallbacks(startCollisionCallback, finishCollisionCallback, nil, nil)
end


function manageHitbox()
    local x_diff = math.floor(loveToWorldSingle(SCREEN_X / 2 + CAMERA_RENDER_OFFSET))
    local y_diff = math.floor(loveToWorldSingle(SCREEN_Y / 2 + CAMERA_RENDER_OFFSET))
    local p_x,p_y = loveToMap(player.body:getWorldCenter())
    local turnOffDistance = 3
    
    for x = p_x - x_diff,p_x +x_diff do
        for y = p_y - y_diff,p_y + y_diff do

            if x > 0 and x <= map.width and y > 0 and y <= map.height then
                local block = map.map[x][y]
                if block ~= nil then
                    if x < p_x - x_diff or x > p_x +x_diff or y < p_y - y_diff or y > p_y + y_diff then
                        -- If outside of range, destroy the body
                        if block.body ~= nil then
                            block.body:destroy()
                        end
                    else
                        local bx, by = loveToMap(block.x, block.y)
                        -- If in range, and one of the neighbors is not a block,or at the edge of the map, generate a body
                        if bx > 1 and bx < map.width and by > 1 and by < map.height then
                            if map.map[x - 1][y] == nil or map.map[x + 1][y] == nil or map.map[x][y - 1] == nil or map.map[x][y + 1] == nil then
                                block:generateBody()
                            end
                        else
                            block:generateBody()
                        end
                    end
                end
            end
        end
    end
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
        for j = 0, 100 do
            local block = Block:new((i - map.center.x - 1) * TILE_SIZE, j * TILE_SIZE, TILE_SIZE, TILE_SIZE)
            map:insert(block)
        end
    end
    local block = Block2:new(5 * TILE_SIZE, -1*TILE_SIZE, TILE_SIZE, TILE_SIZE / 2)
    map:insert(block)
    map.enemies:addEnemy(Enemy1:new(0,-200))
    map.enemies:addEnemy(Enemy1:new(200,-200))
    map.enemies:addEnemy(Enemy1:new(300,-200))
    map.enemies:addEnemy(Enemy:new(-200,-200))
    map.enemies:addEnemy(Enemy:new(-300,-200))
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