require "system_utils"

require "entities.player"
require "constants"
require "keys"
require "world.world"
require "world.scene"
require "entities.enemy"
require "entities.enemy1"
require "blocks.block"
require "animations.animations"


function love.load()
    initVars()
    -- TODO: replace tempMap with a world generation sometime
    tempMap()

    -- saveScene()
    -- loadScene()
    fpsTimer = love.timer.getTime()
    debug = true
end

function love.update(dt)
    if game_state == IN_WORLD then
        if not paused then
            player:updateAnimation()

            -- Update physics
            manageHitbox()
            map:update()
            p_world:update(dt)
            
            -- Movement update
            if player_control then
                player:update()
            end
            
            -- Setting the camera to the player position
            local x,y = player.body:getWorldCenter()
            game_cam:lookAt(x, y)
            
            -- Animation update
            if (player.anim.actor:GetTransformer():GetPower("player") > 0) then
                local vars = player.anim.actor:GetTransformer():GetVariables("player")
                vars.time = vars.time + dt;
            end
            player.anim.actor:Update(dt);
        else

        end
    end
    
    
    if debug then
        -- Print the update fps to the console every second
        if love.timer.getTime() - fpsTimer > 1 then
            fpsTimer = love.timer.getTime()
            print("FPS: " .. love.timer.getFPS())
            print("body count: " .. p_world:getBodyCount())
        end
    end
end

function love.draw()
    if debug then
        debugPrint()
    end

    -- Drawing everything in regard to the camera
    game_cam:attach()
        -- Map draws entities aswell
        map:draw() 
        player.anim.actor:Draw()
    game_cam:detach()
end

function love.keypressed(key)
    if key == EXIT then
        love.event.quit()
    end

    -- IN_WORLD State handling
    if game_state == IN_WORLD then
        -- Check pausing first
        if key == PAUSE then 
            paused = not paused
            player_control = not paused
        elseif not paused then
            -- Save and load keys
            elseif key == SAVE_KEY then
                saveScene()
            elseif key == LOAD_KEY then
                loadScene()
        end
    end
end
