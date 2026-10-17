local _, ns = ...

-- Collections journal: mounts, pets, toys, heirlooms, appearances (wardrobe), warband scenes.
-- Frame names and parentKeys were checked against Gethe/wow-ui-source, Blizzard_Collections.
-- Only appearance is changed. List rows, model scenes and spell buttons keep Blizzard art.
local Skin = ns.Skin

local TABS = {
    "CollectionsJournal.MountsTab", "CollectionsJournal.PetsTab", "CollectionsJournal.ToysTab",
    "CollectionsJournal.HeirloomsTab", "CollectionsJournal.WardrobeTab",
    "CollectionsJournal.WarbandScenesTab",
    "WardrobeCollectionFrame.ItemsTab", "WardrobeCollectionFrame.SetsTab",
}

local INSETS = {
    "MountJournal.LeftInset", "MountJournal.BottomLeftInset", "MountJournal.RightInset",
    "MountJournal.MountCount",
    "PetJournal.PetCount", "PetJournal.LeftInset", "PetJournal.PetCardInset", "PetJournal.RightInset",
    "ToyBox.iconsFrame", "HeirloomsJournal.iconsFrame",
    "WardrobeCollectionFrame.ItemsCollectionFrame",
    "WardrobeCollectionFrame.SetsCollectionFrame.LeftInset",
    "WardrobeCollectionFrame.SetsCollectionFrame.RightInset",
    "WarbandSceneJournal.IconsFrame",
}

local SEARCH_BOXES = {
    "MountJournal.searchBox", "PetJournal.searchBox", "ToyBox.searchBox",
    "HeirloomsJournal.SearchBox", "WardrobeCollectionFrame.SearchBox",
}

local DROPDOWNS = {
    "MountJournal.FilterDropdown", "PetJournal.FilterDropdown", "ToyBox.FilterDropdown",
    "HeirloomsJournal.FilterDropdown", "HeirloomsJournal.ClassDropdown",
    "WardrobeCollectionFrame.FilterButton", "WardrobeCollectionFrame.ClassDropdown",
    "WardrobeCollectionFrame.ItemsCollectionFrame.WeaponDropdown",
    "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.VariantSetsDropdown",
}

local PROGRESS_BARS = {
    "ToyBox.progressBar", "HeirloomsJournal.progressBar", "WardrobeCollectionFrame.progressBar",
}

local SCROLL_BARS = {
    "MountJournal.ScrollBar", "PetJournal.ScrollBar",
    "WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBar",
}

local BUTTONS = {
    "MountJournal.MountButton", "PetJournal.FindBattleButton", "PetJournal.SummonButton",
}

ns.Skin:Register("Collections", "Blizzard_Collections", function()
    Skin.PortraitFrame(CollectionsJournal)
    Skin.Apply(Skin.Tab, TABS)
    Skin.Apply(Skin.Inset, INSETS)
    Skin.Apply(Skin.EditBox, SEARCH_BOXES)
    Skin.Apply(Skin.Dropdown, DROPDOWNS)
    Skin.Apply(Skin.StatusBar, PROGRESS_BARS)
    Skin.Apply(Skin.ScrollBar, SCROLL_BARS)
    Skin.Apply(Skin.PanelButton, BUTTONS)
end)
