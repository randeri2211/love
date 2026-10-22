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
    -- New random seed, loading a world replaces it with the saved one
    map = Map:new(MAP_Y)
    spells = Spells:new()
    -- Physics init
    love.physics.setMeter(TILE_SIZE * TILES_PER_METER)
    p_world = love.physics.newWorld(0, GRAVITY, true)

    -- Player init, standing on the ground of column 1
    player = Player:new(TILE_SIZE, map:surfaceY(1) - PLAYER_HEIGHT - TILE_SIZE, "snaposaurus")

    -- World collision callbacks
    p_world:setCallbacks(startCollisionCallback, finishCollisionCallback, preSolve, postSolve)
end


function manageHitbox()
    local x_diff = math.floor(loveToWorldSingle(SCREEN_X / 2) + CAMERA_RENDER_OFFSET)
    local y_diff = math.floor(loveToWorldSingle(SCREEN_Y / 2) + CAMERA_RENDER_OFFSET)
    local p_x,p_y = loveToMap(player.body:getWorldCenter())
    local destroyDistance = 3
    -- The map is infinite sideways, only the top and bottom have an edge
    for x = p_x - x_diff - destroyDistance, p_x + x_diff + destroyDistance do
        for y = math.max(p_y - y_diff - destroyDistance, 1),math.min(p_y + y_diff + destroyDistance, map.height) do
            local block = map:get(x, y)
            if block ~= nil then
                -- In the body destroy area
                if x < p_x - x_diff or x > p_x +x_diff or y < p_y - y_diff or y > p_y + y_diff then
                    -- If outside of range, destroy the body
                    block:destroyBody()
                -- In the body generate area
                else
                    -- If in range, and one of the neighbors is not a block,or at the top or bottom edge, generate a body
                    if y > 1 and y < map.height then
                        if map:get(x - 1, y) == nil or map:get(x + 1, y) == nil or map:get(x, y - 1) == nil or map:get(x, y + 1) == nil then
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


function getEntityFromFixture(fixture)
    -- Block or enemy that owns a fixture, nil for anything else
    if fixture:getCategory() == BLOCKS_CATEGORY then
        local x, y = loveToMap(fixture:getBody():getWorldCenter())
        return map:get(x, y)
    elseif fixture:getCategory() == ENEMY_CATEGORY then
        return map.enemies:getEnemyByFixture(fixture)
    end
    return nil
end


function startCollisionCallback(fixture1, fixture2, contact)
    -- Spell hit section
    if fixture1:getCategory() == SPELLS_CATEGORY or fixture2:getCategory() == SPELLS_CATEGORY then
        -- Swap positions if fixture2 is the spell for simplicity going forward
        if fixture2:getCategory() == SPELLS_CATEGORY then
            fixture1, fixture2 = fixture2, fixture1
        end
        print("spell collision"..fixture2:getCategory())

        -- Each form decides what touching something means(see Form:onContact)
        local spellPair = spells:getSpellByFixture(fixture1)
        if spellPair then
            spellPair.instance:onContact(fixture2, getEntityFromFixture(fixture2), contact)
        end
    end

    -- Player enemy collision
    if fixture1:getCategory() == PLAYER_CATEGORY or fixture2:getCategory() == PLAYER_CATEGORY then
        -- Swap positions if fixture2 is the player for simplicity going forward
        -- print("player collision")
        if fixture2:getCategory() == PLAYER_CATEGORY then
            fixture1, fixture2 = fixture2, fixture1
        end

        if fixture2:getCategory() == ENEMY_CATEGORY then
            -- print("enemy player collision")
        else
            -- print("collision with category "..fixture2:getCategory())
        end

    end

end


function finishCollisionCallback(fixture1, fixture2, contact)
end

function preSolve(fixture1, fixture2, contact)
    -- Spells can turn off contacts they pass through(see Bullet pierce)
    if fixture1:getCategory() == SPELLS_CATEGORY or fixture2:getCategory() == SPELLS_CATEGORY then
        if fixture2:getCategory() == SPELLS_CATEGORY then
            fixture1, fixture2 = fixture2, fixture1
        end
        local spellPair = spells:getSpellByFixture(fixture1)
        if spellPair then
            spellPair.instance:preSolve(fixture2, contact)
        end
    end

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
    if mx == nil or my == nil then
        return
    end

    local block = map:get(mx, my)
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