# Architektur

```
BoroFrame/            das Addon (wird gezippt)
  BoroFrame.toc
  Core/               Infrastruktur, kritisch (Fable)
    Init.lua          Namespace, Modul-System, ns.IsSecret
    Debug.lua         Guard (Fehlergrenze, einmal melden), Profile
    Events.lua        ein Event-Frame für globale Events
    Scheduler.lua     ein OnUpdate, schläft ohne Aufgaben
    Pool.lua          Objekt-Pools
    Combat.lua        Defer-Queue für Secure-Änderungen im Kampf
    Config.lua        SavedVariables, Profile, additive Defaults, Migrationen
    Mover.lua         gespeicherte Positionen, Unlock-Modus
    Skin.lua          Skin-Registry, lazy pro Blizzard-Addon
    Slash.lua         /boro
  Media/Theme.lua     Palette, Fonts, Backdrop-Helfer
  Skins/              Blizzard-Fenster, eine Gruppe pro Datei (Sonnet)
  Modules/<Name>/     Features, je ein Ordner (Opus)
tools/                check.sh, smoke test, Referenzen
```

## Lebenszyklus
`ADDON_LOADED` → Config initialisiert (Defaults additiv) → `PLAYER_LOGIN` → `ns:StartModules()` → `OnInitialize` aller Module, dann `OnEnable` der aktiven. Skins laufen danach, je Skin in einer Fehlergrenze, erst wenn das Blizzard-Addon geladen ist.

## Modul-Vertrag
```lua
local M = ns:NewModule("Name")
ns.Config:Register("name", { ...defaults... })   -- beim Laden der Datei
function M:OnEnable() end                        -- Frames bauen, Events registrieren
function M:OnDisable() end                       -- oder: "wirkt nach /reload" dokumentieren
```
Module sprechen nur über `ns.*` Core-Dienste miteinander, nie über Globals.

## Unit Frames
Eine Fabrik (`UF.Create`) baut aus einer Spezifikation (Größe, Element-Liste) einen `SecureUnitButton`. Elemente (`Health`, `Absorb`, `Power`, `Name`, `HealthText`, später `Cast`, `Auras`, …) sind kleine Tabellen mit `create`, `refresh`, `events`. Neue Anzeige = neues Element, keine Änderung an der Fabrik. Unit-Events werden pro Frame mit `RegisterUnitEvent` registriert. Der Zustand liegt in Blizzards Engine-Widgets, nicht in Lua-Tabellen.

## Secret-Value-Modell
Werte kommen aus der API und gehen unverändert an `StatusBar`, `FontString:SetFormattedText`, `Cooldown:SetCooldownFromDurationObject`. Entscheidungslogik (Farbe, Sichtbarkeit) nutzt nur nicht-geheime Felder oder Curves. Der Smoke-Test liefert absichtlich Secrets, bei denen jede Lua-Operation einen Fehler wirft.

## Geplante Module
Siehe `docs/vorhaben/BACKLOG.md`.
