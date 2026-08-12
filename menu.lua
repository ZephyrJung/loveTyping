-- loveTyping -- Menu state: glowing buttons for each difficulty level.

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
            love.graphics.printf(names[id] .. "    [1-" .. tostring(id) .. "]",
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
