# BoroFrame

Komplettes UI für WoW Retail (Midnight, Interface 120105 (Patch 12.1.5)), in Lua. Ziele: leicht zu warten, schnell.
Design: Ember-Palette von Borometer (warmes Schwarz, Bernstein, Gold), definiert in `BoroFrame/Media/Theme.lua`.

## Zuerst lesen
- `docs/ARCHITEKTUR.md` Aufbau und Regeln
- `docs/WORKFLOW.md` wer baut was, mit welchem Modell
- `docs/RECHERCHE.md` API-Stand und offene Punkte, die im Spiel geprüft werden müssen
- Skills: `wow-midnight-api`, `wow-performance`, `boroframe-conventions`

## Befehle
- `bash tools/check.sh` Syntax, TOC-Abgleich, Headless-Smoke-Test (Lua 5.1, simulierte Secret Values). Vor jedem PR.
- `bash tools/fetch-refs.sh` große API-Referenzen nach `.refs/`.
- Im Spiel: `/boro` Hilfe, `/boro unlock` Frames verschieben, `/console scriptErrors 1`.
- Secrets außerhalb des Kampfes erzwingen (Tests im Spiel): `/console addonCombatRestrictionsForced 1`, ebenso `addonEncounterRestrictionsForced`, `addonChallengeModeRestrictionsForced`, `addonPvPMatchRestrictionsForced`, `addonMapRestrictionsForced`, `addonChatRestrictionsForced`. Nicht dauerhaft, nach Neustart weg.

## Harte Regeln
1. Secret Values: Rechnen, Vergleichen, `#`, Indizieren, als Tabellenschlüssel und Aufrufen wirft sofort einen Fehler. Verketten und `string.format` gehen, das Ergebnis bleibt geheim. Anzeigen heißt: unverändert an ein Engine-Widget reichen.
2. Secure-Frames im Kampf nur über `ns.Combat:Defer`.
3. Kein `OnUpdate` pro Frame. `ns.Scheduler`, Engine-Timer, Pools.
4. Farben/Fonts nur aus `ns.Theme`.
5. Nichts, was nicht im Spiel getestet werden kann, als fertig melden. Offene Prüfungen kommen in den PR.
