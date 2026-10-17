-- Template for a Blizzard window skin. Copy to Skins/<Window>.lua, add to the TOC.
-- One window group per file. Colors, fonts and spacing come from ns.Theme only.
local _, ns = ...

-- name: key for the on/off option. addon: Blizzard addon that provides the frame
-- (nil if always loaded). The function runs once, inside an error boundary.
ns.Skin:Register("ExampleWindow", "Blizzard_ExampleWindow", function()
    local frame = ExampleWindowFrame
    ns.Skin.Frame(frame)
    ns.Skin.Button(frame.CloseButton)
end)
