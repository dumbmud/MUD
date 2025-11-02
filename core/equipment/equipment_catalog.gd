# res://core/equipment/equipment_catalog.gd
class_name EquipmentCatalog
extends Node
##
## Minimal in-code catalog. Autoload this, or `new()` it where needed.

var by_id: Dictionary = {}   # StringName -> EquipmentItem

func _ready() -> void:
	by_id.clear()
	# --- DRAPE ---
	_reg(_d("cloak",        "Cloak",        2.0,  true, 2, "cloak"))
	_reg(_d("backpack",     "Backpack",     3.0,  true, 3, "backpack"))
	_reg(_d("quiver",       "Quiver",       1.0,  true, 2, "quiver"))
	_reg(_d("utility_belt", "Utility Belt", 0.8,  true, 1, "pouch"))

	# --- HEAD ---
	_reg(_b("leather_hat", "Leather Hat", 0.5, 2, false, ["id:head"], {}))
	_reg(_b("iron_helmet", "Iron Helmet", 2.5, 3, true,  ["id:head"], {}))

	# --- TORSO + ARMS ---
	_reg(_b("shirt",     "Shirt",      0.4, 1, false, ["id:torso","glob:upper_arm.*","glob:lower_arm.*"], {}))
	_reg(_b("dress",     "Dress",      0.7, 1, false, ["id:torso"], {}))
	_reg(_b("platebody", "Plate Body", 9.0, 0, true,  ["id:torso","glob:upper_arm.*","glob:lower_arm.*"], {}))

	# --- PELVIS/LEGS ---
	_reg(_b("underwear",  "Underwear",  0.2, 1, false, ["id:pelvis"], {"id:pelvis":1}))
	_reg(_b("pants",      "Pants",      0.9, 1, false, ["id:pelvis","glob:upper_leg.*","glob:lower_leg.*"], {"id:pelvis":1,"glob:upper_leg.*":2,"glob:lower_leg.*":2}))
	_reg(_b("platelegs",  "Plate Legs", 7.0, 0, true,  ["id:pelvis","glob:upper_leg.*","glob:lower_leg.*"], {"id:pelvis":1,"glob:upper_leg.*":2,"glob:lower_leg.*":2}))

	# --- HANDS / FEET ---
	_reg(_b("cloth_gloves",   "Cloth Gloves",  0.2, 1, false, ["glob:hand.*"], {"glob:hand.*":2}))
	_reg(_b("leather_gloves", "Leather Gloves",0.5, 2, false, ["glob:hand.*"], {"glob:hand.*":2}))
	_reg(_b("cloth_sock",     "Cloth Sock",    0.1, 1, false, ["glob:foot.*"], {"glob:foot.*":2}))
	_reg(_b("cloth_shoe",     "Cloth Shoe",    0.4, 0, true,  ["glob:foot.*"], {"glob:foot.*":2}))

func get_id(id: StringName) -> EquipmentItem:
	return by_id.get(id, null)

func all_ids() -> Array[StringName]:
	var arr: Array[StringName] = []
	for k in by_id.keys():
		arr.append(k)
	return arr

# --- helpers to build items ---------------------------------------------------

static func _d(id: String, name_: String, mass: float, is_drape: bool, cost: int, kind: String) -> EquipmentItem:
	var it := EquipmentItem.new()
	it.id = StringName(id); it.name = name_; it.mass_kg = mass
	it.is_drape = is_drape; it.drape_cost = cost; it.drape_kind = kind
	return it

static func _b(id: String, name_: String, mass: float, soft_units: int, rigid: bool, coverage: Array[String], fit: Dictionary) -> EquipmentItem:
	var it := EquipmentItem.new()
	it.id = StringName(id); it.name = name_; it.mass_kg = mass
	it.is_drape = false; it.soft_units = soft_units; it.is_rigid = rigid
	it.coverage = coverage.duplicate()
	it.fit_shape = fit.duplicate()
	return it

func _reg(it: EquipmentItem) -> void:
	by_id[it.id] = it
