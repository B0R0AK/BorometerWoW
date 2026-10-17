local _, ns = ...

-- Skins are registered as small functions. Each runs in an error boundary, once,
-- and only when the Blizzard addon that owns the frame is loaded (lazy for LoD windows).
local Skin = {}
ns.Skin = Skin

local pending = {}  -- addonName -> array of skins
local applied = {}

local function run(skin)
    if applied[skin.name] then return end
    if not ns.Config:Get("skins").enabled[skin.name] then return end
    applied[skin.name] = true
    ns.Debug.Guard("Skin:" .. skin.name, skin.fn)
end

-- addon = name of the Blizzard addon providing the frame, or nil for always-loaded UI.
function Skin:Register(name, addon, fn)
    local skin = { name = name, addon = addon, fn = fn }
    local key = addon or "*"
    pending[key] = pending[key] or {}
    table.insert(pending[key], skin)
    local enabled = ns.Config.ready and ns.Config:Get("skins").enabled
    if enabled and enabled[name] == nil then enabled[name] = true end
    if ns.Config.ready and (not addon or C_AddOns.IsAddOnLoaded(addon)) then run(skin) end
end

ns.Config:Register("skins", { enabled = {} })

local function runList(list)
    if not list then return end
    for _, skin in ipairs(list) do
        local enabled = ns.Config:Get("skins").enabled
        if enabled[skin.name] == nil then enabled[skin.name] = true end
        run(skin)
    end
end

ns.Events:Register("PLAYER_LOGIN", Skin, function()
    runList(pending["*"])
    for addon, list in pairs(pending) do
        if addon ~= "*" and C_AddOns.IsAddOnLoaded(addon) then runList(list) end
    end
end)

ns.Events:Register("ADDON_LOADED", Skin, function(_, _, addon)
    if ns.Config.ready then runList(pending[addon]) end
end)
