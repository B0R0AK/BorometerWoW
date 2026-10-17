std = "lua51"
max_line_length = 140
exclude_files = { "BoroFrame/Skins/_Template.lua" }
ignore = { "212/self", "212/_.*", "611" }
globals = { "BoroFrameDB", "SlashCmdList", "SLASH_BOROFRAME1", "SLASH_BOROFRAME2" }
read_globals = {
    "CreateFrame", "UIParent", "C_Timer", "C_AddOns", "InCombatLockdown", "Mixin", "wipe", "strtrim", "strsplit",
    "BackdropTemplateMixin", "STANDARD_TEXT_FONT", "GetRealmName", "UnitName", "ReloadUI", "debugprofilestop",
    "issecretvalue", "RegisterUnitWatch", "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitPower",
    "UnitPowerMax", "UnitPowerType", "UnitGetTotalAbsorbs", "UnitIsPlayer", "UnitClass", "UnitReaction",
    "AbbreviateNumbers", "CurveConstants", "RAID_CLASS_COLORS", "FACTION_BAR_COLORS", "PowerBarColor",
    "PlayerFrame", "TargetFrame", "FocusFrame", "BossTargetFrameContainer",
}
