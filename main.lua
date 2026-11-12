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
local Lighting = require "world_utils.lighting"
local Structures = require "world_utils.structures"
local Building = require "world_utils.building"
local Spawner = require "world_utils.spawner"
local PlayerCasting = require "magic.playerCasting"
local Theme = require "ui.theme"
local MenuBackdrop = require "ui.menuBackdrop"
local DevLink = require "devLink"
local ManaNetwork = require "world_utils.manaNetwork"
local Simulation = require "world_utils.simulation"
local placeTimer = 0        -- Time until the held place button places the next block
local worldCanvas = nil     -- The world is drawn here first so the light can be laid over it(see love.draw)
local new_frame = false

function love.load(args)
    love.graphics.setFont(GAME_FONT)    -- The pixel font for every text(see assets/assetLoader)
    game_state = MENU_STATE
    Slab.Initialize(args)
    Theme.apply()       -- Every Slab window in the game colors
    registerAll()       -- Before the first world, placing the player on the ground asks the biomes
    initVars()

    fpsTimer = love.timer.getTime()

    uihandler = UIHandler:new()
end

function love.update(dt)
    Slab.Update(dt)
    uihandler:update()
    DevLink.update(dt)      -- Commands from the Stream Deck plugin(see devLink)

    if game_state == IN_WORLD_STATE then
        if not paused then
            player:updateAnimation()

            -- Update physics
            manageHitbox()
            p_world:update(dt)
            
            -- Movement update
            if player_control then
                player:update(dt)
            end
            -- A dead player waits for the respawn, it cant cast or build
            if not player_control or player:isDead() then
                PlayerCasting.update(player, nil, false, dt)    -- A wind-up or a held beam stops
            end
            if player_control and not player:isDead() then

                -- The mouse acts on the world only when it isnt over a window
                local overWindow = not Slab.IsVoidHovered()
                local holdingStack = uihandler.characterScreen ~= nil and uihandler.characterScreen.held ~= nil

                -- Holding the cast button builds a cast circle and casts when it is done, over and over(see magic/playerCasting)
                -- (with a stack in the hand of the character screen the click throws it instead)
                local spell = Spellbooks.selectedSpell(player.spellbook)
                PlayerCasting.update(player, spell, love.mouse.isDown(CAST_BUTTON) and not overWindow and not holdingStack, dt)

                -- Holding the place button places the selected hotbar block under the mouse, a few a second
                placeTimer = math.max(0, placeTimer - dt)
                if love.mouse.isDown(PLACE_BUTTON) and not overWindow and placeTimer == 0 then
                    local mx, my = mouseToLove()
                    if Building.place(player, mx, my) then
                        placeTimer = PLACE_INTERVAL
                    end
                end
            end

            ManaNetwork.update(dt)      -- A full player's regen fills the batteries around them(see world_utils/manaNetwork)
            Simulation.update(dt)       -- Network chunks keep running while the player is away(see world_utils/simulation)
            map.enemies:update(dt)
            Spawner.update(dt)      -- New enemies around the player, far spawned ones go(see world_utils/spawner)
            map:update(dt)      -- Unloads chunks far from the player
            WorldClock.update(dt)
            spells:update(dt)
            
            -- Setting the camera to the player position, on whole pixels: between two pixels the pixel art tiles
            -- pick up a line of their neighbors on the tilesheet, which flickers at every tile edge while walking
            local x,y = player.body:getWorldCenter()
            game_cam:lookAt(math.floor(x + 0.5), math.floor(y + 0.5))
            
            -- Animation update
            if (player.anim.actor:GetTransformer():GetPower("player") > 0) then
                local vars = player.anim.actor:GetTransformer():GetVariables("player")
                vars.time = vars.time + dt;
            end
            player.anim.actor:Update(dt);
        end
    else
        new_frame = false
        MenuBackdrop.update(dt)
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
        DrawMenu()
    elseif game_state == PICK_WORKD_STATE then
        DrawPickWorld()
    elseif game_state == IN_WORLD_STATE then
        -- Sky and distant hills first, they move slower than the camera
        local camX, camY = game_cam:position()
        Background.drawSky(camX, camY)

        -- The world goes on its own canvas with the tile light over it(sky, torches, spells), then onto the screen
        local w, h = love.graphics.getDimensions()
        if worldCanvas == nil or worldCanvas:getWidth() ~= w or worldCanvas:getHeight() ~= h then
            worldCanvas = love.graphics.newCanvas(w, h)
        end
        love.graphics.setCanvas(worldCanvas)
        love.graphics.clear(0, 0, 0, 0)
        game_cam:attach()
            -- Rock walls behind the caves, then the blocks over them
            Background.drawWalls(camX, camY)
            Structures.drawBackWalls(camX, camY)    -- The walls inside buildings(see world_utils/structures)
            -- Map draws entities aswell
            map:draw()
            if not player:isDead() then
                player.anim.actor:Draw()
            end
            Lighting.update()
            Lighting.draw()
        game_cam:detach()
        love.graphics.setCanvas()
        love.graphics.push("all")
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(worldCanvas)
        love.graphics.pop()

        -- Spells over the light, so magic glows at night, then where the selected block would go
        game_cam:attach()
            map:drawGlow()      -- Mana in batteries and the like shines like the spells
            ManaNetwork.draw()
            if uihandler.showMap and uihandler.minimap ~= nil and uihandler.minimap.showAnchors then
                Simulation.drawOutlines()   -- The chunks the anchors keep running, while the minimap shows them
            end
            spells:draw()
            map.enemies:drawCasting()
            PlayerCasting.draw(player)
            if not paused and Slab.IsVoidHovered() then
                local mx, my = mouseToLove()
                Building.drawPreview(player, mx, my)
            end
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

function love.wheelmoved(x, y)
    -- The mouse wheel moves the hotbar selection, with shift held it moves through the spells instead
    -- Nothing while a window is open(Slab uses the wheel to scroll)
    -- Over the debug item list the wheel scrolls it
    if game_state == IN_WORLD_STATE and uihandler.itemBrowser ~= nil and uihandler.itemBrowser:wheel(y) then
        return
    end
    if game_state == IN_WORLD_STATE and not paused and uihandler.characterScreen == nil and uihandler.spellEditor == nil and y ~= 0 then
        local step = y > 0 and -1 or 1
        if love.keyboard.isDown("lshift", "rshift") then
            Spellbooks.selectStep(player.spellbook, step)
        else
            player.hotbarSlot = (player.hotbarSlot - 1 + step) % HOTBAR_SIZE + 1
        end
    elseif game_state == IN_WORLD_STATE and uihandler.characterScreen ~= nil then
        uihandler.characterScreen:wheel(y)
    elseif game_state == PICK_WORKD_STATE then
        ScrollWorlds(y)
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
        elseif key == GRIMOIRE_KEY then
            uihandler:toggleGrimoire()
        elseif key == ITEM_LIST_KEY then
            uihandler:toggleItemBrowser()
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
            -- Number keys pick a hotbar slot(0 is the tenth), with shift held they pick the spell bound to them
            elseif key:match("^%d$") then
                if love.keyboard.isDown("lshift", "rshift") then
                    Spellbooks.selectByKey(player.spellbook, key)
                else
                    player.hotbarSlot = key == "0" and 10 or tonumber(key)
                end
            elseif key == DEBUG_CASTER_KEY then
                -- A test caster at the mouse(see entities/debugCaster)
                local mx, my = mouseToLove()
                map.enemies:addEnemy(ENTITY_REGISTRY.DebugCaster:new(mx, my))
            elseif key == DEBUG_GLYPH_WALL_KEY then
                -- A glyph wall at the mouse that teaches a rune this character doesnt know yet(any rune when it knows all)
                local Knowledge = require "magic.knowledge"
                local names = {}
                for name in pairs(RUNE_REGISTRY) do
                    if not Knowledge.knows(player.knowledge, name) then
                        table.insert(names, name)
                    end
                end
                if #names == 0 then
                    for name in pairs(RUNE_REGISTRY) do
                        table.insert(names, name)
                    end
                end
                local mx, my = mouseToMap()
                local wall = map:newBlock("GlyphWall", mx, my)
                wall.rune = names[love.math.random(#names)]
                map:set(mx, my, wall)
            elseif key == DEBUG_FORGET_KEY then
                -- Back to only the starting runes, so glyph walls have something to teach
                require("magic.knowledge").forget(player.knowledge)
                uihandler:toast("Forgot every rune but " .. table.concat(STARTING_RUNES, ", "))
            elseif key == DEBUG_GIVE_KEY then
                -- Every armor piece and every wand part, to test equipment
                local Inventories = require "items.inventories"
                for name, item in pairs(ITEM_REGISTRY) do
                    if item.armor ~= nil or item.part ~= nil then
                        Inventories.add(player.inventory, name, 1)
                    end
                end
            else
                uihandler:checkKeyIngame(key)
            end
        end
    end
end
