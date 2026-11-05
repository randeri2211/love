-- Projectiles that arent spells: a skeleton's arrows(see entities/skeletonArcher)
-- They are moved by hand instead of by physics: every frame an arrow falls a little and checks the path it covered
-- for a solid block(it sticks in it for a while, a mana block takes the hit and fires back) or the player(plain damage)
local Projectiles = {}


function Projectiles:new()
    local projectiles = {}
    setmetatable(projectiles, self)
    self.__index = self
    projectiles.list = {}
    return projectiles
end


function Projectiles:shoot(owner, x, y, vx, vy, damage)
    -- An arrow from owner(who it doesnt hit), flying at vx, vy
    table.insert(self.list, {owner = owner, x = x, y = y, vx = vx, vy = vy, damage = damage, life = 6})
end


local function hitsPlayer(x, y)
    -- True when a point is inside the player body
    if player == nil or player:isDead() then
        return false
    end
    local px, py = player.body:getWorldCenter()
    return math.abs(x - px) <= player.width / 2 and math.abs(y - py) <= player.height / 2
end


function Projectiles:update(dt)
    for i = #self.list, 1, -1 do
        local arrow = self.list[i]
        if arrow.stuck ~= nil then
            arrow.stuck = arrow.stuck - dt
            if arrow.stuck <= 0 then
                table.remove(self.list, i)
            end
        else
            arrow.vy = arrow.vy + GRAVITY * ARROW_GRAVITY * dt
            local nx, ny = arrow.x + arrow.vx * dt, arrow.y + arrow.vy * dt
            -- The path in small steps, so a fast arrow never skips a tile or the player
            local steps = math.max(1, math.ceil(distance(arrow.x, arrow.y, nx, ny) / (TILE_SIZE / 4)))
            local done = false
            for s = 1, steps do
                local px, py = arrow.x + (nx - arrow.x) * s / steps, arrow.y + (ny - arrow.y) * s / steps
                if hitsPlayer(px, py) then
                    player:damage(arrow.damage)
                    player:push(arrow.vx * 0.3, -TILE_SIZE * 2)
                    table.remove(self.list, i)
                    done = true
                    break
                end
                local block = map:solidAt(px, py)
                if block ~= nil then
                    -- A mana block takes a hit like from a touch and fires back at the archer(see ManaBlock:damage)
                    if block.name == "ManaBlock" then
                        block:damage(arrow.damage * MANA_BLOCK_CONTACT_SCALE, arrow.damage, arrow.owner)
                    end
                    arrow.x, arrow.y = px, py
                    arrow.stuck = ARROW_STUCK_TIME
                    done = true
                    break
                end
            end
            if not done then
                arrow.x, arrow.y = nx, ny
                arrow.life = arrow.life - dt
                if arrow.life <= 0 then
                    table.remove(self.list, i)
                end
            end
        end
    end
end


function Projectiles:draw()
    -- An arrow along the way it flies: the shaft, a head and the fletching
    love.graphics.push("all")
    for i, arrow in ipairs(self.list) do
        local angle = math.atan2(arrow.vy, arrow.vx)
        local alpha = arrow.stuck ~= nil and math.min(1, arrow.stuck / 0.5) or 1
        love.graphics.push()
        love.graphics.translate(arrow.x, arrow.y)
        love.graphics.rotate(angle)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.55, 0.42, 0.28, alpha)
        love.graphics.line(-TILE_SIZE * 0.7, 0, 0, 0)
        love.graphics.setColor(0.75, 0.76, 0.8, alpha)
        love.graphics.polygon("fill", 0, -3, 6, 0, 0, 3)
        love.graphics.setColor(0.9, 0.9, 0.85, alpha)
        love.graphics.line(-TILE_SIZE * 0.7, -3, -TILE_SIZE * 0.55, 0, -TILE_SIZE * 0.7, 3)
        love.graphics.pop()
    end
    love.graphics.pop()
end


function Projectiles:clear()
    self.list = {}
end

return Projectiles
