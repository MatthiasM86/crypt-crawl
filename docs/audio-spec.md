# Audio-Spezifikation für SFX (ElevenLabs oder manuell)

Ziel: die synthetisierten Platzhalter-Sounds aus `autoloads/sfx.gd`
(`_build_streams()`) schrittweise durch echte, per ElevenLabs generierte
Audio-Dateien ersetzen — analog zur Pixel-Art-Pipeline in `asset-spec.md`.
Aktuell kommt **kein** Ton aus einer Datei; alles wird beim Spielstart im
Code synthetisiert (siehe CLAUDE.md).

Allgemeine Anforderungen an jede Datei:
- Format: MP3, 44.1kHz/128kbps (`mp3_44100_128`, der Free-Tier-Standard von
  ElevenLabs). PCM/WAV-Formate verlangen Pro-Tier und liefern auf Free
  stattdessen stillschweigend kaputte Rohdaten ohne Fehlermeldung — nach
  jeder Generierung mit `file <pfad>` gegenprüfen.
- Dauer: `text_to_sound_effects` erlaubt nur **0.5–5 Sekunden**; für kurze,
  knackige SFX (die synthetisierten Referenzen sind teils <0.2s) auf 0.5s
  anfragen.
- Trocken: kein Reverb, keine Musik im generierten Sample — beides stapelt
  sich schlecht, wenn mehrere Treffer gleichzeitig abgespielt werden
  (Godot mischt über den Player-Pool in `sfx.gd`).
- Dateiname = exakt der `Sfx.play("<name>")`-Key, abgelegt unter
  `assets/sfx/<name>.mp3` (Konvention aus dem Kommentar in `sfx.gd`, Zeile 6).

## 1. Sound-Register (aktueller Bestand)

| Key | Verwendet in | Synth-Charakter (Platzhalter) | Gewünschter Klang | Status |
|---|---|---|---|---|
| `hit` | `player.gd` (Nahkampftreffer landet) | kurzer heller Noise-Burst | Schwert-Treffer auf Gegner, scharf, **kein** Metall-Klang | ✅ erledigt (`assets/sfx/hit.mp3`) |
| `hurt` | `player.gd` (Spieler nimmt Schaden, 2×) | härter, tiefer, länger | Schmerzhafter Treffer-Wumms auf den Spieler, kurz, kein Sprachsample/Schrei | ✅ erledigt |
| `dash` | `player.gd` (Ausweichrolle, 2×) | luftiges Whoosh | Schnelles Luft-Whoosh, kurz und leicht | ✅ erledigt |
| `slam` | `player.gd` (AoE-Skill), `boss.gd` (Nah-Attacke), `exploder.gd` (Tod/Explosion) | tiefer Wummser mit fallender Tonhöhe | Wuchtiger Boden-/Explosions-Einschlag, tiefes Rumpeln | ✅ erledigt — **wird von 3 unterschiedlichen Quellen geteilt**, ggf. später in eigene Sounds auftrennen |
| `shoot` | `ranged_enemy.gd`, `boss.gd` (Fernkampf) | kurzer mittlerer Chirp abwärts | Kurzer Energie-/Armbrust-Schuss | ✅ erledigt |
| `potion` | `player.gd` (Trank trinken) | zwei aufsteigende Töne | Angenehmes Heil-Glucksen + leichtes magisches Glitzern | ✅ erledigt |
| `soul` | `soul_wisp.gd` (Seelen einsammeln) | winziger heller Sparkle-Chirp aufwärts | Kleiner magischer Sammel-Ping, hoch, sehr kurz | ✅ erledigt |
| `pickup` | `potion_pickup.gd` (Trank vom Boden aufheben) | weiches Pop + Ton | Neutrales, sanftes Aufheben-Pop | ✅ erledigt |
| `death_enemy` | `enemy.gd` `_die()` über das `death_sound`-@export-Dial (Standard — Brute + Beschwörer-Diener) | fallendes quadratisches Growl | Bestialischer Grunzer + Körper-Aufprall auf Stein, physisch statt stimmhaft | ✅ erledigt (Re-Roll Juli 2026; v1 klang seltsam) |
| `death_cultist` | `ranged_enemy.tscn` (`death_sound`-Override) | raueres, höheres fallendes Growl | Raues letztes Röcheln/Keuchen, leise, kein Schrei | ✅ erledigt |
| `death_tank` | `shield_tank.tscn` (`death_sound`-Override) | Clank-Teiltöne über tiefem Wumms | Rüstung kollabiert scheppernd auf Steinboden | ✅ erledigt |
| `death_summoner` | `summoner.tscn` (`death_sound`-Override) | Tremolo-Schimmer abwärts | Arkanes Auflösen/Verpuffen, abfallend, leichtes Glitzern | ✅ erledigt |
| `death_exploder` | `exploder.tscn` (`death_sound`-Override; **layert unter `slam`** bei der Detonation) | nasser Noise-Burst | Nasses Platzen/Splatter, sehr kurz | ✅ erledigt |
| `death_boss` | `boss.tscn` (`death_sound`-Override) | langer, tieferer Abstieg als `death_player` | Dramatisches Boss-Sterben: tiefes Brüllen, das in massiven Einsturz übergeht (~2,5s) | ✅ erledigt |
| `death_player` | `player.gd` (Spieler stirbt) | langer dunkler Tonabstieg | Dunkler, dramatischer Todes-Fall-Ton, länger (~0.7s) | ✅ erledigt |
| `stairs` | `stairs.gd`, `victory_portal.gd`, `run_portal.gd` (Treppe/Portal) | aufsteigendes Schimmern | Magisches Portal-/Treppen-Aktivieren, aufsteigend, leicht arkan | ✅ erledigt |
| `relic` | `player.gd` (Relikt aufsammeln, 4×), `blood_shrine.gd` (Schrein-Aktivierung), `summoner.gd` (Beschwörungs-Ritual) | drei-Noten-Arpeggio aufwärts | Wichtiger-Fund-Sting, arkan, kurz | ✅ erledigt — **wird auch vom Beschwörer als Cast-Sound wiederverwendet**, ggf. später eigener `summon`-Sound |
| `clank` | `shield_tank.gd` (Schild blockt) | metallischer Schild-Block | Helles, kurzes Schild-/Metall-Block-Klirren | ✅ erledigt |
| `chest` | `chest.gd` (Truhe öffnen) | tiefes Holz-Knarren + Wumms | Hölzernes Truhen-Öffnen-Knarren mit Metall-Beschlag | ✅ erledigt |
| `ambient` | `Sfx._ready()` (Dauerschleife im Hintergrund) | tiefer Krypta-Drone, 6s nahtlos loopend | Dunkler, loopfähiger Krypta-Ambient-Drone ohne Melodie | ✅ erledigt — mit `loop=true` generiert (5s, Tool-Maximum), `AudioStreamMP3.loop` in `sfx.gd`; **Loop-Naht im Spiel gegenhören** |
| `boon` | `player.add_boon()` (Seelenschrein-Kauf) | zwei sanft fallende Töne (Umkehrung des `relic`-Arpeggios) | „Ausgeben statt finden": arkaner Bezahl-Sting, absteigend, kurz | 🔶 offen (Synth-Platzhalter) |
| `music` | `Sfx._ready()` (eigener Player, Dauerschleife bei −18 dB über dem Ambient) | sparsames Moll-Arpeggio (A2/C3/E3…, 12,8s-Loop) | Dunkle, ruhige Dungeon-Exploration-Musik, loopbar, ohne Melodie-Hook, lässt SFX Raum | 🔶 offen (Synth-Platzhalter — **Music-API braucht Paid-Plan**, siehe §3) |

## 2. Prompt-Bausteine für ElevenLabs (`text_to_sound_effects`)

Erfahrungswerte aus der ersten Generierung (siehe auch Memory
`audio-sfx-pipeline`):

- Explizite **Negativ-Constraints** ergänzen, wenn ein erster Versuch nach
  dem falschen Material/Objekt klingt — z. B. hat "no metallic clang, no
  bell tone" einen nach Hammer-auf-Amboss klingenden Schwert-Treffer
  korrigiert.
- `output_format` **nicht** auf PCM setzen (`pcm_44100` etc.) — Free-Tier
  liefert dafür kaputte Rohdaten ohne Fehlermeldung. Default
  `mp3_44100_128` verwenden.
- Jedem Prompt "no reverb, no music" anhängen, damit die Sounds trocken
  bleiben und sich beim Überlappen im Spiel nicht matschig stapeln.
- Quelle/Objekt explizit benennen statt nur die gewünschte Textur zu
  beschreiben (z. B. "sword slash hit landing on an enemy" statt nur
  "sharp metallic impact").

Beispiel (bereits verwendet, `hit`):
> "Video game sword slash hit landing on an enemy, sharp fast blade impact
> thwack, punchy short transient, no metallic clang, no bell tone, no
> reverb, no music"

## 3. Offene ElevenLabs-Aufgaben (Stand Juli 2026)

**Alle 15 Register-Sounds sind generiert und eingebaut** (Erstgenerierung
Juli 2026, ~1 % des Free-Tier-Monatsbudgets). Offen bleiben nur
Qualitäts-/Aufteilungs-Aufgaben:

- **Re-Rolls nach Klangcheck** — jeder Sound, der sich im Spiel falsch
  anfühlt, wird einzeln neu generiert (Prompt-Regeln aus §2, insbesondere
  Negativ-Constraints) und ersetzt einfach die Datei; kein Code-Wiring nötig.
- **`slam` auftrennen** — aktuell teilen sich Spieler-AoE, Boss-Nahangriff
  und Exploder-Explosion einen Sound; bei Bedarf eigene `slam_boss`/`explode`
  generieren und die `Sfx.play()`-Aufrufe umbenennen.
- **`summon` für den Beschwörer** — nutzt aktuell `relic` als Cast-Sound;
  eigener Ritual-Sound wäre klarer lesbar.
- **`ambient`-Loop-Naht** — mit `loop=true` generiert; falls die Naht im
  Spiel hörbar knackt, neu generieren oder auf den Synth-Drone zurückfallen
  (Datei löschen genügt, Synthese ist der Fallback).
- **`boon` generieren** (Seelenschrein-Kauf, Juli 2026 mit der
  Seelen-Ökonomie dazugekommen): kurzer
  arkaner „Bezahl"-Sting, absteigend statt aufsteigend (bewusst die
  Umkehrung des `relic`-Fund-Stings), trocken, ≤0.5s. Datei nach
  `assets/sfx/boon.mp3`, greift automatisch.
- **Endboss „Die Quelle" (Ebene 50) — nutzt nur Bestands-Keys** (kein neuer
  Sound gebaut): AoE = `slam`, Projektil-Ring = `shoot`, Brut-Beschwörung =
  `relic`, Tod = `death_boss`. Optional später für mehr Finale-Gewicht: eigener
  `death_quelle` (noch dramatischerer Einsturz/Kreischen als `death_boss`) und
  ein `brood`/`birth`-Sound (nasses Fleisch-Gebären statt `relic`) — jeweils
  `assets/sfx/<key>.mp3` + `death_sound`/`Sfx.play()`-Key umbiegen. Der WinScreen
  selbst spielt bewusst keinen Sound (Boss-Death-Sound trägt den Moment).
- **`music` generieren — blockiert durch Free-Tier** (`compose_music`
  liefert 402 `paid_plan_required`; SFX gehen frei, Musik nicht). Sobald ein
  Paid-Plan (Starter reicht) da ist: ~60–90s dunkle, sparsame
  Dungeon-Exploration-Musik ("dark ambient dungeon music, low strings,
  distant drums, ghostly pads, no melody hook, instrumental, seamless
  loop"), Datei nach `assets/sfx/music.mp3` — die Swap-Logik setzt für
  `music` (wie `ambient`) `loop = true`. Interim läuft ein synthetisiertes
  Moll-Arpeggio bei −18 dB. Später optional: eigener Boss-/Hub-Track.

## Einbau (implementiert)

1. Pro Sound: generieren → mit `file` (Format) und `afplay` (Klang)
   gegenprüfen → unter `assets/sfx/<name>.mp3` ablegen →
   `--headless --import` laufen lassen (`.import`-Sidecars committen).
2. **Swap-Logik in `sfx.gd`** (Ende von `_build_streams()`): für jeden
   Stream-Key wird `res://assets/sfx/<key>.mp3` bevorzugt geladen, die
   Synthese bleibt Fallback. Jede neue/ersetzte Datei greift damit
   automatisch, kein Wiring pro Sound. `ambient` bekommt
   `AudioStreamMP3.loop = true` (loopt die ganze Datei).
   **Mixing:** `KEY_OFFSET_DB` in `sfx.gd` trimmt einzelne Keys relativ zu
   `SFX_DB` (aktuell: alle `death_*` −5 dB, `death_boss` −3 dB — Todes-Sounds
   liegen unter dem Kampf-Feedback). Zu laute/leise Generate dort nachziehen
   statt an den `Sfx.play()`-Aufrufstellen.
3. Bekannter Schönheitsfehler: beim Beenden meldet Godot
   "1 resources still in use at exit: res://assets/sfx/ambient.mp3" — der
   Ambient-Player hält den Stream beim Teardown; harmlos, kein Leak im Spiel.
