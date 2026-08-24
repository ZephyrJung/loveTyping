-- loveTyping -- A Love2D typing practice application.
-- Displays difficulty levels via a glowing menu, with Level 1 showing
-- A-Z as pulsating spheres in QWERTY layout that explode on key press.

require("shared")    -- Particle, Sphere, hslToRgb, getKeyboardLayout, state machine
require("menu")       -- states["menu"]
require("level1")     -- states["level1"]
require("level2")     -- states["level2"]
require("level3")     -- states["level3"]

love.load = function()
    love.window.setTitle("loveTyping -- Typing Practice")
    local baseFont = love.graphics.newFont(16)
    love.graphics.setFont(baseFont)
    love.window.setMode(960, 700, {fullscreen = false})
         -- Start at the menu state
    changeState("menu")
end

love.update = function(dt)
         -- Update the active state (timer-driven game logic)
    if states[currentStateName] and states[currentStateName].onUpdate then
        states[currentStateName]:onUpdate(dt)
    end

         -- Always update explosion particles (rendered on top in love.draw)
    for i = #explosionParticles, 1, -1 do
        local p = explosionParticles[i]
        p:update(dt)
        if p:isDead() then table.remove(explosionParticles, i) end
    end
end

love.draw = function()
         -- Draw the active state's visual content
    if states[currentStateName] and states[currentStateName].onDraw then
        states[currentStateName].onDraw(states[currentStateName])
    end
end

love.keyreleased = function(key)
         -- Route key events to the active state
    if states[currentStateName] and states[currentStateName].onKeyReleased then
        states[currentStateName].onKeyReleased(states[currentStateName], key)
    end
end


love.mousepressed = function(x, y, button)
           -- Forward mouse click to menu state's mouseClicked flag
    if button == 1 and currentStateName == "menu" and states["menu"] then
        states["menu"].mouseClicked = true
        states["menu"].clickX = x
        states["menu"].clickY = y
    end

        -- Level 2: click tier selector buttons (bottom-right corner)
    if button == 1 and currentStateName == "level2" and states["level2"] then
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        local bW, bH, gap = 65, 28, 8
        local bx = w - bW * 3 - gap * 2 - 20
        local by = h - 70

        for i = 1, 3 do
            local cbx = bx + (bW + gap) * (i - 1)
                -- Check click bounds
            if x >= cbx and x <= cbx + bW and y >= by and y <= by + bH then
                states["level2"].currentTier = i
                states["level2"].overflowCount = 0
            end
        end
    end
end

           -- Menu touch input for tap-to-select buttons (touchscreens)
love.touchpressed = function(x, y, touch)
    if currentStateName == "menu" and states["menu"] then
        states["menu"].mouseClicked = true
        states["menu"].clickX = x
        states["menu"].clickY = y
    end
end
