local _, ns = ...

-- Mailbox (MailFrame with InboxFrame and SendMailFrame). OpenMailFrame is left out: the letter
-- body is drawn on parchment with dark text. Names verified in Gethe/wow-ui-source 12.1.5.
local Skin = ns.Skin

local BUTTONS = { "OpenAllMail", "SendMailCancelButton", "SendMailMailButton" }

ns.Skin:Register("Mail", "Blizzard_MailFrame", function()
    if not MailFrame then return end
    Skin.Panel(MailFrame)
    -- Inbox rows use light text (GameFontHighlightSmall), so the dark panel suits them.
    Skin.Hide(InboxFrameBg)
    Skin.Tab(MailFrameTab1)
    Skin.Tab(MailFrameTab2)
    for _, name in ipairs(BUTTONS) do Skin.Button(_G[name]) end
end)
