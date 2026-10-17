# Architektur

```
Borometer/                das Addon (wird gezippt)
  Borometer.toc
  Core/                   Infrastruktur, kritisch (Fable)
    Init.lua              Namespace, Modul-System, ns.IsSecret
    Debug.lua             Guard (Fehlergrenze, einmal melden), Profile
    Events.lua            ein Event-Frame für globale Events
    Scheduler.lua         ein OnUpdate, schläft ohne Aufgaben
    Pool.lua              Objekt-Pools
    Combat.lua            Defer-Queue für Secure-Änderungen im Kampf
    Config.lua            SavedVariables (BorometerDB), Profile, additive Defaults, Migrationen
    Mover.lua             gespeicherte Positionen, Unlock-Modus (für eigene Fenster)
    Skin.lua              Skin-Registry, lazy pro Blizzard-Addon
    Slash.lua             /bm, /borometer
  Media/Theme.lua         Ember-Palette, Fonts, Backdrop-Helfer
  Skins/Common.lua        Frame/Button-Helfer für Skins
  Modules/
    DamageMeterSkin/      Blizzards DamageMeter im Borometer-Design (fertig, ungetestet im Spiel)
    (geplant) History, Ring, Breakdown, Live, Optionen, siehe docs/vorhaben/BACKLOG.md
tools/                    check.sh, Smoke-Test, Referenzen
```

## Datenquelle: `C_DamageMeter`
- `IsDamageMeterAvailable()`, `GetAvailableCombatSessions()` (`sessionID`, `name`, `durationSeconds`), `GetCombatSessionFromType(sessionType, meterType)` und `…FromID(sessionID, meterType)` liefern `combatSources` (Spieler/Gegner), `GetCombatSessionSourceFromType/FromID(…, sourceGUID, sourceCreatureID)` liefert `combatSpells` (Zauber, Summe, pro Sekunde, Overkill).
- `Enum.DamageMeterSessionType`: Overall, Current, Expired. `Enum.DamageMeterType`: DamageDone, Dps, HealingDone, Hps, Absorbs, Interrupts, Dispels, DamageTaken, AvoidableDamageTaken, Deaths, EnemyDamageTaken.
- Events: `DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID)`, `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `DAMAGE_METER_RESET`.
- **Secret-Regel:** Die Sitzung ist `SecretWhenInCombat`. Im Kampf sind Summen, DPS und Namen geheim (`name` und `sourceGUID` bedingt), nie geheim sind `classFilename`, `specIconID`, `isLocalPlayer`, `classification`, `deathRecapID`. Nach dem Kampf ist alles Klartext.

## Zwei Betriebsarten
1. **Im Kampf (Live):** nur Engine-Widgets. Balken über `StatusBar:SetMinMaxValues(0, session.maxAmount)` und `SetValue(source.totalAmount)`, Text über `SetFormattedText`/Kurzzahl-Formatter, Klassenfarbe aus `classFilename`. Reihenfolge ist die der API (nicht in Lua sortieren, Vergleiche gehen nicht).
2. **Nach dem Kampf (Auswertung):** auf `PLAYER_REGEN_ENABLED` (mit kurzer Verzögerung) die Sitzung lesen, Werte mit `issecretvalue` prüfen, **in eigene Tabellen kopieren** und erst dann rechnen: Anteile, Ring, Rangliste, Fähigkeiten. Optional als Verlauf in `BorometerDB` ablegen.

## Modul-Vertrag
```lua
local M = ns:NewModule("Name")
ns.Config:Register("name", { ...defaults... })   -- beim Laden der Datei
function M:OnEnable() end
function M:OnDisable() end                        -- oder: "wirkt nach /reload" dokumentieren
```
Module sprechen nur über `ns.*` Core-Dienste miteinander, nie über Globals.
