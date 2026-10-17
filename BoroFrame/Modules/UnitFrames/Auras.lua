local _, ns = ...

-- Auras element: buffs and debuffs through Blizzard's AuraContainer (12.1.0+).
--
-- Why not UNIT_AURA + C_UnitAuras: since 12.1.0 the UNIT_AURA payload is fully secret while
-- auras are restricted, AuraData structs are always secret, and the instance-ID APIs
-- (GetAuraDataByAuraInstanceID, GetAuraDuration, GetAuraApplicationDisplayCount ...) raise a
-- Lua error for addons in that state. The container does the tracking, filtering, delta
-- processing and frame pooling in secure code; we only build the look of each button once.
-- Our Lua never sees an aura, so there is nothing secret to compare and no per-event cost.
local UF = ns.UF
local Theme = ns.Theme

local Auras = {}
UF.Auras = Auras

-- Container point that matches the growth direction. The container is anchored to its
-- parent at this point, so it grows away from the frame.
local FLOW_ANCHOR = {
    RIGHT = { UP = "BOTTOMLEFT", DOWN = "TOPLEFT" },
    LEFT = { UP = "BOTTOMRIGHT", DOWN = "TOPRIGHT" },
}

local DIRECTION = { RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" }

-- Builds the visuals of one aura button. Called by the container's own frame provider,
-- in batches of 10, before the button becomes forbidden. Every region must be a descendant
-- of the button, Blizzard validates that.
local function buttonInitializer(cfg)
    local size = cfg.size
    local edge, bg = Theme.color.ridge, Theme.color.pitch
    local dispelStyle = Enum.CustomAuraButtonDispelTypeTextureStyle
    return function(button)
        button:SetSize(size, size)

        local back = button:CreateTexture(nil, "BACKGROUND", nil, 0)
        back:SetAllPoints()
        back:SetColorTexture(edge[1], edge[2], edge[3], 1)

        -- Recolored by the engine for debuffs with a dispel type, hidden otherwise.
        if dispelStyle then
            local border = button:CreateTexture(nil, "BACKGROUND", nil, 1)
            border:SetAllPoints()
            border:SetTexture(Theme.edge)
            button:AddDispelTypeTexture(border, { style = dispelStyle.PreserveAsset })
        end

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetIcon(icon)

        -- Swipe only. Countdown numbers of Cooldown frames break past 60 s (WoWUIBugs #881),
        -- so the remaining time comes from the container's duration text binding instead.
        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        cd:SetDrawEdge(false)
        cd:SetReverse(true)
        cd:SetSwipeColor(bg[1], bg[2], bg[3], 0.7)
        cd:SetHideCountdownNumbers(true)
        button:SetDurationCooldown(cd)

        -- Text sits on a child of the cooldown so it draws above the swipe.
        local overlay = CreateFrame("Frame", nil, cd)
        overlay:SetAllPoints(button)

        if cfg.showDuration then
            local duration = Theme:Text(overlay, cfg.fontSize)
            duration:SetPoint("CENTER", 0, 0)
            button:SetDurationText(duration)
        end

        -- Engine fills it, empty below two stacks.
        local count = Theme:Text(overlay, cfg.fontSize, Theme.color.lite)
        count:SetPoint("BOTTOMRIGHT", 1, 0)
        button:SetApplicationCount(count)
    end
end

local function sortMethod(name)
    return AuraContainerSortMethod[name or "Default"] or AuraContainerSortMethod.Default
end

-- Creates an aura container under `parent` for `unit`. cfg is the spec's `auras` table:
-- { size, spacing, perRow, fontSize, showDuration, growX, growY, relPoint, x, y,
--   groups = { { key, filter, max, sort, newLine, candidates } } }
-- Returns the container, or nil when auras are off. Reusable for party, raid and nameplates
-- (container:SetUnit(token) when a plate changes owner).
function Auras.Create(parent, unit, cfg)
    if not cfg or cfg.enabled == false or not cfg.groups or #cfg.groups == 0 then return end

    local growX = FLOW_ANCHOR[cfg.growX] and cfg.growX or "RIGHT"
    local growY = cfg.growY == "DOWN" and "DOWN" or "UP"
    local point = FLOW_ANCHOR[growX][growY]
    local size, spacing, perRow = cfg.size, cfg.spacing, cfg.perRow

    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    -- Nothing may be anchored to the container: it takes forbidden layout aspects.
    container:SetPoint(point, parent, cfg.relPoint or point, cfg.x or 0, cfg.y or 0)
    container:SetSize(size, size)
    container:SetFlowLayoutAnchorPoint(point)
    local dir = AnchorUtil.FlowDirection
    container:SetFlowLayoutGrowthDirection(dir[DIRECTION[growX]], dir[DIRECTION[growY]])
    -- Wraps exactly after perRow icons, see FlowLayoutMixin line breaking.
    container:SetFlowLayoutMaximumLineSize(perRow * (size + spacing) - spacing)

    local init = buttonInitializer(cfg)
    for i, group in ipairs(cfg.groups) do
        container:AddAuraGroup(group.key, group.filter, {
            maxFrameCount = group.max,
            sortMethod = sortMethod(group.sort),
            candidateFilters = group.candidates,
            initializeFrame = init,
            layout = {
                elementSpacing = spacing,
                lineSpacing = spacing,
                groupLineSpacing = spacing,
                elementWidth = size,
                elementHeight = size,
                forceNewLine = i > 1 and group.newLine or false,
            },
        })
    end

    container:SetUnit(unit)
    container:SetEnabled(true)
    return container
end

-- Unit frame element. No unit events: the container registers UNIT_AURA itself.
-- refresh runs on OnShow and on the spec's refreshOn events (target/focus change, boss engage),
-- where the token stays the same but the unit behind it changed.
UF.elements.Auras = {
    create = function(frame, spec)
        frame.auras = Auras.Create(frame, spec.unit, spec.auras) or false
    end,
    refresh = function(frame)
        if frame.auras then frame.auras:UpdateAllAuras() end
    end,
}
