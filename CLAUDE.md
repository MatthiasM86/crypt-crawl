# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Godot 4.x top-down action-roguelike PoC ("Diablo-style", desktop only). The design
plan is `docs/plan.md` (German); its single question is *"does the core combat loop
feel fun?"* — this is a feel-first prototype, not a full game. Placeholder graphics
(colored rectangles) are deliberate; pixel art, sound, meta-progression, bosses,
items, and balancing are explicitly post-PoC.

Implemented (all of Phase 4 + extras): Diablo-style click-to-move / attack-move,
melee combat with hit feedback (shader hit-flash, knockback, trauma-based
screenshake), enemy AI (Idle → Chase → Attack state machine with LOS detection
and windup telegraphing), a ranged enemy with projectiles, player HP (10) with
i-frames, dash on Space/Shift (i-frames, passes through enemies, cancels
windups), AoE slam on right-click (2 dmg + amplified knockback in 90px, 3s CD),
heal potion on hotkey 1/Q (heals 5, belt of 3; ~22% drop chance from slain
enemies as glowing pickups), torchlight fog-of-war (CanvasModulate darkness +
shadowed PointLight2D + LightOccluder2D on every wall), tile-based rendering
(TileMapLayer, placeholder atlas — see docs/asset-spec.md for the swap-in art
pipeline), stairs → next generated floor (HP + potion belt carry over;
GameManager tracks `floor_num`), death → full run reset, and a minimal HUD
(HP squares, potion belt, dash/skill cooldowns, floor number — custom `_draw()`
on a Control with `mouse_filter = IGNORE`).
Beyond the PoC, already built: floor-based difficulty scaling (enemy HP/speed/
count via @export dials at spawn), meta-progression (soul wisps from kills,
persistent save at user://save.cfg, hub scene with four upgrade shrines and a
run portal; death returns to the hub; shrine curves continue past their costs
array as "endless" mini-tiers with weaker increments — see UPGRADE_DEFS —
and from floor 3 a soul shrine per floor sells run-bound boons for souls), a
boss ("Kryptwächter", boss.gd extends
enemy.gd) every 5th floor in a generated arena with two telegraphed patterns —
victory is banked on the kill and spawns BOTH a hub portal and stairs deeper —
real audio (Sfx autoload synthesizes all SFX + ambient drone in memory at
startup, then swaps in any `assets/sfx/<name>.mp3` — every register sound is
an ElevenLabs-generated file now except `boon` and the quiet `music` loop
(both synth-only; the Music API needs a paid plan), incl. per-enemy-type
death sounds via the `death_sound` @export dial on enemy.gd and per-key mix
trims in `Sfx.KEY_OFFSET_DB`; see docs/audio-spec.md), and an ESC pause
menu (PauseMenu
autoload, code-built UI, pauses the tree; "Aufgeben" only in runs).
Not yet: character sprites (waiting on assets per docs/asset-spec.md), more
enemy types, item system, biomes/prefab rooms.

## Running things

Godot 4.7-stable is installed at `/Applications/Godot.app/Contents/MacOS/Godot`
(not on PATH). From the repo root:

```
/Applications/Godot.app/Contents/MacOS/Godot --path .            # play (procedural level)
/Applications/Godot.app/Contents/MacOS/Godot -e --path .         # open editor
/Applications/Godot.app/Contents/MacOS/Godot --path . --scene res://scenes/levels/test_room.tscn   # hand-built feel-test arena
```

Headless verification (no test framework exists; this is the verification story):

```
# parse-check a script
Godot --headless --path . --check-only -s res://scenes/player/player.gd
# instance a scene for N frames (catches .tscn + runtime errors)
Godot --headless --path . --scene res://scenes/enemies/enemy.tscn --quit-after 10
# run the main scene headless (exercises generation, bake, AI; errors hit stderr)
Godot --headless --path . --quit-after 300
# editor import pass (regenerates .godot/ cache and *.uid sidecars)
Godot --headless --path . --import
```

Caveats learned the hard way:
- `--check-only -s` fails with "Identifier not found: GameManager" on any script
  whose preload chain reaches a script referencing an autoload — autoload globals
  aren't registered in standalone-script mode. Not a real error; the headless
  *game run* is the authoritative check.
- Headless silence is not success: a broken navmesh or never-aggroing AI exits 0
  silently. For behavioral verification, add a temporary `print()` probe (e.g. in
  `GameManager.player_died()` or the generator), observe the loop, then remove it.
- Headless runs process frames faster than 60/s (no vsync), so `--quit-after N`
  covers less wall/sim time than N/60 seconds suggests.
- Commit `*.uid` sidecar files; never commit `.godot/`.

## Asset workflow (PixelLab + ElevenLabs pipelines)

All real art comes from the PixelLab MCP pipeline in batched generation
passes. **Rule: any feature that introduces or changes a visual** (new enemy
type, prop, pickup, effect, UI element) **ships with an interim look**
(tinted existing sprite, Polygon2D, or code-drawn) **and MUST add an entry to
`docs/asset-spec.md` §4 "Offene PixelLab-Aufgaben"** — with pixel size, style
notes, and which scene/file the finished asset swaps into. That list is the
single backlog the art passes work off; a visual that isn't on it will keep
its placeholder forever. (Example: the exploder enemy launched as an
orange-tinted brute + spec entry.)

All real audio comes from the ElevenLabs MCP pipeline
(`text_to_sound_effects`), same batched-passes shape. **Rule: any feature
that introduces or changes a sound** (new enemy attack, pickup, skill, UI
feedback) **ships with an interim sound** (synthesized in `autoloads/sfx.gd`)
**and MUST add/update an entry in `docs/audio-spec.md` §3 "Offene
ElevenLabs-Aufgaben"** — with the desired sound description and which
`Sfx.play()` key it swaps into. That list is the single backlog the audio
passes work off; a sound that isn't on it will keep its placeholder forever.

## Architecture

- **Scene scripts live next to their `.tscn`** in `scenes/<category>/` (player,
  enemies, projectiles, levels). No top-level `scripts/` tree.
- **Autoloads** in `autoloads/`, registered as `Name="*res://autoloads/name.gd"` in
  `project.godot`. `GameManager` owns death → restart
  (`get_tree().reload_current_scene()` — which regenerates the level, i.e. the
  roguelike loop is literally a scene reload).
- **Damage contract is duck-typed** (no `class_name` anywhere): anything hittable
  implements `take_damage(amount: int, source_position: Vector2)` and exposes a
  `dead` bool; callers check `has_method("take_damage")` / `get("dead")`. Player and
  enemies both implement it; projectiles and hitboxes only speak this contract.
- **Enemy roster & recipe:** `docs/enemies.md` lists every enemy type with
  stats/counterplay/spawn rules and the step-by-step recipe for adding a new
  type — keep it updated when touching enemies.
- **Enemy inheritance:** `scenes/enemies/enemy.gd`/`enemy.tscn` is the base AND the
  melee archetype (state machine, telegraph, strike). `melee_enemy.tscn` is a pure
  inherited pass-through; `ranged_enemy.gd extends "res://.../enemy.gd"` and
  overrides `_in_attack_position`/`_chase_velocity`/`_show_attack_tell`/
  `_perform_attack`; `ranged_enemy.tscn` overrides @exports. Archetype dials are
  `@export var` (child scripts can't override consts the parent reads); shared feel
  constants stay consts at the top of each script — that's where all game-feel
  tuning happens.
- **Navigation flow** (same for hand-built and generated levels): NavigationRegion2D
  with an outline-only NavigationPolygon (`parsed_geometry_type = 1` = static
  colliders, `parsed_collision_mask = 1`, `agent_radius = 24` — paths guarantee
  ~20 px effective wall clearance (24 minus the 4 px `path_desired_distance`
  waypoint cut), so every body that path-follows must keep its worst-case
  collision extent below that: player is r14 at (0,-3) → 17 px. Don't grow
  body shapes or shrink the inset without redoing this math, or corners wedge;
  don't raise the inset past 24 or 2-cell corridors seal. Corollary: any
  walkable opening must be ≥ 2 cells wide — the generator's `_widen_pinches()`
  grid pass enforces this plus no diagonal-only contacts (1-wide gaps LOOK
  walkable but the inset seals them: walking refuses, dash slips through);
  keep that invariant for hand-built rooms and prefabs whose gaps are meant
  to be passable. Grid math still can't fully predict the bake (mitered
  corner offsets seal ~45 px diagonal squeezes between wall corners), so the
  FINAL authority is `_seal_nav_pockets()`: after baking, every floor cell is
  path-checked on the real nav map; sealed pockets are walled up, layouts
  with a sealed room center rerolled. Nav queries need ~10 physics frames
  after a bake before they answer for the CURRENT mesh — earlier queries
  silently answer against the previous/empty mesh (`_await_nav_sync()`);
  and when rebuilding walls in-frame, `free()` the old Walls node
  immediately — a queue_freed node still gets parsed by the bake. Anything
  that spawns bodies or leaves pickups at a runtime-computed position
  (summons, chest ambushes, death drops) must clamp it through
  `GameManager.snap_to_walkable()` or it can land inside wall geometry);
  wall StaticBody2Ds
  are children of the region; the level's `_ready()` calls
  `bake_navigation_polygon(false)` (synchronous). The generator fills every
  non-floor grid cell with row-merged wall rects inflated by `WALL_EPS = 0.1` px —
  exactly-coincident rect edges make the bake's convex partition fail; overlaps
  are fine. The nav map syncs ~1 physics frame after bake; NavigationAgent2D users
  self-heal, but direct `NavigationServer2D` queries right after `_ready()` return
  empty paths.
- **Enemies find the player** via `get_tree().get_first_node_in_group("player")`
  in `_ready()` — spawn order matters: the generator adds the player before enemies.
- **Telegraph rule** (docs/plan.md calls this the core of the feel): every enemy
  attack has a windup — body ramps to warning yellow + 1.15× scale, then hard-snaps
  back at the strike frame; facing locks at windup start so sidestepping dodges.
  Keep this pattern for any new enemy type.

### Collision layers (`[layer_names]` in project.godot)

| # | bit | name | used by | mask |
|---|-----|------|---------|------|
| 1 | 1 | world | wall StaticBody2Ds | 0 |
| 2 | 2 | player | Player body | 5 |
| 3 | 4 | enemy | Enemy bodies | 7 (world+player+enemy — enemies ring, don't stack) |
| 4 | 8 | enemy_hitbox | enemy melee Hitbox (mask 2), projectiles (mask 3) | — |
| 6 | 32 | clickable | enemy ClickArea (generous click targets) | 0 |

Player attack Hitbox: layer 0, mask 4. Gotcha: "layer 3" (enemy) is bit **4**;
"layer 4" (enemy_hitbox) is bit **8** — easy to conflate.

### Hand-authoring .tscn files (all scenes here are hand-written, verified on 4.7)

`[gd_scene format=3]` with NO uid/load_steps — never invent `uid://` strings; the
editor assigns real ones on save. `RectangleShape2D.size` (not 3.x `extents`).
Instanced nodes: `[node name="X" parent="." instance=ExtResource("id")]`, no `type`.
Inherited scenes: root is `[node name="X" instance=ExtResource("id")]`; overridden
children addressed by name+parent only. `motion_mode = 1` on all top-down
CharacterBody2Ds. `resource_local_to_scene = true` on per-instance ShaderMaterials
(else all instances flash together). Never use ColorRect for gameplay visuals
(Controls eat mouse clicks) — use Polygon2D. Space queries only in
`_physics_process`; `set_deferred("disabled", true)` for shapes during physics
callbacks; never set nav targets in `_ready()`.
