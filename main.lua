require "system_utils"

require "entities.player"
require "constants"
require "world.world"
require "world.scene"
require "entities.enemy"
require "entities.enemy1"
require "blocks.block"
require "animations"


function love.load()
    initVars()
    tempMap()

    -- saveScene()
    -- loadScene()
    t = love.timer.getTime()
    animate()
end

function love.update(dt)
    -- updateAnimation()
    -- Update physics
    p_world:update(dt)
    
    -- Movement update
    -- moveEnemies(0, 0)
    player:move(dt)
    groundRay()
    -- Setting the camera to the player position
    local x,y = player.body:getWorldCenter()
    game_cam:lookAt(x, y)
    map:update()
    manageHitbox()

    if (myActor:GetTransformer():GetPower("player") > 0) then
		local vars = myActor:GetTransformer():GetVariables("player");
        print(vars)
		vars.time = vars.time + dt;
	end
	myActor:Update(dt);

    if love.timer.getTime() - t > 1 then
        t = love.timer.getTime()
        print(love.timer.getFPS())
    end
end

function love.draw()
    -- Drawing everything in regard to the camera
    debugPrint()

    game_cam:attach()
        map:draw() 
        player:draw()
    game_cam:detach()
    myActor:Draw();
end

function love.keypressed(key, isRepeat)
	if (key == 'z') then
		myActor:GetTransformer():SetPower("player", 1);
	end
end


