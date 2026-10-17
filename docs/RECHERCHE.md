# Recherche: WoW Retail API (Midnight, Patch 12.1.5, TOC 120105)

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
| 9 | Aura-Icons: `GetAuraDuration` + Cooldown-Swipe ohne Taint, Bug #881 | V03 |
| 10 | `GetScriptBucketThrottleLimits`: was begrenzt Blizzard für Addon-Skripte, und wie nutzt der Scheduler das | Core |

Prüfmethode je Punkt: `/console scriptErrors 1`, Secrets erzwingen (siehe oben), Ergebnis hier nachtragen.

## Performance-Befund
- `OnUpdate` pro Frame summiert sich bei hohen Frameraten, Timer oder Schwellen sind besser.
- Größter Hebel: Rendern an die Engine geben (`SetTimerDuration`, Duration-Objekte, Interpolation von `SetValue`).
- Gemessen wird, nicht geglaubt (`ns.Debug.Profile`, `GetAddOnCPUUsage`).
