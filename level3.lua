-- loveTyping -- Level 3: Timed -- Monsters with typed strings, laser turret.

states["level3"] = {
    monsters = {},
    fallingLetters = {},              -- floating letters on screen
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
        local barrelAngle = math.pi * 0.35     -- default angle

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
            local laserColor = {0.2, 0.8, 0.3}      -- green laser
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
            self.laserTimer = 0.2     -- 200ms cooldown

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
