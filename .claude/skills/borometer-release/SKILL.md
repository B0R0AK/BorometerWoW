---
name: borometer-release
description: Release-Ablauf für Borometer (Version, Changelog, Tag, Paket). Nur der Leitstand nutzt das.
---

# Release

1. `main` ist grün, alle Vorhaben des Meilensteins gemerged.
2. Version in `Borometer/Borometer.toc` (`## Version:`) und `CHANGELOG.md` setzen. SemVer: Minor für Module, Patch für Fixes, Major bei SavedVariables-Bruch.
3. Interface-Nummer in der TOC (`120105` seit 12.1.5) gegen die Live-Version prüfen, siehe Patch-Seiten unter warcraft.wiki.gg (`Patch_X.Y.Z/API_changes`, Abschnitt Resources).
4. Nach Rückfrage beim Nutzer: Tag `vX.Y.Z` setzen. Die Action `.github/workflows/release.yml` zippt `Borometer/` zu `Borometer-vX.Y.Z.zip` und hängt es an das GitHub-Release.
5. Release-Notes aus dem Changelog, auf Deutsch, mit Hinweis auf bekannte Probleme.
