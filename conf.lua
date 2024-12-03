require "constants"

function love.conf(t)
    t.window.width = SCREEN_X
    t.window.height = SCREEN_Y
    t.window.vsync = -1
    t.console = true
end