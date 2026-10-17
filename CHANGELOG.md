# Changelog

## 0.1.0 (in Arbeit)
- Umbenennung: aus dem Repo BoroFrame wird das Addon Borometer (Repo BorometerWoW). Entfernt: Unit Frames, Cooldown Manager, Boss-Timeline und alle Fenster-Skins.
- Core: Module, Events, Scheduler, Pools, Combat-Queue, Config mit Profilen, Mover, Skin-Registry, Slash-Befehle (`/bm`).
- Theme: Ember-Palette nach Borometer.
- Damage-Meter-Skin: Blizzards `DamageMeter` im Ember-Design (Modul `DamageMeterSkin`).
- Test: Headless-Smoke-Test mit simulierten Secret Values.
- Datenschicht (`Data`): nach dem Kampf Schaden und Heilung der letzten Sitzung als Klartext kopieren, bis zu 10 Kämpfe im Speicher.
- Ring (`Ring`): Auswertung als Glutring mit Anteilen je Quelle, Quellenliste, Tabs Schaden/Heilung. `/bm ring [demo]`.
- Tools: `tools/gen-media.py` erzeugt die Ring-Texturen.
