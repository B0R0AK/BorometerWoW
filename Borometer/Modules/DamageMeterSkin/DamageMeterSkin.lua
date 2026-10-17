local _, ns = ...

-- Ember skin for Blizzard's damage meter. No parser of our own: Blizzard keeps the data and
-- builds the windows, we restyle them from post-hooks (hooksecurefunc) and from regions we add.
-- Blizzard's meter code handles secret values, so we never write keys into its frames or tables
-- (that would taint it) and never read anything from its bars or texts.
local M = ns:NewModule("DamageMeterSkin")
local DMS = ns.DamageMeterSkin
local Skin = ns.Skin
local Theme = ns.Theme
local C = Theme.color

local BLIZZARD_ADDON = "Blizzard_DamageMeter"
-- MAX_DAMAGE_METER_SESSION_WINDOWS is local in DamageMeter.lua; windows are named
-- "DamageMeterSessionWindow" .. index by DamageMeterMixin:SetupSessionWindow.
local MAX_WINDOWS = 3

local done = setmetatable({}, { __mode = "k" })

local function onInitEntry(_, frame)
    DMS.SkinEntry(frame)
end

local function skinEntries(window)
    for _, frame in window:EnumerateEntryFrames() do DMS.SkinEntry(frame) end
end

-- Spell breakdown that opens beside a session window.
local function skinSourceWindow(sw)
    if not sw or done[sw] then return end
    done[sw] = true
    Skin.StripTextures(sw)  -- the only region is the shadowed dropdown background
    -- The scroll box sits 20/15 px inside the old art (shadow margin); the panel hugs it.
    DMS.Box(sw, sw.Background, 12, -8, -12, 10, C.comb, 0.95)
    skinEntries(sw)
end

local function skinTitleBar(win)
    Skin.StripTextures(win)  -- the window itself only carries the header art
    local header = win.Header
    local r = C.raise
    local fill = win:CreateTexture(nil, "BACKGROUND", nil, 1)
    fill:SetColorTexture(r[1], r[2], r[3], 0.95)
    fill:SetAllPoints(header)
    local a = C.amber
    local line = win:CreateTexture(nil, "BORDER")
    line:SetColorTexture(a[1], a[2], a[3], 1)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

    local size = Theme.fontSize.normal
    local typeDropdown, sessionDropdown = win.DamageMeterTypeDropdown, win.SessionDropdown
    DMS.Font(win.SessionTimer, size, C.dim)
    DMS.Font(typeDropdown.TypeName, size, C.gold)
    DMS.Font(sessionDropdown.SessionName, size, C.lite)
    DMS.Tint(typeDropdown.Arrow, C.gold, true)

    -- WowStyle2 dropdown re-sets its background atlas on every button state; alpha survives that.
    sessionDropdown.Background:SetAlpha(0)
    DMS.Box(sessionDropdown, sessionDropdown, 0, 0, 0, 0, C.comb, 1)
    DMS.Tint(sessionDropdown.Arrow, C.gold)  -- Blizzard toggles its desaturation itself

    -- Settings dropdown and minimize button swap atlases on state changes; tint survives that.
    DMS.Tint(win.SettingsDropdown.Icon, C.gold, true)
    local minimize = win.MinimizeButton
    DMS.Tint(minimize:GetNormalTexture(), C.gold, true)
    DMS.Tint(minimize:GetPushedTexture(), C.amber, true)
end

local function skinSessionWindow(win)
    if not win or done[win] then return end
    done[win] = true
    skinTitleBar(win)

    local container = win.MinimizeContainer
    -- Blizzard drives this texture's alpha from the Edit Mode transparency; we only recolor it.
    local bg = C.comb
    container.Background:SetColorTexture(bg[1], bg[2], bg[3], 1)
    DMS.Font(container.NotActive, Theme.fontSize.normal, C.dim)

    -- Edge only, as an own frame under the container so it hides with the minimized window.
    local edge = CreateFrame("Frame", nil, container, "BackdropTemplate")
    edge:SetAllPoints(win)
    Theme:Backdrop(edge)
    edge:SetBackdropColor(bg[1], bg[2], bg[3], 0)

    -- InitEntry runs for every acquired, reused and local-player row, on every refresh.
    hooksecurefunc(win, "InitEntry", onInitEntry)
    DMS.SkinEntry(container.LocalPlayerEntry)
    skinEntries(win)
    skinSourceWindow(container.SourceWindow)
end

local function apply()
    -- Spell rows are created only once a breakdown opens, always after this hook is in place.
    -- Hooking the mixin reaches every future row through the template's mixin copy.
    if DamageMeterSpellEntryMixin then
        hooksecurefunc(DamageMeterSpellEntryMixin, "Init", DMS.SkinEntry)
    end
    for i = 1, MAX_WINDOWS do skinSessionWindow(_G["DamageMeterSessionWindow" .. i]) end
    if DamageMeter then
        -- Secondary windows are created later, from the settings menu.
        hooksecurefunc(DamageMeter, "SetupSessionWindow", function(_, _, windowData)
            skinSessionWindow(windowData and windowData.sessionWindow)
        end)
    end
end

local registered = false

function M:OnEnable()
    if registered then return end
    registered = true
    -- Runs once, in an error boundary, as soon as Blizzard_DamageMeter is loaded.
    Skin:Register("DamageMeter", BLIZZARD_ADDON, apply)
end

function M:OnDisable()
    ns.Debug.Print("DamageMeterSkin: Deaktivieren wirkt nach /reload.")
end
