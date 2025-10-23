# res://core/support/activity.gd
extends RefCounted
class_name Activity

var verb: StringName
var args: Dictionary
var remaining: int
var resume_key: Variant

static func from(v: StringName, a: Dictionary, need: int, key: Variant=null) -> Activity:
	var act := Activity.new()
	act.verb = v
	act.args = a
	act.remaining = max(0, int(need))
	act.resume_key = key
	return act
