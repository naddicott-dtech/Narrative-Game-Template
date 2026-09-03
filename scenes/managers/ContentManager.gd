# ContentManager.gd
#
# Owns what is on screen in WorldRoot — exactly ONE thing at a time. Normally
# that is the story view (NarrativeScene). When the story cuts away
# ("# @scene: chase"), the director asks this manager to swap the story view
# out for the linked scene; when that scene says it is finished, the
# director asks for the story view back.
#
# Both requests are ordinary function calls that answer "" (done) or an
# error message — the story never assumes a swap happened. Announcements go
# on SignalBus AFTER a swap really happened, for anything else that cares.
class_name ContentManager
extends Node

## The group the director looks in to find this manager.
const GROUP := "content_manager"

## The node whose one child is "what's on screen" (Main/WorldRoot).
@export var world_root: Node
## The story view scene to bring back after a detour (NarrativeScene.tscn).
@export var story_view: PackedScene

var _story_view_up := true

func _ready() -> void:
	add_to_group(GROUP)

func is_story_view_up() -> bool:
	return _story_view_up

# Replace what's on screen with `scene`. `content_name` is the cue name,
# used in errors and announcements.
func swap_to(scene: PackedScene, content_name: String) -> String:
	if world_root == null:
		return _missing_reference("World Root")
	if scene == null:
		return (
			'[Narrative] Cannot show "%s" — its scene is empty. ' % content_name
			+ "Select the SceneLink and set its Scene in the Inspector."
		)
	var node: Node = scene.instantiate()
	if node == null:
		return (
			'[Narrative] Cannot show "%s" — its scene could not be created. ' % content_name
			+ "Open the scene file in the editor and check it for errors."
		)
	_replace_content(node)
	_story_view_up = false
	SignalBus.content_changed.emit(content_name)
	return ""

# Bring the story view back.
func return_to_story() -> String:
	if world_root == null:
		return _missing_reference("World Root")
	if story_view == null:
		return _missing_reference("Story View")
	var node: Node = story_view.instantiate()
	if node == null:
		return "[Narrative] The story view scene could not be created. Check NarrativeScene.tscn for errors."
	_replace_content(node)
	_story_view_up = true
	SignalBus.story_view_returned.emit()
	return ""

func _replace_content(node: Node) -> void:
	for child in world_root.get_children():
		world_root.remove_child(child)
		child.queue_free()
	world_root.add_child(node)

func _missing_reference(field_name: String) -> String:
	return (
		"[Narrative] ContentManager is missing its %s reference. " % field_name
		+ "Select ContentManager and assign it in the Inspector."
	)
