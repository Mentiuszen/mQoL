local addonName, L = ...
mQoL_Hub = mQoL_Hub or {}

-- Utility functions
local function EaseOutCubic(t)
    return 1 - (1 - t)^3
end

local function EaseInOutQuad(t)
    if t < 0.5 then return 2 * t * t end
    return -1 + (4 - 2 * t) * t
end

local function EaseOutQuint(t)
    return 1 - (1 - t)^5
end

local function EaseInOutCubic(t)
    if t < 0.5 then return 4 * t * t * t end
    return 1 - ((-2 * t + 2)^3) / 2
end

-- Create a single letter frame
local function CreateLetter(parent, char, fontSize, relativeTo, offsetX)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(fontSize, fontSize)
    
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    fs:SetPoint("CENTER")
    fs:SetText(char)
    fs:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE") 
    fs:SetTextColor(1, 0.82, 0)
    
    f.finalX = offsetX
    f.finalY = 0
    
    return f, fs
end

function mQoL_Hub:RunHomeIntro(parent, finalContentFrame)
    -- Force hide content immediately and reliably
    finalContentFrame:SetAlpha(0)
    finalContentFrame:Hide()

    local intro = CreateFrame("Frame", nil, parent)
    intro:SetAllPoints()
    intro:SetFrameLevel(parent:GetFrameLevel() + 50)

    -- Block all clicks during animation
    intro:EnableMouse(true)
    intro:SetScript("OnMouseDown", function() end)

    -- Get parent dimensions for full-space usage
    local parentWidth = parent:GetWidth() or 700
    local parentHeight = parent:GetHeight() or 500

    -- Tornado Particle Container
    local particleContainer = CreateFrame("Frame", nil, intro)
    particleContainer:SetAllPoints()

    local particles = {}
    local numParticles = 140 -- Good density

    -- Tornado rotation direction (-1 = CCW, 1 = CW)
    local rotationDir = -1 

    -- Bottom of funnel (narrow, near ground level)
    local funnelBottomY = -parentHeight * 0.35
    -- Top of funnel (wide, cloud level)
    local funnelTopY = parentHeight * 0.30
    local funnelHeight = funnelTopY - funnelBottomY

    -- Center X position (will sway gently)
    local funnelCenterX = 0

    -- Funnel radius parameters (WIDER at top, NARROWER at bottom)
    local radiusAtTop = 320      -- Wide at top (cloud base)
    local radiusAtBottom = 30    -- Narrow at bottom (ground contact)

    for i = 1, numParticles do
        local p = particleContainer:CreateTexture(nil, "BACKGROUND")

        -- Use basic texture for all version compatibility (no fancy assets)
        local debrisType = math.random(1, 5)
        if debrisType == 1 then
            -- Dust/cloud particle
            p:SetTexture("Interface\\Buttons\\WHITE8X8")
            p:SetBlendMode("ADD")
            p:SetVertexColor(0.5, 0.45, 0.35, math.random(20, 45)/100)
            local size = math.random(10, 30)
            p:SetSize(size, size)
        elseif debrisType == 2 then
            -- Sharp debris shard
            p:SetTexture("Interface\\Buttons\\WHITE8X8")
            p:SetVertexColor(0.4, 0.35, 0.28, math.random(35, 65)/100)
            local width = math.random(1, 3)
            local length = math.random(10, 28)
            p:SetSize(length, width)
        elseif debrisType == 3 then
            -- Wind streak
            p:SetTexture("Interface\\Buttons\\WHITE8X8")
            p:SetBlendMode("ADD")
            p:SetVertexColor(0.75, 0.8, 0.85, math.random(12, 30)/100)
            local width = math.random(1, 2)
            local length = math.random(20, 50)
            p:SetSize(length, width)
        elseif debrisType == 4 then
            -- Larger debris chunk
            p:SetTexture("Interface\\Buttons\\WHITE8X8")
            p:SetVertexColor(0.3, 0.25, 0.2, math.random(45, 75)/100)
            local size = math.random(4, 9)
            p:SetSize(size, size)
        else
            -- Fine dust
            p:SetTexture("Interface\\Buttons\\WHITE8X8")
            p:SetBlendMode("ADD")
            p:SetVertexColor(0.7, 0.65, 0.55, math.random(8, 20)/100)
            local size = math.random(5, 15)
            p:SetSize(size, size)
        end
        
        -- Distribute particles along the funnel height (0 = bottom, 1 = top)
        local heightPos = math.random() 
        local angle = math.rad(math.random(0, 360))
        
        -- Calculate radius based on height (wider at top, narrower at bottom)
        local baseRadius = radiusAtBottom + (radiusAtTop - radiusAtBottom) * heightPos
        local radius = baseRadius * (0.75 + math.random() * 0.5) -- Add variance
        
        -- Rotation speed varies - MUCH faster at bottom, slower at top (realistic vortex)
        local speedFactor = 2.5 - heightPos * 1.8 
        
        table.insert(particles, {
            texture = p,
            angle = angle,
            heightPos = heightPos,
            baseHeightPos = heightPos,
            radius = radius,
            baseRadius = baseRadius,
            speed = (math.random(35, 80) / 10) * speedFactor * rotationDir,
            verticalDrift = (math.random(-25, 35) / 100),
            wobble = math.random() * math.pi * 2,
            wobbleSpeed = math.random(2, 5),
            wobbleAmp = math.random(8, 18) / 100,
        })
        
        p:SetPoint("CENTER", 0, 0) -- Will be positioned in OnUpdate
    end

    -- TORNADO LOGO LETTERS (After Animated Debris)
    local logoCenterY = 20
    local logoFrame = CreateFrame("Frame", nil, intro)
    logoFrame:SetSize(600, 150)
    logoFrame:SetPoint("CENTER", 0, logoCenterY)

    local fontSize = 96
    local lettersData = {
        { char = "m", off = -110 },
        { char = "Q", off = -25 },
        { char = "o", off = 40 },
        { char = "L", off = 90 }
    }
    
    local letters = {}
    for i, data in ipairs(lettersData) do
        local f, fs = CreateLetter(logoFrame, data.char, fontSize, logoFrame, data.off)
        f:SetAlpha(0)
        table.insert(letters, { frame = f, fs = fs, data = data })
    end

    -- Version Text
    local verText = logoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    verText:SetPoint("TOPRIGHT", letters[4].frame, "BOTTOMRIGHT", 20, 5)
    verText:SetText("v." .. (mQoL_Hub.version or "1.1.0"))
    verText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    verText:SetTextColor(1, 1, 1, 0.8)
    verText:SetAlpha(0)

    -- Blue Floor Line
    local lineFrame = CreateFrame("Frame", nil, intro)
    lineFrame:SetSize(1, 4) 
    lineFrame:SetPoint("TOP", logoFrame, "BOTTOM", 0, 10)

    local line = lineFrame:CreateTexture(nil, "ARTWORK")
    line:SetAllPoints()
    line:SetColorTexture(0.3, 0.7, 1)

    -- ANIMATION STATE MACHINE
    local startTime = GetTime()
    local tornadoDuration = 1.2 -- Phase 1 Tornado chaos (quick but visible)
    local settleDuration = 0.8  -- Phase 2 Letters land (smooth transition)
    local totalDuration = tornadoDuration + settleDuration
    local debrisHidden = false

    intro:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local timePassed = now - startTime

        -- UPDATE VERTICAL TORNADO FUNNEL PARTICLES
        if timePassed < totalDuration then
            local phaseProgress = math.min(1, timePassed / tornadoDuration)

            -- Gentle horizontal sway
            local swayAmount = 30 * (1 - phaseProgress * 0.7)
            local swayX = math.sin(timePassed * 1.5) * swayAmount

            -- Funnel contracts slightly as animation progresses
            local radiusScale = 1.0 - phaseProgress * 0.35

            for _, p in ipairs(particles) do
                -- Rotate around vertical funnel axis
                p.angle = p.angle + (p.speed * elapsed)

                -- Vertical drift
                p.heightPos = p.heightPos + p.verticalDrift * elapsed

                -- Wrap around if particle goes out of bounds
                if p.heightPos > 1.12 then
                    p.heightPos = -0.12
                elseif p.heightPos < -0.12 then
                    p.heightPos = 1.12
                end

                local clampedHeight = math.max(0, math.min(1, p.heightPos))

                -- Calculate Y position along the vertical funnel
                local spineY = funnelBottomY + clampedHeight * funnelHeight

                -- X position follows the sway more at top than bottom
                local swayInfluence = clampedHeight * 0.8 + 0.2
                local spineX = funnelCenterX + swayX * swayInfluence

                -- Calculate radius at this height (wider at top, narrower at bottom)
                local radiusAtHeight = (radiusAtBottom + (radiusAtTop - radiusAtBottom) * clampedHeight) * radiusScale

                -- Add wobble for organic turbulence
                p.wobble = p.wobble + p.wobbleSpeed * elapsed
                local wobbleOffset = math.sin(p.wobble) * radiusAtHeight * p.wobbleAmp

                local currentRadius = radiusAtHeight + wobbleOffset

                -- Simple horizontal rotation (circular orbit around vertical axis)
                local rotX = currentRadius * math.cos(p.angle)
                local rotZ = currentRadius * math.sin(p.angle) * 0.45 -- Compress for 3D perspective

                local finalX = spineX + rotX
                local finalY = spineY + rotZ * 0.3 -- Slight vertical offset for depth

                p.texture:ClearAllPoints()
                p.texture:SetPoint("CENTER", particleContainer, "CENTER", finalX, finalY)

                -- Depth-based alpha
                local depthFactor = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(p.angle))
                local r, g, b = p.texture:GetVertexColor()

                -- Fade out during settle phase
                local alphaBase = depthFactor * 0.85
                if timePassed > tornadoDuration then
                     local settleProg = (timePassed - tornadoDuration) / settleDuration
                     alphaBase = alphaBase * (1 - settleProg)
                end

                p.texture:SetVertexColor(r, g, b, alphaBase)
            end
        end

        -- ANIMATE LETTERS
        if timePassed < tornadoDuration then
            -- LETTERS CAUGHT IN TORNADO
            local phaseProgress = timePassed / tornadoDuration

            local alpha = math.min(1, phaseProgress * 2.0) 

            -- Letters orbit in the upper part of the funnel
            local spinSpeed = 2.0
            local orbitRadius = 90 * (1 - EaseOutCubic(phaseProgress) * 0.4)

            local currentAngle = (timePassed * spinSpeed * rotationDir) 

            -- Letters center follows the sway
            local swayAmount = 30 * (1 - phaseProgress * 0.7)
            local swayX = math.sin(timePassed * 1.5) * swayAmount * 0.6

            -- Letters are in upper middle of funnel
            local letterCenterY = funnelBottomY + funnelHeight * 0.65

            for i, item in ipairs(letters) do
                local letterAngle = currentAngle + (i * (math.pi / 2)) 

                local r = orbitRadius + math.sin(timePassed * 3.2 + i) * 10
                local orbitX = r * math.cos(letterAngle)
                local orbitY = r * math.sin(letterAngle) * 0.35 -- Flatten for perspective

                -- Add some vertical bob
                local bobY = math.cos(timePassed * 2.0 + i * 0.9) * 12

                local x = swayX + orbitX
                local y = letterCenterY + orbitY + bobY

                item.frame:ClearAllPoints()
                item.frame:SetPoint("CENTER", intro, "CENTER", x, y)
                item.frame:SetAlpha(alpha)
                item.frame:SetScale(0.7 + 0.12 * math.sin(timePassed * 2.3 + i))
            end

        elseif timePassed < totalDuration then
            -- Settle letters into final position
            local settleProgress = (timePassed - tornadoDuration) / settleDuration
            local ease = EaseOutQuint(settleProgress)

            for i, item in ipairs(letters) do
                local finalX = item.data.off
                local finalY = logoCenterY

                -- Calculate starting position
                local endAngle = (tornadoDuration * 2.0 * rotationDir) + (i * (math.pi / 2))
                local endRadius = 90 * 0.6
                local startX = endRadius * math.cos(endAngle)
                local startY = (funnelBottomY + funnelHeight * 0.65) + endRadius * math.sin(endAngle) * 0.35

                -- Smooth interpolation to final position
                local x = startX + (finalX - startX) * ease
                local y = startY + (finalY - startY) * ease

                -- Scale smoothly to 1.0
                local scale = 0.7 + 0.3 * ease

                item.frame:ClearAllPoints()
                item.frame:SetPoint("CENTER", intro, "CENTER", x, y)
                item.frame:SetScale(scale)
                item.frame:SetAlpha(1)
            end

        else
            -- FINALIZE INTRO SEQUENCE
            if not intro.finishedSequenceStarted then
                intro.finishedSequenceStarted = true

                -- Hide all particles etc immediately
                particleContainer:Hide()

                -- Snap letters to final position
                for _, item in ipairs(letters) do
                    item.frame:ClearAllPoints()
                    item.frame:SetPoint("CENTER", logoFrame, "CENTER", item.data.off, 0)
                    item.frame:SetAlpha(1)
                    item.frame:SetScale(1)
                end

                local ag2 = intro:CreateAnimationGroup()

                local aLine = ag2:CreateAnimation("Scale")
                mQoL_Templates.ApplyAnimation(aLine)
                aLine:SetOrder(1)
                aLine:SetDuration(0.6)
                aLine:SetScaleFrom(1, 1)
                aLine:SetScaleTo(550, 1)
                aLine:SetSmoothing("OUT")
                aLine:SetTarget(lineFrame)

                local aVer = ag2:CreateAnimation("Alpha")
                mQoL_Templates.ApplyAnimation(aVer)
                aVer:SetOrder(1)
                aVer:SetDuration(0.5)
                aVer:SetFromAlpha(0)
                aVer:SetToAlpha(1)
                aVer:SetTarget(verText)

                local aExit = ag2:CreateAnimation("Alpha")
                mQoL_Templates.ApplyAnimation(aExit)
                aExit:SetOrder(2)
                aExit:SetStartDelay(0.5)
                aExit:SetDuration(0.6)
                aExit:SetFromAlpha(1)
                aExit:SetToAlpha(0)
                aExit:SetTarget(intro)

                ag2:SetScript("OnFinished", function()
                    intro:Hide()
                    finalContentFrame:Show()
                    finalContentFrame:SetAlpha(1)
                    local contentAG = finalContentFrame:CreateAnimationGroup()
                    local aC = contentAG:CreateAnimation("Alpha")
                    mQoL_Templates.ApplyAnimation(aC)
                    aC:SetDuration(0.5)
                    aC:SetFromAlpha(0)
                    aC:SetToAlpha(1)
                    contentAG:Play()

                    if mQoL_Hub.db and mQoL_Hub.db.home then
                        local currentVersion = mQoL_Hub.version or "1.0.0"
                        local versionKey = mQoL_Hub.GetIntroVersionKey and mQoL_Hub:GetIntroVersionKey(currentVersion) or currentVersion
                        mQoL_Hub.db.home.introSeen = versionKey
                    end
                end)
                ag2:Play()

                intro:SetScript("OnUpdate", nil)
            end
        end
    end)
end