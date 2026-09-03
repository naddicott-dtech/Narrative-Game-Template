# SpeakerLink.gd
#
# One speaking character. Lives under NarrativeScene/Stage/Links — duplicate
# this node (Cmd+D) for every character in your story, then fill in the
# fields in the Inspector. When your Ink story says:
#
#     Maya waves. # @speaker: maya
#
# the stage finds the SpeakerLink whose Cue Name is "maya", shows its Display
# Name in the dialogue box, and puts its Portrait in the Left or Right slot.
class_name SpeakerLink
extends Node

## Which side of the screen this character stands on.
enum ScreenSide { LEFT, RIGHT }

## The name used in your Ink story's cue: # @speaker: <this>
@export var cue_name: String = ""
## The name players see on screen (capitalization, spaces — anything).
@export var display_name: String = ""
## The character's picture. Leave empty for a voice with no portrait
## (a radio, a narrator with a name, someone off screen).
@export var portrait: Texture2D
## Left or right portrait slot. Two characters on screen = one of each.
@export var side: ScreenSide = ScreenSide.LEFT
