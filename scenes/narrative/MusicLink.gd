# MusicLink.gd
#
# One music track the story can start. Lives under NarrativeScene/Stage/Links
# — duplicate this node (Cmd+D) per track, then fill in the two fields in the
# Inspector. When your Ink story says:
#
#     The engine turns over. # @music: road_theme
#
# the stage finds the MusicLink whose Cue Name is "road_theme" and plays its
# Music through the game's AudioManager. Cueing the same track again keeps it
# playing (no restart); "# @music: off" stops the music.
#
# Music loops if the audio file is set to loop: select the file in the
# FileSystem dock, open the Import tab, turn on Loop, click Reimport.
class_name MusicLink
extends Node

## The name used in your Ink story's cue: # @music: <this>
@export var cue_name: String = ""
## The track (an .ogg, .mp3 or .wav file dragged into the project).
@export var music: AudioStream
