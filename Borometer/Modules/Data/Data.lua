local _, ns = ...

-- Reads a finished fight from C_DamageMeter once the secrets are gone and keeps plain copies.
-- Nothing here runs in combat: the session is SecretWhenInCombat, so numbers are only touched
-- after PLAYER_REGEN_ENABLED and only if issecretvalue says they are readable.
local M = ns:NewModule("Data")
ns.Data = M

local METERS = { damage = "DamageDone", healing = "HealingDone" }
M.types = { "damage", "healing" }

local HISTORY_MAX = 10
local FIRST_TRY, RETRY, TRIES = 1.0, 1.5, 3

local history, listeners = {}, {}

-- True when none of the arguments is a secret value.
local function plain(...)
    for i = 1, select("#", ...) do
        if ns.IsSecret((select(i, ...))) then return false end
    end
    return true
end

local function byAmount(a, b) return a.amount > b.amount end

local function readType(getSession, key)
    local meterType = Enum.DamageMeterType[METERS[key]]
    local session = getSession(meterType)
    if type(session) ~= "table" or not plain(session, session.totalAmount, session.durationSeconds, session.combatSources) then
        return nil
    end
    local out = { total = session.totalAmount or 0, duration = session.durationSeconds or 0, sources = {} }
    for _, s in ipairs(session.combatSources or {}) do
        -- name and sourceGUID can stay secret after combat in instances; class and amounts are enough for the ring.
        if plain(s.totalAmount, s.amountPerSecond) and (s.totalAmount or 0) > 0 then
            out.sources[#out.sources + 1] = {
                name = plain(s.name) and s.name or nil,
                class = s.classFilename,
                amount = s.totalAmount,
                perSecond = s.amountPerSecond or 0,
                isPlayer = s.isLocalPlayer and true or false,
            }
        end
    end
    if #out.sources == 0 then return nil end
    table.sort(out.sources, byAmount)
    return out
end

-- The newest finished fight. Falls back to the "current" session type.
local function sessionGetter()
    local newest
    for _, info in ipairs(C_DamageMeter.GetAvailableCombatSessions() or {}) do
        if plain(info.sessionID) and (not newest or info.sessionID > newest.sessionID) then newest = info end
    end
    if newest then
        local id = newest.sessionID
        return function(meterType) return C_DamageMeter.GetCombatSessionFromID(id, meterType) end, newest.name
    end
    return function(meterType)
        return C_DamageMeter.GetCombatSessionFromType(Enum.DamageMeterSessionType.Current, meterType)
    end
end

local function push(snap)
    history[#history + 1] = snap
    if #history > HISTORY_MAX then table.remove(history, 1) end
    for i = 1, #listeners do ns.Debug.Guard("Data:listener", listeners[i], snap) end
end

function M:Capture()
    if InCombatLockdown() or not C_DamageMeter or not C_DamageMeter.IsDamageMeterAvailable() then return false end
    local getSession, name = sessionGetter()
    local snap = { time = time(), name = name, types = {} }
    for _, key in ipairs(M.types) do snap.types[key] = readType(getSession, key) end
    if not next(snap.types) then return false end
    push(snap)
    return true
end

-- A hand-made fight to judge the look without fighting.
function M:Demo()
    local classes = { "WARRIOR", "MAGE", "ROGUE", "PRIEST", "HUNTER", "DEATHKNIGHT", "SHAMAN", "DRUID" }
    local names = { "Borak", "Ignis", "Vexa", "Lumen", "Skadi", "Morrow", "Tamsin", "Quill" }
    local snap = { time = time(), name = "Demo", demo = true, types = {} }
    for key, base in pairs({ damage = 2400000, healing = 1300000 }) do
        local t = { total = 0, duration = 180, sources = {} }
        for i = 1, #classes do
            local amount = math.floor(base * (1.15 - i * 0.12))
            t.sources[i] = { name = names[i], class = classes[i], amount = amount, perSecond = amount / 180, isPlayer = i == 3 }
            t.total = t.total + amount
        end
        snap.types[key] = t
    end
    push(snap)
end

function M:Latest()
    return history[#history]
end

function M:OnCapture(fn)
    listeners[#listeners + 1] = fn
end

local function attempt(n)
    if InCombatLockdown() then return end
    if not M:Capture() and n < TRIES then ns.Scheduler:After(RETRY, attempt, n + 1) end
end

function M:OnEnable()
    ns.Events:Register("PLAYER_REGEN_ENABLED", M, function() ns.Scheduler:After(FIRST_TRY, attempt, 1) end)
end

function M:OnDisable()
    ns.Events:Unregister("PLAYER_REGEN_ENABLED", M)
end
