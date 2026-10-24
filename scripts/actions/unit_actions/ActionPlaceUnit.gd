## The play action of Unit cards: picks a lane (and optionally a spot in it), then summons the unit there.
## By default the player only picks a lane and the unit joins the back of their line.
## Values (in addition to ActionBasePickLanes'):
## - lane_pick_position: bool. If true the player also picks exactly where on their side of the lane
##   the unit stands (0 = front). Default false.
## - Plus anything ActionSummonUnit reads (unit_strength, unit_stamina, unit_name, unit_owner), usually
##   from the card's card_values.
## When an enemy owns this action the lane is picked randomly and the unit joins the back of its line.
extends ActionBasePickLanes
class_name ActionPlaceUnit

func perform_async_action() -> void:
	if len(picked_lanes) > 0:
		var summon_values: Dictionary = {
			"lane_index": picked_lanes[0],
			"lane_position": picked_lane_position,
			"time_delay": 0.2,
		}
		var action_data: Array[Dictionary] = [{Scripts.ACTION_SUMMON_UNIT: summon_values}]
		var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(parent_combatant, card_play_request, targets, action_data, self)
		ActionHandler.add_actions(generated_actions)
	action_async_finished.emit()

## Placing a single unit always picks one lane.
func get_lane_pick_count() -> int:
	return 1

func get_lane_pick_text() -> String:
	var unit_name: String = get_action_value("unit_name", "")
	if unit_name == "" and get_action_card_data() != null:
		unit_name = get_action_card_data().get_card_name()
	if unit_name == "":
		unit_name = "the unit"
	var default_text: String = "Choose where {0} stands" if is_position_pick() else "Choose a lane for {0}"
	return get_action_value("lane_pick_text", default_text).format([unit_name])

func _to_string() -> String:
	return "Place Unit Action"
