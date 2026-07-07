# Gegner-Register

Bestand, Spawn-Regeln und das Rezept für neue Typen. Bei jedem neuen oder
geänderten Gegner: diese Datei aktualisieren + Asset-Eintrag in
`asset-spec.md` §4 (Regel in CLAUDE.md).

## Bestand

| Typ | Szene | Rolle | HP | Tempo | Schaden | Seelen | Verhalten / Konterspiel |
|---|---|---|---|---|---|---|---|
| **Brute** (Nahkämpfer) | `melee_enemy.tscn` (= Basis `enemy.tscn`) | Druck aufbauen | 3 | 200 | 1 | 2 | Verfolgt, Windup 0,45s mit fixierter Richtung + Lunge. **Konter:** Seitwärts/Dash während des Windups → Whiff, dann bestrafen |
| **Kultist** (Fernkämpfer) | `ranged_enemy.tscn` | Zonen kontrollieren | 2 | 160 | 1 | 3 | Hält Band 180–380px, flieht bei Annäherung, in der Ecke feuert er trotzdem. Projektil 420px/s, kein Homing. **Konter:** seitlich ausweichen, durch Nahkämpfer zu ihm durchbrechen |
| **Exploder** | `exploder.tscn` | Tempo erzwingen | 2 | **340** (> Spieler!) | 2 (AoE r90) | 3 | Sprintet an, bläht sich 0,6s auf (Ring = echter Radius), detoniert. Tod durch Spieler = 0,45s Zündschnur, explodiert trotzdem. **Friendly Fire!** **Konter:** auf Distanz töten + weggehen, in Gruppen locken, oder im letzten Moment rausdashen |
| **Schild-Tank** | `shield_tank.tscn` | Positionierung erzwingen | 6 | 130 | 2 | 5 | Blockt ALLES im 100°-Frontkegel (Clank + blauer Blitz), von hinten normal verwundbar; dreht träge (`turn_speed` 2,5 rad/s ≈ 143°/s — einziger Gegner mit Dreh-Cap, alle anderen drehen instant). **Konter:** hinter ihn dashen und zuschlagen, bevor er nachgedreht hat (~1s Fenster); Exploder-Blasts/Feuerflächen treffen die Flanke |
| **Beschwörer** | `summoner.tscn` | Prioritätsziel | 3 | 150 | — | 6 | Kitet wie der Kultist; 0,8s-Ritual beschwört 2 Diener-Brutes (2 HP, 1 Seele — kein Farming), Cap 3 lebende. **Konter:** sofort durchbrechen und ihn zuerst töten |
| **Kryptwächter** (Boss) | `boss.tscn` | Ebenen-Höhepunkt (Zoner/Bruiser) | 25 (+15/Stufe) | 140 | 2 | 40 (+20/Stufe) | Ebene 5 (dann rotiert). Nah: AoE-Ring r120 (0,7s Telegraph). Fern: Ring aus 8 Projektilen. Unter 50% HP: Enrage (0,55× Cooldown). 75% Knockback-Resistenz. Sieg gebankt beim Kill; danach Portal ODER Treppe |
| **Fleischkoloss** (Boss) | `fleischkoloss.tscn` | Boss (Rusher) | 30 (+15/Stufe) | 145 | 3 | 45 | Ebene 10 (rotiert). Fern: telegraphierte Bahn → **CHARGE** quer durch die Arena (seitwärts aus der Bahn!). Nah: Boden-Schockwelle r130. Enrage <50%. 75% Knockback-Resistenz |
| **Beschwörerkönig** (Boss) | `beschwoererkoenig.tscn` | Boss (Summoner) | 22 (+15/Stufe) | 120 | 2 | 45 | Ebene 15 (rotiert). Wechselt Beschwörung (2 Diener-Brutes) und 5er-Projektil-Fächer; **blinkt weg**, wenn der Spieler <105px kommt. Enrage <50% |
| **Seuchenbischof** (Boss) | `seuchenbischof.tscn` | Boss (Zoner) | 26 (+15/Stufe) | 110 | 2 | 45 | Ebene 20 (rotiert). Nah: legt 3 brennende Bodenflächen (telegraphierte Ringe) auf/um den Spieler; fern: rotierende Projektil-**Spirale**. Enrage <50% |
| **Die Quelle** (Endboss) | `quelle.tscn` | **Run-Ziel** (Ebene 50) | 55 (eigen, kein Stufen-Ramp) | 90 | 2 | 120 | Ebene 50, das Sieg-Ziel des Runs. Fast stationärer Caster mit 3 Mustern: nah AoE-Ring r130; fern dichter 12er-Projektil-Ring; jedes 3. Mal **Brut** (gebiert 3 Brutes, Cap 4). Enrage <50% (0,5× CD). Kill = Sieg gebankt → WinScreen (Hub oder endlos weiter). **Interim:** getönte Seuchenbischof-Frames (asset-spec §4) |

**Elite-Modifikator** (kein eigener Typ): `elite = true` auf Brute/Kultist —
violett, 1,3×, HP ×2+2, +1 Schaden, Seelen ×3, **garantierter Relikt-Drop**.
Max. 1 pro Ebene, ab Ebene 2, Exploder ausgenommen. Logik in `enemy.gd`
(`_ready`-Elite-Block + `_die`-Drop).

## Spawn-Regeln (GameManager.BIOMES + level_generator.gd)

Der Mix kommt pro **Biom** aus `GameManager.BIOMES` (Gewichte + Elite-Chance);
neue Typen debütieren als neues Gewicht im passenden Biom:

Fünf Bänder à 10 Ebenen (Run-Ziel: Ebene 50, plan.md „Rahmen & Run-Ziel"):

| Biom | Ebenen | Brute | Kultist | Exploder | Tank | Beschwörer | Elite-Chance |
|---|---|---|---|---|---|---|---|
| Krypta | 1–10 | 0.45 | 0.35 | 0.2 (ab E2) | – | – | 12% |
| Katakomben | 11–20 | 0.25 | 0.3 | 0.3 | 0.15 | – | 15% |
| Fleischgrube | 21–30 | 0.2 | 0.25 | 0.35 | 0.1 | 0.1 | 18% |
| Fäulnisschlund | 31–40 | 0.15 | 0.2 | 0.3 | 0.2 | 0.15 | 20% |
| Herz der Seuche | 41+ | 0.1 | 0.2 | 0.3 | 0.2 | 0.2 | 22% |

- Ebene 1: Exploder-Gewicht 0 (Lernkurve), keine Elites (ab Ebene 2, max 1/Ebene).
- Elite-Ausschluss: Exploder und Beschwörer (`ELITE_EXCLUDED`).
- Die zwei tiefsten Biome nutzen interim das Fleischgrube-Tileset + eigene
  Dunkelheit (dedizierte Tilesets offen — asset-spec §4.5).
- Skalierung pro Tiefe: +1 max_hp alle 2 Ebenen **(Cap +12, ~ab E25)**, +8 Tempo/
  Ebene (Cap +60), +1 Gegner/Raum alle 3 Ebenen (Cap 4), +1 Seele alle 3 Ebenen.
  Späte Härte kommt aus Biom-Mix/Elite/Anzahl, nicht aus HP-Schwämmen.
- Boss-Ebenen (5, 10, …): nur der Boss, keine normalen Spawns; Arena nutzt
  Tileset/Dunkelheit des jeweiligen Bioms. **Der Boss-Typ rotiert pro Stufe**
  (`BOSS_SCENES` in level_generator.gd): E5 Kryptwächter → E10 Fleischkoloss →
  E15 Beschwörerkönig → E20 Seuchenbischof → dann von vorn, jeweils hochskaliert
  (HP-Ramp +15/Stufe, gedeckelt bei +60). **Ausnahme Ebene 50: `quelle.tscn`
  („Die Quelle") als Endboss — das Sieg-Ziel; Kill bankt den Sieg und öffnet den
  WinScreen (Hub oder endlos weiter absteigen).**
  Gemeinsame Basis `boss_base.gd` (Gruppe „boss", `defeated`-Signal, Knockback-
  Resistenz, `boss_name` für die HUD-Bossleiste, Ring/Lane-Telegraph-Helfer, kein
  `hurt`-Flinch); jeder Boss implementiert nur seine Muster via die enemy.gd-Hooks.
  **Sprites interim** (getönte Kryptwächter-Frames), echte 8-Richtungs-Sprites
  offen — asset-spec §4.

## Rezept: neuen Gegnertyp anlegen

1. **Script** `scenes/enemies/<name>.gd`: `extends "res://scenes/enemies/enemy.gd"`.
   Überschreibbare Hooks der Basis:
   - `_in_attack_position() -> bool` — wann darf er angreifen (Distanz/LOS)
   - `_chase_velocity() -> Vector2` — Bewegungsverhalten (Kiting etc.; `super()` = Nav-Verfolgung)
   - `_show_attack_tell()` — Zusatz-Telegraph im Windup (Ring, Klinge …)
   - `_perform_attack()` — was beim Zuschlagen passiert
   - bei Bedarf `take_damage`/`_die` mit `super()`-Aufruf (siehe exploder.gd/boss.gd)
2. **Szene** `scenes/enemies/<name>.tscn`: geerbte Szene
   (`[node name="X" instance=ExtResource("…enemy.tscn")]`), Script + Dials als
   Property-Overrides setzen. **Dials sind @export-Variablen** (Kind-Skripte
   können Konstanten der Basis nicht überschreiben). Interim-Optik: `Visual`
   mit `self_modulate`-Tönung überschreiben; sobald der PixelLab-Charakter da ist,
   stattdessen `Visual.sprite_frames` (auf `<name>_frames.tres`) überschreiben und
   `scale`/`offset` auf Brute-Größe normieren, Tint weg — siehe
   exploder/shield_tank/summoner.tscn (alle drei haben jetzt echte 8-Richtungs-Sprites).
3. **Telegraph-Regel einhalten** (docs/plan.md, Kern des Feels): jeder Angriff
   hat einen Windup mit sichtbarem Tell; Richtung lockt beim Windup-Start.
4. **Spawn-Tabelle** in `level_generator.gd` erweitern (Preload + Chance/Gewicht,
   ggf. Mindest-Ebene für die Lernkurve).
5. **Asset-Eintrag** in `asset-spec.md` §4 (PixelLab-Charakter: 8 Richtungen,
   idle/walk/attack/death/hurt — Pipeline-Details in der Memory/Spec).
   **Sound:** eigenen `death_sound`-Key vergeben (@export-Dial der Basis,
   Interim-Synth in `sfx.gd`) + Eintrag in `audio-spec.md` (Regel in CLAUDE.md).
6. **Dieses Register** um die neue Zeile ergänzen.
7. **Verifizieren:** Szene instanzieren (`--headless --scene … --quit-after 10`),
   Headless-Probe mit `print()` für das Kernverhalten, dann Feel-Test.
   (`--check-only -s` schlägt bei Autoload-Referenzen fehl — bekannte Macke.)

## Ideen-Backlog (aus plan.md Punkt 7, Ziel 5–8 Typen — Stand: 5 erreicht)

- **Springer/Lurker:** wartet getarnt (dunkler Sprite), springt auf Distanz
  an — Schreckmoment für dunkle Korridore.
- **Splitter:** mittelgroß, zerfällt beim Tod in 2 Mini-Brutes.
