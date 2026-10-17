---
name: borometer-conventions
description: Code- und Ordnerkonventionen für Borometer (WoW-Addon). Laden vor jeder Änderung am Addon.
---

# Konventionen

- Sprache im Code: Englisch (Bezeichner, Kommentare). Doku und Issues: Deutsch.
- Eine Datei = eine Aufgabe, unter 400 Zeilen. Kommentar nur für das Warum.
- Namespace: `local ADDON, ns = ...`. Keine Globals außer `BorometerDB` (SavedVariables) und den Slash-Commands.
- Ordner: `Core/` (Infrastruktur, kritisch), `Media/` (Theme), `Modules/<Name>/` (Features), `Skins/Common.lua` (Hilfsfunktionen für Skins).
- Module: `local M = ns:NewModule("Name")` mit `M:OnInitialize()`, `M:OnEnable()`, `M:OnDisable()`. Defaults über `ns.Config:Register("name", {...})`.
- Farben/Fonts/Abstände nur aus `ns.Theme` (Ember-Palette aus dem Borometer: warmes Schwarz, Bernstein, Gold).
- Keine fremden Bibliotheken ohne Issue.
- Kampf: Alles, was Secure-Frames ändert, nur über `ns.Combat:Defer`. Nach dem Kampf darf Lua Zahlen aus `C_DamageMeter` lesen und rechnen, im Kampf nie (`SecretWhenInCombat`).
- Jede Änderung: `bash tools/check.sh` grün (Exit-Code prüfen, nicht nur filtern), Changelog-Zeile in `CHANGELOG.md`.
- Commits: `<modul>: <was>` im Imperativ, ein Thema pro Commit.
