local _, ns = ...

local Debug = {}
ns.Debug = Debug

local seen = {}

function Debug.Print(...)
    print("|cffe0a64aBorometer|r", ...)
end

-- Runs fn in an error boundary. One broken module or skin must not stop the rest.
-- Each distinct error is reported once.
function Debug.Guard(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local key = label .. tostring(err)
        if not seen[key] then
            seen[key] = true
            Debug.Print("|cffe0644fError|r in " .. label .. ": " .. tostring(err))
        end
    end
    return ok
end

-- Wall-clock cost of fn over n calls, in ms. Use with /run for hot-path experiments.
function Debug.Profile(label, fn, n)
    n = n or 1000
    local t0 = debugprofilestop()
    for _ = 1, n do fn() end
    local ms = debugprofilestop() - t0
    Debug.Print(("%s: %.3f ms total, %.4f ms/call"):format(label, ms, ms / n))
    return ms
end
