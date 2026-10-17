local _, ns = ...

-- The renderer is the sink of a timeline source. It owns the container, the row pools
-- and the layout. Layout runs at most once per frame and only on data changes; between
-- changes the engine animates bars, pips and countdowns on its own.
local TL = ns.Timeline
local Theme = ns.Theme
local Rows = TL.Rows

local R = { rows = {}, fading = {}, order = {} }
TL.Renderer = R

local GAP = 2
local LABEL_H = 12
local scratch = {}

local function poolFor(row)
    return row.kind == "pip" and R.pipPool or R.barPool
end

local function release(row)
    R.fading[row] = nil
    poolFor(row):Release(row)
end

-- Called by the fade animation. A row that already lost its event is freed now;
-- one whose event is still alive waits for OnRemove.
local function onFaded(row)
    if row.removed then release(row) end
end

local function layoutNow()
    R.pending = false
    local source, cfg = R.source, R.cfg
    if not source or not cfg then return end
    local order, rows = R.order, R.rows
    local n = source:GetOrder(cfg.maxBars, order)
    for _, row in pairs(rows) do row.slot = nil end
    local c, h = R.container, cfg.barHeight
    local track = cfg.view == "track"
    for i = 1, n do
        local row = rows[order[i]]
        if row then
            row.slot = i
            row:ClearAllPoints()
            if track then
                row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -((i - 1) % 2) * (h + GAP))
            elseif cfg.grow == "UP" then
                row:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", Rows.IND, (i - 1) * (h + GAP))
            else
                row:SetPoint("TOPLEFT", c, "TOPLEFT", Rows.IND, -(i - 1) * (h + GAP))
            end
            row:Show()
        end
    end
    for _, row in pairs(rows) do
        if not row.slot then row:Hide() end
    end
end
R.LayoutNow = layoutNow

local function buildTrackDecor(c)
    local bg = c:CreateTexture(nil, "BACKGROUND")
    local col = Theme.color.comb
    bg:SetColorTexture(col[1], col[2], col[3], 0.6)
    local labels = {}
    for i = 1, 3 do
        labels[i] = Theme:Text(c, Theme.fontSize.small, Theme.color.dim)
    end
    labels[1]:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    labels[2]:SetPoint("BOTTOM", c, "BOTTOM", 0, 0)
    labels[3]:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
    R.trackBg, R.trackLabels = bg, labels
end

function R:Build()
    if self.container then return self.container end
    local c = CreateFrame("Frame", nil, UIParent)
    c:SetFrameStrata("MEDIUM")
    c:SetClampedToScreen(true)
    c:EnableMouse(false)
    self.container = c
    buildTrackDecor(c)
    self.barPool = ns.Pool:New(function() return Rows.CreateBar(c) end, Rows.Reset)
    self.pipPool = ns.Pool:New(function() return Rows.CreatePip(c) end, Rows.Reset)
    return c
end

local function sizeRow(row, ev, cfg)
    if row.kind == "pip" then
        Rows.SizePip(row, cfg.width, cfg.trackSeconds, cfg.barHeight, ev.duration)
    else
        Rows.SizeBar(row, cfg.width, cfg.barHeight)
    end
end

-- Applies size, view and direction. Live events are re-created in the new style.
function R:Configure(cfg)
    self.cfg = cfg
    local c = self:Build()
    local track = cfg.view == "track"
    local h = cfg.barHeight

    wipe(scratch)
    for _, row in pairs(self.rows) do scratch[#scratch + 1] = row.ev end
    for _, row in pairs(self.rows) do release(row) end
    for row in pairs(self.fading) do release(row) end
    wipe(self.rows)

    self.pool = track and self.pipPool or self.barPool
    if track then
        c:SetSize(cfg.width, 2 * h + GAP + LABEL_H)
        self.trackBg:ClearAllPoints()
        self.trackBg:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
        self.trackBg:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, LABEL_H)
        local t = cfg.trackSeconds
        self.trackLabels[1]:SetText("0")
        self.trackLabels[2]:SetFormattedText("%d", math.floor(t / 2))
        self.trackLabels[3]:SetFormattedText("%d", t)
    else
        c:SetSize(cfg.width, cfg.maxBars * (h + GAP) - GAP)
    end
    self.trackBg:SetShown(track)
    for i = 1, 3 do self.trackLabels[i]:SetShown(track) end
    c:SetClipsChildren(track)

    for i = 1, #scratch do self:OnAdd(scratch[i]) end
    wipe(scratch)
    self:OnReorder()
end

function R:Attach(source)
    if self.source == source then return end
    if self.source then self:Detach() end
    self.source = source
    self.container:Show()
    source:Start(self)
end

function R:Detach()
    local source = self.source
    if not source then return end
    source:Stop()
    self.source = nil
    for _, row in pairs(self.rows) do release(row) end
    for row in pairs(self.fading) do release(row) end
    wipe(self.rows)
    self.container:Hide()
end

-- Sink ------------------------------------------------------------------------
function R:OnAdd(ev)
    if self.rows[ev.id] or not self.pool then return end
    local row = self.pool:Acquire()
    row.ev = ev
    row.onFaded = onFaded
    sizeRow(row, ev, self.cfg)
    Rows.Apply(row, ev, self.source)
    row:Hide()
    self.rows[ev.id] = row
    self:OnReorder()
end

function R:OnState(ev)
    local row = self.rows[ev.id]
    if not row then return end
    Rows.ApplyState(row, ev, self.source)
    self:OnReorder()
end

function R:OnRemove(ev)
    local row = self.rows[ev.id]
    if not row then return end
    self.rows[ev.id] = nil
    if row.fade:IsPlaying() and row:IsShown() then
        row.removed, row.ev = true, nil
        self.fading[row] = true
    else
        release(row)
    end
    self:OnReorder()
end

function R:OnReorder()
    if self.pending then return end
    self.pending = true
    C_Timer.After(0, layoutNow)
end

function R:ActiveCount()
    local n = 0
    for _ in pairs(self.rows) do n = n + 1 end
    return n
end
