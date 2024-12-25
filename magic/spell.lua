require "world.world"
require "magic.bullet1"
Spell = {}

function Spell:new(form, damage)
    local spell = {}
    setmetatable(spell,self)
    self.__index = self
    spell.damage = damage
    spell.form = form
    return spell
end

function Spell:shoot(player)
    local spellShot = self.form:new(player)
    if spellShot ~= nil then
        table.insert(spells.spells, spellShot)
    end
end