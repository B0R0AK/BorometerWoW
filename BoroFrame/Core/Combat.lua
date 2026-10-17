local _, ns = ...

-- Protected frames cannot be changed in combat. Defer queues the call until it ends.
local Combat = {}
ns.Combat = Combat

local queue, n = {}, 0

function Combat:Defer(fn, ...)
    if not InCombatLockdown() then
        fn(...)
        return
    end
    n = n + 1
    queue[n] = { fn = fn, nargs = select("#", ...), ... }
end

function Combat:Pending()
    return n
end

ns.Events:Register("PLAYER_REGEN_ENABLED", Combat, function()
    local run, count = queue, n
    queue, n = {}, 0
    for i = 1, count do
        local job = run[i]
        ns.Debug.Guard("Combat:Defer", job.fn, unpack(job, 1, job.nargs))
    end
end)
