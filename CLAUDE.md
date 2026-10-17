# BoroFrame

Komplettes UI für WoW Retail (Midnight, Interface 120005), in Lua. Ziele: leicht zu warten, schnell.
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

## Harte Regeln
1. Secret Values nie vergleichen, rechnen, verketten, indizieren. Nur an Engine-Widgets reichen.
2. Secure-Frames im Kampf nur über `ns.Combat:Defer`.
3. Kein `OnUpdate` pro Frame. `ns.Scheduler`, Engine-Timer, Pools.
4. Farben/Fonts nur aus `ns.Theme`.
5. Nichts, was nicht im Spiel getestet werden kann, als fertig melden. Offene Prüfungen kommen in den PR.
