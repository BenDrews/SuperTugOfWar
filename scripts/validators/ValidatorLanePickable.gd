## Passes if at least one lane matches a lane filter. Use as a card play validator so lane-targeting
## cards can't be played when there's nothing to pick.
## Values:
## - lane_pick_filter: int (ActionBasePickLanes.LANE_PICK_FILTERS). Default ANY.
## - lane_minimum: int. Minimum number of matching lanes. Default 1.
extends BaseValidator

func _validation(_card_data: CardData, action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var lane_pick_filter: int = _get_validator_value("lane_pick_filter", values, action, ActionBasePickLanes.LANE_PICK_FILTERS.ANY)
	var lane_minimum: int = _get_validator_value("lane_minimum", values, action, 1)
	return len(ActionBasePickLanes.get_lanes_passing_filter(lane_pick_filter)) >= lane_minimum
