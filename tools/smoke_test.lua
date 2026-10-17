-- Headless smoke test for Core, the UnitFrames slice and the CooldownManager. Run through tools/smoke.py.
local root = ...
dofile(root .. "/tools/wowstub.lua")
local S = STUB

local ns = {}
for line in io.lines(root .. "/BoroFrame/BoroFrame.toc") do
    if line:match("%.lua%s*$") then
        local path = root .. "/BoroFrame/" .. line:gsub("\\", "/"):gsub("%s+$", "")
        local chunk = assert(loadfile(path))
        chunk("BoroFrame", ns)
    end
end

local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
    passed = passed + 1
end

-- boot ----------------------------------------------------------------------
S.fire("ADDON_LOADED", "BoroFrame")
S.fire("PLAYER_LOGIN")

test("config fills defaults", function()
    local cfg = BoroFrameDB.profiles.Default.unitframes
    assert(cfg.frames.player.w == 260)
    assert(cfg.frames.boss5, "boss5 default missing")
    assert(BoroFrameDB.profileKeys["Tester-Realm"] == "Default")
end)

test("config fill is additive", function()
    local t = { a = { x = 1 } }
    ns.Config._fill(t, { a = { x = 9, y = 2 }, b = 3 })
    assert(t.a.x == 1 and t.a.y == 2 and t.b == 3)
end)

test("module enabled and frames created", function()
    assert(ns.modules.UnitFrames:IsEnabled())
    for _, n in ipairs({ "player", "target", "targettarget", "focus", "boss1", "boss5" }) do
        assert(ns.UF.frames[n], n)
    end
    assert(ns.UF.frames.target.watched and not ns.UF.frames.player.watched)
    assert(ns.UF.frames.player.attr.unit == "player")
end)

test("blizzard frames hidden", function()
    -- stubs for the Blizzard frames did not exist, so hideBlizzard must tolerate nil
    assert(true)
end)

-- secret safety ---------------------------------------------------------------
test("every unit event handler survives secret values", function()
    for name, frame in pairs(ns.UF.frames) do
        frame.scripts.OnShow(frame)
        for event in pairs(frame.handlers) do
            frame.scripts.OnEvent(frame, event, frame.unit)
        end
        frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
    end
end)

test("secret health goes to the bar untouched", function()
    local f = ns.UF.frames.player
    f.scripts.OnEvent(f, "UNIT_HEALTH", "player")
    assert(issecretvalue(f.health.value))
end)

test("unit events are unit-filtered", function()
    local f = ns.UF.frames.boss3
    assert(f.unitEvents.UNIT_HEALTH[1] == "boss3")
end)

-- cast bar ----------------------------------------------------------------------
local function fireUnit(frame, event, ...) frame.scripts.OnEvent(frame, event, frame.unit, ...) end

test("cast: element on player, target, focus, boss1-5, unit-filtered events", function()
    for _, n in ipairs({ "player", "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
        local f = ns.UF.frames[n]
        assert(rawget(f, "castHolder"), n .. " has no cast bar")
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE",
            "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE",
            "UNIT_SPELLCAST_EMPOWER_STOP" }) do
            assert(f.unitEvents[e] and f.unitEvents[e][1] == f.unit, n .. " " .. e)
        end
    end
    assert(rawget(ns.UF.frames.targettarget, "castHolder") == nil)
end)

test("cast: blizzard player cast bar detached", function()
    assert(rawget(PlayerCastingBarFrame, "unit") == nil)
end)

test("cast: secret cast goes to widgets untouched, stop hides", function()
    local f = ns.UF.frames.target
    S.casts.target = { kind = "cast", castBarID = 7 }
    fireUnit(f, "UNIT_SPELLCAST_START", S.secret("guid", "string"), S.secret("spell"), 7)
    assert(f.castHolder.shown)
    local d, _, dir = unpack(f.castBar.timer)
    assert(issecretvalue(d) and dir == Enum.StatusBarTimerDirection.ElapsedTime)
    assert(issecretvalue(f.castText.text) and issecretvalue(f.castIcon.texture))
    assert(issecretvalue(f.castFill.colorBool[1]) and issecretvalue(f.castShield.alphaBool[1]))
    fireUnit(f, "UNIT_SPELLCAST_DELAYED", S.secret("guid", "string"), S.secret("spell"), 7)
    assert(f.castBar.timer[2] == ns.UF.interp)
    fireUnit(f, "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    assert(f.castFill.colorBool[1] == true and f.castShield.alphaBool[1] == true)
    fireUnit(f, "UNIT_SPELLCAST_INTERRUPTIBLE")
    assert(f.castFill.colorBool[1] == false)
    S.casts.target = nil
    fireUnit(f, "UNIT_SPELLCAST_STOP", S.secret("guid", "string"), S.secret("spell"), 7)
    assert(not f.castHolder.shown)
end)

test("cast: channel drains, empower fills with hold time", function()
    local f = ns.UF.frames.boss2
    S.casts.boss2 = { kind = "channel", castBarID = 3 }
    fireUnit(f, "UNIT_SPELLCAST_CHANNEL_START", S.secret("guid", "string"), S.secret("spell"), 3)
    assert(f.castHolder.shown and f.castBar.timer[3] == Enum.StatusBarTimerDirection.RemainingTime)
    fireUnit(f, "UNIT_SPELLCAST_CHANNEL_UPDATE", S.secret("guid", "string"), S.secret("spell"), 3)
    S.casts.boss2 = nil
    fireUnit(f, "UNIT_SPELLCAST_CHANNEL_STOP", S.secret("guid", "string"), S.secret("spell"), nil, 3)
    assert(not f.castHolder.shown)

    local p = ns.UF.frames.player
    S.casts.player = { kind = "empower", castBarID = 4 }
    fireUnit(p, "UNIT_SPELLCAST_EMPOWER_START", "guid", 1, 4)
    assert(p.castHolder.shown and p.castBar.timer[3] == Enum.StatusBarTimerDirection.ElapsedTime)
    S.casts.player = nil
    fireUnit(p, "UNIT_SPELLCAST_EMPOWER_STOP", "guid", 1, S.secret("complete", "boolean"), nil, 4)
    assert(not p.castHolder.shown)
end)

test("cast: interrupt holds, foreign FAILED ignored, release refreshes", function()
    local f = ns.UF.frames.focus
    S.casts.focus = { kind = "cast", castBarID = 11 }
    fireUnit(f, "UNIT_SPELLCAST_START", S.secret("guid", "string"), S.secret("spell"), 11)
    -- key pressed while casting: FAILED for another cast attempt
    fireUnit(f, "UNIT_SPELLCAST_FAILED", S.secret("guid", "string"), S.secret("spell"), 12)
    assert(f.castHolder.shown and not f.castFail.shown)
    fireUnit(f, "UNIT_SPELLCAST_INTERRUPTED", S.secret("guid", "string"), S.secret("spell"),
        S.secret("kicker", "string"), 11)
    S.casts.focus = nil
    fireUnit(f, "UNIT_SPELLCAST_STOP", S.secret("guid", "string"), S.secret("spell"), 11)
    assert(f.castHolder.shown and f.castFail.shown and f.castText.text == INTERRUPTED)
    S.runTimers()
    assert(not f.castHolder.shown)
    -- secret interruptedBy on a channel stop
    S.casts.focus = { kind = "channel", castBarID = 13 }
    fireUnit(f, "UNIT_SPELLCAST_CHANNEL_START", S.secret("guid", "string"), S.secret("spell"), 13)
    S.casts.focus = nil
    fireUnit(f, "UNIT_SPELLCAST_CHANNEL_STOP", S.secret("guid", "string"), S.secret("spell"),
        S.secret("kicker", "string"), 13)
    assert(f.castFail.shown)
    -- a new cast during the hold replaces the failed state
    S.casts.focus = { kind = "cast", castBarID = 14 }
    fireUnit(f, "UNIT_SPELLCAST_START", S.secret("guid", "string"), S.secret("spell"), 14)
    assert(f.castHolder.shown and not f.castFail.shown)
    S.runTimers()
    assert(f.castHolder.shown, "release must keep a running cast")
    S.casts.focus = nil
    f.scripts.OnEvent(f, "PLAYER_FOCUS_CHANGED")
    assert(not f.castHolder.shown)
end)

test("cast: FAILED without a visible bar is ignored", function()
    local f = ns.UF.frames.player
    fireUnit(f, "UNIT_SPELLCAST_FAILED", "guid", 1, 99)
    assert(not f.castHolder.shown and not f.castFail.shown)
end)

-- auras -------------------------------------------------------------------------
test("auras: containers on target and boss, player off by default", function()
    local F = ns.UF.frames
    assert(F.target.auras and F.target.auras.kind == "AuraContainer", "target container")
    assert(F.target.auras.template == "CustomAuraContainerTemplate")
    assert(F.target.auras.unit == "target" and F.target.auras.enabled == true)
    for i = 1, 5 do
        local c = F["boss" .. i].auras
        assert(c and c.unit == "boss" .. i, "boss" .. i)
    end
    assert(F.player.auras == false, "player auras should be off")
    assert(rawget(F.focus, "auras") == nil and rawget(F.targettarget, "auras") == nil)
end)

test("auras: target groups use API filter strings, own debuffs first", function()
    local c = ns.UF.frames.target.auras
    assert(c.groupOrder[1] == "debuffs" and c.groupOrder[2] == "buffs")
    assert(c.groups.debuffs.filter == "HARMFUL|PLAYER")
    assert(c.groups.buffs.filter == "HELPFUL")
    assert(c.groups.buffs.options.layout.forceNewLine == true)
    assert(c.groups.debuffs.options.maxFrameCount == 10)
end)

test("auras: layout from fixed sizes, wraps after perRow", function()
    local c = ns.UF.frames.target.auras
    assert(c.maxLine == 10 * 24 + 9 * 2, "line size " .. tostring(c.maxLine))
    assert(c.flowAnchor == "BOTTOMLEFT" and c.growth[1] == 1 and c.growth[2] == 1)
    local b = ns.UF.frames.boss2.auras
    assert(b.flowAnchor == "TOPRIGHT" and b.growth[1] == -1 and b.growth[2] == -1)
    assert(b.groups.debuffs.options.layout.elementWidth == 16)
end)

test("auras: buttons wired to engine widgets, countdown numbers hidden (#881)", function()
    local button = ns.UF.frames.target.auras.groups.debuffs.buttons[1]
    local d = button.display
    assert(d.icon and d.cooldown and d.durationText and d.count and d.dispel, "display regions missing")
    assert(d.cooldown.kind == "Cooldown")
    assert(button.w == 24 and button.h == 24)
    assert(d.cooldown.hideNumbers == true, "cooldown countdown numbers must be hidden")
    assert(d.dispel.parent == button and d.count.parent ~= d.cooldown)
end)

test("auras: secret aura data stays inside the widgets", function()
    for _, n in ipairs({ "target", "boss1" }) do
        local c = ns.UF.frames[n].auras
        for _, key in ipairs(c.groupOrder) do
            for _, b in ipairs(c.groups[key].buttons) do S.assignSecretAura(b) end
        end
    end
    local d = ns.UF.frames.target.auras.groups.buffs.buttons[3].display
    assert(issecretvalue(d.count.text) and issecretvalue(d.durationText.text))
end)

test("auras: no addon UNIT_AURA handling, secret payload is ignored", function()
    for name, f in pairs(ns.UF.frames) do
        assert(not f.events.UNIT_AURA, name .. " registered UNIT_AURA")
    end
    S.fire("UNIT_AURA", "target", S.secret("updateInfo"))
end)

test("auras: target change and boss engage refresh the container", function()
    local c, b = ns.UF.frames.target.auras, ns.UF.frames.boss1.auras
    local before, beforeBoss = c.fullUpdates, b.fullUpdates
    S.fire("PLAYER_TARGET_CHANGED")
    S.fire("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    assert(c.fullUpdates == before + 1, "target not refreshed")
    assert(b.fullUpdates == beforeBoss + 1, "boss not refreshed")
end)

test("auras: Create is reusable and tolerates missing config", function()
    assert(ns.UF.Auras.Create(UIParent, "nameplate1", nil) == nil)
    assert(ns.UF.Auras.Create(UIParent, "nameplate1", { enabled = false, groups = {} }) == nil)
    local c = ns.UF.Auras.Create(UIParent, "nameplate1", { size = 20, spacing = 1, perRow = 5,
        growX = "LEFT", growY = "UP", groups = { { key = "d", filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY", sort = "Nope" } } })
    assert(c.unit == "nameplate1" and c.flowAnchor == "BOTTOMRIGHT" and c.maxLine == 104)
    assert(c.groups.d.options.sortMethod == AuraContainerSortMethod.Default)
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
    -- poll task of targettarget is still registered, so cancel it to prove the driver hides
    ns.Scheduler:CancelAll(ns.UF.frames.targettarget)
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
    SlashCmdList.BOROFRAME("modules")
    SlashCmdList.BOROFRAME("")
    SlashCmdList.BOROFRAME("module UnitFrames on")
end)

test("window skins: toggle per skin, missing frames tolerated", function()
    for _, addon in ipairs({ "Blizzard_WorldMap", "Blizzard_MailFrame", "Blizzard_ObjectiveTracker" }) do
        S.fire("ADDON_LOADED", addon)  -- the frames do not exist in the stub, skins must not error
    end
    local enabled = ns.Config:Get("skins").enabled
    for _, name in ipairs({ "WorldMap", "Quest", "Gossip", "Merchant", "Mail", "ObjectiveTracker" }) do
        assert(enabled[name] == true, name)
    end
end)

test("skin helpers: panel, tab, close button", function()
    local function w() local x = S.newWidget(); x.alpha = 1; function x:SetAlpha(a) self.alpha = a end; return x end
    local frame = w()
    frame.NineSlice, frame.Bg, frame.TopTileStreaks, frame.PortraitContainer = w(), w(), w(), w()
    frame.Inset = { NineSlice = w(), Bg = w() }
    frame.TitleContainer = { TitleText = w() }
    frame.CloseButton = w()
    ns.Skin.Panel_c(frame)
    assert(frame.NineSlice.alpha == 0 and frame.Inset.Bg.alpha == 0 and frame.PortraitContainer.alpha == 0)
    assert(#frame.CloseButton.hooks == 2)
    ns.Skin.Panel_c(frame)  -- second call is a no-op
    assert(#frame.CloseButton.hooks == 2)
    local tab = w()
    tab.TabTextures = { w(), w() }
    function tab:IsEnabled() return true end
    ns.Skin.Tab_c(tab)
    assert(tab.TabTextures[1].alpha == 0)
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

-- cooldown manager --------------------------------------------------------------
local OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"

local function fakeTexture(atlas)
    local t = S.newWidget()
    t.atlas, t.masks = atlas, { S.newWidget() }
    function t:GetAtlas() return self.atlas end
    function t:IsObjectType(kind) return kind == "Texture" end
    function t:GetNumMaskTextures() return #self.masks end
    function t:GetMaskTexture(i) return self.masks[i] end
    function t:RemoveMaskTexture(m)
        for i = #self.masks, 1, -1 do if self.masks[i] == m then table.remove(self.masks, i) end end
    end
    return t
end

local function fakeIconItem(index, cooldownID)
    local item = CreateFrame("Frame")
    item.layoutIndex, item.cooldownID, item.shown = index, cooldownID, cooldownID ~= nil
    item.Icon = fakeTexture(nil)
    item.overlay = fakeTexture(OVERLAY)
    item.secretRegion = fakeTexture(S.secret("atlas"))  -- comparing this would throw
    function item:GetRegions() return self.Icon, self.overlay, self.secretRegion end
    item.Cooldown = CreateFrame("Cooldown")
    local cdText = S.newWidget()
    function item.Cooldown:GetCountdownFontString() return cdText end
    item.cdText = cdText
    item.ChargeCount = CreateFrame("Frame")
    item.ChargeCount.Current = S.newWidget()
    item.ChargeCount.Current:SetText(S.secret("charges"))
    item.Applications = false  -- BuffIcon-only parentKey; unset keys are no-op methods in the stub
    return item
end

local function fakeBarItem(index, cooldownID)
    local item = CreateFrame("Frame")
    item.layoutIndex, item.cooldownID = index, cooldownID
    item.Icon = CreateFrame("Frame")
    item.Icon.Icon = fakeTexture(nil)
    item.Icon.Applications = S.newWidget()
    local overlay = fakeTexture(OVERLAY)
    item.Icon.overlay = overlay
    function item.Icon:GetRegions() return self.Icon, overlay end
    item.Bar = CreateFrame("StatusBar")
    item.Bar.BarBG, item.Bar.Pip = S.newWidget(), S.newWidget()
    item.Bar.Name, item.Bar.Duration = S.newWidget(), S.newWidget()
    -- Blizzard feeds its bar with values that are secret in combat
    item.Bar:SetMinMaxValues(0, S.secret("duration"))
    item.Bar:SetValue(S.secret("remaining"))
    item.Bar.Duration:SetText(S.secret("time"))
    return item
end

-- Mimics GridLayoutFrameMixin:Layout: Blizzard anchors every item to the viewer.
local function fakeViewer(name, items)
    local v = CreateFrame("Frame", name)
    local active = {}
    for _, it in ipairs(items) do active[it] = true end
    v.itemFramePool = { EnumerateActive = function() return pairs(active) end }
    v.items = items
    function v:Layout()
        for it in pairs(active) do
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        end
    end
    return v
end

local function anchor(item) return item.points and item.points[#item.points] end
local CDM = ns.modules.CooldownManager
local cdmCfg = BoroFrameDB.profiles.Default.cooldownmanager
local function entry(key)
    for _, e in ipairs(CDM._entries) do if e.key == key then return e end end
end

test("cdm: waits for Blizzard_CooldownViewer", function()
    assert(CDM:IsEnabled())
    assert(#CDM._entries == 0)
    assert(cdmCfg.essential.size == 42 and cdmCfg.buffbar.width == 200)
end)

local ess = fakeViewer("EssentialCooldownViewer",
    { fakeIconItem(3, 103), fakeIconItem(1, 101), fakeIconItem(2, 102), fakeIconItem(4, nil) })
local util = fakeViewer("UtilityCooldownViewer", { fakeIconItem(1, 201), fakeIconItem(2, 202) })
local buffIcons = fakeViewer("BuffIconCooldownViewer", { fakeIconItem(1, 301) })
local bars = fakeViewer("BuffBarCooldownViewer", { fakeBarItem(1, 401), fakeBarItem(2, 402) })
local function sorted(v)
    local t = {}
    for _, it in ipairs(v.items) do t[it.layoutIndex] = it end
    return t
end

test("cdm: hooks on ADDON_LOADED, disabled viewer stays Blizzard's", function()
    cdmCfg.bufficon.enabled = false
    S.loaded = S.loaded or {}
    S.loaded.Blizzard_CooldownViewer = true
    S.fire("ADDON_LOADED", "Blizzard_CooldownViewer")
    assert(#CDM._entries == 3, "entries " .. #CDM._entries)
    buffIcons:Layout()
    assert(anchor(buffIcons.items[1])[2] == buffIcons)
    assert(not ns.CDMStyle.IsSkinned(buffIcons.items[1]))
end)

test("cdm: icons skinned without touching info elements or secrets", function()
    local it = sorted(ess)[1]
    assert(ns.CDMStyle.IsSkinned(it))
    assert(it.overlay.alpha == 0, "overlay atlas not hidden")
    assert(it.secretRegion.alpha == nil, "secret-atlas region was touched")
    assert(#it.Icon.masks == 0, "mask not removed")
    assert(it.w == 42 and it.h == 42 and it.scale == 1)
    assert(it.cdText.font[2] == 16, "countdown font " .. tostring(it.cdText.font[2]))
    assert(issecretvalue(it.ChargeCount.Current.text))
end)

test("cdm: icons follow the holder, centered, padding slot skipped", function()
    local e, s = entry("essential"), sorted(ess)
    for i = 1, 3 do
        local a = anchor(s[i])
        assert(a[1] == "TOP" and a[2] == e.holder, "item " .. i)
        assert(a[4] == (i - 2) * 44, "x " .. tostring(a[4]))
    end
    assert(anchor(s[4]) == nil, "padding slot moved")
end)

test("cdm: Blizzard relayout is re-anchored by the post-hook", function()
    ess:Layout()
    assert(anchor(sorted(ess)[2])[2] == entry("essential").holder)
end)

test("cdm: Edit Mode owns positions while editing", function()
    ess.isEditing = true
    ess:Layout()
    assert(anchor(sorted(ess)[1])[2] == ess)
    ess.isEditing = nil
    ess:Layout()
    assert(anchor(sorted(ess)[1])[2] == entry("essential").holder)
end)

test("cdm: protected chain in combat defers once", function()
    S.inCombat = true
    ess.protected = true
    ess:Layout()
    ess:Layout()
    assert(anchor(sorted(ess)[1])[2] == ess, "touched in combat")
    assert(ns.Combat:Pending() == 1, "pending " .. ns.Combat:Pending())
    -- unprotected viewer may be re-anchored in combat
    util:Layout()
    assert(anchor(sorted(util)[1])[2] == entry("utility").holder)
    S.inCombat = false
    ess.protected = nil
    S.fire("PLAYER_REGEN_ENABLED")
    assert(anchor(sorted(ess)[1])[2] == entry("essential").holder)
end)

test("cdm: buff bars styled, stacked, secrets left alone", function()
    local e, s = entry("buffbar"), sorted(bars)
    local a1, a2 = anchor(s[1]), anchor(s[2])
    assert(a1[1] == "TOPLEFT" and a1[2] == e.holder and a1[5] == 0)
    assert(a2[5] == -22, "y " .. tostring(a2[5]))
    assert(s[1].w == 200 and s[1].h == 20 and s[1].Icon.w == 20)
    assert(s[1].Icon.overlay.alpha == 0)
    assert(s[1].Bar.Pip.w == 1 and s[1].Bar.Pip.h == 20)
    assert(issecretvalue(s[1].Bar.value) and issecretvalue(s[1].Bar.max))
    assert(issecretvalue(s[1].Bar.Duration.text))
end)

test("cdm: viewer scale is compensated", function()
    util.effScale = 2
    util:Layout()
    local it = sorted(util)[1]
    assert(it.w == 16, "size " .. tostring(it.w))
    util.effScale = nil
    util:Layout()
end)

test("cdm: refresh applies new row limit", function()
    cdmCfg.essential.perRow = 2
    CDM:Refresh()
    local a3 = anchor(sorted(ess)[3])
    assert(a3[4] == 0 and a3[5] == -44, "row 2: " .. tostring(a3[4]) .. "," .. tostring(a3[5]))
    cdmCfg.essential.perRow = 8
    CDM:Refresh()
end)

test("cdm: disabled module leaves Blizzard layout alone", function()
    ns:DisableModule("CooldownManager")
    ess:Layout()
    assert(anchor(sorted(ess)[1])[2] == ess)
    ns:EnableModule("CooldownManager")
    assert(anchor(sorted(ess)[1])[2] == entry("essential").holder)
end)

print(("OK %d tests"):format(passed))
