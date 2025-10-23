# README

## What this is

A small, modular simulation core in Godot 4.5.1 built for “immersive sim” style systems. No special cases. Everything is a verb, scheduled by phase.

---

## Mental model

* **Tick**: fixed 0.1 s.
* **Phase**: integer budget. Regens `phase_per_tick`. Spent to commit actions.
* **Command**: intent `{ verb, args }`.
* **Activity**: in-flight work `{ verb, args, remaining, resume_key }`.
* **One command per actor per boundary**: taps beat holds.
* **Blocked actions**: do not advance time or phase.
* **TB vs RT**:

  * **Turn-based**: engine pauses at control boundaries.
  * **Real-time**: if no valid command, engine injects `Wait(1)`.

Fast actors can commit multiple actions per tick. The inner scheduler loops until no actor can commit or `MAX_ROUNDS_PER_TICK` is reached.

---

## Core architecture

```
res://
  core/
	support/
	  activity.gd            # Activity class
	  grid_occupancy.gd*     # Autoload: tile claims
	  message_bus.gd*        # Autoload: messages + per-tick rate limit
	verbs/
	  verb.gd                # Base class
	  move_verb.gd           # Movement
	  wait_verb.gd           # Wait
	  verbs_init.gd*         # Autoload: registers verbs
	registry/
	  verb_registry.gd*      # Autoload: name→Verb map
  creatures/
	_types/
	  actor.gd
	  body_part.gd
	  body_plan.gd
	  species.gd
	  species_db.gd*         # Autoload; compiles species, applies to Actor
	bodyplans/
	species/
  world/
	world_api.gd             # Contract
	world_test.gd            # Demo world
  scenes/
	SimCore.tscn             # SimManager + World node
	SimView.tscn             # Camera + Console + HUD
	Game.tscn                # SimView + SimCore
	console.gd               # ASCII renderer
	sim_manager.gd           # Simulation core
	sim_view.gd              # View/controller wrapper
	ui_overlay.gd            # HUD
```

`*` = Autoload singletons.

---

## Scene graph

* **Game.tscn**

  * `SimView` (script `sim_view.gd`)
  * `SimCore` (script `sim_manager.gd`)

	* `WorldTest` (script `world_test.gd`)

`SimView` subscribes to `SimManager` signals:

* `redraw(player_pos, resolver:Callable)`
* `hud(tick, pos, mode_label, phase, phase_per_tick, is_busy, steps)`

---

## Autoloads

Enable the scripts in the autoloads folder with Project Settings → Autoload:

---

## Key modules

### SimManager (`scenes/sim_manager.gd`)

* Fixed tick loop.
* Phase regen and cap.
* Command acquisition:

  * Drain invalid taps.
  * If taps empty, sample holds once at boundary.
  * RT injects `Wait(1)`.
* Activity scheduling:

  * Player first (sorted by `actor_id`).
  * Multiple commit rounds per tick (`MAX_ROUNDS_PER_TICK`).
* No mid-tick resampling. No TU decay on blocked input.

### Verbs

* Base `Verb` with `can_start`, `phase_cost`, `apply`, `resumable_key`.
* `MoveVerb`: diagonal corner rule, uses `GridOccupancy`.
* `WaitVerb`: spends `ticks * phase_per_tick`. Resets phase at start.

### World API

* `WorldAPI` interface: `is_passable`, `is_wall`, `glyph`.
* `WorldTest`: demo layout. Swappable world nodes.

### Occupancy

* `GridOccupancy` tracks `id ↔ pos`.
* Signals: `claimed`, `released`, `moved`, `reset`.

### Species

* `SpeciesDB` compiles resources. Provides `get_speed()` and `apply_to()`.
* Fallback: missing species → use human stats but magenta `?` glyph.

### Messaging

* `MessageBus.send(text, kind, tick, actor_id)`
* `send_once_per_tick(key, ...)` to rate-limit repeated holds.

---

## Input model

* **Tap**: enqueue one command. Consumed at next boundary.
* **Hold**: sampled once when control is regained. No mid-tick rescans.
* Zoom is handled in `SimView` only.

---

## Determinism

* Single `RandomNumberGenerator` in `SimManager`, seeded by `rng_seed`.
* Do not call RNG in view/UI.
* For record-and-replay, log inputs and `rng_seed`.

---

## Constants and caps

* Tick: `TICK_SEC = 0.1`
* Phase cap: `PHASE_MAX = 1_000_000`
* Move costs: 100 cardinal, 141 diagonal (Pythagorean int).
* Commit loop safety: `MAX_ROUNDS_PER_TICK = 32`

---

## Adding a verb

1. Create `core/verbs/<name>_verb.gd` extending `Verb`.
2. Implement:

   * `can_start(a, args, sim)` — no time effects, pure checks.
   * `phase_cost(a, args, sim)` — integer cost.
   * `apply(a, args, sim)` — mutate world, return `true` if committed.
   * `resumable_key(...)` — return a stable key or `null`.
3. Register in `core/verbs/verbs_init.gd`:

   ```gdscript
   VerbRegistry.register(&"MyVerb", preload("res://core/verbs/my_verb.gd").new())
   ```
4. Issue commands from input or AI as `{ "verb": &"MyVerb", "args": { ... } }`.

No changes to `SimManager` needed.

---

## Swapping worlds

* Replace `WorldTest` child with your world node implementing `WorldAPI`.
* Update `SimCore.tscn` child node script. No other changes.

---

## Coding rules

* No special cases. If a command can’t start, reject early. Do not spend phase.
* Only `SimManager` handles input → command. Views do zoom only.
* Type explicitly if inference yields `Variant`.
* Avoid names that shadow built-ins (`round`, `seed`, `name`).
* Prefix unused parameters with `_`.

---

## Build and run

1. Set **Main Scene** to `res://scenes/Game.tscn`.
2. Ensure all autoloads are added (list above).
3. Run. Arrow keys to move. `.` is floor, `#` is wall. HUD shows phase.

---

## Glossary

* **Boundary**: moment an actor has no activity in flight.
* **Tap queue**: FIFO of player taps.
* **Hold**: currently pressed keys sampled at boundary.
* **Resumable**: long tasks that pause/resume via `resume_key`.

---

## Debug tips

* Set `MAX_ROUNDS_PER_TICK` low to catch runaway commits.
* Use `MessageBus` for blocked reasons.
* Assert occupancy invariants in dev builds if needed.

This is a foundation. Future systems plug new verbs, worlds, and content without touching the scheduler.
