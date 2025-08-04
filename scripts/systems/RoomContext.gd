# RoomContext.gd
extends Resource
class_name RoomContext

static func get_context(room: Room, party: Array[Hero]) -> Dictionary:
	var context = {}
	
	# Count enemies
	context["enemy_count"] = room.enemies.filter(func(e): return e.is_alive()).size()
	
	# Count chests/interactables
	context["chest_count"] = room.interactables.filter(func(i): return i.type == "chest").size()
	
	# Check if party is damaged
	context["party_damaged"] = party.any(func(h): return h.is_alive() and h.current_hp < h.max_hp)
	
	# Check for specific enemy types
	context["has_caster"] = room.enemies.any(func(e): return e.has_tag("caster"))
	context["has_heavy"] = room.enemies.any(func(e): return e.has_tag("heavy"))
	
	return context
