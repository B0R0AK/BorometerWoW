local _, ns = ...

-- Merchant window. Item slots, name plates and money frames keep their art: Blizzard tints
-- the name plate red/grey for unaffordable or unusable items. Names verified in
-- Gethe/wow-ui-source 12.1.5 (Mainline/MerchantFrame.xml).
local Skin = ns.Skin

local HIDE = { "MerchantFrameBottomLeftBorder", "MerchantFramePortrait" }
local INSETS = { "MerchantExtraCurrencyInset", "MerchantMoneyInset" }
local EDGES = { "MerchantExtraCurrencyBg", "MerchantMoneyBg" }
local TABS = { "MerchantFrameTab1", "MerchantFrameTab2" }

ns.Skin:Register("Merchant", nil, function()
    if not MerchantFrame then return end
    Skin.Panel_c(MerchantFrame)
    for _, name in ipairs(HIDE) do Skin.Hide(_G[name]) end
    for _, name in ipairs(INSETS) do
        local inset = _G[name]
        if inset then Skin.Hide(inset.NineSlice); Skin.Hide(inset.Bg) end
    end
    for _, name in ipairs(EDGES) do Skin.Hide(_G[name]) end
    for _, name in ipairs(TABS) do Skin.Tab_c(_G[name]) end
    -- Repair and junk buttons are icon buttons and stay as they are.
end)
