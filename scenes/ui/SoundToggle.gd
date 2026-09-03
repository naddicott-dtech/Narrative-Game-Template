# SoundToggle.gd
#
# The "Sound" switch (top right). The game starts SILENT: a web page must not
# play sound until the player asks for it, and the click that flips this
# switch is also the browser's required first gesture before any audio can
# play. Flipping it on unmutes the whole game (the Master audio bus); off
# mutes it again.
#
# Self-contained: attach it to a CheckButton and it works — nothing to wire.
# To ship with sound on from the start, set Button Pressed = On in the
# Inspector (fine for a desktop build; browsers will still wait for a click).
extends CheckButton

func _ready() -> void:
	_apply(button_pressed)
	toggled.connect(_apply)

func _apply(sound_on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)
