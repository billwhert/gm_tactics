# UnlockNotificationUI.gd - Shows when new content is unlocked
extends Control
class_name UnlockNotificationUI

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var icon: TextureRect = $Container/Icon
@onready var title_label: Label = $Container/VBox/Title
@onready var description_label: Label = $Container/VBox/Description

func show_unlock(type: String, name: String, description: String):
	# Set content
	title_label.text = "UNLOCKED: " + name
	description_label.text = description
	
	# Set icon based on type
	match type:
		"word":
			icon.modulate = Color(1.0, 0.8, 0.3)
		"quirk":
			icon.modulate = Color(0.8, 0.3, 1.0)
		"achievement":
			icon.modulate = Color(0.3, 0.8, 1.0)
	
	# Play animation
	show()
	if animation_player:
		animation_player.play("unlock_reveal")
	
	# Auto-hide after delay
	await get_tree().create_timer(3.0).timeout
	if animation_player:
		animation_player.play("fade_out")
		await animation_player.animation_finished
	hide()
