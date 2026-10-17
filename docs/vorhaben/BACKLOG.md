# Backlog Borometer (WoW)

Modell: S = Sonnet, O = Opus, F = Fable. Abhängigkeiten in Klammern. Alle Vorhaben brauchen Prüfungen im Spiel, siehe `docs/RECHERCHE.md`.

| ID | Vorhaben | Modell | Abh. |
|---|---|---|---|
| M01 | Core und Damage-Meter-Skin (Skin für Blizzards `DamageMeter`) | F/O | fertig, im Spiel ungeprüft |
| M02 | Datenschicht: Sitzungen lesen (`C_DamageMeter`), nach dem Kampf Klartext kopieren, `ns.Data` mit Sitzungs-Snapshots, Tests mit Secret-Attrappen | F | M01 |
| M03 | Auswertung nach dem Kampf: Rangliste, Anteile, DPS/HPS, Typwahl (Schaden, Heilung, Unterbrechungen, Tode …) | O | M02 |
| M04 | Ring-Ansicht (Glutring wie im Borometer) mit Fähigkeiten-Bögen und Quellenliste | O | M03 |
| M05 | Fähigkeiten-Aufschlüsselung je Quelle (`GetCombatSessionSource…`), Overkill, Anteile | O | M03 |
| M06 | Verlauf: Kämpfe als Snapshots in `BorometerDB`, Kampfwahl, Obergrenze und Aufräumen | F | M02 |
| M07 | Live-Anzeige im Kampf: eigene Balkenliste nur mit Engine-Widgets, Reihenfolge der API | O | M01 |
| M08 | Tode und Todesbericht (`Deaths`, `deathRecapID`) | O | M03 |
| M09 | Optionen-Fenster (Skin an/aus, Ansichten, Größen, Profile) | O | M03 |
| M10 | Lokalisierung de/en | S | M09 |
| M11 | Release-Automatisierung, Packaging (CurseForge/Wago), Repo-Umbenennung nachziehen | S | M01 |

Reihenfolge: **1** M02, M07 · **2** M03, M06 · **3** M04, M05, M08, M09 · **4** M10, M11.
