## Places a Unit on the battlefield. This is the play action of every Unit card (see UnitCardFactory).
## Values (pulled through the normal hierarchy, so they usually come from the card's card_values):
## - unit_strength: int. How hard the unit pulls.
## - unit_stamina: int. How many end-of-turns the unit survives before it is discarded.
## - unit_name: String. Optional display name, defaults to the card's name.
## Both stats can be intercepted (eg an artifact giving +1 strength to every unit summoned).
## NOTE: The Unit card itself is sent to HandManager.UNIT_FIELD_PILE by its card_play_destination, and
## moved to the discard pile when the Unit is discarded.
extends BaseAction

func perform_action() -> void:
	# units aren't combatants, so intercept with no targets (parent/player interceptors still apply)
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])

	var card_data: CardData = get_action_card_data()
	var default_name: String = "Unit"
	if card_data != null:
		default_name = card_data.get_card_name()

	for action_interceptor_processor: ActionInterceptorProcessor in action_interceptor_processors:
		var unit_strength: int = action_interceptor_processor.get_shadowed_action_values(CardData.UNIT_STRENGTH_KEY, 0)
		var unit_stamina: int = action_interceptor_processor.get_shadowed_action_values(CardData.UNIT_STAMINA_KEY, 1)
		var unit_name: String = action_interceptor_processor.get_shadowed_action_values("unit_name", default_name)

		if unit_stamina <= 0:
			# a unit with no stamina would be discarded immediately; its card is swept to the discard
			# pile at end of turn by UnitContainer.release_orphaned_field_cards()
			DebugLogger.log_error("ActionSummonUnit: Unit \"{0}\" has no stamina and was not summoned".format([unit_name]))
			continue

		Signals.unit_spawn_requested.emit(card_data, unit_name, max(unit_strength, 0), unit_stamina)

func _to_string() -> String:
	return "Summon Unit Action: STR {0} / STA {1}".format([
		get_action_value(CardData.UNIT_STRENGTH_KEY, 0),
		get_action_value(CardData.UNIT_STAMINA_KEY, 1),
		])
