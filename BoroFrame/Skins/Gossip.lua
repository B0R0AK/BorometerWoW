local _, ns = ...

-- Gossip window (GossipFrame, inherits ButtonFrameTemplate). The parchment background and
-- the scroll list stay as they are: gossip text is colored for the parchment by Blizzard.
local Skin = ns.Skin

ns.Skin:Register("Gossip", nil, function()
    if not GossipFrame then return end
    Skin.Panel_c(GossipFrame)
    local greeting = GossipFrame.GreetingPanel
    if greeting then Skin.Button(greeting.GoodbyeButton) end
end)
