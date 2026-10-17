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
function Skin.Panel(frame)
    if not frame or skinned[frame] then return end
    skinned[frame] = true
    for _, key in ipairs(PANEL_ART) do hide(frame[key]) end
    Skin.Backdrop(frame)
end

function Skin.CloseButton(button)
    if not button or skinned[button] then return end
    skinned[button] = true
    Skin.StripTextures(button)
    local holder = Skin.Backdrop(button)
    local label = Theme:Text(holder, Theme.fontSize.large, Theme.color.dim)
    label:SetPoint("CENTER")
    label:SetText("x")
    button:HookScript("OnEnter", function()
        local g = Theme.color.gold
        label:SetTextColor(g[1], g[2], g[3])
        holder:SetBackdropBorderColor(g[1], g[2], g[3], 1)
    end)
    button:HookScript("OnLeave", function()
        local d, r = Theme.color.dim, Theme.color.ridge
        label:SetTextColor(d[1], d[2], d[3])
        holder:SetBackdropBorderColor(r[1], r[2], r[3], 1)
    end)
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
