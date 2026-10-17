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
function Skin.StripButtonArt(button)
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
    Skin.StripButtonArt(button)
end

function Skin.CloseButton(button)
    if not button or skinned[button] then return end
    Skin.Button(button)
    Skin.StripButtonArt(button)
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
    Skin.CloseButton(frame.CloseButton)
end

-- InsetFrameTemplate and CollectionsBackgroundTemplate panels.
function Skin.Inset(frame)
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
function Skin.Tab(tab)
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
function Skin.Dropdown(dropdown)
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
