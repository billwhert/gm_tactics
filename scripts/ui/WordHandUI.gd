# EnhancedWordHandUI.gd - Updated UI for new features
extends Control
class_name EnhancedWordHandUI

signal word_assigned(word: WordCard, hero: Hero)

@onready var card_container: HBoxContainer = $CardContainer
@onready var hero_portraits: HBoxContainer = $HeroPortraits
@onready var turn_order_display: VBoxContainer = $TurnOrderDisplay
@onready var context_hint: Label = $ContextHint

var current_hand: Array[WordCard] = []
var game_manager: Node2D
var assigned_heroes: Array[Hero] = []

func _ready():
	game_manager = get_node("/root/GameManager")
	game_manager.turn_started.connect(_on_turn_started)
	game_manager.word_assigned.connect(_on_word_assigned)
	game_manager.quirk_triggered.connect(_on_quirk_triggered)

func _on_turn_started(hand: Array[WordCard]):
	current_hand = hand
	assigned_heroes.clear()
	refresh_hand()
	update_context_hint()
	clear_turn_order()

func refresh_hand():
	# Clear existing cards
	for child in card_container.get_children():
		child.queue_free()
	
	# Create new card UI elements
	for card in current_hand:
		var card_ui = create_enhanced_card_ui(card)
		card_container.add_child(card_ui)

func create_enhanced_card_ui(card: WordCard) -> Control:
	var card_ui = preload("res://scenes/ui/EnhancedWordCardUI.tscn").instantiate()
	card_ui.setup(card)
	card_ui.dragged.connect(_on_card_dragged)
	card_ui.dropped.connect(_on_card_dropped)
	card_ui.hovered.connect(_on_card_hovered)
	return card_ui

func _on_card_dragged(card_ui):
	card_ui.modulate.a = 0.8
	# Show valid targets
	highlight_valid_heroes_for_word(card_ui.word_card)

func _on_card_dropped(card_ui, global_pos: Vector2):
	card_ui.modulate.a = 1.0
	clear_hero_highlights()
	
	var hero = get_hero_at_position(global_pos)
	if hero and hero.is_alive() and not hero in assigned_heroes:
		# Check if word can be used by hero
		if card_ui.word_card.can_be_used_by(hero):
			emit_signal("word_assigned", card_ui.word_card, hero)
			assigned_heroes.append(hero)
			update_turn_order(hero, card_ui.word_card)
			card_ui.queue_free()
		else:
			show_error_feedback("${hero.hero_name} cannot use ${card_ui.word_card.word}!")
			card_ui.reset_position()
	else:
		card_ui.reset_position()

func _on_card_hovered(card: WordCard):
	# Show word description
	show_word_tooltip(card)

func _on_word_assigned(hero: Hero, word: WordCard):
	# Update hero portrait to show assigned word
	for portrait in hero_portraits.get_children():
		if portrait.hero == hero:
			portrait.assign_word(word)
			break

func _on_quirk_triggered(hero: Hero, message: String):
	# Show quirk notification
	show_quirk_notification(hero, message)

func update_context_hint():
	var context = game_manager.current_room.get_context()
	var hints = []
	
	if context.get("enemy_count", 0) > 3:
		hints.append("Many enemies - AOE attacks recommended!")
	
	if context.get("party_damaged", false):
		hints.append("Party injured - healing available")
	
	if context.get("chest_count", 0) > 0:
		hints.append("Treasure nearby!")
	
	if context.get("boss_fight", false):
		hints.append("BOSS FIGHT - Words are upgraded!")
	
	context_hint.text = " | ".join(hints)

func update_turn_order(hero: Hero, word: WordCard):
	var order_label = Label.new()
	order_label.text = "%d. %s: %s" % [
		assigned_heroes.size(),
		hero.hero_name,
		word.get_display_name()
	]
	
	# Color code by class
	match hero.class_id:
		"fighter":
			order_label.modulate = Color(0.8, 0.2, 0.2)
		"cleric":
			order_label.modulate = Color(0.8, 0.8, 0.2)
		"rogue":
			order_label.modulate = Color(0.5, 0.5, 0.8)
		"wizard":
			order_label.modulate = Color(0.8, 0.2, 0.8)
	
	turn_order_display.add_child(order_label)

func clear_turn_order():
	for child in turn_order_display.get_children():
		child.queue_free()

func highlight_valid_heroes_for_word(word: WordCard):
	for portrait in hero_portraits.get_children():
		if portrait.hero.is_alive() and word.can_be_used_by(portrait.hero):
			if not portrait.hero in assigned_heroes:
				portrait.highlight(Color.GREEN)
		else:
			portrait.highlight(Color.RED)

func clear_hero_highlights():
	for portrait in hero_portraits.get_children():
		portrait.clear_highlight()

func show_word_tooltip(card: WordCard):
	# Would show a tooltip with word description
	pass

func show_quirk_notification(hero: Hero, message: String):
	var notification = preload("res://scenes/ui/QuirkNotification.tscn").instantiate()
	notification.setup(hero, message)
	add_child(notification)
	
	# Auto-remove after 3 seconds
	await get_tree().create_timer(3.0).timeout
	notification.queue_free()

func show_error_feedback(message: String):
	var error_label = Label.new()
	error_label.text = message
	error_label.modulate = Color.RED
	error_label.position = get_viewport().get_mouse_position() - Vector2(100, 50)
	add_child(error_label)
	
	var tween = create_tween()
	tween.tween_property(error_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(error_label.queue_free)

func get_hero_at_position(global_pos: Vector2) -> Hero:
	for portrait in hero_portraits.get_children():
		if portrait.get_global_rect().has_point(global_pos):
			return portrait.hero
	return null
