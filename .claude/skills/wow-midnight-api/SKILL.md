---
name: wow-midnight-api
description: WoW Retail Midnight (12.0.x) API-Wissen für BoroFrame. Laden bei jeder Arbeit an Frames, Auren, Cooldowns, Casts, Nameplates, Damage Meter, Boss-Timeline oder Secret Values.
---

# WoW Midnight API (Interface 120005)

Lua 5.1 plus XML. Seit 12.0 gibt es **Secret Values**: Kampfdaten kommen als undurchsichtige Werte zurück. Addon-Code darf sie nicht vergleichen, nicht rechnen, nicht verketten, nicht als Tabellenschlüssel nutzen. Er darf sie an Engine-Widgets weiterreichen.

## Grundregel
Zeige geheime Werte an, **entscheide** nie damit. Der Wert geht unverändert an das Widget.

| Anzeige | Secret-sicher |
|---|---|
| Balken Leben/Power | `bar:SetMinMaxValues(0, UnitHealthMax(u))`, `bar:SetValue(UnitHealth(u))` |
| Text | `fs:SetFormattedText("%s", secret)`, `AbbreviateNumbers(secret)` gibt nicht-geheimen String |
| Prozent | `UnitHealthPercent(u, false, CurveConstants.ScaleTo100)`, `UnitPowerPercent(...)` sind nicht geheim |
| Cooldown-Swipe | nur `Cooldown:SetCooldownFromDurationObject(obj)`; `SetCooldown` & Co. sind eingeschränkt |
| Spell-Cooldown | `C_Spell.GetSpellCooldownDuration(id)` liefert ein Duration-Objekt |
| Aura-Dauer | `C_UnitAuras.GetAuraDuration(unit, auraInstanceID)` |
| Cast-Balken | `UnitCastingDuration(u)` / `UnitChannelDuration(u)` + `bar:SetTimerDuration(obj)` |
| Farbe nach Wert | `ColorCurve` / `Curve` auswerten lassen, nicht per `if` |
| Sichtbarkeit nach Bool | `Frame:SetAlphaFromBoolean(secretBool, a1, a2)` |

## Prüfen
`issecretvalue(v)`, `canaccessvalue(v)`, `hasanysecretvalues(...)`, `scrubsecretvalues(...)`. `InCombatLockdown()` reicht nicht als Schutz, Taint erzeugt Secrets auch außerhalb des Kampfes. Bei jedem Wert, mit dem Lua rechnen muss, zuerst über `ns.IsSecret` gehen.

## Nicht mehr da
- `COMBAT_LOG_EVENT_UNFILTERED` für Addons: weg. Stattdessen Unit-Events (`UNIT_SPELLCAST_*`, `UNIT_AURA`, `UNIT_HEALTH`) und `C_DamageMeter`.
- Addon-Nachrichten in Instanzen sind eingeschränkt.
- Namen/GUIDs/Unit-Token können in PvP und bei Nameplates/Boss/Party-Tokens geheim sein (12.0.5 strenger). Nicht per `==` vergleichen.

## Systeme, die wir nutzen
- **Cooldown Manager**: `C_CooldownViewer`, Blizzards Viewer-Frames (`EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`). Wir **skinnen und positionieren** sie, wir ersetzen die Datenquelle nicht. Taint-Fallen: Referenz `13_Cooldown_Viewer_Guide.md`.
- **Boss-Timeline**: `C_EncounterTimeline` (Events, Phasen, Script-Events) und `C_EncounterWarnings`. BigWigs/DBM speisen in Midnight dieselbe Quelle. Der BigWigs-Adapter muss im Spiel verifiziert werden (siehe `docs/RECHERCHE.md`).
- **Damage Meter**: `C_DamageMeter`. Werte im Kampf geheim, also nur Engine-Widgets. Wir skinnen Blizzards Meter-Fenster (`DamageMeter`), bauen keinen eigenen Parser.
- **Nameplates**: `C_NamePlate.GetNamePlateForUnit`, Blizzard-`UnitFrame` ausblenden, eigenes Plate mit Aura-Filter `INCLUDE_NAME_PLATE_ONLY`.

## Tiefer nachschlagen
- `references/secret-values.md`, `api-migration-12.md`, `lua-api-quick-ref.md`, `widget-framework.md`, `toc-structure.md` (MIT, Quelle `DennysOliveira/wow-addon-dev`).
- `bash tools/fetch-refs.sh` klont die große Referenz `Amadeus-/WoWAddonDevGuide` nach `.refs/` (nicht eingecheckt): `12a_Secret_Safe_APIs.md`, `13_Cooldown_Viewer_Guide.md`, `01_API_Reference.md`.
- Blizzards eigener Code: `Gethe/wow-ui-source`. Im Spiel: `/api` bzw. `Blizzard_APIDocumentation`.

Die gelesenen Referenzen sind teils von KI erzeugt. Was Taint-Verhalten angeht, gilt der Test im Spiel, nicht die Referenz.
