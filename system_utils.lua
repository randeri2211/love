local camera = require "libraries.hump.camera"
local Map = require "world_utils.map"
local Spells = require "magic.spells"
local Player = require "entities.player"
local Block = require "blocks.block"
local Enemy = require "entities.enemy"
local Enemy1 = require "entities.enemy1"

function initVars()
    player_control = true
    paused = false

    game_cam = camera()
    map = Map:new(MAP_X, MAP_Y)
    map:emptyMap()
    spells = Spells:new()
    -- Physics init
    love.physics.setMeter(TILE_SIZE * TILES_PER_METER)
    p_world = love.physics.newWorld(0, GRAVITY, true)
    
    -- Player init
    player = Player:new(TILE_SIZE, - TILE_SIZE, "snaposaurus")

    -- World collision callbacks
    p_world:setCallbacks(startCollisionCallback, finishCollisionCallback, preSolve, postSolve)
end


function manageHitbox()
    local x_diff = math.floor(loveToWorldSingle(SCREEN_X / 2) + CAMERA_RENDER_OFFSET)
    local y_diff = math.floor(loveToWorldSingle(SCREEN_Y / 2) + CAMERA_RENDER_OFFSET)
    local p_x,p_y = loveToMap(player.body:getWorldCenter())
    local destroyDistance = 3    
    for x = math.max(p_x - x_diff - destroyDistance, 1), math.min(p_x + x_diff + destroyDistance, map.width) do
        for y = math.max(p_y - y_diff - destroyDistance, 1),math.min(p_y + y_diff + destroyDistance, map.height) do
            -- Making sure were only checking within map bounds (might be redundant)
            if x > 0 and x <= map.width and y > 0 and y <= map.height then
                local block = map.map[x][y]
                if block ~= nil then
                    -- In the body destroy area
                    if x < p_x - x_diff or x > p_x +x_diff or y < p_y - y_diff or y > p_y + y_diff then
                        -- If outside of range, destroy the body
                        block:destroyBody()
                    -- In the body generate area
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
    -- Spell hit section
    if fixture1:getCategory() == SPELLS_CATEGORY or fixture2:getCategory() == SPELLS_CATEGORY then
        -- Swap positions if fixture2 is the spell for simplicity going forward
        if fixture2:getCategory() == SPELLS_CATEGORY then
            fixture1, fixture2 = fixture2, fixture1
        end

        local spellPair = spells:getSpellByFixture(fixture1)
        local entity = nil
        if fixture2:getCategory() == BLOCKS_CATEGORY then
            local x, y = loveToMap(fixture2:getBody():getWorldCenter())
            entity = map.map[x][y]
        end

        if fixture2:getCategory() == ENEMY_CATEGORY then
            entity = map.enemies:getEnemyByFixture(fixture2)
        end

        
        if spellPair then
            if entity ~= nil then
                entity:damage(spellPair.spell.damage)
            end

            spells:destroy(spellPair.instance)
        end
    end

    -- Player enemy collision
    if fixture1:getCategory() == PLAYER_CATEGORY or fixture2:getCategory() == PLAYER_CATEGORY then
        -- Swap positions if fixture2 is the player for simplicity going forward
        print("player collision")
        if fixture2:getCategory() == PLAYER_CATEGORY then
            fixture1, fixture2 = fixture2, fixture1
        end

        if fixture2:getCategory() == ENEMY_CATEGORY then
            print("enemy player collision")
        else
            print("collision with category "..fixture2:getCategory())
        end

    end

end


function finishCollisionCallback(fixture1, fixture2, contact)
end

function preSolve(fixture1, fixture2, contact)
    if fixture1:getCategory() == PLAYER_CATEGORY or fixture2:getCategory() == PLAYER_CATEGORY then
        -- Swap positions if fixture2 is the spell for simplicity going forward
        if fixture2:getCategory() == PLAYER_CATEGORY then
            fixture1, fixture2 = fixture2, fixture1
        end

        if fixture2:getCategory() == BLOCKS_CATEGORY then
            -- Get the normal vector of the collision
            local nx, ny = contact:getNormal()

            -- Check if the contact is horizontal (wall), i.e., normal is mostly x
            if math.abs(nx) > math.abs(ny) then
                -- Disable friction for this contact
                contact:setFriction(0)
            end
        end
    end
end

function postSolve(fixture1, fixture2, contact, normal, tangent)
end

-- Ground Check Functions
function groundRay(p)
    function groundCallback(fixture, x, y, xn, yn, fraction)
        if p.fixtures ~= nil then
            for i = 1, #p.fixtures do
                if fixture == p.fixtures[i] then
                    return 0
                end
            end
        end
        p.grounded = true
        return 0
    end
    p.grounded = false
    local p_x, p_y = p.body:getWorldCenter()
    p_world:rayCast(p_x, p_y + p.height / 2, p_x, p_y + p.height / 2 + 1, groundCallback)
end




function tooltipDraw()
    -- Check if mouse is hovering
    if paused then
        return
    end
    local mx, my = mouseToMap()
    if mx == nil or my == nil or mx <= 0 or mx > MAP_X or my <= 0 or my > MAP_Y then
        return
    end
    
    local block = map.map[mx][my]
    if block ~= nil then
        if block.tooltipText ~= nil then
            -- Draw tooltip
            mx, my = love.mouse.getPosition()
            love.graphics.setColor(0, 0, 0, 0.7) -- Semi-transparent background
            love.graphics.rectangle("fill", mx + 10, my + 10, 250, 20)
            love.graphics.setColor(1, 1, 1, 1) -- White text
            love.graphics.print(block.tooltipText, mx + 15, my + 15)
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end
    end
end


function tempMap()
    for i = 1, map.width do
        for j = 0, 4 do
            local block = Block:new((i - map.center.x - 1) * TILE_SIZE, j * TILE_SIZE, TILE_SIZE, TILE_SIZE)
            map:insert(block)
        end
    end
    map:insert(Block2:new(5 * TILE_SIZE, -1*TILE_SIZE, TILE_SIZE, TILE_SIZE / 2))
    map:insert(InteractiveBlock:new(6 * TILE_SIZE, -1 * TILE_SIZE, TILE_SIZE, TILE_SIZE))
    map:insert(InteractiveBlock:new(6 * TILE_SIZE, -2 * TILE_SIZE, TILE_SIZE, TILE_SIZE))
    map:insert(InteractiveBlock:new(6 * TILE_SIZE, -3 * TILE_SIZE, TILE_SIZE, TILE_SIZE))
    map:insert(InteractiveBlock:new(7 * TILE_SIZE, -1 * TILE_SIZE, TILE_SIZE, TILE_SIZE))
    map.enemies:addEnemy(Enemy1:new(0,-200))
    -- map.enemies:addEnemy(Enemy1:new(200,-200))
    -- map.enemies:addEnemy(Enemy1:new(300,-200))
    -- map.enemies:addEnemy(Enemy:new(-200,-200))
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
    local x, y = loveToMapSmooth(player.body:getWorldCenter())
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