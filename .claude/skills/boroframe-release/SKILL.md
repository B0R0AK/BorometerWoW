---
name: boroframe-release
description: Release-Ablauf für BoroFrame (Version, Changelog, Tag, Paket). Nur der Leitstand nutzt das.
---

# Release

1. `main` ist grün, alle Vorhaben des Meilensteins gemerged.
2. Version in `BoroFrame/BoroFrame.toc` (`## Version:`) und `CHANGELOG.md` setzen. SemVer: Minor für Module, Patch für Fixes, Major bei SavedVariables-Bruch.
3. Interface-Nummer in der TOC gegen die Live-Version prüfen.
4. Nach Rückfrage beim Nutzer: Tag `vX.Y.Z` setzen. Die Action `.github/workflows/release.yml` zippt `BoroFrame/` zu `BoroFrame-vX.Y.Z.zip` und hängt es an das GitHub-Release.
5. Release-Notes aus dem Changelog, auf Deutsch, mit Hinweis auf bekannte Probleme.
