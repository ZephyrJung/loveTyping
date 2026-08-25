-- loveTyping -- Level 2: Falling Spheres -- Three-tier progressive speed!
-- Responsive layout that adapts to any screen size and orientation.

local baseScale = screenScale(1)

states["level2"] = {
    currentTier = 1,                  -- 1=slow (default), 2=medium, 3=fast
    gameTime = 0,
    spawnTimer = 0.5,
    flashAlpha = 0,                             -- screen flash on hit
    score = 0,
    fallingSpheres = {},                  -- active falling spheres
    overflowCount = 0,                -- spheres that fell past ground line

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
            local sx = math.random(math.floor(w * 0.15), math.floor(w * 0.85))
            local speed = (math.random() * 60 + 20)

                 --- Create sphere at top of screen
            local s = Sphere:new(letter, sx, -40)
            s.vy = speed               -- store initial velocity for gravity calc
            table.insert(self.fallingSpheres, s)

                 --- Reset timer with slight randomness
            self.spawnTimer = spawnInt + math.random(-150, 150) / 1000
        end

             --- Update all falling spheres (gravity + pulse)
        local gravity = grav           -- gravity per tier: 40 / 65 / 95
        for i = #self.fallingSpheres, 1, -1 do
            local s = self.fallingSpheres[i]
            s:update(dt)

                 --- Apply gravity to vertical velocity
            s.vy = (s.vy or 30) + gravity * dt
            s.y = s.y + s.vy * dt

                 --- Check if fallen past the ground line
            local h = love.graphics.getHeight()
            local groundY = h - math.floor(120 * baseScale)

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
        local groundY = h - math.floor(120 * baseScale)
        love.graphics.setLineWidth(math.max(1, math.floor(2 * baseScale)))
        love.graphics.setColor(0.35, 0.45, 0.60, 0.30)
        love.graphics.line(0, groundY, w, groundY)
        love.graphics.setLineWidth(1)

             --- Draw falling spheres
        for _, s in ipairs(self.fallingSpheres) do
            s:draw()
        end

             --- Title bar with tier info
        love.graphics.setFont(love.graphics.newFont(math.floor(14 * baseScale)))
        love.graphics.setColor(0.35, 0.42, 0.55, 0.6)
        local tierNames = {"Slow", "Medium", "Fast"}
        local titleY = math.floor(h * 0.06)
        love.graphics.printf("Level 2 -- Falling Letters       (" .. tierNames[self.currentTier] .. ")",
                             w / 2, titleY, math.floor(w * 0.7), "center")

             --- Score display (subtle green)
        local scoreAlpha = math.min(1, self.gameTime * 0.5)
        if self.score > 0 or scoreAlpha >= 1 then
            love.graphics.setFont(love.graphics.newFont(math.floor(16 * baseScale)))
            love.graphics.setColor(0.35, 0.65, 0.40, math.min(1, self.gameTime * 0.5))
            love.graphics.printf("Score: " .. self.score, w / 2 - 60 * baseScale,
                                 h * 0.12, 120 * baseScale, "center")
        end

             --- Speed indicator bar (no flash, just progress within tier)
        local speedPercent = math.min(100, math.floor((self.gameTime % 30) / 30 * 100))
        local barW = w * 0.3
        love.graphics.setFont(love.graphics.newFont(math.floor(13 * baseScale)))
        love.graphics.setColor(0.30, 0.35, 0.42, 0.50)
        love.graphics.rectangle("fill", w / 2 - barW / 2, h * 0.82, barW, 8 * baseScale)
        if speedPercent > 0 then
            local tc = {{0.4, 0.85, 0.35}, {0.85, 0.7, 0.35}, {0.85, 0.35, 0.25}}
            love.graphics.setColor(tc[self.currentTier][1], tc[self.currentTier][2],
                                   tc[self.currentTier][3], 0.7)
            love.graphics.rectangle("fill", w / 2 - barW / 2, h * 0.82,
                                    barW * (speedPercent / 100), 8 * baseScale)
        end
        love.graphics.setColor(0.30, 0.35, 0.42, 0.50)
        love.graphics.rectangle("line", w / 2 - barW / 2, h * 0.82, barW, 8 * baseScale)
        love.graphics.printf("Tier: " .. math.min(3, self.currentTier) .. "/3",
                             w / 2, h * 0.76, math.floor(w * 0.5), "center")

            --- Tier selector buttons (bottom-right)
        local btnH = math.floor(28 * baseScale)
        local btnW = math.floor(65 * baseScale)
        local btnGap = math.floor(8 * baseScale)
        local btnX = w - btnW * 3 - btnGap * 2 - 20 * baseScale
        local btnY = h - btnH - 40 * baseScale

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
            love.graphics.setLineWidth(isActive and math.ceil(2 * baseScale) or 1)
            love.graphics.rectangle("line", bx, by, btnW, btnH, 6)
            love.graphics.setLineWidth(1)

                 -- Button text
            love.graphics.setFont(love.graphics.newFont(math.floor(13 * baseScale)))
            if isActive then
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0.65, 0.7, 0.8)
            end
            love.graphics.printf(tierNames[i], bx + btnW / 2,
                                 by + btnH / 2 - 4 * baseScale,
                                 btnW - 8 * baseScale, "center")
        end

             --- Esc hint (always visible at bottom)
        love.graphics.setFont(love.graphics.newFont(math.floor(13 * baseScale)))
        love.graphics.setColor(0.30, 0.35, 0.42, 0.50)
        love.graphics.printf("Press Esc to go back", w / 2, h - 15 * baseScale,
                             w * 0.6, "center")

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
        local groundY = h - math.floor(120 * baseScale)
        local difficulty = math.max(1, (groundY + 200 - target.y) / (h * 0.4))
        self.score = self.score + math.floor(difficulty + 0.5)

             --- Brief green flash on successful hit (subtle, max 8% alpha)
        self.flashAlpha = 0.08
    end,
}
