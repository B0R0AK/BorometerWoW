local _, ns = ...

-- Frame extras: heal prediction, raid marker, role/leader/PvP icons, dead/offline state, level.
-- Class power lives in ClassPower.lua.
-- Same element contract as Elements.lua. Global (non-unit) events go through ns.Events with the frame as owner.
local UF = ns.UF
local Theme = ns.Theme
local IsSecret = ns.IsSecret

local UnitHealthMax, UnitGetIncomingHeals = UnitHealthMax, UnitGetIncomingHeals

local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local function register(name, element)
    UF.elements[name] = element
end

-- Icons and texts must sit above the health bar, which is a child frame. One shared overlay per unit frame.
local function overlay(frame)
    local o = frame.extrasOverlay
    if not o then
        o = CreateFrame("Frame", nil, frame)
        o:SetAllPoints(frame)
        o:SetFrameLevel(frame:GetFrameLevel() + 6)
        frame.extrasOverlay = o
    end
    return o
end

local function icon(frame, size, point, relPoint, x, y)
    local tex = overlay(frame):CreateTexture(nil, "OVERLAY")
    tex:SetSize(size, size)
    tex:SetPoint(point, frame, relPoint, x, y)
    return tex
end

-- Global events for one element of one frame. ns.Events keeps one handler per (event, owner), and two
-- elements on a frame may want the same event, so each call gets its own owner token.
-- Shared with ClassPower.lua.
local function onGlobal(frame, events, fn)
    local owner = { frame = frame }
    local handler = function(o) if o.frame:IsVisible() then fn(o.frame) end end
    for i = 1, #events do ns.Events:Register(events[i], owner, handler) end
end
UF.OnGlobal = onGlobal

-- Heal prediction -------------------------------------------------------------
-- A bar that starts at the right edge of the health fill and shares its scale. The engine does the
-- addition by anchoring, so secret health and secret incoming heals never meet in Lua. A clip frame
-- cuts what would run past the health bar. It sits one level below the health bar so the name and
-- health texts (regions of the health bar) stay on top.
local function setHealMax(frame)
    frame.healPred:SetMinMaxValues(0, UnitHealthMax(frame.unit))
end

local function setHeal(frame)
    frame.healPred:SetValue(UnitGetIncomingHeals(frame.unit) or 0, UF.interp)
end

register("HealPrediction", {
    create = function(frame, spec)
        local health = assert(frame.health, "HealPrediction needs Health")
        local base = health:GetFrameLevel()
        local clip = CreateFrame("Frame", nil, frame)
        clip:SetAllPoints(health)
        clip:SetClipsChildren(true)
        clip:SetFrameLevel(base)
        health:SetFrameLevel(base + 1)
        if frame.absorb then frame.absorb:SetFrameLevel(base + 2) end

        local bar = CreateFrame("StatusBar", nil, clip)
        bar:SetStatusBarTexture(Theme.bar)
        local fill = health:GetStatusBarTexture()
        bar:SetPoint("TOPLEFT", fill, "TOPRIGHT")
        bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
        -- Fixed width from the spec: the health bar's own width may be secret and is never read.
        bar:SetWidth(spec.w - 2)
        local c = Theme.color.pos
        bar:SetStatusBarColor(c[1], c[2], c[3], 0.45)
        frame.healPred = bar
    end,
    refresh = function(frame)
        setHealMax(frame)
        setHeal(frame)
    end,
    events = {
        UNIT_HEAL_PREDICTION = setHeal,
        UNIT_MAXHEALTH = function(frame)
            setHealMax(frame)
            setHeal(frame)
        end,
    },
})

-- Raid marker -----------------------------------------------------------------
-- The index is not documented as secret. If it ever is, the truth test is still legal (non-boolean
-- secret) and the cell index goes straight to the texture, which accepts secret cells.
local function setRaidMarker(frame)
    local tex = frame.raidMarker
    local index = GetRaidTargetIndex(frame.unit)
    if index then
        if SetRaidTargetIconTexture then
            SetRaidTargetIconTexture(tex, index)
        else
            tex:SetSpriteSheetCell(index, 4, 4)
        end
        tex:Show()
    else
        tex:Hide()
    end
end

register("RaidMarker", {
    create = function(frame)
        local tex = icon(frame, 18, "CENTER", "TOP", 0, 0)
        tex:SetTexture(RAID_ICONS)
        tex:Hide()
        frame.raidMarker = tex
        onGlobal(frame, { "RAID_TARGET_UPDATE" }, setRaidMarker)
    end,
    refresh = setRaidMarker,
})

-- Role ------------------------------------------------------------------------
-- 12.1.5 ships UnitFrameUtil.GetUnitRoleIconDisplayInfo, which returns pre-wrapped secrets. Blizzard's
-- note: tainted callers must apply showRoleIcon with SetAlphaFromBoolean, SetShown rejects secrets.
local roleOptions = { displayRoleIcon = true }

local function setRole(frame)
    local tex, unit = frame.roleIcon, frame.unit
    local util = UnitFrameUtil and UnitFrameUtil.GetUnitRoleIconDisplayInfo
    if util then
        local info = util(unit, roleOptions)
        local show = info.showRoleIcon
        if IsSecret(show) then
            tex:SetAtlas(info.roleIconTexture)
        elseif show then
            tex:SetAtlas(info.roleIconTexture)
        end
        tex:SetAlphaFromBoolean(show)
        return
    end
    local role = UnitGroupRolesAssigned(unit)
    if IsSecret(role) or role == "NONE" or not GetMicroIconForRole then
        tex:SetAlpha(0)
        return
    end
    tex:SetAtlas(GetMicroIconForRole(role))
    tex:SetAlpha(1)
end

register("Role", {
    create = function(frame)
        frame.roleIcon = icon(frame, 14, "CENTER", "TOPLEFT", 10, 0)
        frame.roleIcon:SetAlpha(0)
        onGlobal(frame, { "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE" }, setRole)
    end,
    refresh = setRole,
    events = { UNIT_ENTERED_VEHICLE = setRole, UNIT_EXITED_VEHICLE = setRole },
})

-- Leader / assistant ------------------------------------------------------------
-- Both flags are secret when the unit's identity is restricted, so they only ever drive alpha.
local function setLeader(frame)
    local unit = frame.unit
    frame.leaderIcon:SetAlphaFromBoolean(UnitIsGroupLeader(unit))
    frame.assistIcon:SetAlphaFromBoolean(UnitIsGroupAssistant(unit))
end

register("Leader", {
    create = function(frame)
        local leader = icon(frame, 12, "CENTER", "TOPLEFT", 26, 0)
        leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        local assist = icon(frame, 12, "CENTER", "TOPLEFT", 26, 0)
        assist:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        leader:SetAlpha(0)
        assist:SetAlpha(0)
        frame.leaderIcon, frame.assistIcon = leader, assist
        onGlobal(frame, { "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE" }, setLeader)
    end,
    refresh = setLeader,
})

-- PvP -------------------------------------------------------------------------
-- UnitFrameUtil.UpdateUnitPvPIndicator is Blizzard's secret-safe setter (secure delegate, documented as
-- safe for addons). The fallback only branches on non-secret flags and hides otherwise.
local PVP_SIZE = 18

local function setPvP(frame)
    local tex, unit = frame.pvpIcon, frame.unit
    local update = UnitFrameUtil and UnitFrameUtil.UpdateUnitPvPIndicator
    if update then
        update(frame.pvpElements, unit)
        tex:SetSize(PVP_SIZE, PVP_SIZE)
        return
    end
    local ffa, pvp = UnitIsPVPFreeForAll(unit), UnitIsPVP(unit)
    local faction = UnitFactionGroup(unit)
    if IsSecret(ffa) or IsSecret(pvp) or IsSecret(faction) then
        tex:Hide()
    elseif ffa then
        tex:SetAtlas("UI-HUD-UnitFrame-Player-PVP-FFAIcon")
        tex:Show()
    elseif pvp and (faction == "Horde" or faction == "Alliance") then
        tex:SetAtlas("UI-HUD-UnitFrame-Player-PVP-" .. faction .. "Icon")
        tex:Show()
    else
        tex:Hide()
    end
end

register("PvP", {
    create = function(frame)
        local tex = icon(frame, PVP_SIZE, "CENTER", "TOPRIGHT", -12, 0)
        tex:Hide()
        frame.pvpIcon = tex
        frame.pvpElements = { pvpIcon = tex }
    end,
    refresh = setPvP,
    events = { UNIT_FACTION = setPvP },
})

-- Dead / offline ----------------------------------------------------------------
-- Neither flag is documented as secret. If one is, the health bar is desaturated straight from the
-- secret boolean (SetStatusBarDesaturated accepts secrets from tainted code) and no text is shown.
local function setStatus(frame)
    local unit, health, fs = frame.unit, frame.health, frame.statusText
    local dead, online = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
    if IsSecret(dead) or IsSecret(online) then
        frame.statusState = nil
        health:SetStatusBarDesaturated(dead)
        fs:SetText("")
        return
    end
    local state = (not online and 2) or (dead and 1) or 0
    if state == frame.statusState then return end  -- UNIT_HEALTH is frequent, only act on changes
    frame.statusState = state
    health:SetStatusBarDesaturated(state ~= 0)
    if state ~= 0 then
        local d = Theme.color.dim
        health:SetStatusBarColor(d[1], d[2], d[3])
        fs:SetText(state == 2 and (PLAYER_OFFLINE or "Offline") or (DEAD or "Dead"))
    else
        health:SetStatusBarColor(UF.UnitColor(unit))
        fs:SetText("")
    end
end

-- A new unit behind the token (target change) must not inherit the cached state.
local function refreshStatus(frame)
    frame.statusState = nil
    setStatus(frame)
end

register("Status", {
    create = function(frame)
        assert(frame.health, "Status needs Health")
        local fs = Theme:Text(overlay(frame), Theme.fontSize.normal, Theme.color.dim)
        fs:SetPoint("CENTER", frame.health, "CENTER")
        frame.statusText = fs
    end,
    refresh = refreshStatus,
    events = { UNIT_HEALTH = setStatus, UNIT_CONNECTION = setStatus, UNIT_FLAGS = setStatus },
})

-- Level -------------------------------------------------------------------------
-- UnitEffectiveLevel and UnitClassification carry no secret predicate. A secret level would still
-- be shown, just without the Lua-side "??" and color logic.
local ELITE = { elite = true, worldboss = true, rareelite = true }

local function setLevel(frame)
    local fs, unit = frame.levelText, frame.unit
    local level = UnitEffectiveLevel(unit)
    if IsSecret(level) then
        fs:SetFormattedText("%s", level)
        return
    end
    local c
    if level <= 0 then
        fs:SetText("??")
        c = Theme.color.neg
    else
        local class = UnitClassification(unit)
        local plus = (not IsSecret(class) and ELITE[class]) and "+" or ""
        fs:SetFormattedText("%d%s", level, plus)
        local mine = UnitEffectiveLevel("player")
        local diff = IsSecret(mine) and 0 or level - mine
        c = diff >= 5 and Theme.color.neg or diff >= 3 and Theme.color.amber
            or diff <= -10 and Theme.color.dim or Theme.color.gold
    end
    fs:SetTextColor(c[1], c[2], c[3])
end

register("Level", {
    create = function(frame)
        local fs = Theme:Text(overlay(frame), Theme.fontSize.small)
        fs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 2, 2)
        frame.levelText = fs
    end,
    refresh = setLevel,
    events = { UNIT_LEVEL = setLevel, UNIT_CLASSIFICATION_CHANGED = setLevel },
})
