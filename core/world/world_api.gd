# res://world/world_api.gd
class_name WorldAPI
extends Node
## Contract for worlds used by SimCore/SimManager.

func is_passable(_p: Vector2i) -> bool:
	return true

func is_wall(_p: Vector2i) -> bool:
	return false

func glyph(_p: Vector2i) -> String:
	return " "
