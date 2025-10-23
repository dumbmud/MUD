# res://core/support/activity.gd
extends RefCounted
class_name Activity
## In-flight work unit for an actor.

var verb: StringName
var args: Dictionary
var remaining: int
var resume_key: Variant = null

static func from(verb_name: StringName, args_in: Dictionary, remaining_phase: int, resume_key_in: Variant = null) -> Activity:
	var a := Activity.new()
	a.verb = verb_name
	a.args = args_in
	a.remaining = remaining_phase
	a.resume_key = resume_key_in
	return a
