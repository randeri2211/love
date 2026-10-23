local Rune = {}

function Rune:new(name, kind, complexity, manaCost, color)
    -- Rune Variables
    local rune = {}
    setmetatable(rune, self)
    self.__index = self

    if name == nil then
        return rune
    end

    rune.name = name
    rune.kind = kind                -- "form" sits in the center of the circle, "modifier" and "trigger" go in the ring
    rune.complexity = complexity or 0
    rune.manaCost = manaCost or 0
    rune.color = color or {1, 1, 1}  -- Used to color the spell and the magic circle
    rune.glyph = nil                -- Symbol drawn in the circle slot, set by each rune file
    -- Modifiers set effects to a function per form name, "default" works on any form
    -- Forms without an effect(and no default) cant use the modifier
    rune.effects = nil
    -- Forms list their own params for the editor to show, as {label, param name, format}
    rune.stats = nil
    -- Runes that read marks drawn around them set these(see Split):
    -- readMarks(self, marks) turns the marks from Strokes.readMarks into a plain table that is saved with the slot,
    -- or returns nil and a reason when the marks cant go together(two aim arrows on a Bullet)
    -- checkMarks(self, saved) cleans that table when a save loads, nil drops it
    -- markCost(self, marks) returns the extra complexity and mana the marks add
    -- describeMarks(self, marks) is the text the editor shows for them
    -- Runes can act on runes after them in the flow before anything reaches the spell:
    -- settings(self, marks) is the table a rune is changed through, its marks or its defaults(see Split)
    -- affects maps a rune name to function(settings, strength) that changes that rune settings(see Focus)
    -- Effects get the settings as a second argument
    -- Forms have no effects, their marks go through applyMarks(self, params, settings) instead(see Bullet)
    rune.affects = nil

    return rune
end


-- Rune Functions
function Rune:worksWith(formName)
    -- Runes without effects(forms, triggers) work on every form
    if self.effects == nil then
        return true
    end
    return self.effects[formName] ~= nil or self.effects.default ~= nil
end


function Rune:settings(marks)
    -- Starting settings for this rune in a spell, a copy so other runes can change it without touching the saved marks
    local settings = {}
    for key, value in pairs(marks or {}) do
        settings[key] = value
    end
    return settings
end


-- Aim Marks
-- Forms that are cast in a direction share one mark: a single arrow turns the cast from the aim the way it points
-- (only one, a cast cant go two ways), Spell:shoot turns the direction by params.aimOffset
local AIM_MIN_QUALITY = 0.25        -- Arrows drawn worse than this dont count
local AIM_COMPLEXITY = 1

function Rune:useAimMarks()
    -- Gives a form the aim arrow mark(see Bullet and Laser)
    function self:readMarks(marks)
        local arrows = {}
        for i, mark in ipairs(marks) do
            if mark.kind == "arrow" and mark.quality >= AIM_MIN_QUALITY then
                table.insert(arrows, mark)
            end
        end
        if #arrows > 1 then
            return nil, "Only one aim arrow on a " .. self.name
        end
        if #arrows == 0 then
            return nil
        end
        -- 0 is the aim(to the right on the pad), turned to -180 to 180 degrees
        return {aim = (arrows[1].direction + math.pi) % (2 * math.pi) - math.pi}
    end

    function self:checkMarks(saved)
        -- Marks the form doesnt have anymore(old Bullet bursts and pierce) are dropped
        if type(saved.aim) ~= "number" then
            return nil
        end
        return {aim = math.max(-math.pi, math.min(math.pi, saved.aim))}
    end

    function self:markCost(marks)
        return AIM_COMPLEXITY, 0
    end

    function self:describeMarks(marks)
        local degrees = math.floor(math.deg(math.abs(marks.aim)) + 0.5)
        return string.format("aimed %d %s", degrees, marks.aim < 0 and "up" or "down")
    end

    function self:applyMarks(params, marks)
        params.aimOffset = marks.aim
    end
end


-- Params a drawn rune always changes fully, whatever the drawing quality
-- Costs stay fixed so a sloppy drawing isnt cheaper
-- Repeats and pierce are counted from marks, their quality is already in the count
-- The gravity direction is a direction, blending it would also weaken it
Rune.FULL_PARAMS = {manaScale = true, complexityScale = true, cooldownScale = true, bounces = true, repeats = true, pierce = true,
    gravityX = true, gravityY = true}
-- Params that scale with quality but have to stay whole numbers(a Split drawn at 70% makes fewer projectiles)
Rune.WHOLE_PARAMS = {count = true}


function Rune.strength(quality)
    -- How much of a rune effect a drawing gets, quality is 0 to 1 from the recognizer(nil for runes that werent drawn)
    if quality == nil then
        return 1
    end
    -- Linear, a rune drawn at 70% gets 70% of its effect
    return math.max(0, math.min(1, quality))
end


local function blend(before, after, strength)
    -- Moves a param from its old value toward the full effect, by strength(0 is no change, 1 is the full effect)
    if type(before) ~= "number" or type(after) ~= "number" then
        return after
    end
    -- Drawbacks(lower damage from Split or Weaken) always land fully, so a sloppy drawing cant dodge them
    if after <= before then
        return after
    end
    -- Multiplied values blend on the ratio so x1.5 at half strength is about x1.22, not x1.25
    if before ~= 0 and after / before > 0 then
        return before * (after / before) ^ strength
    end
    -- Values switched on from 0(gravity, recoil) blend in a straight line
    return before + (after - before) * strength
end


function Rune:apply(params, formName, quality, settings)
    -- Runs the effect for this form, falling back to the default effect(multiply values so modifiers stack)
    -- A drawn rune effect is scaled by how well it was drawn, settings come from its marks and the runes before it
    if self.effects == nil then
        return
    end
    local effect = self.effects[formName] or self.effects.default
    if effect == nil then
        return
    end
    local strength = Rune.strength(quality)
    if strength >= 1 then
        effect(params, settings)
        return
    end

    -- Run the effect on a copy, then move each changed param only part of the way
    local changed = {}
    for key, value in pairs(params) do
        changed[key] = value
    end
    effect(changed, settings)
    for key, value in pairs(changed) do
        if Rune.FULL_PARAMS[key] or params[key] == nil then
            params[key] = value
        elseif Rune.WHOLE_PARAMS[key] then
            params[key] = math.floor(blend(params[key], value, strength) + 0.5)
        else
            params[key] = blend(params[key], value, strength)
        end
    end
end

return Rune
