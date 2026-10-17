local _, ns = ...

-- Profiles live in BoroFrameDB.profiles. Each character points at one profile.
-- Defaults are registered per section by the modules and filled in additively,
-- so adding an option never needs a migration.
local Config = {}
ns.Config = Config

local DB_VERSION = 1
local defaults = {}
local db, profile

local function fill(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            fill(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

-- Ordered, versioned migrations. Add one per structural change, never edit old ones.
local migrations = {
    -- [2] = function(db) ... end,
}

function Config:Register(section, sectionDefaults)
    defaults[section] = sectionDefaults
    if profile then
        profile[section] = profile[section] or {}
        fill(profile[section], sectionDefaults)
    end
end

function Config:Get(section)
    return profile[section]
end

function Config:IsModuleEnabled(name)
    return profile.modules[name] ~= false
end

function Config:SetModuleEnabled(name, enabled)
    profile.modules[name] = enabled and true or false
    if enabled then ns:EnableModule(name) else ns:DisableModule(name) end
end

function Config:Reset()
    db.profiles[db.profileKeys[ns.charKey]] = nil
    ReloadUI()
end

local function init()
    BoroFrameDB = BoroFrameDB or {}
    db = BoroFrameDB
    db.profiles = db.profiles or {}
    db.profileKeys = db.profileKeys or {}
    db.version = db.version or DB_VERSION

    for v = db.version + 1, DB_VERSION do
        if migrations[v] then migrations[v](db) end
        db.version = v
    end

    ns.charKey = UnitName("player") .. "-" .. GetRealmName()
    local name = db.profileKeys[ns.charKey] or "Default"
    db.profileKeys[ns.charKey] = name
    db.profiles[name] = db.profiles[name] or {}
    profile = db.profiles[name]
    profile.modules = profile.modules or {}
    profile.movers = profile.movers or {}
    for section, d in pairs(defaults) do
        profile[section] = profile[section] or {}
        fill(profile[section], d)
    end
end

ns.Events:Register("ADDON_LOADED", Config, function(_, _, addon)
    if addon ~= ns.name then return end
    ns.Events:Unregister("ADDON_LOADED", Config)
    init()
    ns.Config.ready = true
end)

ns.Events:Register("PLAYER_LOGIN", Config, function()
    ns:StartModules()
end)

-- Exposed for tests only.
Config._init = init
Config._fill = fill
