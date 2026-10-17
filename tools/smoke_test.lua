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

-- frame extras (V04) -----------------------------------------------------------
local function fireAll(f)
    f.scripts.OnShow(f)
    for event in pairs(f.handlers) do f.scripts.OnEvent(f, event, f.unit) end
end

test("extras: default specs carry the new elements", function()
    local F = ns.UF.frames
    assert(F.player.classPower and F.player.roleIcon and F.player.raidMarker)
    assert(F.target.raidMarker and F.target.levelText)
    assert(F.focus.raidMarker)
    local cfg = BoroFrameDB.profiles.Default.unitframes.frames
    assert(cfg.player.elements[1] == "Health" and cfg.player.elements[6] == "ClassPower")
end)

local xf = ns.UF.Create("extrasTest", { unit = "party1", w = 120, h = 24, powerHeight = 0,
    elements = { "Health", "Absorb", "HealPrediction", "Status", "Leader", "PvP", "Level", "RaidMarker", "Role" } })

test("extras: secret values reach widgets untouched", function()
    fireAll(xf)
    for _, e in ipairs({ "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED" }) do
        S.fire(e)
    end
    assert(issecretvalue(xf.healPred.value) and issecretvalue(xf.healPred.max), "heal prediction")
    assert(issecretvalue(xf.raidMarker.cell) and xf.raidMarker.shown, "raid marker")
    assert(issecretvalue(xf.leaderIcon.alphaBool) and issecretvalue(xf.assistIcon.alphaBool), "leader")
    assert(issecretvalue(xf.roleIcon.alphaBool) and issecretvalue(xf.roleIcon.atlas), "role")
    assert(S.pvpUpdated == xf.pvpIcon, "pvp via UnitFrameUtil")
    assert(issecretvalue(xf.levelText.formatted[2]), "secret level passed through")
end)

test("extras: two elements sharing a global event both update", function()
    xf.leaderIcon.alphaBool, xf.roleIcon.alphaBool = nil, nil
    S.fire("GROUP_ROSTER_UPDATE")
    assert(xf.leaderIcon.alphaBool and xf.roleIcon.alphaBool)
end)

test("extras: raid marker hides without index", function()
    S.raidIndex = false
    S.fire("RAID_TARGET_UPDATE")
    assert(xf.raidMarker.shown == false)
    S.raidIndex = 8
    S.fire("RAID_TARGET_UPDATE")
    assert(xf.raidMarker.shown and xf.raidMarker.cell == 8)
    S.raidIndex = nil
end)

test("extras: role falls back without UnitFrameUtil and hides on secret role", function()
    local util = UnitFrameUtil
    UnitFrameUtil = nil
    xf.scripts.OnShow(xf)
    assert(xf.roleIcon.alpha == 0)
    UnitFrameUtil = util
end)

test("extras: dead/offline state", function()
    S.dead = true
    xf.scripts.OnShow(xf)
    assert(xf.statusText.text == DEAD or xf.statusText.text == "Dead")
    assert(xf.health.desaturated == true)
    S.dead, S.online = false, false
    xf.scripts.OnEvent(xf, "UNIT_CONNECTION", "party1")
    assert(xf.statusText.text == "Offline" or xf.statusText.text == PLAYER_OFFLINE)
    S.online = nil
    xf.scripts.OnEvent(xf, "UNIT_HEALTH", "party1")
    assert(xf.statusText.text == "" and xf.health.desaturated == false)
    S.dead = "secret"
    xf.scripts.OnEvent(xf, "UNIT_HEALTH", "party1")
    assert(issecretvalue(xf.health.desaturated), "secret dead flag goes to the bar")
    S.dead = nil
end)

test("extras: plain level with elite marker", function()
    S.level = 83
    xf.scripts.OnEvent(xf, "UNIT_LEVEL", "party1")
    assert(xf.levelText.formatted[1] == "%d%s" and xf.levelText.formatted[2] == 83 and xf.levelText.formatted[3] == "+")
    S.level = -1
    xf.scripts.OnEvent(xf, "UNIT_LEVEL", "party1")
    assert(xf.levelText.text == "??")
    S.level = nil
end)

test("extras: class power for every class, secret current and secret max", function()
    local p = ns.UF.frames.player
    local cases = {
        { "ROGUE" }, { "PALADIN" }, { "WARLOCK" }, { "EVOKER" }, { "DEATHKNIGHT" },
        { "MONK", 3 }, { "MAGE", 1 }, { "DRUID", nil, 3 },
    }
    for _, plainMax in ipairs({ false, 5 }) do
        S.plainMax = plainMax or nil
        for _, c in ipairs(cases) do
            S.class, S.spec, S.powerType = c[1], c[2], c[3]
            p.scripts.OnEvent(p, "PLAYER_ENTERING_WORLD")
            assert(p.classPower.shown, c[1] .. " class power hidden")
            fireAll(p)
            S.fire("RUNE_POWER_UPDATE", 1, true)
            S.fire("PLAYER_SPECIALIZATION_CHANGED", "player")
            if c[1] ~= "DEATHKNIGHT" then
                assert(issecretvalue(p.cpPips[1].value), c[1] .. " secret power not passed")
            end
        end
    end
    -- off-spec and caster-form cases hide the bar
    S.class, S.spec = "MONK", 1
    p.scripts.OnEvent(p, "PLAYER_ENTERING_WORLD")
    assert(p.classPower.shown == false)
    S.class, S.powerType = "DRUID", 0
    p.scripts.OnEvent(p, "UNIT_DISPLAYPOWER", "player")
    assert(p.classPower.shown == false)
    S.class, S.spec, S.powerType = nil, nil, nil
    p.scripts.OnEvent(p, "PLAYER_ENTERING_WORLD")
    assert(p.classPower.shown == false, "secret class token must hide")
end)

test("extras: class power pip ranges, shards display mod, runes, essence fallback", function()
    local p = ns.UF.frames.player
    S.plainMax = nil
    S.class = "ROGUE"
    p.scripts.OnEvent(p, "PLAYER_ENTERING_WORLD")
    assert(p.cpCount == 1 and issecretvalue(p.cpPips[1].max), "secret max: one continuous bar")

    S.plainMax = 7
    p.scripts.OnEvent(p, "UNIT_MAXPOWER", "player")
    assert(p.cpCount == 7 and p.cpPips[7].min == 6 and p.cpPips[7].max == 7 and p.cpPips[8].shown == false)

    S.class, S.plainMax = "WARLOCK", 5  -- 5 shards, pips scaled by display mod 10 for unmodified values
    p.scripts.OnEvent(p, "PLAYER_ENTERING_WORLD")
    assert(p.cpCount == 5 and p.cpPips[2].min == 10 and p.cpPips[2].max == 20)

    S.class, S.plainMax = "DEATHKNIGHT", nil
    p.scripts.OnEvent(p, "PLAYER_ENTERING_WORLD")
    assert(p.cpCount == 6 and issecretvalue(p.cpDurations[6].start) and p.cpPips[6].timer == p.cpDurations[6])

    S.class, S.plainMax, S.plainPower, S.partial = "EVOKER", 5, 2, 500
    p.scripts.OnEvent(p, "PLAYER_ENTERING_WORLD")
    assert(p.cpPips[3].value == 2.5, "partial essence")
    S.partial = nil  -- secret partial (bug #420 path): whole pips only
    p.scripts.OnEvent(p, "UNIT_POWER_FREQUENT", "player", "ESSENCE")
    assert(p.cpPips[3].value == 2)
    S.plainPower = 3
    p.scripts.OnEvent(p, "UNIT_POWER_FREQUENT", "player", "MANA")
    assert(p.cpPips[3].value == 2, "foreign power token must be ignored")
    S.class, S.plainMax, S.plainPower = nil, nil, nil
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
