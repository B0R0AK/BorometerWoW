local _, ns = ...

-- Saved positions and an unlock mode with drag overlays. Positions are stored per profile.
local Mover = {}
ns.Mover = Mover

local registered = {}
local overlays
local unlocked = false

local function apply(entry)
    local pos = ns.Config:Get("movers")[entry.id]
    local frame = entry.frame
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint(unpack(entry.default))
    end
end

-- default = { point, relPoint, x, y } relative to UIParent.
function Mover:Register(frame, id, default)
    local entry = { frame = frame, id = id, default = { default[1], UIParent, default[2], default[3], default[4] } }
    registered[id] = entry
    ns.Combat:Defer(apply, entry)
end

local function createOverlay(entry)
    local o = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    o:SetFrameStrata("DIALOG")
    o:SetMovable(true)
    o:EnableMouse(true)
    o:RegisterForDrag("LeftButton")
    o:SetClampedToScreen(true)
    ns.Theme:Backdrop(o, ns.Theme.color.amber, 0.35)
    local label = o:CreateFontString(nil, "OVERLAY")
    label:SetFont(ns.Theme.font, 11, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(entry.id)
    o:SetScript("OnDragStart", function(self) self:StartMoving() end)
    o:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.Config:Get("movers")[entry.id] = { point, relPoint, x, y }
        ns.Combat:Defer(apply, entry)
    end)
    return o
end

function Mover:SetUnlocked(state)
    if state and InCombatLockdown() then
        ns.Debug.Print("Im Kampf nicht möglich.")
        return
    end
    unlocked = state
    overlays = overlays or {}
    for id, entry in pairs(registered) do
        local o = overlays[id]
        if state then
            o = o or createOverlay(entry)
            overlays[id] = o
            o:SetAllPoints(entry.frame)
            o:Show()
        elseif o then
            o:Hide()
        end
    end
end

function Mover:Toggle()
    self:SetUnlocked(not unlocked)
end

function Mover:ResetAll()
    wipe(ns.Config:Get("movers"))
    for _, entry in pairs(registered) do ns.Combat:Defer(apply, entry) end
end

ns.Events:Register("PLAYER_REGEN_DISABLED", Mover, function()
    if unlocked then Mover:SetUnlocked(false) end
end)
