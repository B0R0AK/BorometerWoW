-- Shell of the combined spellbook / talents window (PlayerSpellsFrame): frame, close button, tabs.
-- Content skins live in SpellBook.lua and Talents.lua, each with its own switch.
local _, ns = ...

ns.Skin:Register("PlayerSpells", "Blizzard_PlayerSpells", function()
    local frame = PlayerSpellsFrame
    if not frame then return end
    ns.Skin.PortraitPanel(frame)
    ns.Skin.CloseButton(frame.CloseButton)
    ns.Skin.TabSystem(frame.TabSystem)
end)
