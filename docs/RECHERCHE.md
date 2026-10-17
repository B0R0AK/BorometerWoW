# Recherche: WoW Retail API (Midnight, Patch 12.1.5, TOC 120105)

> **Umfang geändert (2026-10-17):** Aus dem UI-Projekt BoroFrame ist das Damage-Meter-Addon **Borometer** geworden. Abschnitte zu Unit Frames, Auren, Cooldown Manager, Boss-Timeline, Nameplates und Fenster-Skins bleiben als geprüftes API-Wissen stehen, gehören aber nicht mehr zum Umfang. Maßgeblich für Borometer: Abschnitt „Damage Meter“ und `docs/ARCHITEKTUR.md`.

Stand: 2026-10-17. **Nichts davon wurde im Spiel getestet.**

## Quellen und ihr Gewicht
1. **warcraft.wiki.gg** (gelesen): `Secret_Values`, `Patch_12.0.0/12.0.5/12.0.7/12.1.0/12.1.5 API_changes`, Einzelseiten `API:…`. Maßgeblich.
2. **Blizzards UI-Code** (`Gethe/wow-ui-source`) und **BigWigs-Quellcode** (`BigWigsMods/BigWigs`): gelesen für Frame-Namen und die Timeline-Anbindung. Maßgeblich für das, was der Code tut.
3. **WoWUIBugs** (Issue-Tracker): nur Titel gelesen.
4. Community-Referenzen (`Amadeus-/WoWAddonDevGuide`, `DennysOliveira/wow-addon-dev`): teils KI-erzeugt, **widersprechen dem Wiki** (siehe unten). Nur als Wegweiser.

## Korrekturen gegenüber der ersten Fassung
| Annahme (Community-Guide) | Befund (Wiki/Code) |
|---|---|
| Interface 120005 | **120105** (12.1.5, 21.09.2026) |
| Secrets dürfen nicht verkettet/formatiert werden | **Verketten und `string.format` sind erlaubt**, das Ergebnis bleibt geheim. Verboten: Arithmetik, Vergleiche, `#`, Indizieren, Schlüssel, Aufruf |
| `C_EncounterTimeline.GetUpcomingEvents`, `GetCurrentPhase`, `GetPhaseInfo` | gibt es nicht. Real: `GetEventList`, `GetSortedEventList`, `GetEventInfo`, `GetEventState`, `GetEventTimeRemaining`, `GetEventTimer`, `GetTrackList`, `SetViewType` … |
| BigWigs-Anbindung unbekannt | geklärt: BigWigs liest die Blizzard-Timeline und sendet `BigWigs_StartBar`/`Pause`/`Resume`/`Stop`; eigene Optik über `BigWigsAPI:RegisterBarStyle` |
| `AbbreviateNumbers` mit eigener Tabelle | Signatur stimmt (`AbbreviateNumbers(n, {breakpointData=…})`), seit 12.0.5 gibt es den sanktionierten `C_StringUtil.CreateAbbreviatedNumberFormatter()`; wir nutzen ihn |
| `UnitHealthPercent` liefert nie Secrets | Ergebnis geheim nur, wenn die übergebene **Kurve** geheim ist (`SecretWhenCurveSecret`) |
| Nur Kampf macht Secrets | Auslöser sind "Secret Predicates": Kampf, Begegnung, M+, PvP-Match, Instanzkarten, Unit-Identität, Aura-/Cooldown-Zustand. Test im Spiel erzwingbar (siehe unten) |

## Neu verstanden, wirkt auf den Code
- **Secret Aspects / Anker:** `StatusBar:SetValue(secret)` macht Position und Maße der Bar und aller daran verankerten Regionen geheim. Wir lesen nie Maße oder Punkte von Bars. `FontString:SetText(secret)` macht `GetText()` geheim.
- **Test ohne Kampf:** `/console addonCombatRestrictionsForced 1` (außerdem `addonEncounterRestrictionsForced`, `addonChallengeModeRestrictionsForced`, `addonPvPMatchRestrictionsForced`, `addonMapRestrictionsForced`, `addonChatRestrictionsForced`). Das ersetzt Puppen-Tests im Kampf.
- **Boss-Timeline:** `SetViewType(Enum.EncounterTimelineViewType.None)` ist ausdrücklich für Addons, die die Anzeige übernehmen. Pro Event liefert `GetEventTimer(id)` ein Duration-Objekt, das direkt in `StatusBar:SetTimerDuration` geht (kein Lua pro Frame).
- **12.1.5:** deprecated Fallbacks entfernt (`GetItemInfo`, `GetItemCount`, `IsEquippedItem`, `GetCoinText` … nur noch über `C_Item.*`, `C_CurrencyInfo.*`). Neu `CreateFrameWithOptions`, `GetScriptBucketThrottleLimits`, `C_UnitAuras.GetAuraCasterGUID`, `GetRefreshCarryOverDuration`, Nameplate-CVars `nameplateTopInset/BottomInset/MotionSpeed`.
- Frame-Namen geprüft: `EncounterTimeline`, `CriticalEncounterWarnings`/`MediumEncounterWarnings`/`MinorEncounterWarnings`, `DamageMeter`, `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`, `CooldownViewerSettings`.

## Cooldown Manager (V07, Blizzards Code 12.1.5 Build 70448 gelesen)
- `Blizzard_CooldownViewer.toc` hat kein `LoadOnDemand`, hängt an `Blizzard_EditMode`. Das Modul hakt trotzdem auch über `ADDON_LOADED` ein, falls es später lädt.
- Edit Mode ersetzt auf jedem Viewer `SetPoint`, `ClearAllPoints`, `SetScale` durch Lua-Overrides (`EditModeSystemMixin:OnSystemLoad`), die Snap-Zustand schreiben und `EditModeManagerFrame:OnEditModeSystemAnchorChanged()` aufrufen. Aufruf aus Addon-Code taintet Edit Mode. Deshalb bewegt BoroFrame den Viewer nie, sondern verankert die Items an einem eigenen Halter-Frame (`ns.Mover`).
- In Standardposition hängen Essential, Utility und BuffIcon im `BottomManagedFrameContainer` (Reparent + Layout durch Blizzard). BuffBar nicht.
- Jeder Relayout-Weg (`RefreshLayout`, `OnShow`, Edit-Mode-Einstellungen) endet in `GridLayoutFrameMixin:Layout` am Viewer. Ein `hooksecurefunc(viewer, "Layout", …)` reicht. Item-Mixins werden nicht gehakt (Aura-Kette, Taint-Gefahr laut Community-Guide).
- Blizzard setzt die Swipe-Farbe bei jedem Refresh neu (`RefreshSpellCooldownInfo`), Swipe-Textur und Countdown-Font nur einmal (`OnLoad`).

## Damage Meter (`C_DamageMeter`), geprüft gegen das Wiki
- Funktionen: `IsDamageMeterAvailable`, `GetAvailableCombatSessions`, `GetCombatSessionFromType/FromID(sessionType|sessionID, meterType)`, `GetCombatSessionSourceFromType/FromID(…, sourceGUID, sourceCreatureID)`, `GetSessionDurationSeconds`, `ResetAllCombatSessions`.
- Sitzung: `combatSources[]`, `maxAmount`, `totalAmount`, `durationSeconds`; **`SecretWhenInCombat`**. Quelle: `sourceGUID` (bedingt geheim), `sourceCreatureID`, `name` (bedingt geheim), `totalAmount`, `amountPerSecond`, `deathTimeSeconds`, `sourceDisplayType` (Ally/Enemy), `factionGroup`; nie geheim: `classFilename`, `specIconID`, `isLocalPlayer`, `classification`, `deathRecapID`.
- Quellen-Detail: `combatSpells[]` mit `spellID`, `totalAmount`, `amountPerSecond`, `overkillAmount`, `isAvoidable`, `isDeadly`, `creatureName`, `combatSpellDetails` (Einheit, Klasse, Pet/Mob, Menge).
- Enums: `DamageMeterSessionType` (Overall, Current, Expired), `DamageMeterType` (DamageDone, Dps, HealingDone, Hps, Absorbs, Interrupts, Dispels, DamageTaken, AvoidableDamageTaken, Deaths, EnemyDamageTaken).
- Events: `DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID)`, `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `DAMAGE_METER_RESET`.
- Folge: Auswertung nach dem Kampf ist mit Klartext möglich, Live im Kampf nur über Engine-Widgets.

**Im Spiel zu klären (Borometer):** (a) kommen `combatSources` bereits nach Betrag sortiert, auch im Kampf? (b) ab wann sind die Werte nach dem Kampf Klartext, direkt nach `PLAYER_REGEN_ENABLED` oder erst nach `DAMAGE_METER_CURRENT_SESSION_UPDATED`? (c) bleiben `name` und `sourceGUID` in Instanzen/PvP auch nach dem Kampf geheim (dann nur Klasse und Spezialisierung anzeigbar)? (d) was liefert `Overall` über mehrere Kämpfe, und wie lange hält Blizzard Sitzungen vor (Grenze für Verlauf)? (e) `Deaths`: was bedeutet `deathRecapID`, gibt es einen Zugriff auf den Bericht?

## Bekannte Blizzard-Bugs (WoWUIBugs, nur Titel gelesen)
| Issue | Befund | Betrifft |
|---|---|---|
| #884 | Cooldown-Manager: Debuffs auf dem Ziel brechen bei zweimaligem Zielwechsel im selben Frame | V07 |
| #875 | Cooldown Manager verfolgt Blutungen nicht | V07 |
| #881 | Nameplate-Debuffs: Dauerzahlen brechen nach 60 s | V10, V03 |
| #834 | `UnitChannelInfo`/`UnitChannelDuration` falsch bei Strahl des Frosts | V02 |
| #420 | `UnitPartialPower` für Beschwörer-Essenzen defekt | V04 |
| #888 | Aktionsleisten tainten, wenn Addon-Code sie im Kampf zeigt/versteckt | V14 |
| #876, #826, #811 | Taint in Chat-Eingabe, Dropdowns, Tooltip-Layout | V13d, V13f |
| #803 | Scrolling Combat Text kann tainten | – |

## Offen / im Spiel prüfen
| # | Frage | Vorhaben |
|---|---|---|
| 1 | Hat ein frischer `AbbreviatedNumberFormatter` brauchbare Standard-Schwellen, oder braucht er `SetBreakpoints(GetDefaultAbbreviationBreakpoints())`? Rundung prüfen | Unit Frames |
| 2 | Blizzard-Unit-Frames per `SetParent(hidden)` + `UnregisterAllEvents` ohne Taint, auch mit Edit Mode | Unit Frames |
| 3 | `SecureUnitButtonTemplate` mit `*type2 = "togglemenu"` in 12.1 | Unit Frames |
| 4 | `StatusBar:SetValue(secret, interpolation)` mit Smoothing: sichtbar sauber bei Boss-Frames (Max-Leben geheim)? | Unit Frames |
| 5 | Timeline: Verhalten von `SetViewType(None)` mit BigWigs-Modus `enhanced`; wann liefert BigWigs eigene Bars (`useCustomTimers`) statt Blizzard-Events | V08, V09 |
| 6 | Cooldown-Viewer-Frames skinnen/verschieben ohne Taint (Items am Halter, Viewer unberührt); sind Items in Standardposition im Kampf geschützt (`IsProtected`)? | V07 |
| 7 | Damage-Meter-Fenster: Skin reicht, oder eigene Darstellung nötig; `sourceGUID` ab 12.1.5 teils geheim | V11 |
| 8 | Party/Raid: Tokens, Namen und Klassenfarbe unter den Unit-Identity-Regeln | V05, V06 |
| 9 | Auren laufen über `AuraContainer` (`CustomAuraContainerTemplate`, `AddAuraGroup`), weil seit 12.1.0 die Instanz-ID-APIs von `C_UnitAuras` bei geheimen Auren einen Lua-Fehler werfen und `UNIT_AURA` komplett geheim ist (Quelle: `Patch_12.1.0/API_changes/notes`, PTR 3). Prüfen: Container als Kind eines `SecureUnitButton` ohne Taint, Dauertext statt Cooldown-Zahlen (Bug #881), `UpdateAllAuras` bei Zielwechsel im Kampf | V03 |
| 10 | `GetScriptBucketThrottleLimits`: was begrenzt Blizzard für Addon-Skripte, und wie nutzt der Scheduler das | Core |

Prüfmethode je Punkt: `/console scriptErrors 1`, Secrets erzwingen (siehe oben), Ergebnis hier nachtragen.

## Stand nach Welle 1 (gebaut, nicht im Spiel getestet)
Gebaut: Cast-Balken, Auren (AuraContainer), Frame-Extras, Cooldown Manager, Boss-Timeline, Damage-Meter-Skin, 12 Fenster-Skins. Der Smoke-Test prüft Struktur und Secret-Sicherheit gegen Attrappen, nicht das Verhalten des Clients.

**Wichtigste Prüfungen im Spiel, in dieser Reihenfolge**
1. Start ohne Lua-Fehler (`/console scriptErrors 1`), dann mit `addonCombatRestrictionsForced 1`, `addonEncounterRestrictionsForced 1`, `addonMapRestrictionsForced 1`.
2. Taint: `ADDON_ACTION_BLOCKED` und `taint.log` nach Edit Mode, Fenster öffnen im Kampf, Zielwechsel im Kampf.
3. Auren: Container als Kind eines `SecureUnitButton` ohne Fehler "implicitly gain Forbidden Aspects"; Auren erscheinen im Kampf (V03).
4. Casts: `SetTimerDuration` mit fremden Casts (geheime Duration), Reihenfolge INTERRUPTED vor STOP, `castBarID` je Cast eindeutig (V02).
5. Timeline: `overrideViewType = None` hält über Edit Mode; `GetEventTimer` an `SetTimerDuration`; mit BigWigs in `enhanced`, `blizzbars`, `blizztimeline` (V08, Punkt 5).
6. Cooldown Manager: Items am Halter nach Edit Mode, Layout- und Spezwechsel, Kampfbeginn bei "nur im Kampf" (V07).
7. Damage-Meter-Skin im und nach dem Kampf, alle vier Blizzard-Stile (V11).
8. Skins: je Fenster öffnen, Kontrast prüfen (Pergament, Marmor, Item-Slots), Schalter aus + `/reload` (V13a–f).
9. Frame-Extras: Klassenressourcen aller Klassen, Rollen-Icon mit geheimem Atlas, Heilvorhersage-Anker (V04).

**Bekannte Lücken**
- `Skins/Common.lua` enthält sechs Fassungen derselben Helfer (Suffixe `_a` bis `_e`) und 680 Zeilen. Konsolidierung steht aus.
- Nicht gestylt (bewusst): neues Menü-System (WoWUIBugs #826), Scrollbars und Checkboxen in den meisten Fenstern, Listenzeilen mit Pool-Frames.
- Nicht gebaut: Party, Raid, Nameplates, Inventar, Aktionsleisten, Optionen, Profile, BigWigs-Quelle, Lokalisierung.

## Performance-Befund
- `OnUpdate` pro Frame summiert sich bei hohen Frameraten, Timer oder Schwellen sind besser.
- Größter Hebel: Rendern an die Engine geben (`SetTimerDuration`, Duration-Objekte, Interpolation von `SetValue`).
- Gemessen wird, nicht geglaubt (`ns.Debug.Profile`, `GetAddOnCPUUsage`).
