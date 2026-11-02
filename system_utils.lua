local camera = require "libraries.hump.camera"
local Map = require "world_utils.map"
local Spells = require "magic.spells"
local Player = require "entities.player"
local Block = require "blocks.block"
local Enemy = require "entities.enemy"
local Enemy1 = require "entities.enemy1"

function initVars(settings)
    -- settings are the world generation choices of a new world, loading a world replaces them with the saved ones
    player_control = true
    paused = false

    game_cam = camera()
    -- New random seed, loading a world replaces it with the saved one
    map = Map:new(MAP_Y, nil, settings or {biomeWidth = BIOME_SIZES[DEFAULT_BIOME_SIZE][2], dayLength = DAY_LENGTH, flora = FLORA_VERSION})
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
    -- Blocks around the player have hitboxes, the map only does work when the player moves to another tile
    local x_diff = math.floor(loveToWorldSingle(SCREEN_X / 2) + CAMERA_RENDER_OFFSET)
    local y_diff = math.floor(loveToWorldSingle(SCREEN_Y / 2) + CAMERA_RENDER_OFFSET)
    local p_x,p_y = loveToMap(player.body:getWorldCenter())
    map:updateHitboxes(p_x - x_diff, p_y - y_diff, p_x + x_diff, p_y + y_diff)
end


function getEntityFromFixture(fixture)
    -- Block or enemy that owns a fixture, nil for anything else(blocks and enemies keep themselves on their fixture)
    local owner = fixture:getUserData()
    if owner ~= nil then
        return owner
    end
    if fixture:getCategory() == ENEMY_CATEGORY then
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
    -- Sets p.grounded when something is under its feet: short rays down at the left, middle and right of the feet
    -- The rays start a little inside the body, standing on the edge of a block its corner is above the lowest point
    -- of the round feet, and a ray that starts inside a block doesnt see it
    local function groundCallback(fixture, x, y, xn, yn, fraction)
        local category = fixture:getCategory()
        if fixture:getBody() == p.body or category == SPELLS_CATEGORY or category == ITEM_CATEGORY or fixture:isSensor() then
            return -1   -- Its own body, spells and dropped items arent ground, keep looking
        end
        p.grounded = true
        return 0
    end
    p.grounded = false
    local p_x, p_y = p.body:getWorldCenter()
    local bottom = p_y + p.height / 2
    local width = p.width or p.height / 2
    for i, side in ipairs(GROUND_RAY_SPOTS) do
        local x = p_x + side * width
        p_world:rayCast(x, bottom - width * GROUND_RAY_START, x, bottom + 2, groundCallback)
        if p.grounded then
            return
        end
    end
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
    printBiome()
    printTime()
end

function printTime()
    local WorldClock = require "world_utils.worldClock"
    local hours = WorldClock.phase() * 24
    love.graphics.print(string.format("time: %02d:%02d  light %.2f", math.floor(hours), math.floor((hours % 1) * 60), WorldClock.light()), 0, order * love.graphics.getFont():getHeight())
    order = order + 1
end

function printBiome()
    local Biomes = require "world_utils.biomes"
    local Generator = require "world_utils.generator"
    local x, y = player.body:getWorldCenter()
    local tx, ty = math.floor(x / TILE_SIZE), math.floor(y / TILE_SIZE)
    local biome = Biomes.at(tx, ty, map.seed, map.settings, Generator.surfaceRow(tx, map.seed, map.settings))
    love.graphics.print("biome: " .. biome.name, 0, order * love.graphics.getFont():getHeight())
    order = order + 1
end

function printPosition()
    local x, y = loveToMapSmooth(player.body:getWorldCenter())
    love.graphics.print("pos:(" .. string.format("%.2f",tostring(x)) .. ","..string.format("%.2f",tostring(y)) .. ")",0,order * love.graphics.getFont():getHeight())
    order = order + 1
end

function printVelocity()
    local x, y = loveToWorld(player.body:getLinearVelocity())
    love.graphics.print("vel:(" .. string.format("%.2f",tostring(x)) .. ","..string.format("%.2f",tostring(y)) .. ")",0,order * love.graphics.getFont():getHeight())
    order = order + 1
end

function printAwake()
    love.graphics.print("awake:" .. tostring(player.body:isAwake()),0,order * love.graphics.getFont():getHeight())
    order = order + 1
end

function printGravity()
    local gravity = loveToWorldSingle(player.body:getGravityScale() * GRAVITY)
    love.graphics.print("gravity:(" .. gravity .. ")",0,order * love.graphics.getFont():getHeight())
    order = order + 1
end

function printGrounded()
    love.graphics.print("grounded:" .. tostring(player.grounded),0,order * love.graphics.getFont():getHeight())
    order = order + 1
end

function printUp()
    love.graphics.print("up:" .. tostring(player.up),0,order * love.graphics.getFont():getHeight())
    order = order + 1
end

function printJumping()
    love.graphics.print("jumping:" .. tostring(player.jumping),0,order * love.graphics.getFont():getHeight())
    order = order + 1
end