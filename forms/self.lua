local Form = require "forms.form"
local Spell = require "magic.spell"

-- A spell on a creature instead of a projectile: it carries buffs for its lifetime
-- It goes on whoever the spell is about: the caster when cast directly, the hit enemy when an onHit triggered it
-- Heal, haste, lightness and a dash come from the modifiers(see the Self entries in the rune effects)
-- onHit fires when the target is hurt while it lasts, onExpire when it ends, both from where the target is
local Self = Form:new()

function Self:new(caster, params, x, y, dirX, dirY)
    local effect = Form:new(caster)
    setmetatable(effect, self)
    self.__index = self

    effect.form = "self"
    if caster == nil then
        return effect
    end

    effect.direction = {dirX, dirY}
    -- A trigger can put it on what was hit, only creatures can carry it(a hit block puts it on the caster)
    local target = params.target
    if target == nil or target.type == "Block" or target.hpBar == nil or target.body == nil then
        target = caster
    end
    effect.target = target
    effect.lastX, effect.lastY = target.body:getWorldCenter()
    effect.lifetime = params.lifetime
    effect.duration = params.lifetime
    effect.heal = params.heal           -- HP given over the whole lifetime
    effect.haste = params.haste         -- Walking speed multiplier
    effect.lightness = params.lightness -- Gravity multiplier, below 1 jumps higher and falls slower
    effect.color = params.color
    effect.time = 0

    -- The target keeps its active effects so buffs from several casts stack(see Entity:selfBuff)
    target.selfEffects = target.selfEffects or {}
    target.selfEffects[effect] = true
    target.statsDirty = true    -- Its haste and lightness go into its stats(see CombatStats)

    -- Dash toward the aim, or the way an arrow on Recoil points(forward is away from the caster when it is on someone else)
    -- Sideways shoves fade fast so they get the full speed, up and down ones less
    if params.dash > 0 and target.push ~= nil then
        local side = dirX < 0 and -1 or 1
        if target ~= caster then
            side = target.body:getX() < caster.body:getX() and -1 or 1
        end
        local dashX, dashY = Spell.facingDirection(params, side)
        if dashX == nil then
            dashX, dashY = dirX, dirY
        end
        local speed = params.dash * SELF_DASH_SPEED
        target:push(dashX * speed, dashY * speed * SELF_DASH_VERTICAL)
    end
    return effect
end


function Self:update(dt)
    -- A target that died takes the effect with it, onExpire still goes off where it was
    if self:targetGone() then
        self:expire()
        return
    end
    self.lastX, self.lastY = self.target.body:getWorldCenter()
    self.time = self.time + dt
    local hpBar = self.target.hpBar
    if self.heal > 0 and hpBar ~= nil then
        hpBar.currentHP = math.min(hpBar.maxHP, hpBar.currentHP + self.heal / self.duration * dt)
    end
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self:expire()
    end
end


function Self:targetGone()
    local target = self.target
    return target.dying ~= nil or target.body:isDestroyed()
end


function Self:casterHit()
    -- The target was hurt while this lasts, onHit children start from the target going the way it was cast
    local x, y = self:getPosition()
    spells:trigger(self, "onHit", self.direction[1], self.direction[2], x, y)
end


function Self:getPosition()
    -- Where the target is, or was when it died
    if self:targetGone() then
        return self.lastX, self.lastY
    end
    return self.target.body:getWorldCenter()
end


function Self:destroy()
    if self.target.selfEffects ~= nil then
        self.target.selfEffects[self] = nil
        self.target.statsDirty = true
    end
end


function Self:draw()
    -- Aura around the target: rings that breathe, fading at the end
    if self:targetGone() then
        return
    end
    local x, y = self:getPosition()
    local fade = math.min(1, self.lifetime / 0.4, self.time / 0.15)
    local c = self.color
    local r = TILE_SIZE * (0.9 + 0.08 * math.sin(self.time * 6))
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setColor(c[1], c[2], c[3], 0.12 * fade)
    love.graphics.ellipse("fill", x, y, r, r * 1.5)
    love.graphics.setColor(c[1], c[2], c[3], 0.7 * fade)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", x, y, r, r * 1.5)
    love.graphics.pop()
end

return Self
