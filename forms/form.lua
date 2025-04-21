
Form = {}

function Form:new(player)
    local form = {}
    setmetatable(form,self)
    self.__index = self

    form.type = "Form"
    form.form = nil
    if player == nil then
        return form
    end
    form.player = player

    return form
end

function Form:update(dt)
end

function Form:destroy()
end

function Form:isFixture(fixture)
end