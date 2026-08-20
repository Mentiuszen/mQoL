local addonName, L = ...
mQoL_Hub = mQoL_Hub or {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local INTRO_CONFIG = {
    fonts = {
        main = "Fonts\\FRIZQT__.TTF",
        style = "OUTLINE",
        size = 96,
        versionSize = 18,
    },
    colors = {
        text = {1, 0.82, 0},
        version = {1, 1, 1, 0.82},
        line = {0.3, 0.7, 1},
        lineGlow = {0.30, 0.70, 1, 0},
    },
    timings = {
        letterStep = 0.08,
        letterDuration = 0.34,
        lineStart = 0.18,
        lineDuration = 0.42,
        versionStart = 0.34,
        versionDuration = 0.26,
        holdDuration = 0.42,
    },
    letters = {
        { char = "m", off = -110 },
        { char = "Q", off = -25 },
        { char = "o", off = 40 },
        { char = "L", off = 90 },
    },
    dimensions = {
        logoWidth = 600,
        logoHeight = 150,
        lineWidth = 550,
        lineHeight = 4,
    }
}

-- ============================================================================
-- UTILITIES
-- ============================================================================
local function EaseOutCubic(t) return 1 - (1 - t)^3 end
local function EaseOutQuint(t) return 1 - (1 - t)^5 end

local function Clamp01(value)
    return math.max(0, math.min(1, value))
end

-- Helper do obliczania progresu animacji z uwzględnieniem opóźnień (staggering)
local function GetAnimProgress(elapsed, start, duration, step, index)
    local adjustedTime = elapsed - ((index - 1) * step)
    return Clamp01((adjustedTime - start) / duration)
end

local function CreateLetter(parent, char, fontSize)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(fontSize, fontSize)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER")
    text:SetText(char)
    text:SetFont(INTRO_CONFIG.fonts.main, fontSize, INTRO_CONFIG.fonts.style)
    text:SetTextColor(unpack(INTRO_CONFIG.colors.text))

    return frame
end

-- ============================================================================
-- MAIN LOGIC
-- ============================================================================

function mQoL_Hub:RunHomeIntro(parent, finalContentFrame)
    if parent.mQoLActiveIntro then
        parent.mQoLActiveIntro:SetScript("OnUpdate", nil)
        parent.mQoLActiveIntro:Hide()
        parent.mQoLActiveIntro = nil
    end

    finalContentFrame:SetAlpha(0)
    finalContentFrame:Hide()

    -- Main Intro Frame
    local intro = CreateFrame("Frame", nil, parent)
    intro:SetAllPoints()
    intro:SetFrameLevel(parent:GetFrameLevel() + 50)
    intro:EnableMouse(true)
    intro:SetScript("OnMouseDown", function() end)
    parent.mQoLActiveIntro = intro

    -- Logo Container
    local logoFrame = CreateFrame("Frame", nil, intro)
    logoFrame:SetSize(INTRO_CONFIG.dimensions.logoWidth, INTRO_CONFIG.dimensions.logoHeight)
    logoFrame:SetPoint("CENTER", 0, 20)

    -- Letters Creation
    local letters = {}
    for i, data in ipairs(INTRO_CONFIG.letters) do
        local frame = CreateLetter(logoFrame, data.char, INTRO_CONFIG.fonts.size)
        frame:SetAlpha(0)
        frame:SetScale(0.92)
        table.insert(letters, { frame = frame, off = data.off })
    end

    -- Line & Glow
    local lineFrame = CreateFrame("Frame", nil, intro)
    lineFrame:SetSize(INTRO_CONFIG.dimensions.lineWidth, INTRO_CONFIG.dimensions.lineHeight)
    lineFrame:SetPoint("TOP", logoFrame, "BOTTOM", 0, 10)

    local line = lineFrame:CreateTexture(nil, "ARTWORK")
    line:SetPoint("CENTER")
    line:SetHeight(INTRO_CONFIG.dimensions.lineHeight)
    line:SetWidth(1)
    line:SetColorTexture(unpack(INTRO_CONFIG.colors.line))

    local lineGlow = lineFrame:CreateTexture(nil, "OVERLAY")
    lineGlow:SetPoint("CENTER")
    lineGlow:SetSize(1, 10)
    lineGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    lineGlow:SetBlendMode("ADD")
    lineGlow:SetVertexColor(unpack(INTRO_CONFIG.colors.lineGlow))

    -- Version Text
    local verText = logoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    verText:SetPoint("TOPRIGHT", letters[#letters].frame, "BOTTOMRIGHT", 20, 5)
    verText:SetText("v." .. (mQoL_Hub.version or "1.1.0"))
    verText:SetFont(INTRO_CONFIG.fonts.main, INTRO_CONFIG.fonts.versionSize, INTRO_CONFIG.fonts.style)
    verText:SetTextColor(unpack(INTRO_CONFIG.colors.version))
    verText:SetAlpha(0)

    local startTime = GetTime()
    local exitStart = INTRO_CONFIG.timings.versionStart + INTRO_CONFIG.timings.versionDuration + INTRO_CONFIG.timings.holdDuration

    local function FinishIntro(revealContent)
        intro:SetScript("OnUpdate", nil)
        intro:Hide()

        if parent.mQoLActiveIntro == intro then
            parent.mQoLActiveIntro = nil
        end

        if revealContent then
            finalContentFrame:Show()
            finalContentFrame:SetAlpha(1)
        end

        if mQoL_Hub.db and mQoL_Hub.db.home then
            local currentVersion = mQoL_Hub.version or "1.0.0"
            local versionKey = mQoL_Hub.GetIntroVersionKey and mQoL_Hub:GetIntroVersionKey(currentVersion) or currentVersion
            mQoL_Hub.db.home.introSeen = versionKey
        end
    end

    local function PlayExitSequence()
        intro.exitStarted = true
        intro:SetScript("OnUpdate", nil)

        for _, letter in ipairs(letters) do
            letter.frame:ClearAllPoints()
            letter.frame:SetPoint("CENTER", logoFrame, "CENTER", letter.off, 0)
            letter.frame:SetScale(1)
            letter.frame:SetAlpha(1)
        end

        line:SetWidth(INTRO_CONFIG.dimensions.lineWidth)
        line:SetAlpha(1)
        lineGlow:SetWidth(INTRO_CONFIG.dimensions.lineWidth)
        lineGlow:SetAlpha(0.18)
        verText:SetAlpha(1)

        local outroAG = intro:CreateAnimationGroup()
        local aExit = outroAG:CreateAnimation("Alpha")
        mQoL_Templates.ApplyAnimation(aExit)
        aExit:SetDuration(0.6)
        aExit:SetFromAlpha(1)
        aExit:SetToAlpha(0)
        aExit:SetTarget(intro)

        outroAG:SetScript("OnFinished", function()
            intro:Hide()
            finalContentFrame:Show()
            finalContentFrame:SetAlpha(0)

            local contentAG = finalContentFrame:CreateAnimationGroup()
            local aContent = contentAG:CreateAnimation("Alpha")
            mQoL_Templates.ApplyAnimation(aContent)
            aContent:SetDuration(0.5)
            aContent:SetFromAlpha(0)
            aContent:SetToAlpha(1)
            contentAG:SetScript("OnFinished", function()
                FinishIntro(true)
            end)
            contentAG:Play()
        end)

        outroAG:Play()
    end

    intro:SetScript("OnUpdate", function(self)
        local elapsed = GetTime() - startTime

        -- Update Letters
        for index, letter in ipairs(letters) do
            local reveal = GetAnimProgress(elapsed, INTRO_CONFIG.timings.letterDuration, INTRO_CONFIG.timings.letterDuration, INTRO_CONFIG.timings.letterStep, index)
            local ease = EaseOutQuint(reveal)
            
            local yOffset = (1 - ease) * -18
            local scale = 0.92 + (0.08 * ease)

            letter.frame:ClearAllPoints()
            letter.frame:SetPoint("CENTER", logoFrame, "CENTER", letter.off, yOffset)
            letter.frame:SetScale(scale)
            letter.frame:SetAlpha(ease)
        end

        -- Update Line
        local lineProgress = EaseOutQuint(Clamp01((elapsed - INTRO_CONFIG.timings.lineStart) / INTRO_CONFIG.timings.lineDuration))
        local lineWidth = math.max(1, INTRO_CONFIG.dimensions.lineWidth * lineProgress)
        line:SetWidth(lineWidth)
        lineGlow:SetWidth(lineWidth)
        line:SetAlpha(lineProgress)
        lineGlow:SetAlpha(0.14 * lineProgress)

        -- Update Version
        local versionProgress = EaseOutCubic(Clamp01((elapsed - INTRO_CONFIG.timings.versionStart) / INTRO_CONFIG.timings.versionDuration))
        verText:SetAlpha(versionProgress)

        if elapsed >= exitStart and not intro.exitStarted then
            PlayExitSequence()
        end
    end)
end
