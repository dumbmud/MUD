# res://scenes/game_boot.gd
extends Node
class_name GameBoot
##
## Bootstrap wiring:
## - Registers SimManager with GameLoop.
## - Creates player + simple NPCs and attaches controllers.
## - Injects the WorldTest into the scheduler.
## - Scheduler remains pure and mode-agnostic.

func _ready() -> void:
	var sim := $SimCore as SimManager
	var world := $SimCore/WorldTest as WorldAPI

	if sim != null and world != null:
		sim.set_world(world)

	GameLoop.register_sim(sim)

	# Player
	var player := ActorFactory.spawn(0, Vector2i.ZERO, &"human", true)
	var pc := PlayerController.new()
	sim.add_actor(player, pc)
	InputManager.set_player_controller(pc)  # also registers controller with GameLoop

	# Debug NPCs
	_spawn_npc(sim, 1, &"goblin", Vector2i(-15, -8), Vector2i(1, 0))
	_spawn_npc(sim, 2, &"goblin", Vector2i(-18, 0),  Vector2i(1, 0))

func _spawn_npc(sim: SimManager, id: int, species: StringName, pos: Vector2i, dir: Vector2i) -> void:
	var a := ActorFactory.spawn(id, pos, species, false)
	var ai := AIPatrolController.new()
	ai.set_initial_dir(dir)
	sim.add_actor(a, ai)
