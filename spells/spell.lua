require "world.world"
require "spells.bullet1"
Spell = {}

function Spell:new(form)
    local spell = {}
    setmetatable(spell,self)
    self.__index = self
    spell.form = form
    return spell
end

function Spell:shoot(player)
    print("form "..tostring(self.form.new))

    local spellShot = self.form:new(player)
    table.insert(spells.spells, spellShot)
end