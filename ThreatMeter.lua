-- Multi-Mob Threat Frame (Real-Time Target-Based, Fixed UNIT_DIED)
local frameHeight = 20
local mobSpacing = 5
local circleSize = 16
local updateInterval = 0.05
local idleTimeout = 30

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

-- Mob tracking table
local mobs = {}

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags,
          amount = CombatLogGetCurrentEventInfo()

    if not destGUID then return end

    -- Remove mob if it dies
    if subevent == "UNIT_DIED" then
        if mobs[destGUID] and mobs[destGUID].frame then
            mobs[destGUID].frame:Hide()
        end
        mobs[destGUID] = nil
        return
    end

    -- Only track hostile mobs
    local isEnemy = bit.band(destFlags or 0, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    if not isEnemy then return end

    if not mobs[destGUID] then
        mobs[destGUID] = {
            name = destName or "Unknown",
            unit = nil,
            frame = nil,
            circle = nil,
            text = nil,
            lastUpdate = GetTime(),
        }
    else
        mobs[destGUID].name = mobs[destGUID].name ~= "" and mobs[destGUID].name or (destName or "Unknown")
    end
    mobs[destGUID].lastUpdate = GetTime()
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
            -- Assign unit if unknown
            if not mob.unit then
                for _, u in pairs({"target", "mouseover"}) do
                    if UnitExists(u) and UnitGUID(u) == guid then
                        mob.unit = u
                        break
                    end
                end
            end

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

            -- Determine color based on target
            local colorR, colorG, colorB = 0,1,0 -- default green
            if mob.unit and UnitExists(mob.unit.."target") then
                local targetGUID = UnitGUID(mob.unit.."target")
                if targetGUID == playerGUID then
                    colorR, colorG, colorB = 1,0,0 -- red if attacking me
                end
            end
            mob.circle:SetVertexColor(colorR, colorG, colorB)

            -- Update text and frame position
            mob.text:SetText(mob.name)
            mob.frame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -yOffset)
            mob.frame:Show()

            local textWidth = mob.text:GetStringWidth() + circleSize + 5
            if textWidth > maxTextWidth then maxTextWidth = textWidth end
            yOffset = yOffset + frameHeight + mobSpacing
        end
    end

    -- Resize frames
    for guid, mob in pairs(mobs) do
        if mob.frame then mob.frame:SetWidth(maxTextWidth + 10) end
    end

    mainFrame:SetWidth(maxTextWidth + 20)
    mainFrame:SetHeight(yOffset + 10)
end)

print("|cff00ff00[MultiThreatMeter]|r Loaded! Real-time target-based threat active.")
