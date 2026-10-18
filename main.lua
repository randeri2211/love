require "registry"
require "system_utils"

require "keys"
require "assets.assetLoader"
require "world_utils.world"
require "world_utils.scene"
local Slab = require "libraries.Slab"
local debugWorldDraw = require "libraries.debugWorldDraw"
local UIHandler = require "ui.uiHandler"
local Spell = require "magic.spell"
local new_frame = false

function love.load(args)
    -- local font = love.graphics.newFont("assets/RamadhanMubarok-Regular.otf")
    -- love.graphics.setFont(font)
    game_state = MENU_STATE
    Slab.Initialize(args)
    initVars()
    registerAll()

    -- Test spells, number keys pick which one the shoot key casts and the editor edits
    spellPresets = {
        Spell:new("Bullet", {"Speed", {"OnHit", Spell:new("Bullet", {"Split", "Split"})}}),     -- 1 Bullet bursting into a shotgun
        Spell:new("Bullet", {"Speed", {"OnHit", Spell:new("Area", {"Size"})}}),                 -- 2 Exploding bullet
        Spell:new("Laser", {"Rebound", "Damage"}),                                              -- 3 Bouncing laser
        Spell:new("Area", {"Gravity", "Size"}),                                                 -- 4 Gravity well
        Spell:new("Trap", {"Split", "Split"}),                                                  -- 5 Minefield
        Spell:new("Bullet", {"Split", "Gravity", "Rebound"}),                                   -- 6 Bouncing arcs
    }
    spellTest = spellPresets[1]

    fpsTimer = love.timer.getTime()

    uihandler = UIHandler:new()
end

function love.update(dt)
    Slab.Update(dt)
    uihandler:update()

    if game_state == IN_WORLD_STATE then
        if not paused then
            player:updateAnimation()

            -- Update physics
            manageHitbox()
            p_world:update(dt)
            
            -- Movement update
            if player_control then
                player:update(dt)

                -- Holding the shoot key keeps casting, the spell cooldown sets the fire rate
                if love.keyboard.isDown(SHOOT_KEY) then
                    spellTest:shoot(player)
                end
            end

            map.enemies:update(dt)
            spells:update(dt)
            
            -- Setting the camera to the player position
            local x,y = player.body:getWorldCenter()
            game_cam:lookAt(x, y)
            
            -- Animation update
            if (player.anim.actor:GetTransformer():GetPower("player") > 0) then
                local vars = player.anim.actor:GetTransformer():GetVariables("player")
                vars.time = vars.time + dt;
            end
            player.anim.actor:Update(dt);
        end
    else
        new_frame = false
    end
    
    
    if DEBUG then
        -- Print the update fps to the console every second
        if love.timer.getTime() - fpsTimer > 1 then
            fpsTimer = love.timer.getTime()
            print("FPS: " .. love.timer.getFPS())
            print("body count: " .. p_world:getBodyCount())
        end
    end
end

function love.draw()
    if game_state == MENU_STATE then

    elseif game_state == IN_WORLD_STATE then
        -- Drawing everything in regard to the camera
        game_cam:attach()
            -- Map draws entities aswell
            map:draw() 
            spells:draw()
            
            -- if new_frame then
                player.anim.actor:Draw()
            -- end
            if not new_frame then
                new_frame = true
            end
            if DEBUG then
                -- player:debugDraw()
                local mx, my  = MAP_X * TILE_SIZE * TILES_PER_METER, MAP_Y * TILE_SIZE * TILES_PER_METER
                debugWorldDraw(p_world, -mx / 2, -my / 2, mx, my)
            end
        game_cam:detach()
        
        tooltipDraw()
        
        if DEBUG then
            debugPrint()
        end
    end
    Slab.Draw()
end

function love.keypressed(key)
    -- Escape closes the top open menu, or asks to quit when nothing is open
    if key == EXIT_KEY then
        uihandler:escape()
        return
    end

    -- Other keys do nothing while the quit confirmation is open
    if uihandler.showQuitConfirm then
        return
    end

    -- IN_WORLD State handling
    if game_state == IN_WORLD_STATE then
        -- Check pausing first
        if key == PAUSE_KEY then
            paused = not paused
            player_control = not paused
        -- Spell editor key works while paused so the editor can be closed
        elseif key == SPELL_EDITOR_KEY then
            uihandler:toggleSpellEditor()
        elseif not paused then
            -- Save and load keys
            if key == SAVE_KEY then
                saveScene("world")
            elseif key == LOAD_KEY then
                loadScene("world")
            elseif key == INTERACT_KEY then
                player:interact()
            elseif key == "y" then
                player:addStat("swiftness", -10)
            elseif key == "u" then
                player:addStat("swiftness", 10)
            -- Number keys pick a test spell
            elseif tonumber(key) ~= nil and spellPresets[tonumber(key)] ~= nil then
                spellTest = spellPresets[tonumber(key)]
            else
                uihandler:checkKeyIngame(key)
            end
        end
    end
end
