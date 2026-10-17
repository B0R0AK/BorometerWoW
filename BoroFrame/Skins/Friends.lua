local _, ns = ...

-- Friends window (FriendsFrame, Blizzard_FriendsFrame): shell, bottom tabs, buttons, ignore
-- list window. List rows, the header tab system (Friends/Recent Allies/RAF) and dropdowns keep
-- Blizzard art: they are rebuilt dynamically and dropdown hooks are a taint risk.
local Skin = ns.Skin

local BUTTONS = {
    "FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton",
    "WhoFrameGroupInviteButton", "WhoFrameAddFriendButton", "WhoFrameWhoButton",
}

ns.Skin:Register("FriendsList", "Blizzard_FriendsFrame", function()
    local frame = FriendsFrame
    if not frame then return end
    Skin.Window(frame)
    for i = 1, 4 do Skin.Tab(_G["FriendsFrameTab" .. i]) end
    for _, name in ipairs(BUTTONS) do Skin.ActionButton(_G[name]) end
    Skin.Inset(WhoFrameListInset)

    local ignore = frame.IgnoreListWindow
    if ignore then
        Skin.Window(ignore)
        Skin.ActionButton(ignore.UnignorePlayerButton)
    end
end)
