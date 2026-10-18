
local Form = {}

function Form:new(player)
    local form = {}
    setmetatable(form,self)
    self.__index = self

    form.type = "Form"
    form.form = nil
    if player == nil then
        return form
    end
    form.player = player
    form.terrainDamage = BASE_SPELL_PARAMS.terrainDamage   -- Forms set it from their params

    return form
end

-- Every form can override these, the defaults fit a form without a physics body

function Form:update(dt)
end

function Form:draw()
end

function Form:destroy()
end

function Form:isFixture(fixture)
    return false
end

function Form:getPosition()
    -- Where triggered child spells start from
    if self.body ~= nil then
        return self.body:getWorldCenter()
    end
    return self.x, self.y
end

function Form:getDirection()
    -- Direction triggered child spells fly in when the event doesnt give one
    return self.direction[1], self.direction[2]
end

function Form:onContact(fixture, entity, contact)
    -- Physics contact with a fixture(entity is the block or enemy it belongs to, or nil)
    -- Forms decide what a contact means, by default nothing happens
end


-- Helpers for forms

function Form:damageFor(entity)
    -- Terrain only takes part of the damage(terrainDamage), enemies take all of it
    if entity.type == "Block" then
        return self.damage * self.terrainDamage
    end
    return self.damage
end

function Form:digStrength()
    -- Strength checked against block hardness: terrain damage compared to a normal spell
    -- A plain spell digs with its full damage, every Dig rune doubles it
    return self.damage * self.terrainDamage / BASE_SPELL_PARAMS.terrainDamage
end

function Form:hit(entity, x, y, dirX, dirY)
    -- Damages what was hit and casts the onHit child spells from there
    -- Blocks check hardness against the dig strength, so weak fast hits still dig slowly
    if entity ~= nil then
        entity:damage(self:damageFor(entity), self:digStrength())
    end
    spells:trigger(self, "onHit", dirX, dirY, x, y)
end

function Form:expire()
    -- Casts the onExpire child spells and removes the spell
    spells:trigger(self, "onExpire")
    spells:destroy(self)
end

return Form
