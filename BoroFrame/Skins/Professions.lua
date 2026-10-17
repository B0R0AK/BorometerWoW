-- Professions window (Blizzard_Professions): shell, crafting page buttons, specialization buttons.
-- Recipe list, schematic form and the crafting orders page keep their Blizzard art.
local _, ns = ...

local Skin = ns.Skin

local CRAFTING_BUTTONS = { "CreateButton", "CreateAllButton", "ViewGuildCraftersButton" }
local SPEC_BUTTONS = {
    "ApplyButton", "UnlockTabButton", "ViewTreeButton", "BackToPreviewButton",
    "ViewPreviewButton", "BackToFullTreeButton",
}
local DETAIL_BUTTONS = { "SpendPointsButton", "UnlockPathButton" }

local function skinButtons(parent, keys)
    if not parent then return end
    for _, key in ipairs(keys) do Skin.Button(parent[key]) end
end

ns.Skin:Register("Professions", "Blizzard_Professions", function()
    local frame = ProfessionsFrame
    if not frame then return end
    Skin.PortraitPanel(frame)
    Skin.CloseButton(frame.CloseButton)
    Skin.TabSystem(frame.TabSystem)

    skinButtons(frame.CraftingPage, CRAFTING_BUTTONS)

    local spec = frame.SpecPage
    if spec then
        skinButtons(spec, SPEC_BUTTONS)
        skinButtons(spec.DetailedView, DETAIL_BUTTONS)
    end
end)
