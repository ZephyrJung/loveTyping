-- loveTyping -- Level 3: Night Escape!
-- A top-down city map with geometric buildings and letter-marked roads.
-- The thief (dark circle, red bandana) runs from the start toward the exit.
-- Type correct letters to advance; wrong keys make you stumble.
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
M.letterMarkers = nil

-- === MAP GENERATION ===

--- Build the city: buildings, road waypoints, and letter markers.
local function generate_map()
    seed_rng(math.floor(os.time()) % 100000)
    local blds = {}

    -- Place ~24 buildings avoiding the start and end zones.
    local placed = 0
    while placed < 24 do
        local bw = 22 + next_rng() * 75
        local bh = 18 + next_rng() * 60
        local bx = 30 + next_rng() * (MAP_W - 60 - bw)
        local by = 30 + next_rng() * (MAP_H - 50 - bh)

        -- Keep clear of start zone (bottom-left) and end zone.
        if (bx < 140 and by > MAP_H - 130) or
                  (bx > MAP_W - 140 and by < 130) then goto skip end

        blds[#blds + 1] = {x = bx, y = by, w = bw, h = bh}
        placed = placed + 1
            ::skip::
    end

    -- A winding road from bottom-left to top-right.
    local cp = {
            {x = MAP_W * 0.12, y = MAP_H * 0.86},
            {x = MAP_W * 0.30, y = MAP_H * 0.72},
            {x = MAP_W * 0.50, y = MAP_H * 0.58},
            {x = MAP_W * 0.42, y = MAP_H * 0.35},
            {x = MAP_W * 0.65, y = MAP_H * 0.25},
            {x = MAP_W * 0.78, y = MAP_H * 0.14},
        }

    local wp = {}
    for seg = 1, #cp - 1 do
        local p0 = cp[seg - 1] or cp[seg]
        local p1 = cp[seg]
        local p2 = cp[seg + 1] or cp[#cp]
        local p3 = cp[seg + 2] or p2

        -- Catmull-Rom interpolation for this segment.
        for t = 0, 1, 1 / 8 do
            local t2 = t * t
            local t3 = t2 * t
            local x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t
                             + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2
                             + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
            local y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t
                             + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2
                             + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
            wp[#wp + 1] = {x = x, y = y}
        end
    end

    -- Place letter markers along the road (~every ~8 waypoints).
    local letters = {}
    local used = {}
    local step = math.max(8, math.floor(#wp / 8))
    for i = 2, #wp, step do
        local li = math.floor(next_rng() * 26) + 1
        local ch = string.char(li + 64)

        -- Force uniqueness.
        if used[ch] then
            for c = string.byte('A'), string.byte('Z') do
                local cs = string.char(c)
                if not used[cs] then ch = cs; break end
            end
        end
        used[ch] = true
        letters[#letters + 1] = {x = wp[i].x, y = wp[i].y - 26, letter = ch}
    end

    return blds, wp, letters
end

-- === DRAWING HELPERS ===

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

-- === STATE FUNCTIONS ===

M.onEnter = function(self)
    M.buildings, M.waypoints, M.letterMarkers = generate_map()

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
    M.comboCount = 0                -- consecutive correct keystrokes
    M.stumbleTimer = 0              -- brief freeze after wrong key
    M._gameTime = 0
    M.nextLetterIdx = 1             -- which letter marker to target next
    M.copOffset = -50               -- cop distance from thief (px behind)
    M.gameState = "running"         -- running | won | caught

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

    -- Slowly close the cop's distance over time (pressure mechanic).
    local chaseRate = 5 + math.max(0, M.copOffset or 0) * 0.3
    M.copOffset = (M.copOffset or 0) + chaseRate * dt

    -- Combo decays slowly (encourages continuous typing).
    M.comboCount = math.max(0, (M.comboCount or 0) - 0.08 * dt)

    -- Win / lose checks.
    if M.gameState ~= "running" then return end

    if (M.thiefProgress or 0) >= 0.93 then
        M.gameState = "won"
        return
    end
    if (M.copOffset or 0) >= 12 then
        M.gameState = "caught"
        return
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

    -- Draw the road: thick center line connecting waypoints.
    love.graphics.setLineWidth(18 * sc)
    love.graphics.setColor(0.25, 0.27, 0.32, 0.45)
    for i = 2, #waypoints do
        local a = waypoints[i - 1]
        local b = waypoints[i]
        love.graphics.line(s_x(a.x), s_y(a.y), s_x(b.x), s_y(b.y))
    end

    -- Road edge lines (dashed pattern).
    for i = 2, #waypoints do
        if math.floor(i / 3) % 2 ~= 0 then
            local a = waypoints[i - 1]
            local b = waypoints[i]
            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(0.65, 0.67, 0.70, 0.5)
            love.graphics.line(s_x(a.x), s_y(a.y), s_x(b.x), s_y(b.y))
        end
    end
    love.graphics.setLineWidth(1)

    -- Letter markers along the road.
    local markers = M.letterMarkers or {}
    local targetIdx = math.min(#markers, M.nextLetterIdx or 1)
    for mi, lm in ipairs(markers) do
        local lmx = s_x(lm.x)
        local lmy = s_y(lm.y)
        local mr = 12 * sc
        local isTarget = (mi == targetIdx)

        -- Pulsing glow ring when it's the target letter.
        if isTarget then
            local gt = M._gameTime or 0
            local pr = 14 + math.sin(gt * 6) * 3
            love.graphics.setLineWidth(2)
            local pa = 0.35 + math.sin(gt * 3) * 0.15
            love.graphics.setColor(0.20, 0.55, 0.25, pa)
            love.graphics.circle("line", lmx, lmy, pr + 8)
            love.graphics.circle("line", lmx, lmy, pr + 3)
            love.graphics.setLineWidth(1)

            local bc = {0.25, 0.65, 0.30}
            love.graphics.setColor(bc[1], bc[2], bc[3], 0.85)
        else
            local bc = {0.45, 0.50, 0.55}
            love.graphics.setColor(bc[1], bc[2], bc[3], 0.65)
        end

        -- Marker circle body.
        love.graphics.circle("fill", lmx, lmy, mr)
        love.graphics.setLineWidth(isTarget and 2 or 1.5)
        love.graphics.setColor(0.80, 0.82, 0.85, isTarget and 0.9 or 0.7)
        love.graphics.circle("line", lmx, lmy, mr)
        love.graphics.setLineWidth(1)

        -- Letter label with subtle drop shadow.
        love.graphics.setFont(love.graphics.newFont(math.max(8, math.floor(9 * sc))))
        if isTarget then
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.printf(lm.letter, lmx - 7 * sc, lmy + 1.5 * sc,
                                     14 * sc, "center", 0, 1)
            love.graphics.setColor(1, 0.98, 0.65, 1)
        else
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.printf(lm.letter, lmx - 7 * sc, lmy + 1.5 * sc,
                                     14 * sc, "center", 0, 1)
            love.graphics.setColor(0.90, 0.92, 0.95, 0.85)
        end
        love.graphics.printf(lm.letter, lmx - 8 * sc, lmy + 0.5 * sc,
                               14 * sc, "center", 0, 1)
    end

    -- Start marker (green check circle at beginning of road).
    if #waypoints >= 1 then
        local sw = waypoints[1]
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.30, 0.65, 0.30, 0.6)
        love.graphics.circle("line", s_x(sw.x), s_y(sw.y), 14 * sc)
        love.graphics.setLineWidth(1)
    end

    -- Exit marker (pulsing gold ring at the end).
    if #waypoints >= 1 then
        local ew = waypoints[#waypoints]
        local gt = M._gameTime or 0
        local pulseR = 16 + math.sin(gt * 4) * 3
        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(0.80, 0.65, 0.20,
                               math.min(0.9, gt + 0.1))
        love.graphics.circle("line", s_x(ew.x), s_y(ew.y), pulseR * sc)
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
        local dirA = math.atan2(waypoints[#waypoints].y - waypoints[1].y,
                                waypoints[#waypoints].x - waypoints[1].x)
        -- Cop sits behind the thief along the road direction.
        local copDist = math.max(0, -(M.copOffset or 0)) * sc
        local cpx = thiefSx + math.cos(dirA + math.pi) * copDist
        local cpy = thiefSy + math.sin(dirA + math.pi) * copDist
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

    -- Cop distance warning (red text when cop is close).
    if (M.copOffset or 0) > 5 then
        local warnAlpha = math.min(0.85, ((M.copOffset or 0) - 5) / 7)
        love.graphics.setFont(love.graphics.newFont(math.max(8, 10 * sc)))
        love.graphics.setColor(0.75, 0.20, 0.20, warnAlpha)
        local distText = "Cop is " .. math.floor(math.max(0, -(M.copOffset or 0)))
                            .. "px away!"
        love.graphics.printf(distText, ox + MAP_W * sc / 2, oy + MAP_H * sc + 6,
                              MAP_W * sc / 2 - 4, "left")
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
end

M.onKeyReleased = function(self, key)
    if key == "escape" then changeState("menu"); return end
    if M.gameState ~= "running" then return end

    -- Only respond to letter keys (A-Z / a-z).
    if not key:match("^%a$") then return end

    local upperKey = string.upper(key)
    local markers = M.letterMarkers or {}
    local targetChar = (M.nextLetterIdx and M.nextLetterIdx <= #markers)
                       and markers[M.nextLetterIdx].letter
                       or "?"

    if upperKey == targetChar then
        -- CORRECT: advance thief + speed boost + combo.
        M.comboCount = (M.comboCount or 0) + 1
        M.thiefProgress = math.min(1, (M.thiefProgress or 0) + 0.035)
        M.stumbleTimer = 0

        -- Push cop back slightly on success.
        if (M.copOffset or 0) < 0 then
            M.copOffset = math.max(M.copOffset, (M.copOffset or 0) - 8)
        end

        -- Particle burst at the letter marker position.
        if M.nextLetterIdx and M.nextLetterIdx <= #markers then
            local lm = markers[M.nextLetterIdx]
            addExplosion(s_x(lm.x), s_y(lm.y) + 10, 0.3, 0.75, 0.30, 12)
        end

        -- Advance to next letter marker.
        M.nextLetterIdx = (M.nextLetterIdx or 0) + 1
    else
        -- WRONG: stumble (lose ground, cop closes in).
        M.comboCount = 0
        M.stumbleTimer = 0.6                -- brief freeze frames
        M.thiefProgress = math.max(0, (M.thiefProgress or 0) - 0.01)
        M.copOffset = (M.copOffset or 0) + 3

        -- Red particle burst at thief position.
        local tx, ty = _road_pos(M.thiefProgress or 0)
        addExplosion(tx, ty, 0.75, 0.18, 0.18, 6)
    end
end

return M
