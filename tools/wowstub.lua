-- Minimal WoW client stub for headless tests. Frames record scripts, events and visibility.
local S = {}
_G.STUB = S
S.frames, S.inCombat = {}, false

local widget = {}
widget.__index = function(t, k)
    local m = rawget(widget, k)
    if m then return m end
    -- Every other widget method (CamelCase) is a no-op. Unset lowercase fields stay nil,
    -- as on real frames, so code can test them.
    if type(k) == "string" and k:find("^%u") then return function() end end
    return nil
end

function widget:SetScript(name, fn) self.scripts[name] = fn end
function widget:HookScript(name, fn) self.hooks[#self.hooks + 1] = { name, fn } end
function widget:GetScript(name) return self.scripts[name] end
function widget:RegisterEvent(e) self.events[e] = true end
function widget:RegisterUnitEvent(e, ...) self.events[e] = true; self.unitEvents[e] = { ... } end
function widget:UnregisterEvent(e) self.events[e] = nil end
function widget:UnregisterAllEvents() self.events = {} end
function widget:IsEventRegistered(e) return self.events[e] == true end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsVisible() return self.shown end
function widget:IsShown() return self.shown end
function widget:SetAttribute(k, v) self.attr[k] = v end
function widget:GetAttribute(k) return self.attr[k] end
function widget:GetFrameLevel() return 1 end
function widget:GetNumRegions() return 0 end
function widget:GetRegions() end
function widget:IsObjectType() return false end
function widget:CreateFontString() return S.newWidget() end
function widget:CreateTexture() return S.newWidget() end
function widget:SetText(t) self.text = t end
function widget:SetFormattedText(f, ...) self.formatted = { f, ... } end
function widget:SetValue(v) self.value = v end
function widget:SetMinMaxValues(a, b) self.min, self.max = a, b end
function widget:SetAlpha(a) self.alpha = a end
function widget:SetTexture(t) self.texture = t end
function widget:SetStatusBarColor(r, g, b) self.color = { r, g, b } end
function widget:SetVertexColor(r, g, b) self.vcolor = { r, g, b } end
function widget:SetTimerDuration(d, interp, dir) self.timer, self.timerDir = d, dir end
function widget:SetSize(w, h) self.w, self.h = w, h end
function widget:GetParent() return self.parent end
function widget:GetStatusBarTexture()
    self.tex = self.tex or S.newWidget()
    return self.tex
end
function widget:CreateAnimationGroup()
    local g = S.newWidget()
    g.parent = self
    return g
end
function widget:CreateAnimation() return S.newWidget() end
function widget:Play() self.playing = true end
function widget:Stop() self.playing = false end
function widget:IsPlaying() return self.playing == true end

function S.newWidget()
    return setmetatable({ scripts = {}, hooks = {}, events = {}, unitEvents = {}, attr = {}, shown = true, watched = false }, widget)
end

function CreateFrame(kind, name)
    local f = S.newWidget()
    f.kind, f.name = kind, name
    S.frames[#S.frames + 1] = f
    if name then _G[name] = f end
    return f
end

-- Deliver a global event the way the client would.
function S.fire(event, ...)
    for _, f in ipairs(S.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- One engine frame of OnUpdate on every visible frame that has the script.
function S.update(elapsed)
    for _, f in ipairs(S.frames) do
        if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, elapsed) end
    end
end

-- A secret value: any Lua operation on it raises, like the real thing.
local secretMT = {}
local function boom() error("attempt to use a secret value", 2) end
secretMT.__add, secretMT.__sub, secretMT.__mul, secretMT.__div = boom, boom, boom, boom
secretMT.__lt, secretMT.__le, secretMT.__concat, secretMT.__len, secretMT.__unm = boom, boom, boom, boom, boom
secretMT.__index = boom
function S.secret(label) return setmetatable({ __label = label }, secretMT) end
function issecretvalue(v) return getmetatable(v) == secretMT end

UIParent = CreateFrame("Frame", "UIParent")
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
BackdropTemplateMixin = {}
function Mixin(t, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do t[k] = v end end return t end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(sep, s) local out = {} for p in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = p end return unpack(out) end
function InCombatLockdown() return S.inCombat end
function GetRealmName() return "Realm" end
function ReloadUI() S.reloaded = true end
function debugprofilestop() return os.clock() * 1000 end
function RegisterUnitWatch(f) f.watched = true end
SlashCmdList = {}
S.timers = {}
C_Timer = {
    After = function(sec, fn) S.timers[#S.timers + 1] = { sec, fn } end,
    NewTimer = function(sec, fn)
        local t = { sec, fn }
        function t:Cancel() self.cancelled = true end
        S.timers[#S.timers + 1] = t
        return t
    end,
}
-- Runs queued zero-delay timers (layout passes), like the next engine frame would.
function S.runTimers()
    local list = S.timers
    S.timers = {}
    for _, t in ipairs(list) do
        if t[1] == 0 and not t.cancelled then t[2]() else S.timers[#S.timers + 1] = t end
    end
end
function hooksecurefunc(t, name, fn)
    local orig = t[name]
    t[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
end
C_AddOns = { GetAddOnMetadata = function() return "0.0.0" end, IsAddOnLoaded = function(n) return S.loaded and S.loaded[n] or false end }

-- Unit API: every combat value is secret, like in an instance fight.
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 } }
FACTION_BAR_COLORS = { [4] = { r = 1, g = 1, b = 0 } }
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
CurveConstants = { ScaleTo100 = {} }
Enum = {
    StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
    StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
    EncounterTimelineViewType = { None = 0, Timeline = 1, Bars = 2 },
    EncounterTimelineEventState = { Active = 0, Paused = 1, Finished = 2, Canceled = 3 },
    EncounterTimelineEventSource = { Encounter = 0, Script = 1, EditMode = 2 },
    EncounterEventSeverity = { Low = 0, Medium = 1, High = 2 },
    SecondsFormatterAbbreviation = { None = 0, Truncate = 1, OneLetter = 2 },
    SecondsFormatterInterval = { Seconds = 0, Minutes = 1, Hours = 2, Days = 3 },
}
Constants = { EncounterTimelineIconMasks = { EncounterTimelineRoleIcons = 896, EncounterTimelineOtherIcons = 127 } }
C_StringUtil = {
    CreateAbbreviatedNumberFormatter = function()
        return { FormatNumber = function(_, v) assert(issecretvalue(v) or type(v) == "number"); return "1.2M" end }
    end,
    CreateSecondsFormatter = function() return S.newWidget() end,
}
C_DurationUtil = { CreateDurationTextBinding = function()
    local b = S.newWidget()
    function b:SetDuration(d) self.duration = d end
    function b:SetEnabled(on) self.enabled = on end
    function b:SetToDefaults() self.duration, self.enabled = nil, false end
    return b
end }
function UnitHealth() return S.secret("hp") end
function UnitHealthMax() return S.secret("maxhp") end
function UnitPower() return S.secret("pow") end
function UnitPowerMax() return S.secret("maxpow") end
function UnitGetTotalAbsorbs() return S.secret("absorb") end
function UnitIsPlayer() return S.secret("isplayer") end
function UnitClass() return "Warrior", S.secret("class") end
function UnitReaction() return S.secret("reaction") end
function UnitPowerType() return 0, S.secret("powertoken") end
function UnitHealthPercent() return 73.4 end
function AbbreviateNumbers(v) assert(issecretvalue(v) or type(v) == "number"); return "1.2M" end
function UnitName(unit) if unit == "player" then return "Tester" end return S.secret("name") end

-- Encounter timeline: a tiny event store. Display fields are secret, like in a boss fight.
local TLS = Enum.EncounterTimelineEventState
S.tl = { events = {}, view = Enum.EncounterTimelineViewType.Bars, iconCalls = 0, nextEditID = 900 }
EncounterTimeline = CreateFrame("Frame", "EncounterTimeline")

local function tlInfo(e)
    return {
        id = e.id, source = e.source, duration = e.duration, maxQueueDuration = 0,
        spellName = S.secret("spellName"), spellID = S.secret("spellID"), iconFileID = S.secret("iconFileID"),
        icons = S.secret("icons"), severity = S.secret("severity"), isApproximate = S.secret("isApproximate"),
    }
end

-- Adds an event with `remaining` seconds left and fires ENCOUNTER_TIMELINE_EVENT_ADDED.
function S.tlAdd(id, remaining, source)
    local e = { id = id, remaining = remaining, duration = remaining + 5, state = TLS.Active,
        source = source or Enum.EncounterTimelineEventSource.Encounter, timer = { durationObject = id } }
    S.tl.events[id] = e
    S.fire("ENCOUNTER_TIMELINE_EVENT_ADDED", tlInfo(e))
end

function S.tlState(id, state)
    S.tl.events[id].state = state
    S.fire("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", id)
end

function S.tlRemove(id)
    S.tl.events[id] = nil
    S.fire("ENCOUNTER_TIMELINE_EVENT_REMOVED", id)
end

local function valid(id) return S.tl.events[id] end

C_EncounterTimeline = {
    GetViewType = function() return S.tl.view end,
    SetViewType = function(v)
        assert(type(v) == "number", "view type must be a plain number")
        local old = S.tl.view
        S.tl.view = v
        S.fire("ENCOUNTER_TIMELINE_VIEW_DEACTIVATED", old)
        S.fire("ENCOUNTER_TIMELINE_VIEW_ACTIVATED", v)
    end,
    GetEventList = function()
        local out = {}
        for id in pairs(S.tl.events) do out[#out + 1] = id end
        return out
    end,
    GetSortedEventList = function(max, _, excludeTerminal)
        local out = {}
        for id, e in pairs(S.tl.events) do
            local terminal = e.state == TLS.Finished or e.state == TLS.Canceled
            if not (terminal and excludeTerminal ~= false) then out[#out + 1] = id end
        end
        table.sort(out, function(a, b) return S.tl.events[a].remaining < S.tl.events[b].remaining end)
        for i = #out, (max or #out) + 1, -1 do out[i] = nil end
        return out
    end,
    GetEventInfo = function(id) local e = valid(id) return e and tlInfo(e) end,
    GetEventState = function(id) local e = valid(id) return e and e.state end,
    IsEventBlocked = function(id) local e = valid(id) return e and e.blocked or false end,
    GetEventTimer = function(id) local e = valid(id) return e and e.timer end,
    GetEventColor = function(id)
        if not valid(id) then return end
        return { GetRGB = function() return S.secret("r"), S.secret("g"), S.secret("b") end }
    end,
    SetEventIconTextures = function(id, mask, textures)
        assert(valid(id) and type(mask) == "number" and #textures == 2)
        S.tl.iconCalls = S.tl.iconCalls + 1
    end,
    AddEditModeEvents = function()
        for i = 1, 3 do
            S.tl.nextEditID = S.tl.nextEditID + 1
            S.tlAdd(S.tl.nextEditID, i * 4, Enum.EncounterTimelineEventSource.EditMode)
        end
        return 20
    end,
    CancelEditModeEvents = function()
        local ids = {}
        for id, e in pairs(S.tl.events) do
            if e.source == Enum.EncounterTimelineEventSource.EditMode then ids[#ids + 1] = id end
        end
        for _, id in ipairs(ids) do S.tlRemove(id) end
    end,
}
