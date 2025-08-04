# QuirkNotification.gd - Popup notification for quirk triggers
extends PanelContainer
class_name QuirkNotification

@onready var title_label: Label = $VBox/Title
@onready var message_label: Label = $VBox/Message
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func setup(hero: Hero, message: String):
	message_label.text = message
	
	# Position above the hero's portrait if possible
	var viewport_size = get_viewport_rect().size
	position.x = (viewport_size.x - size.x) / 2
	position.y = 100
	
	# Play popup animation
	if animation_player and animation_player.has_animation("popup"):
		animation_player.play("popup")
