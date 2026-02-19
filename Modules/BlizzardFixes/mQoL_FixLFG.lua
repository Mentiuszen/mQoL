local addonName = ...

--Blizzard fixed it removed in 1.1.0

local function IsChallengeModeActivity(activityID)
    if not activityID then return false end
    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    return activityInfo and activityInfo.isMythicPlusActivity
end

local function GetCurrentActivityID()
    local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
    return activeEntryInfo and activeEntryInfo.activityIDs and activeEntryInfo.activityIDs[1]
end

local function SafeNumMembers(num)
    if type(num) ~= "number" or num <= 0 then
        return 1
    end
    return num
end

-- Fix Challenge Modes search tooltip
local original_LFGListUtil_SetSearchEntryTooltip = LFGListUtil_SetSearchEntryTooltip
function LFGListUtil_SetSearchEntryTooltip(tooltip, resultID, autoAcceptOption)
    local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not searchResultInfo then 
        if original_LFGListUtil_SetSearchEntryTooltip then
            return original_LFGListUtil_SetSearchEntryTooltip(tooltip, resultID, autoAcceptOption)
        end
        return 
    end
    
    local activityID = searchResultInfo.activityIDs and searchResultInfo.activityIDs[1]
    
    -- if group is challenge modes use fixed version
    if IsChallengeModeActivity(activityID) then
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID, nil, searchResultInfo.isWarMode)
        if not activityInfo then return end
        
        local categoryInfo = C_LFGList.GetLfgCategoryInfo(activityInfo.categoryID)
        local memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID)
        
        tooltip:SetText(searchResultInfo.name, 1, 1, 1, true)
        tooltip:AddLine(activityInfo.fullName)
        
        if searchResultInfo.comment and searchResultInfo.comment ~= "" then
            tooltip:AddLine(string.format(LFG_LIST_COMMENT_FORMAT, searchResultInfo.comment), 
                           LFG_LIST_COMMENT_FONT_COLOR.r, LFG_LIST_COMMENT_FONT_COLOR.g, 
                           LFG_LIST_COMMENT_FONT_COLOR.b, true)
        end
        
        tooltip:AddLine(" ")
        
        if searchResultInfo.requiredItemLevel > 0 then
            if activityInfo.isPvpActivity then
                tooltip:AddLine(LFG_LIST_TOOLTIP_ILVL_PVP:format(searchResultInfo.requiredItemLevel))
            else
                tooltip:AddLine(LFG_LIST_TOOLTIP_ILVL:format(searchResultInfo.requiredItemLevel))
            end
        end
        
        if searchResultInfo.voiceChat ~= "" then
            tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_VOICE_CHAT, searchResultInfo.voiceChat), nil, nil, nil, true)
        end
        
        if searchResultInfo.requiredItemLevel > 0 or searchResultInfo.voiceChat ~= "" then
            tooltip:AddLine(" ")
        end

        if searchResultInfo.leaderName then
            tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_LEADER, searchResultInfo.leaderName))
        end
        
        if searchResultInfo.age > 0 then
            tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_AGE, SecondsToTime(searchResultInfo.age, false, false, 1, false)))
        end

        if searchResultInfo.leaderName or searchResultInfo.age > 0 then
            tooltip:AddLine(" ")
        end

        tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_MEMBERS, searchResultInfo.numMembers, 
                                     memberCounts.TANK or 0, memberCounts.HEALER or 0, memberCounts.DAMAGER or 0))

        if searchResultInfo.numBNetFriends + searchResultInfo.numCharFriends + searchResultInfo.numGuildMates > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine(LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP)
            tooltip:AddLine(LFGListSearchEntryUtil_GetFriendList(resultID), 1, 1, 1, true)
        end
        
        if searchResultInfo.autoAccept then
            tooltip:AddLine(" ")
            tooltip:AddLine(LFG_LIST_TOOLTIP_AUTO_ACCEPT, LIGHTBLUE_FONT_COLOR:GetRGB())
        end

        if searchResultInfo.isDelisted then
            tooltip:AddLine(" ")
            tooltip:AddLine(LFG_LIST_ENTRY_DELISTED, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
        end

        tooltip:Show()
    else
        -- for other groups use blizzard code
        if original_LFGListUtil_SetSearchEntryTooltip then
            return original_LFGListUtil_SetSearchEntryTooltip(tooltip, resultID, autoAcceptOption)
        end
    end
end

-- Fix Challenge Modes applicant
local original_LFGListApplicantMember_OnEnter = LFGListApplicantMember_OnEnter
function LFGListApplicantMember_OnEnter(self)
    local currentActivityID = GetCurrentActivityID()
    
    if IsChallengeModeActivity(currentActivityID) then
        local applicantID = self:GetParent().applicantID
        local memberIdx = self.memberIdx

        local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
        if not activeEntryInfo then return end

        local activityInfo = C_LFGList.GetActivityInfoTable(activeEntryInfo.activityIDs[1])
        if not activityInfo then return end
        
        local applicantInfo = C_LFGList.GetApplicantInfo(applicantID)
        local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)

        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 105, 0)

        if name then
            local classTextColor = RAID_CLASS_COLORS[class]
            GameTooltip:SetText(name, classTextColor.r, classTextColor.g, classTextColor.b)
            GameTooltip_AddHighlightLine(GameTooltip, UNIT_TYPE_LEVEL_TEMPLATE:format(level, localizedClass))
        else
            GameTooltip:SetText(" ")
        end

        if itemLevel and itemLevel > 0 then
            if activityInfo.isPvpActivity then
                GameTooltip_AddColoredLine(GameTooltip, LFG_LIST_ITEM_LEVEL_CURRENT_PVP:format(itemLevel), HIGHLIGHT_FONT_COLOR)
            else
                GameTooltip_AddColoredLine(GameTooltip, LFG_LIST_ITEM_LEVEL_CURRENT:format(itemLevel), HIGHLIGHT_FONT_COLOR)
            end
        end

        local roleText = ""
        if tank then roleText = roleText .. " |T"..GetTexCoordsForRole("TANK")..":14|t" end
        if healer then roleText = roleText .. " |T"..GetTexCoordsForRole("HEALER")..":14|t" end
        if damage then roleText = roleText .. " |T"..GetTexCoordsForRole("DAMAGER")..":14|t" end
        
        if roleText ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Role: " .. roleText)
        end

        if applicantInfo and applicantInfo.comment and applicantInfo.comment ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format(LFG_LIST_COMMENT_FORMAT, applicantInfo.comment), LFG_LIST_COMMENT_FONT_COLOR.r, LFG_LIST_COMMENT_FONT_COLOR.g, LFG_LIST_COMMENT_FONT_COLOR.b, true)
        end
        
        GameTooltip:Show()
    else
        -- for other groups use blizzard code
        if original_LFGListApplicantMember_OnEnter then
            return original_LFGListApplicantMember_OnEnter(self)
        end
    end
end

-- Fix UpdateInviteState
local original_LFGListApplicationViewer_UpdateInviteState = LFGListApplicationViewer_UpdateInviteState
local function MyLFGListApplicationViewer_UpdateInviteState(self)
    if not self or not self.ScrollBox then 
        if original_LFGListApplicationViewer_UpdateInviteState then
            return original_LFGListApplicationViewer_UpdateInviteState(self)
        end
        return 
    end

    local activeEntryInfo = C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
    if not activeEntryInfo then 
        if original_LFGListApplicationViewer_UpdateInviteState then
            return original_LFGListApplicationViewer_UpdateInviteState(self)
        end
        return 
    end

    local activityInfo = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activeEntryInfo.activityIDs[1], activeEntryInfo.questID)
    local numAllowed = (activityInfo and activityInfo.maxNumPlayers) or MAX_RAID_MEMBERS
    local currentCount = GetNumGroupMembers and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) or 0
    local numInvited = C_LFGList.GetNumInvitedApplicantMembers and C_LFGList.GetNumInvitedApplicantMembers() or 0

    self.ScrollBox:ForEachFrame(function(button)
        local btnMembers = SafeNumMembers(button.numMembers)

        if button.InviteButton then
            if (btnMembers + currentCount > numAllowed) then
                button.InviteButton:Disable()
                button.InviteButton.tooltip = LFG_LIST_GROUP_TOO_FULL
            elseif (btnMembers + currentCount + numInvited > numAllowed) then
                button.InviteButton:Disable()
                button.InviteButton.tooltip = LFG_LIST_INVITED_APP_FILLS_GROUP
            else
                button.InviteButton:Enable()
                button.InviteButton.tooltip = nil
            end

            if button.InviteButton:IsMouseOver() then
                if button.InviteButton.tooltip and button.InviteButton:GetScript("OnEnter") then
                    button.InviteButton:GetScript("OnEnter")(button.InviteButton)
                else
                    GameTooltip:Hide()
                end
            end
        end
    end)
end

-- Fix UpdateApplicantMember
local original_LFGListApplicationViewer_UpdateApplicantMember = LFGListApplicationViewer_UpdateApplicantMember
local function MyLFGListApplicationViewer_UpdateApplicantMember(member, appID, memberIdx, status, pendingStatus)
    local currentActivityID = GetCurrentActivityID()
    local isChallengeMode = IsChallengeModeActivity(currentActivityID)
    
    -- for other groups use blizzard code
    if not isChallengeMode and original_LFGListApplicationViewer_UpdateApplicantMember then
        return original_LFGListApplicationViewer_UpdateApplicantMember(member, appID, memberIdx, status, pendingStatus)
    end
    
    -- for Challange modes use fixed
    if not member or not appID or type(memberIdx) ~= "number" then 
        if original_LFGListApplicationViewer_UpdateApplicantMember then
            return original_LFGListApplicationViewer_UpdateApplicantMember(member, appID, memberIdx, status, pendingStatus)
        end
        return 
    end

    local grayedOut = not pendingStatus and (status=="failed" or status=="cancelled" or status=="declined" or status=="declined_full" or status=="declined_delisted" or status=="invitedeclined" or status=="timedout" or status=="inviteaccepted" or status=="invitedeclined")
    local noTouchy = (status == "invited")

    local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship
        = C_LFGList.GetApplicantMemberInfo and C_LFGList.GetApplicantMemberInfo(appID, memberIdx)

    member.memberIdx = memberIdx

    if member.Name then
        member.Name:SetWidth(0)
        if name then
            local displayName = Ambiguate(name, "short")
            member.Name:SetText((memberIdx > 1 and "  " or "")..displayName)
            local classTextColor = grayedOut and GRAY_FONT_COLOR or (RAID_CLASS_COLORS[class] or HIGHLIGHT_FONT_COLOR)
            member.Name:SetTextColor(classTextColor.r, classTextColor.g, classTextColor.b)
        else
            member.Name:SetText("")
        end
    end

    if member.FriendIcon then
        member.FriendIcon:SetShown(relationship)
        member.FriendIcon.relationship = relationship
        if member.FriendIcon.Icon then
            member.FriendIcon.Icon:SetDesaturated(grayedOut)
        end
        member.FriendIcon:SetAlpha(grayedOut and 0.5 or 1)
    end

    local nameLength = 100
    if relationship then nameLength = nameLength - 22 end
    if member.Name and member.Name:GetWidth() > nameLength then
        member.Name:SetWidth(nameLength)
    end

    if member.TankIcon then
        member.TankIcon:SetShown(tank and not grayedOut)
        if tank then
            member.TankIcon:SetDesaturated(grayedOut)
        end
    end

    if member.HealerIcon then
        member.HealerIcon:SetShown(healer and not grayedOut)
        if healer then
            member.HealerIcon:SetDesaturated(grayedOut)
        end
    end

    if member.DamagerIcon then
        member.DamagerIcon:SetShown(damage and not grayedOut)
        if damage then
            member.DamagerIcon:SetDesaturated(grayedOut)
        end
    end

    local activeEntryInfo = C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
    local activityInfo = (activeEntryInfo and C_LFGList.GetActivityInfoTable) and C_LFGList.GetActivityInfoTable(activeEntryInfo.activityIDs[1]) or nil

    if member.ItemLevel then
        member.ItemLevel:SetShown(not grayedOut)
        if itemLevel and itemLevel > 0 then
            member.ItemLevel:SetText(math.floor(itemLevel))
        else
            member.ItemLevel:SetText("0")
        end
    end

    -- hide mythic+ rating why its even here (m+ for classic confirmed? XD) (nah just lazy devs copy pasting retail code without even looking at this)
    if member.Rating then
        member.Rating:Hide()
    end

    if member.SetWidth then 
        member:SetWidth(200) 
    end

    if GetMouseFoci then
        local mouseFoci = GetMouseFoci()
        for _, mouseFocus in ipairs(mouseFoci) do
            if mouseFocus == member then
                if LFGListApplicantMember_OnEnter then LFGListApplicantMember_OnEnter(member) end
                break
            elseif mouseFocus == member.FriendIcon and member.FriendIcon:GetScript("OnEnter") then
                member.FriendIcon:GetScript("OnEnter")(member.FriendIcon)
                break
            end
        end
    end
end

if LFGListApplicationViewer_UpdateInviteState then
    LFGListApplicationViewer_UpdateInviteState = MyLFGListApplicationViewer_UpdateInviteState
end

if LFGListApplicationViewer_UpdateApplicantMember then
    LFGListApplicationViewer_UpdateApplicantMember = MyLFGListApplicationViewer_UpdateApplicantMember
end

hooksecurefunc("LFGListApplicationViewer_UpdateApplicant", function(button, applicantID, status, pendingStatus)
    local currentActivityID = GetCurrentActivityID()
    if not IsChallengeModeActivity(currentActivityID) then return end
    
    local applicantInfo = C_LFGList.GetApplicantInfo(applicantID)
    if not applicantInfo then return end
    
    if button.ItemLevel then
        local totalItemLevel = 0
        local memberCount = 0
        
        for i=1, applicantInfo.numMembers do
            local name, class, localizedClass, level, itemLevel = C_LFGList.GetApplicantMemberInfo(applicantID, i)
            if itemLevel and itemLevel > 0 then
                totalItemLevel = totalItemLevel + itemLevel
                memberCount = memberCount + 1
            end
        end
        
        if memberCount > 0 then
            button.ItemLevel:SetText(math.floor(totalItemLevel / memberCount))
        else
            button.ItemLevel:SetText("0")
        end
    end
end)