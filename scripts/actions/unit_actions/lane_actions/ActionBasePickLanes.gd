## Abstract class for any action which requires selecting one or more lanes. The lane equivalent of
## ActionBasePickCards: the player picks on the Battlefield (or the pick happens automatically),
## picked_lanes is filled in, then perform_async_action() runs.
## See ActionPickLanes for deferring to child lane actions (BaseLaneAction), and ActionPlaceUnit
## for placing a unit card.
## Values:
## - lane_pick_count: int. Number of lanes to pick. Default 1. Clamped to the pickable lanes.
## - lane_pick_mode: int (LANE_PICK_MODES). Default AUTOMATIC: the player picks if they own the
##   action, otherwise (eg an enemy intent) a random lane is picked.
## - lane_pick_filter: int (LANE_PICK_FILTERS). Which lanes are pickable. Default ANY.
## - lane_pick_position: bool. Also pick where on the player's side of the lane (insertion index,
##   0 = front). Stored in picked_lane_position. Default false. Only meaningful for player picks.
## - lane_pick_text: String. Prompt shown while picking.
## - rng_name: String. RNG track for random picks. Default "rng_lane_picking".
extends BaseAsyncAction
class_name ActionBasePickLanes

enum LANE_PICK_MODES {
	AUTOMATIC = -1, # PLAYER for the player's actions, RANDOM otherwise
	PLAYER, # the player clicks the lane(s)
	RANDOM, # random pickable lane(s)
	ALL, # every pickable lane, regardless of lane_pick_count
	}

enum LANE_PICK_FILTERS {
	ANY,
	HAS_UNITS, # lanes with at least one unit on either side
	HAS_PLAYER_UNITS,
	HAS_ENEMY_UNITS,
	}

## The lanes picked automatically or by the player, in pick order. Child actions use this.
var picked_lanes: Array[int] = []
## Insertion index on the player's side of the last picked lane (0 = front), or -1 for the back
## of the line / not picked. Only set when lane_pick_position is true.
var picked_lane_position: int = -1

### Override These

## Override to act on picked_lanes. Must emit action_async_finished.
func perform_async_action() -> void:
	action_async_finished.emit()

func get_lane_pick_text() -> String:
	var default_text: String = "Choose a lane" if get_lane_pick_count() == 1 else "Choose {0} lanes"
	return get_action_value("lane_pick_text", default_text).format([get_lane_pick_count()])

func _to_string() -> String:
	return "Base Lane Pick Action"

### Keep

func perform_action() -> void:
	var pickable_lanes: Array[int] = get_pickable_lanes()
	var lane_pick_count: int = min(get_lane_pick_count(), len(pickable_lanes))

	# always give ActionHandler a frame to start awaiting before finishing, to avoid hangs
	if lane_pick_count <= 0:
		await Global.get_tree().process_frame
		action_async_finished.emit() # nothing pickable, do nothing
		return

	match get_lane_pick_mode():
		LANE_PICK_MODES.ALL:
			picked_lanes = pickable_lanes
		LANE_PICK_MODES.RANDOM:
			var rng_name: String = get_action_value("rng_name", "rng_lane_picking")
			var rng_lane_picking: RandomNumberGenerator = Global.player_data.get_player_rng(rng_name)
			picked_lanes.assign(Random.shuffle_array(rng_lane_picking, pickable_lanes).slice(0, lane_pick_count))
		_:
			if len(pickable_lanes) == lane_pick_count and not is_position_pick():
				picked_lanes = pickable_lanes # no real choice, skip the prompt
			else:
				async_awaiting = true
				Signals.lane_pick_requested.emit(self)
				await Signals.lane_pick_confirmed
				async_awaiting = false
				perform_async_action()
				return

	await Global.get_tree().process_frame
	perform_async_action()

func is_instant_action() -> bool:
	return true

## Lane picks are skipped if combat is already over.
func is_action_short_circuited() -> bool:
	return get_action_value("action_short_circuits", true)

## Forces the pick to end with nothing picked.
func force_action_end() -> void:
	if async_awaiting:
		picked_lanes = []
		picked_lane_position = -1
		async_awaiting = false
		Signals.lane_pick_confirmed.emit()

func get_lane_pick_count() -> int:
	return max(1, get_action_value("lane_pick_count", 1))

func get_lane_pick_mode() -> int:
	var lane_pick_mode: int = get_action_value("lane_pick_mode", LANE_PICK_MODES.AUTOMATIC)
	if lane_pick_mode == LANE_PICK_MODES.AUTOMATIC:
		if parent_combatant == null or parent_combatant is Player:
			return LANE_PICK_MODES.PLAYER
		return LANE_PICK_MODES.RANDOM
	return lane_pick_mode

func is_position_pick() -> bool:
	return get_action_value("lane_pick_position", false) and get_lane_pick_mode() == LANE_PICK_MODES.PLAYER

## Indexes of lanes that pass lane_pick_filter.
func get_pickable_lanes() -> Array[int]:
	return get_lanes_passing_filter(get_action_value("lane_pick_filter", LANE_PICK_FILTERS.ANY))

## Indexes of lanes that pass a LANE_PICK_FILTERS value. Also used by ValidatorLanePickable.
static func get_lanes_passing_filter(lane_pick_filter: int) -> Array[int]:
	var passing_lanes: Array[int] = []
	for lane: UnitLane in Battlefield.get_lanes():
		var passes: bool = true
		match lane_pick_filter:
			LANE_PICK_FILTERS.HAS_UNITS:
				passes = len(lane.get_units()) > 0
			LANE_PICK_FILTERS.HAS_PLAYER_UNITS:
				passes = len(lane.player_units) > 0
			LANE_PICK_FILTERS.HAS_ENEMY_UNITS:
				passes = len(lane.enemy_units) > 0
		if passes:
			passing_lanes.append(lane.lane_index)
	return passing_lanes
