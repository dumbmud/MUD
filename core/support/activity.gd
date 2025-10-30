# res://core/support/activity.gd
class_name Activity
extends RefCounted
##
## Work-in-progress for a verb.
## - `remaining` is total phase still required to commit.
## - The scheduler spends the actor’s per-tick phase toward `remaining`.
## - Commit occurs only when `remaining == 0` in a round. No mid-commit effects.

var verb: StringName
var args: Dictionary
var remaining: int
var resume_key: Variant

static func from(v: StringName, a: Dictionary, need: int, key: Variant=null) -> Activity:
	var act := Activity.new()
	act.verb = v
	act.args = a
	act.remaining = max(1, int(need))
	act.resume_key = key
	return act
