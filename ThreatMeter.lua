-- Multi-Mob Threat Meter (Using UNIT_DIED)
local frameHeight = 20
local mobSpacing = 5
local circleSize = 16
local updateInterval = 0.05
local idleTimeout = 30
local threatDecayPerSecond = 50

-- Main frame
local mainFrame = CreateFrame("Frame", "CombatThreatFrame", UIParent, "BackdropTemplate")
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left=4, right=4, top=4, bottom=4}
})
mainFrame:SetBackdropColor(0,0,0,0.6)

-- Threat table
local mobs = {}

-- Threat multiplier helper
local function GetThreatMultiplier(subevent)
    if subevent:match("SWING") then return 1
    elseif subevent:match("SPELL") then return 1.5
    elseif subevent:match("RANGE") then return 1.0
    else return 1 end
end

-- Combat log tracking
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags,
          amount = CombatLogGetCurrentEventInfo()

    if not destGUID or not destName then return end

    -- Remove mob if it died
    if subevent == "UNIT_DIED" then
        if mobs[destGUID] and mobs[destGUID].frame then
            mobs[destGUID].frame:Hide()
        end
        mobs[destGUID] = nil
        return
    end

    -- Only track player/group members
    local validSource = sourceGUID == UnitGUID("player")
    if not validSource then
        for i=1, GetNumGroupMembers() do
            local unit = IsInRaid() and "raid"..i or "party"..i
            if UnitGUID(unit) == sourceGUID then validSource = true; break end
        end
    end

    local isEnemy = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    if validSource and isEnemy then
        if not mobs[destGUID] then
            mobs[destGUID] = {name=destName, players={}, frame=nil, circle=nil, text=nil, lastUpdate=GetTime()}
        end
        local mob = mobs[destGUID]
        local mult = GetThreatMultiplier(subevent)
        local numericAmount = tonumber(amount) or 0
        local threatAmount = numericAmount * mult
        mob.players[sourceGUID] = (mob.players[sourceGUID] or 0) + threatAmount
        mob.lastUpdate = GetTime()
    end
end)

-- Update frame
local elapsedSinceUpdate = 0
mainFrame:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < updateInterval then return end
    local deltaTime = elapsedSinceUpdate
    elapsedSinceUpdate = 0

    local yOffset = 10
    local maxTextWidth = 0
    local currentTime = GetTime()
    local sortedMobs = {}
    local playerGUID = UnitGUID("player")
    local playerAlive = not UnitIsDeadOrGhost("player")
    local playerVisible = UnitIsVisible("player") and not UnitIsFeignDeath("player")
    local inCombat = UnitAffectingCombat("player")

    -- Reset player threat immediately if dead/invisible/out of combat
    if not playerAlive or not playerVisible or not inCombat then
        for _, mob in pairs(mobs) do
            mob.players[playerGUID] = 0
        end
    end

    for guid, mob in pairs(mobs) do
        if currentTime - mob.lastUpdate > idleTimeout then
            if mob.frame then mob.frame:Hide() end
            mobs[guid] = nil
        else
            -- Max threat calculation
            local maxThreat = 0
            for _, t in pairs(mob.players) do
                if t > maxThreat then maxThreat = t end
            end
            local playerThreat = mob.players[playerGUID] or 0
            local pct = maxThreat > 0 and (playerThreat / maxThreat) * 100 or 0

            -- Create frame if missing
            if not mob.frame then
                mob.frame = CreateFrame("Frame", nil, mainFrame)
                mob.frame:SetHeight(frameHeight)

                mob.circle = mob.frame:CreateTexture(nil, "ARTWORK")
                mob.circle:SetSize(circleSize, circleSize)
                mob.circle:SetPoint("LEFT", mob.frame, "LEFT", 0, 0)
                mob.circle:SetTexture("Interface\\BUTTONS\\UI-Panel-Button-Up")
                mob.circle:SetVertexColor(0,1,0)

                mob.text = mob.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                mob.text:SetPoint("LEFT", mob.circle, "RIGHT", 5, 0)
            end

            -- Update color
            if pct >= 100 then
                mob.circle:SetVertexColor(1,0,0)
            elseif pct >= 80 then
                mob.circle:SetVertexColor(1,1,0)
            else
                mob.circle:SetVertexColor(0,1,0)
            end

            mob.frame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -yOffset)
            mob.text:SetText(mob.name)
            mob.frame:Show()

            -- Decay for other players
            for guid2, threat in pairs(mob.players) do
                if guid2 ~= playerGUID then
                    mob.players[guid2] = math.max(threat - threatDecayPerSecond * deltaTime, 0)
                end
            end

            -- Total threat
            mob.totalThreat = 0
            for _, t in pairs(mob.players) do
                mob.totalThreat = mob.totalThreat + t
            end

            table.insert(sortedMobs, mob)
            local textWidth = mob.text:GetStringWidth() + circleSize + 5
            if textWidth > maxTextWidth then maxTextWidth = textWidth end
            yOffset = yOffset + frameHeight + mobSpacing
        end
    end

    -- Sort by player threat
    table.sort(sortedMobs, function(a,b)
        local aThreat = a.players[playerGUID] or 0
        local bThreat = b.players[playerGUID] or 0
        return aThreat > bThreat
    end)

    -- Resize frames
    for _, mob in ipairs(sortedMobs) do
        if mob.frame then mob.frame:SetWidth(maxTextWidth + 10) end
    end

    mainFrame:SetWidth(maxTextWidth + 20)
    mainFrame:SetHeight(yOffset + 10)
end)

print("|cff00ff00[MultiThreatMeter]|r Loaded! UNIT_DIED handling active.")
