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

- `projectile.png`: 16×16, 2 Frames nebeneinander (Flackern), giftgrünes Geschoss.
- `stairs.png`: 32×32, abwärtsführende Steintreppe, von oben.
- `potion_icon.png`: 16×16, roter/grüner Heiltrank (HUD).

## Einbau-Reihenfolge

1. Tileset tauschen → sofort sichtbar, kein Code nötig.
2. Charakter-Sheets liefern → nächster Milestone verdrahtet AnimatedSprite2D
   (ersetzt die Polygon2D-Rechtecke; Hit-Flash-Shader und alle Effekte bleiben).
3. Treppe/Projektil/Icons → Kleinigkeiten, jederzeit.
