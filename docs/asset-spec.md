# Asset-Spezifikation für Pixel-Art (Bild-KI oder manuell)

Ziel-Look: `assets/sample/sample.png` (Stimmungsreferenz, isometrisch).
**Wichtig: Unser Spiel ist top-down, nicht isometrisch** — alle Assets werden in
Draufsicht bzw. leichter Aufsicht ("3/4 top-down", wie Zelda/Enter the Gungeon)
gebraucht, nicht in Iso-Perspektive.

Allgemeine Anforderungen an jede Datei:
- Sauberes Pixel-Art ohne Anti-Aliasing, ohne Weichzeichner-Halos an Kanten.
- Einheitliche, entsättigte dunkle Palette (blaugraue Steine, Akzente in
  Blutrot/Giftgrün/Fackelorange — siehe Sample).
- PNG. Charaktere/Objekte mit transparentem Hintergrund; Tiles opak.
- Exakte Pixelmaße wie unten — das Spiel rendert 1:1 mit Nearest-Filter.

## 1. Tileset (sofort einbaubar)

> **Status (erledigt):** über PixelLab `create_tiles_pro` (square top-down, 32px)
> generiert und als `tileset_placeholder.png` im **gleichen 256×64-Layout**
> eingebaut — Böden `(0,0)`–`(3,0)`, Riss `(4,0)`, Wände `(0,1)`–`(2,1)`. Drop-in,
> kein Code nötig (`level_generator.gd` liest dieselben Atlas-Zellen).

Ersetzt `assets/sprites/tileset_placeholder.png` — **gleicher Dateiname, gleiches
Layout**, dann ist es ohne Code-Änderung im Spiel:

- Gesamtbild: **256×64 px** = 8 Spalten × 2 Reihen à **32×32 px**.
- Reihe 0 (oben): Spalte 0–3 = vier Steinboden-Varianten (dezent verschieden,
  frei kombinierbar), Spalte 4 = Boden mit Riss/Schaden. Spalten 5–7 frei
  (werden ignoriert).
- Reihe 1: Spalte 0–2 = drei Backstein-/Mauerwerk-Varianten. Spalten 3–7 frei.
- **Böden müssen nahtlos kacheln** (jede Variante mit jeder, alle Richtungen).
  Wände müssen horizontal nahtlos kacheln.
- Lesbarkeit: Die Fackel beleuchtet nur einen Ausschnitt — Texturen dürfen
  kontrastarm sein, brauchen aber erkennbare Struktur (Fugen, Kanten).

Prompt-Baustein (englisch, für Bild-KI):
> "32x32 pixel art dungeon tile, top-down view, dark desaturated blue-grey
> stone floor slabs with mortar seams, seamless tileable, clean 1px pixel art,
> no anti-aliasing, flat lighting (no baked-in light direction), muted palette"

## 2. Charakter-Sprite-Sheets (brauchen danach einen Code-Milestone)

> **Status Spieler (erledigt, abweichend von der Tabelle unten):** Der Spieler
> wird nicht mehr als eine einzelne rechts-blickende Datei umgesetzt, sondern
> über **PixelLab (MCP)** als **8-Richtungs-Charakter** generiert — 48×48 px
> Frames (Figur ~14×33 px, sitzt ohne Skalierung auf den 32er-Tiles), Idle 4f /
> Laufen 6f / Angriff 5f pro Richtung. Frames liegen unter
> `assets/sprites/player/<state>/<richtung>/`, gebündelt in
> `player_frames.tres` (SpriteFrames, 24 Clips `"<state>_<richtung>"`). Der
> Player nutzt jetzt eine `AnimatedSprite2D` (Node „Visual"), gesteuert von
> `state` + `_pivot.rotation` (siehe `_update_animation()` in `player.gd`); die
> Polygon2D-Rechtecke und die WeaponVisual sind entfernt, Hit-Flash-Shader und
> alle Effekte bleiben.
>
> **Status Gegner (erledigt):** Nahkämpfer (`brute`, blutroter Dämon),
> Fernkämpfer (`cultist`, giftgrüner Armbrust-Kultist) und Boss (`Kryptwächter`,
> schwarze Platte + Cleaver) sind ebenfalls über PixelLab als 8-Richtungs-
> Charaktere generiert (idle/walk/attack). Frames unter
> `assets/sprites/enemies/<name>/<state>/<richtung>/`, je ein
> `<name>_frames.tres`. `enemy.tscn` (=Nahkämpfer) trägt die Brute-Frames;
> `ranged_enemy.tscn`/`boss.tscn` überschreiben `sprite_frames` + `offset`.
> `enemy.gd` fährt jetzt eine `AnimatedSprite2D`: das gelbe Windup-Telegraph
> tönt `self_modulate` (statt `color`), der Melee-„Lunge" bleibt, die WeaponVisual
> ist weg. Der windup→snap-Read (docs/plan.md) bleibt voll erhalten.
>
> **Status Tod/Treffer (erledigt):** Alle Figuren haben zusätzlich `death`
> (falling-back-death) und `hurt` (taking-punch) je Richtung — außer der Boss
> (kein `hurt`, bleibt unerschütterlich). `_die()` spielt jetzt `death_<dir>` und
> blendet dann aus (Player + Gegner); der Spieler-Flinch ist **nicht
> unterbrechend** (kein Hitstun, plan.md), der Gegner-Flinch pausiert nicht während
> des eigenen Windups. Frames/Clips liegen bei den jeweiligen `*_frames.tres`.

Alle Charaktere: **32×32 px pro Frame**, horizontale Streifen (Frames
nebeneinander), Blickrichtung **rechts** (das Spiel rotiert/spiegelt selbst),
transparenter Hintergrund. Pro Datei eine Animation pro Zeile:

| Datei | Zeile 1: Idle | Zeile 2: Laufen | Zeile 3: Angriff |
|---|---|---|---|
| `player.png` | 4 Frames | 6 Frames | 4 Frames |
| `melee_enemy.png` | 4 | 4 | 4 (Frame 1–3 = Ausholen/Windup, Frame 4 = Schlag) |
| `ranged_enemy.png` | 4 | 4 | 4 (Frame 1–3 = Spannen, Frame 4 = Schuss) |

Stil: Spieler = gepanzerte Gestalt (Sample: Ritter), Nahkämpfer = blutrote
dämonische Gestalt, Fernkämpfer = giftgrüner Kultist/Schütze. Silhouetten
müssen sich bei 32px klar unterscheiden.

## 3. Kleinkram

> **Status (erledigt):** `projectile`, `potion` (+ HUD-Icon in `hud.gd`), `stairs`,
> Seelen-Wisp und die 4 Hub-Schreine (Edelstein je Upgrade umgefärbt via Hue-Shift,
> Textur/Glow per `upgrade_id` in `shrine.gd`) sind über PixelLab map-objects generiert
> und verdrahtet (Polygon2D → Sprite2D, `assets/sprites/props/`). Keine Platzhalter mehr.

- `projectile.png`: 16×16, 2 Frames nebeneinander (Flackern), giftgrünes Geschoss.
- `stairs.png`: 32×32, abwärtsführende Steintreppe, von oben.
- `potion_icon.png`: 16×16, roter/grüner Heiltrank (HUD).

## 4. Offene PixelLab-Aufgaben (Stand Juli 2026)

> **Status (erledigt, Sprite-Pass Juli 2026):** Punkte 1, 2, 3, 4, 5, 7, 8, 9, 10
> sind umgesetzt und verdrahtet — **nur Punkt 6 (Feuerfläche) bleibt bewusst
> prozedural** (funktioniert, laut Spec optional). Konkret:
> - **1 Truhe / 9 Blutschrein-Altar:** `create_map_object` 32×32 → `chest.png` /
>   `blood_altar.png`, Polygon2D→Sprite2D; „verflucht"/„erschöpft" jetzt per
>   Runtime-`modulate` (statt eigener Hue-Shift-PNG).
> - **2 Relikt-Icons / 10 Waffen-Icons / Skill-Icons:** 15 Icons à 32×32
>   (`create_map_object`, view=side) in `assets/sprites/props/` als
>   `relic_<id>.png` / `skill_<id>.png` / `weapon_<id>.png` (+ `skill_dash.png`,
>   `heart.png`). Pickups (Polygon2D→Sprite2D, Runtime-`load`) + HUD (preload-Dicts).
> - **10 Waffen-Schwünge:** ✅ komplett (Juli 2026, zweiter Pass). Erster Pass
>   war motion-only (immer dieselbe Axt in der Hand); jetzt pro Waffe ein
>   PixelLab-**Character-State** des Crypt Knight mit sichtbarer Waffe
>   (Kurzschwert-State `cfd661d3`, Spieß `c4871694` grün glühende Klinge,
>   Kriegshammer `ac890abe` oranger Doppelkopf) + v3-Attack je State:
>   `attack_<dir>` = Schwert-Slash, `attack_spiess_<dir>` = Stoß,
>   `attack_kriegshammer_<dir>` = Überkopfschlag. Frames in-place ersetzt
>   (gleiche Pfade/5f/48×48), `player_frames.tres` unverändert;
>   `player.gd _update_animation` wählt per `weapon_id`.
> - **4 Gore:** `gore_splatter_a/b.png` + `bone_pile.png`; Blut-Decal-Hook in
>   `enemy.gd _spawn_gore()` (bei `_die()`), Knochenhaufen streut der Generator.
> - **5 Biom-Tilesets:** ✅ im zweiten Anlauf (Juli 2026). Erster Pass lief mit
>   `tile_view="high top-down"` → Kacheln mit Tiefenkante + Transparenz-Padding
>   (nur ~36–78 % opak) → schwarze Streifen ab Ebene 6; zurückgerollt. Rezept
>   wie beim Krypta-Atlas: `create_tiles_pro` mit **`tile_view="top-down"`**
>   (flach!), square_topdown 32 px, segmentation; 16 Varianten, daraus 5 Boden
>   + 3 Wand aufs 256×64-Raster montiert, jede Zelle auf opake Grundfarbe
>   komponiert und Alpha == 255 programmatisch verifiziert (Skript
>   `assemble_atlas.py`, Session-Scratchpad).
> - **7 Gegner-Sprites:** Exploder/Schild-Tank/Beschwörer als 8-Richtungs-Chars
>   (idle/walk/attack/death/hurt), `<name>_frames.tres`, Interim-Tints entfernt,
>   Visual-`scale`+`offset` auf Brute-Größe normiert.
> - **8 Projekt-Icon:** `assets/icon.png` (128×128), `config/icon` gesetzt.
> - **3 Hübsches HUD:** PixelLab-Font (`create_font` → `assets/fonts/hud_font.ttf`,
>   projektweit via `assets/ui/hud_theme.tres`) + Zierrahmen (`create_ui_asset` →
>   `assets/sprites/ui/hud_frame.png`, 9-slice-Helfer `_nine` in `hud.gd` /
>   `full_map_view.gd`). `hud.gd` zeichnet jetzt gerahmte HP-Leiste, Slot-Rahmen,
>   Boss-Leiste, Ebenen-Plakette, Minimap-Rahmen.
> - **Offen:** 6 Feuerfläche (4-Frame-Loop) — Rezept: `create_1_direction_object`
>   (64) → `animate_object` (v3, „flackernde Flammen") → SpriteFrames, dann
>   `fire_patch.gd` `_draw` gegen `AnimatedSprite2D` tauschen (Licht/Ticks bleiben).
> - **Offen (in Arbeit): 3 Boss-Sprites** (Fleischkoloss/Beschwörerkönig/
>   Seuchenbischof) — gleiche 8-Richtungs-Pipeline wie Kryptwächter, aber nur
>   idle/walk/attack/death (kein hurt). Interim = getönte Kryptwächter-Frames
>   (`self_modulate` je `<boss>.tscn`). Swap: `<name>_frames.tres` +
>   `Visual.sprite_frames` überschreiben, Tint weg, `scale`/`offset` justieren.

Was noch Platzhalter ist bzw. gebraucht wird, nach Priorität. Technik-Hinweise:
statische Props via `create_map_object` (min. 32×32), Tiles via `create_tiles_pro`
(NICHT `create_topdown_tileset` — das ist ein Wang-Autotiler), Umfärbungen
kostenlos per Hue-Shift wie bei den Schrein-Edelsteinen.

1. **Truhe** (`scenes/pickups/chest.tscn` ist noch Polygon2D): `chest.png` 32×32,
   geschlossene Holztruhe mit Metallband, von oben. Verfluchte Variante =
   Hue-Shift ins Violette (0 Gens). Optional zweiter Frame „offen" — aktuell
   wird beim Öffnen nur abgedunkelt.
2. **7 Relikt-Icons** 16×16 (Boden-Pickup + HUD ersetzen die farbigen Rauten):
   Brandsiegel (Flamme), Blutdurst (Blutstropfen), Schattenschritt (Stiefel/
   Schemen), Wuchtklinge (Faust/Hammer), Hetzjagd (Flügel), Konzentrat
   (Trank+Stern), Seelengier (Seelen-Auge). Farbcodes stehen in
   `GameManager.RELIC_DEFS` — Icons sollten je Relikt in dieser Farbe dominieren.
3. **Hübsches HUD** (komplettes UI-Paket im Stil von `sample.png` — gerahmte
   Balken statt roher Rechtecke). PixelLab-Tools: `create_ui_asset` für
   Rahmen/Balken/Slots, `create_font` für die Schrift. Braucht danach einen
   **Code-Milestone** (hud.gd zeichnet dann Texturen/NinePatch statt
   `draw_rect`). Bestandteile:
   - **HP-Leiste**: verzierter Rahmen (NinePatch-tauglich, ~240×28) + rote
     Füll-Textur + Herz-Icon als Endkappe; Füllung als eigene Ebene, damit
     der Code sie beschneiden kann.
   - **Slot-Rahmen** 26×26 (dunkler Metall-/Steinrahmen, Diablo-Hotbar-Look)
     für Trank-Gürtel, Dash, den (jetzt austauschbaren) Skill-Slot und die
     4 Relikt-Plätze; Variante „leer" = abgedunkelt, Cooldown-Füllung macht
     weiterhin der Code.
   - **Skill-Icons** 16×16: Dash (Stiefel/Schemen), plus je eins für
     Rundumschlag (Schockwelle), Frostnova (Eiskristall), Blutopfer
     (Blutstropfen+Explosion), Seelenkette (Kette/Sog) — Farbcodes in
     `GameManager.SKILL_DEFS`.
   - **Seelen-Zähler-Icon** 16×16 (cyan Wisp) + **Ebenen-/Biom-Plakette**
     (kleines Banner ~120×24 hinter „Ebene 6 — Katakomben").
   - **Boss-Leiste**: breiter Zierrahmen (~380×24) mit dunkler Füllung.
   - **Minimap-Rahmen** (~160×90, oben rechts) + **Karten-Rahmen** für die
     große [M]-Kartenansicht (`autoloads/full_map_view.gd`) — aktuell beides
     rohe `draw_rect`/`draw_circle`-Formen auf aufgedecktem Fog-of-War.
   - **Pixel-Font** (via `create_font`): leicht gotisch, aber bei Größe 10–16
     gut lesbar; ersetzt die Godot-Fallback-Font überall (HUD, Labels,
     Pause-Menü, Schrein-Texte).
4. **Gore/Blut-Decals** (plan.md Ausblick 2): 2–3 Blutspritzer 32×32 (opak auf
   Boden gelegt, per Zufallsrotation beim Gegner-Tod gespawnt) + Knochenhaufen
   als Raum-Deko. Braucht einen kleinen Code-Hook in `enemy._die()`.
5. **Biom-Tilesets** ✅ erledigt (Juli 2026, zweiter Anlauf — Details im
   Erledigt-Block oben): Katakomben = braune Knochen-/Schädelwände,
   Fleischgrube = rötlich-organisch (Venen, Rippen, Schorf-Risse).
   **Abnahmekriterium für alle künftigen Tileset-Pässe:** jede belegte
   32×32-Zelle randfüllend und voll opak (kein Transparenz-Padding — im Spiel
   werden daraus schwarze Streifen); `create_tiles_pro` zwingend mit
   `tile_view="top-down"` für dieses flache Atlas-Format, Roh-Tiles selbst
   aufs Raster montieren und Alpha programmatisch prüfen.
6. **Feuerfläche** (Brandsiegel-Relikt, aktuell prozedural gezeichnet): optional
   4-Frame-Loop 64×64 Bodenfeuer, transparent.
7. **Sprites für gebaute Gegnertypen** (gleiche 8-Richtungs-Pipeline wie
   Brute/Cultist, idle/walk/attack/death/hurt):
   - **Exploder** (interim: orange getönter Brute): aufgedunsener Kadaver /
     Bombenträger, sollte "gleich platzt er" ausstrahlen.
   - **Schild-Tank** (interim: stahlblau getönter Brute): massige Gestalt mit
     Turmschild nach vorn — die Front muss als "geschützt" lesbar sein.
   - **Beschwörer** (interim: violett getönter Kultist): Ritualist mit Grimoire/
     Stab; Attack-Animation = Beschwörungsgeste (kein Schuss).
   - Künftige Typen (Lurker, Splitter …) erst nach dem Bau generieren.
8. **Projekt-Icon** (Fenster/Dock + itch.io-Export): 128×128, z.B. der
   Kryptritter-Kopf vor dunklem Portal. `config/icon` in project.godot setzen.
9. **Blutschrein-Altar** (`scenes/levels/blood_shrine.tscn` ist Polygon2D):
   32×32 dunkler Steinaltar mit rotem Kristall, von oben; „erschöpft"-Variante
   = entsättigter Hue-Shift (0 Gens). Stil wie die Hub-Schreine.
10. **Waffen-System**: ✅ komplett erledigt — Icons (Sprite-Pass 2), Schwung-
    Animationen mit sichtbarer Waffe (Waffen-State-Pass) UND jetzt die
    **Idle/Walk-Sets pro Waffe** (2026-07-07): auf den Character-States
    `cfd661d3`/`c4871694`/`ac890abe` je `breathing-idle` (4f) + `walking-6-frames`
    (6f) generiert; Kurzschwert überschreibt in-place die Basis `idle/`+`walk/`
    (Basis = Kurzschwert, wie `attack_<dir>`), Spieß/Kriegshammer als neue Ordner
    `idle_spiess`/`walk_spiess`/`idle_kriegshammer`/`walk_kriegshammer` +
    `player_frames.tres`-Clips (jetzt 88 Clips). `player.gd _update_animation`
    wählt über den Helfer `_weapon_clip(base, dir)` → `<base>_<weapon>_<dir>`
    mit Fallback auf `<base>_<dir>` (Kurzschwert fällt immer auf die Basis
    zurück — identisch zum Attack-Muster). Damit trägt der Held die angelegte
    Waffe auch beim Stehen/Laufen (vorher immer die Axt). Verifiziert per
    Screenshot (Schwert/Spieß/Hammer im Idle). Auch die **Hurt/Death-Sets pro
    Waffe** sind nachgezogen (2026-07-07, zweite Runde): Basis `hurt/`+`death/`
    in-place = Kurzschwert, dazu `hurt_spiess`/`death_spiess`/
    `hurt_kriegshammer`/`death_kriegshammer` (120 Clips gesamt);
    `player.gd` spielt Flinch und Todesfall über `_weapon_clip("hurt"/"death",
    dir)`. Achtung Rezept: die Templates `taking-punch`/`falling-back-death`
    **halluzinieren die gehaltene Waffe** auf Waffen-States (Streithammer/Axt/
    Sichel statt Schwert bzw. Hammer) — Schwert-hurt/-death und Hammer-hurt
    mussten als v3 mit expliziter Waffenbeschreibung neu generiert werden;
    nur die Spieß-Sets überlebten die Templates. Damit ist die alte Axt
    vollständig aus allen Spieler-Animationen verschwunden.
11. **Seelenschrein-Altar** (`scenes/levels/soul_shrine.tscn`, interim
    umgefärbter Blutschrein aus Polygon2D): 32×32 dunkler Steinaltar mit
    **cyanem Seelen-Kristall**, von oben; „erschöpft"-Variante = entsättigter
    Hue-Shift (0 Gens). Stil identisch zum Blutschrein-Altar (#9) — ideal
    als Paar in einem Pass generieren, gleiche Silhouette, anderer Kristall.
12. **Endboss „Die Quelle"-Sprite** (`scenes/enemies/quelle.tscn`, interim =
    rötlich getönte Seuchenbischof-Frames + 1,5× scale): der Ursprung der
    Fleischseuche und das Sieg-Ziel des Runs — sollte groß, pulsierend-organisch
    und „gebärend" wirken (Fleischknoten/Augen/Tentakel). Gleiche 8-Richtungs-
    Pipeline wie die anderen Bosse (idle/walk/attack/death, kein hurt). Swap:
    `quelle_frames.tres` + `Visual.sprite_frames` überschreiben, Tint weg,
    `scale`/`offset` justieren. Optional eigenes „Brut"-Telegraph-Sprite.
13. **2 tiefe Biom-Tilesets** (Biom-Umbau 5×10, plan.md §3): `Fäulnisschlund`
    (Ebenen 31–40) und `Herz der Seuche` (41–50) nutzen interim das
    Fleischgrube-Atlas + eigene `darkness`-Tönung (`GameManager.BIOMES`).
    Dediziert: Fäulnisschlund = fauliges, madiges Fleisch (grünlich-braun);
    Herz der Seuche = pulsierendes Herzkammer-Rot, das Zentrum der Seuche.
    Gleiches 256×64-Format/Abnahmekriterium wie #5; Ziel-Dateien z.B.
    `tileset_faeulnisschlund.png` / `tileset_herz.png`, dann die `tileset`-Pfade
    der beiden Bänder in `GameManager.BIOMES` umbiegen.
14. **Waffen-Paperdoll-Ebene** (Kür / Code-Milestone, optional — lohnt erst,
    wenn Waffen ein echtes Loot-System mit 8+ Typen werden). Ersetzt den
    aktuellen Ansatz „ein kompletter Animations-Satz pro Waffe" durch eine
    angeheftete Waffen-Ebene und macht die Waffe dadurch **frame-genau stabil**
    (behebt den Rest-Drift, bei dem PixelLab die kleine Klinge pro Frame neu
    malt — aktuell per v3-Reroll pro Richtung gedämpft, siehe #10). Danach
    kostet jede **neue** Waffe nur noch ein Sprite statt einer kompletten
    Charakter-Generierung. Bestandteile:
    - **Waffenloser Basis-Ritter:** `create_character_state` („empty open hands,
      no weapon") auf dem Crypt Knight, darauf idle/walk/attack/hurt/death neu
      generieren — einmalig der komplette Moveset mit freier Hand.
    - **Waffen-Sprites je Waffe**, vermutlich **pro Blickrichtung eigenes**
      (Top-Down-Klinge sieht nach NO anders aus als nach SW); die Icon-Sprites
      `weapon_<id>.png` taugen dafür nicht direkt (Icon-gerahmt).
    - **Hand-Anker-Tabelle:** je Richtung × Frame × State ein 2D-Offset
      (+ Rotation), grob 8×~6×5 ≈ **240 Punkte**, von Hand nach Augenmaß.
      Achtung: PixelLab hat intern ein Skelett, **exportiert die Gelenk-
      Koordinaten aber NICHT** über die MCP-Tools (nur flache PNGs) — die Anker
      müssen selbst hergeleitet/geklickt werden. Das ist der eigentliche Aufwand.
    - **Engine-Umbau** in `scenes/player/player.tscn` + `player.gd`: zweiter
      Sprite-Node „WeaponVisual", der pro Frame Basis-Clip + Frame-Index +
      Facing liest, aus der Ankertabelle Offset/Rotation zieht und Textur nach
      `weapon_id` setzt; **Z-Order pro Richtung** (Waffe hinter dem Körper bei
      Blick nach Norden/weg, davor bei Süden). Ersetzt die jetzige
      Clip-Auswahl-Logik `_weapon_clip()`.
    - **Zwischenschritt zum Abschätzen:** erst EINE Richtung als Paperdoll
      bauen, um zu sehen, ob das Anker-Tuning erträglich ist, bevor man alle
      240 Punkte macht. Herleitung + Trade-offs im Detail: siehe die
      Waffen-Drift-Notizen im PixelLab-Pipeline-Memory (2026-07-07).

## Einbau-Reihenfolge

1. Tileset tauschen → sofort sichtbar, kein Code nötig.
2. Charakter-Sheets liefern → nächster Milestone verdrahtet AnimatedSprite2D
   (ersetzt die Polygon2D-Rechtecke; Hit-Flash-Shader und alle Effekte bleiben).
3. Treppe/Projektil/Icons → Kleinigkeiten, jederzeit.
