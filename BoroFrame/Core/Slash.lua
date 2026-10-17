local _, ns = ...

SLASH_BOROFRAME1 = "/boro"
SLASH_BOROFRAME2 = "/boroframe"

local help = {
    "/boro unlock - Frames verschieben an/aus",
    "/boro module <name> on|off - Modul schalten",
    "/boro modules - Module auflisten",
    "/boro resetpos - Positionen zurücksetzen",
    "/boro reset - Profil zurücksetzen (lädt neu)",
}

SlashCmdList.BOROFRAME = function(msg)
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
