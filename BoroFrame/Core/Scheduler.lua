local _, ns = ...

-- One OnUpdate for the whole addon. The driver frame is hidden, and therefore free,
-- while nothing is scheduled.
local Scheduler = {}
ns.Scheduler = Scheduler

local driver = CreateFrame("Frame")
driver:Hide()

local tasks, count, dead = {}, 0, false

local function tick(_, elapsed)
    for i = 1, count do
        local t = tasks[i]
        if t.fn then
            t.acc = t.acc + elapsed
            if t.acc >= t.interval then
                t.acc = 0
                local ok, err = pcall(t.fn, t.owner)
                if not ok then ns.Debug.Guard("Scheduler", error, err) end
            end
        end
    end
    if dead then
        local n = 0
        for i = 1, count do
            local t = tasks[i]
            if t.fn then
                n = n + 1
                tasks[n] = t
            end
        end
        for i = count, n + 1, -1 do tasks[i] = nil end
        count, dead = n, false
        if count == 0 then driver:Hide() end
    end
end

driver:SetScript("OnUpdate", tick)

-- Calls fn(owner) every `interval` seconds. Returns a handle for Cancel.
function Scheduler:Every(interval, fn, owner)
    local t = { interval = interval, fn = fn, owner = owner, acc = 0 }
    count = count + 1
    tasks[count] = t
    driver:Show()
    return t
end

function Scheduler:Cancel(handle)
    if handle and handle.fn then
        handle.fn = nil
        dead = true
    end
end

function Scheduler:CancelAll(owner)
    for i = 1, count do
        if tasks[i].owner == owner then self:Cancel(tasks[i]) end
    end
end

function Scheduler:After(seconds, fn, ...)
    local n = select("#", ...)
    if n == 0 then return C_Timer.After(seconds, fn) end
    local args = { ... }
    return C_Timer.After(seconds, function() fn(unpack(args, 1, n)) end)
end
