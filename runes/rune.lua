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


function Rune:apply(params, formName)
    -- Runs the effect for this form, falling back to the default effect(multiply values so modifiers stack)
    if self.effects == nil then
        return
    end
    local effect = self.effects[formName] or self.effects.default
    if effect ~= nil then
        effect(params)
    end
end

return Rune
