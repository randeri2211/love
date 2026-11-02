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
local Background = require "world_utils.background"
local WorldClock = require "world_utils.worldClock"
local worldCanvas = nil     -- The world is drawn here first so the time of day light can tint it(see love.draw)
local new_frame = false

function love.load(args)
    -- local font = love.graphics.newFont("assets/RamadhanMubarok-Regular.otf")
    -- love.graphics.setFont(font)
    game_state = MENU_STATE
    Slab.Initialize(args)
    registerAll()       -- Before the first world, placing the player on the ground asks the biomes
    initVars()

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
            map:update(dt)      -- Unloads chunks far from the player
            WorldClock.update(dt)
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
        -- Sky and distant hills first, they move slower than the camera
        local camX, camY = game_cam:position()
        Background.drawSky(camX, camY)

        -- The world goes on its own canvas, then onto the screen tinted by the light of the time of day
        local w, h = love.graphics.getDimensions()
        if worldCanvas == nil or worldCanvas:getWidth() ~= w or worldCanvas:getHeight() ~= h then
            worldCanvas = love.graphics.newCanvas(w, h)
        end
        love.graphics.setCanvas(worldCanvas)
        love.graphics.clear(0, 0, 0, 0)
        game_cam:attach()
            -- Rock walls behind the caves, then the blocks over them
            Background.drawWalls(camX, camY)
            -- Map draws entities aswell
            map:draw()
            player.anim.actor:Draw()
        game_cam:detach()
        love.graphics.setCanvas()
        local light = WorldClock.blend(AMBIENT_LIGHT)
        love.graphics.push("all")
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.setColor(light[1], light[2], light[3], 1)
        love.graphics.draw(worldCanvas)
        love.graphics.pop()

        -- Spells over the light, so magic glows at night
        game_cam:attach()
            spells:draw()
            if not new_frame then
                new_frame = true
            end
            if DEBUG then
                -- player:debugDraw()
                -- Physics shapes around the player(the world is infinite sideways)
                local px, py = player.body:getWorldCenter()
                debugWorldDraw(p_world, px - SCREEN_X / 2, py - SCREEN_Y / 2, SCREEN_X, SCREEN_Y)
            end
        game_cam:detach()

        tooltipDraw()
        uihandler:draw()    -- HP and mana bars
        
        if DEBUG then
            debugPrint()
        end
    end
    Slab.Draw()
    if game_state == IN_WORLD_STATE then
        uihandler:drawTop()
    end
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
        elseif key == CHARACTER_KEY then
            uihandler:toggleCharacterScreen()
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
            elseif key == SPAWN_ZOMBIE_KEY then
                local mx, my = mouseToLove()
                map.enemies:addEnemy(ENTITY_REGISTRY.Zombie:new(mx, my))
            -- Keys bound in the spell editor pick a spell
            elseif Spellbooks.selectByKey(player.spellbook, key) then
            else
                uihandler:checkKeyIngame(key)
            end
        end
    end
end
