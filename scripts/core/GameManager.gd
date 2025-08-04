# GameManager.gd v2.0 - Complete implementation with all systems
extends Node2D
class_name GameManager

# Signals
signal turn_started(available_words: Dictionary)
signal word_preview_requested(hero: Hero, word: WordCard)
signal resolution_phase
signal room_cleared
signal rest_started
signal dungeon_complete
signal quirk_triggered(hero: Hero, message: String)

# Constants
const ROOMS_PER_DUNGEON_MIN = 14
const ROOMS_PER_DUNGEON_MAX = 17
const SHORT_RESTS_PER_RUN = 2
const QUIRK_CHANCE_NORMAL = 0.2  # 20% chance
const QUIRK_CHANCE_BOSS = 0.1    # 10% for boss fights

# Core Systems
var game_data: GameData
var word_system: HybridWordSystem
var camp_system: CampWordSystem
var momentum_system: MomentumSystem
var initiative_tracker: InitiativeTracker
var combat_resolver: CombatResolver
var save_system: SaveSystem
var achievement_tracker: AchievementTracker

# Game State
var current_room: Room
var party: Array[Hero] = []
var party_gold: int = 100
var turn_count: int = 0
var room_count: int = 0
var short_rests_remaining: int = SHORT_RESTS_PER_RUN
var dungeon_tier: int = 1
var starting_perk: Dictionary = {}

# Dungeon
var dungeon_layout: Array[Dictionary] = []
var current_room_index: int = 0
var dungeon_modifier: String = ""  # Cursed, Wealthy, Chaotic, etc.
var boss_defeated: bool = false

func _ready():
	initialize_systems()
	load_game_data()
	
	# Connect UI elements if they exist
	var start_button = get_node_or_null("UI/MainUI/StartButton")
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	
	# Set up test party for now
	var test_setup = preload("res://scripts/TestGameSetup.gd").new()
	test_setup.setup_test_game(self)

func initialize_systems():
	game_data = GameData.new()
	word_system = HybridWordSystem.new()
	camp_system = CampWordSystem.new()
	momentum_system = MomentumSystem.new()
	initiative_tracker = InitiativeTracker.new()
	combat_resolver = CombatResolver.new()
	save_system = SaveSystem.new()
	achievement_tracker = AchievementTracker.new()
	
	# Connect signals
	word_system.word_assigned.connect(_on_word_assigned)
	momentum_system.combo_achieved.connect(_on_combo_achieved)
	camp_system.camp_word_executed.connect(_on_camp_word_executed)
	achievement_tracker.achievement_unlocked.connect(_on_achievement_unlocked)

func load_game_data():
	game_data.load_all_data()
	CombatResolver.game_data = game_data
	
	# Load saved progress if exists
	if save_system.has_save_file():
		save_system.load_game()

# =============================================================================
# DUNGEON GENERATION
# =============================================================================

func start_new_adventure(p_tier: int = 1, p_modifier: String = ""):
	dungeon_tier = p_tier
	dungeon_modifier = p_modifier
	
	# Generate dungeon
	var num_rooms = randi_range(ROOMS_PER_DUNGEON_MIN, ROOMS_PER_DUNGEON_MAX)
	dungeon_layout = generate_dungeon_layout(num_rooms)
	
	# Reset state
	current_room_index = 0
	room_count = 0
	turn_count = 0
	short_rests_remaining = SHORT_RESTS_PER_RUN
	boss_defeated = false
	
	# Apply dungeon modifier
	apply_dungeon_modifier()
	
	# Enter start room
	enter_start_room()

func generate_dungeon_layout(num_rooms: int) -> Array[Dictionary]:
	var layout = []
	
	# Room 0: Start room
	layout.append({
		"type": "start",
		"cr": 0,
		"description": "Dungeon Entrance"
	})
	
	# Guaranteed rooms
	var guaranteed_elite = randi_range(3, num_rooms/2)
	var guaranteed_rest_1 = randi_range(4, num_rooms/3)
	var guaranteed_rest_2 = randi_range(num_rooms/2, 2*num_rooms/3)
	var mini_boss_room = randi_range(num_rooms/2, 3*num_rooms/4) if randf() < 0.5 else -1
	
	# Generate rooms
	for i in range(1, num_rooms - 1):
		var room_type = ""
		
		if i == guaranteed_elite:
			room_type = "elite"
		elif i == guaranteed_rest_1 or i == guaranteed_rest_2:
			room_type = "rest"
		elif i == mini_boss_room:
			room_type = "mini_boss"
		else:
			room_type = roll_room_type()
		
		layout.append({
			"type": room_type,
			"cr": calculate_room_cr(room_type),
			"description": get_room_description(room_type),
			"revealed": false
		})
	
	# Final room: Boss
	layout.append({
		"type": "boss",
		"cr": dungeon_tier + 2,
		"description": "Boss Chamber",
		"revealed": true  # Boss always visible
	})
	
	# Add secret rooms
	if randf() < 0.3:  # 30% chance
		var secret_index = randi_range(2, num_rooms - 2)
		layout[secret_index]["has_secret"] = true
	
	return layout

func roll_room_type() -> String:
	var weights = {
		"combat": 40,
		"elite": 10,
		"trap": 10,
		"loot": 10,
		"event": 10,
		"rest": 5
	}
	
	if dungeon_modifier == "wealthy":
		weights["loot"] = 20
	elif dungeon_modifier == "cursed":
		weights["trap"] = 20
	
	return weighted_random_choice(weights)

func calculate_room_cr(room_type: String) -> int:
	var base_cr = dungeon_tier
	
	match room_type:
		"elite", "mini_boss":
			return base_cr + 1
		"boss":
			return base_cr + 2
		"combat", "trap":
			return base_cr
		_:
			return 0

# =============================================================================
# ROOM ENTRY
# =============================================================================

func enter_start_room():
	var perks = [
		{
			"name": "Power",
			"description": "+10% damage this run",
			"effect": "damage_boost",
			"value": 0.1
		},
		{
			"name": "Defense",
			"description": "+1 AC all heroes",
			"effect": "ac_boost",
			"value": 1
		},
		{
			"name": "Utility",
			"description": "3 bonus camp words",
			"effect": "extra_camp_words",
			"value": 3
		}
	]
	
	# Show perk selection UI
	show_perk_selection(perks)

func apply_starting_perk(perk: Dictionary):
	starting_perk = perk
	
	match perk.effect:
		"damage_boost":
			for hero in party:
				hero.temp_modifiers["damage_percent"] = perk.value
		"ac_boost":
			for hero in party:
				hero.ac += perk.value
		"extra_camp_words":
			camp_system.bonus_camp_words = perk.value
	
	print("Applied perk: %s" % perk.name)
	advance_to_next_room()

func advance_to_next_room():
	current_room_index += 1
	
	if current_room_index >= dungeon_layout.size():
		complete_dungeon()
		return
	
	var room_data = dungeon_layout[current_room_index]
	room_data.revealed = true
	
	# Reveal next 2-3 rooms if WATCH was used
	reveal_upcoming_rooms(2)
	
	match room_data.type:
		"combat", "elite", "trap", "mini_boss", "boss":
			enter_combat_room(room_data)
		"loot":
			enter_loot_room()
		"rest":
			enter_rest_room()
		"event":
			enter_event_room()

func enter_combat_room(room_data: Dictionary):
	room_count += 1
	
	# Create room
	current_room = Room.new()
	current_room.room_type = room_data.type
	current_room.cr_level = room_data.cr
	
	# Generate with trap hazards if trap room
	if room_data.type == "trap":
		current_room.add_trap_hazards()
	
	# Generate enemies
	current_room.generate(room_count, room_data.cr, true)
	current_room.set_party(party)
	
	# Apply camp buffs
	for hero in party:
		camp_system.apply_camp_buffs_to_combat(hero)
	
	# Position heroes
	position_heroes_at_spawn()
	
	# Display
	display_room()
	
	# Start combat
	start_combat_turn()

# =============================================================================
# COMBAT SYSTEM
# =============================================================================

func start_combat_turn():
	turn_count += 1
	initiative_tracker.reset_turn()
	
	# Build available words for UI
	var available_words = {}
	
	# Get each hero's personal words
	for hero in get_alive_heroes():
		available_words[hero] = word_system.get_available_words_for_hero(hero)
	
	# Draw shared pool
	word_system.draw_shared_pool(get_alive_heroes().size(), get_party_avg_level())
	available_words["shared_pool"] = word_system.shared_pool_available
	
	# Include room context for UI hints
	available_words["context"] = current_room.get_context()
	available_words["context"]["boss_fight"] = current_room.room_type == "boss"
	
	emit_signal("turn_started", available_words)

func preview_word_action(hero: Hero, word: WordCard):
	# Generate preview of what will happen
	var preview = WordActionResolver.get_action_preview(hero, word, current_room, game_data)
	emit_signal("word_preview_requested", hero, word)
	return preview

func confirm_turn(assignments: Dictionary):
	# Validate all assignments
	for hero in assignments:
		var word = assignments[hero]
		if not word_system.can_hero_use_word(hero, word):
			push_error("Invalid word assignment for %s" % hero.hero_name)
			return
	
	# Process assignments
	var order = 1
	for hero in assignments:
		var word = assignments[hero]
		
		# Assign word through system
		word_system.assign_word_to_hero(hero, word)
		
		# Add to initiative
		initiative_tracker.add_hero_action(hero, word, order)
		
		# Track for momentum
		momentum_system.track_word_use(hero, word.word)
		
		order += 1
	
	# Add enemy actions
	initiative_tracker.add_enemy_actions(current_room.get_alive_enemies())
	
	# Resolve turn
	resolve_turn()

func resolve_turn():
	emit_signal("resolution_phase")
	
	while initiative_tracker.has_actions_remaining():
		var action = initiative_tracker.get_next_action()
		
		if action.type == "hero":
			await resolve_hero_action(action.actor, action.word)
		else:
			await resolve_enemy_action(action.actor)
		
		await get_tree().create_timer(0.2).timeout
	
	# End of round
	process_end_of_round()

func resolve_hero_action(hero: Hero, word: WordCard):
	# Get base action
	var action = WordActionResolver.resolve_word(hero, word.word, current_room, game_data)
	
	# Apply momentum
	var momentum_mult = momentum_system.get_total_multiplier(hero, word.word)
	action.apply_momentum(momentum_mult)
	
	# Check for quirk override
	var quirk_chance = QUIRK_CHANCE_BOSS if current_room.room_type == "boss" else QUIRK_CHANCE_NORMAL
	
	if randf() < quirk_chance:
		var context = current_room.get_context()
		var quirk_result = HeroQuirks.check_quirk_trigger(hero, context, word.word)
		
		if quirk_result.triggered:
			emit_signal("quirk_triggered", hero, quirk_result.message)
			HeroQuirks.apply_quirk_to_action(action, quirk_result)
			
			# Track for achievements
			achievement_tracker.track_quirk_trigger(hero, quirk_result.action)
	
	# Execute action
	await execute_hero_action(action)

func execute_hero_action(action: HeroAction):
	# This would connect to the visual system
	var executor = HeroActionExecutor.new()
	executor.game_manager = self
	executor.combat_resolver = combat_resolver
	await executor.execute(action)
	
	# Track statistics
	track_action_statistics(action)

func resolve_enemy_action(enemy: Enemy):
	var ai = EnemyAI.new()
	ai.room = current_room
	ai.party = party
	
	var action = ai.get_enemy_action(enemy)
	await execute_enemy_action(enemy, action)

func process_end_of_round():
	# Process conditions and effects
	combat_resolver.process_end_of_round(party + current_room.get_alive_enemies())
	
	# Check for room clear
	if current_room.all_enemies_dead():
		handle_room_clear()
	elif get_alive_heroes().is_empty():
		handle_party_wipe()
	else:
		# Continue combat
		start_combat_turn()

# =============================================================================
# ROOM COMPLETION
# =============================================================================

func handle_room_clear():
	emit_signal("room_cleared")
	
	# Clear camp buffs (they only last one combat)
	camp_system.clear_camp_buffs()
	
	# Award XP using ⅓ model
	var xp_reward = calculate_xp_reward()
	for hero in get_alive_heroes():
		hero.xp += xp_reward
		check_level_up(hero)
	
	# Generate loot
	if current_room.room_type == "elite":
		generate_elite_loot()
	elif current_room.room_type == "boss":
		boss_defeated = true
		generate_boss_loot()
	
	# Save progress
	save_system.quick_save()
	
	await get_tree().create_timer(2.0).timeout
	advance_to_next_room()

func calculate_xp_reward() -> int:
	# ⅓ XP model: Need 1/3 standard XP to level
	# Distributed across ~15 rooms to reach L5
	var base_xp = 100 * get_party_avg_level()
	var room_xp = base_xp / 3 / 15
	
	# CR modifiers
	var cr_mult = 1.0
	if current_room.cr_level > get_party_avg_level():
		cr_mult = 1.0 + (0.25 * (current_room.cr_level - get_party_avg_level()))
	
	return int(room_xp * cr_mult)

func check_level_up(hero: Hero):
	var xp_needed = calculate_xp_needed(hero.level)
	
	while hero.xp >= xp_needed:
		hero.xp -= xp_needed
		hero.level += 1
		hero._calculate_derived_stats()
		
		# Initialize new class words
		word_system.initialize_hero_words(hero)
		
		# Check for subclass
		if hero.level == 3:
			apply_subclass(hero)
		
		print("%s reached level %d!" % [hero.hero_name, hero.level])
		
		# Check achievements
		achievement_tracker.check_level_achievement(hero)
		
		xp_needed = calculate_xp_needed(hero.level)

func calculate_xp_needed(level: int) -> int:
	# ⅓ of standard D&D XP requirements
	var standard_xp = [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000]
	if level < standard_xp.size():
		return standard_xp[level] / 3
	return 100000 / 3  # High level default

# =============================================================================
# NON-COMBAT ROOMS
# =============================================================================

func enter_loot_room():
	print("Entered loot room!")
	
	var loot = generate_loot_room_rewards()
	distribute_loot_to_party(loot)
	
	# Auto-advance after showing loot
	await get_tree().create_timer(3.0).timeout
	advance_to_next_room()

func enter_rest_room():
	emit_signal("rest_started")
	
	# Show rest UI
	#var rest_ui = preload("res://scenes/ui/RestRoomUI.tscn").instantiate()
	#rest_ui.setup(party, short_rests_remaining, camp_system)
	#rest_ui.choice_made.connect(_on_rest_choice_made)
	#
	#get_tree().current_scene.add_child(rest_ui)

func _on_rest_choice_made(choice: String):
	match choice:
		"camp":
			start_camp_phase()
		"short_rest":
			use_short_rest()
		"skip":
			advance_to_next_room()

func enter_event_room():
	var event_type = ["merchant", "shrine", "prisoner"].pick_random()
	
	match event_type:
		"merchant":
			show_merchant()
		"shrine":
			show_shrine()
		"prisoner":
			show_prisoner_event()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func get_alive_heroes() -> Array[Hero]:
	return party.filter(func(h): return h.is_alive())

func get_party_avg_level() -> int:
	var total = 0
	var count = 0
	for hero in get_alive_heroes():
		total += hero.level
		count += 1
	return max(1, total / max(1, count))

func position_heroes_at_spawn():
	var positions = [
		Vector2i(2, 3),
		Vector2i(2, 4),
		Vector2i(1, 3),
		Vector2i(1, 4)
	]
	
	for i in range(min(party.size(), positions.size())):
		if party[i].is_alive():
			party[i].grid_position = positions[i]

func apply_dungeon_modifier():
	match dungeon_modifier:
		"cursed":
			for hero in party:
				hero.healing_modifier = 0.5
		"wealthy":
			party_gold *= 2
		"chaotic":
			word_system.chaos_mode = true
		"rushed":
			# Rooms have turn limit
			pass
		"heroic":
			dungeon_tier += 1  # Enemies stronger but better rewards

func weighted_random_choice(weights: Dictionary) -> String:
	var total = 0
	for weight in weights.values():
		total += weight
	
	var roll = randi_range(0, total - 1)
	var current = 0
	
	for key in weights:
		current += weights[key]
		if roll < current:
			return key
	
	return weights.keys()[0]

func complete_dungeon():
	emit_signal("dungeon_complete")
	
	# Final save
	save_system.save_game()
	
	# Show victory screen
	get_tree().change_scene_to_file("res://scenes/Victory.tscn")

func handle_party_wipe():
	print("Party wiped!")
	
	# Can use RECOVER word to get gear back
	save_system.mark_gear_recoverable()
	
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
	
func get_room_description(room_type: String) -> String:
	match room_type:
		"combat":
			return "Battle Room"
		"elite":
			return "Elite Guard Post"
		"trap":
			return "Trapped Corridor"
		"loot":
			return "Treasure Chamber"
		"rest":
			return "Safe Haven"
		"event":
			return "Mysterious Encounter"
		"mini_boss":
			return "Champion's Arena"
		"boss":
			return "Boss Chamber"
		"start":
			return "Dungeon Entrance"
		_:
			return "Unknown Room"

func show_perk_selection(perks: Array):
	# This would create a UI for perk selection
	# For now, let's auto-select the first one
	print("Select starting perk:")
	for i in range(perks.size()):
		print("%d. %s - %s" % [i+1, perks[i].name, perks[i].description])
	
	# Auto-select first perk for testing
	apply_starting_perk(perks[0])

func reveal_upcoming_rooms(count: int):
	# Reveal the next N rooms in the dungeon
	for i in range(count):
		var index = current_room_index + i + 1
		if index < dungeon_layout.size():
			dungeon_layout[index].revealed = true
			print("Revealed upcoming room: %s" % dungeon_layout[index].type)

func display_room():
	# This would connect to your visual display system
	var visual_display = get_node_or_null("VisualRoomDisplay")
	if visual_display:
		visual_display.display_room(current_room)
	else:
		print("Room %d: %s (CR %d)" % [room_count, current_room.room_type, current_room.cr_level])
		print("Enemies: %d" % current_room.enemies.size())

func track_action_statistics(action: HeroAction):
	# Track various statistics for achievements
	if action.type == "attack" and action.target:
		var damage = 0
		if action.has("damage_done"):
			damage = action.damage_done
		if damage > 0:
			achievement_tracker.track_damage(damage)
		if action.has("word_id"):
			achievement_tracker.track_word_use(action.word_id)  # Fixed: removed extra parenthesis
	
	elif action.type == "heal":
		var healing = 0
		if action.has("healing_done"):
			healing = action.healing_done
		if healing > 0:
			achievement_tracker.track_healing(healing)
	
	# Track word usage
	if action.has("word_id"):
		achievement_tracker.track_word_use(action.word_id)

func execute_enemy_action(enemy: Enemy, action: Dictionary):
	match action.type:
		"attack":
			if action.target:
				var result = combat_resolver.resolve_attack(enemy, action.target)
				if result.hit:
					print("%s attacks %s for %d damage!" % [enemy.enemy_name, action.target.hero_name, result.damage])
		"move":
			enemy.grid_position = action.target
			print("%s moves to %s" % [enemy.enemy_name, action.target])
		"spell":
			print("%s casts %s!" % [enemy.enemy_name, action.spell])
		_:
			print("%s does %s" % [enemy.enemy_name, action.type])
	
	await get_tree().create_timer(0.2).timeout

func generate_elite_loot():
	print("Elite defeated! Generating rare loot...")
	# Guaranteed rare+ item
	var loot_roll = randf()
	if loot_roll < 0.7:
		print("Found: Rare weapon!")
	elif loot_roll < 0.95:
		print("Found: Epic armor!")
	else:
		print("Found: Legendary artifact!")
	
	# Extra gold
	var gold = randi_range(50, 150) * get_party_avg_level()
	party_gold += gold
	print("Found %d gold!" % gold)

func generate_boss_loot():
	print("Boss defeated! Generating epic loot...")
	# Guaranteed epic+ item
	var loot_roll = randf()
	if loot_roll < 0.6:
		print("Found: Epic weapon!")
	elif loot_roll < 0.9:
		print("Found: Legendary armor!")
	else:
		print("Found: Mythic artifact!")
	
	# Lots of gold
	var gold = randi_range(200, 500) * get_party_avg_level()
	party_gold += gold
	print("Found %d gold!" % gold)
	
	# Special word unlock chance
	if randf() < 0.5:
		var special_words = ["NOVA", "CHAOS", "DIVINE", "SHADOW"]
		var unlocked = special_words[randi() % special_words.size()]
		print("Unlocked special word: %s!" % unlocked)
		achievement_tracker.emit_signal("word_unlocked", unlocked)

func apply_subclass(hero: Hero):
	# Apply subclass based on class
	match hero.class_id:
		"fighter":
			# For now, auto-select champion
			hero.subclass = "champion"
			print("%s becomes a Champion!" % hero.hero_name)
		"wizard":
			hero.subclass = "evocation"
			print("%s specializes in Evocation!" % hero.hero_name)
		"cleric":
			hero.subclass = "life"
			print("%s follows the Life domain!" % hero.hero_name)
		"rogue":
			hero.subclass = "assassin"
			print("%s becomes an Assassin!" % hero.hero_name)

func generate_loot_room_rewards() -> Array:
	var loot = []
	
	# 2-4 items
	var num_items = randi_range(2, 4)
	for i in range(num_items):
		var roll = randf()
		if roll < 0.4:
			loot.append({"type": "potion", "name": "Healing Potion", "value": 50})
		elif roll < 0.7:
			loot.append({"type": "weapon", "name": "Magic Sword", "value": 200})
		elif roll < 0.9:
			loot.append({"type": "armor", "name": "Enchanted Mail", "value": 300})
		else:
			loot.append({"type": "artifact", "name": "Mysterious Rune", "value": 500})
	
	# Gold
	var gold = randi_range(100, 300) * get_party_avg_level()
	party_gold += gold
	loot.append({"type": "gold", "amount": gold})
	
	return loot

func distribute_loot_to_party(loot: Array):
	print("Found treasure!")
	for item in loot:
		if item.type == "gold":
			print("  %d gold!" % item.amount)
		else:
			print("  %s (worth %d gold)" % [item.name, item.value])
			# Add to party inventory
			# party_inventory.append(item)

func start_camp_phase():
	print("Starting camp phase...")
	# This would show camp word UI
	# For now, simulate camp effects
	for hero in party:
		if hero.is_alive():
			camp_system.execute_camp_word("COOK", hero, party)
			break
	
	await get_tree().create_timer(2.0).timeout
	advance_to_next_room()

func use_short_rest():
	if short_rests_remaining <= 0:
		print("No short rests remaining!")
		return
	
	short_rests_remaining -= 1
	print("Short rest used! (%d remaining)" % short_rests_remaining)
	
	# Full heal party
	for hero in party:
		if hero.is_alive():
			hero.heal(hero.max_hp)
			# Restore all class word uses
			word_system.restore_all_uses(hero)
	
	await get_tree().create_timer(1.0).timeout
	advance_to_next_room()

func show_merchant():
	print("A mysterious merchant appears!")
	print("Items for sale:")
	print("1. Healing Potion - 50g")
	print("2. Magic Weapon - 200g")
	print("3. Mystery Box - 500g")
	
	# Auto-skip for now
	await get_tree().create_timer(2.0).timeout
	advance_to_next_room()

func show_shrine():
	print("You find an ancient shrine!")
	var blessing = ["strength", "wisdom", "fortune"].pick_random()
	
	match blessing:
		"strength":
			print("The shrine grants +1 damage to all heroes!")
			for hero in party:
				hero.temp_modifiers["shrine_damage"] = 1
		"wisdom":
			print("The shrine restores a class word use!")
			for hero in party:
				word_system.restore_single_use(hero, hero.class_id + "_word")
		"fortune":
			var gold = randi_range(100, 300)
			party_gold += gold
			print("The shrine grants %d gold!" % gold)
	
	await get_tree().create_timer(2.0).timeout
	advance_to_next_room()

func show_prisoner_event():
	print("You find a prisoner in a cage!")
	print("They claim to be a powerful hero...")
	
	# 50% chance they're telling the truth
	if randf() < 0.5:
		print("You free them and they join your party! (next run)")
		# Would unlock new hero
	else:
		print("It's a trap! Ambush!")
		# Spawn enemies
		current_room = Room.new()
		current_room.room_type = "ambush"
		current_room.generate(room_count, dungeon_tier, true)
		enter_combat_room({"type": "combat", "cr": dungeon_tier})

# Signal callbacks
func _on_word_assigned(hero: Hero, word: WordCard):
	print("Word assigned: %s -> %s" % [hero.hero_name, word.word])

func _on_combo_achieved(hero: Hero, combo: Array):
	print("COMBO! %s achieved %s" % [hero.hero_name, " -> ".join(combo)])

func _on_camp_word_executed(word: String, effect_data: Dictionary):
	print("Camp word executed: %s" % word)
	if effect_data.has("result"):
		print("  Result: %s" % effect_data.result.get("message", ""))

func _on_achievement_unlocked(id: String, name: String, description: String):
	print("ACHIEVEMENT UNLOCKED: %s" % name)
	print("  %s" % description)
