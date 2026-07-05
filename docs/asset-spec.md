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
