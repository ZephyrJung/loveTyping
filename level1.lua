-- loveTyping -- Level 1: Intro -- A-Z spheres in QWERTY layout, explode on press.

states["level1"] = {
    flashAlpha = 0,
    instructionsTimer = 5,
    showInstructions = true,
    scoredLetters = {}, -- tracks exploded letters: {"A": timer}
    totalExplosions = 0,
    hintTimer = 3,       -- display "press Esc" hint after all letters done
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
                       .. "      |   Remaining: " .. remaining,
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
