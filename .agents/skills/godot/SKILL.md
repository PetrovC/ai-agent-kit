---
name: godot
description: >
  Use when working in a Godot 4.x project: GDScript scripts, scenes and the
  scene tree, nodes, signals, resources, autoloads, physics callbacks, input
  handling, or Rust GDExtension (gdext) gameplay modules.
paths:
  - "**/*.gd"
  - "**/*.tscn"
  - "**/*.tres"
  - "**/project.godot"
  - "**/*.gdextension"
allowed-tools:
  - "Bash(godot:*)"
version: "1.0.0"
keywords:
  - godot
  - gdscript
  - gdextension
  - gdext
  - scene tree
  - autoload
  - tilemap
task_intents:
  - implement
  - fix
  - refactor
  - review
delegation_hints:
  can_delegate: true
  when: >
    When the task also involves a separate backend service or a web frontend —
    delegate the engine work to a focused subagent.
---

# Godot Skill

## Goal

Typed GDScript, small composable scenes, and a deliberate GDScript ↔ Rust
boundary. Engine code follows engine idioms — "call down, signal up" — not
backend layering. A designer should be able to tweak behavior from the
Inspector without reading code.

---

## Project structure

```
project.godot
scenes/            # one folder per feature: player/, enemies/, ui/, levels/
  player/
    player.tscn
    player.gd      # co-located with its scene
autoload/          # singletons registered in Project Settings → Autoload
resources/         # .tres data files + the Resource scripts that define them
addons/            # editor plugins (GUT or gdUnit4, etc.)
rust/              # optional gdext crate — see references/rust-gdextension.md
tests/             # GUT / gdUnit4 test scripts
```

- Co-locate each scene with its script; share code via `class_name`, not paths.
- Scene filenames snake_case; `class_name` types PascalCase.

---

## GDScript 4.x rules

- Static typing everywhere: `var speed: float = 300.0`,
  `func take_damage(amount: int) -> void:`. Use `:=` only when the type is
  obvious from the right-hand side.
- `class_name` for every reusable type; prefer it over `load()` of script paths.
- `@export` for designer-tunable values (`@export var jump_force: float = 420.0`);
  `@export` a `Resource` for data blocks shared between scenes.
- `@onready var sprite: Sprite2D = $Sprite2D` — or `%UniqueName` for nodes that
  may move in the tree.
- Signals: declare typed — `signal died(cause: StringName)` — and connect in
  `_ready()`: `enemy.died.connect(_on_enemy_died)`.
- Lifecycle: `_ready()` for setup, `_process(delta)` for visuals,
  `_physics_process(delta)` for movement and anything touching physics.
- `await` for async flow: `await get_tree().create_timer(0.5).timeout`,
  `await some_node.some_signal`. No busy-wait loops.
- `preload()` for paths known at parse time; never `load()` or `instantiate()`
  inside a per-frame loop.

---

## Scenes, nodes, composition

- Composition over inheritance: build features as small scenes and instance
  them; reserve script inheritance for true is-a relationships.
- **Call down, signal up.** A parent may call methods on its children; a child
  communicates upward only by emitting signals. Never `get_parent()` or
  `get_node("../..")` to reach logic.
- Reference nodes via `%UniqueName` or exported `NodePath`/`Node` properties —
  not long absolute paths that break on re-parenting.
- Autoloads are for genuinely global concerns only (event bus, save system,
  audio manager). Gameplay state lives in scenes.

---

## Physics and movement

- `CharacterBody2D`/`CharacterBody3D`: set `velocity`, then `move_and_slide()`
  — inside `_physics_process` only.
- Apply gravity from project settings, not magic numbers:
  `ProjectSettings.get_setting("physics/2d/default_gravity")`.
- Never mutate physics state (position of bodies, collision shapes) from
  `_process` or from signal handlers running mid-physics — defer with
  `call_deferred()`.
- Remove nodes with `queue_free()`, never `free()`, while the tree is active.

---

## GDScript vs Rust (gdext)

| Put it in GDScript | Put it in Rust (GDExtension) |
|---|---|
| Gameplay scripting, UI, scene glue | Pathfinding, procedural generation |
| Prototyping and designer iteration | Simulation ticks over large collections |
| Input handling, animation triggers | Heavy math, image/mesh processing |
| Anything tweaked per-scene in the Inspector | Code that profiles as a hot spot |

Keep the boundary coarse: one Rust call that processes a batch (pass
`PackedFloat32Array` / `PackedVector2Array`), not one call per entity per frame
— each crossing pays marshalling cost. Start in GDScript; move a system to Rust
only when profiling says so.

---

## References

Load these only when signals justify it:

| Reference | Load when |
|---|---|
| [`references/rust-gdextension.md`](references/rust-gdextension.md) | Task mentions GDExtension, gdext, the `godot` Rust crate, exposing Rust to GDScript, or `.gdextension` files. Files match `**/*.gdextension`, or `rust/**/*.rs` alongside a `project.godot`. |

---

## Testing

- Use **GUT** or **gdUnit4** (both MIT) under `addons/`; tests live in `tests/`.
- Keep rules and calculations in plain `RefCounted` classes or static funcs so
  they are testable without instancing scenes.
- Headless run (GUT):
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- Rust side: pure logic gets ordinary `cargo test` in the gdext crate.

---

## What NOT to do

- No untyped GDScript in new code (no bare `var x = ...` for non-obvious types).
- No `get_parent()` coupling or `../..` node paths.
- No `load()` / `instantiate()` / `find_child()` in per-frame code.
- No physics mutation outside `_physics_process` (use `call_deferred`).
- No `free()` on nodes in the active tree — `queue_free()`.
- No gameplay logic in autoloads that belongs to a scene.
- No Godot API calls from background threads without `call_deferred` /
  `call_thread_safe` — most of the scene tree is main-thread only.

---

## Verification commands

```bash
gdformat scripts/ scenes/          # gdtoolkit (MIT) formatter
gdlint scripts/ scenes/            # gdtoolkit linter
godot --headless --import          # re-import assets; catches broken references
godot --headless --quit            # project loads without script errors
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit   # GUT
cargo test                         # gdext crate pure-logic tests (if rust/)
```

---

## Final response requirements

Always report:
- Scenes and scripts changed, and which scene owns each script.
- New signals / `@export`s and who connects or consumes them.
- Any GDScript ↔ Rust boundary decision (what moved to gdext and why).
- Lint / headless-load / test results.
- Risks or assumptions (engine version, plugin dependencies).
