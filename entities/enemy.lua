require "components.hpBar"

function Enemy(x, y)
    -- Enemy Attributes
    local enemy = {}
    enemy.radius = 50
    enemy.body = love.physics.newBody(p_world, x, y, "dynamic")
    enemy.shape = love.physics.newCircleShape(enemy.radius)
    enemy.fixture = love.physics.newFixture(enemy.body, enemy.shape, 1)
    enemy.name = "enemy"
    enemy.hpBar = HPBar(50, 50, 0)

    -- Enemy Init
    enemy.body:setGravityScale(0)
    enemy.body:setSleepingAllowed(false)
    
    -- Enemy Functions
    function enemy.draw()
        local x, y = enemy.body:getWorldCenter()
        love.graphics.circle("fill",x, y,enemy.radius)
    end
    
    function enemy.move(x, y)
        enemy.body:setLinearVelocity(x, y)
    end    

    function enemy.prepSave()
        -- Prep the x and y values for saving(easier than trying to save the box and whatever user data)
        enemy.x, enemy.y = enemy.body:getWorldCenter()
    end

    function enemy.load(enemyTable)
        -- Loads the enemy from a loaded table
        enemy.hpBar = enemyTable.hpBar
        enemy.radius = enemyTable.radius
        enemy.shape:setRadius(enemy.radius)
        enemy.fixture:destroy()
        enemy.fixture = love.physics.newFixture(enemy.body, enemy.shape, 1)
        
    end
    
    function enemy.wakeUp()
        if enemy.body:isAwake() == false then
            enemy.body:wakeUp()
        end
    end

    return enemy
end


