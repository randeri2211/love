-- Time of day for the open world: one number(map.time, seconds of game time) and ways to read it
-- Anything that changes over the day describes itself as values at named moments(night, dawn, day, dusk)
-- and WorldClock.blend mixes the two nearest for now, so systems never decide on their own when dusk is
local WorldClock = {}


function WorldClock.dayLength()
    -- Seconds in a day, the world setting(saved with it), or a short day for testing with DEBUG on
    if DEBUG and DEBUG_DAY_LENGTH ~= nil then
        return DEBUG_DAY_LENGTH
    end
    return map.settings and map.settings.dayLength or DAY_LENGTH
end


function WorldClock.update(dt)
    -- Game time only, a paused game stops the clock
    map.time = (map.time or 0) + dt
end


function WorldClock.phase()
    -- How far through the day it is: 0 midnight, 0.25 dawn, 0.5 noon, 0.75 dusk
    return ((map.time or 0) % WorldClock.dayLength()) / WorldClock.dayLength()
end


local function mix(a, b, t)
    if type(a) == "number" then
        return a + (b - a) * t
    end
    local result = {}
    for i = 1, #a do
        result[i] = a[i] + (b[i] - a[i]) * t
    end
    return result
end


function WorldClock.blend(values, phase)
    -- Value for now from values at named moments: {night = ..., dawn = ..., day = ..., dusk = ...}
    -- Values are numbers or color tables, moments left out use day, TIME_KEYS says where the moments are in the day
    phase = phase or WorldClock.phase()
    local keys = TIME_KEYS
    for i = 1, #keys do
        local from, to = keys[i], keys[i % #keys + 1]
        local start, finish = from[2], to[2]
        if finish <= start then
            finish = finish + 1     -- The last moment blends over midnight into the first
        end
        local p = phase
        if p < start then
            p = p + 1
        end
        if p >= start and p < finish then
            local t = (p - start) / (finish - start)
            t = t * t * (3 - 2 * t)     -- Eases in and out, so changes start and end gently
            local a = values[from[1]] or values.day
            local b = values[to[1]] or values.day
            return mix(a, b, t)
        end
    end
    return values.day
end


function WorldClock.value(v)
    -- A value that may change over the day: a table with moment names is blended, anything else is the same all day
    if type(v) == "table" and (v.day ~= nil or v.night ~= nil or v.dawn ~= nil or v.dusk ~= nil) then
        return WorldClock.blend(v)
    end
    return v
end


function WorldClock.light()
    -- How bright the day is now, 0 the middle of the night to 1 full day
    return WorldClock.blend({night = 0, dawn = 0.5, day = 1, dusk = 0.5})
end


function WorldClock.isNight()
    return WorldClock.light() < 0.25
end

return WorldClock
