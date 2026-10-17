local _, ns = ...

-- Elements are the building blocks of a unit frame. Each one has:
--   create(frame, spec)   build widgets once
--   refresh(frame)        full redraw from current unit state
--   events                { UNIT_EVENT = handler(frame) }, registered per frame with RegisterUnitEvent
-- Display values go straight to engine widgets. They may be secret and are never compared.
local UF = { elements = {} }
ns.UF = UF

local Theme = ns.Theme
local IsSecret = ns.IsSecret

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs

-- K/M/B with one decimal. AbbreviateNumbers accepts secret numbers and returns a plain string.
local abbreviation = { breakpointData = {
    { breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e3, abbreviation = "K", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 0, abbreviation = "", significandDivisor = 1, fractionDivisor = 1, abbreviationIsGlobal = false },
} }

function UF.Short(value)
    return AbbreviateNumbers(value, abbreviation)
end

-- Color needs Lua logic, so every API result is checked for secrecy first.
function UF.UnitColor(unit)
    local isPlayer = UnitIsPlayer(unit)
    if not IsSecret(isPlayer) and isPlayer then
        local _, class = UnitClass(unit)
        if class and not IsSecret(class) then
            local c = RAID_CLASS_COLORS[class]
            if c then return c.r, c.g, c.b end
        end
    end
    local reaction = UnitReaction(unit, "player")
    if reaction and not IsSecret(reaction) then
        local c = FACTION_BAR_COLORS[reaction]
        if c then return c.r, c.g, c.b end
    end
    local g = Theme.color.pos
    return g[1], g[2], g[3]
end

local function powerColor(unit)
    local _, token = UnitPowerType(unit)
    if token and not IsSecret(token) then
        local c = PowerBarColor[token]
        if c then return c.r, c.g, c.b end
    end
    local i = Theme.color.info
    return i[1], i[2], i[3]
end

local function register(name, element)
    UF.elements[name] = element
end

local function newBar(frame)
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetStatusBarTexture(Theme.bar)
    return bar
end

local function setHealthText(frame)
    local unit = frame.unit
    frame.healthText:SetFormattedText("%s  %.0f%%", UF.Short(UnitHealth(unit)),
        UnitHealthPercent(unit, false, CurveConstants.ScaleTo100))
end

local function setPower(frame)
    local unit = frame.unit
    frame.power:SetMinMaxValues(0, UnitPowerMax(unit))
    frame.power:SetValue(UnitPower(unit))
end

-- Health ---------------------------------------------------------------------
register("Health", {
    create = function(frame, spec)
        local bar = newBar(frame)
        bar:SetPoint("TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", -1, 1 + (spec.powerHeight or 0))
        frame.health = bar
    end,
    refresh = function(frame)
        local unit = frame.unit
        frame.health:SetMinMaxValues(0, UnitHealthMax(unit))
        frame.health:SetValue(UnitHealth(unit))
        frame.health:SetStatusBarColor(UF.UnitColor(unit))
    end,
    events = {
        UNIT_HEALTH = function(frame) frame.health:SetValue(UnitHealth(frame.unit)) end,
        UNIT_MAXHEALTH = function(frame)
            local unit = frame.unit
            frame.health:SetMinMaxValues(0, UnitHealthMax(unit))
            frame.health:SetValue(UnitHealth(unit))
        end,
        UNIT_FACTION = function(frame) frame.health:SetStatusBarColor(UF.UnitColor(frame.unit)) end,
    },
})

-- Absorb shield: thin strip along the top of the health bar, scaled to max health.
register("Absorb", {
    create = function(frame)
        local bar = newBar(frame)
        bar:SetFrameLevel(frame.health:GetFrameLevel() + 1)
        bar:SetPoint("TOPLEFT", frame.health, "TOPLEFT")
        bar:SetPoint("TOPRIGHT", frame.health, "TOPRIGHT")
        bar:SetHeight(3)
        local c = Theme.color.lite
        bar:SetStatusBarColor(c[1], c[2], c[3], 0.9)
        frame.absorb = bar
    end,
    refresh = function(frame)
        local unit = frame.unit
        frame.absorb:SetMinMaxValues(0, UnitHealthMax(unit))
        frame.absorb:SetValue(UnitGetTotalAbsorbs(unit))
    end,
    events = {
        UNIT_ABSORB_AMOUNT_CHANGED = function(frame) frame.absorb:SetValue(UnitGetTotalAbsorbs(frame.unit)) end,
        UNIT_MAXHEALTH = function(frame) frame.absorb:SetMinMaxValues(0, UnitHealthMax(frame.unit)) end,
    },
})

-- Power ----------------------------------------------------------------------
register("Power", {
    create = function(frame, spec)
        local bar = newBar(frame)
        bar:SetPoint("BOTTOMLEFT", 1, 1)
        bar:SetPoint("BOTTOMRIGHT", -1, 1)
        bar:SetHeight(spec.powerHeight or 4)
        frame.power = bar
    end,
    refresh = function(frame)
        setPower(frame)
        frame.power:SetStatusBarColor(powerColor(frame.unit))
    end,
    events = {
        UNIT_POWER_UPDATE = function(frame) frame.power:SetValue(UnitPower(frame.unit)) end,
        UNIT_MAXPOWER = setPower,
        UNIT_DISPLAYPOWER = function(frame)
            setPower(frame)
            frame.power:SetStatusBarColor(powerColor(frame.unit))
        end,
    },
})

-- Name -----------------------------------------------------------------------
local function setName(frame)
    frame.nameText:SetText((UnitName(frame.unit)))
end

register("Name", {
    create = function(frame, spec)
        local fs = Theme:Text(frame.health, Theme.fontSize.normal)
        fs:SetPoint("LEFT", 4, 0)
        fs:SetPoint("RIGHT", frame, "RIGHT", -(spec.healthTextWidth or 0) - 4, 0)
        fs:SetJustifyH("LEFT")
        frame.nameText = fs
    end,
    refresh = setName,
    events = { UNIT_NAME_UPDATE = setName },
})

-- Health text: abbreviated value and percent. Percent API is not secret, the value is passed through.
register("HealthText", {
    create = function(frame)
        local fs = Theme:Text(frame.health, Theme.fontSize.normal)
        fs:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        fs:SetJustifyH("RIGHT")
        frame.healthText = fs
    end,
    refresh = setHealthText,
    events = { UNIT_HEALTH = setHealthText },
})
