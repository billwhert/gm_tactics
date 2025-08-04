# EnhancedWordCardUI.gd - Individual word card UI element
extends Control
class_name EnhancedWordCardUI

signal dragged(card)
signal dropped(card, global_pos: Vector2)
signal hovered(word_card: WordCard)

@onready var label: Label = $Background/Label
@onready var description: Label = $Background/Description
@onready var tags_container: HBoxContainer = $Background/Tags
@onready var uses_label: Label = $Background/UsesLabel
@onready var background: NinePatchRect = $Background

var word_card: WordCard
var is_dragging: bool = false
var drag_offset: Vector2
var original_position: Vector2

func setup(card: WordCard):
	word_card = card
	label.text = card.get_display_name()
	
	# Show transformation info
	if card.original_word != "" and card.original_word != card.word:
		description.text = "Transformed from " + card.original_word
		description.show()
	else:
		description.hide()
	
	# Show uses this run
	if card.uses_this_run > 0:
		uses_label.text = "Used: " + str(card.uses_this_run)
		uses_label.show()
	else:
		uses_label.hide()
	
	# Show tags
	for tag in card.tags:
		var tag_label = Label.new()
		tag_label.text = tag
		tag_label.add_theme_font_size_override("font_size", 10)
		tags_container.add_child(tag_label)
	
	# Color based on rarity
	if card.special:
		background.modulate = Color(1.0, 0.8, 0.3)  # Gold for special
	elif card.upgraded:
		background.modulate = Color(0.3, 0.8, 1.0)  # Blue for upgraded
	else:
		# Normal colors by type
		match card.tags[0] if card.tags.size() > 0 else "basic":
			"combat":
				background.modulate = Color(1.0, 0.8, 0.8)
			"support":
				background.modulate = Color(0.8, 1.0, 0.8)
			"movement":
				background.modulate = Color(1.0, 1.0, 0.8)
			"magic":
				background.modulate = Color(0.8, 0.8, 1.0)
			_:
				background.modulate = Color.WHITE

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = global_position - event.global_position
				emit_signal("dragged", self)
				get_parent().move_child(self, -1)
			else:
				if is_dragging:
					is_dragging = false
					emit_signal("dropped", self, event.global_position)
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			global_position = event.global_position + drag_offset
		else:
			# Hover effect
			emit_signal("hovered", word_card)

func reset_position():
	var tween = create_tween()
	tween.tween_property(self, "position", original_position, 0.2)
