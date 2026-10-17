local _, ns = ...

local UF = ns.UF
local Theme = ns.Theme

local frames = {}
UF.frames = frames

local function refreshAll(frame)
    for _, element in ipairs(frame.elementList) do
        element.refresh(frame)
    end
end

-- spec: { unit, w, h, powerHeight, healthTextWidth, elements = {...}, refreshOn = {...}, poll }
function UF.Create(name, spec)
    local frame = CreateFrame("Button", "BoroFrame_" .. name, UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
    frame.unit = spec.unit
    frame:SetSize(spec.w, spec.h)
    frame:SetAttribute("unit", spec.unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:RegisterForClicks("AnyUp")
    Theme:Backdrop(frame)

    frame.elementList, frame.handlers = {}, {}
    for _, elementName in ipairs(spec.elements) do
        local element = assert(UF.elements[elementName], "unknown element " .. elementName)
        element.create(frame, spec)
        frame.elementList[#frame.elementList + 1] = element
        for event, handler in pairs(element.events or {}) do
            local list = frame.handlers[event]
            if not list then
                list = {}
                frame.handlers[event] = list
                frame:RegisterUnitEvent(event, spec.unit)
            end
            list[#list + 1] = handler
        end
    end

    -- Context events that change which unit sits behind the token.
    for _, event in ipairs(spec.refreshOn or {}) do frame:RegisterEvent(event) end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(self, event, ...)
        local list = self.handlers[event]
        if list then
            for i = 1, #list do list[i](self, ...) end
        elseif self:IsVisible() then
            refreshAll(self)
        end
    end)
    frame:SetScript("OnShow", refreshAll)

    -- Units without their own events (targettarget) are polled by the shared scheduler.
    if spec.poll then
        ns.Scheduler:Every(spec.poll, function()
            if frame:IsVisible() then refreshAll(frame) end
        end, frame)
    end

    -- Hide when the unit does not exist. Secure, so it also works in combat.
    if spec.unit ~= "player" then RegisterUnitWatch(frame) end

    frames[name] = frame
    return frame
end
