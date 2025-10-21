class_name UIOverlay
extends Control

@onready var lbl_tick: Label = $VBoxContainer/Tick
@onready var lbl_pos: Label = $VBoxContainer/Pos
@onready var lbl_misc: Label = $VBoxContainer/Misc

func set_debug(tick: int, pos: Vector2i, next_free: int, zoom: float, vis_w: int, vis_h: int) -> void:
	var cols := int(vis_w / zoom)
	var rows := int(vis_h / zoom)
	lbl_tick.text = "Tick: %d" % tick
	lbl_pos.text = "Pos: (%d,%d)" % [pos.x, pos.y]
	lbl_misc.text = "NextFree: %d   Zoom: %.2f   View: %dx%d cells" % [next_free, zoom, cols, rows]
