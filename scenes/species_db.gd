class_name SpeciesDB
extends RefCounted

const DATA: Dictionary = {
	"human":  {"name":"Human",  "glyph":"@", "fg": Color(1,1,1), "tu_per_tick":20, "tags":[]},
	"goblin": {"name":"Goblin", "glyph":"g", "fg": Color(0,1,0), "tu_per_tick":20, "tags":["humanoid"]},
	# "snail": {"glyph":"Ҩ"}
	# "mushfolk": {"glyph":"╥"}
}

static func get_species(id: String) -> Dictionary:
	return (DATA.get(id, DATA["human"]) as Dictionary)

static func apply_to(species_id: String, a: Actor) -> void:
	var s: Dictionary = get_species(species_id)
	a.glyph = s["glyph"]
	a.fg_color = s["fg"]
	a.tu_per_tick = s["tu_per_tick"]
