# res://tools/gen_human.gd
@tool
extends EditorScript
##
## One-shot generator for Human.plan.tres and human.tres
## Run: FileSystem panel → right-click this script → Run
## Output:
##   res://bodies/plans/Human.plan.tres
##   res://bodies/species/human.tres

const PLAN_OUT := "res://bodies/plans/Human.plan.tres"
const SPECIES_OUT := "res://bodies/species/human.tres"

func _run() -> void:
	_ensure_dir("res://bodies/plans")
	_ensure_dir("res://bodies/species")

	var plan := _build_human_plan()
	var err := ResourceSaver.save(plan, PLAN_OUT)
	if err != OK:
		push_error("Failed saving plan: %s (%s)" % [PLAN_OUT, str(err)])
		return

	var species := _build_human_species(PLAN_OUT)
	err = ResourceSaver.save(species, SPECIES_OUT)
	if err != OK:
		push_error("Failed saving species: %s (%s)" % [SPECIES_OUT, str(err)])
		return

	get_editor_interface().get_resource_filesystem().scan()
	print("Generated:", PLAN_OUT, "and", SPECIES_OUT)

# ── Builders ─────────────────────────────────────────────────────────────────

func _build_human_plan() -> BodyPlan:
	var p := BodyPlan.new()
	var parts: Array[BodyPart] = []

	# Zones
	parts.append(_Z(&"head",  &"head",  &"C", 12, 8,
		[_skin(20), _fat(10), _muscle(70)],
		{&"ingestor": 0.6},
		{&"sight": _S_SIGHT(), &"hearing": _S_HEAR(), &"scent": _S_SCENT()}
	))
	parts.append(_Z(&"torso", &"torso", &"C", 40, 46,
		[_skin(15), _fat(20), _muscle(45), _bone(20)]
	))

	# Arms L/R
	parts.append(_Z(&"upper_arm.L", &"arm", &"L", 4, 4, [_skin(20), _fat(15), _muscle(65)]))
	parts.append(_Z(&"lower_arm.L", &"arm", &"L", 3, 3, [_skin(25), _fat(10), _muscle(65)]))
	parts.append(_Z(&"hand.L",      &"arm", &"L", 2, 0, [_skin(30), _muscle(70)], {&"manipulator": 1.0}))
	parts.append(_Z(&"upper_arm.R", &"arm", &"R", 4, 4, [_skin(20), _fat(15), _muscle(65)]))
	parts.append(_Z(&"lower_arm.R", &"arm", &"R", 3, 3, [_skin(25), _fat(10), _muscle(65)]))
	parts.append(_Z(&"hand.R",      &"arm", &"R", 2, 0, [_skin(30), _muscle(70)], {&"manipulator": 1.0}))

	# Legs L/R
	parts.append(_Z(&"upper_leg.L", &"leg", &"L", 7, 8, [_skin(15), _fat(20), _muscle(65)]))
	parts.append(_Z(&"lower_leg.L", &"leg", &"L", 6, 6, [_skin(20), _fat(10), _muscle(70)]))
	parts.append(_Z(&"foot.L",      &"leg", &"L", 2, 2, [_skin(30), _muscle(70)], {&"locomotor": 1.0}))
	parts.append(_Z(&"upper_leg.R", &"leg", &"R", 7, 8, [_skin(15), _fat(20), _muscle(65)]))
	parts.append(_Z(&"lower_leg.R", &"leg", &"R", 6, 6, [_skin(20), _fat(10), _muscle(70)]))
	parts.append(_Z(&"foot.R",      &"leg", &"R", 2, 2, [_skin(30), _muscle(70)], {&"locomotor": 1.0}))

	# Organs
	parts.append(_O(&"brain",      &"vital_core",  &"head",  true,  {&"oxygen": {"consume": 5.0}, &"sleep": {"consume": 1.0}}))
	parts.append(_O(&"heart",      &"pump",        &"torso", false, {&"oxygen": {"gate": 1.0}}))
	parts.append(_O(&"lungs",      &"gas_exchange",&"torso", false, {&"oxygen": {"produce": 10.0, "capacity": 100.0}}))
	parts.append(_O(&"guts",       &"digestive",   &"torso", false, {
		&"nutrition": {"produce": 1.0, "capacity": 100.0},
		&"hydration": {"produce": 1.0, "capacity": 100.0}
	}))
	parts.append(_O(&"blood_pool", &"storage",     &"torso", false, {&"fluid": {"capacity": 100.0}}))

	p.parts = parts
	return p

func _build_human_species(plan_path:String) -> Species:
	var s := Species.new()
	s.id = &"human"
	s.display_name = "Human"
	s.glyph = "?"
	s.fg = Color(1, 0, 1, 1)   # magenta fallback glyph
	s.plan = load(plan_path)
	s.tags = [&"debug"]
	s.size_scale = 1.0
	# ~30s grace at 100ms/tick → 300 ticks; adjust later if needed.
	s.death_policy = {
		"or": [
			{"organ_destroyed": "brain"},
			{"channel_depleted": {"name": "oxygen", "ticks": 300}}
		]
	}
	return s

# ── Helpers ──────────────────────────────────────────────────────────────────

func _L(kind:StringName, thickness:int, rigid:bool, pierce:float, cut:float, blunt:float) -> Dictionary:
	return {
		"kind": kind,
		"thickness_pct": thickness,
		"rigid": rigid,
		"resist": {"pierce": pierce, "cut": cut, "blunt": blunt}
	}

func _skin(th:int) -> Dictionary:   return _L(&"skin",   th, false, 1.0, 1.0, 0.5)
func _fat(th:int) -> Dictionary:    return _L(&"fat",    th, false, 0.5, 0.3, 0.2)
func _muscle(th:int) -> Dictionary: return _L(&"muscle", th, false, 0.8, 0.9, 0.6)
func _bone(th:int) -> Dictionary:   return _L(&"bone",   th, true,  2.0, 1.5, 1.8)

func _Z(name:StringName, group:StringName, side:StringName, cov:int, vol:int, layers:Array, effectors:Dictionary = {}, sensors:Dictionary = {}, label_hint:String="") -> BodyPart:
	var z := BodyPart.new()
	z.name = name
	z.slot = &"zone"
	z.group = group
	z.side = side
	z.coverage_pct = cov
	z.volume_pct = vol
	z.label_hint = label_hint
	z.layers = layers.duplicate(true)
	z.effectors = effectors.duplicate(true)
	z.sensors = sensors.duplicate(true)
	return z

func _O(name:StringName, kind:StringName, host_zone:StringName, vital:bool, channels:Dictionary) -> BodyPart:
	var o := BodyPart.new()
	o.name = name
	o.slot = &"internal"
	o.kind = kind
	o.host_zone_id = host_zone
	o.vital = vital
	o.channels = channels.duplicate(true)
	return o

func _S_SIGHT() -> Dictionary: return {"range": 8.0, "fov_deg": 120.0, "acuity": 1.0, "night": 0.2, "tags": []}
func _S_HEAR()  -> Dictionary: return {"range": 8.0, "fov_deg": 360.0, "acuity": 1.0, "night": 1.0, "tags": []}
func _S_SCENT() -> Dictionary: return {"range": 6.0, "fov_deg": 360.0, "acuity": 0.7, "night": 1.0, "tags": []}

func _ensure_dir(dir_path:String) -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		return
	var d := DirAccess.open("res://")
	if d == null:
		push_error("Unable to open res:// to create " + dir_path)
		return
	var err := d.make_dir_recursive(dir_path)
	if err != OK:
		push_error("Failed to create " + dir_path + " (" + str(err) + ")")
