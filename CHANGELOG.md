# Changelog

## 0.1.0 (in Arbeit)
- Unit Frames: Cast-, Channel- und Empower-Balken (Spieler, Ziel, Fokus, Boss 1–5), Engine-gezeichnet über `SetTimerDuration`; Blizzards Spieler-Castbar wird abgekoppelt.
- Unit Frames: Buffs und Debuffs über Blizzards `AuraContainer` (Ziel, Boss 1–5), Restzeit als Text statt Cooldown-Zahlen.
- Unit Frames: Heilvorhersage, Raid-Marker, Rolle/Leader/PvP-Icons, Tot/Offline-Graustufe, Level, Klassenressourcen am Spieler.
- Cooldown Manager: Blizzards Viewer im Ember-Design, Items an eigenem Halter (`/boro unlock`), Optionen je Viewer.
- Boss-Timeline: eigener Renderer (Balkenliste oder lineare Spur) auf `C_EncounterTimeline`, Quellenschnittstelle für BigWigs (V09), Test-Modus `/boro timeline test`, Skin der Boss-Warnungen.
- Damage Meter: Skin für Blizzards `DamageMeter` (Modul `DamageMeterSkin`).
- Skins: Charakter, Inspektion, Ruf, Währungen; Zauberbuch, Talente, Berufe; Karte, Quests, Gossip, Händler, Post, Quest-Tracker; Chat, Freunde, Gilde, Gruppensuche; Sammlungen, Abenteuerführer; Tooltips, Popups, Edit Mode.
- Test: Headless-Smoke-Test mit simulierten Secret Values deckt Core, Unit Frames, Timeline, Cooldown Manager und Damage-Meter-Skin ab.
- Core: Module, Events, Scheduler, Pools, Combat-Queue, Config mit Profilen, Mover, Skin-Registry, Slash-Befehle.
- Theme: Ember-Palette nach Borometer.
- Unit Frames: Player, Target, Target of Target, Focus, Boss 1–5 (Health, Absorb, Power, Name, Lebenstext).
