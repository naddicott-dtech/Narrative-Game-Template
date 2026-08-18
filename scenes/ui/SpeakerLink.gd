# SpeakerLink.gd
#
# One speaking character. Lives under NarrativeStage/Links — duplicate this
# node (Cmd+D) for every character in your story, then fill in the three
# fields in the Inspector. When your Ink story says:
#
#     Maya waves. # @speaker: maya
#
# the stage finds the SpeakerLink whose Cue Name is "maya" and shows its
# Display Name and Portrait.
class_name SpeakerLink
extends Node

## The name used in your Ink story's cue: # @speaker: <this>
@export var cue_name: String = ""
## The name players see on screen (capitalization, spaces — anything).
@export var display_name: String = ""
## The character's picture. Leave empty for a name-only speaker.
@export var portrait: Texture2D
