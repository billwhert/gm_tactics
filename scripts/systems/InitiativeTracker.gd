# InitiativeTracker.gd - Manages turn order based on word assignments
extends Node
class_name InitiativeTracker

var action_queue: Array = []
var current_index: int = 0

signal action_ready(action: Dictionary)

func reset_turn():
	action_queue.clear()
	current_index = 0

func add_hero_action(hero: Hero, word: WordCard, order: int):
	action_queue.append({
		"type": "hero",
		"actor": hero,
		"word": word,
		"order": order,
		"initiative": hero.initiative_mod
	})

func add_enemy_actions(enemies: Array):
	for enemy in enemies:
		if enemy.is_alive():
			action_queue.append({
				"type": "enemy",
				"actor": enemy,
				"initiative": enemy.initiative or 0
			})
	
	# Sort by order (heroes) then initiative
	action_queue.sort_custom(_sort_actions)

func _sort_actions(a: Dictionary, b: Dictionary) -> bool:
	# Heroes act in assignment order
	if a.type == "hero" and b.type == "hero":
		return a.order < b.order
	# Heroes before enemies
	elif a.type == "hero" and b.type == "enemy":
		return true
	elif a.type == "enemy" and b.type == "hero":
		return false
	# Enemies by initiative
	else:
		return a.initiative > b.initiative

func has_actions_remaining() -> bool:
	return current_index < action_queue.size()

func get_next_action() -> Dictionary:
	if not has_actions_remaining():
		return {}
	
	var action = action_queue[current_index]
	current_index += 1
	emit_signal("action_ready", action)
	return action

func peek_next_action() -> Dictionary:
	if not has_actions_remaining():
		return {}
	return action_queue[current_index]

func get_remaining_actions() -> Array:
	return action_queue.slice(current_index)
