-- Multi-Mob Threat Meter (Red/Yellow/Green, Accurate)
local frameHeight, mobSpacing, circleSize, updateInterval, idleTimeout = 20, 5, 16, 0.05, 10
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

local mobs, playerGUID = {}, UnitGUID("player")

local function IsGroupPlayer(guid)
    if guid == playerGUID then return true end
    for i=1,GetNumGroupMembers() do
        if UnitExists("party"..i) and UnitGUID("party"..i)==guid then return true end
        if UnitExists("raid"..i) and UnitGUID("raid"..i)==guid then return true end
    end
    return false
end

local function AddOrUpdateMob(sourceGUID,destGUID,sourceName,destName)
    if not sourceGUID or not destGUID then return end
    if sourceGUID==playerGUID or destGUID==playerGUID then return end -- ignore player entirely

    local mobName = destName or "Unknown"
    if not mobs[destGUID] then
        mobs[destGUID] = {name=mobName, players={}, lastUpdate=GetTime(), frame=nil, circle=nil, text=nil}
    else
        mobs[destGUID].lastUpdate = GetTime()
        if destName then mobs[destGUID].name = destName end
    end
    mobs[destGUID].players[sourceGUID] = (mobs[destGUID].players[sourceGUID] or 0) + 1
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_,_,...)
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags,
          spellID, spellName, spellSchool, amount = CombatLogGetCurrentEventInfo()

    local isEnemy = bit.band(destFlags or 0, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    if not isEnemy then return end

    if subevent=="UNIT_DIED" and mobs[destGUID] then
        if mobs[destGUID].frame then mobs[destGUID].frame:Hide() end
        mobs[destGUID] = nil
        return
    end

    if IsGroupPlayer(destGUID) or IsGroupPlayer(sourceGUID) then
        AddOrUpdateMob(sourceGUID,destGUID,sourceName,destName)
        AddOrUpdateMob(destGUID,sourceGUID,destName,sourceName)
    end
end)

local elapsedSinceUpdate=0
mainFrame:SetScript("OnUpdate",function(_,elapsed)
    elapsedSinceUpdate=elapsedSinceUpdate+elapsed
    if elapsedSinceUpdate<updateInterval then return end
    elapsedSinceUpdate=0

    local yOffset,maxTextWidth,currentTime=10,0,GetTime()

    for guid,mob in pairs(mobs) do
        if currentTime - mob.lastUpdate > idleTimeout then
            if mob.frame then mob.frame:Hide() end
            mobs[guid]=nil
        else
            local targeting=false
            for i=1,40 do
                local unit="nameplate"..i
                if UnitExists(unit) and UnitGUID(unit)==guid then
                    if UnitGUID(unit.."target")==playerGUID then
                        targeting=true
                        break
                    end
                end
            end
            mob.targetingPlayer=targeting

            if not mob.frame then
                mob.frame=CreateFrame("Frame",nil,mainFrame)
                mob.frame:SetHeight(frameHeight)

                mob.circle=mob.frame:CreateTexture(nil,"ARTWORK")
                mob.circle:SetSize(circleSize,circleSize)
                mob.circle:SetPoint("LEFT",mob.frame,"LEFT",0,0)
                mob.circle:SetTexture("Interface\\BUTTONS\\UI-Panel-Button-Up")

                mob.text=mob.frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
                mob.text:SetPoint("LEFT",mob.circle,"RIGHT",5,0)
                mob.text:Show()
            end

            local colorR,colorG,colorB=0,1,0
            local topThreat,maxThreat=nil,0
            for guidKey,threat in pairs(mob.players) do
                if threat>maxThreat then
                    maxThreat=threat
                    topThreat=guidKey
                end
            end

            if mob.targetingPlayer then
                colorR,colorG,colorB=1,0,0
            elseif topThreat==playerGUID then
                colorR,colorG,colorB=1,1,0
            end

            mob.circle:SetVertexColor(colorR,colorG,colorB)
            mob.text:SetText(mob.name)
            mob.frame:ClearAllPoints()
            mob.frame:SetPoint("TOPLEFT",mainFrame,"TOPLEFT",10,-yOffset)
            mob.frame:Show()
            mob.text:Show()

            maxTextWidth=math.max(maxTextWidth,mob.text:GetStringWidth()+circleSize+5)
            yOffset=yOffset+frameHeight+mobSpacing
        end
    end

    for _,mob in pairs(mobs) do
        if mob.frame then mob.frame:SetWidth(maxTextWidth+10) end
    end
    mainFrame:SetWidth(maxTextWidth+20)
    mainFrame:SetHeight(yOffset+10)
end)

print("|cff00ff00[RealTimeThreatMeter]|r Loaded! Colors: Red/Yellow/Green accurate to player; only mobs shown, player no longer appears as Unknown.")
