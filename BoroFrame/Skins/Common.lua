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

function Skin.CloseButton(button)
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
function Skin.Panel(frame)
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
    Skin.CloseButton(frame.CloseButton)
end

local function refreshTab(tab)
    local holder = tabs[tab]
    if not holder then return end
    -- Blizzard disables the selected tab, so enabled state tells us which one is active.
    local c = tab:IsEnabled() and Theme.color.ridge or Theme.color.gold
    holder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

-- PanelTabButtonTemplate tabs (also FriendsFrameTabTemplate).
function Skin.Tab(tab)
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
