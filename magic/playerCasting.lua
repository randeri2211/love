local MagicCircle = require "magic.magicCircle"
local Statuses = require "magic.statuses"

-- The player casting with the cast button: every cast builds its circle first(MagicCircle.timeline, the same recursive
-- wind-up enemies use, quicker and sped up by cast speed), the spell goes off when the circle is done
-- A Laser winds up once, then the beam is held while the button is(see Laser:updateHeld)
-- Letting go, switching spells or being frozen solid cancels a wind-up, the mana is only paid when the spell goes off
-- The caster keeps caster.casting({spell, timeline, clock}) while it builds and caster.channel(held beams) while it holds
local PlayerCasting = {}


local function aim(caster)
    -- Direction from the caster to the mouse
    local x, y = caster.body:getWorldCenter()
    local mx, my = mouseToLove()
    local dx, dy = mx - x, my - y
    local size = math.sqrt(dx * dx + dy * dy)
    if size < 0.001 then
        return 1, 0
    end
    return dx / size, dy / size
end


function PlayerCasting.release(caster)
    -- Ends the held beams
    for i, beam in ipairs(caster.channel or {}) do
        beam:release()
    end
    caster.channel, caster.channelSpell = nil, nil
end


local function holding(caster)
    -- True while a held beam is still going(running out of mana ends one on its own)
    for i, beam in ipairs(caster.channel or {}) do
        if beam.held then
            return true
        end
    end
    return false
end


function PlayerCasting.update(caster, spell, pressed, dt)
    -- pressed is true while the cast button is down over the world, spell is the selected spell
    if caster.channel ~= nil then
        if pressed and spell == caster.channelSpell and holding(caster) and not Statuses.isFrozen(caster) then
            return
        end
        PlayerCasting.release(caster)
    end

    local casting = caster.casting
    if casting ~= nil then
        if not pressed or casting.spell ~= spell or Statuses.isFrozen(caster) then
            caster.casting = nil
            return
        end
        casting.clock = casting.clock + dt
        local dx, dy = aim(caster)
        if caster.castAt ~= nil then
            caster:castAt(dx, dy)       -- Hands up toward the circle while it builds
        end
        if casting.clock >= casting.timeline.total then
            caster.casting = nil
            caster.castBuilt = true                         -- The cast circle starts already built
            caster.channelCast = spell.core == "Laser"      -- A laser is held(see Spell:shoot)
            spell:shoot(caster)
            caster.castBuilt, caster.channelCast = nil, nil
            if caster.channel ~= nil then
                caster.channelSpell = spell
            end
        end
        return
    end

    if pressed and spell ~= nil and not Statuses.isFrozen(caster) and spell:canCast(caster) then
        local speed = caster.combatStats and caster.combatStats.castSpeed or 1
        caster.casting = {
            spell = spell,
            timeline = MagicCircle.timeline(spell, PLAYER_CAST_RING_TIME / speed, PLAYER_CAST_RUNE_TIME / speed),
            clock = 0,
        }
    end
end


function PlayerCasting.draw(caster)
    -- World space: the circle building in front of the hands, where the cast circle shows once it goes off
    local casting = caster.casting
    if casting == nil then
        return
    end
    local dx, dy = aim(caster)
    local x, y = caster.body:getWorldCenter()
    if caster.castOrigin ~= nil then
        x, y = caster:castOrigin(dx, dy)
    end
    MagicCircle.draw(casting.spell, x + dx * CAST_CIRCLE_OFFSET, y + dy * CAST_CIRCLE_OFFSET, CAST_CIRCLE_SCALE, {
        timeline = casting.timeline,
        clock = casting.clock,
        spiral = true,
    })
end

return PlayerCasting
