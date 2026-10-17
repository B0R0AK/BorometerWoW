local _, ns = ...

-- Boss timeline: our renderer replaces Blizzard's display, the data stays Blizzard's.
-- While enabled, the client view type is locked to None (the mode the API documents
-- for addons that take over the display); the previous view is restored on disable.
local TL = ns.Timeline
local M = ns:NewModule("Timeline")

ns.Config:Register("timeline", {
    width = 260,
    barHeight = 20,
    maxBars = 8,
    grow = "DOWN",          -- DOWN | UP
    view = "bars",          -- bars | track
    trackSeconds = 30,
    pos = { "CENTER", 360, 120 },
})

local CET = C_EncounterTimeline
local VIEW = Enum.EncounterTimelineViewType or { None = 0, Timeline = 1, Bars = 2 }

local previousView
local moverDone = false

-- Blizzard reads this attribute before applying its edit mode view type, so the
-- lock survives edit mode changes. EncounterTimeline is not secure, but it is
-- Blizzard UI, so changes go through the combat queue to stay clear of lockdown.
local function lockView()
    if not M:IsEnabled() then return end
    if previousView == nil then
        local current = CET.GetViewType and CET.GetViewType()
        previousView = current ~= VIEW.None and current or VIEW.Bars
    end
    if EncounterTimeline then EncounterTimeline:SetAttribute("overrideViewType", VIEW.None) end
    CET.SetViewType(VIEW.None)
end

local function unlockView()
    if M:IsEnabled() then return end
    if EncounterTimeline then EncounterTimeline:SetAttribute("overrideViewType", nil) end
    if previousView ~= nil then
        CET.SetViewType(previousView)
        previousView = nil
    end
end

-- Test mode ---------------------------------------------------------------------
-- Edit mode events are client-side dummies that loop; the loop length comes from the API.
local testing, testTimer = false, nil

local function queueTest()
    if not testing then return end
    local loop = CET.AddEditModeEvents()
    if type(loop) == "number" and loop > 0 then testTimer = C_Timer.NewTimer(loop, queueTest) end
end

local function stopTest()
    if not testing then return end
    testing = false
    if testTimer then testTimer:Cancel() end
    testTimer = nil
    CET.CancelEditModeEvents()
end

local function startTest()
    if testing then return end
    if InCombatLockdown() then
        ns.Debug.Print("Timeline: Test im Kampf nicht möglich.")
        return
    end
    testing = true
    queueTest()
end

function M:IsTesting()
    return testing
end

-- Lifecycle -------------------------------------------------------------------
function M:OnEnable()
    if not (CET and CET.SetViewType and CET.GetSortedEventList) then
        ns.Debug.Print("Timeline: C_EncounterTimeline fehlt, Modul inaktiv.")
        return
    end
    local cfg = ns.Config:Get("timeline")
    TL.Renderer:Configure(cfg)
    if not moverDone then
        moverDone = true
        ns.Mover:Register(TL.Renderer.container, "timeline", { cfg.pos[1], cfg.pos[1], cfg.pos[2], cfg.pos[3] })
    end
    TL.Renderer:Attach(TL.BlizzardSource)
    ns.Combat:Defer(lockView)
    ns.Events:Register("PLAYER_REGEN_DISABLED", M, stopTest)
    -- If Blizzard's timeline addon loads after us, apply the lock once it exists.
    ns.Events:Register("ADDON_LOADED", M, function(_, _, addon)
        if addon == "Blizzard_EncounterTimeline" then ns.Combat:Defer(lockView) end
    end)
end

function M:OnDisable()
    if not CET then return end
    stopTest()
    ns.Events:UnregisterAll(M)
    TL.Renderer:Detach()
    ns.Combat:Defer(unlockView)
end

-- Options and slash -------------------------------------------------------------
local LIMITS = {
    width = { 120, 800 }, height = { 10, 48 }, bars = { 1, 20 }, seconds = { 5, 120 },
}
local KEYS = { width = "width", height = "barHeight", bars = "maxBars", seconds = "trackSeconds" }

local help = {
    "/boro timeline on|off - Boss-Timeline an/aus",
    "/boro timeline test - Testbalken an/aus (Edit-Mode-Ereignisse)",
    "/boro timeline view bars|track - Balkenliste oder lineare Spur",
    "/boro timeline grow down|up - Richtung der Balkenliste",
    "/boro timeline width|height|bars|seconds <Zahl> - Größe, Anzahl, Spurlänge",
}

local function refresh()
    if M:IsEnabled() and TL.Renderer.container then TL.Renderer:Configure(ns.Config:Get("timeline")) end
end

function M:HandleSlash(a, b)
    a = (a or ""):lower()
    b = (b or ""):lower()
    local cfg = ns.Config:Get("timeline")
    if a == "on" or a == "off" then
        ns.Config:SetModuleEnabled("Timeline", a == "on")
    elseif a == "test" then
        if testing then
            stopTest()
        elseif M:IsEnabled() then
            startTest()
        else
            ns.Debug.Print("Timeline ist aus: /boro timeline on")
        end
    elseif a == "view" and (b == "bars" or b == "track") then
        cfg.view = b
        refresh()
    elseif a == "grow" and (b == "down" or b == "up") then
        cfg.grow = b:upper()
        refresh()
    elseif KEYS[a] and tonumber(b) then
        local lim = LIMITS[a]
        local v = math.floor(tonumber(b))
        if v < lim[1] then v = lim[1] elseif v > lim[2] then v = lim[2] end
        cfg[KEYS[a]] = v
        refresh()
    else
        for _, line in ipairs(help) do ns.Debug.Print(line) end
    end
end

-- Core's /boro has no extension point yet; wrap it and pass everything else through.
local baseSlash = SlashCmdList.BOROFRAME
SlashCmdList.BOROFRAME = function(msg)
    local cmd, a, b = strsplit(" ", strtrim(msg or ""))
    if (cmd or ""):lower() == "timeline" then
        M:HandleSlash(a, b)
    elseif baseSlash then
        baseSlash(msg)
    end
end
