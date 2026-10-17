local _, ns = ...

-- Character window: frame, tabs, paper doll slots, stats pane, title and equipment managers.
-- Frame names and keys are taken from Blizzard_UIPanels_Game (CharacterFrame.xml,
-- PaperDollFrame.xml). Reputation and currency tabs live in their own skin files.
local Skin = ns.Skin
local Theme = ns.Theme

local SLOTS = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
    "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand",
}
local MODEL_ART = {
    "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom", "Bottom2",
}
local MODEL_BACKGROUNDS = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft",
    "BackgroundBotRight", "BackgroundOverlay" }

local styledRows = setmetatable({}, { __mode = "k" })

-- Rows of the title and equipment set lists. The textures are only hidden by alpha, Blizzard
-- keeps calling Show/Hide on them.
local function styleListRow(row)
    if styledRows[row] then return end
    styledRows[row] = true
    Skin.Hide(row.BgTop)
    Skin.Hide(row.BgMiddle)
    Skin.Hide(row.BgBottom)
    if row.icon then row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
end

local function styleStatRows()
    local pane = CharacterStatsPane
    local pool = pane and pane.statsFramePool
    if not pool then return end
    for row in pool:EnumerateActive() do
        if not styledRows[row] then
            styledRows[row] = true
            Skin.Hide(row.Background)
        end
    end
end

local function styleStatsPane()
    local pane = CharacterStatsPane
    local gold = Theme.color.gold
    for _, key in ipairs({ "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }) do
        local category = pane[key]
        Skin.Hide(category.Background)
        category.Title:SetTextColor(gold[1], gold[2], gold[3])
    end
    Skin.Hide(pane.ItemLevelFrame.Background)
    styleStatRows()
    hooksecurefunc("PaperDollFrame_UpdateStats", styleStatRows)
end

local function paintSidebarTab(tab)
    local selected = not tab.Hider:IsShown()
    local c = selected and Theme.color.gold or Theme.color.ridge
    tab:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

local function styleSidebarTabs()
    local tabs = PaperDollSidebarTabs
    Skin.Hide(tabs.DecorLeft)
    Skin.Hide(tabs.DecorRight)
    local list = {}
    for i = 1, 3 do
        local tab = _G["PaperDollSidebarTab" .. i]
        if tab then
            Skin.Hide(tab.TabBg)
            Skin.Hide(tab.Hider)
            Skin.EnableBackdrop(tab)
            Theme:Backdrop(tab)
            paintSidebarTab(tab)
            list[#list + 1] = tab
        end
    end
    -- Blizzard flips Hider/TabBg here whenever the selected sidebar changes.
    hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
        for _, tab in ipairs(list) do paintSidebarTab(tab) end
    end)
end

local function styleModel()
    local scene = CharacterModelScene
    for _, key in ipairs(MODEL_BACKGROUNDS) do Skin.Hide(scene[key]) end
    for _, part in ipairs(MODEL_ART) do Skin.Hide(_G["PaperDollInnerBorder" .. part]) end
end

ns.Skin:Register("CharacterFrame", "Blizzard_UIPanels_Game", function()
    Skin.Panel_a(CharacterFrame)
    Skin.Inset_a(CharacterFrame.InsetRight)
    for i = 1, 3 do Skin.Tab_a(_G["CharacterFrameTab" .. i]) end

    for _, slot in ipairs(SLOTS) do Skin.ItemSlot(_G["Character" .. slot .. "Slot"]) end
    styleModel()
    styleStatsPane()
    styleSidebarTabs()

    local titles = PaperDollFrame.TitleManagerPane
    Skin.ScrollList(titles.ScrollBox, titles.ScrollBar, styleListRow)

    local sets = PaperDollFrame.EquipmentManagerPane
    Skin.ScrollList(sets.ScrollBox, sets.ScrollBar, styleListRow)
    Skin.Button(sets.EquipSet)
    Skin.Button(sets.SaveSet)
end)
