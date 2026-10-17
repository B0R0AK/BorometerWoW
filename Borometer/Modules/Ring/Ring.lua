local _, ns = ...

-- Post-fight view: a glowing ember ring split by share, a source list underneath.
-- Works on plain snapshots from ns.Data only, so it never sees a secret value.
-- Arcs are Cooldown swipes frozen at a fraction (the client draws the wedge, no per-frame Lua),
-- the glow is a looping alpha animation.
local M = ns:NewModule("Ring")
ns.Ring = M
local Theme = ns.Theme
local C = Theme.color

ns.Config:Register("ring", { autoShow = true, type = "damage" })

local MAX_SOURCES = 6
local SEGMENTS = MAX_SOURCES + 1  -- sources plus "rest"
local RING = 184
local ROW_H = 18
local WIDTH = 300
local SPAN = 100000  -- frozen cooldowns run this long, the drift is invisible

local LABEL = { damage = { "Schaden", "DPS" }, healing = { "Heilung", "HPS" } }

local frame, segs, rows, tabs, center, centerSub, title, halo, pulse

local function className(class)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class or "?"
end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return { c.r, c.g, c.b } end
    return C.gold
end

local function same(a, b)
    return a and b and math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3]) < 0.02
end

-- Draws the wedge from 12 o'clock to `fraction` of the circle and keeps it there.
local function setArc(cd, fraction)
    fraction = math.min(math.max(fraction, 0.001), 0.9995)
    cd:SetCooldown(GetTime() - fraction * SPAN, SPAN)
    cd:Pause()
    cd:Show()
end

local function createRing(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(RING, RING)

    halo = holder:CreateTexture(nil, "BACKGROUND")
    halo:SetTexture(Theme.glow)
    halo:SetBlendMode("ADD")
    halo:SetPoint("CENTER")
    halo:SetSize(RING, RING)  -- same geometry as the ring texture, so the halo sits on it
    pulse = halo:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local a = pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.45)
    a:SetDuration(2.4)
    a:SetSmoothing("IN_OUT")

    local track = holder:CreateTexture(nil, "BORDER")
    track:SetTexture(Theme.ring)
    track:SetAllPoints()
    track:SetVertexColor(C.ridge[1], C.ridge[2], C.ridge[3], 0.9)

    segs = {}
    for i = 1, SEGMENTS do
        local cd = CreateFrame("Cooldown", nil, holder)
        cd:SetAllPoints()
        cd:SetFrameLevel(holder:GetFrameLevel() + 1 + (SEGMENTS - i))  -- shorter arcs sit on top
        cd:SetSwipeTexture(Theme.ring)
        cd:SetDrawEdge(false)
        cd:SetDrawBling(false)
        cd:SetReverse(true)
        cd:SetHideCountdownNumbers(true)
        cd:EnableMouse(false)
        segs[i] = cd
    end

    local textLayer = CreateFrame("Frame", nil, holder)
    textLayer:SetAllPoints()
    textLayer:SetFrameLevel(holder:GetFrameLevel() + SEGMENTS + 2)
    center = Theme:Text(textLayer, 24, C.lite)
    center:SetPoint("CENTER", 0, 8)
    centerSub = Theme:Text(textLayer, Theme.fontSize.normal, C.dim)
    centerSub:SetPoint("CENTER", 0, -14)
    return holder
end

local function createRow(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(WIDTH - 24, ROW_H)
    row:SetPoint("TOPLEFT", 12, -(i - 1) * ROW_H)
    row.swatch = row:CreateTexture(nil, "ARTWORK")
    row.swatch:SetSize(8, 8)
    row.swatch:SetPoint("LEFT", 0, 0)
    row.swatch:SetTexture(Theme.bar)
    row.name = Theme:Text(row, Theme.fontSize.normal)
    row.name:SetPoint("LEFT", 14, 0)
    row.name:SetWidth(120)
    row.name:SetJustifyH("LEFT")
    row.pct = Theme:Text(row, Theme.fontSize.small, C.dim)
    row.pct:SetPoint("RIGHT", 0, 0)
    row.value = Theme:Text(row, Theme.fontSize.normal, C.gold)
    row.value:SetPoint("RIGHT", row.pct, "LEFT", -8, 0)
    return row
end

local function setTab(key)
    ns.Config:Get("ring").type = key
    M:Refresh()
end

local function createTab(parent, key, x)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(80, 20)
    b:SetPoint("TOPLEFT", x, -30)
    Theme:Backdrop(b)
    b.label = Theme:Text(b, Theme.fontSize.normal)
    b.label:SetPoint("CENTER")
    b.label:SetText(LABEL[key][1])
    b:SetScript("OnClick", function() setTab(key) end)
    b.key = key
    return b
end

local function build()
    frame = CreateFrame("Frame", "BorometerRingFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 78 + RING + 12 + MAX_SOURCES * ROW_H + 10)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    Theme:Backdrop(frame, C.amber, 0.6)
    ns.Mover:Register(frame, "Ring", { "RIGHT", "RIGHT", -60, 0 })

    title = Theme:Text(frame, Theme.fontSize.large, C.gold)
    title:SetPoint("TOPLEFT", 12, -9)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -6)
    local x = Theme:Text(close, Theme.fontSize.large, C.dim)
    x:SetPoint("CENTER")
    x:SetText("x")
    close:SetScript("OnClick", function() frame:Hide() end)
    close:SetScript("OnEnter", function() x:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end)

    tabs = { createTab(frame, "damage", 12), createTab(frame, "healing", 98) }

    local ring = createRing(frame)
    ring:SetPoint("TOP", 0, -58)

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", 0, -(58 + RING + 12))
    list:SetSize(WIDTH, MAX_SOURCES * ROW_H)
    rows = {}
    for i = 1, MAX_SOURCES do rows[i] = createRow(list, i) end
end

local function fill(data)
    local total = data.total
    local sources = data.sources
    local n = math.min(#sources, MAX_SOURCES)
    local cum, prev = 0, nil
    for i = 1, SEGMENTS do segs[i]:Hide() end

    for i = 1, MAX_SOURCES do
        local row, s = rows[i], sources[i]
        if s then
            local col = classColor(s.class)
            if same(col, prev) then col = { col[1] * 0.7, col[2] * 0.7, col[3] * 0.7 } end
            prev = col
            cum = cum + s.amount / total
            segs[i]:SetSwipeColor(col[1], col[2], col[3], 1)
            setArc(segs[i], cum)

            row.swatch:SetVertexColor(col[1], col[2], col[3])
            row.name:SetText(s.name or className(s.class))
            local nc = s.isPlayer and C.lite or C.text
            row.name:SetTextColor(nc[1], nc[2], nc[3])
            row.value:SetText(AbbreviateNumbers(s.amount))
            row.pct:SetFormattedText("%.1f%%", s.amount / total * 100)
            row:Show()
        else
            row:Hide()
        end
    end

    if #sources > n and cum < 0.995 then  -- everyone below the list, as one dim wedge
        segs[SEGMENTS]:SetSwipeColor(C.deep[1], C.deep[2], C.deep[3], 1)
        setArc(segs[SEGMENTS], 1)
    end

    local color = classColor(sources[1].class)
    halo:SetVertexColor(color[1] * 0.5 + C.amber[1] * 0.5, color[2] * 0.5 + C.amber[2] * 0.5, color[3] * 0.5 + C.amber[3] * 0.5)
end

function M:Refresh()
    if not frame then return end
    local key = ns.Config:Get("ring").type
    local snap = ns.Data:Latest()
    local data = snap and snap.types[key]
    for _, b in ipairs(tabs) do
        local on = b.key == key
        local edge = on and C.gold or C.ridge
        b:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
        local tc = on and C.lite or C.dim
        b.label:SetTextColor(tc[1], tc[2], tc[3])
    end
    title:SetText(snap and (snap.name or "Borometer") or "Borometer")
    if not data then
        for i = 1, SEGMENTS do segs[i]:Hide() end
        for i = 1, MAX_SOURCES do rows[i]:Hide() end
        center:SetText("-")
        centerSub:SetText("noch kein Kampf")
        pulse:Stop()
        halo:SetAlpha(0.15)
        return
    end
    center:SetText(AbbreviateNumbers(data.total))
    local perSecond = data.duration > 0 and data.total / data.duration or 0
    centerSub:SetText(("%s %s"):format(LABEL[key][2], AbbreviateNumbers(perSecond)))
    fill(data)
    if not pulse:IsPlaying() then pulse:Play() end
end

function M:Show()
    if not frame then build() end
    frame:Show()
    self:Refresh()
end

function M:Toggle(demo)
    if demo then ns.Data:Demo() end
    if frame and frame:IsShown() and not demo then frame:Hide() else self:Show() end
end

local subscribed = false

function M:OnEnable()
    if subscribed then return end
    subscribed = true
    ns.Data:OnCapture(function()
        if not M:IsEnabled() then return end
        if ns.Config:Get("ring").autoShow then M:Show() elseif frame and frame:IsShown() then M:Refresh() end
    end)
end
