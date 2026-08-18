# SignalBus.gd
#
# Think of this as the game's BULLETIN BOARD (it's an autoload, like Globals,
# so it's always available as "SignalBus.").
#
# A "signal" is an announcement. One script posts an announcement ("the money
# changed!") without knowing or caring who reads it. Other scripts subscribe to
# the announcements they care about. This keeps scripts from having to reach
# directly into each other — the HUD never has to know where money lives, it
# just listens for "money_changed". Loosely connected code is much easier to
# change later.
#
# Two halves of every signal:
#   1. POST it:      SignalBus.money_changed.emit(125)
#   2. SUBSCRIBE:    SignalBus.money_changed.connect(my_handler_function)
#
# The value in parentheses (e.g. new_value) is the piece of information that
# travels with the announcement.
extends Node

# @warning_ignore("UNUSED_SIGNAL") just hides a yellow editor warning. Godot
# notices these signals aren't emitted *inside this file* and would normally
# nag about it — but that's expected here, since other scripts do the emitting.
@warning_ignore("UNUSED_SIGNAL")
signal money_changed(new_value)   # posted whenever the player's money changes

@warning_ignore("UNUSED_SIGNAL")
signal day_ended(day_number)      # posted when a new day begins

@warning_ignore("UNUSED_SIGNAL")
signal tick(delta_time)           # posted every single frame (see TimeManager)

@warning_ignore("UNUSED_SIGNAL")
signal speaker_changed(speaker_name)  # posted after a "@speaker:" story cue
									  # succeeds ("none" = the narrator)
