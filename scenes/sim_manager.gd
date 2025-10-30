# res://scenes/sim_manager.gd
class_name SimManager
extends Node2D
##
## Pure scheduler.
## - No knowledge of TB/RT or “player”.
## - Time unit = tick; per-tick budget = 100 phase (1 phase = 1 ms, 100 ms/tick).
## - Actions are activities: remaining phase is spent across rounds; commit at 0.
## - Public stepping:
##     * step_tick(): advance one full tick (begin → rounds until quiet → end).
##     * step_round(stop_on_actor_id := -1): advance a single round; optionally
##         stop early as soon as `stop_on_actor_id` commits. Returns:
##         { "spent": bool, "stopped_on_target": bool }.
##     * end_tick_if_quiet(): finalize the current tick if nobody can spend more.
const PHASE_PER_TICK := 100

signal tick_advanced(tick: int)
signal state_changed()

var world: WorldAPI = null

var tick_count: int = 0
var in_tick: bool = false

var actors: Array[Actor] = []
var actor_by_id: Dictionary = {}            # int -> Actor
var controller_by_id: Dictionary = {}       # int -> CommandSource
var activity_by_id: Dictionary = {}         # int -> Activity or null
var resume_table: Dictionary = {}           # Variant -> Activity
var pending_cmd_by_id: Dictionary = {}      # int -> {verb,args}

# ── wiring ───────────────────────────────────────────────────────────────────

func set_world(w: WorldAPI) -> void:
	world = w

func add_actor(a: Actor, src: CommandSource) -> void:
	actors.append(a)
	actor_by_id[a.actor_id] = a
	controller_by_id[a.actor_id] = src
	activity_by_id[a.actor_id] = null
	GridOccupancy.claim(a.actor_id, a.grid_pos)

func get_actor(id: int) -> Actor:
	return actor_by_id.get(id, null)

# ── stepping API ─────────────────────────────────────────────────────────────

func step_tick() -> void:
	_begin_tick_if_needed()
	while true:
		var r := step_round(-1)
		if !bool(r["spent"]):
			_end_tick()
			break

func step_round(stop_on_actor_id: int = -1) -> Dictionary:
	# Returns {"spent": bool, "stopped_on_target": bool}
	_begin_tick_if_needed()
	var spent_any := false
	var stopped := false

	# Stable order by actor_id each tick
	for a in actors:
		if a.phase <= 0:
			continue

		# Acquire or continue an activity
		var act: Activity = activity_by_id.get(a.actor_id, null)
		if act == null:
			var cmd_v: Variant = _acquire_command(a)
			if cmd_v != null:
				var cmd: Dictionary = cmd_v
				var verb_name: StringName = cmd.get("verb", &"")
				var args: Dictionary = cmd.get("args", {})
				var verb := VerbRegistry.get_verb(verb_name)
				if verb != null:
					var key: Variant = verb.resumable_key(a, args, self)
					if key != null and resume_table.has(key):
						act = resume_table[key]
					else:
						var need: int = max(1, int(verb.phase_cost(a, args, self)))
						act = Activity.from(verb_name, args, need, key)
					activity_by_id[a.actor_id] = act

		# Spend and possibly commit
		act = activity_by_id.get(a.actor_id, null)
		if act != null:
			var spend: int = min(a.phase, act.remaining)
			if spend > 0:
				a.phase -= spend
				act.remaining -= spend
				spent_any = true
			if act.remaining <= 0:
				var verb2 := VerbRegistry.get_verb(act.verb)
				var _ok: bool = verb2 != null and verb2.apply(a, act.args, self)
				if act.resume_key != null:
					resume_table.erase(act.resume_key)
				activity_by_id[a.actor_id] = null
				if a.actor_id == stop_on_actor_id:
					stopped = true
					emit_signal("state_changed")
					break

	emit_signal("state_changed")
	return {"spent": spent_any, "stopped_on_target": stopped}

func end_tick_if_quiet() -> void:
	# External helper when driving rounds manually (TB). Ends the tick
	# if nobody can spend more this tick (i.e., all phase == 0).
	if !in_tick:
		return
	for a in actors:
		if a.phase > 0:
			return
	_end_tick()

# ── internals ────────────────────────────────────────────────────────────────

func _begin_tick_if_needed() -> void:
	if in_tick:
		return
	in_tick = true
	# Reset per-tick budgets
	for a in actors:
		a.phase = PHASE_PER_TICK
	# Stable order: ascending actor_id
	actors.sort_custom(func(x, y): return x.actor_id < y.actor_id)

func _end_tick() -> void:
	if !in_tick:
		return
	
	# TODO tie into survival system
	# background stamina regen for all actors
	var dt := float(PHASE_PER_TICK) * 0.001  # 100 ms/tick ⇒ 0.1 s
	for a in actors:
		var st: Dictionary = a.stamina
		var v := float(st.get("value", 0.0))
		var mx := float(st.get("max", 100.0))
		v = clampf(v + Physio.stamina_regen_over(a, dt), 0.0, mx)
		st["value"] = v
		a.stamina = st
	
	in_tick = false
	tick_count += 1
	emit_signal("tick_advanced", tick_count)
	emit_signal("state_changed")

func _acquire_command(a: Actor) -> Variant:
	# Use prefetched command first (driver path for TB), else ask the source.
	var id := a.actor_id
	if pending_cmd_by_id.has(id):
		var cmd: Dictionary = pending_cmd_by_id[id]
		pending_cmd_by_id.erase(id)
		return cmd
	var src: CommandSource = controller_by_id.get(id, null)
	return src.dequeue(a, self) if src != null else null

func prefetch_command(actor_id: int) -> bool:
	# Ask the controller once without advancing time and stash the result.
	var a := get_actor(actor_id)
	var src: CommandSource = controller_by_id.get(actor_id, null)
	if a == null or src == null:
		return false
	if pending_cmd_by_id.has(actor_id):
		return true
	var cmd: Variant = src.dequeue(a, self)
	if cmd != null:
		pending_cmd_by_id[actor_id] = cmd
		return true
	return false
