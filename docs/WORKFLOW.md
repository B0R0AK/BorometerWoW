# Workflow: Leitstand und Vorhaben

**Leitstand** (Fable): erstellt Vorhaben als GitHub-Issues, startet Builder, prüft, mergt, released. Schreibt keinen Feature-Code.
**Vorhaben** (Builder): setzen genau ein Issue um, im eigenen Worktree und Branch, öffnen einen PR.

## Modellwahl
| Modell | Wann | Agent |
|---|---|---|
| Sonnet | Schema steht schon: Skins nach Vorlage, Optionen, Lokalisierung, Doku, Packaging | `builder-leicht` |
| Opus | eigene Logik, mehrere Dateien: Unit-Frame-Elemente, Auren, Cooldown-Manager, Nameplates, Timeline, Meter-Skin, Inventar | `builder-komplex`, `reviewer` |
| Fable | Fehler hier sind teuer: alles in `Core/`, Secret-/Taint-Grenzen, Secure-Header (Party/Raid), Migrationen, Release, Leitstand selbst | `builder-kritisch`, `leitstand` |

Faustregel: Berührt es Secret Values in neuer Weise, Secure-Frames im Kampf oder SavedVariables-Struktur, geht es eine Stufe hoch.

## Ablauf pro Vorhaben
1. Leitstand legt das Issue an (`docs/vorhaben/_TEMPLATE.md`), Label `modell:*`.
2. Builder arbeitet auf `vorhaben/<nr>-<kurz>`, ruft `bash tools/check.sh` auf.
3. PR mit Vorlage. Reviewer prüft, rote Punkte blockieren.
4. Leitstand mergt (Squash). Core zuerst, abhängige Vorhaben danach.
5. Release: Skill `boroframe-release`. Der Leitstand fragt vor dem Release beim Nutzer nach.

## Parallelität
Module sind unabhängig, sie hängen nur an `Core/`. Core-Änderungen laufen einzeln und zuerst.
