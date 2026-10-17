-- Minimal WoW client stub for headless tests. Frames record scripts, events and visibility.
local S = {}
_G.STUB = S
S.frames, S.inCombat = {}, false

local widget = {}
widget.__index = function(t, k)
    local m = rawget(widget, k)
    if m then return m end
    return function() end  -- every other widget method is a no-op
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
function widget:SetTexture(t) self.texture = t end
function widget:SetAlpha(a) self.alpha = a end
function widget:SetTimerDuration(d, interp, dir) self.timer = { d, interp, dir } end
function widget:GetStatusBarTexture() self.fill = rawget(self, "fill") or S.newWidget(); return self.fill end
-- *FromBoolean accept secret booleans, like the client. Anything but a boolean is an error there.
local function checkBool(v) assert(type(v) == "boolean", "boolean expected, got " .. type(v)) end
function widget:SetAlphaFromBoolean(v, a, b) checkBool(v); self.alphaBool = { v, a, b } end
function widget:SetVertexColorFromBoolean(v, a, b) checkBool(v); assert(a and b); self.colorBool = { v, a, b } end

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
S.timers = {}
C_Timer = { After = function(sec, fn) S.timers[#S.timers + 1] = { sec, fn } end }
-- Run every pending C_Timer.After callback once.
function S.runTimers()
    local list = S.timers
    S.timers = {}
    for _, t in ipairs(list) do t[2]() end
end
C_AddOns = { GetAddOnMetadata = function() return "0.0.0" end, IsAddOnLoaded = function(n) return S.loaded and S.loaded[n] or false end }

-- Unit API: every combat value is secret, like in an instance fight.
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 } }
FACTION_BAR_COLORS = { [4] = { r = 1, g = 1, b = 0 } }
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
CurveConstants = { ScaleTo100 = {} }
Enum = { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
    StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 } }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
FAILED, INTERRUPTED = "Failed", "Interrupted"
C_StringUtil = { CreateAbbreviatedNumberFormatter = function()
    return { FormatNumber = function(_, v) assert(issecretvalue(v) or type(v) == "number"); return "1.2M" end }
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
