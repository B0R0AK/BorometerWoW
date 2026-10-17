local _, ns = ...

SLASH_BOROMETER1 = "/borometer"
SLASH_BOROMETER2 = "/bm"

local help = {
    "/bm unlock - Frames verschieben an/aus",
    "/bm module <name> on|off - Modul schalten",
    "/bm modules - Module auflisten",
    "/bm resetpos - Positionen zurücksetzen",
    "/bm reset - Profil zurücksetzen (lädt neu)",
}

SlashCmdList.BOROMETER = function(msg)
    local cmd, a, b = strsplit(" ", strtrim(msg or ""))
    cmd = (cmd or ""):lower()
    if cmd == "unlock" then
        ns.Mover:Toggle()
    elseif cmd == "resetpos" then
        ns.Mover:ResetAll()
    elseif cmd == "reset" then
        ns.Config:Reset()
    elseif cmd == "modules" then
        for name, m in pairs(ns.modules) do
            ns.Debug.Print(name, m:IsEnabled() and "|cff8cc169an|r" or "|cffe0644faus|r")
        end
    elseif cmd == "module" and a and ns.modules[a] and (b == "on" or b == "off") then
        ns.Config:SetModuleEnabled(a, b == "on")
    else
        for _, line in ipairs(help) do ns.Debug.Print(line) end
    end
end
