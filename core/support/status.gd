# res://core/support/status.gd
class_name Status
extends RefCounted
## Status registry and helpers (status-only survival).
## - Statuses are species-agnostic string IDs stored on Actor.statuses as {id:bool}.
## - No effects here. Other systems may read Status.has(actor, id).

const IDS := {
	&"-h": true, &"-H": true, &"+h": true,      # food
	&"-t": true, &"-T": true, &"+t": true,      # water
	&"-s": true, &"-S": true, &"+s": true,      # sleep
	&"-o": true, &"-O": true, &"+o": true,      # gas
	&"-c": true, &"-C": true,                   # cold
	&"-w": true, &"-W": true,                   # heat
	&"-b": true, &"-B": true,                   # solid waste
	&"-m": true, &"-M": true,                   # meat craving
	&"-p": true, &"-P": true                    # plant craving
}

static func _store(a) -> Dictionary:
	var d: Dictionary = {}
	if a != null and typeof(a.statuses) == TYPE_DICTIONARY:
		d = a.statuses as Dictionary
	else:
		d = {}
		a.statuses = d
	return d

static func has(a, id: StringName) -> bool:
	var d: Dictionary = _store(a)
	return bool(d.get(id, false))

# Renamed from `set` to avoid clashing with Object.set(StringName, Variant)
static func apply(a, id: StringName, on: bool) -> void:
	if !IDS.has(id):
		# allow unknown IDs if desired, or early-return here
		pass
	var d: Dictionary = _store(a)
	var prev: bool = bool(d.get(id, false))
	if prev == on: return
	d[id] = on
	a.statuses = d
	# Event hooks can be added later (e.g., MessageBus signals).

static func list(a) -> PackedStringArray:
	var d: Dictionary = _store(a)
	var out := PackedStringArray()
	for k in d.keys():
		if d[k]:
			out.append(String(k))
	return out

static func clear(a) -> void:
	a.statuses = {}
