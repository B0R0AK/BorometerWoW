local _, ns = ...

-- Class power for the player frame: combo points, holy power, soul shards, chi, arcane charges,
-- essence, runes. Element contract as in Elements.lua.
local UF = ns.UF
local Theme = ns.Theme
local IsSecret = ns.IsSecret

local UnitPower, UnitPowerMax, UnitPartialPower = UnitPower, UnitPowerMax, UnitPartialPower
local GetRuneCooldown = GetRuneCooldown

local MAX_PIPS = 10
local RUNES = 6

-- Every pip is a StatusBar with range (i-1, i] scaled by the display mod, and all pips get the same
-- value. The engine clamps, so a pip is empty, partial or full without Lua ever comparing the current
-- amount. That keeps it correct if UnitPower turns secret. Runes use one duration object each and
-- SetTimerDuration, so the engine animates the refill.
local PT = Enum.PowerType
-- spec: only that specialization index uses the resource. needsPower: only while that is the primary
-- power (druid cat form). unmodified: fractional values (destruction shards) scaled by UnitPowerDisplayMod.
local classPower = {
    ROGUE = { type = PT.ComboPoints, token = "COMBO_POINTS" },
    DRUID = { type = PT.ComboPoints, token = "COMBO_POINTS", needsPower = PT.Energy },
    PALADIN = { type = PT.HolyPower, token = "HOLY_POWER" },
    WARLOCK = { type = PT.SoulShards, token = "SOUL_SHARDS", unmodified = true },
    MONK = { type = PT.Chi, token = "CHI", spec = 3 },
    MAGE = { type = PT.ArcaneCharges, token = "ARCANE_CHARGES", spec = 1 },
    EVOKER = { type = PT.Essence, token = "ESSENCE", partial = true },
    DEATHKNIGHT = { runes = true },
}

local function powerInfo()
    local _, class = UnitClass("player")
    if IsSecret(class) then return nil end
    local info = classPower[class]
    if not info then return nil end
    if info.spec then
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        if not getSpec or getSpec() ~= info.spec then return nil end
    end
    if info.needsPower then
        local current = UnitPowerType("player")
        if IsSecret(current) or current ~= info.needsPower then return nil end
    end
    return info
end

local function layoutPips(frame, n)
    local pips, w = frame.cpPips, frame.cpWidth
    local gap = Theme.pad
    local pw = (w - gap * (n - 1)) / n
    for i = 1, MAX_PIPS do
        local pip = pips[i]
        if i <= n then
            pip:ClearAllPoints()
            pip:SetPoint("TOPLEFT", frame.classPower, "TOPLEFT", (i - 1) * (pw + gap), 0)
            pip:SetPoint("BOTTOMLEFT", frame.classPower, "BOTTOMLEFT", (i - 1) * (pw + gap), 0)
            pip:SetWidth(pw)
            pip:Show()
        else
            pip:Hide()
        end
    end
end

local function updatePower(frame)
    local info = frame.cpInfo
    if not info then return end
    local pips = frame.cpPips
    if info.runes then
        for i = 1, RUNES do
            local start, duration, ready = GetRuneCooldown(i)
            local d = frame.cpDurations[i]
            if start and d then
                d:SetTimeFromStart(start, duration)
                pips[i]:SetTimerDuration(d)
                if not IsSecret(ready) then
                    local c = ready and Theme.color.gold or Theme.color.deep
                    pips[i]:SetStatusBarColor(c[1], c[2], c[3])
                end
            end
        end
        return
    end
    local cur = UnitPower("player", info.type, frame.cpUnmodified)
    -- Essence regen: UnitPartialPower is known broken for essence (WoWUIBugs #420), so the
    -- fraction is used only when it is a plain number in range. Otherwise whole pips only.
    if info.partial and not IsSecret(cur) then
        local part = UnitPartialPower("player", info.type)
        if type(part) == "number" and not IsSecret(part) and part > 0 and part < 1000 then
            cur = cur + part / 1000
        end
    end
    for i = 1, frame.cpCount do pips[i]:SetValue(cur, UF.interp) end
end

local function setupPower(frame)
    local info = powerInfo()
    frame.cpInfo = info
    local box = frame.classPower
    if not info then
        frame.cpCount = 0
        box:Hide()
        return
    end
    local pips = frame.cpPips
    local n
    if info.runes then
        n = RUNES
        for i = 1, n do
            pips[i]:SetMinMaxValues(0, 1)
            pips[i]:SetStatusBarColor(Theme.color.gold[1], Theme.color.gold[2], Theme.color.gold[3])
        end
    else
        local useUnmod, mod = false, 1
        if info.unmodified then
            local m = UnitPowerDisplayMod(info.type)
            if not IsSecret(m) and type(m) == "number" and m > 0 then useUnmod, mod = true, m end
        end
        frame.cpUnmodified = useUnmod
        -- The pip count comes from the display max; values (and pip ranges) use the unmodified scale.
        local max = UnitPowerMax("player", info.type)
        local c = Theme.color.gold
        if IsSecret(max) then
            -- Count unknown to Lua: one continuous bar, the engine scales it.
            n = 1
            pips[1]:SetMinMaxValues(0, UnitPowerMax("player", info.type, useUnmod))
            pips[1]:SetStatusBarColor(c[1], c[2], c[3])
        else
            n = math.min(max, MAX_PIPS)
            for i = 1, n do
                pips[i]:SetMinMaxValues((i - 1) * mod, i * mod)
                pips[i]:SetStatusBarColor(c[1], c[2], c[3])
            end
        end
    end
    if n < 1 then
        frame.cpCount = 0
        box:Hide()
        return
    end
    frame.cpCount = n
    -- Re-anchoring children of a secure frame is deferred out of combat to be safe. Values update now.
    ns.Combat:Defer(layoutPips, frame, n)
    box:Show()
    updatePower(frame)
end

UF.elements.ClassPower = {
    create = function(frame, spec)
        local box = CreateFrame("Frame", nil, frame)
        box:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -3)
        box:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -3)
        box:SetHeight(spec.classPowerHeight or 6)
        box:Hide()
        local pips, bg = {}, Theme.color.raise
        for i = 1, MAX_PIPS do
            local pip = CreateFrame("StatusBar", nil, box)
            pip:SetStatusBarTexture(Theme.bar)
            local back = pip:CreateTexture(nil, "BACKGROUND")
            back:SetAllPoints(pip)
            back:SetColorTexture(bg[1], bg[2], bg[3], 0.9)
            pip:Hide()
            pips[i] = pip
        end
        frame.classPower, frame.cpPips, frame.cpWidth, frame.cpCount = box, pips, spec.w, 0
        frame.cpDurations = {}
        if C_DurationUtil then
            for i = 1, RUNES do frame.cpDurations[i] = C_DurationUtil.CreateDuration() end
        end
        UF.OnGlobal(frame, { "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE" }, setupPower)
        UF.OnGlobal(frame, { "RUNE_POWER_UPDATE" }, updatePower)
    end,
    refresh = setupPower,
    events = {
        UNIT_POWER_FREQUENT = function(frame, _, token)
            local info = frame.cpInfo
            if not info or info.runes then return end
            if token and not IsSecret(token) and token ~= info.token then return end
            updatePower(frame)
        end,
        UNIT_MAXPOWER = setupPower,
        UNIT_DISPLAYPOWER = setupPower,
    },
}
