# HeroPortraitUI.gd
extends Panel
class_name HeroPortraitUI

@onready var name_label: Label = $VBox/NameLabel
@onready var hp_bar: ProgressBar = $VBox/HPBar
@onready var ac_label: Label = $VBox/ACLabel
@onready var status_container: HBoxContainer = $VBox/StatusContainer
@onready var assignment_slot: Control = $AssignmentSlot

var hero: Hero
var assigned_word: WordCard = null

func setup(hero_ref: Hero):
	hero = hero_ref
	hero.hp_changed.connect(_on_hp_changed)
	hero.died.connect(_on_hero_died)
	
	name_label.text = "%s %s" % [hero.race_id, hero.class_id]
	update_display()

func update_display():
	hp_bar.max_value = hero.max_hp
	hp_bar.value = hero.current_hp
	
	# Create HP label if it doesn't exist
	var hp_label = hp_bar.get_node_or_null("Label")
	if not hp_label:
		hp_label = Label.new()
		hp_label.name = "Label"
		hp_bar.add_child(hp_label)
	hp_label.text = "%d/%d" % [hero.current_hp, hero.max_hp]
	
	ac_label.text = "AC: %d" % hero.ac
	
	# Update status effects
	for child in status_container.get_children():
		child.queue_free()
	
	if hero.defending:
		var def_icon = Label.new()
		def_icon.text = "🛡️"
		status_container.add_child(def_icon)
	
	# Show assigned word
	if assigned_word:
		var word_label = assignment_slot.get_node_or_null("Label")
		if not word_label:
			word_label = Label.new()
			word_label.name = "Label"
			assignment_slot.add_child(word_label)
		word_label.text = assigned_word.word
		assignment_slot.show()
	else:
		assignment_slot.hide()

func _on_hp_changed(new_hp: int, max_hp: int):
	update_display()
	
	# Flash red on damage
	if new_hp < hp_bar.value:
		modulate = Color(1.5, 0.8, 0.8)
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func _on_hero_died():
	modulate = Color(0.5, 0.5, 0.5)
	assignment_slot.hide()

func can_accept_word() -> bool:
	return hero.is_alive() and assigned_word == null

func assign_word(word: WordCard):
	assigned_word = word
	update_display()

func clear_assignment():
	assigned_word = null
	update_display()
