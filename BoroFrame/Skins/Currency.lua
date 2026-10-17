local _, ns = ...

-- Currency tab of the character window plus the currency transfer windows
-- (Blizzard_TokenUI: Blizzard_TokenUI.xml, Blizzard_CurrencyTransfer.xml).
local Skin = ns.Skin
local Theme = ns.Theme

local styledRows = setmetatable({}, { __mode = "k" })

-- Only top level headers (TokenHeaderTemplate) get the flat look. Entries and sub headers keep
-- Blizzard's art, which is already plain text plus icon.
local function styleRow(row)
    if styledRows[row] then return end
    styledRows[row] = true
    if row.HighlightTextureRegions then
        Skin.Hide(row.Left)
        Skin.Hide(row.Middle)
        Skin.Hide(row.Right)
        local gold = Theme.color.gold
        row.Name:SetTextColor(gold[1], gold[2], gold[3])
    end
end

local function stylePopup(popup)
    Skin.Frame(popup)
    Skin.Hide(popup.Border)
    Skin.Checkbox(popup.InactiveCheckbox, Theme.color.gold)
    Skin.Checkbox(popup.BackpackCheckbox, Theme.color.gold)
    Skin.Button(popup.CurrencyTransferToggleButton)
end

ns.Skin:Register("Currency", "Blizzard_TokenUI", function()
    local frame = TokenFrame
    Skin.ScrollList(frame.ScrollBox, frame.ScrollBar, styleRow)
    stylePopup(TokenFramePopup)

    local menu = CurrencyTransferMenu
    Skin.Panel_a(menu)
    Skin.Button(menu.Content.ConfirmButton)
    Skin.Button(menu.Content.CancelButton)
    Skin.Button(menu.Content.AmountSelector.MaxQuantityButton)

    local log = CurrencyTransferLog
    Skin.Panel_a(log)
    Skin.ScrollBar_a(log.ScrollBar)
end)
