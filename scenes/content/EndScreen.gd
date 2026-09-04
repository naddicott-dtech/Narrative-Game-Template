# EndScreen.gd
#
# What the player sees after the story's last line: a picture, a message,
# and two buttons — Play Again (start from the top) and Title (back to the
# title screen). Change the words and picture in the Inspector.
#
# Like every screen in WorldRoot this is an ordinary scene: ContentManager
# shows it, and the buttons post on SignalBus (the bulletin board).
extends Control

## The words on screen.
@export var message: String = "THE END"
## The picture behind the message. Any size; scaled to cover the screen.
@export var picture: Texture2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var rect := TextureRect.new()
	rect.name = "Picture"
	rect.texture = picture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(column)

	var message_label := Label.new()
	message_label.name = "Message"
	message_label.text = message
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 48)
	column.add_child(message_label)

	var again := Button.new()
	again.name = "PlayAgainButton"
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(240, 44)
	again.pressed.connect(func(): SignalBus.new_game_requested.emit())
	column.add_child(again)

	var title := Button.new()
	title.name = "TitleButton"
	title.text = "Title"
	title.custom_minimum_size = Vector2(240, 44)
	title.pressed.connect(func(): SignalBus.title_requested.emit())
	column.add_child(title)
