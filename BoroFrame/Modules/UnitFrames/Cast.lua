local _, ns = ...

-- Cast bar element: casts, channels and empowered casts, spell name, icon, not-interruptible marker.
-- The bar is driven by duration objects through StatusBar:SetTimerDuration, so the engine animates it
-- and no Lua runs per frame. Other units' cast data is secret: name, icon and notInterruptible go
-- straight to widgets and are never compared. Only fields documented as NeverSecret (isEmpowered,
-- castBarID) drive Lua branches.
local UF = ns.UF
local Theme = ns.Theme

local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local UnitCastingDuration, UnitChannelDuration = UnitCastingDuration, UnitChannelDuration
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local C_Timer = C_Timer
local type = type

local HOLD = 0.6  -- seconds the interrupted/failed state stays visible
local GAP = 3     -- distance to the unit frame

local Direction = Enum.StatusBarTimerDirection or { ElapsedTime = 0, RemainingTime = 1 }
local Immediate = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0

local function color(c, a) return CreateColor(c[1], c[2], c[3], a or 1) end
local NORMAL = color(Theme.color.amber)
local LOCKED = color(Theme.color.dim)

-- notInterruptible is nilable and may be secret. type() reports the real type of a secret,
-- so this keeps secret booleans intact and only replaces a plain nil.
local function asBool(v)
    if type(v) == "boolean" then return v end
    return false
end

local function setLocked(frame, locked)
    frame.castFill:SetVertexColorFromBoolean(locked, LOCKED, NORMAL)
    frame.castShield:SetAlphaFromBoolean(locked, 1, 0)
end

-- Reads the unit's current cast and puts it on the widgets. Returns false if the unit is not casting.
local function apply(frame, interpolation)
    local unit = frame.unit
    local name, _, texture, _, _, _, _, notInterruptible, _, castBarID = UnitCastingInfo(unit)
    local duration, direction
    if name then
        duration, direction = UnitCastingDuration(unit), Direction.ElapsedTime
    else
        local isEmpowered
        name, _, texture, _, _, _, notInterruptible, _, isEmpowered, _, castBarID = UnitChannelInfo(unit)
        if not name then return false end
        if isEmpowered and UnitEmpoweredChannelDuration then
            -- includes the hold-at-max time, like Blizzard's bar
            duration, direction = UnitEmpoweredChannelDuration(unit, true), Direction.ElapsedTime
        else
            -- WoWUIBugs #834: the channel duration is wrong for Ray of Frost. CHANNEL_UPDATE re-reads it
            -- and CHANNEL_STOP hides the bar, so the bar never outlives the channel.
            duration, direction = UnitChannelDuration(unit), Direction.RemainingTime
        end
    end
    if not duration then return false end

    frame.castBarID = castBarID
    frame.castBar:SetTimerDuration(duration, interpolation or Immediate, direction)
    frame.castText:SetText(name)
    frame.castIcon:SetTexture(texture)
    setLocked(frame, asBool(notInterruptible))
    frame.castFail:Hide()
    frame.castHolder:Show()
    return true
end

local function update(frame, interpolation)
    if frame.castHold then return end
    if not apply(frame, interpolation) then frame.castHolder:Hide() end
end

-- Full redraw (new cast, unit changed, frame shown): drop any pending failed state.
local function refresh(frame)
    frame.castHold = false
    update(frame)
end

local function delayed(frame) update(frame, UF.interp) end

local function stop(frame) update(frame) end

-- Shows the failed/interrupted state for HOLD seconds. castBarID is NeverSecret: a FAILED event
-- for another cast attempt (key pressed while casting) must not end the running bar.
local function fail(frame, text, castBarID)
    if not frame.castHolder:IsShown() then return end
    if castBarID and frame.castBarID and castBarID ~= frame.castBarID then return end
    frame.castHold = true
    frame.castFail:Show()
    frame.castText:SetText(text)
    frame.castHoldCount = frame.castHoldCount + 1
    C_Timer.After(HOLD, frame.castRelease)
end

-- FAILED payload: unit, castGUID, spellID, castBarID
local function failed(frame, _, _, _, castBarID) fail(frame, FAILED, castBarID) end
-- INTERRUPTED payload: unit, castGUID, spellID, interruptedBy, castBarID
local function interrupted(frame, _, _, _, _, castBarID) fail(frame, INTERRUPTED, castBarID) end

-- interruptedBy may be secret. A truth test on a non-boolean secret is allowed, and Blizzard's
-- bar treats nil as "completed" the same way.
local function stopOrInterrupt(frame, interruptedBy, castBarID)
    if interruptedBy then
        fail(frame, INTERRUPTED, castBarID)
    else
        update(frame)
    end
end

-- CHANNEL_STOP payload: unit, castGUID, spellID, interruptedBy, castBarID
local function channelStop(frame, _, _, _, interruptedBy, castBarID)
    stopOrInterrupt(frame, interruptedBy, castBarID)
end

-- EMPOWER_STOP payload: unit, castGUID, spellID, complete, interruptedBy, castBarID.
-- complete may be secret, so only interruptedBy is tested.
local function empowerStop(frame, _, _, _, _, interruptedBy, castBarID)
    stopOrInterrupt(frame, interruptedBy, castBarID)
end

-- Blizzard's player bar would duplicate ours. SetUnit(nil) unregisters its events and hides it,
-- the same call Blizzard uses to detach a casting bar.
local function hidePlayerCastBar()
    if PlayerCastingBarFrame and PlayerCastingBarFrame.SetUnit then
        PlayerCastingBarFrame:SetUnit(nil)
    end
end

local function create(frame, spec)
    local h = spec.castHeight or 16
    local holder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    holder:SetSize(spec.castWidth or spec.w, h)
    if spec.castAnchor == "LEFT" then
        holder:SetPoint("RIGHT", frame, "LEFT", -GAP, 0)
    else
        holder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -GAP)
    end
    Theme:Backdrop(holder)
    holder:Hide()

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetSize(h - 2, h - 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Ring around the icon, visible only for casts that cannot be interrupted.
    local shield = holder:CreateTexture(nil, "BORDER")
    shield:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    shield:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    shield:SetColorTexture(1, 1, 1)
    local lc = Theme.color.lite
    shield:SetVertexColor(lc[1], lc[2], lc[3])
    shield:SetAlpha(0)

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, 0)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(Theme.bar)
    local fill = bar:GetStatusBarTexture()

    -- Covers the bar while the failed/interrupted state is held. The timer bar below keeps running.
    local failTex = bar:CreateTexture(nil, "OVERLAY")
    failTex:SetAllPoints(bar)
    failTex:SetColorTexture(1, 1, 1)
    local nc = Theme.color.neg
    failTex:SetVertexColor(nc[1], nc[2], nc[3], 0.85)
    failTex:Hide()

    local text = Theme:Text(bar, Theme.fontSize.small)
    text:SetDrawLayer("OVERLAY", 7)
    text:SetPoint("LEFT", 3, 0)
    text:SetPoint("RIGHT", -3, 0)
    text:SetJustifyH("LEFT")

    frame.castHolder, frame.castBar, frame.castFill = holder, bar, fill
    frame.castIcon, frame.castShield, frame.castFail, frame.castText = icon, shield, failTex, text
    frame.castHold, frame.castHoldCount = false, 0
    -- Built once per frame, so the timer callback is not a closure created per event.
    frame.castRelease = function()
        frame.castHoldCount = frame.castHoldCount - 1
        if frame.castHoldCount == 0 then refresh(frame) end
    end
    setLocked(frame, false)

    if frame.unit == "player" then ns.Combat:Defer(hidePlayerCastBar) end
end

UF.elements.Cast = {
    create = create,
    refresh = refresh,
    events = {
        UNIT_SPELLCAST_START = refresh,
        UNIT_SPELLCAST_CHANNEL_START = refresh,
        UNIT_SPELLCAST_EMPOWER_START = refresh,
        UNIT_SPELLCAST_STOP = stop,
        UNIT_SPELLCAST_EMPOWER_STOP = empowerStop,
        UNIT_SPELLCAST_CHANNEL_STOP = channelStop,
        UNIT_SPELLCAST_FAILED = failed,
        UNIT_SPELLCAST_INTERRUPTED = interrupted,
        UNIT_SPELLCAST_DELAYED = delayed,
        UNIT_SPELLCAST_CHANNEL_UPDATE = delayed,
        UNIT_SPELLCAST_EMPOWER_UPDATE = delayed,
        UNIT_SPELLCAST_INTERRUPTIBLE = function(frame) setLocked(frame, false) end,
        UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function(frame) setLocked(frame, true) end,
    },
}
