require "entities.enemy"

function Enemy1(x, y)
    local enemy1 = Enemy(x, y)
    enemy1.name = "enemy1"


    function enemy1.draw()
        love.graphics.setColor(0, 1, 0, 1)
        local x, y = enemy1.body:getWorldCenter()
        love.graphics.circle("fill",x, y,enemy1.radius)
        love.graphics.setColor(1, 1, 1, 1)
    end

    return enemy1
end