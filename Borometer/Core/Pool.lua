local _, ns = ...

-- Generic object pool for frames, textures and plain tables.
local Pool = {}
ns.Pool = Pool
Pool.__index = Pool

-- create(pool) -> object, reset(object) is called on release.
function Pool:New(create, reset)
    return setmetatable({ create = create, reset = reset, free = {}, nFree = 0, active = {} }, self)
end

function Pool:Acquire()
    local obj
    if self.nFree > 0 then
        obj = self.free[self.nFree]
        self.free[self.nFree] = nil
        self.nFree = self.nFree - 1
    else
        obj = self.create(self)
    end
    self.active[obj] = true
    return obj
end

function Pool:Release(obj)
    if not self.active[obj] then return end
    self.active[obj] = nil
    if self.reset then self.reset(obj) end
    self.nFree = self.nFree + 1
    self.free[self.nFree] = obj
end

function Pool:ReleaseAll()
    for obj in pairs(self.active) do self:Release(obj) end
end

function Pool:ActiveCount()
    local n = 0
    for _ in pairs(self.active) do n = n + 1 end
    return n
end
