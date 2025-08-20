-- WowCode.lua
-- Custom tweaks to keep UI frames where I want them

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()

    -- ✅ Movable world map
    WorldMapFrame:SetMovable(true)
    WorldMapFrame:EnableMouse(true)
    WorldMapFrame:RegisterForDrag("LeftButton")
    WorldMapFrame:SetScript("OnDragStart", WorldMapFrame.StartMoving)
    WorldMapFrame:SetScript("OnDragStop", WorldMapFrame.StopMovingOrSizing)

    -- ✅ Recenter important frames
    for _, frame in pairs({
        QuestFrame, GossipFrame, MailFrame, MerchantFrame,
        TradeFrame, BankFrame
    }) do
        if frame then
            frame:HookScript("OnShow", function(self)
                self:ClearAllPoints()
                self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end)
        end
    end

    -- ✅ Bags reposition
    local bags = ContainerFrameCombinedBags
    if bags then
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            bags:ClearAllPoints()
            bags:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 200, -80)
        end)
    end

    -- ✅ Auction House reposition
    local function PositionAH()
        if AuctionHouseFrame then
            AuctionHouseFrame:ClearAllPoints()
            AuctionHouseFrame:SetPoint("CENTER", UIParent, "CENTER")
        end
    end

    -- Try to hook if it exists, otherwise wait for first open
    if AuctionHouseFrame then
        AuctionHouseFrame:HookScript("OnShow", PositionAH)
    else
        local ahEvent = CreateFrame("Frame")
        ahEvent:RegisterEvent("AUCTION_HOUSE_SHOW")
        ahEvent:SetScript("OnEvent", function()
            PositionAH()
        end)
    end

    -- ✅ Max camera zoom out
    SetCVar("cameraDistanceMaxZoomFactor", 2.6)

    -- ✅ Confirmation message
    print("|cff00ff00[WoWCode]|r Loaded and applied UI tweaks!")
end)
