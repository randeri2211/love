-- What elements look like: particles from spells and from things burning, frozen or poisoned, a glow around projectiles
-- and the bolts Lightning jumps along. World space, drawn with the spells(over the time of day light, so they glow at night)
local ElementFx = {}

-- How each element moves: colors to fade through, speed ranges, how long a particle lives and how big it is
local STYLES = {
    -- Flames rise and fade from yellow to red
    Fire = {colors = {{1, 0.9, 0.4}, {1, 0.45, 0.1}, {0.6, 0.1, 0.05}}, vx = {-15, 15}, vy = {-80, -40}, life = {0.35, 0.65}, size = 3},
    -- Frost flakes drift down slowly and twinkle
    Frost = {colors = {{0.95, 1, 1}, {0.6, 0.85, 1}}, vx = {-12, 12}, vy = {8, 26}, life = {0.7, 1.1}, size = 2, twinkle = true},
    -- Bubbles rise slowly and sway
    Poison = {colors = {{0.7, 1, 0.4}, {0.3, 0.7, 0.15}}, vx = {-6, 6}, vy = {-30, -12}, life = {0.8, 1.2}, size = 3, sway = true},
    -- Sparks shoot out fast in every direction and are gone at once
    Lightning = {colors = {{1, 1, 0.85}, {1, 0.9, 0.35}}, speed = {80, 150}, life = {0.12, 0.25}, size = 2, streak = true},
    -- Not an element: the white and gold burst of a critical hit(see magic/crit)
    Crit = {colors = {{1, 1, 1}, {1, 0.85, 0.35}}, speed = {60, 120}, life = {0.15, 0.3}, size = 3, streak = true},
}
ElementFx.COLORS = {}      -- The main color of each element, its glow
for name, style in pairs(STYLES) do
    ElementFx.COLORS[name] = style.colors[2]
end

local BOLT_TIME = 0.2       -- Seconds a lightning bolt stays
local BOLT_JAGS = 6         -- Corners in a bolt

local particles = {}
local bolts = {}


local function range(r)
    return r[1] + love.math.random() * (r[2] - r[1])
end


function ElementFx.emit(element, x, y, spread, count)
    -- count particles of an element around x, y(within spread pixels)
    local style = STYLES[element]
    if style == nil then
        return
    end
    for i = 1, count do
        if #particles >= ELEMENT_PARTICLES then
            return
        end
        local angle = love.math.random() * math.pi * 2
        local d = love.math.random() * spread
        local vx, vy
        if style.speed ~= nil then
            local speed, dir = range(style.speed), love.math.random() * math.pi * 2
            vx, vy = math.cos(dir) * speed, math.sin(dir) * speed
        else
            vx, vy = range(style.vx), range(style.vy)
        end
        local life = range(style.life)
        table.insert(particles, {
            style = style, x = x + math.cos(angle) * d, y = y + math.sin(angle) * d,
            vx = vx, vy = vy, life = life, maxLife = life, phase = love.math.random() * 6,
        })
    end
end


function ElementFx.trail(elements, x, y, spread, rate, dt)
    -- Particles of every element in a list at about rate per second, the leftover chance carries over randomly
    for i, element in ipairs(elements) do
        local amount = rate * dt
        local count = math.floor(amount)
        if love.math.random() < amount - count then
            count = count + 1
        end
        ElementFx.emit(element, x, y, spread, count)
    end
end


function ElementFx.bolt(x1, y1, x2, y2)
    -- A jagged lightning line from one point to another, for a Lightning hit jumping between enemies
    local points = {x1, y1}
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    local nx, ny = -dy / math.max(length, 1), dx / math.max(length, 1)
    for i = 1, BOLT_JAGS - 1 do
        local t = i / BOLT_JAGS
        local off = (love.math.random() * 2 - 1) * length * 0.12
        table.insert(points, x1 + dx * t + nx * off)
        table.insert(points, y1 + dy * t + ny * off)
    end
    table.insert(points, x2)
    table.insert(points, y2)
    table.insert(bolts, {points = points, time = BOLT_TIME})
    ElementFx.emit("Lightning", x2, y2, 6, 8)
end


function ElementFx.update(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            particles[i] = particles[#particles]
            particles[#particles] = nil
        else
            local sway = p.style.sway and math.sin((p.maxLife - p.life) * 6 + p.phase) * 20 or 0
            p.x = p.x + (p.vx + sway) * dt
            p.y = p.y + p.vy * dt
        end
    end
    for i = #bolts, 1, -1 do
        bolts[i].time = bolts[i].time - dt
        if bolts[i].time <= 0 then
            table.remove(bolts, i)
        end
    end
end


local function colorAt(colors, t)
    -- Fades through the colors as t goes from 0(new) to 1(gone)
    local f = t * (#colors - 1)
    local i = math.min(#colors - 1, math.floor(f))
    local a, b, k = colors[i + 1], colors[math.min(#colors, i + 2)], f - i
    return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
end


function ElementFx.glow(elements, x, y, radius)
    -- A soft halo of every element color around a projectile, they flicker a little
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    for i, element in ipairs(elements) do
        local c = ElementFx.COLORS[element]
        local flicker = 0.85 + 0.15 * math.sin(love.timer.getTime() * 18 + i * 2)
        love.graphics.setColor(c[1], c[2], c[3], 0.18 * flicker)
        love.graphics.circle("fill", x, y, radius * 2.6, 20)
        love.graphics.setColor(c[1], c[2], c[3], 0.3 * flicker)
        love.graphics.circle("fill", x, y, radius * 1.6, 20)
    end
    love.graphics.pop()
end


function ElementFx.draw()
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    for i, p in ipairs(particles) do
        local t = 1 - p.life / p.maxLife
        local r, g, b = colorAt(p.style.colors, t)
        local alpha = 1 - t
        if p.style.twinkle then
            alpha = alpha * (0.5 + 0.5 * math.sin(p.phase + t * 20))
        end
        love.graphics.setColor(r, g, b, alpha)
        if p.style.streak then
            love.graphics.setLineWidth(p.style.size)
            love.graphics.line(p.x, p.y, p.x - p.vx * 0.03, p.y - p.vy * 0.03)
        else
            local s = p.style.size * (1 - t * 0.5)
            love.graphics.rectangle("fill", math.floor(p.x - s / 2), math.floor(p.y - s / 2), s, s)
        end
    end
    for i, bolt in ipairs(bolts) do
        local fade = bolt.time / BOLT_TIME
        love.graphics.setColor(1, 0.9, 0.4, 0.5 * fade)
        love.graphics.setLineWidth(6)
        love.graphics.line(bolt.points)
        love.graphics.setColor(1, 1, 0.9, fade)
        love.graphics.setLineWidth(2)
        love.graphics.line(bolt.points)
    end
    love.graphics.pop()
end


function ElementFx.clear()
    -- Loading a world starts without old particles
    particles, bolts = {}, {}
end

return ElementFx
