require "registry"
require "system_utils"

require "keys"
require "assets.assetLoader"
require "world_utils.world"
require "world_utils.scene"
local Slab = require "libraries.Slab"
local debugWorldDraw = require "libraries.debugWorldDraw"
local Bullet1 = require "magic.bullet1"
local UIHandler = require "ui.uiHandler"
local Spell = require "magic.spell"
local new_frame = false

function love.load(args)
    -- local font = love.graphics.newFont("assets/RamadhanMubarok-Regular.otf")
    -- love.graphics.setFont(font)
    game_state = MENU_STATE
    Slab.Initialize(args)
    initVars()
    registerAll()

    spellTest = Spell:new(Bullet1, 10)

    fpsTimer = love.timer.getTime()

    uihandler = UIHandler:new()
end

function love.update(dt)
    Slab.Update(dt)
    uihandler:update()

    if game_state == IN_WORLD_STATE then
        if not paused then
            player:updateAnimation()

            -- Update physics
            manageHitbox()
            p_world:update(dt)
            
            -- Movement update
            if player_control then
                player:update(dt)
            end

            map.enemies:update(dt)
            spells:update(dt)
            
            -- Setting the camera to the player position
            local x,y = player.body:getWorldCenter()
            game_cam:lookAt(x, y)
            
            -- Animation update
            if (player.anim.actor:GetTransformer():GetPower("player") > 0) then
                local vars = player.anim.actor:GetTransformer():GetVariables("player")
                vars.time = vars.time + dt;
            end
            player.anim.actor:Update(dt);
        end
    else
        new_frame = false
    end
    
    
    if DEBUG then
        -- Print the update fps to the console every second
        if love.timer.getTime() - fpsTimer > 1 then
            fpsTimer = love.timer.getTime()
            print("FPS: " .. love.timer.getFPS())
            print("body count: " .. p_world:getBodyCount())
        end
    end
end

function love.draw()
    if game_state == MENU_STATE then

    elseif game_state == IN_WORLD_STATE then
        -- Drawing everything in regard to the camera
        game_cam:attach()
            -- Map draws entities aswell
            map:draw() 
            spells:draw()
            
            -- if new_frame then
                player.anim.actor:Draw()
            -- end
            if not new_frame then
                new_frame = true
            end
            if DEBUG then
                -- player:debugDraw()
                local mx, my  = MAP_X * TILE_SIZE * TILES_PER_METER, MAP_Y * TILE_SIZE * TILES_PER_METER
                debugWorldDraw(p_world, -mx / 2, -my / 2, mx, my)
            end
        game_cam:detach()
        
        tooltipDraw()
        
        if DEBUG then
            debugPrint()
        end
    end
    Slab.Draw()
end

function love.keypressed(key)
    if key == EXIT_KEY then
        love.event.quit()
    end

    -- IN_WORLD State handling
    if game_state == IN_WORLD_STATE then
        -- Check pausing first
        if key == PAUSE_KEY then 
            paused = not paused
            player_control = not paused
        elseif not paused then
            -- Save and load keys
            if key == SAVE_KEY then
                saveScene("world")
            elseif key == LOAD_KEY then
                loadScene("world")
            -- Shoot key
            elseif key == SHOOT_KEY then
                spellTest:shoot(player)
            elseif key == INTERACT_KEY then
                player:interact()
            elseif key == "y" then
                player.stats.swiftness = player.stats.swiftness - 10
            elseif key == "u" then
                player.stats.swiftness = player.stats.swiftness + 10
            else
                uihandler:checkKeyIngame(key)
            end
        end
    end
end
