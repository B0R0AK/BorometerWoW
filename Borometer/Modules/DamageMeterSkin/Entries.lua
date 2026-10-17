local _, ns = ...

-- Row skin for Blizzard's damage meter (DamageMeterEntryTemplate and its source/spell variants).
-- Rows live in ScrollBox pools and are reused, so every frame is hooked exactly once (weak set).
-- Blizzard feeds bars and texts with secret values: this file only calls setters on them and
-- never reads sizes, points, values or texts. No keys are written into Blizzard's frames, so the
-- meter's own code keeps running untainted.
local Theme = ns.Theme
local C = Theme.color

local DMS = {}
ns.DamageMeterSkin = DMS

local hooked = setmetatable({}, { __mode = "k" })
local lastColor = setmetatable({}, { __mode = "k" })

function DMS.Font(fs, size, color)
    if not fs then return end
    fs:SetFont(Theme.font, size, "OUTLINE")
    fs:SetShadowOffset(0, 0)
    fs:SetTextColor(color[1], color[2], color[3])
end

-- Flat panel from two textures on `owner`, placed relative to `anchor`. Regions instead of a
-- backdrop frame: they sit under the owner's children and need no frame-level juggling.
function DMS.Box(owner, anchor, left, top, right, bottom, fill, alpha)
    local r = C.ridge
    local edge = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
    edge:SetColorTexture(r[1], r[2], r[3], 1)
    edge:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, top)
    edge:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", right, bottom)
    local bg = owner:CreateTexture(nil, "BACKGROUND", nil, 2)
    bg:SetColorTexture(fill[1], fill[2], fill[3], alpha or 1)
    bg:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
    return edge, bg
end

function DMS.Tint(texture, color, desaturate)
    if not texture then return end
    if desaturate then texture:SetDesaturated(true) end
    texture:SetVertexColor(color[1], color[2], color[3])
end

-- Post-hook of UpdateStyle: Blizzard re-sets the track atlas and its anchors there on every
-- style, icon or suppress-icon change, so the track is redone each time.
local function restyle(entry)
    local bar = entry.StatusBar
    local track = bar.Background
    local p = C.pitch
    track:SetColorTexture(p[1], p[2], p[3], 0.6)
    track:ClearAllPoints()
    track:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    track:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
end

-- Post-hook of SetStatusBarColor. `color` is one of Blizzard's color tables, picked from
-- non-secret fields (classFilename, sourceDisplayType). Class colors stay when the player turned
-- them on in Blizzard's settings; everything else becomes Ember.
local function pick(entry, color)
    if color == DAMAGE_METER_STATUS_BAR_ENEMY_COLOR then return C.neg end
    if color == DAMAGE_METER_STATUS_BAR_CREATURE_COLOR then return C.amber end
    if not entry.isClassColorDesired or color == DAMAGE_METER_STATUS_BAR_DEFAULT_COLOR then return C.gold end
    return nil
end

local function recolor(entry, color)
    -- Blizzard skips SetVertexColor when the color did not change; then ours is still in place.
    if lastColor[entry] == color then return end
    lastColor[entry] = color
    local c = pick(entry, color)
    if c then entry.StatusBar:GetStatusBarTexture():SetVertexColor(c[1], c[2], c[3]) end
end

function DMS.SkinEntry(entry)
    if not entry or hooked[entry] then return end
    local bar = entry.StatusBar
    if not bar then return end
    hooked[entry] = true

    bar:SetStatusBarTexture(Theme.bar)
    -- The shadow edge is only ever shown/hidden and alpha-set by Blizzard, never re-textured.
    bar.BackgroundEdge:SetTexture(nil)
    DMS.Font(bar.Name, Theme.fontSize.normal, C.text)
    DMS.Font(bar.Value, Theme.fontSize.normal, C.lite)

    hooksecurefunc(entry, "UpdateStyle", restyle)
    hooksecurefunc(entry, "SetStatusBarColor", recolor)

    restyle(entry)
    -- The new bar texture may come back white, and Blizzard only recolors on a change.
    local color = entry.statusBarColor
    lastColor[entry] = color
    local c = pick(entry, color)
    if c then
        bar:GetStatusBarTexture():SetVertexColor(c[1], c[2], c[3])
    elseif color then
        bar:GetStatusBarTexture():SetVertexColor(color:GetRGB())
    end
end

-- Exposed for tests only.
DMS._hooked = hooked
