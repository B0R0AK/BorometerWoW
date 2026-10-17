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


-- Panel helpers (V13c). Appended as separate functions so merges stay trivial.
-- They never write into Blizzard tables: backdrops live on our own child frames,
-- and art is hidden with SetAlpha(0), which survives Show/Hide calls from Blizzard code.
local panels = setmetatable({}, { __mode = "k" })
local tabs = setmetatable({}, { __mode = "k" })
local hooked = false

function Skin.Hide(object)
    if object and object.SetAlpha then object:SetAlpha(0) end
end

-- Child frame carrying a Theme backdrop. It sits one level below its parent, so the
-- parent's own text stays on top. opts: edgeOnly, height (top bar), inset (px).
function Skin.NewBackdrop(parent, opts)
    opts = opts or {}
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    holder:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1))
    local inset = opts.inset or 0
    holder:SetPoint("TOPLEFT", inset, -inset)
    if opts.height then
        holder:SetPoint("TOPRIGHT", -inset, -inset)
        holder:SetHeight(opts.height)
    else
        holder:SetPoint("BOTTOMRIGHT", -inset, inset)
    end
    if opts.edgeOnly then
        holder:SetBackdrop({ edgeFile = Theme.edge, edgeSize = 1 })
        local r = Theme.color.ridge
        holder:SetBackdropBorderColor(r[1], r[2], r[3], 1)
    else
        Theme:Backdrop(holder)
    end
    return holder
end

function Skin.CloseButton_c(button)
    if not button or skinned[button] then return end
    skinned[button] = true
    Skin.StripTextures(button)
    local mark = Theme:Text(button, Theme.fontSize.large, Theme.color.dim)
    mark:SetPoint("CENTER", 0, 1)
    mark:SetText("x")
    button:HookScript("OnEnter", function() local c = Theme.color.gold; mark:SetTextColor(c[1], c[2], c[3]) end)
    button:HookScript("OnLeave", function() local c = Theme.color.dim; mark:SetTextColor(c[1], c[2], c[3]) end)
end

function Skin.TitleText(fontString)
    if not fontString then return end
    local c = Theme.color.gold
    fontString:SetFont(Theme.font, Theme.fontSize.large, "OUTLINE")
    fontString:SetTextColor(c[1], c[2], c[3])
end

-- ButtonFrameTemplate / PortraitFrameTemplate windows: hides the default art and puts a
-- flat panel behind. Content art (parchment, item slots) is left alone on purpose.
function Skin.Panel_c(frame)
    if not frame or panels[frame] then return end
    panels[frame] = true
    Skin.Hide(frame.NineSlice)
    Skin.Hide(frame.Bg)
    Skin.Hide(frame.TopTileStreaks)
    Skin.Hide(frame.PortraitContainer)
    if frame.Inset then
        Skin.Hide(frame.Inset.NineSlice)
        Skin.Hide(frame.Inset.Bg)
    end
    Skin.NewBackdrop(frame)
    Skin.TitleText(frame.TitleContainer and frame.TitleContainer.TitleText)
    Skin.CloseButton_c(frame.CloseButton)
end

local function refreshTab(tab)
    local holder = tabs[tab]
    if not holder then return end
    -- Blizzard disables the selected tab, so enabled state tells us which one is active.
    local c = tab:IsEnabled() and Theme.color.ridge or Theme.color.gold
    holder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

-- PanelTabButtonTemplate tabs (also FriendsFrameTabTemplate).
function Skin.Tab_c(tab)
    if not tab or tabs[tab] then return end
    if tab.TabTextures then
        for _, texture in ipairs(tab.TabTextures) do Skin.Hide(texture) end
    else
        Skin.StripTextures(tab)
    end
    tabs[tab] = Skin.NewBackdrop(tab, { inset = 3 })
    refreshTab(tab)
    if not hooked and hooksecurefunc then
        hooked = true
        hooksecurefunc("PanelTemplates_SelectTab", refreshTab)
        hooksecurefunc("PanelTemplates_DeselectTab", refreshTab)
    end
end


-- ---------------------------------------------------------------------------
-- Helpers added for the Collections / Adventure Guide skins (V13e).
-- All of them tolerate nil, so a skin can list frames without guarding each one.
-- ---------------------------------------------------------------------------

local BUTTON_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

-- Resolves "FrameName.parentKey.child" from _G. Returns nil if any step is missing.
function Skin.Find(path)
    local obj = _G
    for key in path:gmatch("[^.]+") do
        if type(obj) ~= "table" then return nil end
        obj = obj[key]
    end
    return obj
end

-- Runs a skin helper over a list of paths (see Skin.Find).
function Skin.Apply(helper, paths)
    for _, path in ipairs(paths) do helper(Skin.Find(path)) end
end

-- Hides named children or regions by alpha. Blizzard code shows/hides them, never changes alpha.
function Skin.HideArt(frame, ...)
    if not frame then return end
    for i = 1, select("#", ...) do
        local obj = frame[select(i, ...)]
        if type(obj) == "table" and obj.SetAlpha then obj:SetAlpha(0) end
    end
end

-- Hides the four state textures of a button (Normal, Pushed, Disabled, Highlight).
function Skin.StripButtonArt_e(button)
    for _, getter in ipairs(BUTTON_ART) do
        local tex = button[getter] and button[getter](button)
        if tex then tex:SetAlpha(0) end
    end
end

-- Flat backdrop child that sits below its parent, so the parent's own text stays on top.
function Skin.Plate(frame, left, top, right, bottom)
    local plate = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    plate:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    plate:SetPoint("TOPLEFT", left or 0, top or 0)
    plate:SetPoint("BOTTOMRIGHT", right or 0, bottom or 0)
    Theme:Backdrop(plate)
    return plate
end

-- Button with its default art removed (UIPanelButton and MagicButton templates).
function Skin.PanelButton(button)
    if not button or skinned[button] then return end
    Skin.Button(button)
    Skin.StripButtonArt_e(button)
end

function Skin.CloseButton_e(button)
    if not button or skinned[button] then return end
    Skin.Button(button)
    Skin.StripButtonArt_e(button)
    local mark = Theme:Text(button, Theme.fontSize.large, Theme.color.dim)
    mark:SetPoint("CENTER", 0, 0)
    mark:SetText("x")
    button:HookScript("OnEnter", function() local g = Theme.color.gold; mark:SetTextColor(g[1], g[2], g[3]) end)
    button:HookScript("OnLeave", function() local d = Theme.color.dim; mark:SetTextColor(d[1], d[2], d[3]) end)
end

-- Window with NineSlice border, portrait and rock background (PortraitFrameTemplate family).
function Skin.PortraitFrame(frame)
    if not frame or skinned[frame] then return end
    Skin.Frame(frame)
    Skin.HideArt(frame, "NineSlice", "PortraitContainer", "Bg", "TopTileStreaks")
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        local g = Theme.color.gold
        title:SetTextColor(g[1], g[2], g[3])
    end
    Skin.CloseButton_e(frame.CloseButton)
end

-- InsetFrameTemplate and CollectionsBackgroundTemplate panels.
function Skin.Inset_e(frame)
    if not frame or skinned[frame] then return end
    skinned[frame] = true
    Skin.StripTextures(frame)
    Skin.HideArt(frame, "NineSlice", "Bg")
    Skin.EnableBackdrop(frame)
    Theme:Backdrop(frame)
end

-- PanelTabButtonTemplate tabs (bottom and top). The selected tab is the disabled one.
local tabs = setmetatable({}, { __mode = "k" })
local tabPlates = setmetatable({}, { __mode = "k" })

local function styleTab(tab, selected)
    local edge = selected and Theme.color.gold or Theme.color.ridge
    local bg = selected and Theme.color.raise or Theme.color.comb
    local plate = tabPlates[tab]
    plate:SetBackdropColor(bg[1], bg[2], bg[3], 0.92)
    plate:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

local tabHooked
function Skin.Tab_e(tab)
    if not tab or skinned[tab] then return end
    skinned[tab] = true
    if tab.TabTextures then
        for _, tex in ipairs(tab.TabTextures) do tex:SetAlpha(0) end
    end
    tabPlates[tab] = Skin.Plate(tab, 8, -4, -8, 2)
    tabs[tab] = true
    styleTab(tab, not tab:IsEnabled())
    if not tabHooked then
        tabHooked = true
        hooksecurefunc("PanelTemplates_SelectTab", function(t) if tabs[t] then styleTab(t, true) end end)
        hooksecurefunc("PanelTemplates_DeselectTab", function(t) if tabs[t] then styleTab(t, false) end end)
    end
end

-- SearchBoxTemplate and InputBoxTemplate edit boxes.
function Skin.EditBox(box)
    if not box or skinned[box] then return end
    skinned[box] = true
    Skin.HideArt(box, "Left", "Middle", "Right")
    Skin.EnableBackdrop(box)
    Theme:Backdrop(box)
end

-- WowStyle1DropdownTemplate and WowStyle1FilterDropdownTemplate.
function Skin.Dropdown_e(dropdown)
    if not dropdown or skinned[dropdown] then return end
    skinned[dropdown] = true
    Skin.HideArt(dropdown, "Background")
    Skin.EnableBackdrop(dropdown)
    Theme:Backdrop(dropdown)
end

-- StatusBar with its own border art (CollectionsProgressBarTemplate). The bar texture is kept.
function Skin.StatusBar(bar)
    if not bar or skinned[bar] then return end
    skinned[bar] = true
    Skin.HideArt(bar, "border")
    bar:SetStatusBarTexture(Theme.bar)
    local c = Theme.color.amber
    bar:SetStatusBarColor(c[1], c[2], c[3])
    Skin.EnableBackdrop(bar)
    Theme:Backdrop(bar)
end

-- MinimalScrollBar: flat rail, gold thumb. Thumb atlases change on hover, vertex color stays.
local THUMB_PARTS = { "Begin", "Middle", "End" }

function Skin.ScrollBar(bar)
    if not bar or skinned[bar] then return end
    skinned[bar] = true
    local track = bar.Track
    if not track then return end
    Skin.HideArt(track, unpack(THUMB_PARTS))
    Skin.Plate(track)
    local thumb = track.Thumb
    if thumb then
        local g = Theme.color.gold
        for _, key in ipairs(THUMB_PARTS) do
            if thumb[key] then thumb[key]:SetVertexColor(g[1], g[2], g[3]) end
        end
    end
end
