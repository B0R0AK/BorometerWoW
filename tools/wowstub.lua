-- Minimal WoW client stub for headless tests. Frames record scripts, events and visibility.
local S = {}
_G.STUB = S
S.frames, S.inCombat = {}, false

local widget = {}
widget.__index = function(t, k)
    local m = rawget(widget, k)
    if m then return m end
    -- Every other widget method (CamelCase) is a no-op. Lowercase keys are addon fields and read as nil,
    -- like on a real frame.
    if type(k) == "string" and k:match("^%u") then return function() end end
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
function widget:CreateFontString() local r = S.newWidget(); r.parent = self; return r end
function widget:CreateTexture() local r = S.newWidget(); r.parent = self; return r end
function widget:GetParent() return self.parent end
function widget:SetText(t) self.text = t end
function widget:SetFormattedText(f, ...) self.formatted = { f, ... } end
function widget:SetValue(v) self.value = v end
function widget:SetMinMaxValues(a, b) self.min, self.max = a, b end
function widget:SetTexture(t) self.texture = t end
function widget:SetAlpha(a) self.alpha = a end
function widget:SetTimerDuration(d, interp, dir) self.timer = { d, interp, dir } end
function widget:GetStatusBarTexture() self.fill = rawget(self, "fill") or S.newWidget(); return self.fill end
-- *FromBoolean accept secret booleans, like the client. Anything but a boolean is an error there.
local function checkBool(v) assert(type(v) == "boolean", "boolean expected, got " .. type(v)) end
function widget:SetAlphaFromBoolean(v, a, b) checkBool(v); self.alphaBool = { v, a, b } end
function widget:SetVertexColorFromBoolean(v, a, b) checkBool(v); assert(a and b); self.colorBool = { v, a, b } end
function widget:SetHideCountdownNumbers(h) self.hideNumbers = h end
function widget:ClearAllPoints() self.points = {} end
function widget:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function widget:SetSize(w, h) self.w, self.h = w, h end
function widget:SetScale(s) self.scale = s end
function widget:GetEffectiveScale() return self.effScale or 1 end
function widget:IsProtected() return self.protected == true end
function widget:SetAlpha(a) self.alpha = a end
function widget:SetFont(font, size, flags) self.font = { font, size, flags } end
function widget:SetSpriteSheetCell(cell) self.cell = cell end
function widget:SetAtlas(a) self.atlas = a end
function widget:SetStatusBarDesaturated(v) self.desaturated = v end
function widget:SetStatusBarColor(r, g, b) self.color = { r, g, b } end
function widget:SetVertexColor(r, g, b) self.vcolor = { r, g, b } end
function widget:GetParent() return self.parent end
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

function CreateFrame(kind, name, parent, template)
    local f = S.newWidget()
    f.kind, f.name, f.parent, f.template = kind, name, parent, template
    S.frames[#S.frames + 1] = f
    if name then _G[name] = f end
    if kind == "AuraContainer" then S.initAuraContainer(f) end
    return f
end

function S.isDescendant(obj, owner)
    local p = obj.parent
    while p do
        if p == owner then return true end
        p = p.parent
    end
    return false
end

-- AuraContainer / AuraButton (12.1): the engine owns aura data. The stub records the
-- configuration and enforces Blizzard's rule that display regions descend from the button.
local auraButton = setmetatable({}, { __index = widget })
auraButton.__index = function(t, k) return rawget(auraButton, k) or widget.__index(t, k) end
local function adopt(slot)
    return function(self, region, options)
        assert(S.isDescendant(region, self), slot .. ": region must descend from the aura button")
        self.display[slot] = region
        self.displayOptions[slot] = options
    end
end
auraButton.SetIcon = adopt("icon")
auraButton.SetDurationCooldown = adopt("cooldown")
auraButton.SetDurationText = adopt("durationText")
auraButton.SetApplicationCount = adopt("count")
auraButton.AddDispelTypeTexture = adopt("dispel")
function auraButton:SetSize(w, h) self.w, self.h = w, h end

-- What the engine does when an aura is assigned while auras are secret.
function S.assignSecretAura(button)
    local d = button.display
    if d.cooldown then d.cooldown:SetCooldownFromDurationObject(S.secret("auraDuration")) end
    if d.durationText then d.durationText:SetText(S.secret("auraRemaining")) end
    if d.count then d.count:SetText(S.secret("auraCount")) end
end

local container = {}
function container:SetUnit(u) self.unit = u end
function container:SetEnabled(e) self.enabled = e end
function container:UpdateAllAuras() self.fullUpdates = self.fullUpdates + 1 end
function container:SetFlowLayoutAnchorPoint(p) self.flowAnchor = p end
function container:SetFlowLayoutGrowthDirection(h, v) self.growth = { h, v } end
function container:SetFlowLayoutMaximumLineSize(n) self.maxLine = n end
function container:AddAuraGroup(key, filter, options)
    assert(type(key) == "string" and key ~= "" and not self.groups[key], "bad group key")
    assert(type(filter) == "string" and filter ~= "", "bad filter")
    assert(options.sortMethod ~= nil, "sortMethod must be a valid AuraContainerSortMethod")
    local group = { filter = filter, options = options, buttons = {} }
    for i = 1, 10 do  -- first batch, like CustomAuraContainerConstants.FrameCreationBatchSize
        local b = setmetatable(S.newWidget(), auraButton)
        b.kind, b.parent, b.display, b.displayOptions = "AuraButton", self, {}, {}
        if options.initializeFrame then options.initializeFrame(b) end
        group.buttons[i] = b
    end
    self.groups[key] = group
    self.groupOrder[#self.groupOrder + 1] = key
end

function S.initAuraContainer(f)
    f.groups, f.groupOrder, f.fullUpdates = {}, {}, 0
    for k, v in pairs(container) do f[k] = v end
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
-- realType: what type() reports for the secret in the client (default "number").
function S.secret(label, realType) return setmetatable({ __label = label, __type = realType }, secretMT) end
function issecretvalue(v) return getmetatable(v) == secretMT end
-- type() on a secret returns the real type in the client.
local rawtype = type
function type(v)
    if getmetatable(v) == secretMT then return rawget(v, "__type") or "number" end
    return rawtype(v)
end

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
-- Post-hook like the client: original runs first, its results are returned unchanged.
function hooksecurefunc(t, k, fn)
    if type(t) == "string" then t, k, fn = _G, t, k end
    local orig = t[k]
    t[k] = function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end
end
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
-- Runs every pending timer once. With zeroOnly, only zero-delay ones (layout passes).
function S.runTimers(zeroOnly)
    local list = S.timers
    S.timers = {}
    for _, t in ipairs(list) do
        if t.cancelled then -- dropped
        elseif zeroOnly and t[1] ~= 0 then S.timers[#S.timers + 1] = t
        else t[2]() end
    end
end
C_AddOns = { GetAddOnMetadata = function() return "0.0.0" end, IsAddOnLoaded = function(n) return S.loaded and S.loaded[n] or false end }

-- Unit API: every combat value is secret, like in an instance fight.
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 } }
FACTION_BAR_COLORS = { [4] = { r = 1, g = 1, b = 0 } }
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
CurveConstants = { ScaleTo100 = {} }
Enum = { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
    StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
    CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2, PreserveAsset = 3, CustomAsset = 4 },
    EncounterTimelineViewType = { None = 0, Timeline = 1, Bars = 2 },
    EncounterTimelineEventState = { Active = 0, Paused = 1, Finished = 2, Canceled = 3 },
    EncounterTimelineEventSource = { Encounter = 0, Script = 1, EditMode = 2 },
    EncounterEventSeverity = { Low = 0, Medium = 1, High = 2 },
    SecondsFormatterAbbreviation = { None = 0, Truncate = 1, OneLetter = 2 },
    SecondsFormatterInterval = { Seconds = 0, Minutes = 1, Hours = 2, Days = 3 },
    PowerType = { Mana = 0, Energy = 3, ComboPoints = 4, Runes = 5, SoulShards = 7, HolyPower = 9, Chi = 12,
        ArcaneCharges = 16, Essence = 19 } }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
FAILED, INTERRUPTED = "Failed", "Interrupted"
AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4 }
AnchorUtil = { FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
Constants = { EncounterTimelineIconMasks = { EncounterTimelineRoleIcons = 896, EncounterTimelineOtherIcons = 127 } }
C_StringUtil = {
    CreateAbbreviatedNumberFormatter = function()
        return { FormatNumber = function(_, v) assert(issecretvalue(v) or type(v) == "number"); return "1.2M" end }
    end,
    CreateSecondsFormatter = function() return S.newWidget() end,
}
C_DurationUtil = {
    CreateDuration = function()
        return { SetTimeFromStart = function(self, start, dur) self.start, self.dur = start, dur end }
    end,
    CreateDurationTextBinding = function()
    local b = S.newWidget()
    function b:SetDuration(d) self.duration = d end
    function b:SetEnabled(on) self.enabled = on end
    function b:SetToDefaults() self.duration, self.enabled = nil, false end
    return b
end }
function UnitHealth() return S.secret("hp") end
function UnitHealthMax() return S.secret("maxhp") end
function UnitPower(_, ptype) if ptype and S.plainPower then return S.plainPower end return S.secret("pow") end
function UnitPowerMax(_, ptype) if ptype and S.plainMax then return S.plainMax end return S.secret("maxpow") end
function UnitGetTotalAbsorbs() return S.secret("absorb") end
function UnitIsPlayer() return S.secret("isplayer") end
function UnitClass(unit)
    if unit == "player" and S.class then return S.class, S.class end
    return "Warrior", S.secret("class")
end
function UnitReaction() return S.secret("reaction") end
function UnitPowerType() return S.powerType or 0, S.secret("powertoken") end
function UnitHealthPercent() return 73.4 end
function AbbreviateNumbers(v) assert(issecretvalue(v) or type(v) == "number"); return "1.2M" end
function UnitName(unit) if unit == "player" then return "Tester" end return S.secret("name") end

-- Casts. S.casts[unit] = { kind = "cast" | "channel" | "empower", castBarID = n }.
-- Name, icon, notInterruptible and the duration are secret, like an enemy cast in an instance.
S.casts = {}
local function castOf(unit, kind)
    local c = S.casts[unit]
    if c and (c.kind == kind or (kind == "channel" and c.kind == "empower")) then return c end
end
local function duration(label) return S.secret(label, "userdata") end
function UnitCastingInfo(unit)
    local c = castOf(unit, "cast")
    if not c then return nil end
    return S.secret("castname", "string"), S.secret("castdisplay", "string"), S.secret("casticon"),
        S.secret("start"), S.secret("end"), false, S.secret("castguid", "string"),
        S.secret("notint", "boolean"), S.secret("spellid"), c.castBarID, 0
end
function UnitChannelInfo(unit)
    local c = castOf(unit, "channel")
    if not c then return nil end
    return S.secret("channame", "string"), S.secret("chandisplay", "string"), S.secret("chanicon"),
        S.secret("start"), S.secret("end"), false, S.secret("notint", "boolean"), S.secret("spellid"),
        c.kind == "empower", c.kind == "empower" and 3 or 0, c.castBarID
end
function UnitCastingDuration(unit) if castOf(unit, "cast") then return duration("castdur") end end
function UnitChannelDuration(unit) if castOf(unit, "channel") then return duration("chandur") end end
function UnitEmpoweredChannelDuration(unit, includeHold)
    assert(includeHold == true)
    if castOf(unit, "channel") then return duration("empdur") end
end
PlayerCastingBarFrame = CreateFrame("StatusBar", "PlayerCastingBarFrame")
PlayerCastingBarFrame.unit = "player"
function PlayerCastingBarFrame:SetUnit(unit) self.unit = unit end
-- Frame extras (V04). Identity-restricted flags and incoming heals are secret, like on an instance map.
function UnitGetIncomingHeals() return S.secret("incheal") end
function GetRaidTargetIndex() if S.raidIndex ~= nil then return S.raidIndex or nil end return S.secret("raidindex") end
function UnitGroupRolesAssigned() return S.secret("role") end
function UnitIsGroupLeader() return S.secret("leader", "boolean") end
function UnitIsGroupAssistant() return S.secret("assist", "boolean") end
function UnitIsPVP() return S.secret("pvp", "boolean") end
function UnitIsPVPFreeForAll() return S.secret("ffa") end
function UnitFactionGroup() return "Horde", "Horde" end
function UnitIsDeadOrGhost() if S.dead == "secret" then return S.secret("dead") end return S.dead or false end
function UnitIsConnected() return S.online ~= false end
function UnitEffectiveLevel(unit)
    if unit == "player" then return 80 end
    if S.level then return S.level end
    return S.secret("level")
end
function UnitClassification() return "elite" end
function UnitPartialPower() if S.partial then return S.partial end return S.secret("partial") end
function UnitPowerDisplayMod() return 10 end
function GetRuneCooldown() return S.secret("runestart"), S.secret("runedur"), S.secret("runeready") end
C_SpecializationInfo = { GetSpecialization = function() return S.spec or 1 end }
UnitFrameUtil = {
    GetUnitRoleIconDisplayInfo = function(_, options)
        assert(options.displayRoleIcon)
        return { roleIconTexture = S.secret("roletex"), showRoleIcon = S.secret("showrole", "boolean"), iconWidth = S.secret("w") }
    end,
    UpdateUnitPvPIndicator = function(elements) S.pvpUpdated = elements.pvpIcon end,
}
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
