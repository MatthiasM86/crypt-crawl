# PoC-Plan: Düsteres Action-Roguelike (Diablo-Style)

**Plattform:** PC (Desktop) · **Engine:** Godot 4.x · **Genre:** 2D-Pixel-Roguelike, Echtzeit-Kampf, Top-down
**Ziel des PoC:** Eine einzige Frage beantworten — *"Macht der Core-Loop Spaß?"*

---

## Kernkonzept

- **Perspektive:** Top-down (isometrisch erst nach dem PoC erwägen — vervielfacht den Asset-Aufwand)
- **Kampf:** Echtzeit-Hack'n'Slash à la Diablo, Maussteuerung
- **Roguelike-Loop:** Permadeath + prozedurale Levels, später Meta-Progression à la Hades (Seelen-Währung, permanente Upgrades)
- **Atmosphäre:** Düster, begrenzter Sichtradius durch Fackellicht, entsättigte Palette mit Akzenten (Blutrot, Giftgrün)

---

## Phase 1: Design-Entscheidungen festnageln (1–2 Tage)

- [ ] **Steuerung:** Linksklick = laufen/angreifen (Diablo-Standard), Rechtsklick = Skill (optional für PoC), Leertaste/Shift = Dash
- [ ] **Kampf-Grundregeln:**
  - Angriff mit Cooldown (z.B. 0,5 s)
  - Hitbox vor dem Spieler
  - Gegner-Angriffe mit **Windup** (kurze Telegraphierung → Ausweichen möglich; Kern des Spielgefühls!)
- [ ] **Minimal-Stats:** HP, Schaden, Bewegungstempo — sonst nichts

## Phase 2: PoC-Scope schriftlich fixieren

Der PoC prüft nur: Fühlt sich Klicken, Treffen und Ausweichen gut an ("Game Feel")?

**Enthalten:**
- [ ] 1 prozedural generierte Ebene (Rooms & Corridors)
- [ ] 1 Spielfigur
- [ ] 2 Gegnertypen: Nahkämpfer (rennt auf dich zu) + Fernkämpfer (hält Abstand, schießt Projektil)
- [ ] 1 Nahkampfangriff, 1 Heiltrank auf Hotkey
- [ ] Fog of War / Sichtradius per Licht (PointLight2D → gratis düstere Atmosphäre)
- [ ] Tod = Neustart
- [ ] Platzhalter-Grafik (farbige Rechtecke reichen!)

**Bewusst NICHT enthalten (nach dem PoC):**
Pixel-Art, Meta-Progression, Biome, Bosse, Item-Vielfalt, Skilltrees, Sound, Balancing, Monetarisierung

## Phase 3: Technisches Fundament (parallel zu Phase 1)

- [ ] Godot 4.x installieren, nur Desktop-Export
- [ ] Kern-Nodes lernen:

| Node | Zweck |
|---|---|
| `CharacterBody2D` + `move_and_slide()` | Bewegung Spieler & Gegner |
| `NavigationRegion2D` / `NavigationAgent2D` | Klick-Bewegung, Gegner-Pathfinding um Wände |
| `Area2D` | Angriffs-Hitboxen und Projektile |
| `AnimationPlayer` / `AnimatedSprite2D` | Angriffs-Timing, Windups |
| `PointLight2D` + `LightOccluder2D` | Fackellicht, Schatten, Fog of War |

- [ ] **Szenen-Struktur:** `Player`, `Enemy` (Basis-Szene, Varianten erben), `Projectile`, `LevelGenerator`, `GameManager` (HP, Tod, Neustart)

## Phase 4: Bauen (3–5 Wochen als Feierabend-Projekt)

Reihenfolge — **Game Feel zuerst**:

1. [ ] **Spieler-Bewegung** per Klick (`NavigationAgent2D`) in einem handgebauten Testraum
2. [ ] **Angriff:** Klick auf Gegner → hinlaufen bis Reichweite → zuschlagen.
   → Sofort an Feedback arbeiten: **Hit-Flash, kurzer Knockback, Screenshake.**
   → *Hier stecken 80 % des Diablo-Gefühls. Unverhältnismäßig viel Zeit investieren!*
3. [ ] **Gegner-KI:** Zustandsmaschine mit 3 Zuständen: `Idle` → `Verfolgen` (sieht Spieler) → `Angreifen` (in Reichweite, mit Windup)
4. [ ] **Fernkämpfer + Projektil**
5. [ ] **Levelgenerator** anschließen (Rooms & Corridors)
   → Navigation-Mesh pro generierter Ebene neu backen: `NavigationRegion2D.bake_navigation_polygon()`
   → Erreichbarkeit garantieren (Treppe immer verbunden, Flood-Fill-Check)
6. [ ] **Licht/Fog of War**, Treppe, Ebenenwechsel, Tod & Neustart

## Erfolgskriterium

> **"Das Kämpfen gegen 3–4 Gegner gleichzeitig fühlt sich knackig an, und ich spiele freiwillig 5 Runs am Stück."**

Fühlt es sich schwammig an → an Schritt 2 (Feedback/Game Feel) schrauben, **bevor** neue Features gebaut werden.

---

## Ausblick nach erfolgreichem PoC

1. **Meta-Progression** (Hades-Style): Seelen-Währung, Hub, permanente Upgrades, Freischaltungen
2. **Pixel-Art & Atmosphäre:** düstere Tilesets, Gore-Details, Ambient-Sound
3. **Ebenen-Struktur:** alle 4–5 Ebenen Boss/Elite-Raum, Biomwechsel (Krypta → Katakomben → Fleischgrube)
4. **Prefab-Räume** einstreuen (Schatzkammer, Schrein, Bossarena — wie Spelunky/Dead Cells)
5. **Risk/Reward:** verfluchte Truhen, optionale Schatzräume; Loot/Gegner nach Distanz zum Spawn skalieren
6. **Content:** 5–8 Gegnertypen, 20–30 Items, Skills, Controller-Support
7. **Vertrieb:** itch.io (kostenlos, unkompliziert) → später Steam; Mobile-Port optional