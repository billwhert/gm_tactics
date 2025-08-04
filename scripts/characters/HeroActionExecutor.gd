# HeroActionExecutor.gd - Executes hero actions with visual feedback
extends Node
class_name HeroActionExecutor

var game_manager: GameManager
var combat_resolver: CombatResolver
var visual_display: VisualRoomDisplay

signal action_completed
signal action_failed(reason: String)

func execute(action: HeroAction):
	match action.type:
		"attack":
			await execute_attack(action)
		"defend":
			await execute_defend(action)
		"move":
			await execute_move(action)
		"heal":
			await execute_heal(action)
		"loot":
			await execute_loot(action)
		"aoe", "fireball", "meteor":
			await execute_aoe(action)
		"inspire", "rally", "bless":
			await execute_buff(action)
		"hide", "vanish":
			await execute_stealth(action)
		"study", "scout":
			await execute_study(action)
		_:
			await execute_special(action)
	
	emit_signal("action_completed")

func execute_attack(action: HeroAction):
	if not action.target or not action.target.is_alive():
		emit_signal("action_failed", "Invalid target")
		return
	
	# Visual: Hero attack animation
	if visual_display:
		visual_display.animate_attack(action.hero, action.target)
	
	# Resolve attack
	var result = combat_resolver.resolve_attack(action.hero, action.target)
	
	if result.hit:
		# Apply damage
		action.target.take_damage(result.damage)
		
		# Visual: Damage number
		if visual_display:
			var target_pos = visual_display.grid_to_world(action.target.grid_position)
			visual_display.show_damage_number(target_pos, result.damage, false)
		
		# Check for additional effects
		if result.crit:
			print("%s CRITS %s for %d damage!" % [action.hero.hero_name, action.target.enemy_name, result.damage])
		else:
			print("%s hits %s for %d damage!" % [action.hero.hero_name, action.target.enemy_name, result.damage])
		
		# Track statistics
		game_manager.achievement_tracker.track_damage(result.damage)
		
		# Check for kill
		if not action.target.is_alive():
			game_manager.achievement_tracker.track_enemy_kill()
	else:
		print("%s misses %s!" % [action.hero.hero_name, action.target.enemy_name])

func execute_defend(action: HeroAction):
	# Apply AC bonus
	action.hero.ac += action.ac_bonus
	action.hero.defending = true
	
	# Store for removal next turn
	action.hero.temp_modifiers["defend_ac"] = action.ac_bonus
	
	# Visual feedback
	if visual_display:
		# Show defend icon/effect
		pass
	
	print("%s takes defensive stance (+%d AC)" % [action.hero.hero_name, action.ac_bonus])

func execute_move(action: HeroAction):
	var start_pos = action.hero.grid_position
	var end_pos = action.target_position
	
	# Check path is clear (basic pathfinding)
	if not action.room.is_walkable(end_pos):
		emit_signal("action_failed", "Can't move there")
		return
	
	# Update position
	action.hero.grid_position = end_pos
	
	# Visual: Movement animation
	if visual_display:
		await visual_display.animate_movement(action.hero, start_pos, end_pos)
	
	print("%s moves to %s" % [action.hero.hero_name, end_pos])

func execute_heal(action: HeroAction):
	if not action.target or not action.target.is_alive():
		emit_signal("action_failed", "Invalid heal target")
		return
	
	# Calculate healing
	var heal_amount = 0
	if action.heal_amount > 0:
		heal_amount = action.heal_amount
	elif action.has("healing_die"):
		heal_amount = Dice.roll(action.healing_die)
		if action.has("healing_bonus"):
			heal_amount += action.healing_bonus
	
	# Apply healing
	action.target.heal(heal_amount)
	
	# Visual: Healing effect
	if visual_display:
		var target_pos = visual_display.grid_to_world(action.target.grid_position)
		visual_display.show_damage_number(target_pos, heal_amount, true)
	
	print("%s heals %s for %d HP" % [action.hero.hero_name, action.target.hero_name, heal_amount])
	
	# Track statistics
	game_manager.achievement_tracker.track_healing(heal_amount)

func execute_loot(action: HeroAction):
	if not action.target:
		emit_signal("action_failed", "No loot target")
		return
	
	# Open chest
	var result = action.target.interact(action.hero)
	
	if result.success:
		if result.has("mimic"):
			# Spawn mimic enemy
			print("It's a mimic!")
			# game_manager.spawn_mimic_at(action.target.grid_position)
		elif result.has("trap_triggered"):
			print("Trap triggered!")
		else:
			# Distribute loot
			for item in result.items:
				print("%s found %s!" % [action.hero.hero_name, item.name])
				# game_manager.add_item_to_party(item)
	else:
		print(result.message)

func execute_aoe(action: HeroAction):
	# Get affected tiles
	var affected_tiles = []
	if action.has("affected_tiles"):
		affected_tiles = action.affected_tiles
	else:
		# Calculate based on radius
		var center = action.target_position if action.has("target_position") else action.hero.grid_position
		affected_tiles = get_tiles_in_radius(center, action.aoe_radius)
	
	# Visual: Highlight affected area
	if visual_display:
		visual_display.highlight_tiles(affected_tiles, Color(1.0, 0.5, 0.0))
		await get_tree().create_timer(0.5).timeout
	
	# Apply to all enemies in area
	var total_damage = 0
	for enemy in action.room.get_alive_enemies():
		if enemy.grid_position in affected_tiles:
			var damage = Dice.roll(action.damage_dice)
			
			# Save for half damage?
			if action.has("save_type"):
				if combat_resolver.resolve_save(enemy, action.save_type, action.save_dc):
					damage /= 2
					print("%s saves!" % enemy.enemy_name)
			
			enemy.take_damage(damage)
			total_damage += damage
			
			if visual_display:
				var pos = visual_display.grid_to_world(enemy.grid_position)
				visual_display.show_damage_number(pos, damage, false)
	
	print("%s's %s deals %d total damage!" % [action.hero.hero_name, action.type, total_damage])
	game_manager.achievement_tracker.track_damage(total_damage)

func execute_buff(action: HeroAction):
	var targets = []
	
	# Determine targets
	if action.has("affects_allies") and action.affects_allies:
		targets = action.room.get_party().filter(func(h): return h.is_alive())
	elif action.has("target"):
		targets = [action.target]
	else:
		targets = [action.hero]
	
	# Apply buffs
	for target in targets:
		if action.has("attack_bonus"):
			target.temp_modifiers["attack"] = action.attack_bonus
		if action.has("ac_bonus"):
			target.ac += action.ac_bonus
		if action.has("temp_hp"):
			target.temp_modifiers["temp_hp"] = action.temp_hp
		
		print("%s is inspired!" % target.hero_name)

func execute_stealth(action: HeroAction):
	action.hero.add_condition("hidden")
	
	if action.has("invisible") and action.invisible:
		action.hero.add_condition("invisible")
		action.hero.temp_modifiers["invisible_duration"] = action.duration
	
	# Visual: Fade effect
	if visual_display:
		var sprite = visual_display.get_sprite_for_unit(action.hero)
		if sprite:
			sprite.modulate.a = 0.5
	
	print("%s vanishes from sight!" % action.hero.hero_name)

func execute_study(action: HeroAction):
	if action.has("target") and action.target:
		# Reveal enemy info
		print("%s studies %s:" % [action.hero.hero_name, action.target.enemy_name])
		print("  HP: %d/%d" % [action.target.current_hp, action.target.max_hp])
		print("  AC: %d" % action.target.ac)
		print("  Damage: %s" % action.target.damage_dice)
		
		if action.has("reveal_weakness") and action.reveal_weakness:
			# Apply vulnerability
			action.target.temp_modifiers["vulnerable"] = true
			print("  Weakness revealed!")
	else:
		# General study effect
		print("%s gains insight!" % action.hero.hero_name)

func execute_special(action: HeroAction):
	# Handle any special/custom actions
	print("%s performs %s!" % [action.hero.hero_name, action.type])
	
	# Apply any generic modifiers
	if action.has("damage_multiplier"):
		action.hero.temp_modifiers["damage_multiplier"] = action.damage_multiplier
	
	# Handle specific special actions
	match action.type:
		"chaos":
			execute_chaos(action)
		"rewind":
			execute_rewind(action)
		"nova":
			execute_nova(action)
		_:
			print("Unknown special action: " + action.type)

func execute_chaos(action: HeroAction):
	# Random effect!
	var effects = ["massive_damage", "party_heal", "summon_ally", "teleport_all", "polymorph_enemy", "time_stop"]
	var chosen = effects[randi() % effects.size()]
	
	print("CHAOS! Effect: " + chosen)
	
	match chosen:
		"massive_damage":
			# Deal big damage to random enemy
			var enemies = action.room.get_alive_enemies()
			if enemies.size() > 0:
				var target = enemies[randi() % enemies.size()]
				var damage = Dice.roll("10d6")
				target.take_damage(damage)
				print("Chaos bolt hits %s for %d!" % [target.enemy_name, damage])
		
		"party_heal":
			# Heal all allies
			for hero in action.room.get_party():
				if hero.is_alive():
					hero.heal(20)
			print("Chaos heals the party!")
		
		"teleport_all":
			# Randomize positions
			print("Everyone teleports randomly!")
			# Implementation would shuffle all positions

func execute_rewind(action: HeroAction):
	# This would need save state implementation
	print("TIME REWINDS! (Not yet implemented)")
	emit_signal("action_failed", "Rewind not implemented yet")

func execute_nova(action: HeroAction):
	# Massive AOE but exhausts hero
	var damage = Dice.roll("12d6")
	
	for enemy in action.room.get_alive_enemies():
		enemy.take_damage(damage)
	
	# Exhaust the hero
	action.hero.add_condition("exhausted")
	action.hero.temp_modifiers["skip_next_turn"] = true
	
	print("%s EXPLODES WITH POWER! %d damage to all!" % [action.hero.hero_name, damage])

func get_tiles_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var offset = Vector2i(x, y)
			if offset.length() <= radius:
				tiles.append(center + offset)
	return tiles
