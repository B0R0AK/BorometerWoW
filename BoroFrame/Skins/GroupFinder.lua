local _, ns = ...

-- Group Finder shell (PVEFrame and the LFGList action buttons, Blizzard_GroupFinder).
-- The listing/search panels, applicant lists and dropdowns keep Blizzard art.
local Skin = ns.Skin

ns.Skin:Register("GroupFinder", "Blizzard_GroupFinder", function()
    local frame = PVEFrame
    if not frame then return end
    Skin.Window(frame)
    if frame.shadows then frame.shadows:SetAlpha(0) end
    for i = 1, 3 do Skin.PanelTab(_G["PVEFrameTab" .. i]) end

    local list = LFGListFrame
    if list then
        local category, search, entry = list.CategorySelection, list.SearchPanel, list.EntryCreation
        if category then
            Skin.ActionButton(category.FindGroupButton)
            Skin.ActionButton(category.StartGroupButton)
        end
        if search then
            Skin.ActionButton(search.BackButton)
            Skin.ActionButton(search.SignUpButton)
        end
        if entry then Skin.ActionButton(entry.ListGroupButton) end
    end
end)
