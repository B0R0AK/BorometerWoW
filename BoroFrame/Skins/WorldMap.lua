local _, ns = ...

-- World map: frame, title bar and close button only. Nothing is attached to the map
-- canvas, pins or data providers (that taints tooltips). Verified in Gethe/wow-ui-source
-- 12.1.5: WorldMapFrame.BorderFrame inherits PortraitFrameTemplateMinimizable.
local Skin, Theme = ns.Skin, ns.Theme

ns.Skin:Register("WorldMap", "Blizzard_WorldMap", function()
    local border = WorldMapFrame and WorldMapFrame.BorderFrame
    if not border then return end

    -- The border frame covers the whole map, so the background must stay transparent:
    -- a 1px edge around everything plus a filled bar behind the title.
    Skin.Hide(border.NineSlice)
    Skin.Hide(border.PortraitContainer)
    Skin.Hide(border.InsetBorderTop)
    Skin.NewBackdrop(border, { edgeOnly = true })
    Skin.NewBackdrop(border, { height = 22 })

    Skin.TitleText(border.TitleContainer and border.TitleContainer.TitleText)
    Skin.CloseButton(border.CloseButton)
    -- MaximizeMinimizeFrame and Tutorial are atlas-driven by Blizzard and stay untouched.
end)
