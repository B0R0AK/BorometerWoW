local _, ns = ...

-- Tooltips: frame, background and status bar only. Never read lines, sizes or text
-- (secret values, WoWUIBugs #811) and never hook tooltip data functions.
-- Frame names verified in Blizzard_GameTooltip/Mainline/GameTooltip.xml and
-- Blizzard_UIPanels_Game/Mainline/ItemRef.xml.
local Skin = ns.Skin
local Theme = ns.Theme

local NAMES = {
    "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip",
    "GameNoHeaderTooltip",
}

local function skinTooltip(tooltip)
    if not tooltip then return end
    Skin.NineSlice(tooltip)
    Skin.Fade(tooltip.TopOverlay)
    Skin.Fade(tooltip.BottomOverlay)

    -- Shopping tooltips carry a "currently equipped" label with its own art.
    local header = tooltip.CompareHeader
    if header then
        Skin.StripTextures(header)
        Skin.Panel(header)
    end

    local bar = tooltip.StatusBar
    if bar then
        bar:SetStatusBarTexture(Theme.bar)
        -- Plain texture, not a backdrop: the bar may hold secret values and a backdrop
        -- would read its size.
        local back = bar:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        local c = Theme.color.pitch
        back:SetColorTexture(c[1], c[2], c[3], 0.9)
    end
end

ns.Skin:Register("Tooltips", "Blizzard_GameTooltip", function()
    for _, name in ipairs(NAMES) do
        skinTooltip(_G[name])
    end
    -- Only ItemRefTooltip has a close button.
    if ItemRefTooltip then Skin.CloseButton(ItemRefTooltip.CloseButton) end
end)
