---
name: boroframe-conventions
description: Code- und Ordnerkonventionen für BoroFrame. Laden vor jeder Änderung am Addon.
---

# Konventionen

- Sprache im Code: Englisch (Bezeichner, Kommentare). Doku und Issues: Deutsch.
- Eine Datei = eine Aufgabe, unter 400 Zeilen. Kommentar nur für das Warum.
- Namespace: `local ADDON, ns = ...`. Keine Globals außer `BoroFrameDB` (SavedVariables) und den Slash-Commands.
- Ordner: `Core/` (Infrastruktur, kritisch), `Media/` (Theme, Texturen), `Modules/<Name>/` (Features), `Skins/` (Blizzard-Fenster, eine Gruppe pro Datei).
- Module: `local M = ns:NewModule("UnitFrames")` mit `M:OnInitialize()`, `M:OnEnable()`, `M:OnDisable()`. Defaults über `ns.Config:Register("unitframes", {...})`.
- Farben/Fonts/Abstände nur aus `ns.Theme` (Ember-Palette, Design wie Borometer: warmes Schwarz, Bernstein, Gold).
- Keine fremden Bibliotheken ohne Issue. Wir brauchen LibStub nur für LibSharedMedia (optional).
- Kampf: Secure-Frames nur über `ns.Combat:Defer`.
- Jede Änderung: `tools/check.sh` (Syntax + Stil + Smoke-Test) grün, Changelog-Zeile in `CHANGELOG.md`.
- Commits: `<modul>: <was>` im Imperativ, ein Thema pro Commit.
