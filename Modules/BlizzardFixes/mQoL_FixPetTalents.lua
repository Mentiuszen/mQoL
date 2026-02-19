local addonName = ...

--Fixed by blizzard this will get removed in 1.1.0

local function FixPetTalentSpecDisplay()
    -- original func
    local function PetSpec_OnLoad_Fix(self)
        local isPet = self.isPet or false

        if not isPet then
            return
        end

        local numSpecs = GetNumSpecializations(false, isPet)
        
        -- These buttons typically get loaded during SpecializationInfo's initialization, resulting in numSpecs being 0.
        if numSpecs == 0 then
            self.needsInitialization = true
            return
        end

        -- 4th spec? idk
        if numSpecs > 3 then
            self.specButton1:SetPoint("TOPLEFT", 6, -61)
            self.specButton4:Show()
        end
        
        for i = 1, numSpecs do
            local button = self["specButton"..i]
            local _, name, description, icon = C_SpecializationInfo.GetSpecializationInfo(i, false, isPet)
            SetPortraitToTexture(button.specIcon, icon)
            button.specName:SetText(name)
            button.tooltip = description
            local role = GetSpecializationRole(i, false, isPet)
            button.roleIcon:SetTexCoord(GetTexCoordsForRole(role))
            button.roleName:SetText(_G[role])
        end

        self.needsInitialization = false
    end

    local function Pet_UpdateSpecFrame_Fix(self, spec)
        local isPet = self.isPet or false

        if not isPet then
            return
        end

        local activeSpecializationIndex = nil
        local selectedSpec = TalentUIUtil.GetSelectedSpec()
        local isActiveSpecSelected = TalentUIUtil.IsActiveSpecSelected()
        if not isPet or IsPetActive() then
            activeSpecializationIndex = C_SpecializationInfo.GetSpecialization(nil, isPet, selectedSpec.talentGroup)
        end

        if IsInitialSpec(activeSpecializationIndex) then
            activeSpecializationIndex = nil
        end

        local shownSpec = spec or activeSpecializationIndex or 1
        local numSpecs = GetNumSpecializations(nil, isPet)
        local petNotActive = isPet and not IsPetActive()
        
        -- do spec buttons
        for i = 1, numSpecs do
            local button = self["specButton"..i]
            local disable = false
            if i == shownSpec then
                button.selected = true
                button.selectedTex:Show()
            else
                button.selected = false
                button.selectedTex:Hide()
            end
            if i == activeSpecializationIndex and (not isPet or isActiveSpecSelected) then
                button.learnedTex:Show()
            else
                button.learnedTex:Hide()
            end
            if isActiveSpecSelected and (not activeSpecializationIndex or i == activeSpecializationIndex) then
                button.bg:SetTexCoord(0.00390625, 0.87890625, 0.75195313, 0.83007813)
            else
                button.bg:SetTexCoord(0.00390625, 0.87890625, 0.67187500, 0.75000000)
                disable = true
            end
            
            if petNotActive then
                disable = true
            end

            if disable and not button.disabled then
                button.disabled = true
                SetDesaturation(button.specIcon, true)
                SetDesaturation(button.roleIcon, true)
                SetDesaturation(button.ring, true)
                button.specName:SetFontObject("GameFontDisable")
            elseif not disable and button.disabled then
                button.disabled = false
                SetDesaturation(button.specIcon, false)
                SetDesaturation(button.roleIcon, false)
                SetDesaturation(button.ring, false)
                button.specName:SetFontObject("GameFontNormal")
            end
            
            if button.disabled then
                button.displayTrainerTooltip = not petNotActive
            else
                button.displayTrainerTooltip = false
            end
        end
        
        -- save viewed spec for Learn button
        self.previewSpec = shownSpec

        -- display spec info in the scrollframe
        local scrollChild = self.spellsScroll.child
        local id, name, description, icon = C_SpecializationInfo.GetSpecializationInfo(shownSpec, false, isPet)
        if id == 0 then
            return
        end
        SetPortraitToTexture(scrollChild.specIcon, icon)
        scrollChild.specName:SetText(name)
        scrollChild.description:SetText(description)
        local role1 = GetSpecializationRole(shownSpec, nil, isPet)
        scrollChild.roleName:SetText(_G[role1])
        scrollChild.roleIcon:SetTexCoord(GetTexCoordsForRole(role1))
        -- disable stuff if not in active spec or have picked a specialization and not looking at it
        local disable = (not isActiveSpecSelected) or (activeSpecializationIndex and shownSpec ~= activeSpecializationIndex) or petNotActive
        if disable and not self.disabled then
            self.disabled = true
            self.bg:SetDesaturated(true)
            scrollChild.description:SetTextColor(0.75, 0.75, 0.75)
            scrollChild.roleName:SetTextColor(0.75, 0.75, 0.75)
            scrollChild.specIcon:SetDesaturated(true)
            scrollChild.roleIcon:SetDesaturated(true)
            scrollChild.ring:SetDesaturated(true)
            scrollChild.gradient:SetDesaturated(true)
            scrollChild.Seperator:SetDesaturated(true)
            scrollChild.scrollwork_topleft:SetDesaturated(true)
            scrollChild.scrollwork_topright:SetDesaturated(true)
            scrollChild.scrollwork_bottomleft:SetDesaturated(true)
            scrollChild.scrollwork_bottomright:SetDesaturated(true)
        elseif not disable and self.disabled then
            self.disabled = false
            self.bg:SetDesaturated(false)
            scrollChild.description:SetTextColor(1.0, 1.0, 1.0)
            scrollChild.roleName:SetTextColor(1.0, 1.0, 1.0)
            scrollChild.specIcon:SetDesaturated(false)
            scrollChild.roleIcon:SetDesaturated(false)
            scrollChild.ring:SetDesaturated(false)	
            scrollChild.gradient:SetDesaturated(false)
            scrollChild.Seperator:SetDesaturated(false)
            scrollChild.scrollwork_topleft:SetDesaturated(false)
            scrollChild.scrollwork_topright:SetDesaturated(false)
            scrollChild.scrollwork_bottomleft:SetDesaturated(false)
            scrollChild.scrollwork_bottomright:SetDesaturated(false)
        end
        -- disable Learn button
        if isPet and isActiveSpecSelected and (not petNotActive) and disable then
            self.learnButton:Enable()
            self.learnButton.Flash:Show()
            self.learnButton.FlashAnim:Play()
        elseif activeSpecializationIndex or disable or not C_SpecializationInfo.CanPlayerUseTalentSpecUI() then
            self.learnButton:Disable()
            self.learnButton.Flash:Hide()
            self.learnButton.FlashAnim:Stop()
        else
            self.learnButton:Enable()
            self.learnButton.Flash:Show()
            self.learnButton.FlashAnim:Play()
        end	
		
        if self.playLearnAnim then
            self.playLearnAnim = false
            self["specButton"..shownSpec].animLearn:Play()
        end
		
        -- set up spells
        local index = 1
        local bonuses
        if isPet then
            bonuses = {GetSpecializationSpells(shownSpec, nil, isPet)}
        else
            bonuses = SPEC_SPELLS_DISPLAY[id]
        end
        if bonuses then
            for i=1,#bonuses,2 do
                local frame = scrollChild["abilityButton"..index]
                if not frame then
                    frame = PlayerTalentFrame_CreateSpecSpellButton(self, index)
                end
                if mod(index, 2) == 0 then
                    frame:SetPoint("LEFT", scrollChild["abilityButton"..(index-1)], "RIGHT", 110, 0)
                else
                    if index <= 2 then
                        frame:SetPoint("TOP", scrollChild, "TOP")
                    elseif (#bonuses/2) > 4 then
                        frame:SetPoint("TOP", scrollChild["abilityButton"..(index-2)], "BOTTOM", 0, 0)
                    else
                        frame:SetPoint("TOP", scrollChild["abilityButton"..(index-2)], "BOTTOM", 0, -20)
                    end
                end
				
                local spellName, subname = GetSpellInfo(bonuses[i])
                local _, spellIcon = GetSpellTexture(bonuses[i])
                SetPortraitToTexture(frame.icon, spellIcon)
                frame.name:SetText(spellName)
                frame.spellID = bonuses[i]
                frame.extraTooltip = nil
                frame.isPet = isPet
                local level = C_Spell.GetSpellLevelLearned(bonuses[i])
                if level and level > UnitLevel("player") then
                    frame.subText:SetFormattedText(SPELLBOOK_AVAILABLE_AT, level)
                else
                    frame.subText:SetText("")
                end
                if disable then
                    frame.disabled = true
                    frame.icon:SetDesaturated(true)
                    frame.ring:SetDesaturated(true)
                    frame.subText:SetTextColor(0.75, 0.75, 0.75)
                else
                    frame.disabled = false
                    frame.icon:SetDesaturated(false)
                    frame.ring:SetDesaturated(false)
                    frame.subText:SetTextColor(0.25, 0.1484375, 0.02)
                end
                frame:Show()
                index = index + 1
            end
        end
		
        -- hide unused spell buttons
        local frame = scrollChild["abilityButton"..index]
        while frame do
            frame:Hide()
            frame.spellID = nil
            index = index + 1
            frame = scrollChild["abilityButton"..index]
        end
    end

    if hooksecurefunc then
        hooksecurefunc("PlayerTalentFrameSpec_OnLoad", PetSpec_OnLoad_Fix)
        hooksecurefunc("PlayerTalentFrame_UpdateSpecFrame", Pet_UpdateSpecFrame_Fix)
    end
end

-- Enforce fixed frames
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Blizzard_TalentUI" then
        FixPetTalentSpecDisplay()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)