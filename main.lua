-- loveTyping -- A Love2D typing practice application
-- Features multiple difficulty levels with glowing sphere letter displays
-- and explosion effects on key press.

--------------------------------------------------------------------------------
-- Utility helpers
--------------------------------------------------------------------------------

--- Returns the absolute value of a number.
local function abs(n) return n < 0 and -n or n end

--- Linear interpolation between two values, clamping t to [0, 1].
local function lerp(a, b, t)
    return a + (b - a) * math.min(math.max(t, 0), 1)
end

--------------------------------------------------------------------------------
-- Particle system: explosion particles rendered on top of everything.
--------------------------------------------------------------------------------

local Particle = {}
Particle.__index = Particle

function Particle:new(x, y, vx, vy, life, color)
    local p = setmetatable({}, self)
    p.x = x
    p.y = y
    p.vx = vx or 0
    p.vy = vy or 0
    p.life = life or 1.0
    p.maxLife = p.life
    p.color = color or {1, 1, 1, 1}
    p.size = math.random(2, 5)
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
    local c = self.color
    love.graphics.setColor(c[1], c[2], c[3], c[4] * alpha)
    love.graphics.circle("fill", self.x, self.y, self.size * alpha)
end

function Particle:isDead() return self.life <= 0 end

--- Creates an explosion of particles at the given position.
local function createExplosion(x, y, color, count)
    local particles = {}
    for i = 1, (count or 40) do
        local angle = math.random() * math.pi * 2
        local speed = math.random(60, 350)
        local life = math.random(4, 12) / 10
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed - 80
        table.insert(particles, Particle:new(x, y, vx, vy, life, color))
    end
    return particles
end

--------------------------------------------------------------------------------
-- Letter sphere: draws a letter as a glowing sphere on screen.
--------------------------------------------------------------------------------

local Sphere = {}
Sphere.__index = Sphere

function Sphere:new(letter, x, y)
    local s = setmetatable({}, self)
    s.letter = letter
    s.x = x
    s.y = y
    s.radius = 28
    s.glowRadius = 42
    s.pulsePhase = math.random() * math.pi * 2
    s.opacity = 1
    s.scale = 1
    s.alive = true

       -- Map letter index A(0) to Y(25) into a hue angle for coloring each sphere.
       -- Uses HSL-to-RGB conversion.
    local hueFrac = (string.byte(letter) - string.byte('A')) / 25
    local hDeg = hueFrac * 360
    local sat, lit = 0.75, 0.55
    local cVal = (1 - abs(2 * lit - 1)) * sat
    local xVal = cVal * (1 - abs(math.fmod(hDeg / 60, 2) - 1))
    local m = lit - cVal / 2
    local r, g, b = 0, 0, 0
    if hDeg < 60 then r, g, b = cVal, xVal, 0
    elseif hDeg < 120 then r, g, b = xVal, cVal, 0
    elseif hDeg < 180 then r, g, b = 0, cVal, xVal
    elseif hDeg < 240 then r, g, b = 0, xVal, cVal
    elseif hDeg < 300 then r, g, b = xVal, 0, cVal
    else r, g, b = cVal, 0, xVal
    end
    s.glowColor = {r + m, g + m, b + m}
    return s
end

function Sphere:update(dt)
    self.pulsePhase = self.pulsePhase + dt * 2.5
end

--- Draw the sphere: outer glow ring, gradient fill with 3D shading, and label.
function Sphere:draw()
    if not self.alive then return end
    local pulse = math.sin(self.pulsePhase) * 0.15 + 1
    local gr = self.glowRadius * pulse
    local gc = self.glowColor

       -- Outer glow ring (colored aura spreading outward)
    love.graphics.setColor(gc[1] * 0.5, gc[2] * 0.5, gc[3] * 0.5, 0.12 * self.opacity)
    love.graphics.circle("fill", self.x, self.y, gr + 15)
    love.graphics.setColor(gc[1] * 0.7, gc[2] * 0.7, gc[3] * 0.7, 0.25 * self.opacity)
    love.graphics.circle("fill", self.x, self.y, gr)

       -- Sphere body with 3D shading: darker bottom-left offset for depth feel
    local sr = self.radius * pulse
    love.graphics.setColor(0.15, 0.15, 0.25, self.opacity)
    love.graphics.circle("fill", self.x + 3, self.y + 3, sr)

       -- Main fill (lighter top-left for gradient feel)
    local bright = self.glowColor[1] * 0.4 + 0.15
    local bgCol = self.glowColor[2] * 0.4 + 0.15
    local bb = self.glowColor[3] * 0.4 + 0.15
    love.graphics.setColor(bright, bgCol, bb, self.opacity)
    love.graphics.circle("fill", self.x - sr * 0.12, self.y - sr * 0.15, sr * 0.92)

       -- Highlight (top-left specular reflection dot)
    local hlR = sr * 0.35
    love.graphics.setColor(1, 1, 1, 0.45 * self.opacity)
    love.graphics.circle("fill", self.x - sr * 0.25, self.y - sr * 0.3, hlR)

       -- Border ring
    love.graphics.setLineWidth(2)
    love.graphics.setColor(gc[1], gc[2], gc[3], 0.6 * self.opacity)
    love.graphics.circle("line", self.x, self.y, sr)
    love.graphics.setLineWidth(1)

       -- Letter label centered on the sphere with shadow for readability
    local fontSize = math.floor(sr * 1.1)
    local font = love.graphics.newFont(fontSize)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, self.opacity * 0.5)
    love.graphics.printf(self.letter, self.x - sr, self.y - fontSize * 0.4,
                         sr * 2, "center")
    love.graphics.setColor(1, 1, 1, self.opacity)
    love.graphics.printf(self.letter, self.x - sr + 1, self.y - fontSize * 0.4 + 1,
                         sr * 2, "center")
end

--------------------------------------------------------------------------------
-- Keyboard layout: rows of letters in physical keyboard order (QWERTY).
-- Returns a table of {letter, x, y} with positions relative to center.
--------------------------------------------------------------------------------

local function getKeyboardLayout(cx, cy)
    local layout = {}
    local rows = {
           {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
           {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
           {"Z", "X", "C", "V", "B", "N", "M"}
      }
    local spacingY = 95

    for i, row in ipairs(rows) do
        local rowsY = cy + (i - 1) * spacingY - 95
        local colsInRow = #row
        for j, letter in ipairs(row) do
               -- Distribute letters evenly with slight inward curve at edges
            local colX = cx + (j - (colsInRow + 1) / 2) * 66
            local arcAmt = math.abs(j - (colsInRow + 1) / 2)
                 / ((colsInRow + 1) / 2)
            colX = colX - arcAmt * 8

            table.insert(layout, {letter = letter, x = colX, y = rowsY})
        end
    end
    return layout
end

--------------------------------------------------------------------------------
-- State machine runner: manages transitions between game screens.
--------------------------------------------------------------------------------

local states = {} -- name -> state object
local currentStateName = nil

--- Switch to a named state; calls onExit of the old and onEnter of the new.
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
-- LEVEL MENU: displays difficulty buttons with glow on hover.
--------------------------------------------------------------------------------

states["menu"] = {
       -- Level definitions displayed as clickable buttons
    levels = {
           {id = 1, name = "\xe5\x85\xa5\xe9\x97\xa8", desc = "Letter spheres in keyboard order, press to explode"},
           {id = 2, name = "\xe5\x9f\xba\xe7\xa1\x80", desc = "Type words as they are prompted"},
           {id = 3, name = "\xe8\xbf\x9b\xe9\x98\xb6", desc = "Timed typing challenge, beat the clock"},
      },

       -- Entrance flash animation (white fade-out on level entry)
    flashAlpha = 0,
    flashTimer = 1.5,

    onEnter = function(self)
           -- Create button rects for each level
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        self.buttons = {}
        local bw, bh = math.min(w * 0.4, 320), 76
        local startY = 260
        for i = 1, #self.levels do
            table.insert(self.buttons, {
                x = (w - bw) / 2,
                y = startY + (i - 1) * (bh + 32),
                w = bw, h = bh,
                levelId = self.levels[i].id,
              })
        end
    end,

    onUpdate = function(self, dt)
           -- Fade entrance flash
        self.flashTimer = self.flashTimer - dt
        if self.flashTimer > 0 then
            self.flashAlpha = math.min(self.flashTimer / 0.5, 1) * 0.3
        end

           -- Detect mouse hover on buttons
        local mx, my = love.mouse.getPosition()
        for _, btn in ipairs(self.buttons) do
            btn.hover = (mx >= btn.x and mx <= btn.x + btn.w and
                         my >= btn.y and my <= btn.y + btn.h)
        end

           -- Handle button click
        if love.mouse.justPressed(1) then
            for _, btn in ipairs(self.buttons) do
                local mx2, my2 = love.mouse.getPosition()
                if (mx2 >= btn.x and mx2 <= btn.x + btn.w and
                     my2 >= btn.y and my2 <= btn.y + btn.h) then
                    changeState("level" .. tostring(btn.levelId))
                    return
                end
            end
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

           -- Entrance flash overlay
        if self.flashAlpha > 0 then
            love.graphics.setColor(1, 1, 1, self.flashAlpha)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end

           -- Title: "loveTyping" in large white text
        local titleFont = love.graphics.newFont(52)
        love.graphics.setFont(titleFont)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("loveTyping", w / 2, 90, w * 0.7, "center")

           -- Subtitle in Chinese
        local subFont = love.graphics.newFont(16)
        love.graphics.setFont(subFont)
        love.graphics.setColor(0.55, 0.70, 0.90, 0.8)
        love.graphics.printf("Select Difficulty Level", w / 2, 150, w * 0.5, "center")

           -- Draw level buttons with hover glow effect
        for i, btn in ipairs(self.buttons) do
            local lvl = self.levels[i]
            local c = btn.hover and {0.3, 0.4, 0.7} or {0.15, 0.2, 0.35}

               -- Button glow (on hover)
            if btn.hover then
                love.graphics.setColor(c[1] * 1.8, c[2] * 1.8, c[3] * 1.8, 0.25)
                love.graphics.rectangle("fill", btn.x - 4, btn.y - 4,
                                         btn.w + 8, btn.h + 8, 14)
            end

               -- Button background (rounded rect)
            love.graphics.setColor(c[1], c[2], c[3], 0.95)
            love.graphics.rectangle("round", btn.x, btn.y, btn.w, btn.h, 10)

               -- Button border (brighter on hover)
            love.graphics.setLineWidth(2)
            local bc = btn.hover and {0.6, 0.8, 1} or {0.35, 0.45, 0.65}
            love.graphics.setColor(bc[1], bc[2], bc[3])
            love.graphics.rectangle("round", btn.x, btn.y, btn.w, btn.h, 10)
            love.graphics.setLineWidth(1)

               -- Button text (Chinese name + English label)
            local txtFont = love.graphics.newFont(20)
            love.graphics.setFont(txtFont)
            local tc = btn.hover and {1, 1, 1} or {0.85, 0.87, 0.9}
            love.graphics.setColor(tc[1], tc[2], tc[3])
            love.graphics.printf(lvl.name .. "   Level " .. tostring(lvl.id),
                                 btn.x + btn.w / 2, btn.y + btn.h / 2 - 6,
                                 btn.w - 24, "center")

               -- Description text below button
            local descFont = love.graphics.newFont(13)
            love.graphics.setFont(descFont)
            love.graphics.setColor(0.45, 0.50, 0.60, 0.75)
            love.graphics.printf(lvl.desc, w / 2, btn.y + btn.h + 10,
                                 btn.w, "center")
        end

           -- Footer hint
        local hintFont = love.graphics.newFont(13)
        love.graphics.setFont(hintFont)
        love.graphics.setColor(0.3, 0.35, 0.42, 0.5)
        love.graphics.printf("Click a button or press Esc", w / 2, h - 40, w * 0.4, "center")
    end,

    onKeyReleased = function(self, key)
           -- Menu is the top-level state; Esc has no effect here
        if key == "escape" then return end
    end,
}

--------------------------------------------------------------------------------
-- LEVEL 1: INTRO -- A-Z letters as glowing spheres in keyboard layout.
-- Pressing a letter triggers an explosion effect at that sphere's position.
--------------------------------------------------------------------------------

states["level1"] = {
    levelLabel = "Level 1 -- Intro",
    flashAlpha = 0,
    instructionsTimer = 4,
    showInstructions = true,
    scoredLetters = {}, -- tracks exploded letters: {"A": timer}
    totalExplosions = 0,

    onEnter = function(self)
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
           -- Get sphere positions for keyboard layout (centered on screen)
        self.layout = getKeyboardLayout(w / 2, h / 2 + 30)

           -- Create spheres at each position
        self.spheres = {}
        for _, entry in ipairs(self.layout) do
            table.insert(self.spheres, Sphere:new(entry.letter,
                                                  entry.x, entry.y))
        end
    end,

    onUpdate = function(self, dt)
           -- Fade entrance flash
        self.flashAlpha = math.max(0, self.flashAlpha - dt * 2)

           -- Instructions fade out after ~4 seconds
        self.instructionsTimer = self.instructionsTimer - dt
        if self.instructionsTimer <= 0 then
            self.showInstructions = false
        end

           -- Update all spheres for pulsing glow animation
        for _, s in ipairs(self.spheres) do
            s:update(dt)
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

           -- Title bar with level name and back hint
        love.graphics.setFont(love.graphics.newFont(15))
        love.graphics.setColor(0.35, 0.42, 0.55, 0.6)
        love.graphics.printf(self.levelLabel .. "     Press Esc to go back",
                             w / 2, 28, w * 0.5, "center")

           -- Instructions overlay (fades out after ~4s)
        if self.showInstructions then
            local instrAlpha = math.min(self.instructionsTimer / 1.5, 1)
            love.graphics.setFont(love.graphics.newFont(22))
            love.graphics.setColor(0.65, 0.78, 0.93, instrAlpha * 0.9)
            love.graphics.printf("Press keyboard letters to explode the spheres!",
                w / 2, 58, w * 0.75, "center")
        end

           -- Draw all spheres at their layout positions
        for _, s in ipairs(self.spheres) do
               -- Dim sphere after it has been exploded (fade-out over ~1s)
            if self.scoredLetters[s.letter] then
                local progress = math.min(self.scoredLetters[s.letter], 1)
                s.opacity = lerp(0.2, 1, progress)
                s.scale = lerp(0.5, 1, progress)
            else
                s.opacity = 1
                s.scale = 1
            end
            s:draw()
        end

           -- Flash overlay on level entry
        if self.flashAlpha > 0 then
            love.graphics.setColor(1, 1, 1, self.flashAlpha * 0.2)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end

           -- Stats: count of remaining unpressed letters
        if self.totalExplosions > 0 then
            local remaining = #self.spheres - self.totalExplosions
            love.graphics.setFont(love.graphics.newFont(17))
            love.graphics.setColor(0.45, 0.60, 0.80, 0.7)
            love.graphics.printf(
                 "Exploded: " .. self.totalExplosions .. "/" .. #self.spheres
                     .. "    |   Remaining: " .. remaining,
                w / 2, h - 35, w * 0.5, "center")
        end
    end,

    onKeyReleased = function(self, key)
           -- Esc goes back to menu
        if key == "escape" then
            changeState("menu")
            return
        end

           -- Only respond to single letter keys (A-Z / a-z)
        if not key:match("^%a$") then return end

        local upperKey = string.upper(key)

           -- Find the sphere matching this letter and explode it
        for _, s in ipairs(self.spheres) do
            if s.letter == upperKey and not self.scoredLetters[upperKey] then
                   -- Explosion position (screen coords: layout is centered)
                local ex = love.graphics.getWidth() / 2 + s.x
                local ey = love.graphics.getHeight() / 2 + s.y + 30

                   -- Color per letter (predefined vibrant palette)
                local colors = {
                     ["A"] = {1,0.5,0.3},   ["B"] = {0.8,0.6,1},
                     ["C"] = {1,0.8,0.4}, ["D"] = {0.9,0.5,0.7},
                     ["E"] = {1,0.9,0.3}, ["F"] = {0.6,0.8,1},
                     ["G"] = {0.4,0.9,0.5},["H"] = {0.9,0.7,1},
                     ["I"] = {0.7,0.7,1}, ["J"] = {1,0.6,0.8},
                     ["K"] = {0.8,0.8,0.6},["L"] = {0.6,1,0.7},
                     ["M"] = {0.9,0.4,0.5},["N"] = {0.7,0.6,0.9},
                     ["O"] = {1,0.7,0.3}, ["P"] = {0.5,0.8,0.9},
                     ["Q"] = {1,0.4,0.6}, ["R"] = {1,0.5,0.4},
                     ["S"] = {0.8,0.9,0.5},["T"] = {0.4,0.7,0.9},
                     ["U"] = {0.6,0.5,1},   ["V"] = {0.9,0.6,0.7},
                     ["W"] = {0.7,0.9,0.4},["X"] = {0.5,0.9,0.8},
                     ["Y"] = {1,0.8,0.3},   ["Z"] = {0.8,0.4,0.7}
                  }
                local color = colors[upperKey] or {1, 1, 1}

                   -- Create explosion particles (added to global list for drawing)
                for _, p in ipairs(createExplosion(ex, ey, color, 50)) do
                    table.insert(explosionParticles, p)
                end

                   -- Mark as exploded (will fade out over ~1 second)
                self.scoredLetters[upperKey] = 0
                self.totalExplosions = self.totalExplosions + 1
                return -- only explode one sphere per keypress
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- LEVEL 2: WORDS -- type words; correct letters sparkle.
--------------------------------------------------------------------------------

states["level2"] = {
    levelLabel = "Level 2 -- Words",
       -- Word bank for the typing exercise
    wordList = {"love","code","type","fast","easy","help","jump",
                  "king","lucky","magic","night","power","quiet","swift",
                  "apple","bread","chair","dream","earth","flame","grape",
                  "heart","jewel","knife","music","world"},
    flashAlpha = 0,
    currentWord = nil,
    typedProgress = 0, -- number of correct chars typed so far

    onEnter = function(self)
        self.currentWord = nil
        self.typedProgress = 0

           -- Shuffle the word list for variety each game session
        local shuffled = {}
        for i = 1, #self.wordList do
            table.insert(shuffled, self.wordList[i])
        end
        for i = #shuffled, 2, -1 do
            local j = math.random(i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end

           -- Preload the first few words into a "queue" that drifts down
        self.wordQueue = {}
        for i = 1, math.min(3, #shuffled) do
            table.insert(self.wordQueue, {text = shuffled[i],
                                          y = (i - 1) * 55, opacity = 1})
        end

           -- Set the first word as the active target to type
        if #shuffled > 0 then
            self.currentWord = shuffled[1]
        end
    end,

    onUpdate = function(self, dt)
        self.flashAlpha = math.max(0, self.flashAlpha - dt * 3)

           -- Drift all queue words downward slowly
        for idx = 1, #self.wordQueue do
            self.wordQueue[idx].y = self.wordQueue[idx].y + dt * 12
        end

           -- Remove off-screen words from the front of the queue
        while #self.wordQueue > 0 and self.wordQueue[1].y > love.graphics.getHeight() - 80 do
            table.remove(self.wordQueue, 1)
        end

           -- Refill queue with new words when running low
        if #self.wordQueue < 2 then
            local shuffled = {}
            for i = 1, #self.wordList do
                table.insert(shuffled, self.wordList[i])
            end
            for i = #shuffled, 2, -1 do
                local j = math.random(i)
                shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
            end
            for idx = 1, #shuffled do
                table.insert(self.wordQueue, {text = shuffled[idx], y = 0})
            end
        end
    end,

    onDraw = function(self)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

           -- Background gradient (dark greenish tint for this level)
        for y = 1, h do
            local t = y / h
            love.graphics.setColor(lerp(0.04, 0.07, t),
                                   lerp(0.03, 0.05, t),
                                   lerp(0.08, 0.12, t))
            love.graphics.rectangle("fill", 0, y, w, 1)
        end

           -- Title bar
        love.graphics.setFont(love.graphics.newFont(15))
        love.graphics.setColor(0.35, 0.42, 0.55, 0.6)
        love.graphics.printf(self.levelLabel .. "     Press Esc to go back",
                             w / 2, 28, w * 0.5, "center")

           -- Draw queue words (drifting in the background)
        for idx = 1, #self.wordQueue do
            local wordEntry = self.wordQueue[idx]
               -- Skip drawing the current active word in the background queue
            if self.currentWord and wordEntry.text == self.currentWord then
                 -- skip: already shown large at center
            else
                love.graphics.setFont(love.graphics.newFont(18))
                love.graphics.setColor(0.35, 0.42, 0.55, wordEntry.opacity * 0.6)
                love.graphics.printf(wordEntry.text, w / 2,
                                     70 + idx * 55, w * 0.5, "center")
            end
        end

           -- Current word (large and prominent in center of screen)
        if self.currentWord then
            local cw = self.currentWord
            local typedStr = cw:sub(1, self.typedProgress)

               -- Progress bar above the word
            local progress = 0
            if #typedStr > 0 then
                progress = #typedStr / #cw
            end
            love.graphics.setLineWidth(4)
            love.graphics.setColor(0.2, 0.28, 0.38, 1)
            love.graphics.rectangle("fill", w / 2 - 100, 55, 200, 6)
            if progress > 0 then
                love.graphics.setColor(0.3, 0.65, 0.4, 1)
                love.graphics.rectangle("fill", w / 2 - 100, 55,
                                        200 * progress, 6)
            end
            love.graphics.setLineWidth(1)

               -- Render typed portion in green, untyped remainder in dim white
            local font = love.graphics.newFont(46)
            love.graphics.setFont(font)
            local startX = w / 2 - #cw * 13

            for idx = 1, #typedStr do
                love.graphics.setColor(0.35, 0.70, 0.40, 1)
                love.graphics.printf(typedStr:sub(idx, idx),
                                     startX + (idx - 1) * 26,
                                     h / 2 - 15, 0, "left")
            end
            for idx = #typedStr + 1, #cw do
                love.graphics.setColor(0.40, 0.45, 0.58, 0.5)
                love.graphics.printf(cw:sub(idx, idx),
                                     startX + (idx - 1) * 26,
                                     h / 2 - 15, 0, "left")
            end

               -- Flash overlay when word is completed
            if self.flashAlpha > 0 then
                love.graphics.setColor(0.3, 0.6, 0.35, self.flashAlpha * 0.15)
                love.graphics.rectangle("fill", 0, 0, w, h)
            end

         else
               -- Prompt to start typing (when no active word set)
            local promptAlpha = math.sin(love.timer.getTime() * 3) * 0.3 + 0.5
            love.graphics.setFont(love.graphics.newFont(16))
            love.graphics.setColor(0.4, 0.5, 0.6, promptAlpha)
            love.graphics.printf("Start typing to begin!", w / 2,
                                 h - 80, w * 0.4, "center")
        end

           -- Bottom hint
        love.graphics.setFont(love.graphics.newFont(13))
        love.graphics.setColor(0.3, 0.35, 0.42, 0.5)
        love.graphics.printf("Word queue: " .. #self.wordQueue
                              .. "     Press Esc to go back",
                             w / 2, h - 35, w * 0.5, "center")
    end,

    onKeyReleased = function(self, key)
        if key == "escape" then
            changeState("menu")
            return
        end

           -- Only process alphabetic keys (A-Z)
        if not key:match("^%a$") then return end
        if not self.currentWord then return end

        local expected = self.currentWord:sub(
            self.typedProgress + 1, self.typedProgress + 1):upper()
        local pressed = string.upper(key)

        if pressed == expected then
               -- Correct: increment progress and add sparkle particles
            self.typedProgress = self.typedProgress + 1

               -- Small sparkle burst for each correct keystroke
            local cx = love.graphics.getWidth() / 2 - #self.currentWord * 13
                        + (self.typedProgress - 1) * 26
            local cy = love.graphics.getHeight() / 2
            for _, p in ipairs(createExplosion(cx, cy,
                 {0.35, 0.7, 0.4}, 6)) do
                table.insert(explosionParticles, p)
            end

               -- Word completed? Reset and move to next word
            if self.typedProgress >= #self.currentWord then
                   -- Celebration burst at center of screen
                local cx2 = love.graphics.getWidth() / 2
                for _, p in ipairs(createExplosion(cx2,
                    love.graphics.getHeight() / 2 - 30,
                     {0.3, 0.9, 0.5}, 55)) do
                    table.insert(explosionParticles, p)
                end
                self.flashAlpha = 1

                   -- Pick next word from queue (or refill if empty)
                if #self.wordQueue > 0 then
                    self.currentWord = table.remove(self.wordQueue, 1)
                    self.typedProgress = 0
                else
                       -- Refill queue and set a new target word
                    local shuffled = {}
                    for i = 1, #self.wordList do
                        table.insert(shuffled, self.wordList[i])
                    end
                    for i = #shuffled, 2, -1 do
                        local j = math.random(i)
                        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
                    end
                    if #shuffled > 0 then
                        self.currentWord = table.remove(shuffled, 1)
                        self.typedProgress = 0
                    end
                end
            end
        else
               -- Wrong letter: visual feedback could be added here
               -- (e.g., red screen flash or shake effect)
        end
    end,
}

--------------------------------------------------------------------------------
-- LEVEL 3: TIMED CHALLENGE -- type words quickly before timer runs out.
--------------------------------------------------------------------------------

states["level3"] = {
    levelLabel = "Level 3 -- Timed",
       -- Smaller word bank for faster-paced timed challenge
    wordList = {"love","code","type","fast","easy","help","jump",
                  "king","lucky","magic","night","power","quiet","swift",
                  "apple","bread","chair","dream","earth","flame","grape"},
    timeLeft = 60,
    score = 0,
    currentWord = nil,
    typedProgress = 0,
    flashAlpha = 0,

    onEnter = function(self)
        self.timeLeft = 60
        self.score = 0
        self.currentWord = nil
        self.typedProgress = 0
           -- Pick a random starting word to type immediately
        local idx = math.random(#self.wordList)
        self.currentWord = self.wordList[idx]
    end,

    onUpdate = function(self, dt)
           -- Countdown timer: subtract frame time each update
        self.timeLeft = self.timeLeft - dt
        if self.timeLeft <= 0 then
            self.timeLeft = 0
               -- Timer expired: mark state (game over will be drawn next frame)
            self.timeLeft = -1
        end

        self.flashAlpha = math.max(0, self.flashAlpha - dt * 3)
    end,

    onDraw = function(self)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

           -- Background gradient (redder tint for sense of urgency)
        for y = 1, h do
            local t = y / h
            local r = math.min(0.08 + t * 0.04, 0.12)
            love.graphics.setColor(r, lerp(0.05, 0.06, t),
                                   lerp(0.10, 0.13, t))
            love.graphics.rectangle("fill", 0, y, w, 1)
        end

           -- Title bar: timer display with color based on urgency level
        local timeColor = {0.4, 0.7, 0.9}
        if self.timeLeft > 0 then
            if self.timeLeft > 20 then
                timeColor = {0.4, 0.7, 0.9}
            elseif self.timeLeft > 10 then
                timeColor = {0.85, 0.55, 0.3}
            else
                timeColor = {0.85, 0.25, 0.25}
            end
        end
        love.graphics.setFont(love.graphics.newFont(15))
        love.graphics.setColor(timeColor[1], timeColor[2], timeColor[3], 0.8)
        local timerDisplay = self.timeLeft > 0 and math.ceil(self.timeLeft)
                                                    or 0
        love.graphics.printf("Clock: " .. timerDisplay .. "s     |  Score: "
                              .. self.score .. "     Press Esc to go back",
                             w / 2, 28, w * 0.6, "center")

        if self.timeLeft > 0 and self.currentWord then
               -- Progress bar: fills as you type, color based on urgency
            local progress = 0
            if self.typedProgress and self.typedProgress > 0 then
                progress = self.typedProgress / #self.currentWord
            end
            love.graphics.setLineWidth(5)
            local barColor = {0.3, 0.65, 0.4}
            if self.timeLeft < 10 then
                barColor = {0.75, 0.25, 0.25}
            end
            love.graphics.setColor(0.2, 0.28, 0.38, 1)
            love.graphics.rectangle("fill", w / 2 - 100, 55, 200, 6)
            if progress > 0 then
                love.graphics.setColor(barColor[1], barColor[2], barColor[3], 1)
                love.graphics.rectangle("fill", w / 2 - 100, 55,
                                        200 * progress, 6)
            end
            love.graphics.setLineWidth(1)

               -- Word display (typed green, untyped dim gray)
            local cw = self.currentWord
            local typedStr = cw:sub(1, self.typedProgress or 0)
            local font = love.graphics.newFont(48)
            love.graphics.setFont(font)
            local startX = w / 2 - #cw * 14

            for idx = 1, #typedStr do
                love.graphics.setColor(0.35, 0.70, 0.40, 1)
                love.graphics.printf(typedStr:sub(idx, idx),
                                     startX + (idx - 1) * 28,
                                     h / 2 - 10, 0, "left")
            end
            for idx = #typedStr + 1, #cw do
                love.graphics.setColor(0.40, 0.45, 0.58, 0.5)
                love.graphics.printf(cw:sub(idx, idx),
                                     startX + (idx - 1) * 28,
                                     h / 2 - 10, 0, "left")
            end

               -- Flash overlay on word completion
            if self.flashAlpha > 0 then
                love.graphics.setColor(0.25, 0.50, 0.30, self.flashAlpha * 0.15)
                love.graphics.rectangle("fill", 0, 0, w, h)
            end

               -- Start hint (pulsing fade-in/out animation)
            if not typedStr or #typedStr == 0 then
                local hintAlpha = math.sin(love.timer.getTime() * 3) * 0.3 + 0.5
                love.graphics.setFont(love.graphics.newFont(14))
                love.graphics.setColor(0.4, 0.5, 0.6, hintAlpha)
                love.graphics.printf("Press any letter key to start!",
                                     w / 2, h - 80, w * 0.4, "center")
            end

         elseif self.timeLeft <= 0 then
               -- Game over overlay: semi-transparent dark with red text
            local goAlpha = math.min(1, love.timer.getTime() % 5 / 3)
            love.graphics.setColor(0.06, 0.03, 0.06, goAlpha * 0.8)
            love.graphics.rectangle("fill", 0, 0, w, h)

            love.graphics.setFont(love.graphics.newFont(48))
            love.graphics.setColor(0.85, 0.25, 0.25, goAlpha)
            love.graphics.printf("Time's up!",
                                 w / 2, h / 2 - 30, w * 0.6, "center")

            love.graphics.setFont(love.graphics.newFont(20))
            love.graphics.setColor(0.6, 0.70, 0.85, goAlpha)
            love.graphics.printf("Final Score: " .. self.score
                                  .. "     Press Esc to go back",
                                 w / 2, h / 2 + 30, w * 0.5, "center")
         end
    end,

    onKeyReleased = function(self, key)
        if key == "escape" then
            changeState("menu")
            return
        end

           -- Ignore keys after game is over (wait for restart logic)
        if self.timeLeft <= 0 then return end
        if not self.currentWord then return end
        if not key:match("^%a$") then return end

           -- Only respond to the first keystroke (to start typing the word)
        if self.typedProgress and self.typedProgress > 0 then return end

           -- Mark that we've started typing
        self.typedProgress = 1

           -- Check correctness of the first letter
        local expected = self.currentWord:sub(1, 1):upper()
        local pressed = string.upper(key)

        if pressed == expected then
               -- Correct! Score scales with remaining time (longer = better)
            self.score = self.score + math.ceil(self.timeLeft) * 10
            self.flashAlpha = 1

               -- Explosion for correct word completion
            local cx = love.graphics.getWidth() / 2
            for _, p in ipairs(createExplosion(cx,
                love.graphics.getHeight() / 2 - 30,
                 {0.3, 0.9, 0.5}, 45)) do
                table.insert(explosionParticles, p)
            end

               -- Pick next random word for the challenge
            local idx = math.random(#self.wordList)
            self.currentWord = self.wordList[idx]
            self.typedProgress = 0
        else
               -- Wrong first letter: switch to a new random word and penalize time
            local idx = math.random(#self.wordList)
            self.currentWord = self.wordList[idx]
            self.timeLeft = self.timeLeft - 3
            if self.timeLeft < 0 then self.timeLeft = 0 end
        end
    end,
}

--------------------------------------------------------------------------------
-- GLOBAL particle list: rendered on top of everything in love.draw.
--------------------------------------------------------------------------------

local explosionParticles = {}

--------------------------------------------------------------------------------
-- Main entry point: Love2D callbacks that dispatch to the state machine.
--------------------------------------------------------------------------------

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

       -- Render explosion particles on top of everything
    for _, p in ipairs(explosionParticles) do
        p:draw()
    end
end

love.keyreleased = function(key, scancode)
       -- Route key events to the active state (passed as simple strings)
    if states[currentStateName] and states[currentStateName].onKeyReleased then
        states[currentStateName]:onKeyReleased(key)
    end
end
