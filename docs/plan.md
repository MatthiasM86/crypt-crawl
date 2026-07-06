# PoC-Plan: Düsteres Action-Roguelike (Diablo-Style)

**Plattform:** PC (Desktop) · **Engine:** Godot 4.x · **Genre:** 2D-Pixel-Roguelike, Echtzeit-Kampf, Top-down
**Ziel des PoC:** Eine einzige Frage beantworten — *"Macht der Core-Loop Spaß?"*

> **Stand Juli 2026:** PoC komplett umgesetzt, Erfolgskriterium im Spieltest
> bestätigt. Vom Ausblick sind Punkt 1 (Meta-Progression) und Punkt 2
> (Pixel-Art via PixelLab) weitgehend fertig, Punkt 3 und 5 teilweise —
> Status-Marker an den Punkten unten.

---

## Kernkonzept

- **Perspektive:** Top-down (isometrisch erst nach dem PoC erwägen — vervielfacht den Asset-Aufwand)
- **Kampf:** Echtzeit-Hack'n'Slash à la Diablo, Maussteuerung
- **Roguelike-Loop:** Permadeath + prozedurale Levels, später Meta-Progression à la Hades (Seelen-Währung, permanente Upgrades)
- **Atmosphäre:** Düster, begrenzter Sichtradius durch Fackellicht, entsättigte Palette mit Akzenten (Blutrot, Giftgrün)

---

## Phase 1: Design-Entscheidungen festnageln (1–2 Tage)

- [x] **Steuerung:** Linksklick = laufen/angreifen (Diablo-Standard), Rechtsklick = Skill (optional für PoC), Leertaste/Shift = Dash
- [x] **Kampf-Grundregeln:**
  - Angriff mit Cooldown (z.B. 0,5 s)
  - Hitbox vor dem Spieler
  - Gegner-Angriffe mit **Windup** (kurze Telegraphierung → Ausweichen möglich; Kern des Spielgefühls!)
- [x] **Minimal-Stats:** HP, Schaden, Bewegungstempo — sonst nichts

## Phase 2: PoC-Scope schriftlich fixieren

Der PoC prüft nur: Fühlt sich Klicken, Treffen und Ausweichen gut an ("Game Feel")?

**Enthalten:**
- [x] 1 prozedural generierte Ebene (Rooms & Corridors)
- [x] 1 Spielfigur
- [x] 2 Gegnertypen: Nahkämpfer (rennt auf dich zu) + Fernkämpfer (hält Abstand, schießt Projektil)
- [x] 1 Nahkampfangriff, 1 Heiltrank auf Hotkey
- [x] Fog of War / Sichtradius per Licht (PointLight2D → gratis düstere Atmosphäre)
- [x] Tod = Neustart
- [x] Platzhalter-Grafik (farbige Rechtecke reichen!) — inzwischen durch PixelLab-Pixel-Art ersetzt

**Bewusst NICHT enthalten (nach dem PoC):**
Pixel-Art, Meta-Progression, Biome, Bosse, Item-Vielfalt, Skilltrees, Sound, Balancing, Monetarisierung

## Phase 3: Technisches Fundament (parallel zu Phase 1)

- [x] Godot 4.x installieren, nur Desktop-Export
- [x] Kern-Nodes lernen:

| Node | Zweck |
|---|---|
| `CharacterBody2D` + `move_and_slide()` | Bewegung Spieler & Gegner |
| `NavigationRegion2D` / `NavigationAgent2D` | Klick-Bewegung, Gegner-Pathfinding um Wände |
| `Area2D` | Angriffs-Hitboxen und Projektile |
| `AnimationPlayer` / `AnimatedSprite2D` | Angriffs-Timing, Windups |
| `PointLight2D` + `LightOccluder2D` | Fackellicht, Schatten, Fog of War |

- [x] **Szenen-Struktur:** `Player`, `Enemy` (Basis-Szene, Varianten erben), `Projectile`, `LevelGenerator`, `GameManager` (HP, Tod, Neustart)

## Phase 4: Bauen (3–5 Wochen als Feierabend-Projekt)

Reihenfolge — **Game Feel zuerst**:

1. [x] **Spieler-Bewegung** per Klick (`NavigationAgent2D`) in einem handgebauten Testraum
2. [x] **Angriff:** Klick auf Gegner → hinlaufen bis Reichweite → zuschlagen.
   → Sofort an Feedback arbeiten: **Hit-Flash, kurzer Knockback, Screenshake.**
   → *Hier stecken 80 % des Diablo-Gefühls. Unverhältnismäßig viel Zeit investieren!*
3. [x] **Gegner-KI:** Zustandsmaschine mit 3 Zuständen: `Idle` → `Verfolgen` (sieht Spieler) → `Angreifen` (in Reichweite, mit Windup)
4. [x] **Fernkämpfer + Projektil**
5. [x] **Levelgenerator** anschließen (Rooms & Corridors)
   → Navigation-Mesh pro generierter Ebene neu backen: `NavigationRegion2D.bake_navigation_polygon()`
   → Erreichbarkeit garantieren (Treppe immer verbunden, Flood-Fill-Check)
6. [x] **Licht/Fog of War**, Treppe, Ebenenwechsel, Tod & Neustart

## Erfolgskriterium

> **"Das Kämpfen gegen 3–4 Gegner gleichzeitig fühlt sich knackig an, und ich spiele freiwillig 5 Runs am Stück."**

Fühlt es sich schwammig an → an Schritt 2 (Feedback/Game Feel) schrauben, **bevor** neue Features gebaut werden.

✅ **Erfüllt** (Spieltest Juli 2026) — Basis-Feel bestätigt, danach Dash + Rundumschlag nachgelegt.

---

## Ausblick nach erfolgreichem PoC

1. **Meta-Progression** (Hades-Style): Seelen-Währung, Hub, permanente Upgrades, Freischaltungen
   → ✅ *umgesetzt: Seelen-Wisps, begehbarer Hub mit 4 Schreinen, Save-File; offen: Freischaltungen (neue Skills/Waffen statt nur Stats)*
2. **Pixel-Art & Atmosphäre:** düstere Tilesets, Gore-Details, Ambient-Sound
   → ✅ *weitgehend: PixelLab-Tileset + 8-Richtungs-Sprites (Spieler, Brute, Kultist, Boss, inkl. Tod/Treffer) + Props; Sound bisher synthetisierte Platzhalter (Sfx-Autoload); offen: Gore, echte Audio-Dateien*
3. **Ebenen-Struktur:** alle 4–5 Ebenen Boss/Elite-Raum, Biomwechsel (Krypta → Katakomben → Fleischgrube)
   → 🔶 *teilweise: Boss „Kryptwächter" alle 5 Ebenen mit Arena + Weiterspiel-Option; offen: Biomwechsel*
4. **Prefab-Räume** einstreuen (Schatzkammer, Schrein, Bossarena — wie Spelunky/Dead Cells)
   → ❌ *offen (Bossarena existiert, aber generiert, keine Prefabs)*
5. **Risk/Reward:** verfluchte Truhen, optionale Schatzräume; Loot/Gegner nach Distanz zum Spawn skalieren
   → ✅ *weitgehend: Truhen in Seitenräumen (verfluchte sichtbar lila → Hinterhalt beim Öffnen), nach Boss-Sieg weiter absteigen, Gegner/Seelen skalieren mit Ebene; offen: dedizierte Schatzräume*
6. **Item-System (Roguelike-Zuschnitt, bewusst schlank):** keine Diablo-Loot-Flut,
   kein Inventar, keine Affixe — stattdessen **Relikte**: seltene, run-gebundene
   Fundstücke (aus Truhen, von Elites, nach dem Boss), die den Build *dieses* Runs
   spürbar verändern (z.B. „Slam hinterlässt Feuerfläche", „Kills heilen 1 HP",
   „+1 Dash-Ladung", „Projektile prallen ab"). Aufheben = Sofort-Entscheidung,
   max. ~4 gleichzeitig als Icons im HUD, Tod = weg. Motivation kommt aus
   Run-Varianz (Hades/Dead Cells), nicht aus Stash-Verwaltung
   → ✅ *erste Scheibe umgesetzt: 7 Relikte (Brandsiegel, Blutdurst, Schattenschritt,
   Wuchtklinge, Hetzjagd, Konzentrat, Seelengier), max. 4 als HUD-Icons, Drop aus
   Truhen (60%) und nach jedem Boss-Kill; offen: weitere Relikte, Elite-Drops*
7. **Content:** 5–8 Gegnertypen, Skills, Controller-Support (Items → Punkt 6)
   → ❌ *dünnste Stelle: 2 Gegnertypen + 1 Boss; Skills nur Dash + Rundumschlag; kein Controller*
8. **Vertrieb:** itch.io (kostenlos, unkompliziert) → später Steam; Mobile-Port optional
   → ❌ *offen: noch kein Export-Preset / Build*