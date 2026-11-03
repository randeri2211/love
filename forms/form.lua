local Elements = require "magic.elements"
local Crit = require "magic.crit"

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


function Form:preSolve(fixture, contact)
    -- Called every physics step while touching a fixture, before the contact is solved(can turn it off)
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
    -- A plain spell digs with its full damage, every Dig rune doubles it, the caster wand or staff caps it(digCap)
    local strength = self.damage * self.terrainDamage / BASE_SPELL_PARAMS.terrainDamage
    return math.min(strength, self.digCap or math.huge)
end

function Form:hit(entity, x, y, dirX, dirY, pushX, pushY)
    -- Damages what was hit and casts the onHit child spells from there(dirX, dirY is the way they go)
    -- Blocks check hardness against the dig strength, so weak fast hits still dig slowly
    -- pushX, pushY is the way the hit shoves, the way the spell was going(defaults to dirX, dirY)
    if entity ~= nil then
        -- Creatures can take a critical hit, blocks only check the dig strength
        local amount = self:damageFor(entity)
        if entity.type ~= "Block" then
            amount = Crit.roll(self, amount, x, y)
        end
        entity:damage(amount, self:digStrength())
        -- Elements burn, freeze and poison what was hit, Lightning jumps on from it
        if self.elementParams ~= nil then
            local hx, hy = x, y
            if hx == nil and entity.body ~= nil and not entity.body:isDestroyed() then
                hx, hy = entity.body:getWorldCenter()
            end
            if hx ~= nil then
                Elements.onHit(self, entity, hx, hy)
            end
        end
        -- Knockback from the spell, only things that can be pushed(enemies, not blocks), with a little hop
        if entity.push ~= nil and (self.knockback or 0) > 0 then
            pushX, pushY = pushX or dirX, pushY or dirY
            local speed = self.knockback * KNOCKBACK_SPEED
            entity:push(pushX * speed, (pushY * KNOCKBACK_VERTICAL - KNOCKBACK_LIFT) * speed)
        end
    end
    spells:trigger(self, "onHit", dirX, dirY, x, y, entity)
end

function Form:expire()
    -- Casts the onExpire child spells and removes the spell
    spells:trigger(self, "onExpire")
    spells:destroy(self)
end

return Form
