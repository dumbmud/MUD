# res://core/world/world_api.gd
class_name WorldAPI
extends Node
## Contract for worlds used by SimCore/SimManager.

func is_passable(_p: Vector2i) -> bool:
	return true

func is_wall(_p: Vector2i) -> bool:
	return false

func glyph(_p: Vector2i) -> String:
	return " "

## Survival/environment snapshot for a grid cell.
## Keys:
## - medium: one of &"air"|&"water"|&"vacuum"|&"substrate"
## - gas: Dictionary of gas fractions by name, e.g., {&"oxygen": 0.21}
## - temp_C: ambient temperature in Celsius
## - humidity: 0.0..1.0
## - water_available: bool, whether drinking is possible here without an item
func environment_at(_p: Vector2i) -> Dictionary:
	return {
		"medium": &"air",
		"gas": {&"oxygen": 0.21},
		"temp_C": 21.0,
		"humidity": 0.5,
		"water_available": false
	}
