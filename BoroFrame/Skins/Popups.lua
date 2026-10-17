local _, ns = ...

-- Static popups StaticPopup1..4. Names and keys verified in
-- Blizzard_StaticPopup_Game/GameDialog.xml (BG, CloseButton, ButtonContainer.Button1-4,
-- ExtraButton, EditBox with TooltipBackdropTemplate, Dropdown). Appearance only: the dialog
-- text, definitions and callbacks are never touched.
local Skin = ns.Skin

local MAX_POPUPS = 4

ns.Skin:Register("Popups", "Blizzard_StaticPopup_Game", function()
    for i = 1, MAX_POPUPS do
        local dialog = _G["StaticPopup" .. i]
        if dialog then
            Skin.Fade(dialog.BG)
            Skin.Panel(dialog)
            Skin.CloseButton(dialog.CloseButton)
            local container = dialog.ButtonContainer
            if container then
                for b = 1, 4 do Skin.Button(container["Button" .. b]) end
            end
            Skin.Button(dialog.ExtraButton)
            Skin.NineSlice(dialog.EditBox)
            Skin.Dropdown(dialog.Dropdown)
        end
    end
end)
