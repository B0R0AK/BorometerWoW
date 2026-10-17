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

-- Window based on PortraitFrame/ButtonFrameTemplate: hide nine-slice, portrait ring and
-- inset, then apply the flat panel. Does not touch the title text.
function Skin.Window(frame)
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

function Skin.PanelTab(tab)
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

-- V13b additions: panels, close buttons, tabs, flat fills. ---------------------------------
-- These never write into Blizzard frame tables: the backdrop lives on our own child frame.
local holders = setmetatable({}, { __mode = "k" })

local function hide(region)
    if region then region:SetAlpha(0) end
end
Skin.Hide = hide

-- Backdrop on a child frame just below `frame`. Returns the child (created once per frame).
function Skin.Backdrop(frame, edge)
    local holder = holders[frame]
    if not holder then
        holder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        holder:SetAllPoints(frame)
        holder:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
        holders[frame] = holder
    end
    Theme:Backdrop(holder, edge)
    return holder
end

-- Paints a texture region with a flat Theme color (keeps size and anchors).
function Skin.Fill(texture, color, alpha)
    if not texture then return end
    texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
end

local PANEL_ART = { "NineSlice", "Bg", "TopTileStreaks", "TitleBg", "PortraitContainer" }

-- Portrait/Default panel frames: hides frame art by key, adds a flat backdrop.
function Skin.PortraitPanel(frame)
    if not frame or skinned[frame] then return end
    skinned[frame] = true
    for _, key in ipairs(PANEL_ART) do hide(frame[key]) end
    Skin.Backdrop(frame)
end

local TAB_ART = {
    "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
    "LeftHighlight", "MiddleHighlight", "RightHighlight",
}

-- TabSystemButtonTemplate tab: flat box, gold edge while selected.
function Skin.Tab(tab)
    if not tab or skinned[tab] then return end
    skinned[tab] = true
    for _, key in ipairs(TAB_ART) do hide(tab[key]) end
    local holder = Skin.Backdrop(tab)
    local function paint(self)
        local bg, edge = Theme.color.comb, Theme.color.ridge
        if self.isSelected then bg, edge = Theme.color.raise, Theme.color.gold end
        holder:SetBackdropColor(bg[1], bg[2], bg[3], 0.92)
        holder:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
    end
    paint(tab)
    if type(tab.SetTabSelected) == "function" then hooksecurefunc(tab, "SetTabSelected", paint) end
    tab:HookScript("OnEnter", function()
        local l = Theme.color.lite
        holder:SetBackdropBorderColor(l[1], l[2], l[3], 1)
    end)
    tab:HookScript("OnLeave", paint)
end

local function skinNewestTab(system)
    local tabs = system.tabs
    if tabs then Skin.Tab(tabs[#tabs]) end
end

-- TabSystemTemplate: skins the existing tabs and every tab added later.
function Skin.TabSystem(system)
    if not system or skinned[system] then return end
    skinned[system] = true
    if system.tabs then
        for _, tab in ipairs(system.tabs) do Skin.Tab(tab) end
    end
    if type(system.AddTab) == "function" then hooksecurefunc(system, "AddTab", skinNewestTab) end
end
