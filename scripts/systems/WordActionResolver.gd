# WordActionResolver.gd v2.0 - Complete word resolution with preview
extends Node
class_name WordActionResolver

# =============================================================================
# MAIN RESOLUTION
# =============================================================================

static func resolve_word(hero: Hero, word_id: String, room: Room, game_data: GameData) -> HeroAction:
	var action = HeroAction.new()
	action.hero = hero
	action.word_id = word_id
	action.room = room
	
	# Check for contextual transformation
	var transformed_word = transform_word_for_context(word_id, hero, room)
	if transformed_word != word_id:
		action.transformed_from = word_id
		word_id = transformed_word
	
	# Resolve based on word type
	match word_id:
		# Basic Actions (Always Available)
		"ATTACK":
			return resolve_attack(hero, room, game_data, action)
		"DEFEND":
			return resolve_defend(hero, room, game_data, action)
		"MOVE":
			return resolve_move(hero, room, game_data, action)
		
		# Common Shared Words
		"LOOT":
			return resolve_loot(hero, room, game_data, action)
		"HEAL":
			return resolve_heal(hero, room, game_data, action)
		"INSPIRE":
			return resolve_inspire(hero, room, game_data, action)
		"DASH":
			return resolve_dash(hero, room, game_data, action)
		"STUDY":
			return resolve_study(hero, room, game_data, action)
		"FOCUS":
			return resolve_focus(hero, room, game_data, action)
		"GUARD":
			return resolve_guard(hero, room, game_data, action)
		"TAUNT":
			return resolve_taunt(hero, room, game_data, action)
		"HIDE":
			return resolve_hide(hero, room, game_data, action)
		"SEARCH":
			return resolve_search(hero, room, game_data, action)
		
		# Class Words
		"CLEAVE", "WHIRLWIND", "RALLY", "CHARGE", "CHAMPION":
			return resolve_fighter_word(word_id, hero, room, game_data, action)
		"FIREBALL", "TELEPORT", "METEOR", "SHIELD", "MAGIC_MISSILE":
			return resolve_wizard_word(word_id, hero, room, game_data, action)
		"HEAL_WORD", "SANCTUARY", "DIVINE", "BLESS", "REVIVE":
			return resolve_cleric_word(word_id, hero, room, game_data, action)
		"SNEAK", "VANISH", "ASSASSINATE", "POISON", "SHADOW_CLONE":
			return resolve_rogue_word(word_id, hero, room, game_data, action)
		
		# Special Unlockable Words
		"FLURRY", "REWIND", "CHAOS", "NOVA":
			return resolve_special_word(word_id, hero, room, game_data, action)
		
		_:
			# Unknown word - default to basic attack
			push_warning("Unknown word: " + word_id)
			return resolve_attack(hero, room, game_data, action)

# =============================================================================
# PREVIEW SYSTEM
# =============================================================================

static func get_action_preview(hero: Hero, word: WordCard, room: Room, game_data: GameData) -> Dictionary:
	var preview = {
		"action_type": "",
		"target": null,
		"expected_damage": 0,
		"expected_healing": 0,
		"movement_path": [],
		"affected_tiles": [],
		"description": "",
		"quirk_chance": 0.0,
		"possible_quirk": ""
	}
	
	# Get base action
	var action = resolve_word(hero, word.word, room, game_data)
	
	# Fill preview based on action type
	match action.type:
		"attack":
			preview.action_type = "Attack"
			preview.target = action.target
			preview.expected_damage = calculate_expected_damage(hero, action)
			preview.description = "Attack %s for ~%d damage" % [
				action.target.get_name() if action.target else "nearest enemy",
				preview.expected_damage
			]
			
		"defend":
			preview.action_type = "Defend"
			preview.description = "Gain +%d AC until next turn" % action.ac_bonus
			
		"heal":
			preview.action_type = "Heal"
			preview.target = action.target
			preview.expected_healing = calculate_expected_healing(hero, action)
			preview.description = "Heal %s for ~%d HP" % [
				action.target.hero_name if action.target else "lowest HP ally",
				preview.expected_healing
			]
			
		"move":
			preview.action_type = "Movement"
			preview.movement_path = calculate_movement_path(hero, action.target_position)
			preview.description = "Move to tactical position"
			
		"aoe":
			preview.action_type = "Area Effect"
			preview.affected_tiles = calculate_aoe_tiles(action.target_position, action.aoe_radius)
			preview.expected_damage = calculate_expected_damage(hero, action)
			preview.description = "Deal ~%d damage in area" % preview.expected_damage
	
	# Check quirk probability
	var quirk_data = check_quirk_probability(hero, room.get_context(), word.word)
	preview.quirk_chance = quirk_data.chance
	preview.possible_quirk = quirk_data.description
	
	return preview

# =============================================================================
# CONTEXTUAL TRANSFORMATION
# =============================================================================

static func transform_word_for_context(word: String, hero: Hero, room: Room) -> String:
	var context = room.get_context()
	
	# LOOT transforms when no chests
	if word == "LOOT" and context.get("chest_count", 0) == 0:
		if context.get("enemy_count", 0) > 0:
			return "SCOUT"  # Reveal enemy weaknesses
		else:
			return "SEARCH"  # Look for secrets
	
	# ATTACK transforms when no enemies
	if word == "ATTACK" and context.get("enemy_count", 0) == 0:
		return "TRAIN"  # Practice moves for temp bonus
	
	# HEAL transforms when party at full HP
	if word == "HEAL" and not context.get("party_damaged", false):
		return "BLESS"  # Preventive buff instead
	
	return word

# =============================================================================
# BASIC ACTIONS
# =============================================================================

static func resolve_attack(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "attack"
	
	# Apply subclass modifications
	if hero.subclass == "champion":
		action.crit_range = 19  # Crit on 19-20
	elif hero.subclass == "eldritch_knight":
		action.magical = true
	
	# Target selection based on class
	match hero.class_id:
		"fighter", "barbarian":
			action.target = get_best_melee_target(hero, room)
			action.damage_die = hero.get_weapon_damage_die()
			action.damage_bonus = hero.get_damage_mod()
		
		"wizard", "sorcerer":
			if hero.has_quirk("MELEE_WIZARD"):
				action.target = get_closest_enemy(hero, room)
				action.damage_die = "1d6"  # Staff bonk
			else:
				action.target = get_best_ranged_target(hero, room)
				action.damage_die = "1d10"  # Fire bolt cantrip
				action.magical = true
		
		"rogue":
			var flanking = get_flanking_target(hero, room)
			if flanking:
				action.target = flanking
				action.sneak_attack = true
				action.damage_die = hero.get_weapon_damage_die() + "+3d6"
			else:
				action.target = get_weakest_enemy(hero, room)
				action.damage_die = hero.get_weapon_damage_die()
		
		"cleric":
			action.target = get_closest_enemy(hero, room)
			action.damage_die = hero.get_weapon_damage_die()
			if hero.subclass == "war_domain":
				action.damage_bonus += 2
	
	return action

static func resolve_defend(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "defend"
	action.ac_bonus = 2  # Base +2 AC
	action.duration = 1  # Until next turn
	
	# Class variations
	match hero.class_id:
		"fighter":
			action.ac_bonus = 3
			if hero.subclass == "champion":
				action.counter_chance = 0.25
		
		"rogue":
			action.dodge = true  # Disadvantage on attacks against
		
		"wizard":
			if hero.subclass == "illusion":
				action.type = "mirror_image"
				action.images = 3
		
		"cleric":
			action.ac_bonus = 2
			action.damage_reduction = 2
	
	return action

static func resolve_move(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "move"
	action.movement_range = hero.speed
	
	# Smart positioning based on class
	match hero.class_id:
		"fighter", "barbarian":
			action.target_position = get_frontline_position(hero, room)
		
		"rogue":
			action.target_position = get_flanking_position(hero, room)
		
		"wizard", "cleric":
			action.target_position = get_backline_position(hero, room)
	
	return action

# =============================================================================
# SHARED POOL WORDS (Continued)
# =============================================================================

static func resolve_loot(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "loot"
	
	var context = room.get_context()
	if context.get("chest_count", 0) > 0:
		action.target = get_nearest_chest(hero, room)
		action.loot_bonus = hero.get_skill_mod("investigation")
		
		# Rogue gets advantage on loot rolls
		if hero.class_id == "rogue":
			action.advantage = true
			action.trap_detection = true
	else:
		# Transforms to SCOUT if no chests
		action.type = "scout"
		action.reveal_count = 2 + hero.get_skill_mod("perception")
	
	return action

static func resolve_heal(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "heal"
	
	# Target lowest HP ally
	action.target = get_lowest_hp_ally(hero, room)
	
	if action.target:
		action.healing_die = "2d4"
		action.healing_bonus = hero.get_skill_mod("medicine")
		
		# Class bonuses
		if hero.class_id == "cleric":
			action.healing_die = "2d6"
			action.healing_bonus += hero.get_spell_mod()
		elif hero.has_quirk("BATTLEFIELD_MEDIC"):
			action.healing_bonus += 3
	else:
		# No injured allies - transform to preventive buff
		action.type = "temp_hp"
		action.temp_hp = 5 + hero.level
	
	return action

static func resolve_inspire(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "inspire"
	action.affects_allies = true
	action.radius = 3
	
	# Base effect: +1 to attack rolls for allies
	action.attack_bonus = 1
	action.duration = 2
	
	# Class variations
	match hero.class_id:
		"fighter":
			if hero.subclass == "champion":
				action.attack_bonus = 2
				action.damage_bonus = 2
		
		"cleric":
			action.saves_bonus = 2
			action.fear_immunity = true
		
		"wizard":
			action.spell_dc_bonus = 1
			action.concentration_bonus = 2
		
		"rogue":
			action.initiative_bonus = 3
			action.speed_bonus = 10
	
	return action

static func resolve_dash(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "dash"
	action.movement_range = hero.speed * 2
	
	# Rogue gets cunning action dash
	if hero.class_id == "rogue":
		action.bonus_action = true
		action.disengage = true  # No opportunity attacks
		
		if hero.subclass == "swashbuckler":
			action.movement_range = hero.speed * 3
	
	# Fighter action surge dash
	elif hero.class_id == "fighter" and hero.has_resource("action_surge"):
		action.additional_action = true
	
	return action

static func resolve_study(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "study"
	
	# Wizard gets the most benefit
	if hero.class_id == "wizard":
		action.spell_slot_recovery = 1
		action.knowledge_gained = true
		
		if hero.subclass == "divination":
			action.portent_die = roll_d20()  # Store for later use
	else:
		# Other classes gain insight
		action.target = get_strongest_enemy(hero, room)
		if action.target:
			action.reveal_weakness = true
			action.vulnerability_check = true
	
	return action

static func resolve_focus(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "focus"
	action.duration = 3
	
	# Base effect: Advantage on next ability
	action.advantage_next = true
	
	# Class specific focus benefits
	match hero.class_id:
		"wizard":
			action.spell_save_dc_bonus = 2
			action.concentration_auto_success = true
		
		"fighter":
			action.crit_range_bonus = 1  # Crit on 19-20
			action.damage_reroll = true
		
		"rogue":
			action.stealth_bonus = 5
			action.guaranteed_sneak_attack = true
		
		"cleric":
			action.channel_divinity_recharge = true
			action.healing_maximized = true
	
	return action

static func resolve_guard(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "guard"
	
	# Select ally to protect
	action.target = get_most_vulnerable_ally(hero, room)
	
	if action.target:
		action.redirect_damage = true
		action.damage_reduction = 2
		
		if hero.class_id == "fighter":
			action.damage_reduction = 4
			if hero.subclass == "protector":
				action.counter_on_redirect = true
	
	return action

static func resolve_taunt(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "taunt"
	action.radius = 3
	
	# Force enemies to target the taunter
	action.forced_target = hero
	action.duration = 2
	
	# Fighter gets better taunts
	if hero.class_id == "fighter":
		action.radius = 5
		action.ac_bonus = 1  # Defensive stance while taunting
		
		if hero.has_quirk("INTIMIDATING"):
			action.fear_chance = 0.25
	
	return action

static func resolve_hide(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "hide"
	
	# Rogue is best at hiding
	if hero.class_id == "rogue":
		action.stealth_check = hero.get_skill_mod("stealth") + 10
		action.hidden = true
		action.next_attack_advantage = true
		
		if hero.subclass == "assassin":
			action.assassinate_ready = true
	else:
		action.stealth_check = hero.get_skill_mod("stealth")
		action.partial_concealment = true
	
	return action

static func resolve_search(hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	action.type = "search"
	
	var perception = hero.get_skill_mod("perception")
	var investigation = hero.get_skill_mod("investigation")
	
	action.search_bonus = max(perception, investigation)
	
	# Rogue finds traps and secret doors
	if hero.class_id == "rogue":
		action.trap_detection = true
		action.secret_detection = true
		action.search_bonus += 5
	
	# Wizard finds magical secrets
	elif hero.class_id == "wizard":
		action.magic_detection = true
		action.arcana_check = hero.get_skill_mod("arcana")
	
	return action

# =============================================================================
# CLASS-SPECIFIC WORDS
# =============================================================================

static func resolve_fighter_word(word: String, hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	match word:
		"CLEAVE":
			action.type = "cleave"
			action.targets = get_adjacent_enemies(hero, room, 2)
			action.damage_die = hero.get_weapon_damage_die()
			action.damage_bonus = hero.get_damage_mod()
			
		"WHIRLWIND":
			action.type = "whirlwind"
			action.targets = get_all_adjacent_enemies(hero, room)
			action.damage_die = hero.get_weapon_damage_die()
			action.damage_reduction = 2  # Slightly less damage to all
			
		"RALLY":
			action.type = "rally"
			action.affects_allies = true
			action.temp_hp = hero.level + hero.get_mod("charisma")
			action.fear_removal = true
			
		"CHARGE":
			action.type = "charge"
			action.movement_required = true
			action.target = get_furthest_enemy(hero, room)
			action.damage_die = hero.get_weapon_damage_die() + "+1d6"
			action.knockback = true
			
		"CHAMPION":
			action.type = "champion_stance"
			action.self_buff = true
			action.crit_range = 18  # Crit on 18-20
			action.damage_bonus = 3
			action.duration = 5
	
	return action

static func resolve_wizard_word(word: String, hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	match word:
		"FIREBALL":
			action.type = "fireball"
			action.aoe = true
			action.radius = 3
			action.damage_die = "8d6"
			action.magical = true
			action.save_type = "dexterity"
			action.save_dc = hero.get_spell_dc()
			
		"TELEPORT":
			action.type = "teleport"
			action.range = 30
			action.bonus_action = true
			if hero.subclass == "conjuration":
				action.allies_can_follow = true
			
		"METEOR":
			action.type = "meteor"
			action.aoe = true
			action.radius = 4
			action.damage_die = "10d6"
			action.bludgeoning = true
			action.fire = true
			action.delay = 1  # Hits next turn
			
		"SHIELD":
			action.type = "shield"
			action.reaction = true
			action.ac_bonus = 5
			action.magic_missile_immunity = true
			
		"MAGIC_MISSILE":
			action.type = "magic_missile"
			action.auto_hit = true
			action.missiles = 3 + hero.level / 2
			action.damage_per_missile = "1d4+1"
			action.force_damage = true
	
	return action

static func resolve_cleric_word(word: String, hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	match word:
		"HEAL_WORD":
			action.type = "healing_word"
			action.bonus_action = true
			action.range = 30
			action.healing_die = "1d4"
			action.healing_bonus = hero.get_spell_mod()
			
		"SANCTUARY":
			action.type = "sanctuary"
			action.target = get_most_vulnerable_ally(hero, room)
			action.protection = true
			action.wisdom_save_to_attack = true
			action.save_dc = hero.get_spell_dc()
			
		"DIVINE":
			action.type = "divine_strike"
			action.damage_die = hero.get_weapon_damage_die() + "+2d8"
			action.radiant_damage = true
			action.undead_extra_damage = "2d8"
			
		"BLESS":
			action.type = "bless"
			action.targets = get_allies_in_range(hero, room, 3)
			action.attack_bonus_die = "1d4"
			action.save_bonus_die = "1d4"
			action.duration = 10
			
		"REVIVE":
			action.type = "revive"
			action.target = get_downed_ally(hero, room)
			if action.target:
				action.healing = 1  # Stabilize at 1 HP
				action.remove_conditions = true
			else:
				# No one to revive - mass healing instead
				action.type = "mass_heal"
				action.healing_die = "3d8"
				action.affects_all_allies = true
	
	return action

static func resolve_rogue_word(word: String, hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	match word:
		"SNEAK":
			action.type = "sneak_attack"
			action.target = get_advantageous_target(hero, room)
			action.damage_die = hero.get_weapon_damage_die() + "+5d6"
			action.advantage = true
			
		"VANISH":
			action.type = "vanish"
			action.invisible = true
			action.duration = 3
			action.movement_bonus = 10
			action.next_attack_crit = hero.subclass == "assassin"
			
		"ASSASSINATE":
			action.type = "assassinate"
			action.target = get_priority_target(hero, room)
			action.auto_crit = true
			action.damage_die = hero.get_weapon_damage_die() + "+10d6"
			action.death_save_dc = 15 + hero.level
			
		"POISON":
			action.type = "poison_blade"
			action.damage_die = hero.get_weapon_damage_die()
			action.poison_damage = "2d6"
			action.poison_duration = 5
			action.constitution_save = hero.get_spell_dc()
			
		"SHADOW_CLONE":
			action.type = "shadow_clone"
			action.creates_illusion = true
			action.clone_hp = hero.level * 5
			action.clone_attacks = true
			action.duration = 5
	
	return action

# =============================================================================
# SPECIAL UNLOCKABLE WORDS
# =============================================================================

static func resolve_special_word(word: String, hero: Hero, room: Room, game_data: GameData, action: HeroAction) -> HeroAction:
	match word:
		"FLURRY":
			action.type = "flurry"
			action.attacks = 4
			action.damage_die = hero.get_weapon_damage_die()
			action.damage_reduction_per_hit = 2
			
		"REWIND":
			action.type = "rewind"
			action.undo_last_turn = true
			action.restore_resources = true
			action.one_use_per_adventure = true
			
		"CHAOS":
			action.type = "chaos"
			action.random_effect = true
			action.possible_effects = [
				"massive_damage", "party_heal", "summon_ally",
				"teleport_all", "polymorph_enemy", "time_stop"
			]
			
		"NOVA":
			action.type = "nova"
			action.aoe = true
			action.radius = 6
			action.damage_die = "12d6"
			action.exhaustion_after = true
	
	return action

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_best_melee_target(hero: Hero, room: Room) -> Enemy:
	var enemies = room.get_enemies_in_range(hero.position, hero.melee_range)
	if enemies.is_empty():
		return null
	
	# Prioritize low HP enemies fighter can finish
	enemies.sort_custom(func(a, b): return a.current_hp < b.current_hp)
	return enemies[0]

static func get_best_ranged_target(hero: Hero, room: Room) -> Enemy:
	var enemies = room.get_all_enemies()
	if enemies.is_empty():
		return null
	
	# Prioritize casters and ranged enemies
	for enemy in enemies:
		if enemy.is_caster or enemy.is_ranged:
			return enemy
	
	return enemies[0]

static func get_flanking_target(hero: Hero, room: Room) -> Enemy:
	var enemies = room.get_all_enemies()
	for enemy in enemies:
		if is_flanking(hero, enemy, room):
			return enemy
	return null

static func is_flanking(hero: Hero, enemy: Enemy, room: Room) -> bool:
	# Check if any ally is on opposite side of enemy
	for ally in room.get_allies():
		if ally == hero:
			continue
		var angle = hero.position.angle_to_point(enemy.position)
		var ally_angle = ally.position.angle_to_point(enemy.position)
		if abs(angle - ally_angle) > PI * 0.75:  # Roughly opposite sides
			return true
	return false

static func get_weakest_enemy(hero: Hero, room: Room) -> Enemy:
	var enemies = room.get_all_enemies()
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): return a.current_hp < b.current_hp)
	return enemies[0]

static func get_strongest_enemy(hero: Hero, room: Room) -> Enemy:
	var enemies = room.get_all_enemies()
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): return a.current_hp > b.current_hp)
	return enemies[0]

static func get_closest_enemy(hero: Hero, room: Room) -> Enemy:
	var enemies = room.get_all_enemies()
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): 
		return hero.position.distance_to(a.position) < hero.position.distance_to(b.position)
	)
	return enemies[0]

static func get_furthest_enemy(hero: Hero, room: Room) -> Enemy:
	var enemies = room.get_all_enemies()
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): 
		return hero.position.distance_to(a.position) > hero.position.distance_to(b.position)
	)
	return enemies[0]

static func get_adjacent_enemies(hero: Hero, room: Room, max_count: int) -> Array:
	var enemies = room.get_enemies_in_range(hero.position, 1.5)  # Adjacent
	if enemies.size() > max_count:
		enemies.resize(max_count)
	return enemies

static func get_all_adjacent_enemies(hero: Hero, room: Room) -> Array:
	return room.get_enemies_in_range(hero.position, 1.5)

static func get_lowest_hp_ally(hero: Hero, room: Room) -> Hero:
	var allies = room.get_allies()
	var lowest = null
	var lowest_percent = 1.0
	
	for ally in allies:
		var percent = float(ally.current_hp) / float(ally.max_hp)
		if percent < lowest_percent and percent < 1.0:
			lowest = ally
			lowest_percent = percent
	
	return lowest

static func get_most_vulnerable_ally(hero: Hero, room: Room) -> Hero:
	var allies = room.get_allies()
	if allies.is_empty():
		return null
	
	# Priority: Low HP > Casters > Low AC
	allies.sort_custom(func(a, b):
		var a_score = (float(a.current_hp) / float(a.max_hp)) * 100
		var b_score = (float(b.current_hp) / float(b.max_hp)) * 100
		
		if a.class_id in ["wizard", "sorcerer"]:
			a_score -= 20
		if b.class_id in ["wizard", "sorcerer"]:
			b_score -= 20
		
		return a_score < b_score
	)
	
	return allies[0]

static func get_allies_in_range(hero: Hero, room: Room, range: float) -> Array:
	return room.get_allies_in_range(hero.position, range)

static func get_downed_ally(hero: Hero, room: Room) -> Hero:
	for ally in room.get_allies():
		if ally.is_downed:
			return ally
	return null

static func get_advantageous_target(hero: Hero, room: Room) -> Enemy:
	# Look for isolated, flanked, or status-affected enemies
	var enemies = room.get_all_enemies()
	
	for enemy in enemies:
		if enemy.has_condition("stunned") or enemy.has_condition("paralyzed"):
			return enemy
	
	for enemy in enemies:
		if is_flanking(hero, enemy, room):
			return enemy
	
	return get_weakest_enemy(hero, room)

static func get_priority_target(hero: Hero, room: Room) -> Enemy:
	var enemies = room.get_all_enemies()
	
	# Priority: Healers > Casters > Ranged > Melee
	for enemy in enemies:
		if enemy.can_heal:
			return enemy
	
	for enemy in enemies:
		if enemy.is_caster:
			return enemy
	
	for enemy in enemies:
		if enemy.is_ranged:
			return enemy
	
	return get_strongest_enemy(hero, room)

static func get_nearest_chest(hero: Hero, room: Room) -> Interactable:
	var chests = room.get_all_chests()
	if chests.is_empty():
		return null
	
	chests.sort_custom(func(a, b):
		return hero.position.distance_to(a.position) < hero.position.distance_to(b.position)
	)
	
	return chests[0]

static func get_frontline_position(hero: Hero, room: Room) -> Vector2:
	# Move toward enemies but maintain formation
	var enemies = room.get_all_enemies()
	if enemies.is_empty():
		return hero.position
	
	var center = Vector2.ZERO
	for enemy in enemies:
		center += enemy.position
	center /= enemies.size()
	
	# Move toward enemy center but not too close
	var direction = (center - hero.position).normalized()
	return hero.position + direction * min(hero.speed, hero.position.distance_to(center) - 2)

static func get_backline_position(hero: Hero, room: Room) -> Vector2:
	# Stay back but in range
	var enemies = room.get_all_enemies()
	if enemies.is_empty():
		return hero.position
	
	var threat_center = Vector2.ZERO
	for enemy in enemies:
		threat_center += enemy.position
	threat_center /= enemies.size()
	
	# Move away from threats but stay in spell range
	var direction = (hero.position - threat_center).normalized()
	var ideal_distance = 25.0  # Typical spell range
	
	if hero.position.distance_to(threat_center) < ideal_distance:
		return hero.position + direction * hero.speed
	
	return hero.position

static func get_flanking_position(hero: Hero, room: Room) -> Vector2:
	var enemy = get_flanking_target(hero, room)
	if not enemy:
		enemy = get_closest_enemy(hero, room)
	
	if not enemy:
		return hero.position
	
	# Try to get behind the enemy
	var allies = room.get_allies()
	for ally in allies:
		if ally == hero:
			continue
		
		# Move to opposite side of ally
		var opposite = enemy.position + (enemy.position - ally.position).normalized() * 2
		if hero.position.distance_to(opposite) <= hero.speed:
			return opposite
	
	return hero.position

# =============================================================================
# CALCULATION HELPERS
# =============================================================================

static func calculate_expected_damage(hero: Hero, action: HeroAction) -> int:
	var base_damage = 0
	
	# Parse damage die (e.g., "2d6+3")
	if action.has("damage_die"):
		base_damage = parse_average_damage(action.damage_die)
	
	if action.has("damage_bonus"):
		base_damage += action.damage_bonus
	
	# Account for crit chance
	var crit_chance = 0.05  # Base 5%
	if action.has("crit_range"):
		crit_chance = (21 - action.crit_range) * 0.05
	
	base_damage *= (1.0 + crit_chance)  # Simple crit calculation
	
	return int(base_damage)

static func calculate_expected_healing(hero: Hero, action: HeroAction) -> int:
	var base_healing = 0
	
	if action.has("healing_die"):
		base_healing = parse_average_damage(action.healing_die)
	
	if action.has("healing_bonus"):
		base_healing += action.healing_bonus
	
	return int(base_healing)

static func parse_average_damage(die_string: String) -> float:
	# Parse strings like "2d6+3" or "1d8"
	var parts = die_string.split("+")
	var dice_part = parts[0]
	var bonus = 0
	
	if parts.size() > 1:
		bonus = int(parts[1])
	
	var dice_split = dice_part.split("d")
	if dice_split.size() != 2:
		return 0
	
	var num_dice = int(dice_split[0])
	var die_size = int(dice_split[1])
	
	# Average roll is (die_size + 1) / 2
	var average_roll = (die_size + 1) * 0.5
	
	return num_dice * average_roll + bonus

static func calculate_movement_path(hero: Hero, target: Vector2) -> Array:
	# Simple pathfinding - would be replaced with A* in real implementation
	var path = []
	var current = hero.position
	var step = hero.speed / 5.0  # 5 segments
	
	for i in range(5):
		var t = (i + 1) / 5.0
		path.append(current.lerp(target, t))
	
	return path

static func calculate_aoe_tiles(center: Vector2, radius: float) -> Array:
	var tiles = []
	var grid_size = 5  # 5-foot squares
	
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var tile_pos = center + Vector2(x * grid_size, y * grid_size)
			if tile_pos.distance_to(center) <= radius * grid_size:
				tiles.append(tile_pos)
	
	return tiles

static func check_quirk_probability(hero: Hero, context: Dictionary, word: String) -> Dictionary:
	var result = {
		"chance": 0.0,
		"description": ""
	}
	
	# Check for quirk triggers
	for quirk in hero.quirks:
		match quirk:
			"COWARD":
				if context.get("enemy_count", 0) > 3:
					result.chance = 0.3
					result.description = "Might flee instead!"
			
			"BERSERKER":
				if hero.current_hp < hero.max_hp * 0.5:
					result.chance = 0.4
					result.description = "Might go berserk!"
			
			"KLEPTOMANIAC":
				if word == "LOOT":
					result.chance = 0.25
					result.description = "Might grab extra loot!"
			
			"PYROMANIAC":
				if word in ["FIREBALL", "METEOR"]:
					result.chance = 0.5
					result.description = "Double damage but might hit allies!"
	
	return result

static func roll_d20() -> int:
	return randi_range(1, 20)
