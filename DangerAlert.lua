-- DangerAlert.lua
-- Alerts for CC, AOE, and targeting with auto-detect for unknown CCs

-- Main frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

-- Flash overlay
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

-- Known CCs
local CCSpells = {
    -- Polymorph / Transformation
    [118] = "Polymorph",
    [28272] = "Polymorph: Pig",
    [28271] = "Polymorph: Turtle",
    [61721] = "Polymorph: Rabbit",
    [61305] = "Polymorph: Black Cat",
    [61780] = "Polymorph: Turkey",
    -- Stuns
    [853] = "Hammer of Justice",
    [108194] = "Asphyxiate",
    [5211] = "Mighty Bash",
    [22570] = "Maim",
    [91797] = "Monstrous Blow",
    [105421] = "Blinding Light",
    [132168] = "Shockwave",
    [46968] = "Shockwave (PvE)",
    [1833] = "Cheap Shot",
    [408] = "Kidney Shot",
    [183752] = "Disorienting Roar",
    [118905] = "Static Charge",
    -- Roots / Immobilize
    [339] = "Entangling Roots",
    [122] = "Frost Nova",
    [114404] = "Void Tendril’s Grasp",
    [3355] = "Freezing Trap",
    [19185] = "Entrapment",
    [33395] = "Freeze",
    [23694] = "Intimidating Shout (root effect)",
    -- Fears / Disorients
    [5782] = "Fear",
    [118699] = "Fear (PvP Talent)",
    [5246] = "Intimidating Shout",
    [5484] = "Howl of Terror",
    [10326] = "Turn Evil",
    [6358] = "Seduction",
    [33786] = "Cyclone",
    -- Sleeps
    [2637] = "Hibernate",
    [20066] = "Repentance",
    [51514] = "Hex",
    -- Charms / Mind Control
    [605] = "Mind Control",
    [710] = "Banish",
    [2094] = "Blind",
    -- Silences
    [15487] = "Silence",
    [55021] = "Silence (PvP)",
    [47476] = "Strangulate",
    -- Misc / Special CCs
    [1776] = "Gouge",
    [31661] = "Dragon's Breath",
    [115750] = "Blinding Light",
    [88625] = "Holy Word: Chastise",
    [137460] = "Incapacitated",
}

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        print("|cff00ff00[DangerAlert]|r Loaded and ready!")
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
        if destGUID == UnitGUID("player") then
            -- Known CC
            if subevent == "SPELL_AURA_APPLIED" and CCSpells[spellID] then
                UIErrorsFrame:AddMessage("CC Incoming: "..CCSpells[spellID], 1, 0, 0, 53, 5)
                PlaySound(8959)
                FlashScreen(0.3)
            -- Unknown / new CC
            elseif subevent == "SPELL_AURA_APPLIED" and spellName then
                print("|cffff8000[DangerAlert]|r New CC detected: "..spellName.." (ID: "..spellID..")")
                UIErrorsFrame:AddMessage("CC Incoming: "..spellName, 1, 0.5, 0, 53, 5)
                PlaySound(8959)
                FlashScreen(0.3)
                -- Auto-add to CCSpells at runtime
                CCSpells[spellID] = spellName
            end

            -- AOE / periodic damage
            if subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "SPELL_DAMAGE" then
                UIErrorsFrame:AddMessage("AOE Damage Incoming: "..(spellName or ""), 1, 0.5, 0, 53, 5)
                PlaySound(5675)
                FlashScreen(0.2)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitCanAttack("target", "player") and UnitIsUnit("targettarget", "player") then
            UIErrorsFrame:AddMessage("You are targeted!", 1, 0, 0, 53, 5)
            PlaySound(8959)
            FlashScreen(0.4)
        end
    end
end)
