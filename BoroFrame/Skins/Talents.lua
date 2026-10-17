-- Talent tabs of PlayerSpellsFrame: specialization, class talents, hero talent choice dialog.
-- Talent node buttons and the per-spec background art are left alone on purpose.
local _, ns = ...

local Skin = ns.Skin
local Theme = ns.Theme

-- Activate buttons live in frame pools that refill on every layout, so hook the refill.
local function skinSpecButtons(specFrame)
    for content in specFrame.SpecContentFramePool:EnumerateActive() do
        Skin.Button(content.ActivateButton)
    end
end

local function skinHeroButtons(dialog)
    for content in dialog.SpecContentFramePool:EnumerateActive() do
        Skin.Button(content.ActivateButton)
    end
end

ns.Skin:Register("Talents", "Blizzard_PlayerSpells", function()
    local frame = PlayerSpellsFrame
    if not frame then return end

    local spec = frame.SpecFrame
    if spec then
        Skin.Hide(spec.Background)
        Skin.Fill(spec.BlackBG, Theme.color.pitch)
        if type(spec.UpdateSpecContents) == "function" then
            hooksecurefunc(spec, "UpdateSpecContents", skinSpecButtons)
        end
        skinSpecButtons(spec)
    end

    local talents = frame.TalentsFrame
    if talents then
        Skin.Fill(talents.BlackBG, Theme.color.pitch)
        Skin.Fill(talents.BottomBar, Theme.color.comb)
        Skin.Button(talents.ApplyButton)
        Skin.Button(talents.InspectCopyButton)
    end

    local hero = HeroTalentsSelectionDialog
    if hero then
        Skin.Panel(hero)
        Skin.CloseButton(hero.CloseButton)
        if type(hero.ShowDialog) == "function" then
            hooksecurefunc(hero, "ShowDialog", skinHeroButtons)
        end
    end
end)
