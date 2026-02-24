local function GetSpellCooldownWrapper(spellID)
    -- Use C_Spell.GetSpellCooldown and handle protected secret numbers
    if _G.GetSpellCooldown then
         return _G.GetSpellCooldown(spellID)
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime, info.duration
        end
    end
    return 0, 0
end

local function GetSpellNameWrapper(spellID)
    if not spellID or spellID <= 0 then
        return nil
    end

    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(spellID)
        if name then
            return name
        end
    end

    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end

    return nil
end

local function RefreshButtonCooldown(btn)
    if not btn or not btn.cooldown then return end
    if not btn.isKnown or not btn.currentSpellID or btn.currentSpellID <= 0 then
        btn.cooldown:Hide()
        return
    end

    local start, duration = GetSpellCooldownWrapper(btn.currentSpellID)
    if start and duration then
        -- Avoid numeric comparisons here because C_Spell can return protected secret numbers
        btn.cooldown:SetCooldown(start, duration)
        btn.cooldown:Show()
    else
        btn.cooldown:Hide()
    end
end

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function IsTeleportSpellKnown(spellID)
    if not spellID or spellID <= 0 then
        return false
    end

    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then
        return true
    end

    if IsPlayerSpell and IsPlayerSpell(spellID) then
        return true
    end

    if IsSpellKnown and IsSpellKnown(spellID) then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known then
            return true
        end
    end

    return false
end

-- Teleport Data Structure
local TeleportCategories = {
    { text = "TWW Season 3", value = "TWW_S3" }, --Both Seasons TWW s3 and Midnight Season 1 are present at sametime so its usable in beta too
    { text = "Midnight Season 1", value = "MID_S1" },
    { separator = true },
    { text = "Midnight", value = "Midnight" },
    { text = "The War Within", value = "The War Within" },
    { text = "Dragonflight", value = "Dragonflight" },
    { text = "Shadowlands", value = "Shadowlands" },
    { text = "Battle for Azeroth", value = "Battle for Azeroth" },
    { text = "Legion", value = "Legion" },
    { text = "Warlords of Draenor", value = "Warlords of Draenor" },
    { text = "Mists of Pandaria", value = "Mists of Pandaria" },
    { text = "Cataclysm", value = "Cataclysm" },
    { text = "Wrath of the Lich King", value = "Wrath of the Lich King" }
}

local TeleportData = {
    ["TWW_S3"] = {
        { id = 2660, name = "Ara-Kara, City of Echoes", texture = 5912537, spellID = 445417, location = "Azj-Kahet" },
        { id = 2662, name = "The Dawnbreaker", texture = 5912543, spellID = 445414, location = "Hallowfall" },
        { id = 2649, name = "Priory of the Sacred Flame", texture = 5912542, spellID = 445444, location = "Hallowfall" },
        { id = 2773, name = "Operation: Floodgate", texture = 6422410, spellID = 1216786, location = "Ringing Deeps" },
        { id = 2830, name = "Eco-Dome Al'dani", texture = 7074041, spellID = 1237215, location = "K'aresh" },
        { id = 2287, name = "Halls of Atonement", texture = 3759918, spellID = 354465, location = "Revendreth" },
        { id = 2441, name = "Tazavesh, the Veiled Market", texture = 4182024, spellID = 367416, location = "Tazavesh" },
        { id = 2810, name = "Manaforge Omega", texture = 7049313, spellID = 1239155, location = "K'aresh" },
    },
    ["MID_S1"] = {
        { id = 658, name = "Pit of Saron", texture = 608249, spellID = 1254555, location = "Icecrown" },
        { id = 1209, name = "Skyreach", texture = 1041989, spellID = 159898, location = "Spires of Arak" },
        { id = 1753, name = "Seat of the Triumvirate", texture = 1718205, spellID = 1254551, location = "Mac'Aree / Eredar" },
        { id = 2526, name = "Algeth'ar Academy", texture = 4742939, spellID = 393273, location = "Thaldraszus" },
        { id = 2805, name = "Windrunner Spire", texture = 7464939, spellID = 1254400, location = "Eversong Woods" },
        { id = 2811, name = "Magisters' Terrace", texture = 7467176, spellID = 1254572, location = "Eversong Woods" },
        { id = 2874, name = "Maisara Caverns", texture = 7478532, spellID = 1254559, location = "Zul'Aman" },
        { id = 2915, name = "Nexus-Point Xenas", texture = 7570499, spellID = 1254563, location = "Voidstorm" },
    },
    ["Midnight"] = {
        { id = 2805, name = "Windrunner Spire", texture = 7464939, spellID = 1254400, location = "Eversong Woods" },
        { id = 2811, name = "Magisters' Terrace", texture = 7467176, spellID = 1254572, location = "Eversong Woods" },
        { id = 2874, name = "Maisara Caverns", texture = 7478532, spellID = 1254559, location = "Zul'Aman" },
        { id = 2915, name = "Nexus-Point Xenas", texture = 7570499, spellID = 1254563, location = "Voidstorm" },
        --{ id = 2813, name = "Murder Row", texture = 7467177, spellID = 0, location = "Eversong Woods" }, --Not Added Yet
        --{ id = 2825, name = "Den of Nalorakk", texture = 7478533, spellID = 0, location = "Zul'Aman" }, --Not Added Yet
        --{ id = 2859, name = "The Blinding Vale", texture = 7478531, spellID = 0, location = "Harandar" }, --Not Added Yet
        --{ id = 2923, name = "Voidscar Arena", texture = 7479111, spellID = 0, location = "Voidstorm" }, --Not Added Yet
        --{ id = 2912, name = "The Voidspire", texture = 7507134, spellID = 0, location = "	Voidstorm" }, --Unconfirmed
        --{ id = 2939, name = "The Dreamrift", texture = 7570500, spellID = 0, location = "Harandar" }, --Unconfirmed
        --{ id = 2913, name = "March on Quel'Danas", texture = 7480125, spellID = 0, location = "Eversong Woods" }, --Unconfirmed
    },
    ["The War Within"] = {
        { id = 2660, name = "Ara-Kara, City of Echoes", texture = 5912537, spellID = 445417, location = "Azj-Kahet" },
        { id = 2661, name = "Cinderbrew Meadery", texture = 5912538, spellID = 445440, location = "Isle of Dorn" },
        { id = 2669, name = "City of Threads", texture = 5912539, spellID = 445416, location = "Azj-Kahet" },
        { id = 2651, name = "Darkflame Cleft", texture = 5912540, spellID = 445441, location = "Ringing Deeps" },
        { id = 2649, name = "Priory of the Sacred Flame", texture = 5912542, spellID = 445444, location = "Hallowfall" },
        { id = 2662, name = "The Dawnbreaker", texture = 5912543, spellID = 445414, location = "Hallowfall" },
        { id = 2648, name = "The Rookery", texture = 5912544, spellID = 445443, location = "Isle of Dorn" },
        { id = 2652, name = "The Stonevault", texture = 5912545, spellID = 445269, location = "Ringing Deeps" },
        { id = 2773, name = "Operation: Floodgate", texture = 6422410, spellID = 1216786, location = "Ringing Deeps" },
        { id = 2830, name = "Eco-Dome Al'dani", texture = 7074041, spellID = 1237215, location = "K'aresh" },
        { id = 2769, name = "Liberation of Undermine", texture = 6422409, spellID = 1226482, location = "Undermine" },
        { id = 2810, name = "Manaforge Omega", texture = 7049313, spellID = 1239155, location = "K'aresh" },
    },
    ["Dragonflight"] = {
        { id = 2526, name = "Algeth'ar Academy", texture = 4742939, spellID = 393273, location = "Thaldraszus" },
        { id = 2520, name = "Brackenhide Hollow", texture = 4742933, spellID = 393267, location = "Azure Span" },
        { id = 2527, name = "Halls of Infusion", texture = 4742936, spellID = 393283, location = "Thaldraszus" },
        { id = 2519, name = "Neltharus", texture = 4742938, spellID = 393276, location = "Waking Shores" },
        { id = 2521, name = "Ruby Life Pools", texture = 4742937, spellID = 393256, location = "Waking Shores" },
        { id = 2515, name = "The Azure Vault", texture = 4742932, spellID = 393279, location = "Azure Span" },
        { id = 2516, name = "The Nokhud Offensive", texture = 4742934, spellID = 393262, location = "Ohn'ahran Plains" },
        { id = 2451, name = "Uldaman: Legacy of Tyr", texture = 4742940, spellID = 393222, location = "Badlands" },
        { id = 2522, name = "Vault of the Incarnates", texture = 4742941, spellID = 432254, location = "Thaldraszus" },
        { id = 2569, name = "Aberrus, the Shadowed Crucible", texture = 5149417, spellID = 432257, location = "Zaralek Cavern" },
        { id = 2549, name = "Amirdrassil, the Dream's Hope", texture = 5409262, spellID = 432258, location = "Emerald Dream" },
    },
    ["Shadowlands"] = {
        { id = 2286, name = "The Necrotic Wake", texture = 3759920, spellID = 354462, location = "Bastion" },
        { id = 2289, name = "Plaguefall", texture = 3759921, spellID = 354463, location = "Maldraxxus" },
        { id = 2290, name = "Mists of Tirna Scithe", texture = 3759919, spellID = 354464, location = "Ardenweald" },
        { id = 2287, name = "Halls of Atonement", texture = 3759918, spellID = 354465, location = "Revendreth" },
        { id = 2293, name = "Theater of Pain", texture = 3759924, spellID = 354467, location = "Maldraxxus" },
        { id = 2291, name = "De Other Side", texture = 3759925, spellID = 354468, location = "Ardenweald" },
        { id = 2285, name = "Spires of Ascension", texture = 3759923, spellID = 354466, location = "Bastion" },
        { id = 2284, name = "Sanguine Depths", texture = 3759922, spellID = 354469, location = "Revendreth" },
        { id = 2441, name = "Tazavesh, the Veiled Market", texture = 4182024, spellID = 367416, location = "Tazavesh" },
        { id = 2296, name = "Castle Nathria", texture = 3759916, spellID = 373190, location = "Revendreth" },
        { id = 2450, name = "Sanctum of Domination", texture = 4182023, spellID = 373191, location = "The Maw" },
        { id = 2481, name = "Sepulcher of the First Ones", texture = 4425895, spellID = 373192, location = "Zereth Mortis" },
    },
    ["Battle for Azeroth"] = {
        { id = 1763, name = "Atal'Dazar", texture = 1778890, spellID = 424187, location = "Zuldazar" },
        { id = 1754, name = "Freehold", texture = 1778891, spellID = 410071, location = "Tiragarde Sound" },
        { id = 1822, name = "Siege of Boralus", texture = 2177726, spellIDHorde = 467555, spellIDAlly = 467553, location = "Tiragarde Sound" },
        { id = 1594, name = "The Motherlode!!", texture = 2177728, spellIDHorde = 464256, spellIDAlly = 445418, location = "Zuldazar" },
        { id = 1841, name = "The Underrot", texture = 2177729, spellID = 410074, location = "Nazmir" },
        { id = 1862, name = "Waycrest Manor", texture = 2177732, spellID = 424167, location = "Drustvar" },
        { id = 2097, name = "Operation: Mechagon", texture = 3025327, spellID = 373274, location = "Mechagon Island" },
    },
    ["Legion"] = {
        { id = 1501, name = "Black Rook Hold", texture = 1411847, spellID = 424153, location = "Val'sharah" },
        { id = 1571, name = "Court of Stars", texture = 1498152, spellID = 393766, location = "Suramar" },
        { id = 1466, name = "Darkheart Thicket", texture = 1411849, spellID = 424163, location = "Val'sharah" },
        { id = 1477, name = "Halls of Valor", texture = 1498154, spellID = 393764, location = "Stormheim" },
        { id = 1458, name = "Neltharion's Lair", texture = 1450572, spellID = 410078, location = "Highmountain" },
        { id = 1651, name = "Return to Karazhan", texture = 1537281, spellID = 373262, location = "Deadwind Pass" },
        { id = 1753, name = "Seat of the Triumvirate", texture = 1718205, spellID = 1254551, location = "Mac'Aree / Eredar" },
    },
    ["Warlords of Draenor"] = {
        { id = 1175, name = "Bloodmaul Slag Mines", texture = 1041984, spellID = 159895, location = "Frostfire Ridge" },
        { id = 1208, name = "Grimrail Depot", texture = 1041986, spellID = 159900, location = "Gorgrond" },
        { id = 1195, name = "Iron Docks", texture = 1060546, spellID = 159896, location = "Gorgrond" },
        { id = 1182, name = "Auchindoun", texture = 1041982, spellID = 159897, location = "Talador" },
        { id = 1279, name = "The Everbloom", texture = 1060545, spellID = 159901, location = "Gorgrond" },
        { id = 1176, name = "Shadowmoon Burial Grounds", texture = 1041988, spellID = 159899, location = "Shadowmoon Valley" },
        { id = 1358, name = "Upper Blackrock Spire", texture = 1041990, spellID = 159902, location = "Blackrock Mountain" },
        { id = 1209, name = "Skyreach", texture = 1041989, spellID = 159898, location = "Spires of Arak" },
    },
    ["Mists of Pandaria"] = {
        { id = 960, name = "Temple of the Jade Serpent", texture = 632283, spellID = 131204, location = "Jade Forest" },
        { id = 961, name = "Stormstout Brewery", texture = 632282, spellID = 131205, location = "Valley of the Four Winds" },
        { id = 959, name = "Shado-Pan Monastery", texture = 632281, spellID = 131206, location = "Kun-Lai Summit" },
        { id = 994, name = "Mogu'shan Palace", texture = 632279, spellID = 131222, location = "Vale of Eternal Blossoms" },
        { id = 962, name = "Gate of the Setting Sun", texture = 632277, spellID = 131225, location = "Vale of Eternal Blossoms" },
        { id = 1011, name = "Siege of Niuzao Temple", texture = 643266, spellID = 131228, location = "Townlong Steppes" },
        { id = 1001, name = "Scarlet Halls", texture = 643265, spellID = 131231, location = "Tirisfal Glades" },
        { id = 1004, name = "Scarlet Monastery", texture = 608253, spellID = 131229, location = "Tirisfal Glades" },
        { id = 1007, name = "Scholomance", texture = 608254, spellID = 131232, location = "Western Plaguelands" },
    },
    ["Cataclysm"] = {
        { id = 657, name = "Vortex Pinnacle", texture = 526414, spellID = 410080, location = "Uldum" },
        { id = 643, name = "Throne of the Tides", texture = 526413, spellID = 424142, location = "Vashj'ir" },
        { id = 670, name = "Grim Batol", texture = 526406, spellID = 445424, location = "Twilight Highlands" },
    },
    ["Wrath of the Lich King"] = {
        { id = 658, name = "Pit of Saron", texture = 608249, spellID = 1254555, location = "Icecrown" },
    }
}

local function InitDungeonTeleportsTab()
    if _G["PVEFrameTab4"] then return end
    if not PVEFrame or not PVEFrameTab3 then return end

    local pendingCategoryValue
    local pendingCategoryText
    local pendingHideAfterCombat = false
    local selectedCategoryValue = "TWW_S3"
    local selectedCategoryText = "TWW Season 3"

    local function GetCategoryTextByValue(value)
        for _, cat in ipairs(TeleportCategories) do
            if cat.value == value then
                return cat.text
            end
        end
        return tostring(value or "")
    end

    -- Create the new tab
    local tab = CreateFrame("Button", "PVEFrameTab4", PVEFrame, "PanelTabButtonTemplate")
    tab:SetID(4)
    tab:SetText("Dungeon Teleports")
    if PanelTemplates_TabResize then
        PanelTemplates_TabResize(tab, 0)
    end
    tab:SetPoint("LEFT", PVEFrameTab3, "RIGHT", 6, 0)
    tab:Show()
    
    -- Create the content frame
    local contentFrame = CreateFrame("Frame", "DungeonTeleportsFrame", PVEFrame)
    contentFrame:SetAllPoints(PVEFrame)
    contentFrame:Hide()

    -- Title
    local title = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 70, -35)
    title:SetText("TWW Season 3")

    -- Background Inset
    local inset = CreateFrame("Frame", "$parentInset", contentFrame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", inset)
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(inset:GetWidth()-30, 500)
    scrollFrame:SetScrollChild(scrollChild)
    contentFrame.scrollChild = scrollChild
    contentFrame.buttons = {}
    
    -- Custom Scrollbar (from mQoL Addon Styles)
    if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar then
        mQoL_Styles.CreateCustomScrollbar(scrollFrame, scrollChild)
    end

    -- Functions
    local function UpdateTeleportList(categoryValue)
        if IsInCombat() then
            return false
        end

        -- Clear existing buttons
        for _, btn in pairs(contentFrame.buttons) do
            btn:Hide()
        end
        
        local data = TeleportData[categoryValue]
        if not data then return true end
        
        -- Card Style Layout
        local availableWidth = scrollChild:GetWidth() or 520
        local cols = 3
        local marginX = 10
        local marginY = 10
        local startX = 10
        local startY = -10

        local btnWidth = (availableWidth - (cols - 1) * marginX - 2 * startX) / cols
        local btnHeight = 95 
        
        for i, info in ipairs(data) do
            if not contentFrame.buttons[i] then
                local btn = CreateFrame("Button", nil, scrollChild, "SecureActionButtonTemplate")
                btn:SetSize(btnWidth, btnHeight)
                
                -- Card Background
                btn.bg = btn:CreateTexture(nil, "BACKGROUND")
                btn.bg:SetAllPoints()
                btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
                
                -- Border
                btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
                btn.border:SetAllPoints()
                btn.border:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                btn.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

                -- Image Section
                btn.imageContainer = btn:CreateTexture(nil, "BACKGROUND")
                btn.imageContainer:SetPoint("TOPLEFT", 0, 0)
                btn.imageContainer:SetPoint("TOPRIGHT", 0, 0)
                btn.imageContainer:SetHeight(btnHeight * 0.6)
                btn.imageContainer:SetColorTexture(0.05, 0.05, 0.05, 1)
                
                btn.imageArea = btn:CreateTexture(nil, "ARTWORK")
                btn.imageArea:SetPoint("CENTER", btn.imageContainer, "CENTER")
                btn.imageArea:SetSize(btnHeight * 0.6, btnHeight * 0.6)
                btn.imageArea:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                
                -- Info Section (Instance Name and Location)
                btn.infoBg = btn:CreateTexture(nil, "ARTWORK")
                btn.infoBg:SetPoint("TOPLEFT", 0, -(btnHeight * 0.6))
                btn.infoBg:SetPoint("BOTTOMRIGHT", 0, 0)
                btn.infoBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

                -- Name
                btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                btn.nameText:SetPoint("TOPLEFT", btn.infoBg, "TOPLEFT", 5, -5)
                btn.nameText:SetPoint("TOPRIGHT", btn.infoBg, "TOPRIGHT", -5, -5)
                btn.nameText:SetJustifyH("LEFT")
                btn.nameText:SetJustifyV("TOP")
                btn.nameText:SetWordWrap(false)
                btn.nameText:SetMaxLines(1)

                -- Location
                btn.locText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                btn.locText:SetPoint("BOTTOMLEFT", btn.infoBg, "BOTTOMLEFT", 5, 5)
                btn.locText:SetPoint("BOTTOMRIGHT", btn.infoBg, "BOTTOMRIGHT", -5, 5)
                btn.locText:SetJustifyH("LEFT")
                btn.locText:SetTextColor(0.7, 0.7, 0.7)
                btn.locText:SetMaxLines(1)

                -- Hover Effect
                btn:SetScript("OnEnter", function(self)
                    self.border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if self.currentSpellID and self.currentSpellID > 0 then
                        GameTooltip:SetSpellByID(self.currentSpellID)
                    end
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    self.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                    GameTooltip:Hide()
                end)
                  
                contentFrame.buttons[i] = btn
            end
            
            local btn = contentFrame.buttons[i]

            -- Ensure cooldown frame exists
            if not btn.cooldown then
                btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                btn.cooldown:SetAllPoints(btn)
                btn.cooldown:SetDrawEdge(false)
                if btn.cooldown.SetDrawBling then
                    btn.cooldown:SetDrawBling(false)
                end
                btn.cooldown:SetHideCountdownNumbers(false)
                
                for _, region in ipairs({btn.cooldown:GetRegions()}) do
                    if region:GetObjectType() == "FontString" then
                        region:SetTextColor(1, 0.82, 0)
                    end
                end
            end
            
            -- Update Size
            btn:SetSize(btnWidth, btnHeight)
            btn.imageContainer:SetHeight(btnHeight * 0.6)
            btn.infoBg:SetPoint("TOPLEFT", 0, -(btnHeight * 0.6))

            -- Grid Position
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", startX + (col * (btnWidth + marginX)), startY - (row * (btnHeight + marginY)))
            btn:Show()
            
            btn.nameText:SetText(info.name)
            btn.locText:SetText(info.location or "Unknown Location")

            -- Setup click and visual state
            local isKnown = false
            local spellToUse = nil
            
            -- Determine player faction for faction specific spell ID selection (if applicable)
            local faction = UnitFactionGroup("player")
            
            -- Determine which spell ID to use based on faction (for few dungeons that have different IDs for Horde/Ally due to faction specific enterance)
            if info.spellIDHorde and info.spellIDAlly then
                if faction == "Horde" then
                    spellToUse = info.spellIDHorde
                else
                    spellToUse = info.spellIDAlly
                end
            else
                spellToUse = info.spellID
            end
            
            isKnown = IsTeleportSpellKnown(spellToUse)

            if isKnown then
                btn:Enable()
                btn:SetAlpha(1)
                btn.imageArea:SetDesaturated(false)
                btn.nameText:SetTextColor(1, 0.82, 0)
                local spellName = GetSpellNameWrapper(spellToUse)
                if spellName then
                    btn:SetAttribute("type", "spell")
                    btn:SetAttribute("type1", "spell")
                    btn:SetAttribute("spell", spellName)
                    btn:SetAttribute("spell1", spellName)
                else
                    btn:SetAttribute("type", nil)
                    btn:SetAttribute("type1", nil)
                    btn:SetAttribute("spell", nil)
                    btn:SetAttribute("spell1", nil)
                end
            else -- Not known, disable button
                btn:Disable()
                btn:SetAlpha(0.5) -- Grayed out
                btn.imageArea:SetDesaturated(true)
                btn.nameText:SetTextColor(0.5, 0.5, 0.5)
                btn:SetAttribute("type", nil)
                btn:SetAttribute("type1", nil)
                btn:SetAttribute("spell", nil)
                btn:SetAttribute("spell1", nil)
            end
            
            -- Store current spell ID for tooltip
            btn.currentSpellID = spellToUse
            btn.isKnown = isKnown

            -- Update Cooldown immediately
            if contentFrame:IsShown() then
                RefreshButtonCooldown(btn)
            else
                btn.cooldown:Hide()
            end
            
            -- Set Texture using texture FileID
            if info.texture and info.texture > 0 then
                btn.imageArea:ClearAllPoints()
                btn.imageArea:SetAllPoints(btn.imageContainer)
                btn.imageArea:SetTexture(info.texture)
                btn.imageArea:SetTexCoord(0.08, 0.65, 0.14, 0.58)
            end
        end
    
        local totalRows = math.ceil(#data / cols)
        local totalHeight = math.abs(startY) + (totalRows * (btnHeight + marginY)) 
        scrollChild:SetHeight(totalHeight)
        if mQoL_Styles and mQoL_Styles.CreateCustomScrollbar and scrollFrame.scrollbar and scrollFrame.scrollbar.UpdateScrollbar then
             scrollFrame.scrollbar.UpdateScrollbar()
        end

        return true
    end
    
    local function RequestCategoryUpdate(categoryValue, categoryText)
        selectedCategoryValue = categoryValue or selectedCategoryValue
        selectedCategoryText = categoryText or GetCategoryTextByValue(selectedCategoryValue)

        if IsInCombat() then
            pendingCategoryValue = selectedCategoryValue
            pendingCategoryText = selectedCategoryText
            contentFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return false
        end

        if UpdateTeleportList(selectedCategoryValue) then
            title:SetText(selectedCategoryText)
        end

        pendingCategoryValue = nil
        pendingCategoryText = nil
        contentFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        return true
    end

    -- Event Handler for cooldowns and deferred secure updates
    contentFrame:SetScript("OnEvent", function(self, event)
        if event == "SPELL_UPDATE_COOLDOWN" then
            if not self:IsShown() then
                return
            end
            for _, btn in pairs(contentFrame.buttons) do
                if btn:IsShown() then
                    RefreshButtonCooldown(btn)
                end
            end
        elseif event == "SPELLS_CHANGED" then
            RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingCategoryValue then
                RequestCategoryUpdate(pendingCategoryValue, pendingCategoryText)
            else
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            end
        end
    end)
    contentFrame:SetScript("OnShow", function(self)
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELLS_CHANGED")
        RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        for _, btn in pairs(self.buttons) do
            if btn:IsShown() then
                RefreshButtonCooldown(btn)
            end
        end
    end)
    contentFrame:SetScript("OnHide", function(self)
        self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        self:UnregisterEvent("SPELLS_CHANGED")
    end)

    -- Dropdown
    local dropdown
    if mQoL_Styles and mQoL_Styles.CreateCustomDropdown then
        dropdown = mQoL_Styles.CreateCustomDropdown(contentFrame, 160, TeleportCategories, selectedCategoryValue, function(value)
            RequestCategoryUpdate(value, GetCategoryTextByValue(value))
        end)
        dropdown:SetPoint("TOPRIGHT", -5, -30)
    else
        -- Fallback to standard dropdown if styles module not present
        dropdown = CreateFrame("Frame", "DungeonTeleportsDropdown", contentFrame, "UIDropDownMenuTemplate")
        dropdown:SetPoint("LEFT", title, "RIGHT", 10, 0)
        UIDropDownMenu_SetWidth(dropdown, 200)

        local function InitializeDropdown(self, level)
            local info = UIDropDownMenu_CreateInfo()
            for _, cat in ipairs(TeleportCategories) do
                if cat.separator then
                    UIDropDownMenu_AddSeparator(level)
                else
                    local catText = cat.text
                    local catValue = cat.value
                    info.text = catText
                    info.value = catValue
                    info.func = function(buttonSelf)
                        UIDropDownMenu_SetSelectedID(dropdown, buttonSelf:GetID())
                        UIDropDownMenu_SetText(dropdown, catText)
                        RequestCategoryUpdate(catValue, catText)
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
        UIDropDownMenu_Initialize(dropdown, InitializeDropdown)
    end

    local function HideDungeonTeleportsFrame()
        if IsInCombat() then
            pendingHideAfterCombat = true
            return false
        end

        pendingHideAfterCombat = false
        if contentFrame then
            contentFrame:Hide()
        end
        if PanelTemplates_DeselectTab then
            PanelTemplates_DeselectTab(tab)
        end
        return true
    end

    local function ShowDungeonTeleportsFrame()
        if IsInCombat() then
            return
        end

        if not PVEFrame:IsShown() then
            ShowUIPanel(PVEFrame)
        end

        if PanelTemplates_DeselectTab then
            if PVEFrameTab1 then PanelTemplates_DeselectTab(PVEFrameTab1) end
            if PVEFrameTab2 then PanelTemplates_DeselectTab(PVEFrameTab2) end
            if PVEFrameTab3 then PanelTemplates_DeselectTab(PVEFrameTab3) end
        end
        if PanelTemplates_SelectTab then
            PanelTemplates_SelectTab(tab)
        end

        if GroupFinderFrame then GroupFinderFrame:Hide() end
        if PVPUIFrame then PVPUIFrame:Hide() end
        if ChallengesFrame then ChallengesFrame:Hide() end

        if PVEFrame_HideLeftInset then
            PVEFrame_HideLeftInset()
        elseif PVEFrameLeftInset then
            PVEFrameLeftInset:Hide()
        end

        contentFrame:Show()
        RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)
        PVEFrame:SetTitle("Dungeon Teleports")
        if PVEFrame.SetPortraitToAsset then
            PVEFrame:SetPortraitToAsset("Interface\\Icons\\Spell_Arcane_TeleportDalaran")
        elseif PortraitFrame_SetPortraitToAsset then
            PortraitFrame_SetPortraitToAsset(PVEFrame, "Interface\\Icons\\Spell_Arcane_TeleportDalaran")
        end
        PVEFrame:SetWidth(PVE_FRAME_BASE_WIDTH or 563)
        if UpdateUIPanelPositions then
            UpdateUIPanelPositions(PVEFrame)
        end
    end

    local function SetDungeonTeleportsTabDisabled(isDisabled)
        tab:SetEnabled(not isDisabled)
        tab:SetAlpha(1)

        local text = tab.Text or _G[tab:GetName() .. "Text"]
        if text then
            if isDisabled then
                text:SetTextColor(0.5, 0.5, 0.5)
            else
                text:SetTextColor(1, 0.82, 0)
            end
        end
    end

    local function UpdateDungeonTeleportsTabState()
        local inCombat = IsInCombat()
        if inCombat then
            if PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                pendingHideAfterCombat = true
            end
            if PanelTemplates_DisableTab then
                PanelTemplates_DisableTab(PVEFrame, 4)
            else
                tab:Disable()
            end
            if not contentFrame:IsShown() and PanelTemplates_DeselectTab then
                PanelTemplates_DeselectTab(tab)
            end
        else
            if pendingHideAfterCombat and PVEFrame and PVEFrame:IsShown() and contentFrame and contentFrame:IsShown() then
                if HideDungeonTeleportsFrame() then
                    if PVEFrame_TabOnClick and PVEFrameTab3 then
                        PVEFrame_TabOnClick(PVEFrameTab3)
                    elseif PVEFrame_ShowFrame then
                        PVEFrame_ShowFrame("ChallengesFrame")
                    end
                end
            end
            if PanelTemplates_EnableTab then
                PanelTemplates_EnableTab(PVEFrame, 4)
            else
                tab:Enable()
            end
            if contentFrame:IsShown() and PanelTemplates_SelectTab then
                PanelTemplates_SelectTab(tab)
            end
        end

        SetDungeonTeleportsTabDisabled(inCombat)
    end

    tab:SetScript("OnClick", function()
        if IsInCombat() then
            return
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowDungeonTeleportsFrame()
    end)

    -- Initial Load
    RequestCategoryUpdate(selectedCategoryValue, selectedCategoryText)

    hooksecurefunc("PVEFrame_TabOnClick", function(clickedTab)
        if clickedTab and clickedTab:GetID() ~= 4 then
            HideDungeonTeleportsFrame()
        end
        UpdateDungeonTeleportsTabState()
    end)

    hooksecurefunc("PVEFrame_ShowFrame", function(sidePanelName)
        if sidePanelName ~= "DungeonTeleportsFrame" then
            HideDungeonTeleportsFrame()
        end
        UpdateDungeonTeleportsTabState()
    end)

    PVEFrame:HookScript("OnHide", HideDungeonTeleportsFrame)
    PVEFrame:HookScript("OnShow", UpdateDungeonTeleportsTabState)

    local tabStateFrame = CreateFrame("Frame")
    tabStateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    tabStateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    tabStateFrame:SetScript("OnEvent", UpdateDungeonTeleportsTabState)
    UpdateDungeonTeleportsTabState()
end

local frame = CreateFrame("Frame")
local isInitialized = false

local function IsGroupFinderLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder")
end

local function TryInitialize(self)
    if isInitialized then
        return
    end
    if not IsGroupFinderLoaded() then
        return
    end
    if IsInCombat() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    InitDungeonTeleportsTab()
    isInitialized = true
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("ADDON_LOADED")
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "Blizzard_GroupFinder" then
            TryInitialize(self)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        TryInitialize(self)
    end
end)

TryInitialize(frame)