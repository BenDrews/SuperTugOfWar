## Abstract class for any action performed against a set of lanes. The lane equivalent of BaseCardsetAction.
## Typically a child of ActionPickLanes, using its picked_lanes. Can also stand alone using:
## - picked_lanes: Array[int]. Explicit lane indexes.
## - pick_all_lanes: bool. Every lane.
## - status_target_units: Array[Unit]. Explicit units (set automatically for unit statuses).
## Common values for subclasses:
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Which units are affected. Default -1.
extends BaseAction
class_name BaseLaneAction

### Override

func perform_action() -> void:
	# for lane_index in _get_picked_lanes(): ...
	breakpoint

### Keep

## Statuses on both sides of the picked lanes, and on the affected units, intercept lane actions.
func get_status_context_holders() -> Array[Object]:
	var holders: Array[Object] = []
	for lane_index: int in _get_picked_lanes():
		var lane: UnitLane = Battlefield.get_lane(lane_index)
		if lane != null:
			holders.append(lane.player_status_holder)
			holders.append(lane.enemy_status_holder)
	for unit: Unit in _get_affected_units():
		if unit.get_status_holder() != null:
			holders.append(unit.get_status_holder())
	return holders

func _get_picked_lanes() -> Array[int]:
	return get_picked_lanes_for(self)

## Units in the picked lanes on the side(s) given by unit_owner_filter.
func _get_affected_units() -> Array[Unit]:
	return get_affected_units_for(self, get_action_value("unit_owner_filter", Unit.UNIT_OWNER_AUTOMATIC))

## The lanes an action works on: every lane with pick_all_lanes, explicit picked_lanes (also how lane
## and unit statuses pass their own lane), or the picked_lanes of a parent ActionBasePickLanes.
static func get_picked_lanes_for(action: BaseAction) -> Array[int]:
	var lanes: Array[int] = []
	if action.get_action_value("pick_all_lanes", false):
		for lane_index: int in Battlefield.LANE_COUNT:
			lanes.append(lane_index)
		return lanes
	if action.has_action_value("picked_lanes"):
		lanes.assign(action.get_action_value("picked_lanes", []))
		return lanes
	var ancestor: BaseAction = action.parent_action
	while ancestor != null:
		if ancestor is ActionBasePickLanes:
			return ancestor.picked_lanes
		ancestor = ancestor.parent_action
	return lanes

## The units an action works on: status_target_units if given (how a unit status passes its unit),
## otherwise the units in the picked lanes whose owner passes unit_owner_filter (-1 = both sides).
static func get_affected_units_for(action: BaseAction, unit_owner_filter: int) -> Array[Unit]:
	var units: Array[Unit] = []
	if action.has_action_value("status_target_units"):
		for unit in action.get_action_value("status_target_units", []):
			if is_instance_valid(unit) and not unit.is_discarded:
				units.append(unit)
		return units
	for lane_index: int in get_picked_lanes_for(action):
		units += Battlefield.get_units(unit_owner_filter, lane_index)
	return units

func _to_string() -> String:
	return "Base Lane Action"
