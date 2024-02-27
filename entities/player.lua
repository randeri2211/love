require "constants"
require "world.world"
require "components.hpBar"
require "components.manaBar"

function Player(x, y)
    -- Player Attributes
    local player = {}
    player.body = love.physics.newBody(p_world, x, y,"dynamic")
    player.shape = love.physics.newCircleShape(50)
    player.fixture = love.physics.newFixture(player.body, player.shape, 1)

    player.speed = 4 * TILE_SIZE
    player.hpBar = HPBar(100, 100, 1)
    player.manaBar = ManaBar(100, 100, 10)


    -- Player Init
    player.body:setGravityScale(1)
    player.body:setSleepingAllowed(false)
    player.body:setLinearDamping(LINEAR_DAMPING)


    -- Player Functions
    function player.movement(dt)
        -- Increase linear velocity according to speed(does'nt depend on time since its using world)
        local x,y = player.body:getLinearVelocity()
        if love.keyboard.isDown("d") then
            player.body:setLinearVelocity(player.speed, y)
        end
        local x,y = player.body:getLinearVelocity()
        if love.keyboard.isDown("a") then
            player.body:setLinearVelocity(-player.speed, y)
        end
        local x,y = player.body:getLinearVelocity()
        if love.keyboard.isDown("w") then
            player.body:setLinearVelocity(x, - player.speed)
        end
        local x,y = player.body:getLinearVelocity()
        if love.keyboard.isDown("s") then
            player.body:setLinearVelocity(x, player.speed)
        end
        
    end
    
    function player.draw()
        -- Get the world center to base all player drawing on
        local x, y = player.body:getWorldCenter()

        love.graphics.circle("fill", x, y, 50)
    end
    
    
    function player.prepSave()
        -- Prep the x and y values for saving(easier than trying to save the box and whatever user data)
        player.x, player.y = player.body:getWorldCenter()
    end
    
    
    function player.load(playerTable)
        -- Gets a table with all the values from the recursiveLoad and sets the player with them
        player.body:setPosition(playerTable.x, playerTable.y)
        player.speed = playerTable.speed
    end

    return player
end


