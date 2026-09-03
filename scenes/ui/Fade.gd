# Fade.gd
#
# A full-screen black layer in Main's UI that starts invisible. flash()
# snaps it to black and fades it away over `seconds` — a "fade in from
# black" the story uses for "# @transition: fade" and for SceneLinks whose
# Transition is Fade. It never blocks clicks.
#
# Self-contained: the stage and the director find it by its group.
extends ColorRect

## The group the story looks in to find this node.
const GROUP := "screen_fade"

## How long the fade from black takes.
@export_range(0.05, 5.0, 0.05) var seconds := 0.6

var _tween: Tween = null

func _ready() -> void:
	add_to_group(GROUP)
	color = Color(0, 0, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

# Black now, then fade away.
func flash() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	color.a = 1.0
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 0.0, seconds)
