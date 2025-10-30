class_name Capacity
extends RefCounted
##
## Capacity derivation from BodyGraph baked dicts (no legacy).
## Input shape (body): { "nodes": {id->{tissue, integument, channels_present, sockets:[{kind,params}], ports:[{role,anchor,max_count}], tags:[]}}, "links":[{a,b,flow:{signal,fluid,gas}}] }
## Output keys: neuro, circ, resp, load, manip, sense, thermo, mobility

static func recompute_from_body(body: Dictionary, size_scale: float, mass_kg: float, reserve_mass: float = 0.0) -> Dictionary:
	if body.is_empty():
		return _zero_caps()

	var nodes: Dictionary = body.get("nodes", {})
	var links: Array = body.get("links", [])
	var n_total : int = max(1, nodes.size())

	# Build adjacency per channel
	var adj := {"signal": {}, "fluid": {}, "gas": {}}
	for id in nodes.keys():
		adj["signal"][id] = []
		adj["fluid"][id] = []
		adj["gas"][id] = []
	for e in links:
		if e == null: continue
		var a := StringName(e.get("a", &""))
		var b := StringName(e.get("b", &""))
		var f: Dictionary = e.get("flow", {})
		if bool(f.get("signal", 0) > 0):
			(adj["signal"][a] as Array).append(b)
			(adj["signal"][b] as Array).append(a)
		if bool(f.get("fluid", 0) > 0):
			(adj["fluid"][a] as Array).append(b)
			(adj["fluid"][b] as Array).append(a)
		if bool(f.get("gas", 0) > 0):
			(adj["gas"][a] as Array).append(b)
			(adj["gas"][b] as Array).append(a)

	# Locate controllers
	var controllers: Array[StringName] = []
	for id in nodes.keys():
		var sarr: Array = nodes[id].get("sockets", [])
		for s in sarr:
			if StringName(s.get("kind", &"")) == &"controller":
				controllers.append(id); break

	# Reachability
	var reach_signal := _reach_set(controllers, adj["signal"])
	var neuromotor := float(reach_signal.size()) / float(n_total)

	# Fluid/Gas presence sets
	var fluid_nodes := _filter_nodes_by_channel(nodes, &"fluid")
	var gas_nodes := _filter_nodes_by_channel(nodes, &"gas")

	# Largest connected coverage ratios (only within nodes that present the channel)
	var circ := _largest_component_ratio(fluid_nodes, adj["fluid"], n_total)
	var resp := _largest_component_ratio(gas_nodes, adj["gas"], n_total)

	# Effectors and sensors from sockets
	var mobility := _mobility_from_sockets(nodes, reach_signal)
	var manip := _sum_eff(nodes, reach_signal, &"manipulator")
	var load  := _support_score(nodes, reach_signal)
	var sense := _sense_from_sockets(nodes, reach_signal)

	# Thermoregulation: simple model using reserve mass and a surface proxy
	var rm : float = max(0.0, reserve_mass)
	var mm : float = max(0.1, mass_kg)
	var insul : float = clamp(rm / mm, 0.0, 0.6)     # 0..0.6 insulation from reserves
	var shed  : float = clamp(1.0 - insul, 0.2, 1.0) # ability to shed heat
	var thermo := {"insulation": insul, "shedding": shed}

	return {
		"neuro": neuromotor,
		"circ": circ,
		"resp": resp,
		"load": load,
		"manip": manip,
		"sense": sense,
		"thermo": thermo,
		"mobility": mobility
	}

# ── helpers ──────────────────────────────────────────────────────────────────

static func _zero_caps() -> Dictionary:
	return {"neuro":0.0,"circ":0.0,"resp":0.0,"load":0.0,"manip":0.0,"sense":{},"thermo":{},"mobility":{}}

static func _reach_set(starts: Array, adj: Dictionary) -> Dictionary:
	var seen := {}
	var q := []
	for s in starts:
		if s == &"": continue
		seen[s] = true
		q.append(s)
	while q.size() > 0:
		var u = q.pop_front()
		for v in adj.get(u, []):
			if !seen.has(v):
				seen[v] = true
				q.append(v)
	return seen  # Dictionary[id]->true

static func _filter_nodes_by_channel(nodes: Dictionary, ch: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in nodes.keys():
		var present: Dictionary = nodes[id].get("channels_present", {})
		if bool(present.get(ch, false)):
			out.append(id)
	return out

static func _largest_component_ratio(node_ids: Array, adj: Dictionary, n_total: int) -> float:
	if node_ids.is_empty() or n_total <= 0:
		return 0.0
	var allowed := {}
	for id in node_ids: allowed[id] = true
	var best := 0
	var seen := {}
	for id in node_ids:
		if seen.has(id): continue
		# BFS confined to allowed set
		var q := [id]
		seen[id] = true
		var count := 0
		while q.size() > 0:
			var u = q.pop_front()
			count += 1
			for v in adj.get(u, []):
				if allowed.has(v) and !seen.has(v):
					seen[v] = true
					q.append(v)
		if count > best: best = count
	return float(best) / float(n_total)

static func _mobility_from_sockets(nodes: Dictionary, reach_signal: Dictionary) -> Dictionary:
	# Aggregate locomotion modes from sockets on signal-reachable nodes.
	# Expected socket examples:
	#   {kind:"effector", params:{type:"locomotor", mode:"biped", score:1.0}}
	#   {kind:"effector", params:{locomotor:1.0, mode:"ground"}}
	var sum_by_mode := {}   # mode -> score
	for id in nodes.keys():
		if !reach_signal.has(id): continue
		for s in nodes[id].get("sockets", []):
			if StringName(s.get("kind", &"")) != &"effector": continue
			var p: Dictionary = s.get("params", {})
			var is_loco := bool(p.get("type", &"") == &"locomotor") or p.has("locomotor")
			if !is_loco: continue
			var mode := StringName(p.get("mode", &"ground"))
			var score := float(p.get("score", p.get("locomotor", 1.0)))
			sum_by_mode[mode] = float(sum_by_mode.get(mode, 0.0)) + max(0.0, score)
	# Soft normalize to 0..~2 range with diminishing return beyond 2.0
	var out := {}
	for m in sum_by_mode.keys():
		var r := float(sum_by_mode[m])
		var gain := r if r <= 2.0 else (2.0 + (r - 2.0) * 0.6)
		out[m] = {"score": clamp(gain, 0.0, 10.0)}
	return out

static func _sum_eff(nodes: Dictionary, reach_signal: Dictionary, eff_name: StringName) -> float:
	# Sum generic effector scores on reachable nodes.
	var acc := 0.0
	for id in nodes.keys():
		if !reach_signal.has(id): continue
		for s in nodes[id].get("sockets", []):
			if StringName(s.get("kind", &"")) != &"effector": continue
			var p: Dictionary = s.get("params", {})
			if p.has(eff_name):
				acc += max(0.0, float(p[eff_name]))
	return acc

static func _support_score(nodes: Dictionary, reach_signal: Dictionary) -> float:
	# Load-bearing from dedicated supports or structural ports.
	var acc := 0.0
	for id in nodes.keys():
		if !reach_signal.has(id): continue
		# sockets.kind=="support" → params.score
		for s in nodes[id].get("sockets", []):
			if StringName(s.get("kind", &"")) == &"support":
				acc += max(0.0, float((s.get("params", {}) as Dictionary).get("score", 1.0)))
		# ports with anchor "bone" contribute 0.25 each
		for pt in nodes[id].get("ports", []):
			if StringName(pt.get("anchor", &"")) == &"bone":
				acc += 0.25
	return acc

static func _sense_from_sockets(nodes: Dictionary, reach_signal: Dictionary) -> Dictionary:
	# Collect modality budgets; last-writer wins for simplicity.
	var out := {}  # modality -> params
	for id in nodes.keys():
		if !reach_signal.has(id): continue
		for s in nodes[id].get("sockets", []):
			if StringName(s.get("kind", &"")) != &"sensor": continue
			var p: Dictionary = s.get("params", {})
			var mod := StringName(p.get("modality", &""))
			if mod == &"": continue
			out[mod] = p.duplicate(true)
	return out
