# Rust GDExtension (gdext)

## Load when

Task mentions GDExtension, gdext, the `godot` Rust crate, exposing Rust to
GDScript, or `.gdextension` files — or files match `rust/**/*.rs` /
`**/*.gdextension` inside a Godot project.

---

## Setup

The crate is `godot` (the gdext project — godot-rust). Built as a dynamic
library that the engine loads through a `.gdextension` descriptor.

```toml
# rust/Cargo.toml
[lib]
crate-type = ["cdylib"]

[dependencies]
godot = "0.5"
```

Entry point — one per library:

```rust
use godot::prelude::*;

struct MyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}
```

Descriptor the editor reads (paths per platform/profile):

```ini
; godot/native.gdextension
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = 4.1
reloadable = true

[libraries]
linux.debug.x86_64   = "res://../rust/target/debug/lib{crate}.so"
linux.release.x86_64 = "res://../rust/target/release/lib{crate}.so"
windows.debug.x86_64 = "res://../rust/target/debug/{crate}.dll"
macos.debug          = "res://../rust/target/debug/lib{crate}.dylib"
```

Adjust paths to where the crate lives relative to `project.godot`.

---

## Registering classes

```rust
use godot::classes::{CharacterBody2D, ICharacterBody2D};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(init, base=CharacterBody2D)]
pub struct Player {
    base: Base<CharacterBody2D>,
    #[init(val = 100)]
    hitpoints: i32,
}

#[godot_api]
impl Player {
    #[func]
    fn take_damage(&mut self, amount: i32) {
        self.hitpoints -= amount;
        if self.hitpoints <= 0 {
            self.signals().died().emit();
        }
    }

    #[signal]
    fn died();
}

#[godot_api]
impl ICharacterBody2D for Player {
    fn physics_process(&mut self, delta: f64) {
        // velocity / move_and_slide() via self.base_mut()
        let _ = delta;
    }
}
```

- `#[derive(GodotClass)]` + `#[class(init, base=...)]` registers the type; the
  `Base<T>` field gives access to the engine base object (`self.base_mut()`).
- `#[func]` exposes a method to GDScript; `#[signal]` declares a signal.
- Lifecycle hooks come from the `I<BaseClass>` interface trait
  (`ICharacterBody2D::physics_process`, `ISprite2D::ready`, ...).
- After `cargo build`, the editor picks the library up via the `.gdextension`
  file; hot-reload is supported (`reloadable = true`), but restart the editor
  after changing class signatures or the entry symbol.

---

## Boundary design

- Crossing GDScript ↔ Rust marshals every argument. Batch work: pass
  `PackedFloat32Array` / `PackedVector2Array` / `PackedByteArray`, return the
  same — not one call per entity per frame.
- Keep Rust types engine-free where possible: a pure `sim` module with plain
  structs + a thin `#[godot_api]` adapter layer. The `rust` skill's
  domain/adapter rules apply to the crate's internals.
- Most scene-tree APIs are main-thread only. Do not touch `Gd<Node>` from
  spawned threads; hand results back and apply them on the main thread.
- Do not hold `Gd<T>` references to nodes that GDScript may free; re-fetch or
  validate with `is_instance_valid`.

---

## Errors and panics

- A Rust panic across the FFI boundary aborts or corrupts the session — never
  let one escape a `#[func]`. Validate inputs, return early, and report with
  `godot_error!` / `godot_warn!` instead of `panic!` / `unwrap()`.
- Follow the `rust` skill's error rules inside the crate (`thiserror` for the
  pure core); convert to logs + safe defaults at the `#[func]` adapter layer.

---

## Testing

- Pure logic: ordinary `cargo test` on the engine-free core — fast, no editor.
- Integration: a minimal headless scene that exercises the registered classes
  (`godot --headless` + GUT/gdUnit4 from the main project).
- CI: build the crate for every shipped platform; a `.gdextension` pointing at
  a missing library fails only at load time, so make the build matrix explicit.

---

## Pitfalls

- Editor opened before the first `cargo build` → "can't open dynamic library":
  build first, then open the project.
- `compatibility_minimum` higher than the installed engine silently hides
  classes.
- Renaming a `#[derive(GodotClass)]` type breaks scenes referencing the old
  name — fix the `.tscn` or re-attach.
- Debug vs release library paths in `.gdextension` must both exist before
  export; export templates use the `release` entries.
