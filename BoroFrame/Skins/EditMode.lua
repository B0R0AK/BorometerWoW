local _, ns = ...

-- Edit Mode manager window only (EditModeManagerFrame), not the per-system dialogs.
-- Keys verified in Blizzard_EditMode/Shared/EditModeManager.xml: Border (translucent dialog
-- border), CloseButton, LayoutDropdown. The window is a layout frame, our panel has no
-- layoutIndex so it takes no part in the layout.
local Skin = ns.Skin

ns.Skin:Register("EditMode", "Blizzard_EditMode", function()
    local frame = EditModeManagerFrame
    if not frame then return end
    Skin.Fade(frame.Border)
    Skin.Panel(frame)
    Skin.CloseButton(frame.CloseButton)
    Skin.Dropdown(frame.LayoutDropdown)
end)
