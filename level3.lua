-- loveTyping -- Level 3: Night Escape!
-- A top-down city map with geometric buildings.
-- Characters lie along straight streets (horizontal and vertical only).
-- The thief (dark circle, red bandana) runs from the start toward the exit.
-- Type correct letters to run; wrong keys make you stumble.
-- The cop chases from behind -- reach the end before getting caught!

local M = {}
states["level3"] = M

-- Map dimensions in world pixels.
local MAP_W = 860
local MAP_H = 520

--- Seeded pseudo-random (multiply-additive congruential PRNG).
local rng_s = nil
local function seed_rng(s) rng_s = s end
local function next_rng()
    rng_s = (rng_s * 1103515245 + 12345) % (2^31)
    return math.abs(rng_s) / (2^31)
end

-- Screen scale and offset: map coord -> screen coord.
M._sc = 1
M._ox = 0
M._oy = 0

--- Convert world coords to screen pixels. Safe even when M.waypoints is nil.
local function s_x(mx) return mx * M._sc + M._ox end
local function s_y(my) return my * M._sc + M._oy end

-- Map data (nil until onEnter runs).
M.buildings = nil
M.waypoints = nil
M.pathChars = nil         -- char at each waypoint: {"A", "B", ...}

-- === MAP GENERATION ===

--- Build the city: buildings and road characters.
local function generate_map()
    seed_rng(math.floor(os.time()) % 100000)
    local blds = {}

            -- A winding road through city blocks (straight streets only).
    local cp = {
                {x = MAP_W * 0.12, y = MAP_H * 0.86},
                {x = MAP_W * 0.35, y = MAP_H * 0.86},     -- same Y (horizontal)
                {x = MAP_W * 0.35, y = MAP_H * 0.62},     -- same X (vertical up)
                {x = MAP_W * 0.15, y = MAP_H * 0.62},     -- same Y (horizontal left)
                {x = MAP_W * 0.15, y = MAP_H * 0.38},     -- same X (vertical up)
                {x = MAP_W * 0.50, y = MAP_H * 0.38},     -- same Y (horizontal right)
                {x = MAP_W * 0.50, y = MAP_H * 0.14},     -- same X (vertical up)
                {x = MAP_W * 0.78, y = MAP_H * 0.14},     -- same Y (horizontal right)
                {x = MAP_W * 0.78, y = MAP_H * 0.07},     -- same X (vertical up to exit)
            }

    local wp = {}
    for seg = 1, #cp - 1 do
        local p1 = cp[seg]
        local p2 = cp[seg + 1]
        local dx = p2.x - p1.x      -- purely horizontal or vertical
        local dy = p2.y - p1.y

            -- Straight Manhattan-style interpolation (no curves).
        local segLen = math.sqrt(dx * dx + dy * dy)
        local totalPts = math.floor(segLen / 15)      -- spacing ~15 world pixels     -- spacing ~4 world pixels
        for pIdx = 1, totalPts do
            local t = pIdx / totalPts
            wp[#wp + 1] = {x = p1.x + dx * t, y = p1.y + dy * t}
        end
    end


           -- Place ~24 buildings avoiding the road.
    local placed = 0
    while placed < 24 do
        local bw = 22 + next_rng() * 75
        local bh = 18 + next_rng() * 60
        local bx = 30 + next_rng() * (MAP_W - 60 - bw)
        local by = 30 + next_rng() * (MAP_H - 50 - bh)

               -- Keep clear of start zone (bottom-left) and end zone.
        if (bx < 140 and by > MAP_H - 130) or
                      (bx > MAP_W - 140 and by < 130) then goto skip end

               -- Keep clear of all road waypoints.
        local tooClose = false
        for wi = 1, #wp do
            local ddx = bx + bw / 2 - wp[wi].x
            local ddy = by + bh / 2 - wp[wi].y
            if math.sqrt(ddx * ddx + ddy * ddy) < 50 then
                tooClose = true
                break
            end
        end
        if tooClose then goto skip end

        blds[#blds + 1] = {x = bx, y = by, w = bw, h = bh}
        placed = placed + 1
               ::skip::
    end

          -- Assign a random keyboard character to each road step.
    local chars = {}
    for i = 1, #wp do
        chars[i] = string.char(math.floor(next_rng() * 26) + 65)
    end

    return blds, wp, chars
end

-- === DRAWING HELPERS ===

--- Draw a flat-shaded geometric building with shadow offset for depth.
local function _draw_building(b)
    local sx = s_x(b.x)
    local sy = s_y(b.y)
    local sw = b.w * M._sc
    local sh = b.h * M._sc

    love.graphics.push()
    love.graphics.translate(sx, sy)

         -- Shadow (offset for depth effect).
    love.graphics.setColor(0.18, 0.20, 0.24, 0.35)
    love.graphics.rectangle("fill", 4 * M._sc, 4 * M._sc, sw + 6, sh + 6)

         -- Building faces with flat shading (top face lighter).
    love.graphics.setColor(0.55, 0.57, 0.62)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

         -- Top edge highlight.
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.70, 0.72, 0.76)
    love.graphics.rectangle("line", 0, 0, sw, sh)

    love.graphics.pop()
end

--- Compute the screen position of a point along the road at given progress (0..1).
local function _road_pos(progress)
    local waypoints = M.waypoints
    if not waypoints or #waypoints < 1 then
        return s_x(MAP_W * 0.12), s_y(MAP_H * 0.86)
    end

    local totalLen = M._totalLen
    if not totalLen or totalLen <= 0 then totalLen = 1 end

    local tgtDist = progress * totalLen
    local acc = 0
    for i = 2, #waypoints do
        local dx = waypoints[i].x - waypoints[i - 1].x
        local dy = waypoints[i].y - waypoints[i - 1].y
        local segLen = math.sqrt(dx * dx + dy * dy)
        if acc + segLen >= tgtDist then
            local frac = (tgtDist - acc) / segLen
            return s_x(waypoints[i - 1].x + dx * frac),
                   s_y(waypoints[i - 1].y + dy * frac)
        end
        acc = acc + segLen
    end
    return s_x(waypoints[#waypoints].x), s_y(waypoints[#waypoints].y)
end

-- === STATE FUNCTIONS ===

M.onEnter = function(self)
    M.buildings, M.waypoints, M.pathChars = generate_map()

          -- Precompute total road length for progress scaling.
    local totalLen = 0
    if M.waypoints then
        for i = 2, #M.waypoints do
            local dx = M.waypoints[i].x - M.waypoints[i - 1].x
            local dy = M.waypoints[i].y - M.waypoints[i - 1].y
            totalLen = totalLen + math.sqrt(dx * dx + dy * dy)
        end
    end
    M._totalLen = math.max(totalLen, 1)

          -- Thief progress: 0.0 (start) to 1.0 (exit).
    M.thiefProgress = 0
    M.step = 0                            -- characters typed
    M.comboCount = 0                  -- consecutive correct keystrokes
    M.stumbleTimer = 0                -- brief freeze after wrong key
    M._gameTime = 0
    M.copProgress = -8                -- starts 8% of road behind
    M.copDelayTimer = 3.0           -- seconds before cop starts

          -- Camera state: how much the map is shifted.
    M.camOffsetX = 0
    M.camOffsetY = 0
end

M.onUpdate = function(self, dt)
    M._gameTime = (M._gameTime or 0) + dt

          -- Screen scale/offset: compute once per frame for onKeyReleased.
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local titleBar = 36
    local hudSpace = 50
    local availW = math.max(40, w - 40)
    local availH = math.max(86, h - titleBar - hudSpace)
    M._sc = math.min(availW / MAP_W, availH / MAP_H)
    M._ox = 20 + (availW - MAP_W * M._sc) / 2
    M._oy = titleBar + (availH - MAP_H * M._sc) / 2

          -- Stumble cooldown.
    if (M.stumbleTimer or 0) > 0 then
        M.stumbleTimer = (M.stumbleTimer or 0) - dt
    end

             -- Cop only chases after countdown finishes
             if (M.copDelayTimer or 0) <= 0 then
                 M.copDelayTimer = 0
                 local copSpeed = 2.0
                 local thiefProgVal = (M.thiefProgress or 0)
                 if (M.copProgress or 0) < thiefProgVal then
                     M.copProgress = math.min(thiefProgVal, (M.copProgress or 0) + copSpeed * dt)
                 end
             else
                 M.copDelayTimer = math.max(0, (M.copDelayTimer or 0) - dt)
             end
          -- Combo decays slowly (encourages continuous typing).
    M.comboCount = math.max(0, (M.comboCount or 0) - 0.08 * dt)

          -- Win / lose checks.
    if M.gameState ~= "running" then return end

    if (M.thiefProgress or 0) >= 0.93 then
        M.gameState = "won"
        return
    end
    if (M.copProgress or 0) >= (M.thiefProgress or 0) then
        M.gameState = "caught"
    end
end

M.onDraw = function(self)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

          -- Background: white / near-white (light city feel).
    love.graphics.setColor(0.95, 0.96, 0.98)
    love.graphics.rectangle("fill", 0, 0, w, h)

          -- Scale/offset: use module-level values with safe defaults for first frame.
    local sc = M._sc or 1
    local ox = M._ox or 0
    local oy = M._oy or 0

          -- Title bar at the top of the map area.
    local title = "Level 3 -- Night Escape"
    if M.gameState == "won" then title = "Level 3 -- YOU ESCAPED!"
    elseif M.gameState == "caught" then title = "Level 3 -- CAUGHT!" end
    love.graphics.setFont(love.graphics.newFont(14))
    local tcol
    if M.gameState == "won" then
        tcol = {0.25, 0.60, 0.45}
    elseif M.gameState == "caught" then
        tcol = {0.55, 0.15, 0.45}
    else
        tcol = {0.35, 0.45, 0.45}
    end
    love.graphics.setColor(tcol[1], tcol[2], tcol[3], 0.7)
    love.graphics.printf(title, w / 2, 10, w * 0.8, "center")

          -- Guard: check if map has been initialized.
    local blds = M.buildings
    local waypoints = M.waypoints
    local chars = M.pathChars

    if not waypoints or #waypoints < 1 then
              -- Map not generated yet: show a simple placeholder.
        love.graphics.setColor(0.85, 0.87, 0.90)
        love.graphics.rectangle("fill", ox, oy, MAP_W * sc, MAP_H * sc)
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(0.35, 0.42, 0.55)
        love.graphics.printf("Loading map...", w / 2, h / 2, w * 0.5, "center")
        return
    end

          -- Map area background (subtle off-white grid).
    love.graphics.setColor(0.93, 0.94, 0.96)
    love.graphics.rectangle("fill", ox, oy, MAP_W * sc, MAP_H * sc)

          -- Grid lines on the ground (subtle).
    love.graphics.setLineWidth(0.5)
    love.graphics.setColor(0.87, 0.89, 0.91, 0.6)
    for gx = 0, MAP_W, 40 do
        love.graphics.line(gx * sc + ox, oy,
                           gx * sc + ox, oy + MAP_H * sc)
    end
    for gy = 0, MAP_H, 40 do
        love.graphics.line(ox, gy * sc + oy,
                           ox + MAP_W * sc, gy * sc + oy)
    end
    love.graphics.setLineWidth(1)

          -- Draw geometric buildings (Y-sorted for depth).
    if blds then
        local sortedBlds = {}
        for _, b in ipairs(blds) do sortedBlds[#sortedBlds + 1] = b end
        table.sort(sortedBlds, function(a, b) return a.y < b.y end)
        for _, b in ipairs(sortedBlds) do _draw_building(b) end
    end
         -- Draw the road: characters only, no lines or decorations.
          local thiefIdx = math.floor((M.thiefProgress or 0) * #waypoints) + 1

          for i = 1, #waypoints do
              local px = waypoints[i].x
              local py = waypoints[i].y
              local spx = s_x(px)
              local spy = s_y(py)
              local ch = chars[i]

               -- Draw all road characters. High contrast for visibility.
               if i == thiefIdx then
                   -- Target: gold character with white hollow circle
                   love.graphics.setLineWidth(2 * sc)
                   love.graphics.setColor(1.0, 1.0, 1.0)
                   love.graphics.circle('line', spx, spy, 16 * sc)
                   love.graphics.setLineWidth(1)
                   love.graphics.setColor(1.0, 0.85, 0.1)
                   love.graphics.printf(ch, spx, spy, 24 * sc, 'center')
               elseif i < thiefIdx then
                   -- Typed: GREEN character (no outline, small glow only)
                   love.graphics.setColor(0.15, 0.65, 0.15)
                   love.graphics.printf(ch, spx, spy, 24*sc, 'center')
               else
                   -- Untyped: RED character (waiting)
                   love.graphics.setColor(0.90, 0.15, 0.15)
                   love.graphics.printf(ch, spx, spy, 24*sc, 'center')
               end

          end

           -- Draw road edge markers (start / exit).
    if #waypoints >= 1 then
                   -- Start marker: subtle green circle at beginning.
        local sWp = waypoints[1]
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.30, 0.65, 0.30, 0.6)
        love.graphics.circle("line", s_x(sWp.x), s_y(sWp.y), 14 * sc)
        love.graphics.setLineWidth(1)
    end

           -- Exit marker: pulsing gold ring at the end.
    if #waypoints >= 1 then
        local eWp = waypoints[#waypoints]
        local gt = M._gameTime or 0
        local pulseR = 16 + math.sin(gt * 4) * 3
        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(0.80, 0.65, 0.20,
                               math.min(0.9, gt + 0.1))
        love.graphics.circle("line", s_x(eWp.x), s_y(eWp.y), pulseR * sc)
        love.graphics.setLineWidth(1)
    end


          -- === THIEF CHARACTER ===
          -- Dark circle with a red bandana stripe across the top,
          -- direction arrow pointing toward the exit.
    local thiefSx, thiefSy = _road_pos(M.thiefProgress or 0)
    local thiefR = 9 * sc
    local gt = M._gameTime or 0
    local bobY = math.sin(gt * ((M.stumbleTimer and M.stumbleTimer > 0) and 2 or 8))
                     * 2 * sc

    love.graphics.push()
    love.graphics.translate(thiefSx, thiefSy + bobY)

          -- Shadow underneath.
    love.graphics.setColor(0.15, 0.16, 0.18, 0.30)
    love.graphics.circle("fill", 2 * sc, thiefR + 2, thiefR * 0.45)

          -- Body: dark circle (silhouette).
    love.graphics.setColor(0.12, 0.10, 0.16)
    love.graphics.circle("fill", 0, 0, thiefR)

          -- Red bandana stripe across the top half.
    love.graphics.setLineWidth(3 * sc)
    love.graphics.setColor(0.75, 0.15, 0.18)
    love.graphics.circle("fill", 0, -thiefR * 0.15, thiefR * 0.65)

          -- Direction arrow (points toward exit).
    if #waypoints >= 2 and (M.thiefProgress or 0) < 1 then
        local dirA = math.atan2(waypoints[#waypoints].y - waypoints[1].y,
                                waypoints[#waypoints].x - waypoints[1].x)
        local aLen = thiefR + 7 * sc
        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0.80, 0.65, 0.20, 0.45)
        love.graphics.line(0, 0, math.cos(dirA) * aLen, math.sin(dirA) * aLen)
        for sign = -1, 1, 2 do
            local off = dirA + sign * 0.35
            love.graphics.line(math.cos(dirA) * aLen, math.sin(dirA) * aLen,
                               math.cos(off) * (aLen - 4 * sc),
                               math.sin(off) * (aLen - 4 * sc))
        end
    end

    love.graphics.pop()

          -- === COP CHARACTER ===
          -- Blue circle with gold badge dot, hat brim, chasing behind.
    if #waypoints >= 2 then
               -- Cop follows the character path. Position based on copProgress.
        local cProg = math.max(0, (M.copProgress or 0))
        local cpx, cpy = _road_pos(cProg)
        local copR = 8 * sc

              -- Only draw cop if visible on screen.
        if cpx >= ox - 20 and cpx <= ox + MAP_W * sc + 20 and
               cpy >= oy - 20 and cpy <= oy + MAP_H * sc + 20 then
            love.graphics.push()
            love.graphics.translate(cpx, cpy)

                      -- Shadow.
            love.graphics.setColor(0.15, 0.16, 0.18, 0.35)
            love.graphics.circle("fill", 2 * sc, copR + 2, copR * 0.45)

                      -- Body: blue circle (police uniform).
            love.graphics.setColor(0.18, 0.28, 0.50)
            love.graphics.circle("fill", 0, 0, copR)

                      -- Gold badge on chest.
            love.graphics.setLineWidth(2 * sc)
            love.graphics.setColor(0.85, 0.80, 0.25)
            love.graphics.circle("fill", 0, -copR * 0.15, 2.5 * sc)

                      -- Hat brim (horizontal bar across top).
            love.graphics.rectangle("fill", -copR * 0.6, copR * 0.3,
                                    copR * 1.2, 1.5 * sc)

            love.graphics.pop()
        end
    end

          -- === HUD (simplified: no speed bar or progress indicator) ===
    local hudY = oy + MAP_H * sc + 6

          -- Combo counter (top-right of map area).
    if (M.comboCount or 0) > 1 then
        local ca = math.min(0.9, (M.comboCount or 0) / 5)
        love.graphics.setFont(love.graphics.newFont(math.max(8, 11 * sc)))
        love.graphics.setColor(0.75, 0.60, 0.20, ca)
        love.graphics.printf("Combo x" .. math.floor(M.comboCount or 0) .. "!",
                              ox + MAP_W * sc - 4, oy + 4, 90, "right")
    end

-- Cop proximity warning (turns red as cop gets closer).
    local cProg = math.max(0, (M.copProgress or 0))
    local tProg = (M.thiefProgress or 0)
    if cProg > 0 and cProg < tProg then
        local gapFrac = (tProg - cProg) / 0.93       -- normalize to 0..1
        local warnAlpha = math.min(0.85, (1 - gapFrac) * 0.8)
        if warnAlpha > 0.05 then
            local gapChars = math.floor(gapFrac * #waypoints + 0.5)
            love.graphics.setFont(love.graphics.newFont(math.max(8, 10 * sc)))
            love.graphics.setColor(0.75, 0.20, 0.20, warnAlpha)
            local distText = "Cop is " .. gapChars .. " chars away!"
            love.graphics.printf(distText, ox + MAP_W * sc / 2,
                                 oy + MAP_H * sc + 6,
                                 MAP_W * sc / 2 - 4, "left")
        end
    end

          -- Game state overlay (won / caught).
    if M.gameState == "won" then
        local fa = math.min(0.55, gt * 0.3)
        love.graphics.setColor(0.20, 0.55, 0.25, fa)
        love.graphics.rectangle("fill", ox, oy, MAP_W * sc, MAP_H * sc)
        love.graphics.setFont(love.graphics.newFont(math.max(14, 20 * sc)))
        love.graphics.setColor(0.30, 0.75, 0.35, 0.9)
        love.graphics.printf("YOU ESCAPED!", ox + MAP_W * sc / 2 - 40 * sc,
                              oy + MAP_H * sc / 2 - 8, 80 * sc, "center")
    elseif M.gameState == "caught" then
        local fa = math.min(0.65, gt * 0.35)
        love.graphics.setColor(0.55, 0.12, 0.12, fa)
        love.graphics.rectangle("fill", ox, oy, MAP_W * sc, MAP_H * sc)
        love.graphics.setFont(love.graphics.newFont(math.max(14, 20 * sc)))
        love.graphics.setColor(0.75, 0.22, 0.22, 0.9)
        love.graphics.printf("CAUGHT!", ox + MAP_W * sc / 2 - 30 * sc,
                              oy + MAP_H * sc / 2 - 8, 60 * sc, "center")
    end

          -- Map boundary outline.
    love.graphics.setLineWidth(1.5)
    local bdrCol
    if M.gameState == "won" then
        bdrCol = {0.3, 0.65, 0.3}
    elseif M.gameState == "caught" then
        bdrCol = {0.7, 0.2, 0.2}
    else
        bdrCol = {0.45, 0.48, 0.52}
    end
    love.graphics.setColor(bdrCol[1], bdrCol[2], bdrCol[3], 0.6)
    love.graphics.rectangle("line", ox, oy, MAP_W * sc, MAP_H * sc)
    love.graphics.setLineWidth(1)

          -- Esc hint (outside map area).
    if M.gameState == "running" then
        local escY = hudY + 22
        love.graphics.setFont(love.graphics.newFont(math.max(8, 9 * sc)))
        love.graphics.setColor(0.50, 0.52, 0.55, 0.6)
        love.graphics.printf("Press Esc to flee back", w / 2 - 20 * sc, escY,
                                40 * sc, "center")
    end

    -- Countdown: cop starts chasing after delay
    if (M.copDelayTimer or 0) > 0 then
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        local cnt = math.ceil(M.copDelayTimer)
        local bigFont = love.graphics.newFont(math.max(16, 40 * M._sc))
        love.graphics.setFont(bigFont)
        love.graphics.setColor(0.15, 0.15, 0.25, math.min(1, (M.copDelayTimer or 0) * 0.3))
        love.graphics.printf("GET READY! " .. tostring(cnt), w / 2, h / 2,
                                 w * 0.6, "center")
    end
end

M.onKeyReleased = function(self, key)
    if key == "escape" then changeState("menu"); return end
    if M.gameState ~= "running" then return end

           -- Only respond to letter keys (A-Z / a-z).
    if not key:match("^%a$") then return end

    local upperKey = string.upper(key)
    local waypoints = M.waypoints
    local chars = M.pathChars

        -- Find the character at our current road position.
    local targetChar = nil
    if waypoints and #waypoints >= 1 then
        local thiefIdx = math.min(#waypoints, math.floor((M.thiefProgress or 0) * #waypoints) + 1)
        targetChar = chars[thiefIdx]
    end
    targetChar = targetChar or "A"

    if upperKey == targetChar then
        -- CORRECT: advance thief along the road.
        M.comboCount = (M.comboCount or 0) + 1
         -- Advance by one character per correct key press
         M.step = (M.step or 0) + 1
         M.thiefProgress = math.min(1, M.step / #waypoints)
        M.stumbleTimer = 0

                -- Dash: push cop back by a few characters when hitting correctly.
            local cProg = math.max(0, (M.copProgress or 0))
            M.copProgress = math.max(-8, cProg - 3 * (#waypoints > 0 and 1 / #waypoints or 0))

                -- Particle burst at the current road position.
        local tx, ty = _road_pos((M.thiefProgress or 0) - 0.035)
        addExplosion(tx, ty, 0.3, 0.75, 0.30, 12)
    else
        -- WRONG: stumble (lose ground, cop closes in).
        M.comboCount = 0
        M.stumbleTimer = 0.6                     -- brief freeze frames
        M.thiefProgress = math.max(0, (M.thiefProgress or 0) - 0.01)

                -- Red particle burst at thief position.
        local tx, ty = _road_pos((M.thiefProgress or 0) + 0.01)
        addExplosion(tx, ty, 0.75, 0.18, 0.18, 6)
    end
end

return M
