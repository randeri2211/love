require "system_utils"

require "entities.player"
require "constants"
require "world.world"
require "world.scene"
require "entities.enemy"
require "entities.enemy1"
require "blocks.block"
require "animations.animations"


function love.load()
    initVars()
    tempMap()

    saveScene()
    -- loadScene()
    fpsTimer = love.timer.getTime()
    debug = true
end

function love.update(dt)
    -- Update physics
    manageHitbox()
    -- map:update()
    p_world:update(dt)
    
    -- Movement update
    player:move()
    groundRay()
    -- Setting the camera to the player position
    local x,y = player.body:getWorldCenter()
    game_cam:lookAt(x, y)
    
    -- Animation update
    if (player.anim.actor:GetTransformer():GetPower("player") > 0) then
		local vars = player.anim.actor:GetTransformer():GetVariables("player")
		vars.time = vars.time + dt;
	end
	player.anim.actor:Update(dt);
    
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
    -- Drawing everything in regard to the camera
    if debug then
        debugPrint()
    end

    game_cam:attach()
        map:draw() 
        player.anim.actor:Draw()
    game_cam:detach()
end


