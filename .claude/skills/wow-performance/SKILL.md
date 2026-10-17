---
name: wow-performance
description: Performance-Regeln für Borometer-Lua. Laden bei jedem neuen Frame, Event-Handler, Timer, Aura- oder Nameplate-Code.
---

# Performance-Regeln

Ziel: im 20er-Raid mit aktiven Nameplates unter 1 ms Addon-CPU pro Frame im Schnitt, kein Speicherwachstum über die Zeit.

1. **Ein Event-Frame.** Events laufen über `ns.Events`. Unit-Events immer unit-gefiltert (`RegisterUnitEvent`), nie `RegisterEvent("UNIT_AURA")` für alle Units.
2. **Kein `OnUpdate` pro Frame** außer für Animation, die die Engine nicht kann. Für Gedrosseltes: `ns.Scheduler:Every(sek, fn, owner)`. Es gibt genau einen OnUpdate, der schläft, wenn nichts eingetragen ist.
3. **Engine statt Lua.** `SetTimerDuration`, `SetCooldownFromDurationObject`, Animation-Groups, `StatusBar`-Interpolation. Alles, was die Engine pro Render-Frame selbst fortschreibt, kostet kein Lua.
4. **Pools.** Aura-Icons, Nameplates, Timeline-Zeilen, Meter-Zeilen kommen aus `ns.Pool`. `CreateFrame` im Hot-Path ist ein Fehler.
5. **Keine Wegwerf-Tabellen** in Handlern. Wiederverwendbare Scratch-Tabellen, `wipe`, `select("#", ...)` statt `{...}`.
6. **Event-Bündelung.** `UNIT_AURA` liefert `updateInfo`: nur Delta verarbeiten (`addedAuras`, `updatedAuraInstanceIDs`, `removedAuraInstanceIDs`), nicht alles neu lesen.
7. **Dirty-Flags.** Handler markieren, ein gedrosselter Tick zeichnet einmal. Gilt für Raid-Frames und Meter.
8. **Lokale Referenzen** für Hot-Path-Globals (`local UnitHealth = UnitHealth`) am Dateianfang. Messwerte sind klein, aber es kostet nichts.
9. **Lazy Skins.** Skins von Load-on-Demand-Fenstern laufen erst bei `ADDON_LOADED` bzw. `OnShow` des Fensters.
10. **Messen.** `/run UpdateAddOnCPUUsage()` + `GetAddOnCPUUsage("Borometer")` (CVar `scriptProfile=1`), `/dump collectgarbage("count")`. Eigene Tests: `ns.Debug.Profile(name, fn)` in `Core/Debug.lua`.

Nie tun: String-Konkatenation pro Frame, Closures im Handler anlegen, `GetBuffDataByIndex`-Schleifen bei jedem Event, `pairs` über große Tabellen pro Tick.
