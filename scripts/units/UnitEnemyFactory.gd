## Test enemies that put Units on the battlefield, so the tug of war has two sides.
## Enemies have one intent per lane (EnemyData.add_lane_intents()). An intent that summons a unit uses
## ActionSummonUnit as a custom action; the unit goes into the intent's lane and belongs to the enemy
## side because the action's parent is an Enemy.
extends RefCounted
class_name UnitEnemyFactory

const DIFFICULTY_STARTING: int = 0
const DIFFICULTY_STANDARD_ENEMIES_HARDER: int = 1

## Returns intent custom actions that summon one enemy unit.
static func summon_unit_actions(unit_name: String, unit_strength: int, unit_stamina: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = [{
		Scripts.ACTION_SUMMON_UNIT: {
			"unit_name": unit_name,
			CardData.UNIT_STRENGTH_KEY: unit_strength,
			CardData.UNIT_STAMINA_KEY: unit_stamina,
			"time_delay": 0.5,
		}
	}]
	return actions

## Called from GlobalTestDataGenerator.generate_test_data(), after events are generated.
static func add_test_unit_enemies() -> void:
	# a rival that fields its own pullers and occasionally attacks directly
	var enemy_tug_rival: EnemyData = EnemyData.new("enemy_tug_rival")
	enemy_tug_rival.enemy_name = "Rival Puller"
	enemy_tug_rival.add_health_bounds(30, 34)
	enemy_tug_rival.add_health_bounds(38, 42, DIFFICULTY_STANDARD_ENEMIES_HARDER)
	enemy_tug_rival.enemy_texture_path = "external/sprites/enemies/enemy_yellow_medium.png"

	# one intent per lane each turn, each lane walking this graph on its own.
	# NOTE: 0 attacks is required for non-attacking intents, otherwise an attack is inferred
	var next_intent_weights: Dictionary[String, int] = {"intent_summon_grunt": 3, "intent_summon_hulk": 1, "intent_attack": 1, "intent_guard": 1, "intent_rest": 2}
	enemy_tug_rival.add_intent_state([
		EnemyIntentData.new("intent_summon_grunt", DIFFICULTY_STARTING, 0, 0, "", 0, "", next_intent_weights,
			summon_unit_actions("Grunt", 3, 2)),
		EnemyIntentData.new("intent_summon_grunt", DIFFICULTY_STANDARD_ENEMIES_HARDER, 0, 0, "", 0, "", next_intent_weights,
			summon_unit_actions("Grunt", 4, 2)),
		])
	enemy_tug_rival.add_intent_state([
		EnemyIntentData.new("intent_summon_hulk", DIFFICULTY_STARTING, 0, 0, "", 0, "", next_intent_weights,
			summon_unit_actions("Hulk", 6, 1)),
		])
	enemy_tug_rival.add_intent_state([
		EnemyIntentData.new("intent_attack", DIFFICULTY_STARTING, 5, 1, "animation_vfx_impact_default", 0, "", next_intent_weights),
		])
	enemy_tug_rival.add_intent_state([
		EnemyIntentData.new("intent_guard", DIFFICULTY_STARTING, 0, 0, "", 6, "", next_intent_weights),
		])
	enemy_tug_rival.add_intent_state([
		EnemyIntentData.new("intent_rest", DIFFICULTY_STARTING, 0, 0, "", 0, "", next_intent_weights),
		])
	# how each lane opens: the top and bottom lanes field units, the middle lane varies
	enemy_tug_rival.add_lane_intents([
		{"intent_summon_grunt": 1},
		{"intent_attack": 1, "intent_guard": 1, "intent_rest": 1},
		{"intent_summon_grunt": 1, "intent_summon_hulk": 1},
		])
	
	var _enemy_tug_rival_anim: AnimationData = enemy_tug_rival.add_standard_animations(
		["external/sprites/enemies/enemy_yellow_medium.png"]
	)
	Global.register_rod(enemy_tug_rival)

	# combat event with the rival, added to the act 1 easy combat pool
	var event_tug_rival: EventData = EventData.new("event_act_1_tug_rival")
	event_tug_rival.event_death_message_bbcode = "Out-pulled by a rival"
	event_tug_rival.event_weighted_enemy_object_ids = [
		{"enemy_tug_rival": 1},
		]
	Global.register_rod(event_tug_rival)

	var event_pool_act_1_easy: EventPoolData = Global.get_event_pool_data("event_pool_act_1_easy")
	if event_pool_act_1_easy != null:
		event_pool_act_1_easy.add_events_to_pool(null, [event_tug_rival])
