require "magic.spell"

Spells = {}

function Spells:new()
    local spells = {}
    setmetatable(spells,self)
    self.__index = self
    spells.spells = {}

    return spells
end


function Spells:update(dt)
    for i, spell in pairs(self.spells) do
        spell.instance:update(dt)
    end
end


function Spells:draw()
    for i, spell in pairs(self.spells) do
        spell.instance:draw()
    end
end


function Spells:getSpellByFixture(fixture)
    for i, spell in pairs(self.spells) do
        if spell.instance:isFixture(fixture) then
            return spell
        end
    end
end


function Spells:destroy(instance)
    for i, spell in pairs(self.spells) do
        if spell.instance == instance then
            spell.instance:destroy()
            table.remove(self.spells, i)
            return true
        end
    end
    return false
end