local _, ns = ...

-- Inspect window (Blizzard_InspectUI, Mainline/Blizzard_InspectUI.xml and InspectPaperDollFrame.xml).
-- The PvP and guild pages keep Blizzard's art for now.
local Skin = ns.Skin

local SLOTS = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
    "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand",
}
local MODEL_ART = {
    "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom", "Bottom2",
}
local MODEL_BACKGROUNDS = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft",
    "BackgroundBotRight", "BackgroundOverlay" }

ns.Skin:Register("InspectFrame", "Blizzard_InspectUI", function()
    Skin.Panel(InspectFrame)
    for i = 1, 3 do Skin.Tab(_G["InspectFrameTab" .. i]) end

    for _, slot in ipairs(SLOTS) do Skin.ItemSlot(_G["Inspect" .. slot .. "Slot"]) end

    for _, key in ipairs(MODEL_BACKGROUNDS) do Skin.Hide(InspectModelFrame[key]) end
    for _, part in ipairs(MODEL_ART) do Skin.Hide(_G["InspectModelFrameBorder" .. part]) end

    Skin.Button(InspectPaperDollFrame.ViewButton)
    Skin.Button(InspectPaperDollItemsFrame.InspectTalents)
end)
