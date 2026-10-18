local Spell = {}

function Spell:new(core, slots)
    -- A spell is a magic circle, the core is the form rune name in the center
    -- and slots are the rune names in the ring around it(clockwise from the top)
    local spell = {}
    setmetatable(spell,self)
    self.__index = self
    spell.core = core
    spell.slots = slots or {}
    spell.dirty = true      -- Compile on first use
    return spell
end


function Spell.isBlocked(formName, runeName)
    -- True when the rune has no effect for this form(see Rune:worksWith)
    local rune = RUNE_REGISTRY[runeName]
    return rune ~= nil and not rune:worksWith(formName)
end


function Spell:readSlot(slot)
    -- A slot is either a rune name("Speed") or a trigger with its child circle({"OnHit", childSpell})
    if type(slot) == "table" then
        return slot[1], slot[2]
    end
    return slot, nil
end


function Spell:compile(depth)
    -- Turns the circle into a flat params table the form can use
    depth = depth or 1
    local formRune = RUNE_REGISTRY[self.core]
    -- Shared base params first, then the form own values on top
    local params = {}
    for key, value in pairs(BASE_SPELL_PARAMS) do
        params[key] = value
    end
    for key, value in pairs(formRune:defaults()) do
        params[key] = value
    end
    params.form = formRune.form
    params.complexity = formRune.complexity
    params.manaCost = formRune.manaCost
    params.triggers = {}    -- Child spells by event name, e.g. triggers.onHit = {childSpell}
    local colors = {formRune.color}

    -- Apply every rune in the ring(empty slots are false)
    for i, slot in ipairs(self.slots) do
        local runeName, childSpell = self:readSlot(slot)
        local rune = runeName and RUNE_REGISTRY[runeName]
        -- Runes the form blocks stay in the circle but do nothing and cost nothing
        if rune and not Spell.isBlocked(self.core, runeName) then
            if rune.kind == "modifier" then
                rune:apply(params, self.core)
            elseif rune.kind == "trigger" and childSpell ~= nil then
                if depth < MAX_SPELL_DEPTH then
                    -- Child complexity counts toward this spell, the child mana is paid when the trigger happens
                    local childParams = childSpell:compile(depth + 1)
                    params.complexity = params.complexity + childParams.complexity
                    params.triggers[rune.event] = params.triggers[rune.event] or {}
                    table.insert(params.triggers[rune.event], childSpell)
                else
                    print("Spell too deep, ignoring "..runeName.." trigger")
                end
            end
            params.complexity = params.complexity + rune.complexity
            params.manaCost = params.manaCost + rune.manaCost
            table.insert(colors, rune.color)
        end
    end

    -- Form and rune scales on the totals(rounded so the editor shows clean numbers)
    -- Child complexity is already inside the total, so a discount here covers the children too
    params.manaCost = math.floor(params.manaCost * params.manaScale * 10 + 0.5) / 10
    params.complexity = math.floor(params.complexity * params.complexityScale + 0.5)

    -- Blend all rune colors into the spell color
    params.color = {0, 0, 0, 1}
    for i, color in ipairs(colors) do
        for c = 1, 3 do
            params.color[c] = params.color[c] + color[c] / #colors
        end
    end

    self.params = params
    self.dirty = false
    return params
end


function Spell:getParams()
    -- Only recompile when the circle changed
    if self.dirty then
        self:compile()
    end
    return self.params
end


function Spell:setSlots(slots)
    -- Changes the ring runes and marks the spell for recompiling
    self.slots = slots
    self.dirty = true
end


function Spell:getMaxComplexity(caster)
    if caster.combatStats ~= nil then
        return caster.combatStats.maxComplexity
    end
    return BASE_MAX_COMPLEXITY
end


function Spell:getCooldown(caster)
    -- More complex spells take longer to cast again, cooldown reduction shortens it
    local cooldownReduction = 0
    if caster.combatStats ~= nil then
        cooldownReduction = caster.combatStats.cooldownReduction
    end
    local params = self:getParams()
    return params.complexity * COOLDOWN_PER_COMPLEXITY * params.cooldownScale * (1 - cooldownReduction)
end


function Spell:cooldownLeft()
    -- Seconds until the spell can be cast again, in game time so pausing freezes it
    -- Loading a world makes a new spells clock, cooldowns from the old one dont count
    if self.cooldownClock ~= spells then
        return 0
    end
    return math.max(0, self.cooldownEnd - spells.time)
end


function Spell:canCast(caster)
    -- Returns true, or false and the reason("complexity", "cooldown", "mana")
    local params = self:getParams()
    if params.complexity > self:getMaxComplexity(caster) then
        return false, "complexity"
    end
    if self:cooldownLeft() > 0 then
        return false, "cooldown"
    end
    if caster.manaBar.currentMana < params.manaCost then
        return false, "mana"
    end
    return true
end


function Spell:shoot(caster, x, y, dirX, dirY, triggered)
    -- Casts the spell from x, y in the dirX, dirY direction(defaults to the caster aiming at the mouse)
    -- triggered is true for child spells, their complexity and cooldown were checked with the parent
    local params = self:getParams()

    if triggered then
        -- Child spells still pay their own mana, and fizzle without enough
        if caster.manaBar.currentMana < params.manaCost then
            return
        end
    else
        if not self:canCast(caster) then
            return
        end
        self.cooldownEnd = spells.time + self:getCooldown(caster)
        self.cooldownClock = spells
    end
    caster.manaBar.currentMana = caster.manaBar.currentMana - params.manaCost

    -- Default origin and direction
    if x == nil or y == nil then
        x, y = caster.body:getWorldCenter()
    end
    if dirX == nil or dirY == nil then
        local mx, my = mouseToLove()
        dirX, dirY = mx - x, my - y
    end
    local dirSize = math.sqrt(dirX^2 + dirY^2)
    dirX, dirY = dirX / dirSize, dirY / dirSize

    spells:addCircle(self, x, y, dirX, dirY)

    -- Recoil pushes the caster away from the aim, only for casts the caster makes(not triggered children)
    -- Rapid fire forms push less per cast so holding them pushes about as hard
    if not triggered and params.recoil > 0 and caster.push ~= nil then
        local strength = params.recoil * RECOIL_SPEED * params.cooldownScale
        caster:push(-dirX * strength, -dirY * strength)
    end

    -- Magic damage bonus from the caster stats
    local magicDamage = 1
    if caster.combatStats ~= nil then
        magicDamage = caster.combatStats.magicDamage
    end
    -- Params for this cast only, reads everything else from the compiled params
    local castParams = setmetatable({damage = params.damage * magicDamage}, {__index = params})

    -- Spawn every projectile
    for i = 1, params.count do
        -- Spread is the total fan width, projectiles are spaced evenly from one edge to the other
        local angle = 0
        if params.count > 1 then
            angle = -params.spread / 2 + (i - 1) * params.spread / (params.count - 1)
        end

        -- Rotate the aim direction by the angle
        local dx = dirX * math.cos(angle) - dirY * math.sin(angle)
        local dy = dirX * math.sin(angle) + dirY * math.cos(angle)

        local instance = params.form:new(caster, castParams, x, y, dx, dy)
        if instance ~= nil then
            instance.spell = self   -- So triggers can find their child spells
            local t = {}
            t.spell = self
            t.instance = instance
            table.insert(spells.spells, t)
        end
    end
end

return Spell
