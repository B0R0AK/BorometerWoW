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

-- ---------------------------------------------------------------------------
-- Additions for window skins (tabs, panel art, close button, button art).
-- ---------------------------------------------------------------------------

local BUTTON_ART_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }

-- Textures set through SetNormalTexture and friends are not always plain regions.
function Skin.StripButtonArt(button)
    for _, getter in ipairs(BUTTON_ART_GETTERS) do
        local fn = button[getter]
        local tex = fn and fn(button)
        if tex then tex:SetAlpha(0) end
    end
end

-- Text button with Blizzard art: strip all art, then flat backdrop with gold hover edge.
function Skin.ActionButton(button)
    if not button or skinned[button] then return end
    Skin.StripButtonArt(button)
    Skin.Button(button)
end

-- Inset panels (InsetFrameTemplate): drop the nine-slice border and background.
function Skin.Inset(inset)
    if not inset or skinned[inset] then return end
    skinned[inset] = true
    if inset.NineSlice then inset.NineSlice:SetAlpha(0) end
    if inset.Bg then inset.Bg:SetAlpha(0) end
    Skin.StripTextures(inset)
end

function Skin.CloseButton(button)
    if not button or skinned[button] then return end
    Skin.StripButtonArt(button)
    Skin.Button(button)
    local label = Theme:Text(button, Theme.fontSize.normal, Theme.color.dim)
    label:SetPoint("CENTER", 0, 0)
    label:SetText("x")
end

-- Window based on PortraitFrame/ButtonFrameTemplate: hide nine-slice, portrait ring and
-- inset, then apply the flat panel. Does not touch the title text.
function Skin.Panel(frame)
    if not frame or skinned[frame] then return end
    if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
    if frame.PortraitContainer then frame.PortraitContainer:SetAlpha(0) end
    if frame.Bg then frame.Bg:SetAlpha(0) end
    Skin.Inset(frame.Inset)
    Skin.Frame(frame)
    Skin.CloseButton(frame.CloseButton)
end

-- Tab buttons (PanelTabButtonTemplate). Blizzard marks the selected tab by disabling it,
-- so the edge color follows IsEnabled(). Two global post-hooks cover all skinned tabs.
local tabs = setmetatable({}, { __mode = "k" })
local tabHooked = false

local function syncTab(tab)
    if not tabs[tab] then return end
    local c = tab:IsEnabled() and Theme.color.ridge or Theme.color.gold
    tab:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

function Skin.Tab(tab)
    if not tab or tabs[tab] then return end
    tabs[tab] = true
    skinned[tab] = true
    Skin.StripTextures(tab)
    Skin.StripButtonArt(tab)
    Skin.EnableBackdrop(tab)
    Theme:Backdrop(tab)
    syncTab(tab)
    if not tabHooked then
        tabHooked = true
        hooksecurefunc("PanelTemplates_SelectTab", syncTab)
        hooksecurefunc("PanelTemplates_DeselectTab", syncTab)
    end
end
