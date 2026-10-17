local _, ns = ...

-- Skins and positions Blizzard's Cooldown Manager. Blizzard keeps the data: which
-- cooldowns, their order, timers, swipes, auras. We change optics, item size and where
-- the items sit, nothing else.
--
-- How (see docs/RECHERCHE.md, V07):
--  * One post-hook per viewer on `Layout` (hooksecurefunc, never a replacement). Blizzard's
--    RefreshLayout, OnShow and Edit Mode all end in Layout, so the hook sees every relayout.
--  * The viewer frame itself is never moved. Its SetPoint/ClearAllPoints are Edit Mode
--    overrides that write Lua state (snapping, layout dirty flags); calling them from
--    addon code would taint Edit Mode. Instead the items are anchored to an addon-owned
--    holder frame, which ns.Mover positions. Items stay parented to the viewer, so
--    Blizzard's visibility rules (in combat only, hidden, vehicle) still apply.
--  * While Edit Mode edits a viewer we leave the item positions to Blizzard.
--  * Known Blizzard bugs, not worked around here: WoWUIBugs #884 (target debuffs break on
--    two target changes in one frame), #875 (bleeds not tracked).
local Style = ns.CDMStyle
local M = ns:NewModule("CooldownManager")

local VIEWERS = {
    { key = "essential", frame = "EssentialCooldownViewer", kind = "icon", id = "CooldownEssential" },
    { key = "utility", frame = "UtilityCooldownViewer", kind = "icon", id = "CooldownUtility" },
    { key = "bufficon", frame = "BuffIconCooldownViewer", kind = "icon", id = "CooldownBuffIcons" },
    { key = "buffbar", frame = "BuffBarCooldownViewer", kind = "bar", id = "CooldownBuffBars" },
}

-- enabled: BoroFrame optics for this viewer. move: anchor items to our mover (else Edit Mode
-- places them). perRow: icons per row, or bars per column. pos = { point, x, y } from center.
ns.Config:Register("cooldownmanager", {
    essential = { enabled = true, move = true, size = 42, perRow = 8, spacing = 2, growUp = false,
        pos = { "CENTER", 0, -170 } },
    utility = { enabled = true, move = true, size = 32, perRow = 10, spacing = 2, growUp = false,
        pos = { "CENTER", 0, -225 } },
    bufficon = { enabled = true, move = true, size = 34, perRow = 10, spacing = 2, growUp = true,
        pos = { "CENTER", 0, -125 } },
    buffbar = { enabled = true, move = true, width = 200, height = 20, perRow = 8, spacing = 2, growUp = false,
        pos = { "CENTER", 300, -125 } },
})

local BLIZZARD_ADDON = "Blizzard_CooldownViewer"
local entries, byViewer = {}, {}
local scratch = {}
local hooked = false

local floor, max, min = math.floor, math.max, math.min

local function byLayoutIndex(a, b)
    return (a.layoutIndex or 0) < (b.layoutIndex or 0)
end

-- Active items in Blizzard's order. Reads the pool, writes nothing into it.
local function collect(viewer)
    wipe(scratch)
    local pool = viewer.itemFramePool
    if pool then
        for item in pool:EnumerateActive() do scratch[#scratch + 1] = item end
        table.sort(scratch, byLayoutIndex)
    end
    return scratch
end

-- Items without a cooldown and not shown are Blizzard's padding slots; they take no cell.
local function occupiesCell(item)
    if item.cooldownID then return true end
    return item:IsShown()
end

-- Holder sizes are in UIParent units. Item offsets are in the item's own units, hence k.
local function holderSize(entry)
    local cfg = entry.cfg
    local perRow = max(1, cfg.perRow)
    if entry.kind == "bar" then return cfg.width, cfg.height end
    return perRow * cfg.size + (perRow - 1) * cfg.spacing, cfg.size
end

local function scaleFactor(viewer)
    local mine, theirs = UIParent:GetEffectiveScale(), viewer:GetEffectiveScale()
    if not mine or not theirs or theirs <= 0 then return 1 end
    return mine / theirs
end

local function placeIcon(item, holder, cfg, index, count, k)
    local perRow = max(1, cfg.perRow)
    local step = (cfg.size + cfg.spacing) * k
    local row = floor(index / perRow)
    local col = index % perRow
    local inRow = min(perRow, count - row * perRow)
    local x = (col - (inRow - 1) / 2) * step
    item:ClearAllPoints()
    if cfg.growUp then
        item:SetPoint("BOTTOM", holder, "BOTTOM", x, row * step)
    else
        item:SetPoint("TOP", holder, "TOP", x, -row * step)
    end
end

local function placeBar(item, holder, cfg, index, k)
    local perCol = max(1, cfg.perRow)
    local col = floor(index / perCol)
    local row = index % perCol
    local x = col * (cfg.width + cfg.spacing) * k
    local y = row * (cfg.height + cfg.spacing) * k
    item:ClearAllPoints()
    if cfg.growUp then
        item:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, y)
    else
        item:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -y)
    end
end

local function anyProtected(viewer, items)
    if viewer:IsProtected() then return true end
    for i = 1, #items do
        if items[i]:IsProtected() then return true end
    end
    return false
end

local apply

local function deferredApply(entry)
    entry.pending = nil
    apply(entry)
end

function apply(entry)
    local cfg, viewer = entry.cfg, entry.viewer
    if not (M.enabled and cfg.enabled) then return end
    local items = collect(viewer)
    -- Items anchored into a protected chain (viewer in Blizzard's managed bottom container)
    -- cannot be touched in combat. Then the whole pass waits for combat to end, once.
    if InCombatLockdown() and anyProtected(viewer, items) then
        if not entry.pending then
            entry.pending = true
            ns.Combat:Defer(deferredApply, entry)
        end
        return
    end
    local k = scaleFactor(viewer)
    local move = cfg.move and entry.holder and not viewer.isEditing
    local count = 0
    if move then
        for i = 1, #items do
            if occupiesCell(items[i]) then count = count + 1 end
        end
    end
    local index = 0
    for i = 1, #items do
        local item = items[i]
        item:SetScale(1)
        if entry.kind == "bar" then
            Style.Bar(item, cfg.width * k, cfg.height * k)
        else
            Style.Icon(item, cfg.size * k)
        end
        if move and occupiesCell(item) then
            if entry.kind == "bar" then
                placeBar(item, entry.holder, cfg, index, k)
            else
                placeIcon(item, entry.holder, cfg, index, count, k)
            end
            index = index + 1
        end
    end
end

-- hooksecurefunc passes the viewer as self; one shared function, no closure per viewer.
local function onLayout(viewer)
    local entry = byViewer[viewer]
    if entry then ns.Debug.Guard("CooldownManager:Layout", apply, entry) end
end

local function createHolder(entry)
    local cfg = entry.cfg
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(holderSize(entry))
    entry.holder = holder
    ns.Mover:Register(holder, entry.id, { cfg.pos[1], cfg.pos[1], cfg.pos[2], cfg.pos[3] })
end

local function setup()
    if hooked then return end
    local cfg = ns.Config:Get("cooldownmanager")
    for _, def in ipairs(VIEWERS) do
        local viewer = _G[def.frame]
        if viewer and viewer.Layout and cfg[def.key].enabled then
            local entry = { key = def.key, kind = def.kind, id = def.id, viewer = viewer, cfg = cfg[def.key] }
            entries[#entries + 1] = entry
            byViewer[viewer] = entry
            if entry.cfg.move then createHolder(entry) end
            hooksecurefunc(viewer, "Layout", onLayout)
            ns.Debug.Guard("CooldownManager:apply", apply, entry)
        end
    end
    hooked = true
end

-- Re-reads sizes and limits from ns.Config. Positions come from ns.Mover.
function M:Refresh()
    for _, entry in ipairs(entries) do
        if entry.holder then entry.holder:SetSize(holderSize(entry)) end
        ns.Debug.Guard("CooldownManager:apply", apply, entry)
    end
end

function M:OnEnable()
    if hooked then
        self:Refresh()
    elseif C_AddOns.IsAddOnLoaded(BLIZZARD_ADDON) then
        setup()
    else
        ns.Events:Register("ADDON_LOADED", M, function(_, _, addon)
            if addon ~= BLIZZARD_ADDON then return end
            ns.Events:Unregister("ADDON_LOADED", M)
            if M.enabled then setup() end
        end)
    end
end

function M:OnDisable()
    -- Hooks cannot be removed; apply() checks M.enabled, Blizzard's next relayout no longer
    -- goes through us. Restoring Blizzard's optics needs a reload.
    ns.Debug.Print("CooldownManager: Deaktivieren wirkt vollständig nach /reload.")
end

-- Tests only.
M._entries = entries
