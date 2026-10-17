# Borometer (WoW)

Damage-Meter-Addon für WoW Retail (Midnight, Interface 120105 = Patch 12.1.5), in Lua. Name des Addons: **Borometer**, Repo: **BorometerWoW**. Das Repo trug früher den Namen BoroFrame (ein größeres UI, das aufgegeben wurde).
Aufgabe: (1) Blizzards eingebautes Damage Meter im Borometer-Design skinnen, (2) eigene Zusatzanzeigen auf Basis von `C_DamageMeter`, vor allem eine Auswertung nach dem Kampf (Ring, Anteile, Fähigkeiten) wie im Borometer für Throne and Liberty.
Design: Ember-Palette (warmes Schwarz, Bernstein, Gold), `Borometer/Media/Theme.lua`.

## Zuerst lesen
- `docs/ARCHITEKTUR.md` Aufbau und Datenmodell
- `docs/WORKFLOW.md` wer baut was, mit welchem Modell
- `docs/RECHERCHE.md` geprüfter API-Stand und offene Punkte, die im Spiel getestet werden müssen
- Skills: `wow-midnight-api`, `wow-performance`, `borometer-conventions`

## Befehle
- `bash tools/check.sh` Syntax, TOC-Abgleich, Headless-Smoke-Test (Lua 5.1, simulierte Secret Values). Vor jedem PR. Exit-Code prüfen.
- `bash tools/fetch-refs.sh` Blizzards UI-Code, BigWigs und Community-Referenzen nach `.refs/`.
- Im Spiel: `/bm` (oder `/borometer`) Hilfe, `/console scriptErrors 1`.
- Secrets außerhalb des Kampfes erzwingen (Tests im Spiel): `/console addonCombatRestrictionsForced 1`, ebenso `addonEncounterRestrictionsForced`, `addonChallengeModeRestrictionsForced`, `addonPvPMatchRestrictionsForced`, `addonMapRestrictionsForced`, `addonChatRestrictionsForced`. Nicht dauerhaft.

## Harte Regeln
1. `C_DamageMeter`-Sitzungen sind **im Kampf geheim** (`SecretWhenInCombat`), danach Klartext. Im Kampf: Rechnen, Vergleichen, `#`, Indizieren, Tabellenschlüssel, Aufrufen wirft einen Fehler; Verketten und `string.format` gehen, das Ergebnis bleibt geheim. Anzeigen heißt: unverändert an ein Engine-Widget reichen.
2. Eigene Auswertungen nur mit nicht geheimen Daten: erst nach `PLAYER_REGEN_ENABLED` lesen und mit `issecretvalue` prüfen, dann in eigene Tabellen kopieren.
3. Secure-Frames im Kampf nur über `ns.Combat:Defer`.
4. Kein `OnUpdate` pro Frame. `ns.Scheduler`, Engine-Timer, Pools.
5. Farben/Fonts nur aus `ns.Theme`.
6. Nichts, was nicht im Spiel getestet werden kann, als fertig melden. Offene Prüfungen kommen in den PR.
