local _, ns = ...

-- Ember palette, taken from the Borometer design: warm black, amber, gold.
local Theme = {}
ns.Theme = Theme

local function hex(h)
    return {
        tonumber(h:sub(1, 2), 16) / 255,
        tonumber(h:sub(3, 4), 16) / 255,
        tonumber(h:sub(5, 6), 16) / 255,
    }
end

Theme.color = {
    pitch = hex("060402"), comb = hex("0f0a05"), raise = hex("211708"), ridge = hex("2e2110"),
    text = hex("f4ece1"), dim = hex("b3a189"),
    amber = hex("c8791e"), gold = hex("e0a64a"), lite = hex("efc078"), deep = hex("8a5314"),
    pos = hex("8cc169"), neg = hex("e0644f"), info = hex("6fa8d8"),
}

Theme.font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
Theme.bar = "Interface\\Buttons\\WHITE8X8"
Theme.edge = "Interface\\Buttons\\WHITE8X8"
Theme.fontSize = { small = 10, normal = 12, large = 14 }
Theme.pad = 2

local backdropInfo = { bgFile = Theme.bar, edgeFile = Theme.edge, edgeSize = 1 }

-- Flat dark panel with a 1px edge. `edge` is a color table, alpha applies to the edge.
function Theme:Backdrop(frame, edge, edgeAlpha)
    edge = edge or self.color.ridge
    frame:SetBackdrop(backdropInfo)
    local bg = self.color.comb
    frame:SetBackdropColor(bg[1], bg[2], bg[3], 0.92)
    frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edgeAlpha or 1)
end

function Theme:Text(parent, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(self.font, size or self.fontSize.normal, "OUTLINE")
    local c = color or self.color.text
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetWordWrap(false)
    return fs
end
