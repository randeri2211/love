require "spells.spell"

Spells = {}

function Spells:new()
    local spells = {}
    setmetatable(spells,self)
    self.__index = self
    spells.spells = {}

    return spells
end

function Spells:draw()
    for i, spell in pairs(self.spells) do
        spell:draw()
    end
end