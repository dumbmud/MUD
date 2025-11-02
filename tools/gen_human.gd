@tool
extends EditorScript
##
## Generates:
##   res://bodies/plans/Human.graph.tres
##   res://bodies/species/human.tres

const GRAPH_OUT   := "res://bodies/plans/Human.graph.tres"
const SPECIES_OUT := "res://bodies/species/human.tres"

const SPECIES_SCRIPT := preload("res://creatures/_types/species.gd")
const BODY_GRAPH     := preload("res://creatures/_types/body_graph.gd")
const BODY_NODE      := preload("res://creatures/_types/body_node.gd")
const BODY_LINK      := preload("res://creatures/_types/body_link.gd")
const BODY_SOCKET    := preload("res://creatures/_types/body_socket.gd")
const BODY_PORT      := preload("res://creatures/_types/body_port.gd")

const SKIN_HP := 100
const SOFT_HP := 100
const STRUCT_HP := 100

func _run() -> void:
	_ensure_dir("res://bodies/plans")
	_ensure_dir("res://bodies/species")

	var g: BodyGraph = _build_human_graph()
	var err := ResourceSaver.save(g, GRAPH_OUT)
	if err != OK:
		push_error("Failed to save graph: %s" % err)
		return

	var s: Resource = _build_human_species(GRAPH_OUT)
	err = ResourceSaver.save(s, SPECIES_OUT)
	if err != OK:
		push_error("Failed to save species: %s" % err)
		return
	print("Generated:", GRAPH_OUT, "and", SPECIES_OUT)

# ── helpers ──────────────────────────────────────────────────────────────────

func _N(id: StringName, channels: Dictionary, sockets: Array, ports: Array, tags: Array = [], props: Dictionary = {}) -> BodyNode:
	var n: BodyNode = BODY_NODE.new()
	n.id = id
	n.tissue = {"skin_hp": SKIN_HP, "soft_hp": SOFT_HP, "structure_hp": STRUCT_HP}
	n.integument = {"cut": 1.0, "pierce": 1.0, "blunt": 1.0, "thermal": 1.0}
	n.channels_present = channels

	n.sockets = []
	for s in sockets: n.sockets.append(s as BodySocket)
	n.ports = []
	for p in ports:   n.ports.append(p as BodyPort)

	n.tags = []
	for t in tags: n.tags.append(t)  # keep as Strings
	if "props" in n: n.props = props.duplicate(true)
	return n

func _sock_eff_loco(medium: StringName, weight: float) -> BodySocket:
	var s: BodySocket = BODY_SOCKET.new()
	s.kind = &"effector"
	s.params = {"kind": "loco", "medium": medium, "weight": weight}
	return s

func _sock_support(weight: float) -> BodySocket:
	var s: BodySocket = BODY_SOCKET.new()
	s.kind = &"effector"
	s.params = {"kind": "support", "weight": weight}
	return s

func _sock_resp_surface() -> BodySocket:
	var s: BodySocket = BODY_SOCKET.new()
	s.kind = &"resp_surface"
	s.params = {}
	return s

func _sock_pump() -> BodySocket:
	var s: BodySocket = BODY_SOCKET.new()
	s.kind = &"gland"
	s.params = {"kind": "pump"}
	return s

func _sock_controller() -> BodySocket:
	var s: BodySocket = BODY_SOCKET.new()
	s.kind = &"controller"
	s.params = {"kind": "brain"}
	return s

func _port(role: StringName, anchor: StringName, maxc: int) -> BodyPort:
	var p: BodyPort = BODY_PORT.new()
	p.role = role
	p.anchor = anchor
	p.max_count = maxc
	return p

func _link(a: StringName, b: StringName, sf: int, ff: int, gf: int) -> BodyLink:
	var e: BodyLink = BODY_LINK.new()
	e.a = a
	e.b = b
	e.flow = {"signal": sf, "fluid": ff, "gas": gf}
	return e

# ── graph ────────────────────────────────────────────────────────────────────

func _build_human_graph() -> BodyGraph:
	var g: BodyGraph = BODY_GRAPH.new()

	var torso := _N(&"torso", {"signal": true, "fluid": true, "gas": true}, [
		_sock_eff_loco(&"ground", 0.0),
		_sock_support(1.0),
		_sock_pump(),
		_sock_resp_surface()
	], [
		_port(&"limb", &"bone", 6)
	], ["core"])

	var head := _N(&"head", {"signal": true, "fluid": true, "gas": true}, [
		_sock_controller()   # controller organ lives here
	], [], ["core"])

	var pelvis := _N(&"pelvis", {"signal": true, "fluid": true, "gas": false}, [
		_sock_support(1.0)
	], [
		_port(&"limb", &"bone", 2)
	], ["core", "pelvic"])

	var ual := _N(&"upper_arm.L", {"signal": true, "fluid": true, "gas": false}, [], [_port(&"limb", &"bone", 1)])
	var lal := _N(&"lower_arm.L", {"signal": true, "fluid": true, "gas": false}, [], [_port(&"limb", &"bone", 1)])
	var hanl := _N(&"hand.L", {"signal": true, "fluid": true, "gas": false}, [], [])

	var uar := _N(&"upper_arm.R", {"signal": true, "fluid": true, "gas": false}, [], [_port(&"limb", &"bone", 1)])
	var lar := _N(&"lower_arm.R", {"signal": true, "fluid": true, "gas": false}, [], [_port(&"limb", &"bone", 1)])
	var hanr := _N(&"hand.R", {"signal": true, "fluid": true, "gas": false}, [], [])

	var ull := _N(&"upper_leg.L", {"signal": true, "fluid": true, "gas": false}, [], [_port(&"limb", &"bone", 1)])
	var lll := _N(&"lower_leg.L", {"signal": true, "fluid": true, "gas": false}, [], [_port(&"limb", &"bone", 1)])
	var fotl := _N(&"foot.L", {"signal": true, "fluid": true, "gas": false}, [_sock_eff_loco(&"ground", 1.0)], [])

	var ulr := _N(&"upper_leg.R", {"signal": true, "fluid": true, "gas": false}, [], [_port(&"limb", &"bone", 1)])
	var llr := _N(&"lower_leg.R", {"signal": true, "fluid": true, "gas": false}, [], [_port(&"limb", &"bone", 1)])
	var fotr := _N(&"foot.R", {"signal": true, "fluid": true, "gas": false}, [_sock_eff_loco(&"ground", 1.0)], [])

	var nodes: Array = []
	nodes.append(torso); nodes.append(head); nodes.append(pelvis)
	nodes.append(ual); nodes.append(lal); nodes.append(hanl)
	nodes.append(uar); nodes.append(lar); nodes.append(hanr)
	nodes.append(ull); nodes.append(lll); nodes.append(fotl)
	nodes.append(ulr); nodes.append(llr); nodes.append(fotr)
	g.nodes = nodes

	var links: Array = []
	links.append(_link(&"torso", &"head", 3, 3, 2))
	links.append(_link(&"torso", &"pelvis", 3, 3, 0))
	links.append(_link(&"pelvis", &"upper_leg.L", 3, 3, 0))
	links.append(_link(&"upper_leg.L", &"lower_leg.L", 3, 3, 0))
	links.append(_link(&"lower_leg.L", &"foot.L", 3, 3, 0))
	links.append(_link(&"pelvis", &"upper_leg.R", 3, 3, 0))
	links.append(_link(&"upper_leg.R", &"lower_leg.R", 3, 3, 0))
	links.append(_link(&"lower_leg.R", &"foot.R", 3, 3, 0))
	links.append(_link(&"torso", &"upper_arm.L", 3, 3, 0))
	links.append(_link(&"upper_arm.L", &"lower_arm.L", 3, 3, 0))
	links.append(_link(&"lower_arm.L", &"hand.L", 3, 3, 0))
	links.append(_link(&"torso", &"upper_arm.R", 3, 3, 0))
	links.append(_link(&"upper_arm.R", &"lower_arm.R", 3, 3, 0))
	links.append(_link(&"lower_arm.R", &"hand.R", 3, 3, 0))
	g.links = links
	return g

# ── species ──────────────────────────────────────────────────────────────────

func _build_human_species(graph_path: String) -> Resource:
	var s := SPECIES_SCRIPT.new()
	s.id = &"human"
	s.display_name = "Human"
	s.glyph = "?"
	s.fg = Color(1.0, 0.0, 1.0, 1.0)
	s.graph = load(graph_path) as BodyGraph

	s.tags = [&"debug", &"sleep_required", &"solid_excretion", &"requires_gas:oxygen"]
	s.size_scale = 1.0
	# Keep death policy simple and valid for now: oxygen only. (Future: controller-socket kill)
	s.death_policy = {"or": [{"channel_depleted": {"name": "oxygen", "ticks": 300}}]}
	s.body_mass_kg = 70.0
	s.survival = {
		"diet_eff": {"plant": 0.6, "meat": 0.9},
		"diet_req": {"plant_min": 0.2, "meat_min": 0.1},
		"requires_gas": "oxygen",
		"start_fat_kg": 12.0,
		"temp_band": {"min_C": 35.0, "max_C": 39.0}
	}

	# morph scaffolding (foundation only)
	s.repro_key = &"human"
	s.morph_rules = {"sex_system": "dioecious", "weights": {"sex.micro": 50, "sex.macro": 50}}
	s.morph_defs = {
		"sex.micro": {"ops": [
			{"op": "add_node", "id": "repro/gonad.micro", "tags": ["repro","internal","organ_type:gonad"], "props": {"repro_active": false, "gestation_site": false, "gamete_out.micro": true}},
			{"op": "add_link", "a": "pelvis", "b": "repro/gonad.micro", "flow": {"signal":3, "fluid":3, "gas":0}}
		]},
		"sex.macro": {"ops": [
			{"op": "add_node", "id": "repro/gonad.macro", "tags": ["repro","internal","organ_type:gonad"], "props": {"repro_active": false, "gestation_site": true, "gamete_out.macro": true}},
			{"op": "add_link", "a": "pelvis", "b": "repro/gonad.macro", "flow": {"signal":3, "fluid":3, "gas":0}},
			{"op": "add_node", "id": "repro/breast.L", "tags": ["repro","external","organ_type:lactation"], "props": {"repro_active": false, "feed_out": true, "mount_parent": "torso", "mount_hint": "front"}},
			{"op": "add_node", "id": "repro/breast.R", "tags": ["repro","external","organ_type:lactation"], "props": {"repro_active": false, "feed_out": true, "mount_parent": "torso", "mount_hint": "front"}},
			{"op": "add_link", "a": "torso", "b": "repro/breast.L", "flow": {"signal":3, "fluid":1, "gas":0}},
			{"op": "add_link", "a": "torso", "b": "repro/breast.R", "flow": {"signal":3, "fluid":1, "gas":0}}
		]}
	}
	return s

# ── FS helper ────────────────────────────────────────────────────────────────

func _ensure_dir(dir_path: String) -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		return
	var d := DirAccess.open("res://")
	if d == null:
		push_error("Unable to open res:// to create " + dir_path)
		return
	var err := d.make_dir_recursive(dir_path)
	if err != OK:
		push_error("Failed to create " + dir_path + " (" + str(err) + ")")
