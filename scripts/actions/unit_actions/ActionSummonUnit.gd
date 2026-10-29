## Places a Unit on the battlefield in a given lane. Unit cards reach this through ActionPlaceUnit,
## which picks the lane first. Enemy intents can use it directly.
## Values (pulled through the normal hierarchy, so they usually come from the card's card_values):
## - unit_strength: int. How hard the unit pulls.
## - unit_stamina: int. How many end-of-turns the unit survives before it is discarded.
## - unit_name: String. Optional display name, defaults to the card's name.
## - unit_owner: int (Unit.UNIT_OWNERS). Which side the unit pulls for. Defaults to automatic:
##   ENEMY if the action's parent is an Enemy (eg an enemy intent), otherwise PLAYER.
## - lane_index: int. Lane to place the unit in. -1 (default) means no lane chosen yet: a player's
##   unit hands off to ActionPlaceUnit so the player picks one, an enemy's unit goes in a random lane.
## - lane_random: bool. Force a random lane even for player units. Default false.
## - lane_position: int. Index within the owner's side of the lane, 0 = front. -1 (default) = back of the line.
## Both stats can be intercepted (eg an artifact giving +1 strength to every unit summoned), including
## by statuses on the destination lane's side for the new unit (see get_status_context_holders()).
## NOTE: lane_index and unit_owner are settled before interception (they decide which lane statuses
## apply), so interceptors can't redirect a unit to another lane or side.
## NOTE: The Unit card itself is sent to HandManager.UNIT_FIELD_PILE by its card_play_destination, and
## moved to the discard pile when the Unit is discarded.
extends BaseAction

var _resolved_lane_index: int = -1
var _resolved_unit_owner: int = Unit.UNIT_OWNERS.PLAYER

## The destination lane's statuses for the new unit's side intercept this action.
func get_status_context_holders() -> Array[Object]:
	var lane: UnitLane = Battlefield.get_lane(_resolved_lane_index)
	if lane == null:
		return []
	return [lane.get_status_holder(_resolved_unit_owner)]

func perform_action() -> void:
	# a player unit with no lane yet (eg a card saved before lanes existed, or one written with a bare
	# summon) gets the lane pick from ActionPlaceUnit, which then runs this action again with a lane
	if _needs_player_lane_pick():
		var place_values: Dictionary = values.duplicate()
		place_values.erase("lane_index")
		var place_actions: Array[BaseAction] = ActionGenerator.create_actions(parent_combatant, card_play_request, targets, [{Scripts.ACTION_PLACE_UNIT: place_values}], self)
		ActionHandler.add_actions(place_actions)
		return
	
	# settle the lane and side first: the destination lane's statuses for that side get to intercept
	# this (eg a lane power giving units placed there +1 stamina). See get_status_context_holders().
	_resolved_unit_owner = get_action_value("unit_owner", Unit.UNIT_OWNER_AUTOMATIC)
	if _resolved_unit_owner == Unit.UNIT_OWNER_AUTOMATIC:
		_resolved_unit_owner = Unit.UNIT_OWNERS.ENEMY if parent_combatant is Enemy else Unit.UNIT_OWNERS.PLAYER
	_resolved_lane_index = get_action_value("lane_index", -1)
	if _resolved_lane_index < 0 or _resolved_lane_index >= Battlefield.LANE_COUNT:
		var rng_name: String = get_action_value("rng_name", "rng_lane_picking")
		_resolved_lane_index = Global.player_data.get_player_rng(rng_name).randi_range(0, Battlefield.LANE_COUNT - 1)
	
	# units aren't combatants, so intercept with no targets (parent/player and lane interceptors still apply)
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])

	var card_data: CardData = get_action_card_data()
	var default_name: String = "Unit"
	if card_data != null:
		default_name = card_data.get_card_name()
	elif parent_combatant is Enemy:
		default_name = (parent_combatant as Enemy).enemy_data.enemy_name + " Unit"

	for action_interceptor_processor: ActionInterceptorProcessor in action_interceptor_processors:
		var unit_strength: int = action_interceptor_processor.get_shadowed_action_values(CardData.UNIT_STRENGTH_KEY, 0)
		var unit_stamina: int = action_interceptor_processor.get_shadowed_action_values(CardData.UNIT_STAMINA_KEY, 1)
		var unit_name: String = action_interceptor_processor.get_shadowed_action_values("unit_name", default_name)
		var unit_owner: int = _resolved_unit_owner
		var lane_position: int = action_interceptor_processor.get_shadowed_action_values("lane_position", -1)
		var lane_index: int = _resolved_lane_index
		
		if unit_stamina <= 0:
			# a unit with no stamina would be discarded immediately; its card is swept to the discard
			# pile at end of turn by Battlefield.release_orphaned_field_cards()
			DebugLogger.log_error("ActionSummonUnit: Unit \"{0}\" has no stamina and was not summoned".format([unit_name]))
			continue

		Signals.unit_spawn_requested.emit(card_data, unit_name, max(unit_strength, 0), unit_stamina, unit_owner, lane_index, lane_position)

## True when this would place a player-owned unit without a lane having been picked.
func _needs_player_lane_pick() -> bool:
	if get_action_value("lane_random", false):
		return false
	var lane_index: int = get_action_value("lane_index", -1)
	if lane_index >= 0 and lane_index < Battlefield.LANE_COUNT:
		return false
	var unit_owner: int = get_action_value("unit_owner", Unit.UNIT_OWNER_AUTOMATIC)
	if unit_owner == Unit.UNIT_OWNER_AUTOMATIC:
		unit_owner = Unit.UNIT_OWNERS.ENEMY if parent_combatant is Enemy else Unit.UNIT_OWNERS.PLAYER
	return unit_owner == Unit.UNIT_OWNERS.PLAYER

func _to_string() -> String:
	return "Summon Unit Action: STR {0} / STA {1}".format([
		get_action_value(CardData.UNIT_STRENGTH_KEY, 0),
		get_action_value(CardData.UNIT_STAMINA_KEY, 1),
		])
