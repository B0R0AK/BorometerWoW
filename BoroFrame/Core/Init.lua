local ADDON, ns = ...

ns.name = ADDON
ns.version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

-- Secret values exist from 12.0. The fallback keeps Core testable outside the client.
ns.IsSecret = issecretvalue or function() return false end

local modules, order = {}, {}
ns.modules = modules

local ModuleProto = {}
ModuleProto.__index = ModuleProto

function ModuleProto:IsEnabled()
    return self.enabled
end

function ns:NewModule(name)
    assert(not modules[name], "duplicate module " .. name)
    local m = setmetatable({ name = name, enabled = false }, ModuleProto)
    modules[name] = m
    order[#order + 1] = m
    return m
end

function ns:GetModule(name)
    return modules[name]
end

function ns:EnableModule(name)
    local m = modules[name]
    if not m or m.enabled then return end
    m.enabled = true
    if m.OnEnable then ns.Debug.Guard(name .. ":OnEnable", m.OnEnable, m) end
end

function ns:DisableModule(name)
    local m = modules[name]
    if not m or not m.enabled then return end
    m.enabled = false
    if m.OnDisable then ns.Debug.Guard(name .. ":OnDisable", m.OnDisable, m) end
end

-- Called once from Config after SavedVariables are ready.
function ns:StartModules()
    for _, m in ipairs(order) do
        if m.OnInitialize then ns.Debug.Guard(m.name .. ":OnInitialize", m.OnInitialize, m) end
    end
    for _, m in ipairs(order) do
        if ns.Config:IsModuleEnabled(m.name) then ns:EnableModule(m.name) end
    end
end
