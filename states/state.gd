extends Node
class_name State

## Base class for one state in a StateMachine. Subclasses override the hooks they need.
## `sm` is the owning StateMachine; `actor` is the node being controlled (e.g. an EnemyBase).

var sm: StateMachine
var actor: Node

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
