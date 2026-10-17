local _, ns = ...

-- Encounter warnings stay Blizzard's (text, sound, timing, edit mode position).
-- We only restyle the icons and give the text a hard shadow in the Ember palette.
-- Hooks are post-hooks; nothing in Blizzard's call path is replaced.
local Theme = ns.Theme

local FRAMES = { "CriticalEncounterWarnings", "MediumEncounterWarnings", "MinorEncounterWarnings" }
-- Kept outside Blizzard's tables so we never write keys into their frames.
local done = setmetatable({}, { __mode = "k" })

local function skinIcon(icon)
    if not icon or done[icon] then return end
    done[icon] = true
    if icon.NormalOverlay then icon.NormalOverlay:SetAlpha(0) end
    local tex = icon.Icon
    if tex then
        if icon.IconMask and tex.RemoveMaskTexture then tex:RemoveMaskTexture(icon.IconMask) end
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local border = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    Theme:Backdrop(border, Theme.color.gold)
    border:SetBackdropColor(0, 0, 0, 0)
end

local function shadowText(fs)
    local p = Theme.color.pitch
    fs:SetShadowColor(p[1], p[2], p[3], 1)
    fs:SetShadowOffset(1, -1)
end

local function skinView(view)
    if not view or done[view] then return end
    done[view] = true
    skinIcon(view.LeftIcon)
    skinIcon(view.RightIcon)
    local text = view.Text
    -- Init sets the font object per severity, which resets the shadow every time.
    if text and text.Init then hooksecurefunc(text, "Init", shadowText) end
end

ns.Skin:Register("EncounterWarnings", "Blizzard_EncounterWarnings", function()
    for _, name in ipairs(FRAMES) do
        local frame = _G[name]
        if frame then skinView(frame.View) end
    end
end)
