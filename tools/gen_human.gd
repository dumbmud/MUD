@tool
extends EditorScript
##
## One-shot generator for Human.graph.tres and human.tres (BodyGraph-based).
## Run: FileSystem panel → right-click this script → Run
## Output:
##   res://bodies/plans/Human.graph.tres
##   res://bodies/species/human.tres

const GRAPH_OUT   := "res://bodies/plans/Human.graph.tres"
const SPECIES_OUT := "res://bodies/species/human.tres"
const SPECIES_SCRIPT := preload("res://creatures/_types/species.gd")

const SKIN_HP := 100
const SOFT_HP := 100
const STRUCT_HP := 100

const RESIST := {"cut": 1.0, "pierce": 1.0, "blunt": 1.0, "thermal": 1.0}

func _run() -> void:
	_ensure_dir("res://bodies/plans")
	_ensure_dir("res://bodies/species")

	var graph := _build_human_graph()
	var err := ResourceSaver.save(graph, GRAPH_OUT)
	if err != OK:
		push_error("Failed saving graph: %s (%s)" % [GRAPH_OUT, str(err)])
		return

	var species := _build_human_species(GRAPH_OUT)
	err = ResourceSaver.save(species, SPECIES_OUT)
	if err != OK:
		push_error("Failed saving species: %s (%s)" % [SPECIES_OUT, str(err)])
		return

	get_editor_interface().get_resource_filesystem().scan()
	print("Generated:", GRAPH_OUT, "and", SPECIES_OUT)

func _new_species() -> Species:
	var res := Resource.new()
	res.set_script(SPECIES_SCRIPT)
	return res as Species

# ── Builders ─────────────────────────────────────────────────────────────────

func _build_human_graph() -> BodyGraph:
	var g := BodyGraph.new()

	# nodes
	var torso := _N(&"torso", {"signal":true,"fluid":true,"gas":true}, [
		_sock_eff_loco(&"ground", 0.0),   # locomotion lives on feet; torso contributes 0
		_sock_support(1.0),
		_sock_pump(),          # heart placeholder
		_sock_resp_surface()   # lungs placeholder
	], [
		_port(&"limb",&"bone", 6)
	])

	var head := _N(&"head", {"signal":true,"fluid":true,"gas":true}, [
		_sock_controller(),
		_sock_sensor(&"sight",  {"range":8.0,"fov_deg":120.0,"acuity":1.0,"night":0.2}),
		_sock_sensor(&"hearing",{"range":8.0,"fov_deg":360.0,"acuity":1.0,"night":1.0}),
		_sock_sensor(&"scent",  {"range":6.0,"fov_deg":360.0,"acuity":0.7,"night":1.0})
	], [])

	# Arms L/R
	var ual := _N(&"upper_arm.L", {"signal":true,"fluid":true,"gas":false}, [], [_port(&"limb",&"bone",1)])
	var lal := _N(&"lower_arm.L", {"signal":true,"fluid":true,"gas":false}, [], [_port(&"limb",&"bone",1)])
	var hanl:= _N(&"hand.L",      {"signal":true,"fluid":true,"gas":false}, [
		_sock_eff_manip(1.0)
	], [])

	var uar := _N(&"upper_arm.R", {"signal":true,"fluid":true,"gas":false}, [], [_port(&"limb",&"bone",1)])
	var lar := _N(&"lower_arm.R", {"signal":true,"fluid":true,"gas":false}, [], [_port(&"limb",&"bone",1)])
	var hanr:= _N(&"hand.R",      {"signal":true,"fluid":true,"gas":false}, [
		_sock_eff_manip(1.0)
	], [])

	# Legs L/R
	var ull := _N(&"upper_leg.L", {"signal":true,"fluid":true,"gas":false}, [], [_port(&"limb",&"bone",1)])
	var lll := _N(&"lower_leg.L", {"signal":true,"fluid":true,"gas":false}, [], [_port(&"limb",&"bone",1)])
	var fotl:= _N(&"foot.L",      {"signal":true,"fluid":true,"gas":false}, [
		_sock_eff_loco(&"ground", 1.0)
	], [])

	var ulr := _N(&"upper_leg.R", {"signal":true,"fluid":true,"gas":false}, [], [_port(&"limb",&"bone",1)])
	var llr := _N(&"lower_leg.R", {"signal":true,"fluid":true,"gas":false}, [], [_port(&"limb",&"bone",1)])
	var fotr:= _N(&"foot.R",      {"signal":true,"fluid":true,"gas":false}, [
		_sock_eff_loco(&"ground", 1.0)
	], [])

	# assign nodes as a TypedArray[BodyNode]
	var node_list: Array[BodyNode] = []
	for n in [torso, head, ual, lal, hanl, uar, lar, hanr, ull, lll, fotl, ulr, llr, fotr]:
		node_list.append(n)
	g.nodes = node_list

	# links (signal=3 across all; fluid=3 across limbs; gas=2 only torso↔head)
	var L = func(a: StringName, b: StringName, sf:int, ff:int, gf:int) -> BodyLink:
		var e := BodyLink.new()
		e.a = a; e.b = b
		e.flow = {"signal":sf, "fluid":ff, "gas":gf}
		return e

	var link_list: Array[BodyLink] = []
	for e in [
		L.call(&"torso", &"head", 3, 3, 2),
		L.call(&"torso", &"upper_arm.L", 3, 3, 0),
		L.call(&"upper_arm.L", &"lower_arm.L", 3, 3, 0),
		L.call(&"lower_arm.L", &"hand.L", 3, 3, 0),
		L.call(&"torso", &"upper_arm.R", 3, 3, 0),
		L.call(&"upper_arm.R", &"lower_arm.R", 3, 3, 0),
		L.call(&"lower_arm.R", &"hand.R", 3, 3, 0),
		L.call(&"torso", &"upper_leg.L", 3, 3, 0),
		L.call(&"upper_leg.L", &"lower_leg.L", 3, 3, 0),
		L.call(&"lower_leg.L", &"foot.L", 3, 3, 0),
		L.call(&"torso", &"upper_leg.R", 3, 3, 0),
		L.call(&"upper_leg.R", &"lower_leg.R", 3, 3, 0),
		L.call(&"lower_leg.R", &"foot.R", 3, 3, 0)
	]:
		link_list.append(e)
	g.links = link_list

	return g

func _build_human_species(graph_path:String) -> Species:
	var s := _new_species()
	s.id = &"human"
	s.display_name = "Human"
	s.glyph = "?"
	s.fg = Color(1, 0, 1, 1)
	s.graph = load(graph_path)
	# Tags
	s.tags = [&"debug", &"sleep_required", &"solid_excretion", &"requires_gas:oxygen"]
	# Policy / physicals
	s.size_scale = 1.0
	s.death_policy = {
		"or": [
			{"organ_destroyed": "controller0"},
			{"channel_depleted": {"name": "oxygen", "ticks": 300}}
		]
	}
	s.body_mass_kg = 70.0
	# Survival defaults
	s.survival = {
		"diet_eff": {"plant": 0.6, "meat": 0.9},
		"diet_req": {"plant_min": 0.2, "meat_min": 0.1},
		"temp_band": {"min_C": 35.0, "max_C": 39.0},
		"requires_gas": "oxygen",
		"start_fat_kg": 12.0
	}
	return s


# ── Node/socket/port helpers ─────────────────────────────────────────────────

func _N(id:StringName, ch:Dictionary, sockets:Array, ports:Array, tags:Array[StringName]=[]) -> BodyNode:
	var n := BodyNode.new()
	n.id = id
	n.channels_present = {
		"signal": bool(ch.get("signal", true)),
		"fluid":  bool(ch.get("fluid",  true)),
		"gas":    bool(ch.get("gas",    true))
	}
	n.tissue = {"skin_hp": SKIN_HP, "soft_hp": SOFT_HP, "structure_hp": STRUCT_HP}
	n.integument = RESIST.duplicate()

	# force-typed arrays
	var s_out: Array[BodySocket] = []
	for s in sockets:
		if s is BodySocket: s_out.append(s)
	n.sockets = s_out

	var p_out: Array[BodyPort] = []
	for p in ports:
		if p is BodyPort: p_out.append(p)
	n.ports = p_out

	var t_out: Array[StringName] = []
	for t in tags:
		t_out.append(StringName(t))
	n.tags = t_out

	return n

func _sock_controller() -> BodySocket:
	var s := BodySocket.new()
	s.kind = &"controller"
	s.params = {"id": &"controller0"}
	return s

func _sock_eff_loco(medium:StringName, score:float) -> BodySocket:
	var s := BodySocket.new()
	s.kind = &"effector"
	# medium used by speed path; score contributes to mobility capacity
	s.params = {"type": &"locomotor", "medium": medium, "score": score}
	return s

func _sock_eff_manip(score:float) -> BodySocket:
	var s := BodySocket.new()
	s.kind = &"effector"
	s.params = {"manipulator": score}
	return s

func _sock_support(score:float) -> BodySocket:
	var s := BodySocket.new()
	s.kind = &"support"
	s.params = {"score": score}
	return s

func _sock_sensor(modality:StringName, p:Dictionary) -> BodySocket:
	var s := BodySocket.new()
	s.kind = &"sensor"
	var d := p.duplicate()
	d["modality"] = modality
	s.params = d
	return s

func _sock_pump() -> BodySocket:
	var s := BodySocket.new()
	s.kind = &"pump"
	s.params = {"name": &"circulation_gate"}
	return s

func _sock_resp_surface() -> BodySocket:
	var s := BodySocket.new()
	s.kind = &"resp_surface"
	s.params = {"name": &"oxygen_exchange"}
	return s

func _port(role:StringName, anchor:StringName, max_count:int) -> BodyPort:
	var p := BodyPort.new()
	p.role = role
	p.anchor = anchor
	p.max_count = max_count
	return p

# ── FS helper ────────────────────────────────────────────────────────────────

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
