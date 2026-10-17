local _, ns = ...

local UF = ns.UF
local M = ns:NewModule("UnitFrames")

local FULL = { "Health", "Absorb", "Power", "Name", "HealthText" }
local SMALL = { "Health", "Name" }

-- Defaults double as the frame list. pos = { point, x, y } relative to the screen center.
local defaults = {
    frames = {
        player = { unit = "player", w = 260, h = 46, powerHeight = 5, healthTextWidth = 110, elements = FULL,
            pos = { "CENTER", -320, -200 } },
        target = { unit = "target", w = 260, h = 46, powerHeight = 5, healthTextWidth = 110, elements = FULL,
            refreshOn = { "PLAYER_TARGET_CHANGED" }, pos = { "CENTER", 320, -200 } },
        targettarget = { unit = "targettarget", w = 140, h = 24, elements = SMALL,
            refreshOn = { "UNIT_TARGET", "PLAYER_TARGET_CHANGED" }, poll = 0.25, pos = { "CENTER", 520, -250 } },
        focus = { unit = "focus", w = 180, h = 30, powerHeight = 3, elements = { "Health", "Power", "Name" },
            refreshOn = { "PLAYER_FOCUS_CHANGED" }, pos = { "CENTER", -520, -250 } },
    },
    hideBlizzard = true,
}
for i = 1, 5 do
    defaults.frames["boss" .. i] = { unit = "boss" .. i, w = 200, h = 34, powerHeight = 3, healthTextWidth = 50,
        elements = { "Health", "Power", "Name", "HealthText" },
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
