local _, ns = ...

-- Reputation tab of the character window (ReputationFrame.xml, Blizzard_UIPanels_Game).
-- Rows are recycled by a ScrollBox, so they are styled through Skin.ScrollList.
local Skin = ns.Skin
local Theme = ns.Theme

local styledRows = setmetatable({}, { __mode = "k" })

local function styleRow(row)
    if styledRows[row] then return end
    styledRows[row] = true
    if row.Content then
        -- entry or sub header: the standing bar
        local bar = row.Content.ReputationBar
        if bar then
            Skin.Hide(bar.LeftTexture)
            Skin.Hide(bar.RightTexture)
            Skin.EnableBackdrop(bar)
            Theme:Backdrop(bar)
        end
    elseif row.HighlightTextureRegions then
        -- top level header button
        Skin.Hide(row.Left)
        Skin.Hide(row.Middle)
        Skin.Hide(row.Right)
        local gold = Theme.color.gold
        row.Name:SetTextColor(gold[1], gold[2], gold[3])
    end
end

ns.Skin:Register("Reputation", "Blizzard_UIPanels_Game", function()
    local frame = ReputationFrame
    Skin.ScrollList(frame.ScrollBox, frame.ScrollBar, styleRow)

    local detail = frame.ReputationDetailFrame
    Skin.Frame(detail)
    Skin.Hide(detail.Border)
    Skin.CloseButton(detail.CloseButton)
    Skin.ScrollBar(detail.ScrollingDescriptionScrollBar)
    Skin.Checkbox(detail.AtWarCheckbox)
    Skin.Checkbox(detail.MakeInactiveCheckbox, Theme.color.gold)
    Skin.Checkbox(detail.WatchFactionCheckbox, Theme.color.gold)
end)
