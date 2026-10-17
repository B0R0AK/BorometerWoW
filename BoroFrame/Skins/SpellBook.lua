-- Spellbook tab of PlayerSpellsFrame: drops the book art, recolors the parchment text.
local _, ns = ...

local Theme = ns.Theme

local BOOK_ART = { "TopBar", "BookBGHalved", "BookBGLeft", "BookBGRight", "BookCornerFlipbook", "Bookmark" }

local styled = setmetatable({}, { __mode = "k" })

local function color(fontString, c)
    if fontString then fontString:SetTextColor(c[1], c[2], c[3]) end
end

-- Spell items and headers come from a pool and are initialised through captured function
-- references, so a mixin hook would miss them. We restyle after each page layout instead.
local function styleElement(frame)
    if styled[frame] then return end
    local text = frame.TextContainer
    if text then
        styled[frame] = true
        color(text.Name, Theme.color.text)
        color(text.SubName, Theme.color.dim)
        color(text.RequiredLevel, Theme.color.dim)
    elseif frame.Text and frame.Border then
        styled[frame] = true
        color(frame.Text, Theme.color.gold)
    end
end

local function styleVisibleElements(paged)
    for _, frame in paged:EnumerateFrames() do styleElement(frame) end
end

ns.Skin:Register("SpellBook", "Blizzard_PlayerSpells", function()
    local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
    if not book then return end

    for _, key in ipairs(BOOK_ART) do ns.Skin.Hide(book[key]) end
    ns.Skin.TabSystem(book.CategoryTabSystem)

    local paged = book.PagedSpellsFrame
    if paged then
        local paging = paged.PagingControls
        if paging then color(paging.PageText, Theme.color.dim) end
        hooksecurefunc(paged, "DisplayViewsForCurrentPage", styleVisibleElements)
        styleVisibleElements(paged)
    end
end)
