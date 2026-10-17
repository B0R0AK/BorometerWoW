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

-- V13a helpers: panels, tabs, close buttons, scroll bars, lists, checkboxes, item slots.
-- Everything here only changes looks (alpha, colors, backdrops). No Blizzard function is
-- replaced and no Blizzard table gets values, except the backdrop mixin from EnableBackdrop.

local function hide(object)
    if object then object:SetAlpha(0) end
end
Skin.Hide = hide

local function setBorder(frame, color)
    frame:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

function Skin.CloseButton(button)
    if not button or skinned[button] then return end
    Skin.Button(button)
    local mark = Theme:Text(button, Theme.fontSize.normal, Theme.color.dim)
    mark:SetPoint("CENTER", 0, 0)
    mark:SetText("x")
end

-- Inset content area of a ButtonFrameTemplate window (frame.Inset, frame.InsetRight).
function Skin.Inset(inset)
    if not inset or skinned[inset] then return end
    Skin.Frame(inset)
    hide(inset.Bg)
    hide(inset.NineSlice)
end

-- Window built on PortraitFrameTemplate / ButtonFrameTemplate: NineSlice, Bg, portrait, title.
function Skin.Panel(frame)
    if not frame or skinned[frame] then return end
    Skin.Frame(frame)
    hide(frame.NineSlice)
    hide(frame.Bg)
    hide(frame.TopTileStreaks)
    hide(frame.PortraitContainer)
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        local g = Theme.color.gold
        title:SetTextColor(g[1], g[2], g[3])
    end
    Skin.CloseButton(frame.CloseButton)
    Skin.Inset(frame.Inset)
end

local tabs = setmetatable({}, { __mode = "k" })
local tabHooked

local function paintTab(tab, selected)
    setBorder(tab, selected and Theme.color.gold or Theme.color.ridge)
end

-- PanelTabButtonTemplate tabs. The owner's selectedTab names the active one, and Blizzard
-- calls PanelTemplates_SelectTab/DeselectTab whenever it changes.
function Skin.Tab(tab)
    if not tab or skinned[tab] then return end
    skinned[tab] = true
    if tab.TabTextures then
        for _, texture in ipairs(tab.TabTextures) do texture:SetAlpha(0) end
    end
    Skin.EnableBackdrop(tab)
    Theme:Backdrop(tab)
    tabs[tab] = true
    local owner = tab:GetParent()
    paintTab(tab, owner and owner.selectedTab == tab:GetID())
    if not tabHooked then
        tabHooked = true
        hooksecurefunc("PanelTemplates_SelectTab", function(t) if tabs[t] then paintTab(t, true) end end)
        hooksecurefunc("PanelTemplates_DeselectTab", function(t) if tabs[t] then paintTab(t, false) end end)
    end
end

-- MinimalScrollBar: keeps Blizzard's atlas swaps, only tints the textures.
function Skin.ScrollBar(bar)
    if not bar or skinned[bar] then return end
    skinned[bar] = true
    local track = bar.Track
    if not track then return end
    local r, a = Theme.color.ridge, Theme.color.amber
    for _, key in ipairs({ "Begin", "Middle", "End" }) do
        if track[key] then track[key]:SetVertexColor(r[1], r[2], r[3]) end
        local thumb = track.Thumb
        if thumb and thumb[key] then thumb[key]:SetVertexColor(a[1], a[2], a[3]) end
    end
end

-- Scroll list whose rows are recycled: styleRow(row) must be idempotent (guard with a weak table).
-- Styles the rows that exist now and every row Blizzard initializes later.
function Skin.ScrollList(scrollBox, scrollBar, styleRow)
    Skin.ScrollBar(scrollBar)
    if not scrollBox or skinned[scrollBox] then return end
    skinned[scrollBox] = true
    if scrollBox:GetView() then scrollBox:ForEachFrame(styleRow) end
    scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame,
        function(_, row) styleRow(row) end, {})
end

-- CheckButton: hides the stock box art, draws a small flat box. tint = color for the check mark.
function Skin.Checkbox(check, tint)
    if not check or skinned[check] then return end
    skinned[check] = true
    hide(check:GetNormalTexture())
    hide(check:GetPushedTexture())
    local box = CreateFrame("Frame", nil, check, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("CENTER", 0, 0)
    box:SetFrameLevel(math.max(check:GetFrameLevel() - 1, 0))
    Theme:Backdrop(box)
    local mark = check:GetCheckedTexture()
    if tint and mark then mark:SetVertexColor(tint[1], tint[2], tint[3]) end
end

-- ItemButton equipment slot (character and inspect). The slot art ("$parentFrame") and the
-- textures anchored to it are hidden; the quality border (IconBorder) stays.
function Skin.ItemSlot(slot)
    if not slot or skinned[slot] then return end
    skinned[slot] = true
    Skin.EnableBackdrop(slot)
    Theme:Backdrop(slot)
    hide(slot:GetNormalTexture())
    local name = slot:GetName()
    local art = name and _G[name .. "Frame"]
    if art then
        hide(art)
        for i = 1, slot:GetNumRegions() do
            local region = select(i, slot:GetRegions())
            if region ~= art and region:IsObjectType("Texture") then
                local _, relativeTo = region:GetPoint(1)
                if relativeTo == art then hide(region) end
            end
        end
    end
    if slot.icon then slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
end
