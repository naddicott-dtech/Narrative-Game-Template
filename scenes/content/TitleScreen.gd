# TitleScreen.gd
#
# The screen the game opens on: a picture, your game's title, and two
# buttons. New Game starts the story from the top; Continue picks up at the
# last choice the player faced (it is greyed out when there is no saved
# game). Change the words and the picture in the Inspector; restyle the
# buttons in the Theme Overrides like any Button.
#
# Like every screen in WorldRoot, this is an ordinary scene: ContentManager
# shows it, and the buttons post on SignalBus (the bulletin board) — the
# NarrativeDirector does the rest.
extends Control

## Your game's name.
@export var title: String = "Narrative Game Template"
## A line under the title (leave empty for none).
@export var subtitle: String = "Click New Game"
## The picture behind the title. Any size; scaled to cover the screen.
@export var picture: Texture2D

var _continue_button: Button

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

	var title_label := Label.new()
	title_label.name = "Title"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	column.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "Subtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.visible = subtitle.strip_edges() != ""
	column.add_child(subtitle_label)

	var new_game := Button.new()
	new_game.name = "NewGameButton"
	new_game.text = "New Game"
	new_game.custom_minimum_size = Vector2(240, 44)
	new_game.pressed.connect(func(): SignalBus.new_game_requested.emit())
	column.add_child(new_game)

	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(240, 44)
	_continue_button.disabled = not SaveManager.has_save()
	_continue_button.pressed.connect(func(): SignalBus.continue_requested.emit())
	column.add_child(_continue_button)
