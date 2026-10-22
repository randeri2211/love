local Rune = require "runes.rune"

local Spell = {}

function Spell:new(core, slots)
    -- A spell is a magic circle, the core is the form rune name in the center
    -- and slots are the runes in the ring around it(clockwise from the top, see readSlot)
    local spell = {}
    setmetatable(spell,self)
    self.__index = self
    spell.core = core
    spell.coreDrawing = nil  -- Player drawing of the form rune, nil when it wasnt drawn
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
    -- A slot is a rune name("Speed"), or a table with the rune name, the trigger child circle(nil for modifiers)
    -- and the player drawing of the rune({"OnHit", childSpell, drawing = {quality, marks, strokes}})
    if type(slot) == "table" then
        return slot[1], slot[2] or nil, slot.drawing
    end
    return slot, nil, nil
end


-- Drawings are saved as plain numbers, strokes flattened to x1, y1, x2, y2... and rounded to keep saves small
local function drawingToData(drawing)
    if drawing == nil then
        return nil
    end
    local strokes = {}
    for i, stroke in ipairs(drawing.strokes or {}) do
        local flat = {}
        for j, point in ipairs(stroke) do
            table.insert(flat, math.floor(point[1] * 1000 + 0.5) / 1000)
            table.insert(flat, math.floor(point[2] * 1000 + 0.5) / 1000)
        end
        table.insert(strokes, flat)
    end
    return {quality = drawing.quality, marks = drawing.marks, strokes = strokes}
end


local function drawingFromData(data, rune)
    -- Bad or missing drawings load as nil, the rune then works at full strength like an undrawn rune
    -- The marks are checked by the rune that read them, so an edited save cant ask for 99 projectiles
    if rune == nil or type(data) ~= "table" or type(data.quality) ~= "number" then
        return nil
    end
    local strokes = {}
    for i, flat in ipairs(type(data.strokes) == "table" and data.strokes or {}) do
        local stroke = {}
        for j = 1, #flat - 1, 2 do
            if type(flat[j]) == "number" and type(flat[j + 1]) == "number" then
                table.insert(stroke, {flat[j], flat[j + 1]})
            end
        end
        table.insert(strokes, stroke)
    end
    local marks = nil
    if rune.checkMarks ~= nil and type(data.marks) == "table" then
        marks = rune:checkMarks(data.marks)
    end
    return {quality = math.max(0, math.min(1, data.quality)), marks = marks, strokes = strokes}
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
    -- A well drawn form hits harder(see Rune.strength)
    params.damage = params.damage * Rune.strength(self.coreDrawing and self.coreDrawing.quality)
    params.complexity = formRune.complexity
    params.manaCost = formRune.manaCost
    -- Marks drawn around the form(Bullet aim, burst and pierce), before the modifiers so they build on them
    local coreMarks = self.coreDrawing and self.coreDrawing.marks
    if coreMarks ~= nil then
        if formRune.applyMarks ~= nil then
            formRune:applyMarks(params, formRune:settings(coreMarks))
        end
        if formRune.markCost ~= nil then
            local complexity, mana = formRune:markCost(coreMarks)
            params.complexity = params.complexity + complexity
            params.manaCost = params.manaCost + mana
        end
    end
    params.triggers = {}    -- Child spells by event name, e.g. triggers.onHit = {childSpell}
    local colors = {formRune.color}

    -- Runes act on each other first: every rune starts with its own settings(Split count and fan),
    -- then runes with affects change the settings of every rune after them in the flow(Focus narrows a later Split)
    -- Runes the form blocks stay in the circle but do nothing and cost nothing
    local settings = {}
    for i, slot in ipairs(self.slots) do
        local runeName, _, drawing = self:readSlot(slot)
        local rune = runeName and RUNE_REGISTRY[runeName]
        if rune and not Spell.isBlocked(self.core, runeName) then
            settings[i] = rune:settings(drawing and drawing.marks)
        end
    end
    for i, slot in ipairs(self.slots) do
        local runeName, _, drawing = self:readSlot(slot)
        local rune = settings[i] and RUNE_REGISTRY[runeName]
        if rune and rune.affects ~= nil then
            local strength = Rune.strength(drawing and drawing.quality)
            for j = i + 1, #self.slots do
                local target = settings[j] and RUNE_REGISTRY[self:readSlot(self.slots[j])]
                local affect = target and rune.affects[target.name]
                if affect ~= nil then
                    affect(settings[j], strength)
                end
            end
        end
    end

    -- Then every rune applies to the spell(empty slots are false)
    for i, slot in ipairs(self.slots) do
        local runeName, childSpell, drawing = self:readSlot(slot)
        local rune = runeName and RUNE_REGISTRY[runeName]
        if settings[i] then
            -- Runes that acted on other runes still apply to the spell too
            if rune.kind == "modifier" then
                rune:apply(params, self.core, drawing and drawing.quality, settings[i])
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
            -- Marks drawn around the rune cost extra(more projectiles from Split arrows)
            if drawing ~= nil and drawing.marks ~= nil and rune.markCost ~= nil then
                local complexity, mana = rune:markCost(drawing.marks)
                params.complexity = params.complexity + complexity
                params.manaCost = params.manaCost + mana
            end
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


function Spell:toData()
    -- Plain data for saving: rune names with their drawings, triggers hold their child circle data
    local slots = {}
    for i = 1, SPELL_SLOTS do
        local runeName, childSpell, drawing = self:readSlot(self.slots[i])
        if not runeName then
            slots[i] = false
        else
            slots[i] = {runeName, childSpell and childSpell:toData() or false, drawing = drawingToData(drawing)}
        end
    end
    return {core = self.core, coreDrawing = drawingToData(self.coreDrawing), slots = slots}
end


function Spell.fromData(data, depth)
    -- Rebuilds a spell from saved data, checking every name against the rune registry
    -- so runes that dont exist anymore become empty slots and an unknown form becomes a Bullet
    depth = depth or 1
    local core, coreDrawing = data.core, nil
    if RUNE_REGISTRY[core] == nil or RUNE_REGISTRY[core].kind ~= "form" then
        core = "Bullet"
    else
        coreDrawing = drawingFromData(data.coreDrawing, RUNE_REGISTRY[core])
    end

    local slots = {}
    for i = 1, SPELL_SLOTS do
        -- Older saves have plain rune names and {trigger, child} without drawings
        local slot = data.slots and data.slots[i]
        local runeName, childData, drawingData = slot, nil, nil
        if type(slot) == "table" then
            runeName, childData, drawingData = slot[1], slot[2], slot.drawing
        end
        local rune = type(runeName) == "string" and RUNE_REGISTRY[runeName] or nil
        local drawing = drawingFromData(drawingData, rune)

        if rune == nil or rune.kind == "form" then
            slots[i] = false
        elseif rune.kind == "trigger" then
            -- Triggers need their child circle, and nesting stops at the depth limit
            if type(childData) == "table" and depth < MAX_SPELL_DEPTH then
                slots[i] = {runeName, Spell.fromData(childData, depth + 1), drawing = drawing}
            else
                slots[i] = false
            end
        else
            slots[i] = {runeName, nil, drawing = drawing}
        end
    end
    local spell = Spell:new(core, slots)
    spell.coreDrawing = coreDrawing
    return spell
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
    if self.cooldownClock ~= spells or self.cooldownEnd == nil then
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
    local defaultOrigin = x == nil or y == nil
    if defaultOrigin then
        x, y = caster.body:getWorldCenter()
    end
    if dirX == nil or dirY == nil then
        local mx, my = mouseToLove()
        dirX, dirY = mx - x, my - y
    end
    local dirSize = math.sqrt(dirX^2 + dirY^2)
    dirX, dirY = dirX / dirSize, dirY / dirSize

    -- Aim arrow drawn around the form turns the shot from the aim(triggered children turn from their own direction)
    -- Mirrored when aiming left, so an arrow pointing up always shoots higher
    if params.aimOffset ~= nil and params.aimOffset ~= 0 then
        local offset = dirX < 0 and -params.aimOffset or params.aimOffset
        dirX, dirY = dirX * math.cos(offset) - dirY * math.sin(offset), dirX * math.sin(offset) + dirY * math.cos(offset)
    end

    -- Casters with hands cast from between them instead of their center(triggered children keep their hit point)
    if defaultOrigin and caster.castOrigin ~= nil then
        x, y = caster:castOrigin(dirX, dirY)
    end

    spells:addCircle(self, x, y, dirX, dirY)

    -- The caster raises their hands toward the cast(only for casts they make, not triggered children)
    if not triggered and caster.castAt ~= nil then
        caster:castAt(dirX, dirY)
    end

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
    -- triggered tells forms the cast came from a trigger(like an Area centering on the hit point)
    local castParams = setmetatable({damage = params.damage * magicDamage, triggered = triggered == true}, {__index = params})

    self:spawnVolley(caster, castParams, x, y, dirX, dirY)

    -- Burst, more volleys in a row the same way, already paid for in the mana cost
    -- Casts the caster made follow their hands, triggered ones stay where they were triggered
    for shot = 2, params.burst or 1 do
        spells:schedule((shot - 1) * BURST_DELAY, function()
            local shotX, shotY = x, y
            if defaultOrigin and caster.castOrigin ~= nil then
                shotX, shotY = caster:castOrigin(dirX, dirY)
            end
            self:spawnVolley(caster, castParams, shotX, shotY, dirX, dirY)
        end)
    end
end


function Spell:spawnVolley(caster, castParams, x, y, dirX, dirY)
    -- Spawns every projectile of one cast
    for i = 1, castParams.count do
        -- Spread is the total fan width, projectiles are spaced evenly from one edge to the other
        local angle = 0
        if castParams.count > 1 then
            angle = -castParams.spread / 2 + (i - 1) * castParams.spread / (castParams.count - 1)
        end

        -- Rotate the aim direction by the angle
        local dx = dirX * math.cos(angle) - dirY * math.sin(angle)
        local dy = dirX * math.sin(angle) + dirY * math.cos(angle)

        local instance = castParams.form:new(caster, castParams, x, y, dx, dy)
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
