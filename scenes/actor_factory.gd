class_name ActorFactory
extends RefCounted

static func spawn(actor_id:int, grid_pos:Vector2i, species_id:StringName, is_player:bool) -> Actor:
	var actor: Actor = Actor.new(actor_id, grid_pos, is_player)
	SpeciesDB.apply_to(species_id, actor)
	return actor
