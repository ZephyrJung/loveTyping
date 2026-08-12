-- loveTyping -- A Love2D typing practice application.
-- Displays difficulty levels via a glowing menu, with Level 1 showing
-- A-Z as pulsating spheres in QWERTY layout that explode on key press.

--------------------------------------------------------------------------------
-- Helpers: math utilities and shared constants
--------------------------------------------------------------------------------

--- Returns the absolute value of n.
local function abs(n) return n < 0 and -n or n end

--- Linear interpolation between a and b, clamping t to [0, 1].
local function lerp(a, b, t)
    return a + (b - a) * math.min(math.max(t, 0), 1)
end

--- Convert HSL hue angle (radians, 0..2pi) to RGB floats in [0, 1].
local function hslToRgb(hue)
    local sat = 0.75
    local lit = 0.55
    local cVal = (1 - abs(2 * lit - 1)) * sat
    local xVal = cVal * (1 - abs(math.fmod(hue / math.pi * 3, 2) - 1))
    local m = lit - cVal / 2
    if hue < math.pi / 3 then return cVal + m, xVal + m, m
    elseif hue < math.pi * 2 / 3 then return xVal + m, cVal + m, m
    elseif hue < math.pi then return m, cVal + m, xVal + m
    elseif hue < math.pi * 4 / 3 then return m, xVal + m, cVal + m
    elseif hue < math.pi * 5 / 3 then return xVal + m, m, cVal + m
    else return cVal + m, m, xVal + m end
end

--------------------------------------------------------------------------------
-- Particle system: explosion particles rendered on top of everything.
--------------------------------------------------------------------------------

--- A single particle in an explosion effect.
local Particle = {}
Particle.__index = Particle

function Particle:new(x, y, vx, vy, life, r, g, b, size)
    local p = setmetatable({}, self)
    p.x = x
    p.y = y
    p.vx = vx or 0
    p.vy = vy or 0
    p.life = life or 1.0
    p.maxLife = p.life
    p.r = r or 1
    p.g = g or 1
    p.b = b or 1
    p.size = size or math.random(2, 5)
    return p
end

function Particle:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.vy = self.vy + 180 * dt -- gravity pull downward
    self.life = self.life - dt
end

function Particle:draw()
    if self.life <= 0 then return end
    local alpha = math.min(self.life / self.maxLife, 1)
    love.graphics.setColor(self.r, self.g, self.b, alpha)
    love.graphics.circle("fill", self.x, self.y, self.size * alpha)
end

function Particle:isDead() return self.life <= 0 end

--- Creates a burst of explosion particles at (x, y).
local function createExplosion(x, y, r, g, b, count)
    local particles = {}
    for i = 1, (count or 40) do
        local angle = math.random() * math.pi * 2
        local speed = math.random(60, 350)
        local life = math.random(4, 12) / 10
        table.insert(particles, Particle:new(x, y,
            math.cos(angle) * speed,
            math.sin(angle) * speed - 80,
            life, r or 1, g or 1, b or 1))
    end
    return particles
end

--------------------------------------------------------------------------------
-- Sphere class: draws a letter as a glowing sphere with 3D shading.
--------------------------------------------------------------------------------

local Sphere = {}
Sphere.__index = Sphere

--- Create a new sphere displaying the given letter at screen position (x, y).
function Sphere:new(letter, x, y)
    local s = setmetatable({}, self)
    s.letter = letter
    s.x = x
    s.y = y
    s.radius = 26
    s.glowRadius = 40
    s.pulsePhase = math.random() * math.pi * 2
    s.opacity = 1
    s.scale = 1
    s.alive = true

        -- Map letter A(0)..Y(25) to RGB via HSL hue angle for unique coloring.
    local hueFrac = (string.byte(letter) - string.byte('A')) / 25
    local r, g, b = hslToRgb(hueFrac * math.pi * 2)
    s.glowColor = {r, g, b}
    return s
end

function Sphere:update(dt)
    self.pulsePhase = self.pulsePhase + dt * 2.5
end

--- Draw the sphere: outer glow, 3D gradient fill with specular highlight, and label.
function Sphere:draw()
    if not self.alive then return end
    local pulse = math.sin(self.pulsePhase) * 0.15 + 1
    local gc = self.glowColor

        -- Outer glow aura (two layers for soft falloff)
    love.graphics.setColor(gc[1] * 0.5, gc[2] * 0.5, gc[3] * 0.5, 0.10 * self.opacity)
    love.graphics.circle("fill", self.x, self.y, self.glowRadius * pulse + 18)
    love.graphics.setColor(gc[1] * 0.6, gc[2] * 0.6, gc[3] * 0.6, 0.20 * self.opacity)
    love.graphics.circle("fill", self.x, self.y, self.glowRadius * pulse)

        -- Sphere body with 3D shading (offset shadow for depth)
    local sr = self.radius * pulse
    love.graphics.setColor(0.12, 0.12, 0.22, self.opacity)
    love.graphics.circle("fill", self.x + 3, self.y + 3, sr)

        -- Main fill (lighter top-left for gradient feel)
    local bright = self.glowColor[1] * 0.4 + 0.15
    local bgCol = self.glowColor[2] * 0.4 + 0.15
    local bb = self.glowColor[3] * 0.4 + 0.15
    love.graphics.setColor(bright, bgCol, bb, self.opacity)
    love.graphics.circle("fill", self.x - sr * 0.12, self.y - sr * 0.15, sr * 0.92)

        -- Specular highlight dot (top-left of sphere)
    local hlR = sr * 0.35
    love.graphics.setColor(1, 1, 1, 0.45 * self.opacity)
    love.graphics.circle("fill", self.x - sr * 0.28, self.y - sr * 0.32, hlR)

        -- Colored border ring
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(gc[1] * 0.7, gc[2] * 0.7, gc[3] * 0.7, 0.50 * self.opacity)
    -- circle outline for sphere border effect (supported in LOVE 11+)
    love.graphics.setLineWidth(2.5)
    love.graphics.circle("line", self.x, self.y, sr - 1)
    love.graphics.setLineWidth(1)

        -- Letter label with drop shadow for readability
    local fontSize = math.floor(sr * 1.0)
    local font = love.graphics.newFont(fontSize)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, self.opacity * 0.45)
    love.graphics.printf(self.letter, self.x - sr, self.y - fontSize * 0.35,
                         sr * 2, "center", 0, 1, 1)
    love.graphics.setColor(1, 1, 1, self.opacity)
    love.graphics.printf(self.letter, self.x - sr + 1, self.y - fontSize * 0.35 + 1,
                         sr * 2, "center", 0, 1, 1)
end

--------------------------------------------------------------------------------
-- Keyboard layout: letters in QWERTY order with slight arc curve.
-- Returns table of {letter, x, y} where x/y are absolute screen positions.
--------------------------------------------------------------------------------

local function getKeyboardLayout(cx, cy)
    local layout = {}
    local rows = {
            {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
            {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
            {"Z", "X", "C", "V", "B", "N", "M"}
       }
    local spacingY = 90

    for i, row in ipairs(rows) do
        local rowsY = cy + (i - 1) * spacingY - 90
        local colsInRow = #row
        for j, letter in ipairs(row) do
                -- Distribute evenly with slight inward arc at edges
            local colX = cx + (j - (colsInRow + 1) / 2) * 64
            local arcAmt = math.abs(j - (colsInRow + 1) / 2)
                    / ((colsInRow + 1) / 2)
            colX = colX - arcAmt * 6

            table.insert(layout, {letter = letter, x = colX, y = rowsY})
        end
    end
    return layout
end

--------------------------------------------------------------------------------
-- State machine: manages transitions between game screens.
--------------------------------------------------------------------------------

local states = {} -- name -> state object with update/draw methods
local currentStateName = nil

--- Switch to a named state; calls onExit of old and onEnter of new.
local function changeState(name)
    if states[currentStateName] and states[currentStateName].onExit then
        states[currentStateName]:onExit()
    end
    currentStateName = name
    if states[name] and states[name].onEnter then
        states[name]:onEnter()
    end
end

--------------------------------------------------------------------------------
-- Global particle pool: updated each frame, drawn on top of everything.
--------------------------------------------------------------------------------

local explosionParticles = {}

--- Add a batch of particles to the global pool.
local function addExplosion(x, y, r, g, b, count)
    for _, p in ipairs(createExplosion(x, y, r, g, b, count)) do
        table.insert(explosionParticles, p)
    end
end

--------------------------------------------------------------------------------
-- MENU STATE: glowing buttons for each difficulty level.
--------------------------------------------------------------------------------

states["menu"] = {
    flashAlpha = 0,
    hoverIdx = -1, -- track which button is hovered (for keyboard nav)
    mouseClicked = false, -- flag set by love.mousepressed

    onEnter = function(self)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        self.buttons = {}
        local bw, bh = math.min(w * 0.45, 300), 68
        local startY = 280
            -- Build button rects for each level
        for i = 1, 3 do
            table.insert(self.buttons, {x = (w - bw) / 2, y = startY + (i - 1) * (bh + 36),
                                          w = bw, h = bh, id = i})
        end
    end,

    onUpdate = function(self, dt)

            -- Mouse hover detection on buttons
        local mx, my = love.mouse.getPosition()
        self.hoverIdx = -1
        for i, btn in ipairs(self.buttons) do
            if (mx >= btn.x and mx <= btn.x + btn.w and
                my >= btn.y and my <= btn.y + btn.h) then
                self.hoverIdx = i
            end
        end

            -- Handle mouse click on buttons (use our clicked flag for LÖVE 11 compatibility)
        if self.mouseClicked then
            self.mouseClicked = false -- reset the flag
            local mmx, mmy = love.mouse.getPosition()
            for i, btn in ipairs(self.buttons) do
                if (mmx >= btn.x and mmx <= btn.x + btn.w and
                    mmy >= btn.y and mmy <= btn.y + btn.h) then
                    changeState("level" .. tostring(btn.id))
                    return
                end
            end
        end

            -- Keyboard navigation for buttons (1/2/3 keys)
        if love.keyboard.isDown("1") or love.keyboard.isDown("2")
             or love.keyboard.isDown("3") then
            local key = nil
            if love.keyboard.isDown("1") then key = 1
            elseif love.keyboard.isDown("2") then key = 2
            else key = 3 end
            changeState("level" .. tostring(key))
        end
    end,

    onDraw = function(self)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

            -- Background gradient (dark blue-purple)
        for y = 1, h do
            local t = y / h
            love.graphics.setColor(lerp(0.03, 0.06, t),
                                   lerp(0.04, 0.05, t),
                                   lerp(0.10, 0.18, t))
            love.graphics.rectangle("fill", 0, y, w, 1)
        end

            -- Title: "loveTyping" in large white text
        local titleFont = love.graphics.newFont(48)
        love.graphics.setFont(titleFont)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("loveTyping", w / 2, 80, w * 0.7, "center")

            -- Subtitle
        local subFont = love.graphics.newFont(14)
        love.graphics.setFont(subFont)
        love.graphics.setColor(0.50, 0.65, 0.85, 0.7)
        love.graphics.printf("Select Difficulty Level", w / 2, 140, w * 0.5, "center")

            -- Draw level buttons with glow on hover
        for i, btn in ipairs(self.buttons) do
            local id = btn.id
            local names = {"Intro", "Words", "Timed"}
            local descs = {"A-Z letters as glowing spheres",
                           "Type words as prompted",
                           "Beat the clock challenge"}
            local c = (self.hoverIdx == i) and {0.3, 0.4, 0.7} or {0.12, 0.16, 0.30}

                -- Glow effect on hover
            if self.hoverIdx == i then
                love.graphics.setColor(c[1] * 1.8, c[2] * 1.8, c[3] * 1.8, 0.20)
                love.graphics.rectangle("fill", btn.x - 4, btn.y - 4,
                                         btn.w + 8, btn.h + 8, 14)
            end

                -- Button background
            love.graphics.setColor(c[1], c[2], c[3], 0.95)
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 10)

                -- Button border (brighter on hover)
            love.graphics.setLineWidth(2)
            local bc = (self.hoverIdx == i) and {0.6, 0.8, 1} or {0.35, 0.45, 0.65}
            love.graphics.setColor(bc[1], bc[2], bc[3])
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 10)
            love.graphics.setLineWidth(1)

                -- Button text (level name + number hint)
            local txtFont = love.graphics.newFont(20)
            love.graphics.setFont(txtFont)
            local tc = (self.hoverIdx == i) and {1, 1, 1} or {0.80, 0.82, 0.90}
            love.graphics.setColor(tc[1], tc[2], tc[3])
            love.graphics.printf(names[id] .. "   [1-" .. tostring(id) .. "]",
                                 btn.x + btn.w / 2, btn.y + btn.h / 2 - 4,
                                 btn.w - 20, "center")

                -- Description below button
            local descFont = love.graphics.newFont(12)
            love.graphics.setFont(descFont)
            love.graphics.setColor(0.45, 0.50, 0.60, 0.70)
            love.graphics.printf(descs[id], w / 2, btn.y + btn.h + 8,
                                 btn.w, "center")
        end

            -- Footer hint with keyboard shortcut
        local hintFont = love.graphics.newFont(13)
        love.graphics.setFont(hintFont)
        love.graphics.setColor(0.35, 0.40, 0.50, 0.55)
        love.graphics.printf("Press [1] [2] or [3] to quick-select", w / 2, h - 38, w * 0.45, "center")
    end,

    onKeyReleased = function() end, -- menu ignores key input here
}

--------------------------------------------------------------------------------
-- LEVEL 1: INTRO -- A-Z spheres in QWERTY layout, explode on press.
--------------------------------------------------------------------------------

states["level1"] = {
    flashAlpha = 0,
    instructionsTimer = 5,
    showInstructions = true,
    scoredLetters = {}, -- tracks exploded letters: {"A": timer}
    totalExplosions = 0,
    hintTimer = 3,      -- display "press Esc" hint after all letters done
    restartHint = false,

    onEnter = function(self)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
            -- Get sphere positions for keyboard layout (centered on screen)
        self.layout = getKeyboardLayout(w / 2, h / 2 + 10)

            -- Create a sphere at each position
        self.spheres = {}
        for _, entry in ipairs(self.layout) do
            table.insert(self.spheres, Sphere:new(entry.letter, entry.x, entry.y))
        end
    end,

    onUpdate = function(self, dt)
            -- Instructions fade out after ~5 seconds
        self.instructionsTimer = self.instructionsTimer - dt
        if self.instructionsTimer <= 0 then
            self.showInstructions = false
        end

            -- Update all spheres for pulsing glow animation
        for _, s in ipairs(self.spheres) do
            s:update(dt)
                -- Fade out exploded spheres
            if self.scoredLetters[s.letter] then
                self.scoredLetters[s.letter] = self.scoredLetters[s.letter] + dt
            end
        end

            -- Show restart hint after all letters are done
        local allDone = true
        for _, s in ipairs(self.spheres) do
            if not self.scoredLetters[s.letter] then allDone = false; break end
        end
        if allDone and not self.restartHint then
            self.hintTimer = 5 -- show "press any key" hint
            self.restartHint = true
        end

            -- Check for any-letter press to restart level
        if self.restartHint and self.hintTimer > 0 then
            -- Any key restarts (handled via a small delay)
        end
    end,

    onDraw = function(self)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

            -- Background gradient (dark blue-purple)
        for y = 1, h do
            local t = y / h
            love.graphics.setColor(lerp(0.03, 0.05, t),
                                   lerp(0.04, 0.06, t),
                                   lerp(0.08, 0.12, t))
            love.graphics.rectangle("fill", 0, y, w, 1)
        end

            -- Title bar
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(0.35, 0.42, 0.55, 0.6)
        love.graphics.printf("Level 1 -- Intro     Press Esc to go back",
                             w / 2, 28, w * 0.9, "center")

            -- Instructions overlay (fades out after ~5s)
        if self.showInstructions then
            local instrAlpha = math.min(self.instructionsTimer / 1.5, 1)
            love.graphics.setFont(love.graphics.newFont(20))
            love.graphics.setColor(0.60, 0.75, 0.90, instrAlpha * 0.85)
            love.graphics.printf("Press the keyboard letters to explode the spheres!",
                                 w / 2, 55, w * 0.85, "center")
        end

            -- Draw all spheres at their layout positions (with fade-out for exploded ones)
        for _, s in ipairs(self.spheres) do
            if self.scoredLetters[s.letter] then
                local elapsed = math.min(self.scoredLetters[s.letter], 1.0)
                s.opacity = lerp(0.15, 1, 1 - elapsed)
                s.scale = lerp(0.4, 1, 1 - elapsed)
            else
                s.opacity = 1
                s.scale = 1
            end
            s:draw()
        end

            -- Stats display: count of remaining vs total letters
        local allDone = true
        local remaining = 0
        for _, s in ipairs(self.spheres) do
            if not self.scoredLetters[s.letter] then
                remaining = remaining + 1
                allDone = false
            end
        end

        if allDone and self.hintTimer > 0 then
                -- All letters exploded: show restart hint
            local hintAlpha = math.sin(love.timer.getTime() * 3) * 0.25 + 0.45
            love.graphics.setFont(love.graphics.newFont(18))
            love.graphics.setColor(0.50, 0.65, 0.80, hintAlpha)
            love.graphics.printf("Press any key to restart the level", w / 2, h - 35, w * 0.5, "center")
            self.hintTimer = self.hintTimer - (love.timer.getDelta() or 0.016)
        elseif self.totalExplosions > 0 then
                -- Show progress counter
            love.graphics.setFont(love.graphics.newFont(16))
            love.graphics.setColor(0.45, 0.60, 0.80, 0.70)
            love.graphics.printf(
                  "Exploded: " .. self.totalExplosions .. "/" .. #self.spheres
                      .. "     |   Remaining: " .. remaining,
                w / 2, h - 35, w * 0.80, "center")
        end

            -- Draw explosion particles on top of spheres
        for _, p in ipairs(explosionParticles) do
            p:draw()
        end
    end,

    onKeyReleased = function(self, key)
            -- Esc goes back to menu
        if key == "escape" then
            changeState("menu")
            return
        end

            -- Restart hint: any key restarts the level when all done
        if self.restartHint and self.hintTimer > 0 then
            self.totalExplosions = 0
            self.scoredLetters = {}
            self.restartHint = false
            self.showInstructions = true
            self.instructionsTimer = 5
                -- Refire onEnter to recreate spheres
            local w, h = love.graphics.getWidth(), love.graphics.getHeight()
            self.layout = getKeyboardLayout(w / 2, h / 2 + 10)
            self.spheres = {}
            for _, entry in ipairs(self.layout) do
                table.insert(self.spheres, Sphere:new(entry.letter, entry.x, entry.y))
            end
            return
        end

            -- Only respond to single letter keys (A-Z / a-z)
        if not key:match("^%a$") then return end

        local upperKey = string.upper(key)

            -- Check if this letter hasn't been exploded yet
        if self.scoredLetters[upperKey] then return end

            -- Find the sphere matching this letter and explode it
        for _, s in ipairs(self.spheres) do
            if s.letter == upperKey then
                    -- Explosion at the sphere's exact screen position (NOT double-centered!)
                addExplosion(s.x, s.y, 1, 0.7, 0.4, 50)

                    -- Mark as exploded (will fade out over ~1 second)
                self.scoredLetters[upperKey] = 0
                self.totalExplosions = self.totalExplosions + 1
                    -- Exit immediately: only one sphere per keypress
                return
            end
        end
    end,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- LEVEL 2: FALLING SPHERES -- Three-tier progressive speed!
-- Spheres fall from top. Type letters before they overflow past ground line.
-- < 5 on screen for ~6s clean play --> prompt to advance tier.
--------------------------------------------------------------------------------

states["level2"] = {
    currentTier = 1,                -- 1=slow (default), 2=medium, 3=fast
    gameTime = 0,
    spawnTimer = 0.5,
    flashAlpha = 0,                           -- screen flash on hit
    score = 0,
    fallingSpheres = {},                -- active falling spheres
    overflowCount = 0,              -- spheres that fell past ground line

    onUpdate = function(self, dt)
        self.gameTime = self.gameTime + dt

          --- Tier config table: {spawnInterval, gravity}
        local tiers = {{1.5, 40}, {0.8, 65}, {0.35, 95}}
        local tierConf = tiers[self.currentTier]
        local spawnInt = tierConf[1]
        local grav = tierConf[2]

          --- Spawn logic per tier
        self.spawnTimer = self.spawnTimer - dt
        if self.spawnTimer <= 0 then
            local w = love.graphics.getWidth()
            local letterIdx = math.random(26)
            local letter = string.char(letterIdx + 64) -- A-Z
            local sx = math.random(80, w - 80)
            local speed = (math.random() * 60 + 20)

              --- Create sphere at top of screen
            local s = Sphere:new(letter, sx, -40)
            s.vy = speed             -- store initial velocity for gravity calc
            table.insert(self.fallingSpheres, s)

              --- Reset timer with slight randomness
            self.spawnTimer = spawnInt + math.random(-150, 150) / 1000
        end

          --- Update all falling spheres (gravity + pulse)
        local gravity = grav         -- gravity per tier: 40 / 65 / 95
        for i = #self.fallingSpheres, 1, -1 do
            local s = self.fallingSpheres[i]
            s:update(dt)

              --- Apply gravity to vertical velocity
            s.vy = (s.vy or 30) + gravity * dt
            s.y = s.y + s.vy * dt

              --- Check if fallen past the ground line
            local h = love.graphics.getHeight()
            local groundY = h - 120

            if s.y > groundY then
                  -- Sphere overflowed! Increment overflow counter
                self.overflowCount = self.overflowCount + 1
                table.remove(self.fallingSpheres, i)
            end
        end

      -- Safe window tracking removed; tier is fully user-controlled via bottom-right buttons.

          --- Flash fade decay (subtle green flash on hit only)
        self.flashAlpha = math.max(0, self.flashAlpha - dt * 3)
    end,

    onDraw = function(self)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

          --- Background gradient (dark blue-purple, subtle teal accent)
        for y = 1, h do
            local t = y / h
            love.graphics.setColor(lerp(0.03, 0.06, t),
                                   lerp(0.04, 0.07, t),
                                   lerp(0.10, 0.20, t))
            love.graphics.rectangle("fill", 0, y, w, 1)
        end

          --- Draw ground line
        local groundY = h - 120
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.35, 0.45, 0.60, 0.30)
        love.graphics.line(0, groundY, w, groundY)
        love.graphics.setLineWidth(1)

          --- Draw falling spheres
        for _, s in ipairs(self.fallingSpheres) do
            s:draw()
        end

          --- Title bar with tier info
        local tierNames = {"Slow", "Medium", "Fast"}
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(0.35, 0.42, 0.55, 0.6)
        love.graphics.printf("Level 2 -- Falling Letters    (" .. tierNames[self.currentTier] .. ")", w / 2, 28, w * 0.7, "center")

          --- Score display (subtle green)
        local scoreAlpha = math.min(1, self.gameTime * 0.5)
        if self.score > 0 or scoreAlpha >= 1 then
            love.graphics.setFont(love.graphics.newFont(16))
            love.graphics.setColor(0.35, 0.65, 0.40, math.min(1, self.gameTime * 0.5))
            love.graphics.printf("Score: " .. self.score, w / 2 - 60, 48, 120, "center")
        end

          --- Speed indicator bar (no flash, just progress within tier)
        local speedPercent = math.min(100, math.floor((self.gameTime % 30) / 30 * 100))
        love.graphics.setFont(love.graphics.newFont(13))
        love.graphics.setColor(0.30, 0.35, 0.42, 0.50)
        local barW = w * 0.3
        love.graphics.rectangle("fill", w / 2 - barW / 2, h - 60, barW, 8)
        if speedPercent > 0 then
            local tc = {{0.4, 0.85, 0.35}, {0.85, 0.7, 0.35}, {0.85, 0.35, 0.25}}
            love.graphics.setColor(tc[self.currentTier][1], tc[self.currentTier][2], tc[self.currentTier][3], 0.7)
            love.graphics.rectangle("fill", w / 2 - barW / 2, h - 60, barW * (speedPercent / 100), 8)
        end
        love.graphics.setColor(0.30, 0.35, 0.42, 0.50)
        love.graphics.rectangle("line", w / 2 - barW / 2, h - 60, barW, 8)
        love.graphics.printf("Tier: " .. math.min(3, self.currentTier) .. "/3", w / 2, h - 40, w * 0.5, "center")



          --- Tier selector buttons (bottom-right)
        local btnH = 28
        local btnW = 65
        local btnGap = 8
        local btnX = w - btnW * 3 - btnGap * 2 - 20
        local btnY = h - 70

        for i = 1, 3 do
            local bx = btnX + (btnW + btnGap) * (i - 1)
            local by = btnY
            local isActive = (self.currentTier == i)

              -- Button background (highlighted if active)
            local actColors = {{0.2, 0.5, 0.3}, {0.6, 0.4, 0.1}, {0.6, 0.15, 0.15}}
            local stdColor = {0.12, 0.16, 0.28}
            local col = isActive and actColors[i] or stdColor
            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.rectangle("fill", bx, by, btnW, btnH, 6)

              -- Button border
            if isActive then
                love.graphics.setColor(0.5, 0.7, 0.4)
            else
                love.graphics.setColor(0.25, 0.3, 0.4)
            end
            love.graphics.setLineWidth(isActive and 2 or 1)
            love.graphics.rectangle("line", bx, by, btnW, btnH, 6)
            love.graphics.setLineWidth(1)

              -- Button text
            love.graphics.setFont(love.graphics.newFont(13))
            if isActive then
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0.65, 0.7, 0.8)
            end
            love.graphics.printf(tierNames[i], bx + btnW / 2, by + btnH / 2 - 4,
                                 btnW - 8, "center")
        end

          --- Esc hint (always visible at bottom)
        love.graphics.setFont(love.graphics.newFont(13))
        love.graphics.setColor(0.30, 0.35, 0.42, 0.50)
        love.graphics.printf("Press Esc to go back", w / 2, h - 15, w * 0.6, "center")

          --- Draw explosion particles on top of everything
        for _, p in ipairs(explosionParticles) do
            p:draw()
        end
    end,

    onKeyReleased = function(self, key)
          --- Esc goes back to menu
        if key == "escape" then
            changeState("menu")
            return
        end

          --- Only respond to single letter keys (A-Z / a-z)
        if not key:match("^%a$") then return end

        local upperKey = string.upper(key)

          --- Find matching falling sphere closest to the bottom (most urgent)
        local bestIdx = nil
        local bestY = -9999

        for i = 1, #self.fallingSpheres do
            local s = self.fallingSpheres[i]
            if s.letter == upperKey and s.y > bestY then
                bestIdx = i
                bestY = s.y
            end
        end

          --- If no falling sphere matches, try overflow pile (destroy one)
        if not bestIdx then
            if self.overflowCount > 0 then
                  -- Reduce overflow count (gives player a chance)
                self.overflowCount = math.max(0, self.overflowCount - 1)
            end
            return
        end

          --- Found it! Explosion!
        local target = self.fallingSpheres[bestIdx]
        addExplosion(target.x, target.y, 1, 0.7, 0.4, 50)

          --- Remove from falling spheres
        table.remove(self.fallingSpheres, bestIdx)

          --- Score increases more for harder-to-reach (lower) spheres
        local h = love.graphics.getHeight()
        local groundY = h - 120
        local difficulty = math.max(1, (groundY + 200 - target.y) / (h * 0.4))
        self.score = self.score + math.floor(difficulty + 0.5)

          --- Brief green flash on successful hit (subtle, max 8% alpha)
        self.flashAlpha = 0.08
    end,
}



states["level3"] = {
    monsters = {},
    fallingLetters = {},            -- floating letters on screen
    typedStr = "",
    kills = 0,
    spawnTimer = 1.2,
    letterSpawnTimer = 0.8,
    laserTimer = 0,
    gameOver = false,
    gameTime = 0,
    flashAlpha = 0,

    charPool = "abcdefghijklmnopqrstuvwxyz0123456789",

    getMonStringLen = function(self)
        local tier = math.floor(self.kills / 10) + 1
        if tier == 1 then return 2 end
        if tier == 2 then return 3 end
        return math.min(7, 4 + (tier - 3))
    end,

    makeMonString = function(self, length)
        local str = ""
        for i = 1, length do
            local ci = math.random(#self.charPool)
            str = str .. self.charPool:sub(ci, ci)
        end
        return str
    end,

    onEnter = function(self)
        self.monsters = {}
        self.fallingLetters = {}
        self.typedStr = ""
        self.kills = 0
        self.spawnTimer = 1.2
        self.letterSpawnTimer = 0.8
        self.laserTimer = 0
        self.gameOver = false
        self.gameTime = 0
    end,

    onUpdate = function(self, dt)
        if self.gameOver then return end
        self.gameTime = self.gameTime + dt

        --- Monster spawn logic
        local spawnRate = math.max(0.4, 1.5 - self.kills * 0.03)
        self.spawnTimer = self.spawnTimer - dt
        if self.spawnTimer <= 0 then
            local w = love.graphics.getWidth()
            local targetLen = self:getMonStringLen()
            for attempts = 1, 3 do
                local monStr = self:makeMonString(targetLen)
                local margin = 90
                local mx = math.random(margin, w - margin)
                local my = math.random(60, love.graphics.getHeight() - 200)
                local overlaps = false
                for _, m in ipairs(self.monsters) do
                    if m.alive then
                        local dx = m.x - mx
                        local dy = m.y - my
                        if dx * dx + dy * dy < 144 * 144 then
                            overlaps = true
                            break
                        end
                    end
                end
                if not overlaps then
                    table.insert(self.monsters, {
                        str = monStr, x = mx, y = my,
                        radius = 32, hue = math.random(0, 360),
                        alive = true, hp = (targetLen > 4 and 2 or 1),
                    })
                    break
                end
            end
            self.spawnTimer = spawnRate + math.random(-100, 100) / 1000
        end

        --- Letter spawn logic
        self.letterSpawnTimer = self.letterSpawnTimer - dt
        if self.letterSpawnTimer <= 0 then
            local w = love.graphics.getWidth()
            local margin = 60
            local lx = math.random(margin, w - margin)
             -- A-Z + a-z pool
            local pool = "abcdefghijklmnopqrstuvwxyz"
            local lc = pool:sub(math.random(1, #pool), math.random(1, #pool))
            table.insert(self.fallingLetters, {
                x = lx, y = -20, speed = 35 + math.random(25),
                hue = math.random(0, 360), radius = 18, letter = string.upper(lc),
            })
            if #self.fallingLetters > 20 then
                table.remove(self.fallingLetters, 1)
            end
            self.letterSpawnTimer = math.max(0.3, 1.0 - self.kills * 0.008) + math.random(-80, 80) / 1000
        end

        --- Monster update (gravity + ground check)
        local gravity = {0, 8, 16, 28}
        local g = gravity[math.min(4, math.floor(self.kills / 10) + 1)] or 0
        for i = #self.monsters, 1, -1 do
            local m = self.monsters[i]
            if m.alive then
                m.vy = (m.vy or 20) + g * dt
                m.y = m.y + m.vy * dt
                local groundY = love.graphics.getHeight() - 150
                if m.y > groundY then
                    self.monsters[i] = nil
                    if #self.monsters < 3 then
                        self.gameOver = true
                    end
                end
            end
        end

        --- Letter update (falling + screen bounds)
        for i = #self.fallingLetters, 1, -1 do
            local fl = self.fallingLetters[i]
            fl.y = fl.y + fl.speed * dt
            if fl.y > love.graphics.getHeight() + 30 then
                table.remove(self.fallingLetters, i)
            end
        end

        self.laserTimer = math.max(0, self.laserTimer - dt)
    end,

    onDraw = function(self)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

        --- Background gradient (dark blue-black with green tint)
        for y = 1, h do
            local t = y / h
            love.graphics.setColor(lerp(0.02, 0.04, t), lerp(0.03, 0.06, t), lerp(0.08, 0.12, t))
            love.graphics.rectangle("fill", 0, y, w, 1)
        end

        --- Ground line
        local groundY = h - 150
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.30, 0.40, 0.50, 0.35)
        love.graphics.line(0, groundY, w, groundY)
        love.graphics.setLineWidth(1)

        --- Draw falling letters first (behind monsters)
        for _, fl in ipairs(self.fallingLetters) do
            local r, g_c, b = hslToRgb(fl.hue)
            local bobPhase = math.sin(self.gameTime * 3 + fl.x * 0.1) * 4
            local fr = fl.radius + bobPhase

                -- Outer glow
            love.graphics.setColor(r * 0.5, g_c * 0.5, b * 0.5, 0.15)
            love.graphics.circle("fill", fl.x, fl.y, fr + 12)
            love.graphics.setColor(r * 0.6, g_c * 0.6, b * 0.6, 0.22)
            love.graphics.circle("fill", fl.x, fl.y, fr + 6)

                -- Main body
            love.graphics.setLineWidth(1)
            local darkR = r * 0.15 + 0.08
            local darkG = g_c * 0.15 + 0.08
            local darkB = b * 0.15 + 0.12
            love.graphics.setColor(darkR, darkG, darkB, 0.95)
            love.graphics.circle("fill", fl.x + 2, fl.y + 3, fr)
            local midR = r * 0.35 + 0.18
            local midG = g_c * 0.35 + 0.18
            local midB = b * 0.35 + 0.22
            love.graphics.setColor(midR, midG, midB, 0.9)
            love.graphics.circle("fill", fl.x - fr * 0.12, fl.y - fr * 0.12, fr * 0.88)

                -- Letter text on sphere
            local fontSize = math.max(8, math.floor(fr * 0.8))
            love.graphics.setFont(love.graphics.newFont(fontSize))
            love.graphics.setColor(0.95, 0.90, 0.75, 1)
            love.graphics.printf(fl.letter, fl.x, fl.y + fr + 4, fr * 2, "center")
        end

            --- Monster drawing (detailed sprites with text labels)
        for _, m in ipairs(self.monsters) do
            if not m.alive then goto continue_monster end

             local r, g_c, b = hslToRgb(m.hue)
            local mr = m.radius + math.sin(self.gameTime * 2.5 + m.x * 0.1) * 3

             -- Outer glow aura (two layers for soft falloff)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(r * 0.5, g_c * 0.5, b * 0.5, 0.15)
            love.graphics.circle("fill", m.x, m.y, mr + 14)
            love.graphics.setColor(r * 0.6, g_c * 0.6, b * 0.6, 0.22)
            love.graphics.circle("fill", m.x, m.y, mr + 8)

             -- Shadow / gradient body (bottom-left darker for 3D effect)
            local darkR = r * 0.12 + 0.06
            local darkG = g_c * 0.12 + 0.06
            local darkB = b * 0.12 + 0.10
            love.graphics.setColor(darkR, darkG, darkB, 0.95)
            love.graphics.circle("fill", m.x + 3, m.y + 4, mr)

             -- Main body gradient (lighter top-left for shading)
            local midR = r * 0.32 + 0.16
            local midG = g_c * 0.32 + 0.16
            local midB = b * 0.32 + 0.20
            love.graphics.setColor(midR, midG, midB, 0.9)
            love.graphics.circle("fill", m.x - mr * 0.12, m.y - mr * 0.15, mr * 0.85)

             -- Monster HEAD: horn bumps on top
            local hornH = mr * 0.30
            love.graphics.setColor(midR * 0.7, midG * 0.7, midB * 0.7, 0.95)
            love.graphics.circle("fill", m.x - mr * 0.28, m.y - mr * 0.68, hornH * 0.55)
            love.graphics.circle("fill", m.x + mr * 0.28, m.y - mr * 0.68, hornH * 0.55)

             -- MONSTER WINGS: curved shapes extending outward
            local wingSpread = mr * 1.3
            love.graphics.setLineWidth(1)
                -- Left wing
            love.graphics.setColor(midR * 0.5, midG * 0.5, midB * 0.5, 0.45)
            love.graphics.circle("fill", m.x - wingSpread * 0.55, m.y - mr * 0.1, wingSpread * 0.32, 8)
            love.graphics.setColor(midR * 0.4, midG * 0.4, midB * 0.4, 0.40)
            love.graphics.circle("fill", m.x - wingSpread * 0.3, m.y + mr * 0.15, wingSpread * 0.28, 8)
                -- Right wing
            love.graphics.setColor(midR * 0.5, midG * 0.5, midB * 0.5, 0.45)
            love.graphics.circle("fill", m.x + wingSpread * 0.55, m.y - mr * 0.1, wingSpread * 0.32, 8)
            love.graphics.setColor(midR * 0.4, midG * 0.4, midB * 0.4, 0.40)
            love.graphics.circle("fill", m.x + wingSpread * 0.3, m.y + mr * 0.15, wingSpread * 0.28, 8)

             -- EYES: two circles with pupils looking slightly down (scary look)
            local eyeY = m.y - mr * 0.18
            local eyeSpread = mr * 0.30
            local pupilOffX = 2
            local pupilOffY = 2
            love.graphics.setLineWidth(1)

                -- Left eye white + outline + red pupil
            love.graphics.setColor(0.92, 0.92, 0.95, 0.95)
            love.graphics.circle("fill", m.x - eyeSpread, eyeY, mr * 0.20)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(midR, midG, midB, 0.7)
            love.graphics.circle("line", m.x - eyeSpread, eyeY, mr * 0.20)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.75, 0.12, 0.12, 0.95)
            love.graphics.circle("fill", m.x - eyeSpread + pupilOffX, eyeY + pupilOffY, mr * 0.10)

                 -- Right eye white + outline + red pupil
            love.graphics.setColor(0.92, 0.92, 0.95, 0.95)
            love.graphics.circle("fill", m.x + eyeSpread, eyeY, mr * 0.20)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(midR, midG, midB, 0.7)
            love.graphics.circle("line", m.x + eyeSpread, eyeY, mr * 0.20)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.75, 0.12, 0.12, 0.95)
            love.graphics.circle("fill", m.x + eyeSpread + pupilOffX, eyeY + pupilOffY, mr * 0.10)

             -- TEETH / JAW: jagged mouth with sharp triangle teeth at bottom of body
            local jawY = m.y + mr * 0.38
            local jawW = mr * 0.65
            love.graphics.setLineWidth(1)
            for ti = 0, 4 do
                local tx = m.x - jawW + (ti + 0.5) * (jawW * 2 / 5)
                local isUp = (ti % 2 == 0)
                local tyTop = isUp and jawY or (jawY + mr * 0.30)
                local tyBot = isUp and (jawY - mr * 0.18) or jawY
                love.graphics.setColor(isUp and 0.85 or darkR,
                                       isUp and 0.85 or darkG,
                                       isUp and 0.85 or darkB, 0.92)
                love.graphics.polygon("fill",
                    tx - jawW / (5 * 2), tyBot,
                    tx, tyTop,
                    tx + jawW / (5 * 2), tyBot)
            end

             -- BODY BORDER: colored outline ring (keeping original feel)
            love.graphics.setLineWidth(2.5)
            love.graphics.setColor(r * 0.60, g_c * 0.60, b * 0.60, 0.50)
            love.graphics.circle("line", m.x, m.y, mr - 1)
            love.graphics.setLineWidth(1)

             -- HP indicator for hard-tier monsters
            if m.hp and m.hp > 1 then
                love.graphics.setFont(love.graphics.newFont(9))
                love.graphics.setColor(r, g_c, b, 0.85)
                local hpText = "HP:" .. m.hp
                love.graphics.printf(hpText, m.x, m.y + mr + 6, mr * 1.2, "center")
            end

             -- STRING LABEL on monster (displayed below body)
            local fontSize = math.max(8, math.floor(mr * 0.65))
            love.graphics.setFont(love.graphics.newFont(fontSize))
            local monStrWidth = m.str:len() * (fontSize * 0.6)
            local offsetX = -monStrWidth / 2
            for ci = 1, #m.str do
                local ch = m.str:sub(ci, ci)
                love.graphics.setColor(0.85, 0.80, 0.95, 0.95)
                love.graphics.printf(ch, m.x + offsetX + ci * (fontSize * 0.6),
                                     m.y + mr + 24, 0, "center")
            end

        ::continue_monster::
        end

            --- TURRET: detailed cannon with base, barrel, and dome top
        local turretX = w / 2
        local tBaseY = groundY - 4
        local barrelLen = 48
        local barrelAngle = math.pi * 0.35    -- default angle

            -- Find nearest alive monster for barrel aim direction
        local nearestMonX = turretX
        for _, m in ipairs(self.monsters) do
            if m.alive then
                nearestMonX = m.x
                break
            end
        end
           -- Calculate barrel angle based on nearest monster position
        local dy = 0
        for _, m in ipairs(self.monsters) do
            if m.alive then
                dy = groundY - 100 - m.y
                break
            end
        end

            -- TURRET BASE: trapezoidal shape sitting on ground (wider at bottom)
        local baseTopW, baseBotW, baseH = 28, 45, 30
        love.graphics.setLineWidth(1)
           -- Base body gradient (metallic green-gray)
        love.graphics.setColor(0.12, 0.22, 0.28, 0.95)
        love.graphics.polygon("fill",
            turretX - baseBotW, tBaseY,
            turretX + baseBotW, tBaseY,
            turretX + baseTopW, tBaseY - baseH,
            turretX - baseTopW, tBaseY - baseH)
           -- Base highlight (left edge gets more light)
        love.graphics.setColor(0.20, 0.35, 0.42, 0.4)
        love.graphics.polygon("fill",
            turretX - baseBotW + 2, tBaseY,
            turretX - baseTopW + 2, tBaseY - baseH,
            turretX - baseTopW, tBaseY - baseH,
            turretX - baseBotW, tBaseY)
           -- Base border
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.35, 0.48, 0.55, 0.7)
        love.graphics.polygon("line",
            turretX - baseBotW, tBaseY,
            turretX + baseBotW, tBaseY,
            turretX + baseTopW, tBaseY - baseH,
            turretX - baseTopW, tBaseY - baseH)
        love.graphics.setLineWidth(1)

            -- TURRET BARREL: angled rectangle extending from base toward nearest monster
        local barrelHalfW = 9
        local barrelEndX = turretX + math.sin(barrelAngle) * barrelLen
        local barrelEndY = (tBaseY - baseH) - math.cos(barrelAngle) * barrelLen
           -- Barrel body
        love.graphics.setColor(0.15, 0.25, 0.32, 0.95)
        love.graphics.polygon("fill",
            turretX - barrelHalfW, tBaseY - baseH + 2,
            turretX + barrelHalfW, tBaseY - baseH + 2,
            barrelEndX + barrelHalfW * 0.6, barrelEndY,
            barrelEndX - barrelHalfW * 0.6, barrelEndY)
           -- Barrel highlight (side facing "light")
        love.graphics.setColor(0.25, 0.38, 0.45, 0.35)
        love.graphics.polygon("fill",
            turretX - barrelHalfW + 1, tBaseY - baseH + 2,
            turretX + 1, tBaseY - baseH + 2,
            barrelEndX - barrelHalfW * 0.3, barrelEndY,
            barrelEndX - barrelHalfW * 0.6, barrelEndY)
           -- Barrel outline
        love.graphics.setLineWidth(1.5)
        love.graphics.line(turretX - barrelHalfW, tBaseY - baseH + 2,
                           barrelEndX - barrelHalfW * 0.6, barrelEndY)
        love.graphics.line(turretX + barrelHalfW, tBaseY - baseH + 2,
                           barrelEndX + barrelHalfW * 0.6, barrelEndY)
        love.graphics.setLineWidth(1)

            -- TURRET DOME / CANNON HEAD: rounded shape on top of barrel
        local domeX = turretX
        local domeY = tBaseY - baseH - 8
        local domeR = 13
           -- Dome body (dark metallic)
        love.graphics.setColor(0.10, 0.20, 0.25, 0.95)
        love.graphics.circle("fill", domeX, domeY, domeR)
           -- Dome highlight (left-top)
        love.graphics.setColor(0.30, 0.42, 0.50, 0.35)
        love.graphics.circle("fill", domeX - domeR * 0.2, domeY - domeR * 0.2, domeR * 0.6)
           -- Dome border ring
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.45, 0.58, 0.65, 0.7)
        love.graphics.circle("line", domeX, domeY, domeR - 1)
        love.graphics.setLineWidth(1)

            -- CROSSHAIR on turret dome (small targeting indicator)
        local chAlpha = math.min(1, self.gameTime * 0.5)
        love.graphics.setColor(0.30, 0.80, 0.40, chAlpha * 0.8)
        love.graphics.setLineWidth(1.5)
           -- Horizontal crosshair
        love.graphics.line(domeX - 4, domeY, domeX + 4, domeY)
           -- Vertical crosshair
        love.graphics.line(domeX, domeY - 4, domeX, domeY + 4)
           -- Center dot
        love.graphics.setColor(0.50, 1.0, 0.60, chAlpha)
        love.graphics.circle("fill", domeX, domeY, 1.5)
        love.graphics.setLineWidth(1)

            -- Laser beam from turret dome to nearest monster (if firing)
        if self.laserTimer > 0 and #self.typedStr > 0 then
            local laserColor = {0.2, 0.8, 0.3}     -- green laser
            local lAlpha = math.min(1, self.laserTimer * 4)

                -- Find target monster (first alive one with partial string)
            local laserTX = domeX + math.sin(barrelAngle) * (barrelLen + 60)
            local laserTY = domeY - math.cos(barrelAngle) * (barrelLen + 60)

            for _, m in ipairs(self.monsters) do
                if m.alive and #self.typedStr < m.str:len() then
                    laserTX = m.x
                    laserTY = m.y
                    break
                end
            end

               -- Laser glow (thick transparent outer beam)
            love.graphics.setColor(laserColor[1], laserColor[2], laserColor[3], lAlpha * 0.15)
            love.graphics.setLineWidth(16)
            love.graphics.line(domeX, domeY - domeR, laserTX, laserTY)

               -- Laser core (bright white-green center)
            love.graphics.setColor(laserColor[1] * 1.2, laserColor[2], laserColor[3], lAlpha * 0.9)
            love.graphics.setLineWidth(4)
            love.graphics.line(domeX, domeY - domeR, laserTX, laserTY)

               -- Laser tip flash (expanding circle at target)
            local flashR = 8 + (1 - lAlpha) * 20
            love.graphics.setColor(laserColor[1] * 1.5, laserColor[2] * 1.5,
                                   laserColor[3], lAlpha * 0.4)
            love.graphics.circle("fill", laserTX, laserTY, flashR)

            love.graphics.setLineWidth(1)
        end

            -- Turret HP / ammo indicator (small bar below base)
        local ammoW = 36
        local ammoH = 5
        local ammoX = turretX - ammoW / 2
        local ammoY = tBaseY + 8
        love.graphics.setColor(0.10, 0.15, 0.20, 0.6)
        love.graphics.rectangle("fill", ammoX, ammoY, ammoW, ammoH)
        local ammoPct = #self.monsters > 0 and math.min(1, #self.monsters / 8) or 1
        love.graphics.setColor(0.30, 0.70, 0.40, 0.7 * ammoPct)
        love.graphics.rectangle("fill", ammoX, ammoY, ammoW * ammoPct, ammoH)

             -- Kill counter and tier info (top-left corner)
        local font14 = love.graphics.newFont(14)
        love.graphics.setFont(font14)
        local killTier = math.floor(self.kills / 10) + 1
        local tNames = {"Easy", "Medium", "Hard"}
        if killTier > #tNames then tNames = {"Max"} end
        love.graphics.setColor(0.50, 0.70, 0.80, 0.7)
        love.graphics.printf("Kills: " .. self.kills .. "    Tier: " .. tNames[killTier], 20, 28, 200, "center")

             -- Draw explosion particles on top of everything
         -- Typed string display (bottom center, near ground line)
        if #self.typedStr > 0 then
            love.graphics.setFont(love.graphics.newFont(20))
            love.graphics.setColor(0.90, 0.75, 0.30, 0.85)
            love.graphics.printf("[" .. self.typedStr .. "]", w / 2, h - 100, 200, "center")
        end
        for _, p in ipairs(explosionParticles) do
            p:draw()
        end

             -- Game over overlay (if ever triggered)
        if self.gameOver then
            love.graphics.setColor(0.05, 0.02, 0.05, 0.7)
            love.graphics.rectangle("fill", 0, 0, w, h)
            love.graphics.setFont(love.graphics.newFont(40))
            love.graphics.setColor(0.85, 0.30, 0.25, 1)
            love.graphics.printf("Game Over!", w / 2, h / 2 - 30, w * 0.6, "center")
            love.graphics.setFont(love.graphics.newFont(16))
            love.graphics.setColor(0.60, 0.70, 0.85, 1)
            love.graphics.printf("Final Kills: " .. self.kills .. "    Esc for menu", w / 2, h / 2 + 30, w * 0.6, "center")
        end

             -- Esc hint at bottom
        love.graphics.setFont(love.graphics.newFont(13))
        love.graphics.setColor(0.30, 0.35, 0.42, 0.50)
        love.graphics.printf("Press Esc to go back", w / 2, h - 15, w * 0.6, "center")

    end,

    onKeyReleased = function(self, key)
           -- Esc goes back to menu
        if key == "escape" then
            changeState("menu")
            return
        end

           -- Space: fire laser at matched monster!
        if key == "space" and #self.typedStr > 0 and not self.gameOver then
             -- Check which monster (if any) has matching typed string
            local foundMon = nil
            for _, m in ipairs(self.monsters) do
                if m.alive and m.str:len() >= #self.typedStr then
                    -- Verify ALL typed characters match this monster's string
                    local match = true
                    for ci = 1, #self.typedStr do
                        if m.str:sub(ci, ci):upper() ~= self.typedStr:sub(ci, ci):upper() then
                            match = false
                            break
                        end
                    end
                    if match then
                        foundMon = m
                        break
                    end
                end
            end

                  -- Fire!
            self.laserTimer = 0.2    -- 200ms cooldown

            if foundMon then
                   -- Kill the monster: add explosion particles
                addExplosion(foundMon.x, foundMon.y, 0.3, 0.8, 0.4, 60)
                self.kills = self.kills + 1
            end

                  -- Reset typed string after firing (even if no match)
            self.typedStr = ""
            return
        end

           -- Backspace: remove last character from typed string
        if key == "backspace" then
            if #self.typedStr > 0 then
                self.typedStr = self.typedStr:sub(1, #self.typedStr - 1)
            end
            return
        end

           -- Only process single-character keys (letters, digits, punctuation)
        if not key:match("^.{1}$") then return end

           -- Add character to typed string (max length = max monster string length)
        local maxLen = self:getMonStringLen()
        if #self.typedStr < maxLen then
            self.typedStr = self.typedStr .. key
        end
    end,
}


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
        states[currentStateName]:onDraw()
    end
end

love.keyreleased = function(key)
        -- Route key events to the active state
    if states[currentStateName] and states[currentStateName].onKeyReleased then
        states[currentStateName]:onKeyReleased(key)
    end
end


love.mousepressed = function(x, y, button)
         -- Forward mouse click to menu state's mouseClicked flag
    if button == 1 and currentStateName == "menu" and states["menu"] then
        states["menu"].mouseClicked = true
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
