local Items = require "items.items"
local Inventories = require "items.inventories"

-- Items lying in the world: they pop out of broken blocks, fall and rest on the ground,
-- fly to the player when it comes near and go into its inventory on touch
-- Drops near each other merge, old ones disappear, far from the player they freeze like enemies
local Drops = {}

function Drops:new()
    local drops = {}
    setmetatable(drops, self)
    self.__index = self

    drops.list = {}
    drops.queue = {}        -- Drops waiting to be made, bodies cant be made inside physics callbacks(a spell breaking a block)
    drops.pickups = {}      -- Recent pickups shown over the player, {item, count, time}
    drops.mergeTimer = 0
    return drops
end


function Drops:spawn(name, count, x, y, popped, pickupDelay, data)
    -- Queues a drop at love x, y, popped ones jump out a little(from a broken block)
    -- pickupDelay is how long before it flies to the player(thrown items wait longer so they dont come right back)
    -- data is the stack data of items that have it(a thrown wand keeps its parts)
    if ITEM_REGISTRY[name] == nil or count <= 0 then
        return
    end
    table.insert(self.queue, {item = name, count = count, x = x, y = y, popped = popped ~= false, pickupDelay = pickupDelay, data = data})
end


function Drops:make(entry)
    local drop = {item = entry.item, count = entry.count, data = entry.data, age = 0, magnet = false, pickupDelay = entry.pickupDelay or ITEM_PICKUP_DELAY}
    local r = ITEM_DROP_SIZE / 2
    drop.body = love.physics.newBody(p_world, entry.x, entry.y, "dynamic")
    drop.body:setFixedRotation(true)
    drop.body:setLinearDamping(ITEM_DROP_DAMPING)
    drop.fixture = love.physics.newFixture(drop.body, love.physics.newCircleShape(r), 1)
    drop.fixture:setCategory(ITEM_CATEGORY)
    -- Only blocks stop it, it passes through the player, enemies, spells and other drops
    drop.fixture:setMask(PLAYER_CATEGORY, ENEMY_CATEGORY, SPELLS_CATEGORY, ITEM_CATEGORY)
    drop.fixture:setFriction(0.9)
    drop.fixture:setRestitution(0.15)
    if entry.popped then
        drop.body:setLinearVelocity((love.math.random() - 0.5) * ITEM_POP_SPEED, -ITEM_POP_SPEED)
    end
    table.insert(self.list, drop)
end


function Drops:remove(i)
    local drop = self.list[i]
    if not drop.body:isDestroyed() then
        drop.body:destroy()
    end
    table.remove(self.list, i)
end


function Drops:collect(drop)
    -- Puts what fits into the inventory, returns true when all of it went in
    local left = Inventories.addStack(player.inventory, drop)
    local taken = drop.count - left
    if taken > 0 then
        -- Pickups of the same item close together show as one line
        local last = self.pickups[#self.pickups]
        if last ~= nil and last.item == drop.item and not drop.data and last.time < ITEM_PICKUP_SHOW_TIME * 0.5 then
            last.count = last.count + taken
            last.time = 0
        else
            table.insert(self.pickups, {item = drop.item, name = Items.stackName(drop), count = taken, time = 0})
        end
    end
    drop.count = left
    return left == 0
end


function Drops:merge()
    -- Drops of the same item resting close together become one
    for i = #self.list, 1, -1 do
        local a = self.list[i]
        for j = i - 1, 1, -1 do
            local b = self.list[j]
            if not a.magnet and not b.magnet and a.item == b.item and not a.data and not b.data and b.count + a.count <= Items.maxStack(a.item) then
                local ax, ay = a.body:getPosition()
                local bx, by = b.body:getPosition()
                if distance(ax, ay, bx, by) <= ITEM_MERGE_DISTANCE then
                    b.count = b.count + a.count
                    b.age = math.min(a.age, b.age)
                    self:remove(i)
                    break
                end
            end
        end
    end
end


function Drops:update(dt)
    for i, entry in ipairs(self.queue) do
        self:make(entry)
    end
    self.queue = {}

    local px, py = player.body:getWorldCenter()
    for i = #self.list, 1, -1 do
        local drop = self.list[i]
        drop.age = drop.age + dt
        local x, y = drop.body:getPosition()
        -- Far from the player blocks have no hitboxes, so the drop waits frozen
        local mx, my = loveToMap(math.floor(x / TILE_SIZE) * TILE_SIZE, math.floor(y / TILE_SIZE) * TILE_SIZE)
        local active = map:inHitboxWindow(mx, my)
        if drop.body:isActive() ~= active then
            drop.body:setActive(active)
        end

        local d = distance(x, y, px, py)
        if drop.age >= ITEM_LIFETIME then
            self:remove(i)
        elseif d <= ITEM_PICKUP_DISTANCE and drop.age >= drop.pickupDelay and self:collect(drop) then
            self:remove(i)
        elseif active and d <= ITEM_MAGNET_DISTANCE and drop.age >= drop.pickupDelay and Inventories.canAdd(player.inventory, drop.item) then
            -- Flies to the player through blocks
            if not drop.magnet then
                drop.magnet = true
                drop.fixture:setSensor(true)
                drop.body:setGravityScale(0)
            end
            drop.body:setLinearVelocity((px - x) / d * ITEM_MAGNET_SPEED, (py - y) / d * ITEM_MAGNET_SPEED)
        elseif drop.magnet then
            -- Out of reach again(or the inventory filled up), it falls where it is
            drop.magnet = false
            drop.fixture:setSensor(false)
            drop.body:setGravityScale(1)
        end
    end

    self.mergeTimer = self.mergeTimer + dt
    if self.mergeTimer >= ITEM_MERGE_INTERVAL then
        self.mergeTimer = 0
        self:merge()
    end

    for i = #self.pickups, 1, -1 do
        local pickup = self.pickups[i]
        pickup.time = pickup.time + dt
        if pickup.time >= ITEM_PICKUP_SHOW_TIME then
            table.remove(self.pickups, i)
        end
    end
end


function Drops:draw()
    -- World space: each drop is its item icon bobbing a little, then the pickup lines over the player
    local size = ITEM_DROP_SIZE
    for i, drop in ipairs(self.list) do
        local x, y = drop.body:getPosition()
        local bob = drop.magnet and 0 or math.sin(drop.age * 3) * 1.5
        love.graphics.setColor(1, 1, 1, 1)
        Items.drawIcon(drop.item, math.floor(x - size / 2), math.floor(y - size / 2 + bob), size, drop)
        if drop.count > 1 then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(drop.count, math.floor(x + size / 2 - 2), math.floor(y - 2), 0, 0.5, 0.5)
        end
    end

    local px, py = player.body:getWorldCenter()
    for i, pickup in ipairs(self.pickups) do
        local rise = pickup.time * 12 + (#self.pickups - i) * 12
        local alpha = 1 - pickup.time / ITEM_PICKUP_SHOW_TIME
        local text = "+" .. pickup.count .. " " .. (pickup.name or Items.displayName(pickup.item))
        local font = love.graphics.getFont()
        love.graphics.setColor(0, 0, 0, alpha * 0.7)
        love.graphics.print(text, math.floor(px - font:getWidth(text) / 2) + 1, math.floor(py - PLAYER_HEIGHT - rise) + 1)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(text, math.floor(px - font:getWidth(text) / 2), math.floor(py - PLAYER_HEIGHT - rise))
    end
    love.graphics.setColor(1, 1, 1, 1)
end


function Drops:toData()
    local list = {}
    for i, drop in ipairs(self.list) do
        local x, y = drop.body:getPosition()
        table.insert(list, {item = drop.item, count = drop.count, data = drop.data, x = x, y = y})
    end
    for i, entry in ipairs(self.queue) do
        table.insert(list, {item = entry.item, count = entry.count, data = entry.data, x = entry.x, y = entry.y})
    end
    return list
end


function Drops:loadData(list)
    -- Saved drops come back lying where they were
    for i, data in ipairs(type(list) == "table" and list or {}) do
        if type(data.item) == "string" and type(data.count) == "number" and type(data.x) == "number" and type(data.y) == "number" then
            self:spawn(data.item, math.floor(data.count), data.x, data.y, false, nil, type(data.data) == "table" and data.data or nil)
        end
    end
end


function Drops:clear()
    for i = #self.list, 1, -1 do
        self:remove(i)
    end
    self.queue = {}
end

return Drops
