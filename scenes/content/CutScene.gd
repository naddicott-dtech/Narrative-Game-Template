# CutScene.gd
#
# The simplest thing a story can cut away to: one full-screen picture; the
# player clicks (or presses Space/Enter) and the story continues. Duplicate
# scenes/content/CutScene.tscn for each cut scene in your game and change
# its Picture in the Inspector.
#
# THE ONE RULE for any scene the story cuts away to — a cut scene, an
# animation, a mini-game, a whole level: when it is done, post
#
#     SignalBus.content_finished.emit()
#
# and the story view comes back and the story goes on. That's the entire
# contract; this file is the smallest example of it.
extends Control

## The picture to show. Any size; it is scaled to cover the screen.
@export var picture: Texture2D

var _finished := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rect := TextureRect.new()
	rect.name = "Picture"
	rect.texture = picture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE   # clicks reach this scene
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		finish()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		finish()

# Tell the story we are done. Posting twice would confuse it, so this runs once.
func finish() -> void:
	if _finished:
		return
	_finished = true
	SignalBus.content_finished.emit()
