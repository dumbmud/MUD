```
You are writing code for Godot 4.5.1 only. Use GDScript 2.0 syntax. Before output, scan and replace any 3.x patterns. Follow these guardrails:

Target + syntax
- Use annotations: `@export`, `@onready`, `@tool` when needed.
- Use properties, not `setget`:
```

var hp: int = 100:
set(value): hp = max(value, 0)
get: return hp

```
- Signals are first-class. Declare and connect without strings:
```

signal hit(amount: int)
hit.connect(_on_hit)
func _on_hit(amount: int) -> void: pass

# or: timer.timeout.connect(_on_timer_timeout)

```
- Instantiate scenes with `PackedScene.instantiate()`; never `instance()`.
- Use `await` instead of `yield`:
```

await get_tree().create_timer(1.0).timeout

```
- Use typed containers:
```

var enemies: Array[Node] = []
var loot: Dictionary[String, int] = {}

```
- Use `@export` with types:
```

@export var speed: float = 200.0
@export var enemy_scene: PackedScene

```
- Tween API: create tweens in code:
```

var t = create_tween()
t.tween_property(self, "position", Vector2(600, 0), 0.3)

```
- Character controllers: use `CharacterBody2D/3D` with built-in `velocity` and call `move_and_slide()` with no arguments.

Renames to enforce
- `KinematicBody2D/3D` → `CharacterBody2D/3D`
- `Spatial` → `Node3D`
- Add `2D/3D` suffixes consistently to nodes.
- `PackedScene.instance()` → `instantiate()`

Banned 3.x constructs (auto-fail the draft if present)
- `setget`, `yield`, `instance()`, string-based `connect("signal", self, "method")`, untyped export `export(...)` keyword, `Tween` as a scene node.

Output rules
- Start with a minimal, runnable script for the stated node type (`extends Node`, `extends CharacterBody2D`, etc.).
- Include required Input actions and node paths at the top as `const` placeholders with TODO comments.
- Add types and return types on all functions.
- If adapting 3.x code, show a short diff block listing each fix (connect, instantiate, await, property syntax, node renames).
- No pseudocode. No deprecated APIs. All code must parse in Godot 4.5.1.
```

Sources for these guardrails: signal connect syntax using Callables and property examples, instantiate rename, CharacterBody and `move_and_slide()` behavior, `@export` and annotations, `await` replacing `yield`, typed arrays/dicts, and tweens via `create_tween()`. ([GitHub][1])

[1]: https://github.com/godotengine/godot-docs/issues/5577 "[Godot 4] Step by step tutorial deprecated syntax for signal connecting · Issue #5577 · godotengine/godot-docs · GitHub"










-----------

# Updated spec: glyph-based roguelike (RT/TB parity)

## Time model

* **Tick:** fixed 100 ms. Accumulator in `_process(dt)`. Catch-up runs `while acc ≥ 0.1: tick(); acc -= 0.1`. Cap max catch-up ticks/frame to avoid spiral.
* **Game time:** tick count only. Never read wall-clock for logic.
* **Modes:**

  * **Real-time:** accumulator drives ticks at ~10 Hz.
  * **Turn-based:** one commit = one tick.
  * **Auto-toggle:** enter TB on interrupts; return to RT after N threat-free seconds or manual toggle.

## Scheduler (centralized)

* **Credits:** fixed-point. `STEP_CARD=100`, `STEP_DIAG=141`. `speed` = credits/sec. Per tick add `speed*0.1`.
* **Substeps:** per actor, spend credits to attempt tile steps; carry remainder. Default cap **3 substeps/actor/tick**.
* **Order:** round-robin across ready actors within the tick. Stable ordering by persistent `actor_id`. New spawns append. Ties: lower `actor_id`, then older spawn.
* **Atomicity:** resolve all ready actors and their substeps inside the tick before render. No inter-tick peeking.

## Determinism and RNG

* **RNG:** stateless, split streams. Sample with a hash of `(tick, actor_id, substep_index, purpose_hash)` so results are order-independent across RT/TB.
* **Replay:** record `(tick_index, input)` stream. RT and TB replays must produce identical snapshots.

## Tick phases (read-old/write-next)

1. **Sense & intent build**
2. **Movement & collisions**
3. **Attacks & on-hit effects**
4. **Projectiles**
5. **Fields:** fire, gases, fluids
6. **Status:** wounds, timers

## Movement/combat

* **Corners:** no diagonal through fully blocked corners. Allow if at least one orthogonal neighbor is open.
* **Swap/push:** define explicit rules (swap allowed only if both intend; push requires target movable and enough credit).
* **Auto-targeting:** resolves in the Attacks phase using current intents.

## Projectiles

* Move in **tile substeps** (1 tile per substep). Interleave with actors in the same round-robin. No tunneling.

## Fire, gases, fluids, status

* **Fire/explosions:** same-tick emission may trigger explosions. Apply a per-tick **explosion budget** to cap chain reactions.
* **Gases (simple v1):** O₂, poison, explosive. Synchronous, conservative diffusion with integer mass. **Cell capacity 100**. Deterministic vertical bias. Conserve total mass and clamp to capacity.
* **Fluids:** maintain a **frontier queue**. Expand up to **N cells/tick**; shallow/deep states; hooks for stamina/hypothermia.
* **Wounds/first aid:** tick timers always advance; TB **Wait** advances status to prevent abuse.

## RT↔TB and interrupts

* **LOS/FOV rule:** general FOV updates on ticks. In RT **fast-move**, recompute **player-centric LOS after each player substep** to allow mid-tick interrupts.
* **Interrupts:** trigger TB or stop fast-move on: new LOS enemy, sudden low O₂, explosive gas near fire, deep water entry, or any prediction invalidation.
* **Input:** all actions queue to next tick. Lock input during tick resolution. No mid-tick cancels after RNG sampled.
* **Step-5 / Until-Safe:** enforce a **max tick budget per press**.

## Controls/UI

* **Mode banner:** Real-time / Turn-based.
* **TB commits:** Act, Wait, Step-5, Step-Until-Safe. Hold to “repeat last action”; stop on any interrupt or path-cost change.
* **Timeline strip:** predicted next 5 ticks’ actor icons using current credits/speeds and substep cap. Hide if invalidated by spawns/state changes.
* **Overlays:** status, limb panel, gas/water unchanged.

## Godot 4.5.1 implementation

* **Manager node only:**

  * **RT:** accumulator in `_process(dt)`; run capped catch-up.
  * **TB:** call `tick()` per commit. Do **not** use `Timer`; timers drift on low FPS and pause.
* **Actors:** in `"Sim"` group. Do not iterate group order directly. Each exposes intent/build and step hooks; **manager orchestrates** round-robin.
* **Sorting:** gather actors each tick and sort by persistent id.
* **Physics/visuals:** move tilewise by setting transforms; disable CCD; no `_physics_process` for rules. Render at 60 FPS; interpolate visuals only between previous/current tile states.
* **RNG/util:** global stateless RNG helper. `world_tick_index` increments per tick.
* **Savegame:** store `world_tick_index`, per-actor `move_credit`, RNG salt/base, and any mid-tick phase state.

## Data locks (initial)

* `STEP_CARD=100`, `STEP_DIAG=141`.
* **Substep cap:** 3 by default; overflow credit carries.
* **Projectile:** 1 tile/substep; speed controls substeps/tick.
* **Gas cell max:** 100 units. Explicit explosion threshold. Integer O₂/explosive mix rules.

## Anti-exploit

* Sample RNG **on resolution**, not on keypress. Show small “queued” marker in TB if needed.
* Cursor/look never advances sim or recalculates non-player FOV.

## Tests (must pass)

* **RT vs TB parity:** same seed+inputs → identical map snapshots every 50 ticks.
* **Fast-vs-slow passing:** with substep cap on/off.
* **Projectile vs mover:** entering same tile same tick across all orderings.
* **Explosion chain:** budget clamps chains deterministically.
* **Until-Safe:** stops on every listed interrupt.
* **Save/reload mid-tick:** resumes to same outcome.


i need help making my roguelike from scratch in godot 4.5.1. i want to start with the console. my idea is to have a console that's quite large and supports zooming. i want to use a camera2d to act as a zoom. the camera never moves, the console never moves. the console displays your character `@` in the center as you move around. don't do level generation just need a tiny test room. console should have square cells, but the glyphs (monospace font) shouldn't be stretched
**Tick:** fixed 100 ms. Accumulator in `_process(dt)`. Catch-up runs `while acc ≥ 0.1: tick(); acc -= 0.1`.
**Game time:** tick count only. Never read wall-clock for logic.
it takes 5 ticks to move cardinal, 7 diagonal
actions shouldn't be instant, 1 tick should pass at real time, 1 tick = 100ms in real life and in game.
**Console size:** 480×270 is ideal, but it's even, so player isn't centered. maybe 481x271 and keep the extra out of the camera view when at max zoom out so character is always centered and there's no letterboxing. FOV can see 120 out, so the console must accomodate this. use camera zoom to help with performance.