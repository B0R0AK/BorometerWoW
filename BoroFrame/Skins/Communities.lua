local _, ns = ...

-- Guild and Communities window (CommunitiesFrame, Blizzard_Communities): shell only.
-- No dropdown hooks (WoWUIBugs #826: dropdown taint). Member list, chat pane, side tabs,
-- guild finder and dialogs keep Blizzard art.
ns.Skin:Register("Communities", "Blizzard_Communities", function()
    local frame = CommunitiesFrame
    if not frame then return end
    -- Blizzard shows/hides the inset itself, so only its art is removed, never the frame.
    ns.Skin.Window(frame)
end)
