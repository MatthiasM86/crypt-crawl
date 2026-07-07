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

## Rahmen & Run-Ziel (Juli 2026)

Der PoC brauchte keine Story, aber sobald Runs freiwillig wiederholt werden
sollen, braucht ein Run einen **Zielpunkt** — sonst fehlt der „geschafft!"-Moment,
der den nächsten Lauf rechtfertigt. Bewusst schlank (Roguelike-Konvention:
Rahmen in einem Satz, kein Plot; Lore später dosiert wie Hades — über Hub-NPCs,
Schrein-Fragmente, Boss-Intros):

- **Prämisse (ein Satz, Ton-Setzer):** *„Aus der Tiefe der Krypta frisst sich
  eine Fleischseuche nach oben — steig hinab durch Krypta, Katakomben und
  Fleischgrube und vernichte ihren Ursprung, bevor sie die Welt verschlingt."*
  Lesart für die Welt: Die Biome sind Stufen fortschreitender Fäulnis (je tiefer,
  desto verseuchter), die Bosse deren Wächter/Herolde (Seuchenbischof,
  Fleischkoloss, Beschwörerkönig), der Endboss auf Ebene 50 die Quelle selbst.
  Die bestehenden Benennungen tragen den Rahmen schon: Krypta → Katakomben →
  Fleischgrube, Kryptwächter, Seelen-Währung, Blutschreine.
- **Run-Ziel / Sieg-Bedingung:** **Ebene 50** erreichen und den dortigen Endboss
  töten = „Run gewonnen". Sieg wird gebankt (analog Boss-Sieg), Rücksprung in den
  Hub + Lauf-Statistik; danach optional Endlos-/New-Game+-Modus.

**Konsequenzen von „Ebene 50" — umgesetzt (Juli 2026), siehe Ausblick 9:**
- **Run-Länge:** 50 Ebenen bleiben ein langer Permadeath-Lauf (~1–3 min/Ebene →
  grob 1–2,5 h). Bewusst als *aspirationales* Ziel (selten erreicht). Der
  „Endlos weiter"-Ausgang macht 50 zum echten Abschluss statt zum Zwangsende.
  Offen für den Spieltest: ob späte Ebenen sich zäh anfühlen (dann kürzen).
- **Biome:** ✅ auf **5 Bänder à 10 Ebenen** gestreckt (`GameManager.BIOMES`):
  Krypta 1–10 → Katakomben 11–20 → Fleischgrube 21–30 → Fäulnisschlund 31–40 →
  Herz der Seuche 41+. Die zwei tiefsten interim auf Fleischgrube-Tileset +
  eigener Dunkelheit (dedizierte Tilesets: asset-spec §4.13).
- **Difficulty-Scaling:** ✅ Gegner-HP-Bonus bei **+12 gedeckelt** (`SCALE_HP_CAP`,
  ~ab E25), Boss-Stufen-Ramp bei **+60** (`BOSS_HP_SCALE_CAP`); späte Härte über
  Biom-Mix/Elite/Anzahl statt HP-Schwämme. Feintuning im Spieltest offen.
- **Boss-Varianz:** Boss alle 5 Ebenen zyklt weiter (4 Biom-Bosse), **Ebene 50 =
  dedizierter Endboss „Die Quelle"** (`quelle.tscn`, eigene 3 Muster + eigenes HP).
  Feineres „Signature-Boss je Biom" bleibt spätere Kür.

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
   → ✅ *umgesetzt: Seelen-Wisps, begehbarer Hub mit 4 Schreinen, Save-File.
   Entscheidung Juli 2026: neue Skills/Waffen werden NICHT hier permanent
   freigeschaltet, sondern laufen run-gebunden über Punkt 6 — die Schreine
   bleiben reine Stat-Upgrades*

   **Seelen-Ökonomie-Plan (Juli 2026):** Playtest-Befund: alle 4 Schreine sind
   nach wenigen Runs maxed (12 Stufen, 1.240 Seelen gesamt), danach sind Wisps
   wertlos. Beschlossene Gegenmittel, in dieser Reihenfolge:
   → ✅ *alle drei Schritte umgesetzt (Juli 2026). Abweichungen vom Plantext:
   Vitalität-∞ startet bei 400 Seelen (nicht 200 — muss über dem neuen
   Kurvenende von 330 liegen); der Seelenschrein spawnt garantiert 1×/Ebene
   ab Ebene 3 direkt in einem Mittelraum (level_generator) statt über einen
   Prefab-Marker — „1×/Ebene" wörtlich genommen. Neu dabei: `boon`-Sound-Key
   (Synth-Interim, audio-spec §3) und Seelenschrein-Prop-Eintrag
   (asset-spec §4.11).*
   1. *Längere Kostenkurven* — `UPGRADE_DEFS`-`costs`-Arrays (game_manager.gd)
      verlängern: Vitalität 5→8 Stufen (…200, 260, 330), Gürtel 2→3 (…250;
      Deckel 6 Tränke), Reflexe bleibt 3 (0,5s Dash-CD ist untere Feel-Grenze
      für normale Stufen), Wucht bleibt 2 (+1 Waffenschaden ist 33–100% einer
      Waffe — mehr kippt die Balance gegen das Ebenen-Scaling).
   2. *Endlos-Stufen nach dem Cap* — `UPGRADE_DEFS` bekommt optionalen
      `endless`-Block `{increment-Beschreibung, base_cost, growth}`;
      `upgrade_cost()` liefert nach dem Array-Ende `base_cost *
      growth^(level - costs.size())` statt −1. Kleinere Inkremente als die
      Grundstufen, damit endlos nicht eskaliert:
      - Vitalität ∞: **+1** Start-HP (statt +2), 400 × 1,5ⁿ
      - Reflexe ∞: **−0,02s** Dash-CD (statt −0,1s), 150 × 1,5ⁿ, harter Boden
        0,25s (danach zeigt der Schrein MAX — faktisch ~12 Stufen)
      - Wucht ∞: **+1 Skill-Schaden** (nur `slam_damage`/Skill-Kanal, NICHT
        Waffenschaden), 300 × 1,6ⁿ
      - Gürtel: keine ∞-Stufe (Trank-Slots skalieren nicht sinnvoll endlos)
      Dazu: `player._apply_meta_upgrades()`-Formeln splitten (Grundstufen +
      ∞-Anteil), shrine.gd zeigt „Stufe n (∞)" statt „n/max". Save-Format
      (Level-Ints) bleibt kompatibel.
   3. *Seelen im Run ausgeben (Boon-Stationen)* — neue Station im Level
      (Prefab-Marker analog Blutschrein „B", 1×/Ebene ab Ebene 3): E-Interakt
      öffnet kleine Wahl-UI (LoadoutChoice-Muster) mit 2–3 zufälligen Boons
      NUR für diesen Run, bezahlt aus den echten Seelen (Opportunitätskosten
      Run-Power vs. Meta-Fortschritt ist der Punkt). Startpool z. B.:
      Trank auffüllen (25), +2 Max-HP diesen Run (40), −20% Skill-CD (50),
      +1 Schaden diesen Run (60, selten). Ein Kauf, dann erlischt sie. Boons
      tragen wie HP/Relikte über Treppen (carry), sterben mit dem Tod.
      Pflicht dabei: Interim-Optik (getönter Blutschrein-Prop) + Eintrag
      asset-spec §4, Interim-Sound + Eintrag audio-spec §3.

   **Für später (bewusst geparkt):** *Freischalt-Schrein* — Seelen kaufen
   Content statt Stats: neue Waffen/Skills/Relikte starten gesperrt und werden
   im Hub freigekauft, erst dann erscheinen sie im Drop-Pool. Löst „schnell
   maxed" UND „immer dieselben Funde" (Pool: 3 Waffen/4 Skills/7 Relikte)
   ohne Power-Creep — revidiert aber teilweise die obige Juli-Entscheidung
   („keine permanenten Freischaltungen") und braucht neuen Content als
   Kaufware; deshalb erst angehen, wenn Punkt 6/7 mehr Waffen/Skills/Relikte
   liefern.
2. **Pixel-Art & Atmosphäre:** düstere Tilesets, Gore-Details, Ambient-Sound
   → ✅ *weitgehend: PixelLab-Tileset + 8-Richtungs-Sprites (Spieler, Brute, Kultist, Boss, inkl. Tod/Treffer) + Props; Sound bisher synthetisierte Platzhalter (Sfx-Autoload); offen: **hübsches HUD** (komplettes UI-Kit — Rahmen, Slots, Icons, Pixel-Font — spezifiziert in asset-spec.md §4.3, braucht PixelLab-Pass + hud.gd-Milestone), Gore, echte Audio-Dateien*
3. **Ebenen-Struktur:** alle 4–5 Ebenen Boss/Elite-Raum, Biomwechsel (Krypta → Katakomben → Fleischgrube)
   → ✅ *umgesetzt: Boss alle 5 Ebenen, Elites ab Ebene 2, **5 Biome à 10 Ebenen**
   (Run-Umbau Juli 2026): Krypta 1–10 → Katakomben 11–20 → Fleischgrube 21–30 →
   Fäulnisschlund 31–40 → Herz der Seuche 41+, mit Tileset (interim Hue-Shift; die
   zwei tiefsten interim auf Fleischgrube-Atlas), Lichtstimmung, Gegner-Mix pro
   Biom und Biom-Name im HUD; offen: echte PixelLab-Biom-Tilesets (asset-spec §4.5/4.13)*
4. **Prefab-Räume** einstreuen (Schatzkammer, Schrein, Bossarena — wie Spelunky/Dead Cells)
   → ✅ *umgesetzt: ASCII-Templates werden in passende Mittelräume gestempelt
   (60%/Ebene) — Schatzkammer (2 Truhen in Nischen), Blutschrein-Raum (3 HP →
   35 Seelen, einmalig), Säulenhalle; Flood-Fill sichert Erreichbarkeit ab.
   Neue Templates = neuer Eintrag in `PREFABS` (level_generator.gd)*
5. **Risk/Reward:** verfluchte Truhen, optionale Schatzräume; Loot/Gegner nach Distanz zum Spawn skalieren
   → ✅ *umgesetzt: Truhen in Seitenräumen (verfluchte sichtbar lila → Hinterhalt),
   Schatzkammer-/Blutschrein-Prefabs, nach Boss-Sieg weiter absteigen, Gegner/Seelen
   skalieren mit Ebene*
6. **Item-System (Roguelike-Zuschnitt, bewusst schlank):** keine Diablo-Loot-Flut,
   kein Inventar, keine Affixe — stattdessen **Relikte**: seltene, run-gebundene
   Fundstücke (aus Truhen, von Elites, nach dem Boss), die den Build *dieses* Runs
   spürbar verändern (z.B. „Slam hinterlässt Feuerfläche", „Kills heilen 1 HP",
   „+1 Dash-Ladung", „Projektile prallen ab"). Aufheben = Sofort-Entscheidung,
   max. ~4 gleichzeitig als Icons im HUD, Tod = weg. Motivation kommt aus
   Run-Varianz (Hades/Dead Cells), nicht aus Stash-Verwaltung
   → 🔶 *Relikte umgesetzt: 7 Stück (Brandsiegel, Blutdurst, Schattenschritt,
   Wuchtklinge, Hetzjagd, Konzentrat, Seelengier), max. 4 als HUD-Icons, Drop aus
   Truhen (60%) und nach jedem Boss-Kill; offen: weitere Relikte, Elite-Drops.*

   **Entscheidung Juli 2026 (Erweiterung):** Waffen und Skills werden — wie
   Relikte — run-gebunden gefunden statt permanent freigeschaltet (siehe
   Punkt 1); jeder Run soll sich anders anfühlen:
   - **Waffen:** volles eigenes Moveset pro Waffe (Hitbox-Größe/-Position,
     Reichweite, Timing, Schaden, Knockback — kein reiner Stat-Modifier auf
     einen gemeinsamen Schwung), 1 ausgerüstet, Fund tauscht via Wahl-UI
   - **Skills:** aktive Fähigkeiten mit eigenem Cooldown auf dem RMB-Slot,
     1 ausgerüstet, Fund tauscht via Wahl-UI. Rundumschlag ist der Start-Skill
   - **Vereinheitlichte Wahl-UI:** ein voller Slot (Relikt/Waffe/Skill) löst bei
     neuem Fund eine Auswahl aus („behalten oder tauschen?") — ersetzt das
     frühere stillschweigende Ignorieren bei vollen Relikt-Slots
   → ✅ *umgesetzt: 3 Waffen (Kurzschwert, Spieß, Kriegshammer), 4 Skills
   (Rundumschlag, Frostnova, Blutopfer, Seelenkette), `LoadoutChoice`-Autoload
   für die Wahl-UI (pausiert währenddessen), Drop aus Truhen/Boss gleichmäßig
   über Relikt/Waffe/Skill verteilt; Wächter-Beschwörung als Skill bewusst
   zurückgestellt (Stretch-Goal, bräuchte umgedrehte enemy.gd-KI als
   Verbündeten). Offen: alle drei Waffen teilen sich noch dieselbe
   Schwung-Animation (asset-spec.md #10), Skill-/Waffen-Icons im HUD sind
   Platzhalter-Formen*
7. **Content:** 5–8 Gegnertypen, Skills, Controller-Support (Items → Punkt 6)
   → 🔶 *Ziel-Untergrenze erreicht: 5 Typen (Brute, Kultist, Exploder, Schild-Tank
   ab Katakomben, Beschwörer ab Fleischgrube — Register: docs/enemies.md) +
   Elites + Boss; offen: PixelLab-Sprites für Typ 3–5 (interim getönt),
   Skilltree, Controller*
8. **Vertrieb:** itch.io (kostenlos, unkompliziert) → später Steam; Mobile-Port optional
   → ❌ *offen: noch kein Export-Preset / Build*
9. **Sieg-Bedingung / Run-Ende** (siehe „Rahmen & Run-Ziel"): Endboss auf **Ebene 50**,
   Sieg banken (GameManager) + Win-Screen + Hub-Rücksprung, danach Endlos/NG+.
   Bedingt Biom-/Scaling-/Boss-Varianz bis Ebene 50 (Punkt 3) und eine gewählte
   Prämisse.
   → ✅ *umgesetzt (Juli 2026): `GameManager.FINAL_FLOOR = 50` + `is_final_floor()`;
   dedizierter Endboss „Die Quelle" (`quelle.tscn`, 3 Muster: AoE/Projektil-Ring/
   Brut, eigenes HP statt Stufen-Ramp); Kill → `_on_final_boss_defeated` bankt den
   Sieg und öffnet den `WinScreen`-Autoload mit Wahl **Zum Hub** oder **Endlos
   weiter** (Portal+Treppe+Loot bleiben stehen). Biome auf 5 Bänder à 10 gestreckt,
   Gegner-HP-Scaling bei +12 gedeckelt, Boss-Ramp bei +60. Interim: getönter
   Quelle-Sprite + 2 tiefe Biome auf Fleischgrube-Tileset (asset-spec §4.12/13).
   Offen: dedizierte Quelle-/Biom-Assets, NG+-Loop, Balance-Feintuning im Spieltest*