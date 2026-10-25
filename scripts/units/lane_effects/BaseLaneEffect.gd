## A lasting effect attached to one lane for the rest of combat, usually by a lane power card
## (see ActionApplyLaneEffect). The lane equivalent of a status effect on a combatant.
## Extend and override the hooks you need; UnitLane shows each effect as a badge with a tooltip.
## Effects with the same script and values stack by adding their amounts.
## Values (set from the applying action):
## - unit_owner_filter: int (Unit.UNIT_OWNERS, or -1 for both sides). Whose units are affected. Default PLAYER.
## - lane_effect_name: String. Display name for the tooltip.
extends RefCounted
class_name BaseLaneEffect

## Script path this effect was created from. Used to stack identical effects.
var lane_effect_script_path: String = ""
## Stacking magnitude, eg +1 stamina.
var amount: int = 0
var values: Dictionary = {}
var lane_index: int = 0

func init(_lane_effect_script_path: String, _amount: int, _values: Dictionary, _lane_index: int) -> void:
	lane_effect_script_path = _lane_effect_script_path
	amount = _amount
	values = _values
	lane_index = _lane_index

## True if another application should stack onto this one instead of adding a new effect.
func stacks_with(script_path: String, other_values: Dictionary) -> bool:
	return script_path == lane_effect_script_path and other_values.get("unit_owner_filter", Unit.UNIT_OWNERS.PLAYER) == get_unit_owner_filter()

func get_unit_owner_filter() -> int:
	return values.get("unit_owner_filter", Unit.UNIT_OWNERS.PLAYER)

func affects_owner(unit_owner: int) -> bool:
	var unit_owner_filter: int = get_unit_owner_filter()
	return unit_owner_filter == Unit.UNIT_OWNER_AUTOMATIC or unit_owner_filter == unit_owner

func _get_owner_text() -> String:
	match get_unit_owner_filter():
		Unit.UNIT_OWNERS.PLAYER: return "Your units"
		Unit.UNIT_OWNERS.ENEMY: return "Enemy units"
	return "All units"

### Override

## Called by ActionSummonUnit before a unit is placed in this lane. summon has keys
## unit_strength, unit_stamina, unit_owner, unit_name; modify them in place.
func modify_unit_summon(_summon: Dictionary) -> void:
	pass

## Short badge text, eg "+1 STA".
func get_badge_text() -> String:
	return str(amount)

## Tooltip text.
func get_description() -> String:
	return values.get("lane_effect_name", "Lane effect")
