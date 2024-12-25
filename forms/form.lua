
Form = {}

function Form:new(player)
    local form = {}
    setmetatable(form,self)
    self.__index = self
    if player == nil then
        return form
    end
    form.player = player

    return form
end

function Form:update(dt)

end