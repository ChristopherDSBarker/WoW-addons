-- DangerAlert.lua
-- Alerts for CC, AOE, melee/ranged, and targeting with distinct audio cues

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

local flashFrame = CreateFrame("Frame", nil, UIParent)
flashFrame:SetAllPoints(UIParent)
flashFrame.texture = flashFrame:CreateTexture()
flashFrame.texture:SetAllPoints()
flashFrame.texture:SetColorTexture(1, 0, 0, 0)
flashFrame:Hide()

local function FlashScreen(duration)
    flashFrame:Show()
    flashFrame.texture:SetAlpha(0.5)
    C_Timer.After(duration, function() flashFrame:Hide() end)
end

local alertedSpells = {}

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        print("|cff00ff00[DangerAlert]|r Loaded and ready!")
        alertedSpells = {} -- reset every login
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
        if destGUID == UnitGUID("player") and sourceGUID ~= UnitGUID("player") then
            -- Crowd Control alert
            if subevent == "SPELL_AURA_APPLIED" and spellName then
                if not alertedSpells[spellID] then
                    print("|cffff8000[DangerAlert]|r CC detected: "..spellName.." (ID: "..spellID..")")
                    UIErrorsFrame:AddMessage("CC Incoming: "..spellName, 1, 0.5, 0)
                    PlaySound(5693)  -- CC sound
                    FlashScreen(0.3)
                    alertedSpells[spellID] = true
                end
            end
            -- Damage / AOE / melee / ranged
            if subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE"
               or subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE" then
                UIErrorsFrame:AddMessage("Damage Incoming: "..(spellName or "Unknown"), 1, 0.5, 0)
                PlaySound(5691)  -- different AOE/damage sound
                FlashScreen(0.2)
            end
            -- Missed attacks (optional)
            if subevent == "SPELL_MISSED" then
                UIErrorsFrame:AddMessage("Missed Attack: "..(spellName or "Unknown"), 1, 0.5, 0)
                PlaySound(5692)  -- optional distinct sound
                FlashScreen(0.2)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitCanAttack("target", "player") and UnitIsUnit("targettarget", "player") then
            UIErrorsFrame:AddMessage("You are targeted!", 1, 0, 0)
            PlaySound(5690)  -- targeting alert sound
            FlashScreen(0.4)
        end
    end
end)
