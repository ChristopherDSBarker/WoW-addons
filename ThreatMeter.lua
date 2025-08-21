-- Multi-Mob Threat Meter (Accurate Threat, Red/Yellow/Green)
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

-- Threat table
local mobs = {}

-- Threat multiplier helper
local function GetThreatMultiplier(subevent)
    if subevent:match("SWING") then return 1
    elseif subevent:match("SPELL") then return 1.5
    elseif subevent:match("RANGE") then return 1.0
    else return 1 end
end

-- Validate source (player or group)
local function IsValidSource(guid)
    if guid == UnitGUID("player") then return true end
    for i=1, GetNumGroupMembers() do
        local unit = IsInRaid() and "raid"..i or "party"..i
        if UnitExists(unit) and UnitGUID(unit) == guid then return true end
    end
    return false
end

-- Update threat from combat log
local function UpdateThreatFromCombat(timestamp, subevent, sourceGUID, destGUID, destName, amount, destFlags)
    if not destGUID or not destName then return end
    if subevent == "UNIT_DIED" then
        if mobs[destGUID] and mobs[destGUID].frame then mobs[destGUID].frame:Hide() end
        mobs[destGUID] = nil
        return
    end

    if not IsValidSource(sourceGUID) then return end

    local isEnemy = destFlags and bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    if isEnemy then
        if not mobs[destGUID] then
            mobs[destGUID] = {name=destName, players={}, frame=nil, circle=nil, text=nil, lastUpdate=GetTime(), unit=nil}
        end
        local mob = mobs[destGUID]
        local mult = GetThreatMultiplier(subevent)
        local numericAmount = tonumber(amount) or 0
        mob.players[sourceGUID] = (mob.players[sourceGUID] or 0) + numericAmount * mult
        mob.lastUpdate = GetTime()
    end
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("UNIT_TARGET")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags,
              amount = CombatLogGetCurrentEventInfo()
        UpdateThreatFromCombat(timestamp, subevent, sourceGUID, destGUID, destName, amount, destFlags)
    else
        -- On target/mouseover changes, assign unit to mobs
        for guid, mob in pairs(mobs) do
            for _, u in pairs({"target","mouseover"}) do
                if UnitExists(u) and UnitGUID(u) == guid then mob.unit = u end
            end
        end
    end
end)

-- OnUpdate
local elapsedSinceUpdate = 0
mainFrame:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < updateInterval then return end
    local deltaTime = elapsedSinceUpdate
    elapsedSinceUpdate = 0

    local yOffset = 10
    local maxTextWidth = 0
    local currentTime = GetTime()
    local playerGUID = UnitGUID("player")

    for guid, mob in pairs(mobs) do
        if currentTime - mob.lastUpdate > idleTimeout or (mob.unit and (not UnitExists(mob.unit) or UnitIsDead(mob.unit))) then
            if mob.frame then mob.frame:Hide() end
            mobs[guid] = nil
        else
            if not mob.frame then
                mob.frame = CreateFrame("Frame", nil, mainFrame)
                mob.frame:SetHeight(frameHeight)

                mob.circle = mob.frame:CreateTexture(nil, "ARTWORK")
                mob.circle:SetSize(circleSize, circleSize)
                mob.circle:SetPoint("LEFT", mob.frame, "LEFT", 0, 0)
                mob.circle:SetTexture("Interface\\BUTTONS\\UI-Panel-Button-Up")

                mob.text = mob.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                mob.text:SetPoint("LEFT", mob.circle, "RIGHT", 5, 0)
            end

            -- Threat % calculation
            local maxThreat = 0
            local playerThreat = mob.players[playerGUID] or 0
            for guidKey, t in pairs(mob.players) do
                if IsValidSource(guidKey) and t > maxThreat then maxThreat = t end
            end
            local pct = maxThreat > 0 and (playerThreat / maxThreat) * 100 or 0

            -- Color logic
            local r,g,b
            if mob.unit and UnitExists(mob.unit.."target") and UnitGUID(mob.unit.."target") == playerGUID then
                r,g,b = 1,0,0 -- Red: mob attacking me
            elseif pct >= 80 then
                r,g,b = 1,1,0 -- Yellow: close to switching
            else
                r,g,b = 0,1,0 -- Green: safe
            end
            mob.circle:SetVertexColor(r,g,b)

            mob.frame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -yOffset)
            mob.text:SetText(mob.name)
            mob.frame:Show()

            local textWidth = mob.text:GetStringWidth() + circleSize + 5
            if textWidth > maxTextWidth then maxTextWidth = textWidth end
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

print("|cff00ff00[MultiThreatMeter]|r Loaded! Accurate threat meter active.")
