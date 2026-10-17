local _, ns = ...

local UF = ns.UF
local M = ns:NewModule("UnitFrames")

local FULL = { "Health", "Absorb", "Power", "Name", "HealthText", "Auras" }
local SMALL = { "Health", "Name" }

-- Aura rows above the frame, growing up: own debuffs nearest the frame, buffs above.
-- 10 x 24 px + 9 x 2 px spacing = 258 px, fits the 260 px frame. Filters are Blizzard filter strings.
local function bigAuras(enabled)
    return { enabled = enabled, size = 24, spacing = 2, perRow = 10, fontSize = 10, showDuration = true,
        growX = "RIGHT", growY = "UP", relPoint = "TOPLEFT", x = 0, y = 4,
        groups = {
            { key = "debuffs", filter = "HARMFUL|PLAYER", max = 10 },
            { key = "buffs", filter = "HELPFUL", max = 10, newLine = true },
        } }
end

-- Defaults double as the frame list. pos = { point, x, y } relative to the screen center.
local defaults = {
    frames = {
        player = { unit = "player", w = 260, h = 46, powerHeight = 5, healthTextWidth = 110, elements = FULL,
            auras = bigAuras(false), pos = { "CENTER", -320, -200 } },
        target = { unit = "target", w = 260, h = 46, powerHeight = 5, healthTextWidth = 110, elements = FULL,
            auras = bigAuras(true), refreshOn = { "PLAYER_TARGET_CHANGED" }, pos = { "CENTER", 320, -200 } },
        targettarget = { unit = "targettarget", w = 140, h = 24, elements = SMALL,
            refreshOn = { "UNIT_TARGET", "PLAYER_TARGET_CHANGED" }, poll = 0.25, pos = { "CENTER", 520, -250 } },
        focus = { unit = "focus", w = 180, h = 30, powerHeight = 3, elements = { "Health", "Power", "Name" },
            refreshOn = { "PLAYER_FOCUS_CHANGED" }, pos = { "CENTER", -520, -250 } },
    },
    hideBlizzard = true,
    smooth = true,
}
for i = 1, 5 do
    defaults.frames["boss" .. i] = { unit = "boss" .. i, w = 200, h = 34, powerHeight = 3, healthTextWidth = 50,
        elements = { "Health", "Power", "Name", "HealthText", "Auras" },
        -- Two 16 px rows (34 px) left of the frame, growing left and down.
        auras = { size = 16, spacing = 2, perRow = 6, fontSize = 8, showDuration = true,
            growX = "LEFT", growY = "DOWN", relPoint = "TOPLEFT", x = -4, y = 0,
            groups = {
                { key = "debuffs", filter = "HARMFUL|PLAYER", max = 6 },
                { key = "buffs", filter = "HELPFUL", max = 6, newLine = true },
            } },
        refreshOn = { "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }, pos = { "RIGHT", -60, 120 - (i - 1) * 44 } }
end
ns.Config:Register("unitframes", defaults)

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- Blizzard's own frames are parked under a hidden parent. Done once, out of combat.
local function hideBlizzard(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    frame:SetParent(hiddenParent)
end

function M:OnEnable()
    local cfg = ns.Config:Get("unitframes")
    UF.interp = cfg.smooth and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut or nil
    for name, spec in pairs(cfg.frames) do
        if not UF.frames[name] then
            local frame = UF.Create(name, spec)
            ns.Mover:Register(frame, name, { spec.pos[1], spec.pos[1], spec.pos[2], spec.pos[3] })
        end
    end
    if cfg.hideBlizzard then
        ns.Combat:Defer(function()
            hideBlizzard(PlayerFrame)
            hideBlizzard(TargetFrame)
            hideBlizzard(FocusFrame)
            hideBlizzard(BossTargetFrameContainer)
        end)
    end
end

function M:OnDisable()
    ns.Debug.Print("UnitFrames: Deaktivieren wirkt nach /reload.")
end
