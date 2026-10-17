local _, ns = ...

-- Chat windows: background, border art, tabs, edit box art. Visual only.
-- The edit box gets no hooks, no mixin and no attribute access (WoWUIBugs #876: touching it
-- in M+/chat lockdown makes its attributes permanently secret). Only texture alpha and a
-- separate backdrop child frame are used.
local Theme = ns.Theme

local done = setmetatable({}, { __mode = "k" })

-- Regions of FloatingBorderedFrame, named "<ChatFrameN><suffix>" (Blizzard_ChatFrameBase).
local BORDER_SUFFIX = {
    "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture",
    "ButtonFrameBackground", "ButtonFrameTopLeftTexture", "ButtonFrameBottomLeftTexture",
    "ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture",
    "ButtonFrameLeftTexture", "ButtonFrameRightTexture",
}
-- Regions of ChatFrameEditBoxTemplate: $parentLeft/Right/Mid and the focus variants.
local EDITBOX_SUFFIX = { "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }
local TAB_CLEAR = { "Left", "Middle", "Right", "HighlightLeft", "HighlightMiddle", "HighlightRight" }
local TAB_ACTIVE = { "ActiveLeft", "ActiveMiddle", "ActiveRight" }

local function skinFrame(name)
    -- Blizzard re-applies alpha and vertex color to these (chat window settings), so the
    -- borders are hidden outright and only the background texture is swapped.
    for _, suffix in ipairs(BORDER_SUFFIX) do
        local tex = _G[name .. suffix]
        if tex then tex:Hide() end
    end
    local bg = _G[name .. "Background"]
    if bg then
        local c = Theme.color.pitch
        bg:SetColorTexture(c[1], c[2], c[3], 1)
    end
end

local function skinEditBox(editBox, name)
    for _, suffix in ipairs(EDITBOX_SUFFIX) do
        local tex = _G[name .. suffix]
        if tex then tex:SetAlpha(0) end
    end
    -- Backdrop lives on a child frame so the edit box itself stays untouched.
    local back = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
    back:SetFrameLevel(math.max(0, editBox:GetFrameLevel() - 1))
    back:SetPoint("TOPLEFT", 0, -4)
    back:SetPoint("BOTTOMRIGHT", 0, 4)
    Theme:Backdrop(back)
end

local function skinTab(tab)
    -- Alpha, not Hide: Blizzard anchors the temporary-window tab text to tab.Left.
    for _, key in ipairs(TAB_CLEAR) do
        local tex = tab[key]
        if tex then tex:SetAlpha(0) end
    end
    -- Selected marker: Blizzard shows/hides these and tints them with the window color.
    local a = Theme.color.amber
    for _, key in ipairs(TAB_ACTIVE) do
        local tex = tab[key]
        if tex then tex:SetColorTexture(a[1], a[2], a[3], 0.35) end
    end
end

local function skinWindow(i, withEditBox)
    local name = "ChatFrame" .. i
    local frame = _G[name]
    if not frame or done[frame] then return end
    done[frame] = true
    skinFrame(name)
    local tab = _G[name .. "Tab"]
    if tab then skinTab(tab) end
    if withEditBox and frame.editBox then skinEditBox(frame.editBox, name .. "EditBox") end
end

ns.Skin:Register("Chat", "Blizzard_ChatFrameBase", function()
    -- ChatFrame1-10 always exist. Their edit boxes are skinned once, here, never later.
    for i = 1, 10 do skinWindow(i, true) end
    -- Temporary (whisper) windows are created on demand. Their edit boxes stay untouched.
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        local i = 11
        while _G["ChatFrame" .. i] do
            skinWindow(i, false)
            i = i + 1
        end
    end)
end)
