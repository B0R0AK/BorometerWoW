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
function widget:CreateFontString() return S.newWidget() end
function widget:CreateTexture() return S.newWidget() end
function widget:SetText(t) self.text = t end
function widget:SetFormattedText(f, ...) self.formatted = { f, ... } end
function widget:SetValue(v) self.value = v end
function widget:SetMinMaxValues(a, b) self.min, self.max = a, b end
function widget:GetStatusBarTexture() self.fill = self.fill or S.newWidget(); return self.fill end
function widget:SetSpriteSheetCell(cell) self.cell = cell end
function widget:SetAlphaFromBoolean(v) self.alphaBool = v end
function widget:SetAlpha(a) self.alpha = a end
function widget:SetAtlas(a) self.atlas = a end
function widget:SetTimerDuration(d) self.timer = d end
function widget:SetStatusBarDesaturated(v) self.desaturated = v end

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
C_Timer = { After = function(sec, fn) S.timers[#S.timers + 1] = { sec, fn } end }
C_AddOns = { GetAddOnMetadata = function() return "0.0.0" end, IsAddOnLoaded = function(n) return S.loaded and S.loaded[n] or false end }

-- Unit API: every combat value is secret, like in an instance fight.
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 } }
FACTION_BAR_COLORS = { [4] = { r = 1, g = 1, b = 0 } }
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
CurveConstants = { ScaleTo100 = {} }
Enum = { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 },
    PowerType = { Mana = 0, Energy = 3, ComboPoints = 4, Runes = 5, SoulShards = 7, HolyPower = 9, Chi = 12,
        ArcaneCharges = 16, Essence = 19 } }
C_StringUtil = { CreateAbbreviatedNumberFormatter = function()
    return { FormatNumber = function(_, v) assert(issecretvalue(v) or type(v) == "number"); return "1.2M" end }
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

-- Frame extras (V04). Identity-restricted flags and incoming heals are secret, like on an instance map.
function UnitGetIncomingHeals() return S.secret("incheal") end
function GetRaidTargetIndex() if S.raidIndex ~= nil then return S.raidIndex or nil end return S.secret("raidindex") end
function UnitGroupRolesAssigned() return S.secret("role") end
function UnitIsGroupLeader() return S.secret("leader") end
function UnitIsGroupAssistant() return S.secret("assist") end
function UnitIsPVP() return S.secret("pvp") end
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
C_DurationUtil = { CreateDuration = function()
    return { SetTimeFromStart = function(self, start, dur) self.start, self.dur = start, dur end }
end }
C_SpecializationInfo = { GetSpecialization = function() return S.spec or 1 end }
UnitFrameUtil = {
    GetUnitRoleIconDisplayInfo = function(_, options)
        assert(options.displayRoleIcon)
        return { roleIconTexture = S.secret("roletex"), showRoleIcon = S.secret("showrole"), iconWidth = S.secret("w") }
    end,
    UpdateUnitPvPIndicator = function(elements) S.pvpUpdated = elements.pvpIcon end,
}
