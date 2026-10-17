---
name: wow-midnight-api
description: WoW Retail Midnight (12.1.x) API-Wissen für BoroFrame, geprüft gegen warcraft.wiki.gg und Blizzards UI-Quellcode. Laden bei jeder Arbeit an Frames, Auren, Cooldowns, Casts, Nameplates, Damage Meter, Boss-Timeline oder Secret Values.
---

# WoW Midnight API (Interface 120105, Patch 12.1.5)

Lua 5.1 plus XML. Quelle der Fakten unten: `warcraft.wiki.gg/wiki/Secret_Values`, die `Patch_12.x/API_changes`-Seiten, `Gethe/wow-ui-source` (Blizzards Code) und `BigWigsMods/BigWigs`. Die Referenzen in `references/` sind Community-Material und älter, bei Widerspruch gilt das Wiki.

## Secret Values (Regeln laut Wiki)
Nur **getaintete** Ausführung ist betroffen. Verboten, wirft sofort einen Lua-Fehler:
Arithmetik, Vergleiche, boolesche Tests auf Boolean-Secrets, `#`, Indizieren/Zuweisen (`secret.x`), als Tabellenschlüssel, als Funktion aufrufen.
Erlaubt: in Variablen/Upvalues/Tabellenwerten speichern, an Lua-Funktionen weiterreichen, **verketten und `string.format`** (Ergebnis bleibt geheim), `type(secret)` (liefert den echten Typ), boolescher Test auf Nicht-Boolean-Secrets (nil = false, sonst true).
Tabellen: ein geheimer Schlüssel macht die Tabelle unlesbar ("forbidden table"). Nie geheime Werte als Schlüssel nutzen.

Prüfen: `issecretvalue(v)`, `canaccessvalue(v)`, `issecrettable(t)`, `canaccesstable(t)`, `hasanysecretvalues(...)`. Fragen, ob etwas gerade geheim wäre: `C_Secrets.ShouldUnitHealthMaxBeSecret(...)` und Verwandte (27 Funktionen), `C_Secrets.HasSecretRestrictions()`, `C_RestrictedActions.IsAddOnRestrictionActive(...)`.

Wann Werte geheim sind, steuern die "Secret Predicates" der API-Doku, nicht allein der Kampf:
`UnitHealthMax` und `UnitPowerMax` für nicht spielergesteuerte Units; `UnitName`/Identität für Units, die weder Spieler noch Gruppe sind; Casts anderer Units; Auren und Cooldowns bei Kampf, Begegnung, M+ und PvP (einzelne Zauber können immer/nie geheim sein); Vergleiche mit zusammengesetzten Tokens (`boss1target`) immer. Auf Instanz-Karten (`SecretOnRestrictedMaps`) greifen zusätzliche Regeln.

### Secret Aspects und Anker (wichtig für Frame-Code)
- `FontString:SetText(secret)` setzt den Aspekt *Text*: `GetText()` liefert danach Secrets.
- `StatusBar:SetValue(secret)` markiert die **ganze Bar** als "hat Secrets": ihre Position und Maße sind geheim und das gilt für alles, was an ihr verankert ist. Folge: nie `GetWidth/GetPoint/GetCenter` auf Bars, die Secrets bekommen. Layout über feste Größen und Anker. Test: `ScriptRegion:IsAnchoringSecret()`, `FrameScriptObject:HasSecretValues()`, `HasSecretAspect(aspect)`. Zurücksetzen: `SetToDefaults()` bzw. Anker löschen.

### Anzeige ohne Lua-Logik
| Ziel | API |
|---|---|
| Leben/Power-Balken | `bar:SetMinMaxValues(0, UnitHealthMax(u))`, `bar:SetValue(UnitHealth(u), Enum.StatusBarInterpolation.ExponentialEaseOut)` |
| Text | `fs:SetFormattedText("%s", secret)` oder `SetText(secret)` |
| Prozent | `UnitHealthPercent(unit, usePredicted, curve)` und `UnitPowerPercent(...)`: Ergebnis geheim nur, wenn die Kurve geheim ist |
| Kurzzahl "1,2 Mio" | `C_StringUtil.CreateAbbreviatedNumberFormatter()` (seit 12.0.5), `formatter:FormatNumber(n)`, Standardschwellen `C_StringUtil.GetDefaultAbbreviationBreakpoints()`; älter: `AbbreviateNumbers(n, {breakpointData=...})` |
| Farbe nach Wert | `C_CurveUtil.CreateColorCurve()` / `CreateCurve()`, `UnitHealthPercent(unit, false, colorCurve)`, `C_CurveUtil.EvaluateColorFromBoolean` |
| Balken nach Zeit | `StatusBar:SetTimerDuration(durationObject [, interpolation [, Enum.StatusBarTimerDirection]])`, die Engine zeichnet jeden Frame |
| Cooldown-Swipe | `Cooldown:SetCooldownFromDurationObject(duration [, clearIfZero])` |
| Duration-Objekte holen | `C_Spell.GetSpellCooldownDuration`, `C_Spell.GetSpellChargeDuration`, `C_UnitAuras.GetAuraDuration`, `UnitCastingDuration`, `UnitChannelDuration`, `C_EncounterTimeline.GetEventTimer(eventID)`, selbst bauen: `C_DurationUtil.CreateDuration()` |
| Sichtbarkeit nach Bool | `Frame:SetAlphaFromBoolean(secretBool, ...)` |

### Entfallen / geändert
- `COMBAT_LOG_EVENT_UNFILTERED` steht Addons nicht mehr offen. Ersatz: Unit-Events und `C_DamageMeter`.
- 12.1.5 hat die Veraltet-Fallbacks entfernt. Immer `C_Item.GetItemInfo`, `C_Item.GetItemCount` usw. statt der globalen `GetItem*`/`IsEquippedItem`-Funktionen (Inventar!). Gleiches für `C_CurrencyInfo.GetCoinText*`.
- Neu in 12.1.5: `CreateFrameWithOptions`, `GetScriptBucketThrottleLimits`, `C_UnitAuras.GetAuraCasterGUID`, `C_UnitAuras.GetRefreshCarryOverDuration`, `C_Timer.NewTimedSignalMap`, `math.clamp/lerp/round/...`, `table.contains/keys/values/...`, `string.startswith/endswith/...`, Nameplate-CVars `nameplateTopInset/BottomInset/MotionSpeed`, `UnitFrameUtil.GetUnitRoleIconDisplayInfo` u. a.

## Systeme und ihre echte API

**Boss-Timeline** (`C_EncounterTimeline`): `GetEventList()`, `GetSortedEventList([maxCount, maxDuration, excludeTerminal, excludeHidden])`, `GetEventInfo(id)` (`id`, `source`, `duration`, `maxQueueDuration` nie geheim; `spellName`, `spellID`, `iconFileID`, `icons` (Bitmaske), `severity`, `isApproximate` geheim), `GetEventState(id)` (`Enum.EncounterTimelineEventState`: Active, Paused, Finished, Canceled), `GetEventTimeRemaining(id)`, `GetEventTimer(id)` (Duration-Objekt, pausiert selbst), `GetTrackList/GetTrackInfo/GetEventTrack`, `AddScriptEvent({spellID, iconFileID, duration, ...})`, `SetViewType(Enum.EncounterTimelineViewType.None|Timeline|Bars)`. **`None` ist laut Wiki für Addons gedacht, die die Anzeige komplett übernehmen.** Events: `ENCOUNTER_TIMELINE_EVENT_ADDED(eventInfo)`, `..._STATE_CHANGED(eventID)`, `..._REMOVED(eventID)`, `..._BLOCK_STATE_CHANGED(eventID)`. Blizzards Frame: `EncounterTimeline`. Warnungen: `C_EncounterWarnings`, Frames `CriticalEncounterWarnings`, `MediumEncounterWarnings`, `MinorEncounterWarnings`, Event `ENCOUNTER_WARNING`.
CVars: `encounterTimelineEnabled`, `combatWarningsEnabled`.

**BigWigs (Retail)** liest dieselbe Blizzard-Timeline (siehe `BigWigsMods/BigWigs`, `Plugins/Timeline.lua`) und sendet daraus Nachrichten `BigWigs_StartBar(addon, module, key, text, time, icon, maxQueueDuration, duration, eventId)`, `BigWigs_PauseBar`, `BigWigs_ResumeBar`, `BigWigs_StopBar`. Modus je Profil: `enhanced` | `blizzbars` | `blizztimeline` | `dev`. Boss-Module mit `useCustomTimers` zeigen Blizzards Balken nicht und liefern eigene Bars. Eigene Optik für BigWigs-Bars: `BigWigsAPI:RegisterBarStyle(key, { apiVersion = 1, version = 1, GetStyleName, ApplyStyle, BarStopped, ... })`. Schnittstellen-Doku: BigWigs-Wiki "Custom Bar Styles".

**Cooldown Manager**: `C_CooldownViewer.GetCooldownViewerCategorySet/GetCooldownViewerCooldownInfo/GetLayoutData/SetLayoutData/GetGroupBuffItems/GetValidAlertTypes/IsCooldownViewerAvailable`. Frames (Blizzard_CooldownViewer): `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`, Einstellungen `CooldownViewerSettings`. Wir skinnen und positionieren, wir ersetzen die Datenquelle nicht.

**Damage Meter**: `C_DamageMeter.IsDamageMeterAvailable/GetAvailableCombatSessions/GetCombatSessionFromType/GetCombatSessionFromID/GetCombatSessionSourceFromType/...FromID/GetSessionDurationSeconds/ResetAllCombatSessions`. Blizzards Frame `DamageMeter` (Vorlagen `DamageMeterSessionWindowTemplate`, `DamageMeterSourceWindowTemplate`). Felder im Kampf geheim, also nur Engine-Widgets.

**Nameplates**: `C_NamePlate.GetNamePlateForUnit(unit [, issecure])`, `GetNamePlates`, `GetNamePlateSize/SetNamePlateSize`, `C_NamePlateManager.SetNamePlateHitTestFrame` (12.0.5), Plate-Methoden `SetHitTestPoints`/`CanChangeHitTestPoints`. Aura-Filter `INCLUDE_NAME_PLATE_ONLY`. Frames in `Blizzard_NamePlates`.

## Tiefer nachschlagen
- Wiki-Seiten abrufen: `curl -sL https://warcraft.wiki.gg/wiki/API:Name` (Funktionen), `…/wiki/EVENT_NAME` (Events), `…/index.php?title=Patch_12.1.5/API_changes&action=raw` (Patch-Listen). Bei Widget-Methoden `API:Widget_Method` mit Unterstrich.
- `bash tools/fetch-refs.sh` klont `Gethe/wow-ui-source`, `BigWigsMods/BigWigs` und die Community-Referenz nach `.refs/`.
- `references/*.md`: ältere Community-Zusammenfassung (MIT, `DennysOliveira/wow-addon-dev`). Dort steht teils, Verketten sei verboten. Das ist laut Wiki falsch.
