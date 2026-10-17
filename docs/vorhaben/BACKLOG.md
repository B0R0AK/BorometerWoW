# Backlog

Modell: S = Sonnet, O = Opus, F = Fable. Abhängigkeiten in Klammern.

| ID | Vorhaben | Modell | Abh. |
|---|---|---|---|
| V01 | Core + Unit-Frame-Durchstich (Player, Target, ToT, Focus, Boss) | F | – (fertig im Gründungs-PR) |
| V02 | Cast-Balken (Player, Target, Boss, Focus), `SetTimerDuration`, Nicht-unterbrechbar | O | V01 |
| V03 | Auren-Element: Pool, Delta-Verarbeitung, Duration-Objekte, Filter | O | V01 |
| V04 | Frame-Extras: Klassenressourcen, Heilvorhersage, Raid-Marker, Status-Icons, Tot/Offline | O | V01 |
| V05 | Party-Frames (SecureGroupHeader, Rollen, Dispel, Aggro) | F | V01, V03 |
| V06 | Raid-Frames (bis 40, Gruppen, Dirty-Flag-Batching, Performance-Test) | F | V05 |
| V07 | Cooldown Manager: Blizzard-Viewer skinnen, positionieren, Tracking-Leisten | O | V01 |
| V08 | Boss-Timeline: eigener Renderer auf `C_EncounterTimeline` (`SetViewType(None)`, `GetSortedEventList`, `GetEventTimer` + `SetTimerDuration`), Warnungen (`C_EncounterWarnings`) | O | V01 |
| V09 | BigWigs: Quelle `BigWigs_StartBar/Pause/Resume/Stop` für Boss-Module mit eigenen Timern, Moduswechsel (`enhanced`/`blizzbars`/`blizztimeline`), Bar-Style `BoroFrame` über `BigWigsAPI:RegisterBarStyle` | O | V08 |
| V10 | Nameplates: eigenes Plate, Auren, Cast, Bedrohung, Blizzard-Plate ausblenden | O | V02, V03 |
| V11 | Damage-Meter-Skin (`C_DamageMeter`-Fenster) | O | V01 |
| V12 | Inventar: kombinierte Taschen, Suche, Sortierung, Bank, Skin | O | V01 |
| V13a | Skins: Charakter, Inspektion, Ruf, Währungen | S | V01 |
| V13b | Skins: Zauberbuch, Talente, Berufe | S | V01 |
| V13c | Skins: Karte, Quests, Gossip, Händler, Post | S | V01 |
| V13d | Skins: Chat, Freunde, Gilde, Gruppensuche | S | V01 |
| V13e | Skins: Sammlungen, Abenteuerführer, Dungeonjournal | S | V01 |
| V13f | Skins: Tooltips, Menüs, Popups, Edit Mode | S | V01 |
| V14 | Aktionsleisten, Mikromenü, Minimap, Spieler-Buffs/Debuffs | O | V01 |
| V15 | Optionen-Fenster (Module, Frame-Größen, Skins, Profile) | O | V01 |
| V16 | Profil-Export/Import (`C_EncodingUtil`) und Migrationen | F | V15 |
| V17 | Lokalisierung de/en | S | V15 |
| V18 | Release-Automatisierung, Packaging, CurseForge/Wago | S | V01 |

Reihenfolge der Wellen: **1** V02, V03, V04, V07, V08, V11, V13a–f (parallel) · **2** V05, V09, V10, V12, V14, V15 · **3** V06, V16, V17, V18.
