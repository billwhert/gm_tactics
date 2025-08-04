# MomentumUI.gd - Visual feedback for momentum system
extends Control
class_name MomentumUI

@onready var momentum_container: VBoxContainer = $MomentumContainer
@onready var variety_label: Label = $VarietyBonus
@onready var combo_popup: Control = $ComboPopup
@onready var combo_label: Label = $ComboPopup/Label

var momentum_system: MomentumSystem
var momentum_bars: Dictionary = {}  # word -> ProgressBar

func _ready():
	momentum_system = get_node_or_null("/root/MomentumSystem")
	if momentum_system:
		momentum_system.momentum_changed.connect(_on_momentum_changed)
		momentum_system.combo_achieved.connect(_on_combo_achieved)
		momentum_system.variety_bonus_gained.connect(_on_variety_bonus_gained)

func _on_momentum_changed(word: String, level: int):
	if not word in momentum_bars:
		create_momentum_bar(word)
	
	update_momentum_bar(word, level)

func create_momentum_bar(word: String):
	var container = HBoxContainer.new()
	
	var label = Label.new()
	label.text = word
	label.custom_minimum_size.x = 80
	container.add_child(label)
	
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 20)
	bar.max_value = 12  # Max momentum level
	bar.step = 1
	bar.show_percentage = false
	container.add_child(bar)
	
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Normal"
	container.add_child(level_label)
	
	momentum_container.add_child(container)
	momentum_bars[word] = bar

func update_momentum_bar(word: String, level: int):
	if not word in momentum_bars:
		return
	
	var bar = momentum_bars[word]
	var uses = momentum_system.word_momentum.get(word, 0)
	bar.value = uses
	
	# Update color based on level
	var color = momentum_system.get_momentum_color(word)
	bar.modulate = color
	
	# Update level label
	var container = bar.get_parent()
	var level_label = container.get_node("LevelLabel")
	level_label.text = momentum_system.MOMENTUM_LEVELS[level].name
	level_label.modulate = color
	
	# Pulse animation on level up
	if uses > 0 and uses in momentum_system.MOMENTUM_LEVELS:
		var tween = create_tween()
		tween.tween_property(container, "scale", Vector2(1.1, 1.1), 0.2)
		tween.tween_property(container, "scale", Vector2.ONE, 0.2)

func _on_combo_achieved(hero: Hero, combo: Array):
	# Show combo popup
	combo_label.text = "%s achieved %s!" % [hero.hero_name, " → ".join(combo)]
	combo_popup.show()
	combo_popup.modulate.a = 1.0
	
	# Animate
	var tween = create_tween()
	tween.tween_property(combo_popup, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(combo_popup, "scale", Vector2.ONE, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(combo_popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(combo_popup.hide)

func _on_variety_bonus_gained(bonus: float):
	variety_label.text = "Variety Bonus: +%.0f%%" % (bonus * 100)
	variety_label.modulate = Color(0.2, 1.0, 0.2)
	
	# Pulse effect
	var tween = create_tween()
	tween.tween_property(variety_label, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(variety_label, "scale", Vector2.ONE, 0.2)
