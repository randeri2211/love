require "constants"
require "world.world"
require "components.hpBar"
require "components.manaBar"

function Player(x, y)
    -- Player Attributes
    local player = {}
    player.radius = PLAYER_WIDTH / 2
    player.body = love.physics.newBody(p_world, x - TILE_SIZE, y, "dynamic")
    player.shapes = {}
    player.grounded = false
    player.jumping = false
    player.shapes[1] = love.physics.newRectangleShape(PLAYER_WIDTH, PLAYER_HEIGHT - PLAYER_WIDTH)
    player.shapes[2] = love.physics.newCircleShape(0, -(PLAYER_HEIGHT - PLAYER_WIDTH) / 2, player.radius)
    player.shapes[3] = love.physics.newCircleShape(0, (PLAYER_HEIGHT - PLAYER_WIDTH) / 2, player.radius)


    player.fixtures = {}
    player.fixtures[1] = love.physics.newFixture(player.body, player.shapes[1], 1)
    player.fixtures[1]:setCategory(2)
    player.fixtures[2] = love.physics.newFixture(player.body, player.shapes[2], 1)
    player.fixtures[2]:setCategory(2)
    player.fixtures[3] = love.physics.newFixture(player.body, player.shapes[3], 1)
    player.fixtures[3]:setCategory(2)
    player.fixture_check = {}
    player.fixture_check[player.fixtures[1]] = true
    player.fixture_check[player.fixtures[2]] = true
    player.fixture_check[player.fixtures[3]] = true


    player.jumpHeight = 4 * TILE_SIZE
    player.speed = 4 * TILE_SIZE
    player.hpBar = HPBar(100, 100, 1)
    player.manaBar = ManaBar(100, 100, 10)

    -- Player Init
    player.body:setGravityScale(1)
    player.body:setSleepingAllowed(false)
    player.body:setFixedRotation(true)
    player.body:setLinearDamping(LINEAR_DAMPING)


    player.up = true

    -- Player Functions
    function player.movement(dt)
        -- Increase linear velocity according to speed(does'nt depend on time since its using world)
        local moved = false
        local x,y = player.body:getLinearVelocity()
        if love.keyboard.isDown("d") then
            player.body:setLinearVelocity(player.speed, y)
            moved = true
        end
        local x,y = player.body:getLinearVelocity()
        if love.keyboard.isDown("a") then
            player.body:setLinearVelocity(-player.speed, y)
            moved = true
        end


        local x,y = player.body:getLinearVelocity()
        if love.keyboard.isDown("space") then
            if player.grounded then
                player.jumping = true
                player.body:setLinearVelocity(x, - player.jumpHeight)
                moved = true
            elseif player.jumping and player.up then
                player.body:setGravityScale(JUMP_GRAVITY_SCALE)
            else
                player.body:setGravityScale(1)
            end
        else
            player.jumping = false
            player.body:setGravityScale(1)
        end
        

        -- Figuring up direction
        local x,y_after = loveToWorld(player.body:getLinearVelocity())
        if y_after < 0.1 then
            if player.up == true then
                player.up = false
                local x, y = loveToWorld(player.body:getWorldCenter())
                print("y:"..y)
            end
        elseif y_after > 0.1 then
            if player.up == false then
                player.up = true
            end            
        end
        -- print("up:"..tostring(player.up))

        -- player.linearDamping(moved)
        player.resetSmallVel()
    end



    function player.linearDamping(moved)
        if moved == false and player.grounded == true then
            player.body:setLinearDamping(2)
        else
            player.body:setLinearDamping(LINEAR_DAMPING)
        end
    end


    function player.resetSmallVel()
        -- Resets small velocity values to stop flickering at low speeds
        local x,y = player.body:getLinearVelocity()
        if math.abs(x) < 0.001 then
            x = 0
        end
        if math.abs(y) < 0.001 then
            y = 0
        end
        player.body:setLinearVelocity(x, y)
    end
    

    function player.draw()
        -- Get the world center to base all player drawing on
        for i = 1, #player.shapes do
            -- print(tostring(player.shapes[i]))
            if i == 1 then
                love.graphics.polygon("line", player.body:getWorldPoints(player.shapes[i]:getPoints()))
            else
                local x, y = player.shapes[i]:getPoint()
                local b_x, b_y = player.body:getWorldCenter()
                love.graphics.circle("line", x + b_x, y + b_y, player.radius)
            end
        end
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


