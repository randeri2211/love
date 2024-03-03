require "system_utils"

require "entities.player"
require "constants"
require "world.world"
require "world.scene"
require "entities.enemy"
require "entities.enemy1"
require "blocks.block"

function love.load()
    initVars()
    tempMap()
    initScreen()

    saveScene()
    loadScene()
end

function love.update(dt)
    -- Update physics
    p_world:update(dt)
    
    -- Movement update
    -- moveEnemies(0, 0)
    player.movement(dt)
    groundRay()
    -- Setting the camera to the player position
    local x,y = player.body:getWorldCenter()
    game_cam:lookAt(x, y)
    map.update()
end

function love.draw()
    -- Drawing everything in regard to the camera
    debugPrint()

    game_cam:attach()
        map.draw() 
        drawEnemies()
        player.draw()

    game_cam:detach()

end


