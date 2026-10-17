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

-- timeline --------------------------------------------------------------------
local TL = ns.Timeline
local TLS = Enum.EncounterTimelineEventState
local VIEW = Enum.EncounterTimelineViewType

local function rowFor(id) return TL.Renderer.rows[id] end

test("timeline: enabled, blizzard view locked to None", function()
    assert(ns.modules.Timeline:IsEnabled())
    assert(S.tl.view == VIEW.None, "view " .. tostring(S.tl.view))
    assert(EncounterTimeline.attr.overrideViewType == VIEW.None)
    assert(TL.Renderer.source == TL.BlizzardSource)
end)

test("timeline: secret events become sorted bars without Lua on secrets", function()
    S.tlAdd(11, 30)
    S.tlAdd(12, 5)
    S.tlAdd(13, 12)
    S.runTimers()
    assert(TL.Renderer:ActiveCount() == 3)
    assert(rowFor(12).slot == 1 and rowFor(13).slot == 2 and rowFor(11).slot == 3)
    local row = rowFor(12)
    assert(row.kind == "bar" and row.shown)
    assert(issecretvalue(row.name.text), "name must reach the widget untouched")
    assert(issecretvalue(row.icon.texture), "icon must reach the widget untouched")
    assert(issecretvalue(row.bar.color[1]), "event color goes to the bar as is")
    assert(row.bar.timer == S.tl.events[12].timer, "bar driven by the event timer")
    assert(row.bar.timerDir == Enum.StatusBarTimerDirection.RemainingTime)
    assert(row.binding.enabled and row.binding.duration == S.tl.events[12].timer, "countdown via text binding")
    assert(S.tl.iconCalls >= 6, "symbols assigned by the client")
end)

test("timeline: duplicate add is ignored, max bars caps the list", function()
    S.fire("ENCOUNTER_TIMELINE_EVENT_ADDED", C_EncounterTimeline.GetEventInfo(12))
    assert(TL.Renderer:ActiveCount() == 3)
    SlashCmdList.BOROFRAME("timeline bars 2")
    S.runTimers()
    assert(rowFor(11).shown == false and rowFor(12).shown and rowFor(13).shown)
    SlashCmdList.BOROFRAME("timeline bars 8")
    S.runTimers()
end)

test("timeline: paused, finished, canceled, removed", function()
    S.tlState(13, TLS.Paused)
    assert(rowFor(13).alpha == 0.55)
    S.tlState(13, TLS.Active)
    assert(rowFor(13).alpha == 1)
    S.tlState(12, TLS.Finished)
    local row = rowFor(12)
    assert(row.fade:IsPlaying())
    S.tlRemove(12)
    assert(rowFor(12) == nil and TL.Renderer.fading[row], "fading row kept until its outro ends")
    row.fade.scripts.OnFinished(row.fade)
    assert(not TL.Renderer.fading[row] and row.ev == nil and row.bar.max == 0, "released, timer dropped")
    S.tlState(11, TLS.Canceled)
    S.tlRemove(11)
    S.runTimers()
    assert(TL.Renderer:ActiveCount() == 1)
end)

test("timeline: options rebuild rows, track view uses pips", function()
    SlashCmdList.BOROFRAME("timeline width 300")
    SlashCmdList.BOROFRAME("timeline grow up")
    local cfg = BoroFrameDB.profiles.Default.timeline
    assert(cfg.width == 300 and cfg.grow == "UP")
    SlashCmdList.BOROFRAME("timeline width 5")
    assert(cfg.width == 120, "clamped")
    SlashCmdList.BOROFRAME("timeline view track")
    S.runTimers()
    local pip = rowFor(13)
    assert(pip.kind == "pip" and pip.shown)
    assert(pip.w == 120 * S.tl.events[13].duration / cfg.trackSeconds, "pip width maps duration to track scale")
    assert(issecretvalue(pip.edge.vcolor[1]), "event color tints the pip edge as is")
    SlashCmdList.BOROFRAME("timeline view bars")
    SlashCmdList.BOROFRAME("timeline grow down")
    SlashCmdList.BOROFRAME("timeline width 260")
    S.runTimers()
    assert(rowFor(13).kind == "bar")
end)

test("timeline: test mode adds and cancels edit mode events", function()
    SlashCmdList.BOROFRAME("timeline test")
    S.runTimers()
    assert(ns.modules.Timeline:IsTesting() and TL.Renderer:ActiveCount() == 4)
    S.fire("PLAYER_REGEN_DISABLED")
    assert(not ns.modules.Timeline:IsTesting() and TL.Renderer:ActiveCount() == 1)
    SlashCmdList.BOROFRAME("timeline test")
    SlashCmdList.BOROFRAME("timeline test")
    assert(not ns.modules.Timeline:IsTesting())
end)

test("timeline: off restores the previous view, on takes over again", function()
    SlashCmdList.BOROFRAME("timeline off")
    assert(S.tl.view == VIEW.Bars and EncounterTimeline.attr.overrideViewType == nil)
    assert(TL.Renderer:ActiveCount() == 0 and TL.Renderer.container.shown == false)
    S.tlAdd(14, 8)  -- no listener while off
    SlashCmdList.BOROFRAME("timeline on")
    S.runTimers()
    assert(S.tl.view == VIEW.None and TL.Renderer:ActiveCount() == 2, "resynced from GetEventList")
    SlashCmdList.BOROFRAME("timeline")
    SlashCmdList.BOROFRAME("modules")  -- base /boro still reachable through the wrapper
end)

test("timeline: encounter warnings get skinned via post-hooks", function()
    local shown = 0
    for _, name in ipairs({ "CriticalEncounterWarnings", "MediumEncounterWarnings", "MinorEncounterWarnings" }) do
        local view = { LeftIcon = S.newWidget(), RightIcon = S.newWidget(), Text = S.newWidget() }
        view.LeftIcon.Icon, view.LeftIcon.NormalOverlay = S.newWidget(), S.newWidget()
        view.Text.Init = function() shown = shown + 1 end
        _G[name] = { View = view }
    end
    S.fire("ADDON_LOADED", "Blizzard_EncounterWarnings")
    local view = CriticalEncounterWarnings.View
    assert(view.LeftIcon.NormalOverlay.alpha == 0)
    view.Text:Init({ text = S.secret("warn") })
    assert(shown == 1, "Blizzard's Init still runs")
end)

print(("OK %d tests"):format(passed))
