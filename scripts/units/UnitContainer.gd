## Holds and lays out the Units on the battlefield. Created by Combat in code.
## Spawns units on Signals.unit_spawn_requested and clears them when combat or the run ends.
## Also provides static helpers for querying units from actions.
## NOTE: Lanes will slot in here later: one row/column per lane, with spawn requests carrying a lane index.
extends Control
class_name UnitContainer

const UNIT_SEPARATION: int = 8

var _unit_flow: HFlowContainer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_unit_flow = HFlowContainer.new()
	_unit_flow.name = "UnitFlow"
	_unit_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_flow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unit_flow.add_theme_constant_override("h_separation", UNIT_SEPARATION)
	_unit_flow.add_theme_constant_override("v_separation", UNIT_SEPARATION)
	add_child(_unit_flow)

	# played unit cards fly here instead of to the discard pile
	HandManager.card_destination_to_ui_elements[HandManager.UNIT_FIELD_PILE] = self

	Signals.unit_spawn_requested.connect(_on_unit_spawn_requested)
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_run_ended)

func spawn_unit(card_data: CardData, unit_name: String, unit_strength: int, unit_stamina: int) -> Unit:
	var unit: Unit = Unit.new()
	_unit_flow.add_child(unit)
	unit.init(card_data, unit_name, unit_strength, unit_stamina)
	Signals.unit_spawned.emit(unit)
	return unit

## Removes all units without moving their cards. The combat deck is rebuilt from the
## player's deck at the start of each combat, so field cards don't need returning.
func clear_units() -> void:
	for child: Node in _unit_flow.get_children():
		if child is Unit:
			child.clear_unit()
		else:
			child.queue_free()

#region Static Helpers
## Returns all live units on the battlefield, in summon order.
static func get_units() -> Array[Unit]:
	var units: Array[Unit] = []
	units.assign(Global.get_tree().get_nodes_in_group(Unit.UNITS_GROUP))
	return units

## Total strength of all live units. Starting point for tug-of-war resolution.
static func get_total_strength() -> int:
	var total: int = 0
	for unit: Unit in get_units():
		total += unit.unit_strength
	return total

## Returns if any live unit was summoned by the given card.
static func is_card_on_field(card_data: CardData) -> bool:
	for unit: Unit in get_units():
		if unit.card_data == card_data:
			return true
	return false

## Moves any card in the field pile that no longer has a live unit to the discard pile.
## Covers edge cases like a summon being rejected by an interceptor.
static func release_orphaned_field_cards() -> void:
	for card_data: CardData in HandManager.get_pile(HandManager.UNIT_FIELD_PILE):
		if not is_card_on_field(card_data):
			HandManager.move_card_to_pile(card_data, HandManager.UNIT_FIELD_PILE, HandManager.DISCARD_PILE, HandManager.PILE_INSERTION_STRATEGIES.TOP, HandManager.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX, true, true)
#endregion

func _on_unit_spawn_requested(card_data: CardData, unit_name: String, unit_strength: int, unit_stamina: int) -> void:
	spawn_unit(card_data, unit_name, unit_strength, unit_stamina)

func _on_combat_started(_event_id: String) -> void:
	clear_units()

func _on_combat_ended() -> void:
	clear_units()

func _on_run_ended() -> void:
	clear_units()
