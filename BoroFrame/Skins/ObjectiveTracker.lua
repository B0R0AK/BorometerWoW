local _, ns = ...

-- Objective tracker: headers only (background art and text color). Nothing is hooked.
-- ScenarioObjectiveTracker is deliberately skipped: it calls ShouldShowMawBuffs on UNIT_AURA
-- (WoWUIBugs #882), and we stay away from anything near it. Names verified in
-- Gethe/wow-ui-source 12.1.5 (Blizzard_ObjectiveTracker/*.xml).
local Skin, Theme = ns.Skin, ns.Theme
local lined = setmetatable({}, { __mode = "k" })

local MODULES = {
    "QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "WorldQuestObjectiveTracker",
    "BonusObjectiveTracker", "AchievementObjectiveTracker", "AdventureObjectiveTracker",
    "InitiativeTasksObjectiveTracker", "MonthlyActivitiesObjectiveTracker",
    "ProfessionsRecipeTracker", "UIWidgetObjectiveTracker",
}

local function header(h)
    if not h or lined[h] then return end
    lined[h] = true
    Skin.Hide(h.Background)
    -- Color only: the header font size is managed by AutoScalingFontStringMixin.
    local g = Theme.color.gold
    h.Text:SetTextColor(g[1], g[2], g[3])
    local line = h:CreateTexture(nil, "ARTWORK")
    local c = Theme.color.amber
    line:SetColorTexture(c[1], c[2], c[3], 0.6)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", 0, 2)
end

ns.Skin:Register("ObjectiveTracker", "Blizzard_ObjectiveTracker", function()
    if ObjectiveTrackerFrame then header(ObjectiveTrackerFrame.Header) end
    for _, name in ipairs(MODULES) do
        local module = _G[name]
        if module then header(module.Header) end
    end
end)
