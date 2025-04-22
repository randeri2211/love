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
    local t = {}
    t.spell = self
    t.instance = spellShot
    if spellShot ~= nil then
        table.insert(spells.spells, t)
    end
end