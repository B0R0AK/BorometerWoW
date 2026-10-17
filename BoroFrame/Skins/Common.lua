local _, ns = ...

-- Shared helpers for Blizzard window skins. Skins call these, they never style by hand.
local Skin = ns.Skin
local Theme = ns.Theme

local skinned = setmetatable({}, { __mode = "k" })

-- Hides the default art of a frame. Pass region names (children or regions) to keep.
function Skin.StripTextures(frame)
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
end

-- Blizzard frames without BackdropTemplate need the mixin plus its two hooks.
function Skin.EnableBackdrop(frame)
    if frame.SetBackdrop then return end
    Mixin(frame, BackdropTemplateMixin)
    frame:OnBackdropLoaded()
    frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
end

function Skin.Frame(frame)
    if not frame or skinned[frame] then return end
    skinned[frame] = true
    Skin.StripTextures(frame)
    Skin.EnableBackdrop(frame)
    Theme:Backdrop(frame)
end

function Skin.Button(button)
    if not button or skinned[button] then return end
    skinned[button] = true
    Skin.StripTextures(button)
    Skin.EnableBackdrop(button)
    Theme:Backdrop(button)
    button:HookScript("OnEnter", function(self)
        local g = Theme.color.gold
        self:SetBackdropBorderColor(g[1], g[2], g[3], 1)
    end)
    button:HookScript("OnLeave", function(self)
        local r = Theme.color.ridge
        self:SetBackdropBorderColor(r[1], r[2], r[3], 1)
    end)
end

-- V13f additions: appearance-only helpers that never write into Blizzard frame tables.
-- Instead of mixing BackdropTemplate into a Blizzard frame, they add a separate child frame.
-- The child is built from plain textures, not BackdropTemplate: the backdrop reads its own
-- size on every resize, which throws when the anchor chain carries secret values
-- (tooltips, bars). Textures anchored to a frame never need its size in Lua.

local panels = setmetatable({}, { __mode = "k" })

-- Fully transparent, so the art stays in place for layout but is invisible.
function Skin.Fade(object)
    if object and object.SetAlpha then object:SetAlpha(0) end
end

-- Adds a flat backdrop child behind the frame's own regions. Returns it (reused if present).
function Skin.Panel(frame, edge)
    if not frame then return end
    local panel = panels[frame]
    if panel then return panel end
    panel = CreateFrame("Frame", nil, frame)
    panels[frame] = panel
    panel:SetAllPoints(frame)
    panel:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    panel:EnableMouse(false)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local c = Theme.color.comb
    bg:SetColorTexture(c[1], c[2], c[3], 0.92)
    local top = panel:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    local bottom = panel:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    local left = panel:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)
    local right = panel:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
    panel.edges = { top, bottom, left, right }
    Skin.SetPanelEdge(panel, edge or Theme.color.ridge)
    return panel
end

function Skin.SetPanelEdge(panel, color)
    for i = 1, 4 do panel.edges[i]:SetColorTexture(color[1], color[2], color[3], 1) end
end

-- Frames that carry a NineSlice (tooltips, TooltipBackdropTemplate): hide it, show our panel.
function Skin.NineSlice(frame, edge)
    if not frame then return end
    Skin.Fade(frame.NineSlice)
    return Skin.Panel(frame, edge)
end

local function hoverEdge(button, panel)
    button:HookScript("OnEnter", function() Skin.SetPanelEdge(panel, Theme.color.gold) end)
    button:HookScript("OnLeave", function() Skin.SetPanelEdge(panel, Theme.color.ridge) end)
end

-- Close button: Blizzard art faded, flat square with an "x" in the theme font.
function Skin.CloseButton(button)
    if not button or panels[button] then return end
    Skin.StripTextures(button)
    local panel = Skin.Panel(button)
    local x = Theme:Text(button, Theme.fontSize.large, Theme.color.dim)
    x:SetPoint("CENTER", 0, 1)
    x:SetText("x")
    hoverEdge(button, panel)
end

-- WowStyle1 dropdown button (the closed widget, not the popup menu).
function Skin.Dropdown(dropdown)
    if not dropdown or panels[dropdown] then return end
    Skin.Fade(dropdown.Background)
    local panel = Skin.Panel(dropdown)
    hoverEdge(dropdown, panel)
end
