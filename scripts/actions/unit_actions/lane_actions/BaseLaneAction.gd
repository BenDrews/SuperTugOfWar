## Abstract class for any action performed against a set of lanes. The lane equivalent of BaseCardsetAction.
## Typically a child of ActionPickLanes, using its picked_lanes. Can also stand alone using:
## - picked_lanes: Array[int]. Explicit lane indexes.
## - pick_all_lanes: bool. Every lane.
## - status_target_units: Array[Unit]. Explicit units.
## Actions run by a lane or unit status fall back to that status's lane / unit (invoking_status_* values).
## Common values for subclasses:
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Which units are affected. Default -1.
extends BaseAction
class_name BaseLaneAction

### Override

func perform_action() -> void:
	# for lane_index in _get_picked_lanes(): ...
	breakpoint

### Keep

## Set by subclasses that act on units one at a time (see _intercept_for_unit()).
var _current_context_unit: Unit = null

## Statuses on both sides of the picked lanes, and on the affected units, intercept lane actions.
## While a single unit is being processed, only that unit's lane and its own statuses apply.
func get_status_context_holders() -> Array[Object]:
	var holders: Array[Object] = []
	if _current_context_unit != null:
		var unit_lane: UnitLane = _current_context_unit.lane
		if unit_lane != null:
			holders.append(unit_lane.player_status_holder)
			holders.append(unit_lane.enemy_status_holder)
		if _current_context_unit.get_status_holder() != null:
			holders.append(_current_context_unit.get_status_holder())
		return holders
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

## Intercepts this action for one unit, with only that unit's lane and own statuses as context, so
## a status on one unit can't change what happens to its neighbours.
func _intercept_for_unit(unit: Unit) -> Array[ActionInterceptorProcessor]:
	_current_context_unit = unit
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	_current_context_unit = null
	return processors

## Units in the picked lanes on the side(s) given by unit_owner_filter.
func _get_affected_units() -> Array[Unit]:
	return get_affected_units_for(self, _get_unit_owner_filter())

## The lanes an action works on, in order of precedence:
## pick_all_lanes; explicit picked_lanes; the picked_lanes of a parent ActionBasePickLanes; or, for
## an action run by a lane or unit status, that status's lane (invoking_status_lanes).
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
	if action.has_action_value("invoking_status_lanes"):
		lanes.assign(action.get_action_value("invoking_status_lanes", []))
	return lanes

## The units an action works on: explicit status_target_units; otherwise, for an action run by a unit
## status with no unit_owner_filter of its own, that unit; otherwise the units in the picked lanes
## whose owner passes unit_owner_filter (-1 = both sides).
static func get_affected_units_for(action: BaseAction, unit_owner_filter: int) -> Array[Unit]:
	var units: Array[Unit] = []
	var explicit_units: Array = []
	if action.has_action_value("status_target_units"):
		explicit_units = action.get_action_value("status_target_units", [])
	elif action.has_action_value("invoking_status_units") and not action.values.has("unit_owner_filter"):
		explicit_units = action.get_action_value("invoking_status_units", [])
	if len(explicit_units) > 0:
		for unit in explicit_units:
			if is_instance_valid(unit) and not unit.is_discarded:
				units.append(unit)
		return units
	for lane_index: int in get_picked_lanes_for(action):
		if lane_index < 0:
			continue
		units += Battlefield.get_units(unit_owner_filter, lane_index)
	return units

## unit_owner_filter for this action: its own value, else (when run by a lane status) the status's
## side, so a lane status affects its own side's units unless told otherwise. -1 = both sides.
func _get_unit_owner_filter() -> int:
	if has_action_value("unit_owner_filter"):
		return get_action_value("unit_owner_filter", Unit.UNIT_OWNER_AUTOMATIC)
	return get_action_value("invoking_status_side", Unit.UNIT_OWNER_AUTOMATIC)

func _to_string() -> String:
	return "Base Lane Action"
