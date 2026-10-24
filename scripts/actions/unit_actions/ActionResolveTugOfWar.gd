## The tug of war for one lane. Compares the total strength of the player's units against the enemy's
## units in that lane, and the weaker side takes damage equal to the difference. Ties do nothing.
## Generated once per lane at the end of the player's turn by
## ActionGenerator.generate_end_of_turn_unit_actions(), before unit stamina decays, so a unit always
## pulls at least once. Lanes resolve top to bottom, each with its own damage.
## The damage is an ActionDirectDamage, so block absorbs it.
## Values:
## - lane_index: int. The lane to resolve. Default 0.
## - player_strength_bonus / enemy_strength_bonus: int. Added to each side's total. Default 0.
##   Intercept these for effects like "your side pulls +3 this turn".
## - tug_damage_multiplier: int. Multiplies the difference. Default 1.
## - bypass_block: bool. If tug damage ignores block. Default false.
## NOTE: When the enemy side loses a lane, the frontmost living enemy takes the damage. Per-lane
## opponents (eg enemy N owns lane N) would slot in here.
extends BaseAction

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
