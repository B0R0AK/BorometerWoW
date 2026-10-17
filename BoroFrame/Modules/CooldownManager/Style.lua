local _, ns = ...

-- Optics for the items of Blizzard's Cooldown Viewer (Blizzard_CooldownViewer).
-- Taint rules, checked against Blizzard's CooldownViewer.lua (12.1.5):
--  * Only widget methods on Blizzard regions (SetFont, SetAlpha, SetTexCoord, ...).
--    Never a write into a Blizzard Lua table, never a nil-out of a parentKey.
--  * Elements Blizzard uses for information (DebuffBorder, OutOfRange, pandemic and
--    proc glows, cooldown flash) stay untouched. We hide decoration only, via alpha.
--  * Our own per-item state lives in a weak table keyed by the item frame.
--  * Swipe color is left to Blizzard: RefreshSpellCooldownInfo sets it on every refresh.
local Theme = ns.Theme
local IsSecret = ns.IsSecret

local Style = {}
ns.CDMStyle = Style

local OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local CROP = 0.08
local edgeBackdrop = { edgeFile = Theme.edge, edgeSize = 1 }

local state = setmetatable({}, { __mode = "k" })
Style._state = state  -- tests only

local floor, max = math.floor, math.max

local function fontSize(size, ratio, minimum)
    return max(minimum, floor(size * ratio + 0.5))
end

local function setFont(fs, size, color)
    if not fs then return end
    fs:SetFont(Theme.font, size, "OUTLINE")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

-- The frame overlay atlas is an unnamed region, so it is found by its atlas name.
-- GetAtlas is checked for secrecy first: a comparison on a secret would throw.
local function hideOverlayAtlas(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.GetAtlas and region:IsObjectType("Texture") then
            local atlas = region:GetAtlas()
            if not IsSecret(atlas) and atlas == OVERLAY_ATLAS then region:SetAlpha(0) end
        end
    end
end

-- Square icon: drop Blizzard's rounded mask, crop the baked-in edge.
local function squareIcon(texture)
    if not texture then return end
    if texture.GetNumMaskTextures then
        for i = texture:GetNumMaskTextures() or 0, 1, -1 do
            local mask = texture:GetMaskTexture(i)
            if mask then texture:RemoveMaskTexture(mask) end
        end
    end
    texture:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
end

-- 1px edge around `anchor`, on an addon-owned child frame (the backdrop mixin lands on our frame).
local function addBorder(parent, anchor)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
    border:SetBackdrop(edgeBackdrop)
    local c = Theme.color.pitch
    border:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    return border
end

local function countdownFontString(item)
    local cd = item.Cooldown
    return cd and cd.GetCountdownFontString and cd:GetCountdownFontString()
end

-- Essential, Utility and BuffIcon items. `size` is the item size in the item's own scale.
function Style.Icon(item, size)
    local s = state[item]
    if not s then
        s = {}
        state[item] = s
        squareIcon(item.Icon)
        hideOverlayAtlas(item:GetRegions())
        s.border = addBorder(item, item)
        if item.Cooldown then item.Cooldown:SetSwipeTexture(Theme.bar) end
    end
    item:SetSize(size, size)
    if s.size == size then return end
    s.size = size
    setFont(countdownFontString(item), fontSize(size, 0.38, 10), Theme.color.text)
    local charges = item.ChargeCount and item.ChargeCount.Current
    setFont(charges, fontSize(size, 0.3, 9), Theme.color.gold)
    local stacks = item.Applications and item.Applications.Applications
    setFont(stacks, fontSize(size, 0.3, 9), Theme.color.gold)
end

-- BuffBar items: icon left, StatusBar right. Values on the bar stay Blizzard's.
function Style.Bar(item, width, height)
    local s = state[item]
    local iconFrame, bar = item.Icon, item.Bar
    if not s then
        s = {}
        state[item] = s
        if iconFrame then
            squareIcon(iconFrame.Icon)
            hideOverlayAtlas(iconFrame:GetRegions())
            s.iconBorder = addBorder(iconFrame, iconFrame)
        end
        if bar then
            bar:SetStatusBarTexture(Theme.bar)
            local a = Theme.color.amber
            bar:SetStatusBarColor(a[1], a[2], a[3], 1)
            if bar.BarBG then
                local c = Theme.color.comb
                bar.BarBG:SetColorTexture(c[1], c[2], c[3], 0.92)
                bar.BarBG:ClearAllPoints()
                bar.BarBG:SetAllPoints(bar)
            end
            if bar.Pip then
                local l = Theme.color.lite
                bar.Pip:SetColorTexture(l[1], l[2], l[3], 1)
            end
            s.barBorder = addBorder(bar, bar)
        end
    end
    item:SetSize(width, height)
    if iconFrame then iconFrame:SetSize(height, height) end
    if bar then bar:SetHeight(height) end
    if s.height == height then return end
    s.height = height
    if bar and bar.Pip then bar.Pip:SetSize(1, height) end
    local size = fontSize(height, 0.55, 9)
    if bar then
        setFont(bar.Name, size, Theme.color.text)
        setFont(bar.Duration, size, Theme.color.lite)
    end
    setFont(iconFrame and iconFrame.Applications, fontSize(height, 0.45, 9), Theme.color.gold)
end

function Style.IsSkinned(item)
    return state[item] ~= nil
end
