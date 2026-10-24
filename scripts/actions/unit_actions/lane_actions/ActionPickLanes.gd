## General use lane pick action that generates child lane actions (BaseLaneAction) once lanes are picked.
## The lane equivalent of ActionPickCards. Child actions read this action's picked_lanes.
## Values (in addition to ActionBasePickLanes'):
## - action_data: Array[Dictionary]. The child actions to run against the picked lanes.
## Example, a card that tires every unit in a chosen lane:
##   {Scripts.ACTION_PICK_LANES: {"action_data": [{Scripts.ACTION_CHANGE_LANE_UNIT_STAMINA: {"stamina_change": -1}}]}}
extends ActionBasePickLanes
class_name ActionPickLanes

func perform_async_action() -> void:
	_generate_child_actions()
	action_async_finished.emit()

func _generate_child_actions() -> void:
	if len(picked_lanes) == 0:
		return # nothing picked (or the pick was cancelled)
	var action_data: Array[Dictionary] = []
	action_data.assign(get_action_value("action_data", []))
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(parent_combatant, card_play_request, targets, action_data, self)
	ActionHandler.add_actions(generated_actions)

func _to_string() -> String:
	return "Pick Lanes Action"
