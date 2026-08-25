-- loveTyping -- Level 3: Night Escape!
-- A top-down city map with geometric buildings.
-- Characters lie along a winding road from start to exit.
-- The thief (dark circle, red bandana) runs ahead; the cop (blue circle) chases.
-- Type correct letters to move forward; wrong keys keep you in place.
-- Cop advances one step every N seconds -- reach the end before caught!

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

--- Resolve virtual index: maps negative idx to off-road / first elements.
--- thiefIdx=-1 → element 1, thiefIdx=0 → element 2, copIdx=-2 → off-road.
local function _v(idx) return math.max(1, idx + 2) end

--- Convert world coords to screen pixels. Safe even when M.stepping is nil.
local function s_x(mx) return mx * M._sc + M._ox end
local function s_y(my) return my * M._sc + M._oy end

-- Road data: array of {char, x, y} from start to exit.
M.stepping = nil           -- {{char="A", x=..., y=...}, ...}

-- === MAP GENERATION ===

--- Build the city: road stepping-stones with characters assigned to each.
--- Road shape is randomly deformed each run while keeping total length ~constant.
local function generate_map()
    seed_rng(math.floor(os.time()) % 100000)
    local blds = {}

        -- A winding road through city blocks (straight streets only).
    local base_cp = {
               {x = MAP_W * 0.12, y = MAP_H * 0.86},
               {x = MAP_W * 0.35, y = MAP_H * 0.86},        -- same Y (horizontal)
               {x = MAP_W * 0.35, y = MAP_H * 0.62},        -- same X (vertical up)
               {x = MAP_W * 0.15, y = MAP_H * 0.62},        -- same Y (horizontal left)
               {x = MAP_W * 0.15, y = MAP_H * 0.38},        -- same X (vertical up)
               {x = MAP_W * 0.50, y = MAP_H * 0.38},        -- same Y (horizontal right)
               {x = MAP_W * 0.50, y = MAP_H * 0.14},        -- same X (vertical up)
               {x = MAP_W * 0.78, y = MAP_H * 0.14},        -- same Y (horizontal right)
               {x = MAP_W * 0.78, y = MAP_H * 0.07},        -- same X (vertical up to exit)
           }

    local nwp = #base_cp          -- number of waypoints

      --- Compute total length of an array of waypoints.
    local function pathLen(wps)
        local L = 0
        for i = 1, #wps - 1 do
            local dx = wps[i+1].x - wps[i].x
            local dy = wps[i+1].y - wps[i].y
            L = L + math.sqrt(dx*dx + dy*dy)
        end
        return L
    end

     -- Target total length (from base road).
    local targetLen = pathLen(base_cp)

      --- Perturb waypoints: random jitter, then scale to keep ~targetLen.
    local cp = {}
    for i = 1, nwp do
        cp[i] = {x = base_cp[i].x, y = base_cp[i].y}
    end

     -- Apply random offsets (max ±60px per axis on internal waypoints).
    for i = 2, nwp - 1 do
        cp[i].x = cp[i].x + (math.random() * 2 - 1) * 100
        cp[i].y = cp[i].y + (math.random() * 2 - 1) * 40
         -- Clamp to map bounds.
        cp[i].x = math.max(60, math.min(MAP_W - 60, cp[i].x))
        cp[i].y = math.max(60, math.min(MAP_H - 60, cp[i].y))
    end

     -- Iteratively scale offsets to hit target length.
    for iter = 1, 20 do
        local curLen = pathLen(cp)
        if curLen <= 0 then break end
        local scale = targetLen / curLen
         -- Adjust internal waypoints relative to their neighbors' midpoint.
        for i = 2, nwp - 1 do
            local nx = cp[i+1].x - cp[i-1].x    -- delta from prev waypoint
            local ny = cp[i+1].y - cp[i-1].y
            local cx = (cp[i+1].x + cp[i-1].x) / 2
            local cy = (cp[i+1].y + cp[i-1].y) / 2
             -- Scale the offset from center.
            local newOffX = cp[i].x - cx
            local newOffY = cp[i].y - cy
            local targetOff = math.sqrt(newOffX^2 + newOffY^2) * scale
            if targetOff > 0 then
                cp[i].x = cx + (newOffX / targetOff) * targetOff
                cp[i].y = cy + (newOffY / targetOff) * targetOff
            else
                 -- Fallback: just shift by target offset in random direction.
                local ang = math.random() * math.pi * 2
                cp[i].x = cx + math.cos(ang) * 50
                cp[i].y = cy + math.sin(ang) * 50
            end
        end
    end

          -- Compute cumulative distances for proportional interpolation.
    local totalLen = pathLen(cp)
    local segLens = {}
    for seg = 1, nwp - 1 do
        local dx = cp[seg+1].x - cp[seg].x
        local dy = cp[seg+1].y - cp[seg].y
        segLens[#segLens + 1] = math.sqrt(dx*dx + dy*dy)
    end

    local cumul = {0}    -- cumulative distance at each waypoint (0-based)
    for i = 1, nwp - 1 do
        cumul[#cumul + 1] = cumul[i] + segLens[i]
    end

          --- Interpolate position along the road at a given fraction [0, 1].
    local function atFraction(frac)
        local targetDist = frac * totalLen
        for i = 1, nwp - 1 do
            if cumul[i + 1] >= targetDist then
                local segStart = cumul[i]
                local segEnd = cumul[i + 1]
                local p1 = cp[i]
                local p2 = cp[i + 1]
                local segLen = segEnd - segStart
                if segLen > 0 then
                    local t = (targetDist - segStart) / segLen
                    return {x = p1.x + (p2.x - p1.x) * t, y = p1.y + (p2.y - p1.y) * t}
                end
            end
        end
          -- Fallback: last waypoint.
        local last = cp[#cp]
        return {x = last.x, y = last.y}
    end

    local steps = {}
          -- Generate uniformly spaced stepping stones along the road.
    local TARGET = math.max(45, math.min(80, math.floor(totalLen / 35)))
    for i = 0, TARGET - 1 do
        local frac = i / (TARGET - 1)    -- 0 to 1 proportionally along entire road
        steps[i + 1] = atFraction(frac)
    end

           -- Shuffle character pool and expand to keyboard characters.
        local _pool = {}
        for _c = 65, 90 do _pool[#_pool + 1] = string.char(_c) end
        for _c = 48, 57 do _pool[#_pool + 1] = string.char(_c) end
        for _c, _ in ipairs({"!", "@", "#", "$", "%", "&", "*", "+", "=", "."}) do
             _pool[#_pool + 1] = _
        end
          -- Fisher-Yates shuffle
        for _si = #_pool, 2, -1 do
            local _ni = math.random(_si)
              _pool[_si], _pool[_ni] = _pool[_si], _pool[_ni]
        end

           -- Assign shuffled characters to ALL road steps.
        for i = 1, #steps do
            steps[i].char = _pool[math.random(1, #_pool)]
        end

          -- === BUILDING PLACEMENT ALONG BOTH SIDES OF THE ROAD ===
          -- Place ~30-40 buildings along the road at regular intervals.
          -- Each building sits on one side of the road (left or right),
          -- avoiding overlap with road markers and character positions.
    local MAX_BUILDINGS = 36
    local placedCount = 0

         -- Helper: check if a point is far enough from all road steps.
    function nearbyStep(x, y)
        for s = 1, #steps do
            local dx = x - steps[s].x
            local dy = y - steps[s].y
            if math.sqrt(dx*dx + dy*dy) < 70 then return true end
        end
        return false
    end

          -- Helper: check if a point avoids existing buildings.
    function nearbyBuilding(bx, by, bw, bh)
        for bi = 1, #blds do
            local ob = blds[bi]
             -- Check bounding box overlap with 30px padding.
            if bx - 30 < ob.x + ob.w and bx + bw + 30 > ob.x and
               by - 30 < ob.y + ob.h and by + bh + 30 > ob.y then
                return true
            end
        end
        return false
    end

          -- Helper: compute perpendicular offset direction for a waypoint.
    local function perpNormal(idx)
         -- Use segment between idx-1 and idx+1 to determine road direction.
        if idx <= 1 or idx >= #cp then
            return 0, -1    -- edges face "up"
        end
        local dx = cp[idx + 1].x - cp[idx].x
        local dy = cp[idx + 1].y - cp[idx].y
        local len = math.sqrt(dx*dx + dy*dy)
        if len > 0 then
            return -dy / len, dx / len    -- perpendicular (rotated 90deg)
        end
        return 0, -1
    end

          -- Place buildings at intervals along the road.
    local interval = math.max(1, math.floor((#cp - 2) / MAX_BUILDINGS))     -- spacing between placements
    for wpIdx = 2, #cp - 1, interval do
        if placedCount >= MAX_BUILDINGS then break end

         -- Alternate sides: even idx on left side, odd on right side.
        local sideDir = (wpIdx % 2 == 0) and -1 or 1
        local px = cp[wpIdx].x
        local py = cp[wpIdx].y
        local nx, ny = perpNormal(wpIdx)

             -- Offset perpendicular to road direction by 50-90px.
        local offDist = 50 + math.random() * 40
        local bx = px + nx * offDist * sideDir
        local by = py + ny * offDist * sideDir

              -- Clamp to map bounds.
        local bw = 22 + math.random() * 60
        local bh = 18 + math.random() * 45
        bx = math.max(30, math.min(MAP_W - 30 - bw, bx))
        by = math.max(30, math.min(MAP_H - 30 - bh, by))

              -- Ensure placement is far from road steps.
        if not nearbyStep(bx + bw/2, by + bh/2) then
                 -- Avoid overlap with other buildings.
            blds[#blds + 1] = {x = bx, y = by, w = bw, h = bh}
            placedCount = placedCount + 1
        end
    end

    return blds, steps
end

M.onEnter = function(self)
    M.buildings, M.stepping = generate_map()

-- Cop starts one step before the first road element.
-- Thief starts at the first road element (the target character).
    M.thiefIdx = -1                                  -- virtual index (at first element)
    M.copIdx = -2                                    -- virtual index (one step before thief)
    M.stumbleTimer = 0                   -- brief freeze after wrong key
    M._gameTime = 0
    M.gameState = "running"              -- running | won | caught

           -- Cop timer: counts down from DELAY_SECS, then advances by 1 every COP_INTERVAL seconds.
    M.copDelayTimer = 3.0               -- initial delay before cop starts (seconds)
    M._copNextAdvance = M.copDelayTimer -- when the next cop tick fires

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

           -- Cop AI: advances one step every COP_INTERVAL seconds after delay.
    if (M.copDelayTimer or 0) <= 0 and #M.stepping > 1 then
        M.copDelayTimer = 0
        local copInterval = 2.5             -- seconds between each cop tick
        if M._gameTime >= M._copNextAdvance then
            M.copIdx = math.min(#M.stepping - 1, M.copIdx + 1)
            M._copNextAdvance = M._gameTime + copInterval
        end
    else
        M.copDelayTimer = math.max(0, (M.copDelayTimer or 0) - dt)
    end

           -- Combo decays slowly (encourages continuous typing).
    M.comboCount = math.max(0, (M.comboCount or 0) - 0.08 * dt)

           -- Win / lose checks.
    if M.gameState ~= "running" then return end

            -- Thief reaches the last road element: escape!
    local lastIdx = #M.stepping - 1
    if M.thiefIdx >= lastIdx then
        M.gameState = "won"
        return
    end

            -- Cop catches thief when both are on-road (cop past first element).
    if M.copIdx > -1 and M.copIdx >= M.thiefIdx then
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
    love.graphics.setFont(love.graphics.newFont(math.max(10, 14 * sc)))
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
    local steps = M.stepping

    if not steps or #steps < 1 then
               -- Map not generated yet: show a simple placeholder.
        love.graphics.setColor(0.85, 0.87, 0.90)
        love.graphics.rectangle("fill", ox, oy, MAP_W * sc, MAP_H * sc)
        love.graphics.setFont(love.graphics.newFont(math.max(12, 16 * sc)))
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
        for _, b in ipairs(sortedBlds) do
            local sx = s_x(b.x)
            local sy = s_y(b.y)
            local sw = b.w * sc
            local sh = b.h * sc
            love.graphics.push()
            love.graphics.translate(sx, sy)

                       -- Shadow (offset for depth effect).
            love.graphics.setColor(0.18, 0.20, 0.24, 0.35)
            love.graphics.rectangle("fill", 4 * sc, 4 * sc, sw + 6, sh + 6)

                       -- Building faces with flat shading (top face lighter).
            love.graphics.setColor(0.55, 0.57, 0.62)
            love.graphics.rectangle("fill", 0, 0, sw, sh)

                       -- Top edge highlight.
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.70, 0.72, 0.76)
            love.graphics.rectangle("line", 0, 0, sw, sh)

            love.graphics.pop()
        end
    end

    for i = 1, #steps do
        local px = steps[i].x
        local py = steps[i].y
        local spx = s_x(px)
        local spy = s_y(py)
        local spyC = spy - 40 * sc
        local ch = steps[i].char

              -- Draw road connection line between adjacent visible steps.
        if i > 1 then
            local ppx = steps[i - 1].x
            local ppy = steps[i - 1].y
            love.graphics.setLineWidth(2 * sc)
            love.graphics.setColor(0.65, 0.68, 0.72, 0.35)
            love.graphics.line(s_x(ppx), s_y(ppy), spx, spy)
            love.graphics.setLineWidth(1)
        end

             -- Character rendering based on state.
            -- Dark gray at thief position (target), RED for untyped ahead, GREEN for typed behind.
        if i == _v(M.thiefIdx) then
                 -- Target character: dark gray with white hollow circle.
            love.graphics.setLineWidth(2 * sc)
            love.graphics.setColor(1.0, 1.0, 1.0)
            love.graphics.circle('line', spx, spyC, 16 * sc)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.35, 0.35, 0.35)
            love.graphics.printf(ch, spx, spyC, 24 * sc, 'center')
        elseif i > _v(M.thiefIdx) then
                 -- Not yet reached: RED character.
            love.graphics.setColor(0.90, 0.15, 0.15)
            love.graphics.printf(ch, spx, spyC, 24*sc, 'center')
        else
                 -- Already typed/passed: GREEN character (no outline).
            love.graphics.setColor(0.15, 0.65, 0.15)
            love.graphics.printf(ch, spx, spyC, 24*sc, 'center')
        end

            -- Highlight the next target character.
        if i == _v(M.thiefIdx) then
            local gt = M._gameTime or 0
            local pulseR = 16 + math.sin(gt * 5) * 3
            love.graphics.setLineWidth(2 * sc)
            love.graphics.setColor(0.5, 0.5, 0.5, 0.4 + math.sin(gt * 5) * 0.2)
            love.graphics.circle("line", spx, spyC, pulseR * sc + 4 * sc)
            love.graphics.setLineWidth(1)
        end

           -- Draw road edge markers (start / exit).
    if #steps >= 1 then
               -- Start marker: subtle green circle at beginning.
        local sWp = steps[1]
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.30, 0.65, 0.30, 0.6)
        love.graphics.circle("line", s_x(sWp.x), s_y(sWp.y), 14 * sc)
        love.graphics.setLineWidth(1)
    end

           -- Exit marker: pulsing gold ring at the end.
    if #steps >= 1 then
        local eWp = steps[#steps]
        local gt = M._gameTime or 0
        local pulseR = 16 + math.sin(gt * 4) * 3
        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(0.80, 0.65, 0.20,
                               math.min(0.9, gt + 0.1))
        love.graphics.circle("line", s_x(eWp.x), s_y(eWp.y), pulseR * sc)
        love.graphics.setLineWidth(1)
    end
    end

           -- === THIEF CHARACTER ===
           -- Dark circle with a red bandana stripe across the top,
           -- direction arrow pointing toward the exit.
    local thiefPos = steps[_v(M.thiefIdx)]
    if thiefPos then
        local thiefSx = s_x(thiefPos.x + 35)
        local thiefSy = s_y(thiefPos.y + 25)
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
        if #steps >= 2 and M.thiefIdx < #steps - 1 then
            local dirX = steps[#steps].x - steps[1].x
            local dirY = steps[#steps].y - steps[1].y
            local dirA = math.atan2(dirY, dirX)
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
    end


            -- === COP CHARACTER ===
            -- Blue circle with gold badge dot, hat brim, chasing behind.
    local copPos = nil
    if M.copIdx < -1 then
             -- Cop is off-road (before element 1): offset backward by spacing.
        if #steps >= 1 then
            local s1 = steps[1]
            local dirX, dirY = (MAP_W * 0.78 - MAP_W * 0.12), (MAP_H * 0.07 - MAP_H * 0.86)
            local len = math.sqrt(dirX * dirX + dirY * dirY)
            if len > 0 then dirX, dirY = dirX / len, dirY / len end
            copPos = {x = s1.x - dirX * 60, y = s1.y - dirY * 60}
        end
    else
             -- Cop is at element 1 or beyond.
        local cs = steps[_v(M.copIdx)]
        if cs then copPos = cs end
    end
    if copPos then
        local cpx = s_x(copPos.x)
        local cpy = s_y(copPos.y)
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

           -- === HUD: Progress bar showing thief vs cop positions ===
    local hudY = oy + MAP_H * sc + 6
    local barW = math.min(300, MAP_W * sc * 0.7)
    local barH = 12
    local barX = ox + (MAP_W * sc - barW) / 2
    local barY = hudY + 20

               -- Progress bar background.
    love.graphics.setColor(0.30, 0.30, 0.35, 0.5)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4)

               -- Cop marker (red square on progress bar).
    if #steps > 1 then
        local copFrac = math.max(0, (M.copIdx or 0)) / math.max(1, #steps - 1)
        local thiefFrac = math.max(0, (M.thiefIdx or 0)) / math.max(1, #steps - 1)

                   -- Progress fill up to thief.
        love.graphics.setColor(0.25, 0.60, 0.30, 0.4)
        love.graphics.rectangle("fill", barX, barY, barW * thiefFrac, barH, 4)

                   -- Cop dot (red).
        local copDotX = barX + barW * copFrac
        love.graphics.setColor(0.80, 0.15, 0.15)
        love.graphics.circle("fill", copDotX, barY + barH / 2, 6)

                   -- Thief dot (gold).
        local thiefDotX = barX + barW * thiefFrac
        love.graphics.setColor(1.0, 0.85, 0.1)
        love.graphics.circle("fill", thiefDotX, barY + barH / 2, 7)

                   -- Labels.
        love.graphics.setFont(love.graphics.newFont(math.max(8, 9 * sc)))
        love.graphics.setColor(0.85, 0.85, 0.90, 0.7)
        love.graphics.printf("YOU", thiefDotX, barY + barH + 4, 30, "center")
        love.graphics.printf("COP", copDotX, barY + barH + 4, 30, "center")

                   -- Proximity warning.
        if M.thiefIdx - M.copIdx <= 3 and M.copIdx < M.thiefIdx then
            local warnAlpha = math.min(0.9, (4 - (M.thiefIdx - M.copIdx)) * 0.25)
            love.graphics.setColor(0.85, 0.15, 0.15, warnAlpha)
            local distText = "Cop is " .. (M.thiefIdx - M.copIdx) .. " steps behind!"
            love.graphics.printf(distText, barX + barW / 2, barY + barH + 24,
                                 barW, "center")
        end
    end

           -- === HUD: Combo counter (top-right of map area). ===
    if (M.comboCount or 0) > 1 then
        local ca = math.min(0.9, (M.comboCount or 0) / 5)
        love.graphics.setFont(love.graphics.newFont(math.max(8, 11 * sc)))
        love.graphics.setColor(0.75, 0.60, 0.20, ca)
        love.graphics.printf("Combo x" .. math.floor(M.comboCount or 0) .. "!",
                              ox + MAP_W * sc - 4, oy + 4, 90, "right")
    end

           -- === HUD: Timer display (top-left of map area). ===
    if M.gameState == "running" then
        local elapsed = math.floor((M._gameTime or 0))
        local timerSecs = math.max(0, math.ceil(M.copDelayTimer or 0))
        love.graphics.setFont(love.graphics.newFont(math.max(8, 10 * sc)))
        if M.copDelayTimer and M.copDelayTimer > 0 then
            love.graphics.setColor(0.85, 0.70, 0.10, 0.8)
            love.graphics.printf("Cop arrives in " .. timerSecs .. "s",
                                 ox + 4, oy + 4, 120, "left")
        else
            love.graphics.setColor(0.85, 0.20, 0.20, 0.8)
            love.graphics.printf("COP CHASING!", ox + 4, oy + 4, 120, "left")
        end
        love.graphics.setColor(0.50, 0.52, 0.55, 0.6)
        love.graphics.printf("Time: " .. elapsed .. "s",
                             ox + MAP_W * sc - 4, oy + 4, 120, "right")
    end

           -- Game state overlay (won / caught).
    local gt = M._gameTime or 0
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
        local escY = hudY + 36
        love.graphics.setFont(love.graphics.newFont(math.max(8, 9 * sc)))
        love.graphics.setColor(0.50, 0.52, 0.55, 0.6)
        love.graphics.printf("Press Esc to flee back", w / 2 - 20 * sc, escY,
                                   40 * sc, "center")
    end

           -- Countdown: cop starts chasing after delay.
    if (M.copDelayTimer or 0) > 0 then
        local cnt = math.ceil(M.copDelayTimer)
        love.graphics.setFont(love.graphics.newFont(math.max(16, 48 * sc)))
        love.graphics.setColor(0.95, 0.20, 0.10,
                               math.min(1, (M.copDelayTimer or 0) * 0.5))
        love.graphics.printf(cnt .. "!", w / 2, h / 2 - 30,
                             w * 0.6, "center")
           -- Draw a pulsing countdown ring around the thief.
        local pulseR = 16 + math.sin(gt * 8) * 4
        love.graphics.setLineWidth(3 * sc)
        love.graphics.setColor(0.95, 0.20, 0.10, 0.6)
        local thfStep = steps[_v(M.thiefIdx)]
        if thfStep then
            love.graphics.circle("line", s_x(thfStep.x), s_y(thfStep.y),
                                 pulseR * sc)
        end
        love.graphics.setLineWidth(1)
    end
end

M.onKeyReleased = function(self, key)
    if key == "escape" then changeState("menu"); return end
    if M.gameState ~= "running" then return end

      -- On macOS LÖVE2D often sends Shift+key as base physical key ("1") not "!".
      -- Map each physical key to its shifted symbol for lookup.
    local _shifted = {["1"]="!", ["2"]="@", ["3"]="#", ["4"]="$",
              ["5"]="%", ["7"]="&", ["8"]="*", ["="]="+", ["/"]="?",
                    ["+"]="-"}

      -- Only accept printable single-character keys (letters, digits, symbols).
    if #key ~= 1 then return end

    local steps = M.stepping or {}

      -- Find the character at thief's current position.
    local targetChar = nil
    local tIdx = _v(M.thiefIdx or -1)
    if #steps > 0 and steps[tIdx] then
        targetChar = steps[tIdx].char
    end
    targetChar = targetChar or "A"

      -- Try direct match, uppercase, and shifted-equivalent lookups.
    local upperKey = string.upper(key)
    local correct = key == targetChar or upperKey == targetChar or _shifted[key] == targetChar

    if correct then
        M.comboCount = (M.comboCount or 0) + 1
        M.stumbleTimer = 0
        M.thiefIdx = math.min(#steps - 1, (M.thiefIdx or -1) + 1)

          -- Particle burst at the new road position.
        local vIdx = _v(M.thiefIdx)
        if steps[vIdx] then
            addExplosion(s_x(steps[vIdx].x), s_y(steps[vIdx].y), 0.3, 0.75, 0.30, 12)
        end
    else
        M.comboCount = 0
        M.stumbleTimer = 0.6

          -- Red particle burst at current thief position (stumble effect).
        local vIdx = _v(M.thiefIdx)
        if steps[vIdx] then
            addExplosion(s_x(steps[vIdx].x), s_y(steps[vIdx].y), 0.75, 0.18, 0.18, 6)
        end
    end
end


return M