-- Multi-Mob Threat Meter (Real-Time, Red/Yellow/Green, Party/Raid)
local frameHeight = 20
local mobSpacing = 5
local circleSize = 16
local updateInterval = 0.05
local idleTimeout = 30

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

local mobs = {}
local playerGUID = UnitGUID("player")

-- Track pseudo-threat
local function UpdateTopThreat(sourceGUID, destGUID, isHitPlayer)
    if not destGUID then return end
    if not mobs[destGUID] then return end
    mobs[destGUID].players = mobs[destGUID].players or {}
    mobs[destGUID].players[sourceGUID] = (mobs[destGUID].players[sourceGUID] or 0) + 1
    mobs[destGUID].lastUpdate = GetTime()

    -- Track if mob recently hit the player
    if isHitPlayer then
        mobs[destGUID].hitPlayerTime = GetTime()
    end
end

-- Combat log tracking
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags,
          spellID, spellName, spellSchool, amount = CombatLogGetCurrentEventInfo()

    -- Remove dead mobs
    if subevent == "UNIT_DIED" and mobs[destGUID] then
        if mobs[destGUID].frame then mobs[destGUID].frame:Hide() end
        mobs[destGUID] = nil
        return
    end

    -- Only track hostile mobs
    local isEnemy = bit.band(destFlags or 0, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    if not isEnemy or not destGUID then return end

    -- Initialize mob
    if not mobs[destGUID] then
        mobs[destGUID] = {
            name = destName or "Unknown",
            frame = nil,
            circle = nil,
            text = nil,
            lastUpdate = GetTime(),
            players = {},
            hitPlayerTime = 0,
        }
    else
        mobs[destGUID].name = mobs[destGUID].name ~= "" and mobs[destGUID].name or (destName or "Unknown")
        mobs[destGUID].lastUpdate = GetTime()
    end

    -- Determine if this event hit the player
    local hitPlayer = false
    if destGUID == playerGUID and (subevent:find("DAMAGE") or subevent:find("SPELL") or subevent:find("ENVIRONMENTAL")) then
        hitPlayer = true
    end

    -- Update pseudo-threat
    if sourceGUID then UpdateTopThreat(sourceGUID, destGUID, hitPlayer) end
end)

-- Update loop
local elapsedSinceUpdate = 0
mainFrame:SetScript("OnUpdate", function(self, elapsed)
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
                -- Red if mob hit player in last 2 seconds
                colorR, colorG, colorB = 1,0,0
            elseif topThreat == playerGUID then
                -- Yellow if top pseudo-threat but mob not attacking you
                colorR, colorG, colorB = 1,1,0
            end

            mob.circle:SetVertexColor(colorR, colorG, colorB)

            -- Update text & position
            mob.text:SetText(mob.name)
            mob.frame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -yOffset)
            mob.frame:Show()

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

print("|cff00ff00[RealTimeThreatMeter]|r Loaded! Red/Yellow/Green working for party/raid.")
