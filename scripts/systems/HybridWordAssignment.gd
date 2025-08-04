# HybridWordAssignmentUI.gd - UI for the new hybrid word system
extends Control
class_name HybridWordAssignmentUI

@onready var hero_panels: HBoxContainer = $HeroSection/HeroPanels
@onready var shared_pool_container: HBoxContainer = $SharedPoolSection/WordContainer
@onready var turn_preview: VBoxContainer = $TurnPreview
@onready var confirm_button: Button = $ConfirmButton

var game_manager: Node2D
var word_system: HybridWordSystem
var current_assignments: Dictionary = {}  # hero -> word
var hero_panels_dict: Dictionary = {}  # hero -> panel

signal turn_confirmed(assignments: Dictionary)

func _ready():
	game_manager = get_node("/root/GameManager")
	word_system = HybridWordSystem.new()
	
	# Connect signals
	word_system.word_assigned.connect(_on_word_assigned)
	word_system.shared_word_claimed.connect(_on_shared_word_claimed)
	word_system.class_word_used.connect(_on_class_word_used)
	
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.disabled = true

func setup_turn(party: Array[Hero], room_context: Dictionary):
	current_assignments.clear()
	confirm_button.disabled = true
	
	# Initialize hero panels
	for child in hero_panels.get_children():
		child.queue_free()
	hero_panels_dict.clear()
	
	for hero in party:
		if hero.is_alive():
			var panel = create_hero_panel(hero)
			hero_panels.add_child(panel)
			hero_panels_dict[hero] = panel
	
	# Draw shared pool
	word_system.draw_shared_pool(party.size(), get_average_party_level(party))
	refresh_shared_pool_display()

func create_hero_panel(hero: Hero) -> Control:
	var panel = preload("res://scenes/ui/HeroWordPanel.tscn").instantiate()
	panel.setup(hero, word_system)
	panel.word_selected.connect(_on_hero_word_selected)
	return panel

func refresh_shared_pool_display():
	# Clear existing
	for child in shared_pool_container.get_children():
		child.queue_free()
	
	# Display available shared words
	for word in word_system.shared_pool_available:
		var word_ui = create_shared_word_ui(word)
		shared_pool_container.add_child(word_ui)

func create_shared_word_ui(word: WordCard) -> Control:
	var word_ui = preload("res://scenes/ui/SharedWordCard.tscn").instantiate()
	word_ui.setup(word)
	word_ui.selected.connect(_on_shared_word_selected)
	return word_ui

func _on_hero_word_selected(hero: Hero, word: WordCard):
	# Assign word to hero
	if word_system.assign_word_to_hero(hero, word):
		current_assignments[hero] = word
		update_turn_preview()
		check_all_assigned()

func _on_shared_word_selected(word: WordCard):
	# Show hero selection mode
	show_hero_selection_for_word(word)

func show_hero_selection_for_word(word: WordCard):
	# Highlight heroes that can use this word
	for hero in hero_panels_dict:
		var panel = hero_panels_dict[hero]
		if not hero in current_assignments:
			panel.set_selectable(true)
			panel.pending_word = word

func _on_word_assigned(hero: Hero, word: WordCard):
	# Update UI
	if hero in hero_panels_dict:
		var panel = hero_panels_dict[hero]
		panel.show_assigned_word(word)
	
	# Refresh shared pool if a shared word was used
	if word.custom_data.get("type", "") == "shared":
		refresh_shared_pool_display()

func _on_shared_word_claimed(word: WordCard, hero: Hero):
	# Remove the word from shared pool display
	refresh_shared_pool_display()

func _on_class_word_used(hero: Hero, word: String, uses_left: int):
	# Update hero panel to show remaining uses
	if hero in hero_panels_dict:
		var panel = hero_panels_dict[hero]
		panel.update_class_word_uses(word, uses_left)

func update_turn_preview():
	# Clear preview
	for child in turn_preview.get_children():
		child.queue_free()
	
	# Show assignment order
	var order = 1
	for hero in current_assignments:
		var label = Label.new()
		label.text = "%d. %s → %s" % [order, hero.hero_name, current_assignments[hero].word]
		turn_preview.add_child(label)
		order += 1

func check_all_assigned():
	# Enable confirm if all alive heroes have words
	var all_assigned = true
	for hero in hero_panels_dict:
		if hero.is_alive() and not hero in current_assignments:
			all_assigned = false
			break
	
	confirm_button.disabled = not all_assigned

func _on_confirm_pressed():
	emit_signal("turn_confirmed", current_assignments)

func get_average_party_level(party: Array[Hero]) -> int:
	var total = 0
	var count = 0
	for hero in party:
		if hero.is_alive():
			total += hero.level
			count += 1
	return total / max(1, count)
