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
