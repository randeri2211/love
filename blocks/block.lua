require "components.hpBar"

function Block(x, y, width, height)
    -- Block Variables
    local block = {}
    block.width = width
    block.height = height
    block.body = love.physics.newBody(p_world, x, y, "static")
    block.shape = love.physics.newRectangleShape(block.width / 2, block.height / 2, block.width, block.height)
    block.fixture = love.physics.newFixture(block.body, block.shape, 1)
    block.body:setGravityScale(0)
    block.type = "Block"
    block.hpBar = HPBar(1, 1, 0)




    -- Block Functions
    function block.draw()
        local x, y = block.body:getWorldCenter()
        love.graphics.rectangle("fill",x, y, block.width, block.height)
    end

    function block.damage(dmg)
        block.hpBar.currentHP = block.hpBar.currentHP - dmg
        if block.hpBar.currentHP <= 0 then
            block = block.destroy()
        end
        return block
    end

    function block.destroy()
        block = nil
        return block
    end

    function block.prepSave()
        block.x, block.y = block.body:getWorldCenter()
    end

    function block.load(blockTable)
        block.hpBar = blockTable.hpBar
    end
    return block
end

