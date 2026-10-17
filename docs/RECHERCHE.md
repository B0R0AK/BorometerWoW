# Recherche: WoW Retail API (Midnight, 12.0.x)

Stand: 2026-10-17. **Nichts davon wurde im Spiel getestet.** Die Sandbox hatte keinen Zugriff auf warcraft.wiki.gg (Proxy 403). Quellen sind die frei zugänglichen Referenz-Repos, teils KI-erzeugt, und der Code der Community:

- `Amadeus-/WoWAddonDevGuide` (12a Secret Safe APIs, 13 Cooldown Viewer, 12 Migration, 01 API)
- `DennysOliveira/wow-addon-dev` (MIT, als Skill-Referenz übernommen)
- Eigene Prüfung: der Smoke-Test simuliert Secrets, er ersetzt keinen Spieltest.

## Was gilt (aus den Quellen, konsistent)
- **Secret Values** (seit 12.0.0, überall im Kampf, nicht nur in Instanzen): nicht vergleichen, rechnen, verketten, indizieren. Engine-Widgets nehmen sie an: `StatusBar:SetValue/SetMinMaxValues/SetTimerDuration`, `FontString:SetText/SetFormattedText`, `Cooldown:SetCooldownFromDurationObject`, `Frame:SetAlphaFromBoolean`. Prüfen: `issecretvalue`, `canaccessvalue`, `hasanysecretvalues`.
- `UnitHealthPercent` / `UnitPowerPercent` liefern nicht geheime Prozentwerte (Argument `CurveConstants.ScaleTo100`).
- `AbbreviateNumbers(value, breakpoints)` akzeptiert geheime Zahlen und gibt einen normalen String.
- `COMBAT_LOG_EVENT_UNFILTERED` steht Addons nicht mehr zur Verfügung. Ersatz: Unit-Events und `C_DamageMeter`.
- Ab 12.0.1 ist `SetCooldownFromDurationObject` die einzige Cooldown-Methode, die Secrets annimmt.
- 12.0.5: Aura-Klassifikationsfelder (`isHelpful`, `isHarmful`, `isRaid`, `isNameplateOnly`, `isFromPlayerOrPlayerPet`) nicht geheim; Unit-Token von `nameplate*`, `boss*`, `party*`, `raid*` können geheim sein.
- Systeme: `C_CooldownViewer`, `C_EncounterTimeline`, `C_EncounterWarnings`, `C_DamageMeter`, `C_NamePlate`.

## Offen / im Spiel prüfen
| # | Frage | Warum unsicher | Vorhaben |
|---|---|---|---|
| 1 | Interface-Nummer `120005` stimmt mit Live überein | nur aus einem Community-Guide | Release |
| 2 | Genaue Funktionsnamen von `C_EncounterTimeline` | zwei Guides nennen unterschiedliche (`GetEventList/GetEventInfo` vs. `GetUpcomingEvents`) | Boss-Timeline |
| 3 | Wie speist BigWigs die Timeline in Midnight, und gibt es eine Schnittstelle für Fremd-Anzeigen | keine belastbare Quelle gefunden | BigWigs-Adapter |
| 4 | Signatur und Verhalten von `AbbreviateNumbers` mit unserer Breakpoint-Tabelle (`UF.Short`) | nur aus Guide, Rundung ungeprüft | Unit Frames |
| 5 | `UnitHealthPercent(unit, false, CurveConstants.ScaleTo100)` Argumente | aus Guide | Unit Frames |
| 6 | Blizzard-Unit-Frames per `SetParent(hidden)` + `UnregisterAllEvents` ohne Taint, auch mit Edit Mode | Taint nur im Spiel sichtbar | Unit Frames |
| 7 | Skinnen/Umpositionieren der Cooldown-Viewer-Frames ohne Taint | Guide 13 beschreibt Fallen, Details im Spiel | Cooldown-Manager |
| 8 | Damage-Meter-Fenster: skinnen reicht, oder braucht es eigene Darstellung | Felder sind im Kampf geheim, sourceGUID ab 12.1.5 teils geheim | Meter-Skin |
| 9 | Party/Raid: welche Tokens/Namen sind geheim (12.0.5) und was heißt das für Header und Klassenfarbe | Regeln sind eng und ändern sich | Party/Raid |
| 10 | Aura-Icons: `GetAuraDuration` + Cooldown-Swipe ohne Taint im Kampf | aus Guide | Auren |
| 11 | `SecureUnitButtonTemplate` + `togglemenu` Klickattribut in 12.x | aus dem Gedächtnis des Standardmusters | Unit Frames |

## Bekannte Blizzard-Bugs (WoWUIBugs, Stand 2026-10-17)
Quelle: https://github.com/Stanzilla/WoWUIBugs/issues. Nur die Titel der ersten Seiten gelesen, Details je Issue vor der Arbeit prüfen. Der Patch-12.1.5-Wikiartikel war aus der Sandbox nicht abrufbar (Host gesperrt), diese Änderungen sind **nicht** eingearbeitet.

| Issue | Befund | Betrifft |
|---|---|---|
| #884 | Cooldown-Manager: Debuffs auf dem Ziel brechen, wenn das Ziel zweimal im selben Frame wechselt | V07 |
| #875 | Cooldown Manager verfolgt Blutungen nicht | V07 |
| #881 | Nameplate-Debuffs: Dauerzahlen brechen nach 60 s | V10, V03 |
| #834 | `UnitChannelInfo`/`UnitChannelDuration` liefern bei Strahl des Frosts falsche Werte | V02 |
| #420 | `UnitPartialPower` für Beschwörer-Essenzen defekt | V04 |
| #888 | Aktionsleisten tainten, wenn Addon-Code sie im Kampf zeigt/versteckt | V14 |
| #876 | Chat-Eingabefeld kann Attribute in M+/Chat-Lockdown dauerhaft geheim machen | V13d |
| #803 | Scrolling Combat Text kann tainten und Anzeigen verweigern | – |
| #811 | Tooltip: Secret-Value-Fehler in `LayoutFrame.lua` | V13f |
| #826 | Dropdown-Taint zerstört Communities-Fenster im Boss-Kampf | V13d, V13f |

Folge: Spezialfälle (Cooldown-Manager-Debuffs, Kanalzauber, Nameplate-Dauer) bekommen eigene Testfälle im Spiel, nicht nur den Smoke-Test.

Jede Zeile wird zu einem Prüfpunkt im jeweiligen PR. Ergebnisse tragen wir hier nach.

## Performance-Befund aus den Quellen
- `OnUpdate` pro Frame summiert sich bei 120–144 fps stark, Timer oder Schwellen sind besser.
- Lokale Globals bringen heute wenig, die Regel ist billig, die Wirkung klein. Gemessen wird, nicht geglaubt (`ns.Debug.Profile`).
- Größter Hebel in Midnight: Rendern an die Engine übergeben (`SetTimerDuration`, Duration-Objekte), nicht in Lua nachbauen.
