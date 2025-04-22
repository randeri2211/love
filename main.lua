require "system_utils"

require "entities.player"
require "keys"
require "assets.assetLoader"
require "world.world"
require "world.scene"
require "animations.animations"
require "registry"
local debugWorldDraw = require "libraries.debugWorldDraw"
local Slab = require "libraries.Slab"

local showWindow = false

function love.load(args)
    Slab.Initialize(args)
    initVars()
    registerAll()
    -- TODO: replace tempMap with a world generation sometime
    tempMap()

    spellTest = Spell:new(Bullet1, 10)

    fpsTimer = love.timer.getTime()
end

function love.update(dt)
    Slab.Update(dt)

    if game_state == IN_WORLD then
        if not paused then
            player:updateAnimation()

            -- Update physics
            manageHitbox()
            p_world:update(dt)
            
            -- Movement update
            if player_control then
                player:update(dt)
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
        else

        end
    end
    
    
    if DEBUG then
        -- Print the update fps to the console every second
        if love.timer.getTime() - fpsTimer > 1 then
            fpsTimer = love.timer.getTime()
            print("FPS: " .. love.timer.getFPS())
            print("body count: " .. p_world:getBodyCount())
        end
    end

    if showWindow then
        Slab.BeginWindow('InventoryWindow', {
            Title = "Inventory",
            AllowMove = true,
            AutoSizeWindow = false,
            W = 300,
            H = 200
        })

        Slab.Text("You have 3 potions.")
        Slab.Button("Use Potion")

        Slab.EndWindow()
    end
end

function love.draw()
    if DEBUG then
        debugPrint()
    end

    -- Drawing everything in regard to the camera
    game_cam:attach()
        -- Map draws entities aswell
        map:draw() 
        spells:draw()
        player.anim.actor:Draw()
        if DEBUG then
            -- player:debugDraw()
            local mx, my  = MAP_X * TILE_SIZE * TILES_PER_METER, MAP_Y * TILE_SIZE * TILES_PER_METER
            debugWorldDraw(p_world, -mx / 2, -my / 2, mx, my)
        end
    game_cam:detach()
    tooltipDraw()
    Slab.Draw()
end

function love.keypressed(key)
    if key == EXIT then
        love.event.quit()
    end

    -- IN_WORLD State handling
    if game_state == IN_WORLD then
        -- Check pausing first
        if key == PAUSE then 
            d = not paused
            player_control = not paused
        elseif not paused then
            -- Save and load keys
            if key == SAVE_KEY then
                saveScene()
            elseif key == LOAD_KEY then
                loadScene()
            -- Shoot key
            elseif key == SHOOT then
                spellTest:shoot(player)
            elseif key == WINDOW then
                showWindow = not showWindow
            end
        end
    end
end
