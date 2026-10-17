local _, ns = ...

-- Timeline sources feed the renderer. A source owns the data, the renderer only draws.
--
-- Contract (V09 can add a BigWigs source next to this one):
--   source:Start(sink)            begin delivering; existing events arrive as OnAdd
--   source:Stop()                 stop; every live event is delivered as OnRemove first
--   source:GetOrder(max, out)     fill `out` with event ids, soonest first; returns count
--   source:GetColor(ev)           optional, r, g, b for the bar (may be secret)
--   source:SetIndicators(ev, tx)  optional, assign role/effect symbols to 4 textures
-- The sink receives sink:OnAdd(ev), sink:OnState(ev), sink:OnRemove(ev), sink:OnReorder().
-- An event record `ev` has: id (never secret, the key), name, icon (both may be secret),
-- duration (seconds, never secret), timer (LuaDurationObject or nil), state
-- (Enum.EncounterTimelineEventState), blocked (bool). Records belong to the source.
local TL = ns.Timeline or {}
ns.Timeline = TL

local IsSecret = ns.IsSecret
local CET = C_EncounterTimeline

local STATE = Enum.EncounterTimelineEventState or { Active = 0, Paused = 1, Finished = 2, Canceled = 3 }
TL.STATE = STATE

local Blizzard = { name = "blizzard", events = {} }
TL.BlizzardSource = Blizzard

local records = ns.Pool:New(function() return {} end, wipe)
local scratch = {}

local masks = Constants and Constants.EncounterTimelineIconMasks
local ROLE_ICONS = masks and masks.EncounterTimelineRoleIcons or 896
local OTHER_ICONS = masks and masks.EncounterTimelineOtherIcons or 127

-- Event payloads are plain tables whose display fields can be secret. Only the
-- NeverSecret fields (id, source, duration) are read by Lua, the rest is passed on.
local function readable(t)
    return t and not IsSecret(t) and (not canaccesstable or canaccesstable(t))
end

function Blizzard:Add(info)
    if not readable(info) then return end
    local id = info.id
    if not id or self.events[id] then return end
    local ev = records:Acquire()
    ev.id = id
    ev.name = info.spellName
    ev.icon = info.iconFileID
    ev.duration = info.duration or 0
    ev.timer = CET.GetEventTimer(id)
    ev.state = CET.GetEventState(id) or STATE.Active
    ev.blocked = CET.IsEventBlocked and CET.IsEventBlocked(id) or false
    self.events[id] = ev
    self.sink:OnAdd(ev)
end

function Blizzard:Remove(id)
    local ev = self.events[id]
    if not ev then return end
    self.events[id] = nil
    self.sink:OnRemove(ev)
    records:Release(ev)
end

function Blizzard:Clear()
    wipe(scratch)
    for id in pairs(self.events) do scratch[#scratch + 1] = id end
    for i = 1, #scratch do self:Remove(scratch[i]) end
    wipe(scratch)
end

-- Full rebuild from the API, used on start and whenever Blizzard swaps the view
-- (the view switch resets event data on the client side).
function Blizzard:Resync()
    self:Clear()
    local list = CET.GetEventList and CET.GetEventList()
    if not list then return end
    for i = 1, #list do
        local info = CET.GetEventInfo(list[i])
        if info then self:Add(info) end
    end
    self.sink:OnReorder()
end

local function onAdded(self, _, info)
    self:Add(info)
end

local function onState(self, _, id)
    local ev = self.events[id]
    if not ev then return end
    ev.state = CET.GetEventState(id) or ev.state
    if CET.IsEventBlocked then ev.blocked = CET.IsEventBlocked(id) or false end
    self.sink:OnState(ev)
end

local function onRemoved(self, _, id)
    self:Remove(id)
end

local function onTrack(self, _, id)
    if self.events[id] then self.sink:OnReorder() end
end

local function onViewActivated(self)
    self:Resync()
end

local function onViewDeactivated(self)
    self:Clear()
end

local handlers = {
    ENCOUNTER_TIMELINE_EVENT_ADDED = onAdded,
    ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = onState,
    ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED = onState,
    ENCOUNTER_TIMELINE_EVENT_COLOR_CHANGED = onState,
    ENCOUNTER_TIMELINE_EVENT_REMOVED = onRemoved,
    ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED = onTrack,
    ENCOUNTER_TIMELINE_VIEW_ACTIVATED = onViewActivated,
    ENCOUNTER_TIMELINE_VIEW_DEACTIVATED = onViewDeactivated,
}

function Blizzard:Start(sink)
    if self.sink then return end
    self.sink = sink
    for event, fn in pairs(handlers) do ns.Events:Register(event, self, fn) end
    self:Resync()
end

function Blizzard:Stop()
    if not self.sink then return end
    ns.Events:UnregisterAll(self)
    self:Clear()
    self.sink = nil
end

-- Terminal events stay in the list until REMOVED so their outro can play;
-- hidden events are included because the None view may not lay out any tracks.
function Blizzard:GetOrder(max, out)
    wipe(out)
    local list = CET.GetSortedEventList(max, nil, false, false)
    local n = 0
    if list then
        for i = 1, #list do
            if self.events[list[i]] then
                n = n + 1
                out[n] = list[i]
            end
        end
    end
    return n
end

function Blizzard:GetColor(ev)
    if not CET.GetEventColor then return end
    local c = CET.GetEventColor(ev.id)
    if not readable(c) then return end
    return c:GetRGB()
end

-- The icon mask is secret, so the client assigns the atlases itself.
-- textures[1..2] take role symbols, textures[3..4] effect symbols (deadly, enrage, dispel).
local roleTx, otherTx = {}, {}
function Blizzard:SetIndicators(ev, textures)
    if not CET.SetEventIconTextures then return end
    roleTx[1], roleTx[2] = textures[1], textures[2]
    otherTx[1], otherTx[2] = textures[3], textures[4]
    CET.SetEventIconTextures(ev.id, ROLE_ICONS, roleTx)
    CET.SetEventIconTextures(ev.id, OTHER_ICONS, otherTx)
end
