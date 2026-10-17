-- Headless smoke test for Core and the damage meter skin. Run through tools/smoke.py.
local root = ...
dofile(root .. "/tools/wowstub.lua")
local S = STUB

local ns = {}
for line in io.lines(root .. "/Borometer/Borometer.toc") do
    if line:match("%.lua%s*$") then
        local path = root .. "/Borometer/" .. line:gsub("\\", "/"):gsub("%s+$", "")
        local chunk = assert(loadfile(path))
        chunk("Borometer", ns)
    end
end

local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
    passed = passed + 1
end

-- boot ----------------------------------------------------------------------
S.fire("ADDON_LOADED", "Borometer")
S.fire("PLAYER_LOGIN")
test("config creates the profile", function()
    local db = BorometerDB
    assert(db.profileKeys["Tester-Realm"] == "Default")
    assert(db.profiles.Default.modules and db.profiles.Default.movers)
end)

test("config fill is additive", function()
    local t = { a = { x = 1 } }
    ns.Config._fill(t, { a = { x = 9, y = 2 }, b = 3 })
    assert(t.a.x == 1 and t.a.y == 2 and t.b == 3)
end)

-- events ----------------------------------------------------------------------
test("events: dispatch, unregister during dispatch, compaction", function()
    local owner1, owner2, calls = {}, {}, {}
    ns.Events:Register("TEST_EVENT", owner1, function() calls[#calls + 1] = 1; ns.Events:Unregister("TEST_EVENT", owner1) end)
    ns.Events:Register("TEST_EVENT", owner2, function() calls[#calls + 1] = 2 end)
    S.fire("TEST_EVENT")
    S.fire("TEST_EVENT")
    assert(table.concat(calls, ",") == "1,2,2", table.concat(calls, ","))
    ns.Events:Unregister("TEST_EVENT", owner2)
    S.fire("TEST_EVENT")
    S.fire("TEST_EVENT")
end)

test("events: erroring handler does not block the next", function()
    local a, b, ran = {}, {}, false
    ns.Events:Register("TEST_ERR", a, function() error("x") end)
    ns.Events:Register("TEST_ERR", b, function() ran = true end)
    S.fire("TEST_ERR")
    assert(ran)
end)

-- scheduler -------------------------------------------------------------------
test("scheduler: interval, cancel in callback, driver sleeps when empty", function()
    local n, h = 0, nil
    local before = 0
    h = ns.Scheduler:Every(0.5, function() n = n + 1; if n == 2 then ns.Scheduler:Cancel(h) end end, "t")
    for _ = 1, 20 do S.update(0.25) end
    assert(n == 2, "ticks " .. n)
    S.update(0.1)
    local driver
    for _, f in ipairs(S.frames) do if f.scripts.OnUpdate then driver = f end end
    assert(driver.shown == false, "driver still shown")
end)

-- pool ------------------------------------------------------------------------
test("pool reuses objects", function()
    local made = 0
    local pool = ns.Pool:New(function() made = made + 1; return {} end, function(o) o.used = false end)
    local a = pool:Acquire(); a.used = true
    pool:Release(a)
    assert(a.used == false)
    local b = pool:Acquire()
    assert(a == b and made == 1)
    pool:Release(b); pool:Release(b)  -- double release is ignored
    assert(pool.nFree == 1)
end)

-- combat ----------------------------------------------------------------------
test("combat defer queues and flushes", function()
    local out = {}
    S.inCombat = true
    ns.Combat:Defer(function(a, b) out[#out + 1] = a .. b end, "x", "y")
    ns.Combat:Defer(function() error("boom") end)
    assert(#out == 0 and ns.Combat:Pending() == 2)
    S.inCombat = false
    S.fire("PLAYER_REGEN_ENABLED")
    assert(out[1] == "xy" and ns.Combat:Pending() == 0)
    ns.Combat:Defer(function() out[#out + 1] = "now" end)
    assert(out[2] == "now")
end)

-- skins -----------------------------------------------------------------------
test("skins: one failing skin does not stop others, lazy for LoD", function()
    local ran = {}
    ns.Skin:Register("Bad", nil, function() error("bad skin") end)
    ns.Skin:Register("Good", nil, function() ran.good = true end)
    ns.Skin:Register("Lazy", "Blizzard_Lazy", function() ran.lazy = true end)
    assert(ran.good and not ran.lazy)
    S.fire("ADDON_LOADED", "Blizzard_Lazy")
    assert(ran.lazy)
end)

test("modules: disable and enable", function()
    local m = ns:NewModule("Dummy")
    local on = false
    function m:OnEnable() on = true end
    function m:OnDisable() on = false end
    ns:EnableModule("Dummy"); assert(on)
    ns:DisableModule("Dummy"); assert(not on)
end)

test("slash commands parse", function()
    SlashCmdList.BOROMETER("modules")
    SlashCmdList.BOROMETER("")
    SlashCmdList.BOROMETER("module DamageMeterSkin on")
end)

-- damage meter skin -------------------------------------------------------------
-- Fake Blizzard_DamageMeter: just the regions, fields and methods the skin touches. Every
-- getter that would expose a secret aspect (bar geometry, values, texts) raises.
local hookCount = {}
function hooksecurefunc(t, k, fn)
    if type(t) == "string" then t, k, fn = _G, t, k end
    local orig = t[k]
    assert(type(orig) == "function", "hook target missing: " .. tostring(k))
    t[k] = function(...) orig(...); fn(...) end
    hookCount[t] = (hookCount[t] or 0) + 1
end

local function forbidden(what) return function() error("read of secret aspect: " .. what, 2) end end
local function tex()
    local t = S.newWidget()
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetVertexColor(r, g, b) self.vertex = { r, g, b } end
    function t:SetAtlas(a) self.atlas = a; self.color = nil end
    function t:SetTexture(f) self.textureSet = true; self.file = f; self.color = nil end
    function t:SetAlpha(a) self.alpha = a end
    return t
end
local function fontString()
    local fs = S.newWidget()
    fs.GetText = forbidden("text")
    function fs:SetFont(f, size) self.font = { f, size } end
    return fs
end
local function statusBar()
    local bar, fill = S.newWidget(), tex()
    bar.Background, bar.BackgroundEdge = tex(), tex()
    bar.Name, bar.Value = fontString(), fontString()
    function bar:GetStatusBarTexture() return fill end
    function bar:SetStatusBarTexture(f) self.barFile = f; fill.vertex = nil end
    for _, m in ipairs({ "GetWidth", "GetHeight", "GetSize", "GetPoint", "GetCenter", "GetRect", "GetValue", "GetMinMaxValues" }) do
        bar[m] = forbidden(m)
    end
    return bar
end
local function colorT(r, g, b) return { r = r, g = g, b = b, GetRGB = function(c) return c.r, c.g, c.b end } end
DAMAGE_METER_STATUS_BAR_DEFAULT_COLOR = colorT(.5, .5, .5)
DAMAGE_METER_STATUS_BAR_CREATURE_COLOR = colorT(.6, .2, .2)
DAMAGE_METER_STATUS_BAR_ENEMY_COLOR = colorT(1, 0, 0)
DAMAGE_METER_STATUS_BAR_ALLY_COLOR = colorT(0, 0, 1)
local WARRIOR = colorT(.78, .61, .43)

local EntryMixin = {}
function EntryMixin:UpdateStyle() self.StatusBar.Background:SetAtlas("ui-damagemeters-bar-shadowbg") end
function EntryMixin:SetStatusBarColor(color)
    if color ~= self.statusBarColor then
        self.statusBarColor = color
        self.StatusBar:GetStatusBarTexture():SetVertexColor(color:GetRGB())
    end
end
function EntryMixin:UpdateStatusBarColor()
    self:SetStatusBarColor(self.isClassColorDesired and WARRIOR or DAMAGE_METER_STATUS_BAR_DEFAULT_COLOR)
end
function EntryMixin:Init(source)
    local bar = self.StatusBar
    bar:SetMinMaxValues(0, source.maxAmount)
    bar:SetValue(source.totalAmount)
    bar.Name:SetText(source.name)
    bar.Value:SetText(source.totalAmount)
    self:UpdateStatusBarColor()
    self:UpdateStyle()
end
DamageMeterEntryMixin = EntryMixin
DamageMeterSpellEntryMixin = { Init = function(self, s) EntryMixin.Init(self, s) end }
local function newEntry(extra)
    local e = S.newWidget()
    e.StatusBar = statusBar()
    -- the stub answers unknown keys with a function; the client answers nil
    e.statusBarColor, e.isClassColorDesired = false, false
    Mixin(e, EntryMixin, extra or {})
    return e
end
local function secretSource()
    return { totalAmount = S.secret("amount"), maxAmount = S.secret("max"), name = S.secret("name") }
end

local function sessionWindow(name)
    local win = CreateFrame("Frame", name)
    win.Header, win.SessionTimer = tex(), fontString()
    win.DamageMeterTypeDropdown = S.newWidget()
    win.DamageMeterTypeDropdown.TypeName, win.DamageMeterTypeDropdown.Arrow = fontString(), tex()
    win.SessionDropdown = S.newWidget()
    win.SessionDropdown.SessionName, win.SessionDropdown.Background, win.SessionDropdown.Arrow = fontString(), tex(), tex()
    win.SettingsDropdown = S.newWidget()
    win.SettingsDropdown.Icon = tex()
    local normal, pushed = tex(), tex()
    win.MinimizeButton = S.newWidget()
    function win.MinimizeButton:GetNormalTexture() return normal end
    function win.MinimizeButton:GetPushedTexture() return pushed end
    local box = S.newWidget()
    box.Background, box.NotActive, box.LocalPlayerEntry = tex(), fontString(), newEntry()
    local sw = S.newWidget()
    sw.Background, sw.rows = tex(), {}
    function sw:EnumerateEntryFrames() return ipairs(self.rows) end
    box.SourceWindow = sw
    win.MinimizeContainer = box
    win.rows = { newEntry(), newEntry() }  -- rows acquired before the skin ran
    function win:EnumerateEntryFrames() return ipairs(self.rows) end
    function win:InitEntry(frame, data) frame:Init(data) end
    return win
end

local dmWin = sessionWindow("DamageMeterSessionWindow1")
CreateFrame("Frame", "DamageMeter")
function DamageMeter:SetupSessionWindow(index, windowData)
    windowData.sessionWindow = windowData.sessionWindow or sessionWindow("DamageMeterSessionWindow" .. index)
end
local originalSpellInit = DamageMeterSpellEntryMixin.Init
local DMS = ns.DamageMeterSkin

test("dmskin: Blizzard addon not loaded, nothing is touched", function()
    assert(ns.modules.DamageMeterSkin:IsEnabled())
    S.fire("ADDON_LOADED", "Blizzard_SomethingElse")
    assert(DamageMeterSpellEntryMixin.Init == originalSpellInit)
    assert(not DMS._hooked[dmWin.rows[1]] and not hookCount[dmWin])
end)

test("dmskin: lazy on ADDON_LOADED, windows and existing rows skinned", function()
    local errors, print0 = {}, ns.Debug.Print
    ns.Debug.Print = function(...) errors[#errors + 1] = table.concat({ ... }, " ") end
    S.loaded = { Blizzard_DamageMeter = true }
    S.fire("ADDON_LOADED", "Blizzard_DamageMeter")
    ns.Debug.Print = print0
    assert(#errors == 0, errors[1])
    assert(DamageMeterSpellEntryMixin.Init ~= originalSpellInit)
    assert(hookCount[dmWin] == 1 and hookCount[DamageMeter] == 1)
    local box = dmWin.MinimizeContainer
    assert(DMS._hooked[dmWin.rows[1]] and DMS._hooked[dmWin.rows[2]] and DMS._hooked[box.LocalPlayerEntry])
    assert(box.Background.color[1] == ns.Theme.color.comb[1])
    assert(dmWin.SessionDropdown.Background.alpha == 0)
    local bar = dmWin.rows[1].StatusBar
    assert(bar.barFile == ns.Theme.bar and bar.BackgroundEdge.textureSet and rawget(bar.BackgroundEdge, "file") == nil)
    assert(bar.Name.font[1] == ns.Theme.font)
end)

test("dmskin: pooled rows are hooked once, secrets pass untouched", function()
    local row = dmWin.rows[1]
    for _ = 1, 3 do dmWin:InitEntry(row, secretSource()) end
    assert(hookCount[row] == 2, "hooks " .. tostring(hookCount[row]))
    local pooled = newEntry()  -- acquired later from the pool
    dmWin:InitEntry(pooled, secretSource())
    dmWin:InitEntry(pooled, secretSource())
    assert(hookCount[pooled] == 2)
    assert(issecretvalue(pooled.StatusBar.value) and issecretvalue(pooled.StatusBar.max))
    assert(issecretvalue(pooled.StatusBar.Name.text))
end)

test("dmskin: track restyled after Blizzard's UpdateStyle", function()
    local row = dmWin.rows[2]
    row:UpdateStyle()
    local track = row.StatusBar.Background
    assert(track.color and track.color[1] == ns.Theme.color.pitch[1])
end)

test("dmskin: Ember bar colors, class colors respected", function()
    local C, row = ns.Theme.color, newEntry()
    dmWin:InitEntry(row, secretSource())
    local fill = row.StatusBar:GetStatusBarTexture()
    assert(fill.vertex[1] == C.gold[1] and fill.vertex[2] == C.gold[2])
    row.isClassColorDesired = true
    row:UpdateStatusBarColor()
    assert(fill.vertex[1] == WARRIOR.r)
    row:SetStatusBarColor(DAMAGE_METER_STATUS_BAR_ENEMY_COLOR)
    row:SetStatusBarColor(DAMAGE_METER_STATUS_BAR_ENEMY_COLOR)
    assert(fill.vertex[1] == C.neg[1] and fill.vertex[2] == C.neg[2])
end)

test("dmskin: secondary windows and spell rows created later", function()
    DamageMeter:SetupSessionWindow(2, {})
    local win2 = DamageMeterSessionWindow2
    assert(hookCount[win2] == 1 and DMS._hooked[win2.rows[1]])
    DamageMeter:SetupSessionWindow(2, { sessionWindow = win2 })
    assert(hookCount[win2] == 1)
    local spell = newEntry(DamageMeterSpellEntryMixin)
    spell:Init(secretSource())
    assert(DMS._hooked[spell] and hookCount[spell] == 2)
end)

print(("OK %d tests"):format(passed))
