extends Node
class_name StateMachine

## Reusable node-based finite state machine. Add State child nodes; each child's (lowercased)
## name is its key. The owning actor calls setup(self) in _ready and physics_update(delta)
## from its own _physics_process (so movement order stays deterministic).

@export var initial_state: NodePath

var states: Dictionary = {}
var current: State

func setup(controlled: Node) -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.sm = self
			child.actor = controlled
	if not initial_state.is_empty():
		current = get_node(initial_state)
	elif not states.is_empty():
		current = states.values()[0]
	if current:
		current.enter()

func transition_to(state_name: String, msg: Dictionary = {}) -> void:
	var key := state_name.to_lower()
	if not states.has(key):
		push_warning("StateMachine: no state '%s'" % state_name)
		return
	if states[key] == current:
		return
	if current:
		current.exit()
	current = states[key]
	current.enter(msg)

func physics_update(delta: float) -> void:
	if current:
		current.physics_update(delta)

func state_name() -> String:
	return current.name.to_lower() if current else ""
