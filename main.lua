require "registry"
require "system_utils"

require "keys"
require "assets.assetLoader"
require "world_utils.world"
require "world_utils.scene"
local Slab = require "libraries.Slab"
local debugWorldDraw = require "libraries.debugWorldDraw"
local UIHandler = require "ui.uiHandler"
local Spellbooks = require "magic.spellbooks"
local new_frame = false

function love.load(args)
    -- local font = love.graphics.newFont("assets/RamadhanMubarok-Regular.otf")
    -- love.graphics.setFont(font)
    game_state = MENU_STATE
    Slab.Initialize(args)
    initVars()
    registerAll()

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
                local spell = Spellbooks.selectedSpell(player.spellbook)
                if spell ~= nil and love.keyboard.isDown(SHOOT_KEY) then
                    spell:shoot(player)
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
        uihandler:draw()    -- HP and mana bars
        
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

    -- Other keys do nothing while the quit confirmation or the pause menu is open
    if uihandler.showQuitConfirm or uihandler.showPauseMenu then
        return
    end

    -- Typing in a text box(like a spell name) shouldnt trigger game keys
    if Slab.IsAnyInputFocused() then
        return
    end

    -- The spell editor gets keys first while it is open(binding a key to a spell)
    if uihandler.spellEditor ~= nil and uihandler.spellEditor:handleKey(key) then
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
        -- Save and load the open world, saving while paused is fine
        elseif key == SAVE_KEY then
            saveScene(currentWorld)
        elseif key == LOAD_KEY then
            if hasSave(currentWorld) then
                loadScene(currentWorld)
            end
        elseif not paused then
            if key == INTERACT_KEY then
                player:interact()
            elseif key == "y" then
                player:addStat("swiftness", -10)
            elseif key == "u" then
                player:addStat("swiftness", 10)
            -- Keys bound in the spell editor pick a spell
            elseif Spellbooks.selectByKey(player.spellbook, key) then
            else
                uihandler:checkKeyIngame(key)
            end
        end
    end
end
