-- loveTyping -- Shared utilities: math helpers, classes, particle system, state machine.
-- This module sets up all shared globals so level modules can require it and be self-contained.

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
    elseif hue < math.pi * 5 / 3 then return m, xVal + m, cVal + m
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

states = {} -- name -> state object with update/draw methods
currentStateName = nil              -- read/written by changeState + main.lua

--- Switch to a named state; calls onExit of old and onEnter of new.
local function changeState(name)
    if states[currentStateName] and states[currentStateName].onExit then
        states[currentStateName].onExit(states[currentStateName])
    end
    currentStateName = name
    if states[name] and states[name].onEnter then
        states[name].onEnter(states[name])
    end
end

--------------------------------------------------------------------------------
-- Responsive layout: scale values relative to a 960x700 design baseline.
-- Call screenScale(v) to get the value for the current screen dimensions.
-- On portrait screens, scales against width (the limiting dimension);
-- on landscape, uses height so tall UI elements don't overflow.
--------------------------------------------------------------------------------

_G.screenScale = function(v)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local scaleX = (w - 40) / 960     -- 960 design baseline, 40px margin budget
    local scaleY = (h - 80) / 700     -- 700 design baseline, 80px margin budget
    if h > w then return v * math.max(0.35, scaleX) end
    return v * math.min(scaleX, scaleY)
end

--------------------------------------------------------------------------------
-- Global particle pool: updated each frame, drawn on top of everything.
--------------------------------------------------------------------------------

explosionParticles = {}

--- Add a batch of particles to the global pool.
local function addExplosion(x, y, r, g, b, count)
    for _, p in ipairs(createExplosion(x, y, r, g, b, count)) do
        table.insert(explosionParticles, p)
    end
end

--------------------------------------------------------------------------------
-- Expose everything as globals for level modules to use.
--------------------------------------------------------------------------------

_G.abs = abs
_G.lerp = lerp
_G.hslToRgb = hslToRgb
_G.Particle = Particle
_G.Sphere = Sphere
_G.getKeyboardLayout = getKeyboardLayout
_G.currentStateName = currentStateName   -- read-only reference
_G.changeState = changeState
_G.addExplosion = addExplosion

return {}
