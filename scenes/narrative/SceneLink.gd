# SceneLink.gd
#
# One scene the story can cut away to: a comic-panel cut scene, an
# animation, or a whole other game mode (a side-scroller level, a map).
# Lives under NarrativeScene/Stage/Links — duplicate this node (Cmd+D),
# then fill in the fields in the Inspector. When your Ink story says:
#
#     You floor it past the weigh station. # @scene: chase
#
# that line shows, and on the player's NEXT click the story view is
# replaced by this Scene. When the scene says it is finished (see
# scenes/content/CutScene.gd — one line: SignalBus.content_finished.emit()),
# the story view comes back exactly as it was and the story continues.
class_name SceneLink
extends Node

## How the new scene appears.
enum Transition {
	NONE, ## instantly
	FADE, ## from black
}

## The name used in your Ink story's cue: # @scene: <this>
@export var cue_name: String = ""
## The scene file to show (drag a .tscn here). Start from
## scenes/content/CutScene.tscn — duplicate it and change its picture.
@export var scene: PackedScene
## Instant, or fade in from black.
@export var transition: Transition = Transition.NONE
