## Attaches a lasting lane effect (BaseLaneEffect) to the picked lanes for the rest of combat.
## The play action of lane powers, usually as a child of ActionPickLanes so the player picks the lane.
## Applying the same effect again stacks its amount.
## Values:
## - lane_effect_script: String. Script path of a BaseLaneEffect, eg Scripts.LANE_EFFECT_UNIT_STAMINA_BONUS.
## - lane_effect_amount: int. Default 1.
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Default PLAYER.
## - lane_effect_name: String. Name shown in the lane badge's tooltip (defaults to the card's name).
extends BaseLaneAction

func perform_action() -> void:
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for action_interceptor_processor: ActionInterceptorProcessor in action_interceptor_processors:
		var lane_effect_script: String = action_interceptor_processor.get_shadowed_action_values("lane_effect_script", "")
		if lane_effect_script == "":
			DebugLogger.log_error("ActionApplyLaneEffect: No lane_effect_script given")
			return
		var amount: int = action_interceptor_processor.get_shadowed_action_values("lane_effect_amount", 1)
		var default_name: String = get_action_card_data().get_card_name() if get_action_card_data() != null else "Lane effect"
		var effect_values: Dictionary = {
			"unit_owner_filter": action_interceptor_processor.get_shadowed_action_values("unit_owner_filter", Unit.UNIT_OWNERS.PLAYER),
			"lane_effect_name": action_interceptor_processor.get_shadowed_action_values("lane_effect_name", default_name),
		}
		for lane_index: int in _get_picked_lanes():
			var lane: UnitLane = Battlefield.get_lane(lane_index)
			if lane != null:
				lane.add_lane_effect(lane_effect_script, amount, effect_values)

func _to_string() -> String:
	return "Apply Lane Effect Action: " + str(get_action_value("lane_effect_script", ""))
