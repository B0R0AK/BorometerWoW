local _, ns = ...

-- Adventure Guide: dungeon/raid journal, journeys, monthly activities, loot tables.
-- Frame names and parentKeys were checked against Gethe/wow-ui-source, Blizzard_EncounterJournal.
-- Instance art, boss buttons, loot rows and the side tabs (icon art) keep Blizzard textures.
local Skin = ns.Skin

local TABS = {
    "EncounterJournal.JourneysTab", "EncounterJournal.MonthlyActivitiesTab",
    "EncounterJournal.suggestTab", "EncounterJournal.dungeonsTab", "EncounterJournal.raidsTab",
    "EncounterJournal.LootJournalTab", "EncounterJournal.TutorialsTab",
}

local DROPDOWNS = {
    "EncounterJournal.LootJournalViewDropdown",
    "EncounterJournal.instanceSelect.ExpansionDropdown",
    "EncounterJournal.encounter.info.difficulty",
    "EncounterJournal.encounter.info.LootContainer.filter",
    "EncounterJournal.encounter.info.LootContainer.slotFilter",
    "EncounterJournal.LootJournal.ClassDropdown",
    "EncounterJournal.LootJournal.RuneforgePowerDropdown",
    "EncounterJournal.LootJournalItems.ItemSetsFrame.ClassDropdown",
}

local SCROLL_BARS = {
    "EncounterJournal.instanceSelect.ScrollBar",
    "EncounterJournal.encounter.instance.LoreScrollBar",
    "EncounterJournal.encounter.info.BossesScrollBar",
    "EncounterJournal.encounter.info.LootContainer.ScrollBar",
    "EncounterJournal.JourneysFrame.ScrollBar",
    "EncounterJournal.MonthlyActivitiesFrame.ScrollBar",
    "EncounterJournal.LootJournal.ScrollBar",
    "EncounterJournal.LootJournalItems.ItemSetsFrame.ScrollBar",
}

ns.Skin:Register("EncounterJournal", "Blizzard_EncounterJournal", function()
    Skin.PortraitFrame(EncounterJournal)
    Skin.Apply(Skin.Tab, TABS)
    Skin.Inset_e(EncounterJournal.inset)
    Skin.EditBox(EncounterJournal.searchBox)
    Skin.Apply(Skin.Dropdown, DROPDOWNS)
    Skin.Apply(Skin.ScrollBar, SCROLL_BARS)
end)
