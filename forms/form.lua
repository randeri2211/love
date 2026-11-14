local Elements = require "magic.elements"
local Crit = require "magic.crit"
local Statuses = require "magic.statuses"

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

function Form:light(add)
    -- Light it gives off(see world_utils/lighting): add(x, y, color, strength), a faint glow in its color by default
    local x, y = self:getPosition()
    if x ~= nil then
        add(x, y, self.color or {1, 1, 1}, self:lightStrength(SPELL_LIGHT))
    end
end

function Form:lightStrength(base)
    -- How bright its light is: the faint glow of its form, and more for every Light rune on it
    return base + (self.glow or 0) * LIGHT_RUNE_GLOW
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


function Form.sourceBlock(params)
    -- The mana block a cast was sent off by(its onHit or onExpire make it their target), nil for any other cast
    local target = params.target
    if target ~= nil and target.name == "ManaBlock" then
        return target
    end
    return nil
end

function Form:isCaster(entity)
    -- A spell never hits the one who cast it, everything else(the player, every enemy) it can
    -- A spell a mana block sent off passes through that block too, or it would set the block off again and again
    -- A caster allied with the player(a Spell Turret) doesnt hit the player either, nor the turret block it casts from
    local caster = self.player
    return entity ~= nil and (entity == caster or entity == self.fromBlock
        or (caster ~= nil and caster.alliedWithPlayer == true and (entity == player or entity == caster.turret)))
end


-- Helpers for forms

function Form:damageFor(entity)
    -- Terrain only takes part of the damage(terrainDamage), enemies take all of it
    if entity.type == "Block" then
        return self.damage * self.terrainDamage
    end
    return self.damage
end

function Form:digReach()
    -- The hardest block it can damage: the dig cap of the wand or staff it was cast with(see items/tools)
    -- Only the tool decides what can be mined, the spell damage and Dig runes decide how fast(the HP a hit takes)
    return self.digCap or math.huge
end

function Form:hit(entity, x, y, dirX, dirY, pushX, pushY)
    -- Damages what was hit and casts the onHit child spells from there(dirX, dirY is the way they go)
    -- Blocks check their hardness against the dig cap of the caster tool, the hit only sets how much they lose
    -- pushX, pushY is the way the hit shoves, the way the spell was going(defaults to dirX, dirY)
    if entity ~= nil then
        -- Creatures can take a critical hit, blocks only check the dig cap
        local amount = self:damageFor(entity)
        if entity.type ~= "Block" then
            -- Frost on it shatters, then the hit can crit
            amount = Crit.roll(self, amount * Statuses.shatterFactor(entity), x, y)
        end
        if entity.type == "Block" then
            entity:damage(amount, self:digReach(), self)    -- Blocks learn what hit them(a mana block fires back, see ManaBlock)
        else
            entity:damage(amount, self:digReach())
        end
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
