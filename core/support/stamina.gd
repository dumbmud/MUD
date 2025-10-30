class_name StaminaUtil
extends RefCounted

static func val(a: Actor) -> float:
	return float(a.stamina.get("value", 0.0))

static func max(a: Actor) -> float:
	return float(a.stamina.get("max", 100.0))

static func add(a: Actor, delta: float) -> void:
	var st: Dictionary = a.stamina
	st["value"] = clampf(float(st.get("value", 0.0)) + delta, 0.0, float(st.get("max", 100.0)))
	a.stamina = st

static func can_pay(a: Actor, cost: float) -> bool:
	return val(a) >= cost

static func pay(a: Actor, cost: float) -> bool:
	if !can_pay(a, cost): return false
	add(a, -cost)
	return true
