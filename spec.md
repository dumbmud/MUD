\# Subterranean Life Sim — Spec v2



\## Core intent



Tile-based, realistic-ish subterranean life sim. Persistent world. You are a carnivore with regeneration. No runs, no resets. Everything persists.



\## Time and ticks



\* Tick = \*\*0.20 s\*\*. 18,000 ticks/hour.

\* Clock starts \*\*08:00\*\*. Time advances on all actions incl. rest/sleep.

\* \*\*HPmax 100\*\*.



\## Saves and permadeath



\* \*\*Autosave on area/shaft transition.\*\*

\* \*\*Permadeath ON:\*\* single save. `Q` = save+quit. File deleted on death.

\* \*\*Permadeath OFF:\*\* two saves: \*\*Auto\*\* (transitions), \*\*Manual\*\* (`Q`). Load most recent.

\* \*\*Fairness:\*\* `Q` costs \*\*10t\*\* and is blocked if any enemy visible \*\*or\*\* damage taken/dealt in last \*\*50t\*\*.



\## Pools and caps



\* Pools: \*\*kcal\*\*, \*\*water L\*\*, \*\*alert 0–100\*\*. Hidden in HUD by default.

\* Caps: \*\*kcal max 2400\*\*, \*\*water max 2.0 L\*\*, \*\*alert max 100\*\*.

\* Short, event-driven pool-state messages (≤20 chars). No placebo.



\## Baselines (per state, multiplier 1.0)



\* \*\*Idle:\*\* −1 kcal/\*\*225t\*\*; −0.01 L/\*\*1800t\*\*; alert −1/\*\*4800t\*\*

\* \*\*Act:\*\*  −1 kcal/\*\*72t\*\*;  −0.01 L/\*\*600t\*\*;  alert −1/\*\*3600t\*\*

\* \*\*Sleep:\*\*−1 kcal/\*\*300t\*\*; −0.01 L/\*\*3600t\*\*; alert \*\*+1/\*\*2100t\*\*



\## Hypermetabolism and regen



\* \*\*Gates:\*\* regen only if \*\*kcal ≥800\*\* and \*\*water ≥0.5\*\*.

\* \*\*Hysteresis:\*\* start at ≥800/≥0.50; pause if <750/<0.45.

\* \*\*Cost per +1 HP:\*\* \*\*50 kcal + 0.01 L\*\*.

\* \*\*Timing per +1 HP:\*\*



&nbsp; \* Sleep: HP 80–100 \*\*7200t\*\*; 40–79 \*\*14,400t\*\*; <40 \*\*28,800t\*\*.

&nbsp; \* Idle/Act: HP 80–100 \*\*14,400t\*\*; 40–79 \*\*28,800t\*\*; <40 \*\*57,600t\*\*.

\* \*\*Hypermetabolism applies to regen cost only:\*\*



&nbsp; \* HP 80–100 ×1.0; 40–79 ×1.25; <40 ×1.5. Baseline drains stay ×1.0.

\* Empty-pool HP damage unchanged: \*\*Starvation −1/216,000t\*\*, \*\*Dehydration −1/9,000t\*\*.



\## Speed and fatigue



\* Action speed multiplier = product of hunger and thirst bands; \*\*floor at 0.65\*\*.



&nbsp; \* kcal <800 → ×0.9; <300 → ×0.75.

&nbsp; \* water <0.5 → ×0.9; <0.25 → ×0.8.

\* Exhaustion: alert ≤40 “very tired.” ≤20 adds idle-skips (skip 1 per 200t).



\## Rest and sleep



\* \*\*Rest `s`:\*\* heals if gates met. Prohibited while any enemy \*\*visible\*\*. Stops on visibility, gates drop, or no progress. Log `Rested HH:MM:SS.t`.

\* \*\*Sleep `S`:\*\* requires alert ≤60. Prohibited while any enemy visible. Warn if kcal<300 or water<0.25; proceed on confirm. Runs until alert=100 or interrupted. Log `Slept HH:MM:SS.t`.

\* Chunk cap per loop: \*\*144,000t (8h)\*\*.



\## Actions and costs



\* Move hv \*\*5t\*\*, diag \*\*7t\*\*. Wait `.`=1t, `5`=5t.

\* Bump to attack. Default attack \*\*6t\*\*. Both sides \*\*commit\*\* actions.

\* Stairs/shafts `<` `>` \*\*10t\*\*, commit before transition.

\* \*\*Eat `e` 5t\*\*; blocked if enemies visible.

\* \*\*Drink `d` 0.25 L = 10t\*\*; blocked if enemies visible.

\* Help `?`. \*\*Q\*\* save+quit (rules above).



\## HUD and UI



\* Viewport \*\*43×13\*\*, centered when possible.

\* Right panel \*\*20 cols\*\*. Header: `F1AA 08:00:00.0 Cold`.

\* Line 2: `HP <n> \[##########]`.

\* Status tags: minimal. kcal: \*\*Peckish\*\* <1200, \*\*Hungry\*\* <800, \*\*Starving\*\* <300. water: \*\*Thirsty\*\* <1.0, \*\*Parched\*\* <0.5, \*\*Dry\*\* <0.25. alert: \*\*Drowsy\*\* ≤60, \*\*Very tired\*\* ≤40, \*\*Exhausted\*\* ≤20.

\* Advanced HUD toggle exposes numeric pools.



\## World model (replaces branching levels)



\* \*\*Slices:\*\* each \*\*Fₓ\*\* is a huge persistent 2D slice. \*\*Fₓ±1\*\* are adjacent vertical slices connected by shafts/ramps.

\* \*\*Streaming:\*\* chunked world. Default chunk \*\*128×128\*\* tiles. Active window \*\*5×5 chunks\*\*. Save deltas only.

\* \*\*Scale targets:\*\*



&nbsp; \* Ship: \*\*8k×8k tiles per slice\*\*.

&nbsp; \* Ambitious: \*\*16–32k\*\* per side. “Infinite” by chunk IDs if desired.

\* \*\*Rail→Ruin spine:\*\* a continuous spline across each slice. Terminates near Town density peaks, continues as Ruin below.



\## Fields → biome resolution



\* Scalar fields sampled per tile:



&nbsp; \* \*\*Temperature T(F)\*\* from anchors (below).

&nbsp; \* \*\*Moisture M\*\* (noise + sump proximity).

&nbsp; \* \*\*Geology G\*\* (openness/stone vs structure).

\* Biome decision (continuous, no bands):



&nbsp; \* \*\*Cold\*\* if T low.

&nbsp; \* \*\*Sump\*\* if T≥32°F and M high.

&nbsp; \* \*\*Mush\*\* if M high and G medium.

&nbsp; \* \*\*Cave\*\* if G high and M low.

&nbsp; \* \*\*Warm\*\* where geothermal mask hits.

\* Overlays:



&nbsp; \* \*\*Town:\*\* falloff around Rail termini; ≤6 rooms per high-density zone.

&nbsp; \* \*\*Wild:\*\* noise mask weighted by breadth proxy; at least one clean water tile per cluster.



\## Temperature anchors



Linear map: \*\*F→°F\*\*



\* 0→−15, 25→10, 50→35, 75→45, 100→55, 125→65, 150→80, 175→90, 200→100.

\* \*\*Sump forbidden when T<32°F\*\*.

\* \*\*Cave suppressed\*\* in deep ice; substitute Cold tunnels.



\## Water network (Sump)



\* Generate sinks then carve channels following −∇M.

\* Enforce T≥32°F along channels.

\* Place cisterns, seeps, and refill tiles at bends and confluences.



\## Points of interest



\* Rail stations, collapsed lifts, micro-Ruin, geothermal vents, fungal groves.

\* Scatter via Poisson disk per biome with rarity by T/M/G.



\## Ecology and AI



\* No random spawns. Populations with territories and sleep windows.

\* If you see them they \*\*may\*\* see you: depends on light. Otherwise detection via \*\*hearing\*\* radius and \*\*scent\*\* trails.

\* On loss of LOS: walk to last seen tile, then patrol/wander.

\* Corpses decay. Butchered meat shares the decay clock.



\## FoV and detection



\* \*\*Symmetric shadowcasting\*\* at viewport size. Cache per chunk until tiles change.

\* Detection symmetry only in lit tiles. In darkness use hearing/scent checks.



\## Food, butchering, cooking



\* Kill → corpse `×`. No respawns by default.

\* \*\*Butcher `b`\*\* (committed): Small \*\*25t→1\*\* meat; Medium \*\*75t→2\*\*; Large \*\*150t→4\*\*.

\* \*\*Meat per unit:\*\*



&nbsp; \* Fresh \*\*0–180,000t\*\*: \*\*300 kcal\*\*, \*\*0.05 L\*\*.

&nbsp; \* Stale \*\*180,001–360,000t\*\*: \*\*150 kcal\*\*, \*\*0.03 L\*\*.

&nbsp; \* Spoiled \*\*>360,000t\*\*: \*\*0 kcal\*\*, \*\*Sick\*\*: −1 HP/\*\*300t\*\* for \*\*3,000t\*\*; −5% hit.

\* \*\*Cooking\*\* (structures below):



&nbsp; \* \*\*Roast:\*\* +25% kcal, water −60%, sickness removed, freshness ×2.

&nbsp; \* \*\*Jerky/Smoker:\*\* kcal same, water −80%, sickness removed, freshness ×4.

&nbsp; \* \*\*Stew:\*\* costs \*\*0.5 L\*\* water → ration \*\*150 kcal, 0.15 L\*\*, sickness removed, freshness ×3.

\* \*\*Drink\*\* from waterskin or sources: `d` 0.25 L per \*\*10t\*\*. Refill sources \*\*10t/0.5 L\*\*.



\## Base building and tech



\* Placeables: \*\*fire pit\*\*, \*\*drying rack\*\*, \*\*smoker\*\*, \*\*cistern\*\*, \*\*butcher table\*\* (+1 yield on Large), \*\*bedroll\*\* (+10% sleep alert gain).

\* Construction uses raw stone/wood/metal salvage from Ruin/Rail.

\* Higher tech gated by rare finds in Rail/Ruin.



\## Inventory and burden (planned)



\* `i` inventory modal. Two columns. Stacks for readability.

\* Capacity metric \*\*◆\*\*. Default cap \*\*◆ 12.0\*\*.

\* `g` picks up only current tile.

\* Burden rules: Armor reduced burden (nonzero; TBD). Readied weapon \*\*0.25×\*\*; pack \*\*1.0×\*\*. No money/keys. Equip `\[W]/\[U]`. Two trinkets.



\## Equipment, combat, skills (planned)



\* Slots: head, torso, legs, boots, gloves, trinket1, trinket2, main, off.

\* Dual-wield: off-hand “small,” main not two-handed; main has % to proc off-hand.

\* Shields: % block that negates a hit.

\* Skills 1–10 per weapon; slow growth; affects hit/dmg/recovery/block.

\* Combat pipeline v1: to-hit → block → penetration vs armor → damage → wounds/debuffs.



\## Controls



\* Move arrows/numpad (diag 7t). Wait `.`=1t, `5`=5t.

\* Rest `s`. Sleep `S`.

\* Stairs/shafts `<` `>`.

\* Attack: bump.

\* Help `?`. \*\*Q\*\* save+quit.



\## Start options



\* Default start \*\*F1A\*\* near Rail. Optional random \*\*Fₓ\*\* sandbox spawn.



\## Persistence



\* Single-file format retained. Seed + per-chunk deltas (tiles changed, placed structures, corpses with timers, items, entities).

\* Atomic write on autosave.



\## Sanity checks (targets)



\* 1→100 HP with ~8h sleep + 12h idle daily: \*\*≈7.3 days\*\*.

\* 1→100 HP continuous sleep: \*\*≈4.3 days\*\*.

\* Week resources baseline (8h sleep, 12h idle, 4h act): \*\*≈2,440 kcal/day\*\*, \*\*≈2.8 L/day\*\*; seven days \*\*≈17,080 kcal, 19.6 L\*\*. Regen 99 HP adds \*\*≈4,950 kcal, 0.99 L\*\* before hypermetabolism multipliers.

\* Dehydration death from 2.0 L, no intake: empty ≈\*\*1.25 days\*\*, then \*\*30 min/HP\*\* → total \*\*≈3.3 days\*\*.

\* Starvation death from 2400 kcal, no intake: empty ≈\*\*1.67 days\*\*, then \*\*12 h/HP\*\* → total \*\*≈51.7 days\*\*.



\## Performance targets (Godot 4.5.1)



\* Chunk \*\*128×128\*\*. Active window \*\*5×5\*\*.

\* Live entities \*\*≤300\*\*; off-screen coarse sim.

\* One \*\*NavigationRegion\*\* per chunk; update ≤2 per second.

\* FoV per chunk cached; recompute on edits.

\* All clocks integer ticks; actions use `end\_tick` scheduling.



\## Open items



\* Finalize status thresholds and durations.

\* Species sleep schedules; lairs and patrols.

\* Shadowcasting edge-centering rules.

\* Burden cap tuning and per-item burdens; rounding/display.

\* Armor burden reductions by slot/material; readiness stacking.

\* Skill curves and exact modifiers.

\* Species→corpse size table; yields/times.

\* Meat realism vs physiology; tweak kcal/water and timers if needed.

\* Starting kit and sandbox toggles; random-spawn constraints (if any).



\## Lore premise (short)



Far beyond history, stacked civilizations fused into a subterranean world. The surface is dead. Life persists below. You are a carnivorous descendant of humans who regenerates. No language. Feared as an animal. Rail towers, caverns, sump, and fungal forests blend underground. Survive, hunt, build.













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