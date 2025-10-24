# res://controllers/player_controller.gd
extends CommandSource
class_name PlayerController
##
## Player-controlled command source.
## - No tick locks. Scheduler decides pacing.
## - Returns at most one command when asked.
## - Prechecks verbs; blocked taps advance zero time and post a message.
## - Holds are optional (enabled via GameLoop policy).
## - RT idle policy: optionally return Wait(1) when no input.

var allow_holds: bool = false
var assume_wait_when_idle: bool = false

var _tap_pending: Variant = null
var _hold_sampler: Callable = Callable(self, "_no_holds")

func push(cmd: Dictionary) -> void:
	# Single-slot; last tap wins.
	_tap_pending = cmd

func set_hold_sampler(c: Callable) -> void:
	_hold_sampler = c if c.is_valid() else Callable(self, "_no_holds")

func dequeue(a: Actor, sim: SimManager) -> Variant:
	# 1) Pending tap first
	if _tap_pending != null:
		var cmd: Dictionary = _tap_pending
		_tap_pending = null
		if _can_start(a, cmd, sim):
			return cmd
		MessageBus.send("blocked: %s" % [str(cmd)], &"info", sim.tick_count, a.actor_id)
		return null

	# 2) Held inputs (if allowed)
	if allow_holds:
		var holds := _safe_holds()
		for hc in holds:
			if _can_start(a, hc, sim):
				return hc
		# No message spam on held blocks; silence by design.

	# 3) RT idle policy
	if assume_wait_when_idle:
		return {"verb": &"Wait", "args": {"ticks": 0}}

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
