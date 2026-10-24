## Abstract class for any action performed against a set of lanes. The lane equivalent of BaseCardsetAction.
## Typically a child of ActionPickLanes, using its picked_lanes. Can also stand alone using:
## - picked_lanes: Array[int]. Explicit lane indexes.
## - pick_all_lanes: bool. Every lane.
## Common values for subclasses:
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Which units are affected. Default -1.
extends BaseAction
class_name BaseLaneAction

### Override

func perform_action() -> void:
	# for lane_index in _get_picked_lanes(): ...
	breakpoint

### Keep

func _get_picked_lanes() -> Array[int]:
	var lanes: Array[int] = []
	if get_action_value("pick_all_lanes", false):
		for lane_index: int in Battlefield.LANE_COUNT:
			lanes.append(lane_index)
		return lanes
	if has_action_value("picked_lanes"):
		lanes.assign(get_action_value("picked_lanes", []))
		return lanes
	if parent_action != null and parent_action is ActionBasePickLanes:
		return parent_action.picked_lanes
	return lanes

## Units in the picked lanes on the side(s) given by unit_owner_filter.
func _get_affected_units() -> Array[Unit]:
	var unit_owner_filter: int = get_action_value("unit_owner_filter", Unit.UNIT_OWNER_AUTOMATIC)
	var units: Array[Unit] = []
	for lane_index: int in _get_picked_lanes():
		units += Battlefield.get_units(unit_owner_filter, lane_index)
	return units

func _to_string() -> String:
	return "Base Lane Action"
