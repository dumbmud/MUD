# res://controllers/player_controller.gd
extends CommandSource
class_name PlayerController
##
## Player-controlled command source.
## - Single pending tap (last tap wins). Extra taps in the same tick are ignored.
## - At most one command per tick from this source (covers holds too).
## - No world mutations. Only proposes commands.

var _tap_pending: Variant = null
var _hold_sampler: Callable = Callable(self, "_no_holds")

var _last_hold_block_tick: int = -1
var _lock_tick: int = -1           # hard cap: one command per tick
var _tap_locked: bool = false      # ignore pushes until next tick after a tap is consumed
var _lock_release_tick: int = -1   # tick when tap lock can be cleared

func push(cmd: Dictionary) -> void:
	# Do not queue taps after one was consumed for this tick.
	if _tap_locked:
		return
	_tap_pending = cmd  # single-slot; last tap wins

func set_hold_sampler(c: Callable) -> void:
	_hold_sampler = c if c.is_valid() else Callable(self, "_no_holds")

func dequeue(a: Actor, sim: SimManager) -> Variant:
	# Release tap lock when the next tick begins.
	if _tap_locked and sim.tick_count >= _lock_release_tick:
		_tap_locked = false

	# Enforce at most one command per tick.
	if _lock_tick == sim.tick_count:
		return null

	# 1) Pending tap first.
	if _tap_pending != null:
		var cmd: Dictionary = _tap_pending
		_tap_pending = null
		if _can_start(a, cmd, sim):
			# Lock taps and further commands for this tick.
			_tap_locked = true
			_lock_release_tick = sim.tick_count + 1
			_lock_tick = sim.tick_count
			return cmd
		# Drop and report once on failure.
		MessageBus.send("blocked: %s" % [str(cmd)], &"info", sim.tick_count, a.actor_id)
		# fall through

	# 2) Holds once per boundary.
	var holds := _safe_holds()
	for hc in holds:
		if _can_start(a, hc, sim):
			_lock_tick = sim.tick_count
			return hc
	if holds.size() > 0 and _last_hold_block_tick != sim.tick_count:
		_last_hold_block_tick = sim.tick_count
		MessageBus.send("blocked: %s" % [str(holds[0])], &"info", sim.tick_count, a.actor_id)

	# 3) RT fallback.
	if sim.mode == SimManager.GameMode.REAL_TIME:
		_lock_tick = sim.tick_count
		return {"verb": &"Wait", "args": {"ticks": 1}}

	return null

# ── helpers ──────────────────────────────────────────────────────────────────

func _can_start(a: Actor, cmd: Dictionary, sim: SimManager) -> bool:
	var verb_name: StringName = cmd.get("verb", &"")
	var args: Dictionary = cmd.get("args", {})
	var v := VerbRegistry.get_verb(verb_name)
	return v != null and v.can_start(a, args, sim)

func _safe_holds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _hold_sampler.is_valid():
		var r: Variant = _hold_sampler.call()
		if r is Array:
			for it in r:
				if it is Dictionary:
					out.append(it)
	return out

func _no_holds() -> Array[Dictionary]:
	return []
