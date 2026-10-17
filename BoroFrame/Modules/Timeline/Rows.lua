local _, ns = ...

-- Widgets for one timeline event: a bar row (sorted list) and a pip (linear track).
-- Progress and countdown are driven by the engine from the event's duration object;
-- no Lua runs per render frame. Name and icon may be secret and only go to widgets.
local TL = ns.Timeline
local Theme = ns.Theme
local STATE = TL.STATE

local Rows = {}
TL.Rows = Rows

local INTERP = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
local REMAINING = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
local QUESTION_MARK = 134400  -- Interface\Icons\INV_Misc_QuestionMark

Rows.IND = 22   -- left gutter of a bar row for the 2x2 symbol grid
Rows.FADE = 0.35

-- One shared formatter: "12", "1m" etc. Text updates are pushed by the engine.
local secondsFormatter
local function formatter()
    if secondsFormatter == nil then
        secondsFormatter = false
        if C_StringUtil and C_StringUtil.CreateSecondsFormatter then
            local f = C_StringUtil.CreateSecondsFormatter()
            local abbr = Enum.SecondsFormatterAbbreviation
            local interval = Enum.SecondsFormatterInterval
            if abbr and f.SetDefaultAbbreviation then f:SetDefaultAbbreviation(abbr.OneLetter) end
            if interval and f.SetMinInterval then f:SetMinInterval(interval.Seconds) end
            if f.SetDesiredUnitCount then f:SetDesiredUnitCount(1) end
            secondsFormatter = f
        end
    end
    return secondsFormatter
end

local function bindCountdown(row, timer)
    local binding = row.binding
    if not binding then return end
    binding:SetToDefaults()
    local f = formatter()
    if not (timer and f) then
        row.time:SetText("")
        return
    end
    binding:SetFormatter(f)
    binding:SetFontString(row.time)
    binding:SetExpiredText("")
    binding:SetUpdateInterval(0.1)
    binding:SetDuration(timer)
    binding:SetEnabled(true)
end

local function onFadeFinished(anim)
    local row = anim:GetParent()
    if row.onFaded then row.onFaded(row) end
end

local function addFade(row)
    local group = row:CreateAnimationGroup()
    group:SetToFinalAlpha(true)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(Rows.FADE)
    group:SetScript("OnFinished", onFadeFinished)
    row.fade = group
end

local function newTimerBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(Theme.bar)
    local a = Theme.color.amber
    bar:SetStatusBarColor(a[1], a[2], a[3])
    return bar
end

-- Bar row ---------------------------------------------------------------------
function Rows.CreateBar(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:EnableMouse(false)
    Theme:Backdrop(row)
    row.kind = "bar"

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMLEFT", 1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local bar = newTimerBar(row)
    bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, 0)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    row.bar = bar

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local r = Theme.color.raise
    bg:SetColorTexture(r[1], r[2], r[3], 1)

    local time = Theme:Text(bar, Theme.fontSize.normal, Theme.color.lite)
    time:SetPoint("RIGHT", -4, 0)
    time:SetJustifyH("RIGHT")
    row.time = time

    local name = Theme:Text(bar, Theme.fontSize.small)
    name:SetPoint("LEFT", 4, 0)
    name:SetPoint("RIGHT", time, "LEFT", -4, 0)
    name:SetJustifyH("LEFT")
    row.name = name

    row.ind = {}
    for i = 1, 4 do row.ind[i] = row:CreateTexture(nil, "OVERLAY") end

    if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
        row.binding = C_DurationUtil.CreateDurationTextBinding()
    end
    addFade(row)
    return row
end

-- Fixed geometry per config. Never read back from the bar: once it holds secret
-- colors its aspects are secret, so layout only flows from config numbers.
function Rows.SizeBar(row, w, h)
    row:SetSize(w - Rows.IND, h)
    row.icon:SetWidth(h - 2)
    local s = math.floor((h - 2) / 2)
    for i = 1, 4 do
        local t = row.ind[i]
        t:SetSize(s, s)
        t:ClearAllPoints()
        local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
        t:SetPoint("TOPRIGHT", row, "TOPLEFT", -2 - col * (s + 1), -1 - line * (s + 1))
    end
end

-- Pip on the linear track ------------------------------------------------------
-- The pip is a transparent timer bar whose width maps its full duration onto the
-- track scale. The icon rides the right edge of the fill texture, so the engine
-- moves it: x = trackWidth * remaining / trackSeconds.
function Rows.CreatePip(parent)
    local row = newTimerBar(parent)
    row:EnableMouse(false)
    row.kind = "pip"
    row:SetStatusBarColor(1, 1, 1, 0)
    row.bar = row

    local holder = CreateFrame("Frame", nil, row)
    holder:SetPoint("CENTER", row:GetStatusBarTexture(), "RIGHT", 0, 0)
    row.holder = holder

    local edge = holder:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(1, 1, 1, 1)
    row.edge = edge

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    addFade(row)
    return row
end

function Rows.SizePip(row, trackWidth, trackSeconds, h, duration)
    local w = trackWidth * (duration or 0) / trackSeconds
    if w < 1 then w = 1 end
    row:SetSize(w, h)
    row.holder:SetSize(h, h)
end

-- Shared ---------------------------------------------------------------------
function Rows.SetColor(row, r, g, b)
    if row.kind == "pip" then
        row.edge:SetVertexColor(r, g, b)
    else
        row.bar:SetStatusBarColor(r, g, b)
    end
end

function Rows.Apply(row, ev, source)
    row.icon:SetTexture(ev.icon or QUESTION_MARK)
    if row.name then row.name:SetText(ev.name or "") end
    local bar = row.bar
    if ev.timer then
        bar:SetTimerDuration(ev.timer, INTERP, REMAINING)
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
    end
    if row.time then bindCountdown(row, ev.timer) end
    if row.ind and source.SetIndicators then source:SetIndicators(ev, row.ind) end
    Rows.ApplyState(row, ev, source)
end

function Rows.ApplyState(row, ev, source)
    local state = ev.state
    local r, g, b
    if source.GetColor then r, g, b = source:GetColor(ev) end
    if not r then
        local a = Theme.color.amber
        r, g, b = a[1], a[2], a[3]
    end
    local text = Theme.color.text
    if state == STATE.Finished then
        local c = Theme.color.gold
        r, g, b = c[1], c[2], c[3]
    elseif state == STATE.Canceled then
        local c = Theme.color.neg
        r, g, b = c[1], c[2], c[3]
    end
    Rows.SetColor(row, r, g, b)

    if state == STATE.Finished or state == STATE.Canceled then
        if not row.fade:IsPlaying() then row.fade:Play() end
        return
    end
    if state == STATE.Paused or ev.blocked then
        row:SetAlpha(0.55)
        text = Theme.color.dim
    else
        row:SetAlpha(1)
    end
    if row.name then row.name:SetTextColor(text[1], text[2], text[3]) end
end

-- Drops every reference to the event's duration object so the client can free it.
function Rows.Reset(row)
    row:Hide()
    row:ClearAllPoints()
    row.fade:Stop()
    row:SetAlpha(1)
    row.onFaded, row.ev, row.removed, row.slot = nil, nil, nil, nil
    row.bar:SetMinMaxValues(0, 0)
    if row.binding then
        row.binding:SetEnabled(false)
        row.binding:SetToDefaults()
    end
    if row.time then row.time:SetText("") end
end
