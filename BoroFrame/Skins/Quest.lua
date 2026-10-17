local _, ns = ...

-- Quest dialog (QuestFrame). The parchment panels keep their art: Blizzard colors the quest
-- text dark for them at runtime, so removing the parchment would make it unreadable.
-- Only chrome is skinned: frame, title, close button, action buttons.
local Skin = ns.Skin

local BUTTONS = {
    "QuestFrameCompleteQuestButton", "QuestFrameGoodbyeButton", "QuestFrameCompleteButton",
    "QuestFrameDeclineButton", "QuestFrameAcceptButton", "QuestFrameGreetingGoodbyeButton",
}

ns.Skin:Register("Quest", nil, function()
    if not QuestFrame then return end
    Skin.Panel_c(QuestFrame)
    Skin.Hide(QuestFramePortrait)
    for _, name in ipairs(BUTTONS) do Skin.Button(_G[name]) end
end)
