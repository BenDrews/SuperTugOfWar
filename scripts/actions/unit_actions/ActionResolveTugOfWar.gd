## The tug of war for one lane. Compares the total strength of the player's units against the enemy's
## units in that lane; if the side given by damaged_owner is weaker, it takes damage equal to the
## difference. Ties do nothing.
## Each side is only pulled at the end of its own turn (see ActionGenerator.generate_end_of_turn_unit_actions()):
## - end of the player's turn: the player takes damage from lanes where the enemy is stronger
## - end of the enemy's turn, after its intents: the enemy takes damage from lanes where the player is stronger
## Lanes resolve top to bottom, each with its own damage.
## The damage is an ActionDirectDamage, so block absorbs it.
## Values:
## - lane_index: int. The lane to resolve. Default 0.
## - damaged_owner: int (Unit.UNIT_OWNERS). The side that can take damage this resolution.
##   -1 lets whichever side is weaker take damage. Default -1.
## - player_strength_bonus / enemy_strength_bonus: int. Added to each side's total. Default 0.
##   Intercept these for effects like "your side pulls +3 this turn".
## - tug_damage_multiplier: int. Multiplies the difference. Default 1.
## - bypass_block: bool. If tug damage ignores block. Default false.
## NOTE: When the enemy side loses a lane, the frontmost living enemy takes the damage. Per-lane
## opponents (eg enemy N owns lane N) would slot in here.
extends BaseAction

## Statuses on both sides of the lane being resolved intercept it (eg to add a strength bonus).
## Interceptors can tell sides apart with (source as StatusEffectHolder).get_side().
func get_status_context_holders() -> Array[Object]:
	var lane: UnitLane = Battlefield.get_lane(get_action_value("lane_index", 0))
	if lane == null:
		return []
	return [lane.player_status_holder, lane.enemy_status_holder]

func perform_action() -> void:
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])

	for action_interceptor_processor: ActionInterceptorProcessor in action_interceptor_processors:
		var lane_index: int = action_interceptor_processor.get_shadowed_action_values("lane_index", 0)
		var player_strength: int = Battlefield.get_total_strength(Unit.UNIT_OWNERS.PLAYER, lane_index)
		var enemy_strength: int = Battlefield.get_total_strength(Unit.UNIT_OWNERS.ENEMY, lane_index)
		player_strength += action_interceptor_processor.get_shadowed_action_values("player_strength_bonus", 0)
		enemy_strength += action_interceptor_processor.get_shadowed_action_values("enemy_strength_bonus", 0)
		player_strength = max(player_strength, 0)
		enemy_strength = max(enemy_strength, 0)

		var tug_damage_multiplier: int = action_interceptor_processor.get_shadowed_action_values("tug_damage_multiplier", 1)
		var bypass_block: bool = action_interceptor_processor.get_shadowed_action_values("bypass_block", false)
		var damage: int = abs(player_strength - enemy_strength) * max(tug_damage_multiplier, 0)

		Signals.tug_of_war_resolved.emit(lane_index, player_strength, enemy_strength)

		if damage <= 0:
			continue # tie, nobody budges
		
		# only the side whose turn is ending can be pulled
		var damaged_owner: int = action_interceptor_processor.get_shadowed_action_values("damaged_owner", Unit.UNIT_OWNER_AUTOMATIC)
		var weaker_owner: int = Unit.UNIT_OWNERS.PLAYER if player_strength < enemy_strength else Unit.UNIT_OWNERS.ENEMY
		if damaged_owner != Unit.UNIT_OWNER_AUTOMATIC and damaged_owner != weaker_owner:
			continue

		var player: Player = Global.get_player()
		var alive_enemies: Array[Enemy] = Global.get_alive_enemies()
		if player == null or len(alive_enemies) == 0:
			continue
		var front_enemy: Enemy = alive_enemies[0]

		# the stronger side "pulls" the weaker side, so it's the parent of the damage
		var damage_parent: BaseCombatant = player
		var damage_target: BaseCombatant = front_enemy
		if player_strength < enemy_strength:
			damage_parent = front_enemy
			damage_target = player

		var damage_action_data: Array[Dictionary] = [{
			Scripts.ACTION_DIRECT_DAMAGE: {
				"damage": damage,
				"bypass_block": bypass_block,
				"time_delay": 0.4,
				"action_tags": ["tug_of_war"], # lets interceptors single out tug damage
			}
		}]
		var damage_actions: Array[BaseAction] = ActionGenerator.create_actions(damage_parent, null, [damage_target], damage_action_data, self)
		ActionHandler.add_actions(damage_actions)

func _to_string() -> String:
	return "Resolve Tug of War Action: lane " + str(get_action_value("lane_index", 0))
