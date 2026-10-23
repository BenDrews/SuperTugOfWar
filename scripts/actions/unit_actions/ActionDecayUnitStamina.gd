## Every Unit on the battlefield loses stamina. Units that reach 0 stamina are discarded, which also
## sends their card to the discard pile.
## Generated at the end of the player's turn by ActionGenerator.generate_end_of_turn_unit_actions().
## Values:
## - stamina_decay: int. Stamina lost per unit. Defaults to 1. Intercept to make units tire faster/slower.
extends BaseAction

func perform_action() -> void:
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])

	for action_interceptor_processor: ActionInterceptorProcessor in action_interceptor_processors:
		var stamina_decay: int = action_interceptor_processor.get_shadowed_action_values("stamina_decay", 1)

		for unit: Unit in UnitContainer.get_units():
			unit.change_stamina(-stamina_decay)
			if unit.unit_stamina <= 0:
				unit.discard_unit()

	# safety net: any unit card stuck in the field pile without a unit goes to the discard pile
	UnitContainer.release_orphaned_field_cards()

func _to_string() -> String:
	return "Decay Unit Stamina Action: " + str(get_action_value("stamina_decay", 1))
