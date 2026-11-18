local MagicCircle = require "magic.magicCircle"
local Statuses = require "magic.statuses"

-- The player casting: every input that casts(the cast button with the selected spell, a quick-cast key with its spell,
-- see Spellbooks.quickKey) runs a cast of its own. A cast builds its circle first(MagicCircle.timeline, the same
-- recursive wind-up enemies use, quicker and sped up by cast speed), the spell goes off when the circle is done, and
-- while the input is held it builds again(a Laser winds up once, then the beam is held, see Laser:updateHeld)
-- Casts run side by side up to the caster's cast slots(1, more from gear, see castSlots): starting one more halts the
-- oldest, which stays halted until its input is let go, so it doesnt take its slot straight back
-- A cast aims at the mouse, or with the movement keys(W, A, S, D and between them, the way the caster faces when none
-- is held), set per spell(see Spellbooks.aimOf)
-- Letting go, a different spell on the input or being frozen solid ends a cast, the mana is only paid when it goes off
-- The caster keeps caster.casts, oldest first: {input, spell, aim, phase("waiting", "building", "holding"),
-- timeline, clock, beams}, and caster.haltedInputs
local PlayerCasting = {}


local function normalize(dx, dy)
    local size = math.sqrt(dx * dx + dy * dy)
    if size < 0.001 then
        return nil
    end
    return dx / size, dy / size
end


function PlayerCasting.aim(caster, mode)
    -- Direction a cast goes: to the mouse, or by the movement keys
    if mode == "keys" then
        local dx = (love.keyboard.isDown(RIGHT_KEY) and 1 or 0) - (love.keyboard.isDown(LEFT_KEY) and 1 or 0)
        local dy = (love.keyboard.isDown(AIM_DOWN_KEY) and 1 or 0) - (love.keyboard.isDown(AIM_UP_KEY) and 1 or 0)
        local x, y = normalize(dx, dy)
        if x == nil then
            return caster.direction == "left" and -1 or 1, 0
        end
        return x, y
    end
    local x, y = caster.body:getWorldCenter()
    local mx, my = mouseToLove()
    local ax, ay = normalize(mx - x, my - y)
    if ax == nil then
        return 1, 0
    end
    return ax, ay
end


local function holding(cast)
    -- True while one of its held beams is still going(running out of mana ends one on its own)
    for i, beam in ipairs(cast.beams or {}) do
        if beam.held then
            return true
        end
    end
    return false
end


local function stop(cast)
    -- Ends a cast: its wind-up goes, its held beams let go
    for i, beam in ipairs(cast.beams or {}) do
        beam:release()
    end
    cast.beams = nil
end


function PlayerCasting.slots(caster)
    -- How many casts can run at once
    return 1 + (caster.combatStats and caster.combatStats.castSlots or 0)
end


local function step(caster, cast, dt)
    -- One frame of a cast that is still held
    if cast.phase == "holding" then
        if holding(cast) then
            return
        end
        cast.beams, cast.phase = nil, "waiting"      -- The beam ran out of mana, it builds again
    end
    if cast.phase == "waiting" then
        if not cast.spell:canCast(caster) then
            return
        end
        local speed = caster.combatStats and caster.combatStats.castSpeed or 1
        cast.timeline = MagicCircle.timeline(cast.spell, PLAYER_CAST_RING_TIME / speed, PLAYER_CAST_RUNE_TIME / speed)
        cast.clock, cast.phase = 0, "building"
    end
    cast.clock = cast.clock + dt
    local dx, dy = PlayerCasting.aim(caster, cast.aim)
    if caster.castAt ~= nil then
        caster:castAt(dx, dy)       -- Hands up toward the circle while it builds
    end
    if cast.clock < cast.timeline.total then
        return
    end
    -- The circle is done: it goes off, a laser is held while the input is(see Spell:shoot)
    cast.phase = "waiting"
    local earlier = caster.channel
    caster.channel = nil
    caster.castBuilt = true                         -- The cast circle starts already built
    caster.channelCast = cast.spell.core == "Laser"
    cast.spell:shoot(caster, nil, nil, dx, dy)
    caster.castBuilt, caster.channelCast = nil, nil
    if caster.channel ~= nil then
        cast.beams, cast.phase = caster.channel, "holding"
        local mode = cast.aim
        for i, beam in ipairs(cast.beams) do
            beam.aim = function() return PlayerCasting.aim(caster, mode) end     -- A held beam follows its own aim
        end
    end
    caster.channel = earlier
end


function PlayerCasting.update(caster, inputs, dt)
    -- inputs: what can cast this frame, {id, spell, pressed, aim}(the cast button, every quick-cast key)
    -- An empty list stops every cast(the caster is dead or cant act)
    caster.casts = caster.casts or {}
    caster.haltedInputs = caster.haltedInputs or {}
    local byId = {}
    for i, input in ipairs(inputs) do
        byId[input.id] = input
        if not input.pressed then
            caster.haltedInputs[input.id] = nil     -- Let go, a halted input can cast again
        end
    end
    local frozen = Statuses.isFrozen(caster)

    -- Casts whose input was let go, changed spell or aim, or that cant go on end
    for i = #caster.casts, 1, -1 do
        local cast = caster.casts[i]
        local input = byId[cast.input]
        if input == nil or not input.pressed or input.spell ~= cast.spell or input.aim ~= cast.aim or frozen then
            stop(cast)
            table.remove(caster.casts, i)
        end
    end
    for i, cast in ipairs(caster.casts) do
        step(caster, cast, dt)
    end

    -- New casts, the oldest is halted when every slot is taken
    if frozen then
        return
    end
    for i, input in ipairs(inputs) do
        local running = false
        for j, cast in ipairs(caster.casts) do
            if cast.input == input.id then
                running = true
            end
        end
        if input.pressed and input.spell ~= nil and not running and not caster.haltedInputs[input.id] then
            if #caster.casts >= PlayerCasting.slots(caster) then
                local oldest = table.remove(caster.casts, 1)
                stop(oldest)
                caster.haltedInputs[oldest.input] = true
            end
            local cast = {input = input.id, spell = input.spell, aim = input.aim, phase = "waiting"}
            table.insert(caster.casts, cast)
            step(caster, cast, dt)
        end
    end
end


function PlayerCasting.release(caster)
    -- Ends every cast(see the death and the respawn)
    for i, cast in ipairs(caster.casts or {}) do
        stop(cast)
    end
    caster.casts = {}
end


function PlayerCasting.draw(caster)
    -- World space: every circle building in front of the hands, where the cast circle shows once it goes off
    for i, cast in ipairs(caster.casts or {}) do
        if cast.phase == "building" then
            local dx, dy = PlayerCasting.aim(caster, cast.aim)
            local x, y = caster.body:getWorldCenter()
            if caster.castOrigin ~= nil then
                x, y = caster:castOrigin(dx, dy)
            end
            MagicCircle.draw(cast.spell, x + dx * CAST_CIRCLE_OFFSET, y + dy * CAST_CIRCLE_OFFSET, CAST_CIRCLE_SCALE, {
                timeline = cast.timeline,
                clock = cast.clock,
                spiral = true,
            })
        end
    end
end

return PlayerCasting
