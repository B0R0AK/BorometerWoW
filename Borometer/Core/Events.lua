local _, ns = ...

-- Global (non-unit) events share one frame. Unit events are registered per unit frame
-- with RegisterUnitEvent so the client filters them before they reach Lua.
local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local listeners = {}  -- event -> array of { owner, fn }
local dirty = {}

local function compact(event)
    local list, n = listeners[event], 0
    for i = 1, #list do
        local entry = list[i]
        if entry.fn then
            n = n + 1
            list[n] = entry
        end
    end
    for i = #list, n + 1, -1 do list[i] = nil end
    dirty[event] = nil
    if n == 0 then
        listeners[event] = nil
        frame:UnregisterEvent(event)
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local entry = list[i]
        local fn = entry.fn
        if fn then
            local ok, err = pcall(fn, entry.owner, event, ...)
            if not ok then ns.Debug.Guard(event, error, err) end
        end
    end
    if dirty[event] then compact(event) end
end)

function Events:Register(event, owner, fn)
    local list = listeners[event]
    if not list then
        list = {}
        listeners[event] = list
        frame:RegisterEvent(event)
    end
    for i = 1, #list do
        if list[i].owner == owner and list[i].fn then
            list[i].fn = fn
            return
        end
    end
    list[#list + 1] = { owner = owner, fn = fn }
end

function Events:Unregister(event, owner)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        if list[i].owner == owner then
            list[i].fn = nil
            dirty[event] = true
        end
    end
end

function Events:UnregisterAll(owner)
    for event in pairs(listeners) do self:Unregister(event, owner) end
end

-- Safe outside dispatch: compacts immediately when no handler is running for the event.
function Events:Flush()
    for event in pairs(dirty) do compact(event) end
end
