local addonName, L = ...
mQoL_Hub = mQoL_Hub or {}

local function EaseOutCubic(t)
    return 1 - (1 - t)^3
end

local function EaseOutQuint(t)
    return 1 - (1 - t)^5
end

local function Clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function CreateLetter(parent, char, fontSize)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(fontSize, fontSize)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER")
    text:SetText(char)
    text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    text:SetTextColor(1, 0.82, 0)

    return frame
end

function mQoL_Hub:RunHomeIntro(parent, finalContentFrame)
    if parent.mQoLActiveIntro then
        parent.mQoLActiveIntro:SetScript("OnUpdate", nil)
        parent.mQoLActiveIntro:Hide()
        parent.mQoLActiveIntro = nil
    end

    finalContentFrame:SetAlpha(0)
    finalContentFrame:Hide()

    local intro = CreateFrame("Frame", nil, parent)
    intro:SetAllPoints()
    intro:SetFrameLevel(parent:GetFrameLevel() + 50)
    intro:EnableMouse(true)
    intro:SetScript("OnMouseDown", function() end)
    parent.mQoLActiveIntro = intro

    local logoFrame = CreateFrame("Frame", nil, intro)
    logoFrame:SetSize(600, 150)
    logoFrame:SetPoint("CENTER", 0, 20)

    local fontSize = 96
    local lettersData = {
        { char = "m", off = -110 },
        { char = "Q", off = -25 },
        { char = "o", off = 40 },
        { char = "L", off = 90 },
    }

    local letters = {}
    for _, data in ipairs(lettersData) do
        local frame = CreateLetter(logoFrame, data.char, fontSize)
        frame:SetAlpha(0)
        frame:SetScale(0.92)
        table.insert(letters, {
            frame = frame,
            off = data.off,
        })
    end

    local lineFrame = CreateFrame("Frame", nil, intro)
    lineFrame:SetSize(550, 4)
    lineFrame:SetPoint("TOP", logoFrame, "BOTTOM", 0, 10)

    local line = lineFrame:CreateTexture(nil, "ARTWORK")
    line:SetPoint("CENTER")
    line:SetHeight(4)
    line:SetWidth(1)
    line:SetColorTexture(0.3, 0.7, 1)

    local lineGlow = lineFrame:CreateTexture(nil, "OVERLAY")
    lineGlow:SetPoint("CENTER")
    lineGlow:SetSize(1, 10)
    lineGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    lineGlow:SetBlendMode("ADD")
    lineGlow:SetVertexColor(0.30, 0.70, 1, 0)

    local verText = logoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    verText:SetPoint("TOPRIGHT", letters[#letters].frame, "BOTTOMRIGHT", 20, 5)
    verText:SetText("v." .. (mQoL_Hub.version or "1.1.0"))
    verText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    verText:SetTextColor(1, 1, 1, 0.82)
    verText:SetAlpha(0)

    local startTime = GetTime()
    local letterStep = 0.08
    local letterDuration = 0.34
    local lineStart = 0.18
    local lineDuration = 0.42
    local versionStart = 0.34
    local versionDuration = 0.26
    local holdDuration = 0.42
    local exitStart = versionStart + versionDuration + holdDuration

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

        line:SetWidth(550)
        line:SetAlpha(1)
        lineGlow:SetWidth(550)
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

        for index, letter in ipairs(letters) do
            local reveal = Clamp01((elapsed - ((index - 1) * letterStep)) / letterDuration)
            local ease = EaseOutQuint(reveal)
            local yOffset = (1 - ease) * -18
            local scale = 0.92 + (0.08 * ease)

            letter.frame:ClearAllPoints()
            letter.frame:SetPoint("CENTER", logoFrame, "CENTER", letter.off, yOffset)
            letter.frame:SetScale(scale)
            letter.frame:SetAlpha(ease)
        end

        local lineProgress = EaseOutQuint(Clamp01((elapsed - lineStart) / lineDuration))
        local lineWidth = math.max(1, 550 * lineProgress)
        line:SetWidth(lineWidth)
        lineGlow:SetWidth(lineWidth)
        line:SetAlpha(lineProgress)
        lineGlow:SetAlpha(0.14 * lineProgress)

        local versionProgress = EaseOutCubic(Clamp01((elapsed - versionStart) / versionDuration))
        verText:SetAlpha(versionProgress)

        if elapsed >= exitStart and not intro.exitStarted then
            PlayExitSequence()
        end
    end)
end