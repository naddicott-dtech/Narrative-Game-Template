# BackgroundLink.gd
#
# One background picture the story can call up. Lives under
# NarrativeScene/Stage/Links — duplicate this node (Cmd+D) for every place in
# your story, then fill in the two fields in the Inspector. When your Ink
# story says:
#
#     The truck stop glows at dusk. # @background: truck_stop
#
# the stage finds the BackgroundLink whose Cue Name is "truck_stop" and shows
# its Image behind everything. "# @background: none" goes back to the
# picture the scene started with.
class_name BackgroundLink
extends Node

## The name used in your Ink story's cue: # @background: <this>
@export var cue_name: String = ""
## The picture. Any size works; it is scaled to cover the whole screen.
@export var image: Texture2D
