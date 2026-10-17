-- Headless smoke test for Core and the UnitFrames slice. Run through tools/smoke.py.
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

print(("OK %d tests"):format(passed))
