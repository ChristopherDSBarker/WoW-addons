-- Multi-Mob Threat Meter (Red/Yellow/Green, Real-Time, Player + Group Interactions)
local frameHeight = 20
local mobSpacing = 5
local circleSize = 16
local updateInterval = 0.05
local idleTimeout = 30

-- Main frame
local mainFrame = CreateFrame("Frame", "RealTimeThreatFrame", UIParent, "BackdropTemplate")
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

-- Mob tracking
local mobs = {}
local playerGUID = UnitGUID("player")

-- Track pseudo-threat per mob
local function UpdateTopThreat(sourceGUID, destGUID)
    if not destGUID then return end
    if not mobs[destGUID] then return end
    mobs[destGUID].players = mobs[destGUID].players or {}
    mobs[destGUID].players[sourceGUID] = (mobs[destGUID].players[sourceGUID] or 0) + 1
    mobs[destGUID].lastUpdate = GetTime()
end

-- Check if GUID is a player in your group
local function IsGroupPlayer(guid)
    if guid == playerGUID then return true end
    for i = 1, GetNumGroupMembers() do
        if UnitExists("party"..i) and UnitGUID("party"..i) == guid then return true end
        if UnitExists("raid"..i) and UnitGUID("raid"..i) == guid then return true end
    end
    return false
end

-- Combat log tracking
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, _, ...)
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags,
          spellID, spellName, spellSchool, amount = CombatLogGetCurrentEventInfo()

    if not destGUID then return end

    -- Only track hostile mobs
    local isEnemy = bit.band(destFlags or 0, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    if not isEnemy then return end

    -- Remove dead mobs
    if subevent == "UNIT_DIED" and mobs[destGUID] then
        if mobs[destGUID].frame then mobs[destGUID].frame:Hide() end
        mobs[destGUID] = nil
        return
    end

    -- Only add mobs interacting with player/party/raid
    if IsGroupPlayer(destGUID) or IsGroupPlayer(sourceGUID) then
        if not mobs[destGUID] then
            mobs[destGUID] = {
                name = destName or "Unknown",
                frame = nil,
                circle = nil,
                text = nil,
                lastUpdate = GetTime(),
                players = {},
                hitPlayerTime = (destGUID == playerGUID) and GetTime() or nil,
            }
        else
            mobs[destGUID].lastUpdate = GetTime()
            if destGUID == playerGUID then
                mobs[destGUID].hitPlayerTime = GetTime() -- Red only for player
            end
        end

        -- Track pseudo-threat
        if sourceGUID and sourceGUID ~= destGUID then
            UpdateTopThreat(sourceGUID, destGUID)
        end
    end
end)

-- Update loop
local elapsedSinceUpdate = 0
mainFrame:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < updateInterval then return end
    elapsedSinceUpdate = 0

    local yOffset = 10
    local maxTextWidth = 0
    local currentTime = GetTime()
    local playerGUID = UnitGUID("player")

    for guid, mob in pairs(mobs) do
        -- Remove idle mobs
        if currentTime - mob.lastUpdate > idleTimeout then
            if mob.frame then mob.frame:Hide() end
            mobs[guid] = nil
        else
            -- Create frame if missing
            if not mob.frame then
                mob.frame = CreateFrame("Frame", nil, mainFrame)
                mob.frame:SetHeight(frameHeight)
                
                mob.circle = mob.frame:CreateTexture(nil, "ARTWORK")
                mob.circle:SetSize(circleSize, circleSize)
                mob.circle:SetPoint("LEFT", mob.frame, "LEFT", 0, 0)
                mob.circle:SetTexture("Interface\\BUTTONS\\UI-Panel-Button-Up")

                mob.text = mob.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                mob.text:SetPoint("LEFT", mob.circle, "RIGHT", 5, 0)
                mob.text:Show()
            end

            -- Determine color
            local colorR, colorG, colorB = 0,1,0 -- default green
            local topThreat, maxThreat = nil, 0
            for guidKey, threat in pairs(mob.players) do
                if threat > maxThreat then
                    maxThreat = threat
                    topThreat = guidKey
                end
            end

            if mob.hitPlayerTime and currentTime - mob.hitPlayerTime <= 2 then
                colorR, colorG, colorB = 1,0,0 -- Red for player
            elseif topThreat == playerGUID then
                colorR, colorG, colorB = 1,1,0 -- Yellow if top pseudo-threat
            end

            mob.circle:SetVertexColor(colorR, colorG, colorB)

            -- Update text & position
            mob.text:SetText(mob.name)
            mob.frame:ClearAllPoints()
            mob.frame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -yOffset)
            mob.frame:Show()
            mob.text:Show()

            maxTextWidth = math.max(maxTextWidth, mob.text:GetStringWidth() + circleSize + 5)
            yOffset = yOffset + frameHeight + mobSpacing
        end
    end

    -- Resize frames
    for _, mob in pairs(mobs) do
        if mob.frame then mob.frame:SetWidth(maxTextWidth + 10) end
    end
    mainFrame:SetWidth(maxTextWidth + 20)
    mainFrame:SetHeight(yOffset + 10)
end)

print("|cff00ff00[RealTimeThreatMeter]|r Loaded! Red/Yellow/Green for player; frame shows mobs interacting with group.")
