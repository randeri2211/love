require "system_utils"

require "entities.player"
require "constants"
require "keys"
require "world.world"
require "world.scene"
require "animations.animations"
require "registry"

require "magic.bullet1"

function love.load()
    initVars()
    registerAll()
    -- TODO: replace tempMap with a world generation sometime
    tempMap()

    spellTest = Spell:new(Bullet1, 10)

    fpsTimer = love.timer.getTime()
end

function love.update(dt)
    if game_state == IN_WORLD then
        if not paused then
            player:updateAnimation()

            -- Update physics
            manageHitbox()
            p_world:update(dt)
            
            -- Movement update
            if player_control then
                player:update(dt)
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
        spells:draw()
        player.anim.actor:Draw()
        -- player:debugDraw()
    game_cam:detach()
    tooltipDraw()
end

function love.keypressed(key)
    if key == EXIT then
        love.event.quit()
    end

    -- IN_WORLD State handling
    if game_state == IN_WORLD then
        -- Check pausing first
        if key == PAUSE then 
            d = not paused
            player_control = not paused
        elseif not paused then
            -- Save and load keys
            if key == SAVE_KEY then
                saveScene()
            elseif key == LOAD_KEY then
                loadScene()
            elseif key == "b" then
                spellTest:shoot(player)
            end
        end
    end
end
