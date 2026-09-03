# SfxLink.gd
#
# One sound effect the story can play. Lives under NarrativeScene/Stage/Links
# — duplicate this node (Cmd+D) per sound, then fill in the two fields in the
# Inspector. When your Ink story says:
#
#     A horn blares behind you. # @sfx: horn
#
# the stage finds the SfxLink whose Cue Name is "horn" and plays its Sound
# once through the game's AudioManager. Several sounds can overlap.
class_name SfxLink
extends Node

## The name used in your Ink story's cue: # @sfx: <this>
@export var cue_name: String = ""
## The sound (an .ogg, .mp3 or .wav file dragged into the project).
@export var sound: AudioStream
