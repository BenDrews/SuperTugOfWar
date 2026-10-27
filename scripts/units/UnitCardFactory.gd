## Builds Unit cards (CardData.CARD_TYPES.UNIT) with all the wiring they need:
## inherent Strength/Stamina values, the place-unit play action (pick a lane, then summon), no target,
## and the field pile as their play destination. Also defines the prototype's test unit and lane cards.
extends RefCounted
class_name UnitCardFactory

## Standard description prefix for unit cards. [unit_strength]/[unit_stamina] are replaced with
## (intercepted) values by Card.get_card_description().
const UNIT_DESCRIPTION: String = "Summon a unit\n[b]Strength[/b] [unit_strength]\n[b]Stamina[/b] [unit_stamina]"

## Creates (but does not register) a Unit card.
## extra_description is appended under the stats for units with additional effects.
## picks_position: when played, the player picks exactly where in their side of the lane the unit
## stands, instead of it joining the back of the line.
static func create_unit_card(object_id: String, card_name: String, unit_strength: int, unit_stamina: int,
energy_cost: int = 1, card_color_id: String = "color_white", card_rarity: int = CardData.CARD_RARITIES.COMMON,
extra_description: String = "", picks_position: bool = false) -> CardData:
	var card_data: CardData = CardData.new(object_id)
	card_data.card_name = card_name
	card_data.card_type = CardData.CARD_TYPES.UNIT
	card_data.card_rarity = card_rarity
	card_data.card_color_id = card_color_id
	var color_name: String = card_color_id.trim_prefix("color_")
	card_data.card_texture_path = "external/sprites/cards/{0}/card_{0}.png".format([color_name])
	card_data.card_energy_cost = energy_cost
	card_data.card_requires_target = false

	# inherent stats
	card_data.card_values = {
		CardData.UNIT_STRENGTH_KEY: unit_strength,
		CardData.UNIT_STAMINA_KEY: unit_stamina,
	}
	card_data.card_description = UNIT_DESCRIPTION
	if extra_description != "":
		card_data.card_description += "\n" + extra_description
	# show intercepted strength/stamina (green/red) on the card like damage/block do
	card_data.card_description_preview_overrides = [
		[CardData.UNIT_STRENGTH_KEY, Scripts.ACTION_SUMMON_UNIT],
		[CardData.UNIT_STAMINA_KEY, Scripts.ACTION_SUMMON_UNIT],
	]

	# playing the card picks a lane (and maybe a spot) and summons the unit there; the card waits in
	# the field pile until the unit is discarded
	card_data.card_play_actions = [{
		Scripts.ACTION_PLACE_UNIT: {"lane_pick_position": picks_position}
	}]
	card_data.card_play_destination = HandManager.UNIT_FIELD_PILE

	# default upgrade: +1 strength
	card_data.card_upgrade_value_improvements = {CardData.UNIT_STRENGTH_KEY: 1}

	return card_data

## Test unit cards for the prototype. Called from GlobalTestDataGenerator.generate_test_data().
## Also adds some to the red character's starting deck so they show up in the first combat.
static func add_test_unit_cards() -> void:
	# cheap, durable
	var card_unit_footman: CardData = create_unit_card("card_unit_footman", "Footman", 2, 3, 1, "color_white", CardData.CARD_RARITIES.BASIC)
	Global.register_rod(card_unit_footman)

	# strong but tires immediately
	var card_unit_brute: CardData = create_unit_card("card_unit_brute", "Brute", 5, 1, 1, "color_red", CardData.CARD_RARITIES.COMMON)
	Global.register_rod(card_unit_brute)

	# expensive, solid all round
	var card_unit_anchor: CardData = create_unit_card("card_unit_anchor", "Anchor", 4, 4, 2, "color_red", CardData.CARD_RARITIES.UNCOMMON)
	card_unit_anchor.card_upgrade_value_improvements = {CardData.UNIT_STRENGTH_KEY: 1, CardData.UNIT_STAMINA_KEY: 1}
	Global.register_rod(card_unit_anchor)

	# lets the player choose exactly where in the line it stands
	var card_unit_vanguard: CardData = create_unit_card("card_unit_vanguard", "Vanguard", 3, 2, 1, "color_red", CardData.CARD_RARITIES.COMMON, "Choose its spot in the line", true)
	Global.register_rod(card_unit_vanguard)
	
	add_test_lane_cards()
	
	# put them in the red character's starting deck for testing
	var character_red: CharacterData = Global.get_character_data("character_red")
	if character_red != null:
		for card_object_id: String in [
			"card_unit_footman", "card_unit_footman", "card_unit_brute", "card_unit_anchor", "card_unit_vanguard",
			"card_lane_fatigue", "card_lane_rally",
			"card_power_supply_line", "card_power_war_banner", "card_lane_second_wind",
			"card_power_rally_point", "card_power_spearhead",
			]:
			character_red.character_starting_card_object_ids.append(card_object_id)

## Creates (but does not register) a lane power: a POWER card that asks for a lane when played and
## puts a status effect on your side of that lane for the rest of combat (ActionPickLanes +
## ActionApplyStatus with status_target_type LANE).
## Powers that don't need a lane keep working as before: they put a status on the player and affect
## everything.
## description can use [status_charge_amount].
static func create_lane_power_card(object_id: String, card_name: String, description: String,
status_effect_object_id: String, status_charge_amount: int = 1, energy_cost: int = 1,
card_color_id: String = "color_red", card_rarity: int = CardData.CARD_RARITIES.UNCOMMON) -> CardData:
	var card_data: CardData = CardData.new(object_id)
	card_data.card_name = card_name
	card_data.card_type = CardData.CARD_TYPES.POWER
	card_data.card_rarity = card_rarity
	card_data.card_color_id = card_color_id
	var color_name: String = card_color_id.trim_prefix("color_")
	card_data.card_texture_path = "external/sprites/cards/{0}/card_{0}.png".format([color_name])
	card_data.card_energy_cost = energy_cost
	card_data.card_requires_target = false
	card_data.card_play_destination = HandManager.BANISH_PILE # powers banish
	card_data.card_values = {"status_charge_amount": status_charge_amount, "status_effect_object_id": status_effect_object_id}
	card_data.card_upgrade_value_improvements = {"status_charge_amount": 1}
	card_data.card_description = description
	card_data.card_play_actions = [{
		Scripts.ACTION_PICK_LANES: {
			"lane_pick_text": "Choose a lane for " + card_name,
			"action_data": [{
				Scripts.ACTION_APPLY_STATUS: {"status_target_type": StatusEffectHolder.STATUS_TARGET_TYPES.LANE}
			}],
		}
	}]
	return card_data

## Status effects for lanes and units, and the interceptors behind them.
static func add_test_lane_and_unit_statuses() -> void:
	# lane: your units placed here start with +N stamina
	var status_effect_lane_unit_stamina: StatusEffectData = StatusEffectData.new("status_effect_lane_unit_stamina")
	status_effect_lane_unit_stamina.status_effect_name = "Supply Line: units placed here start with extra stamina"
	status_effect_lane_unit_stamina.status_effect_texture_path = "external/sprites/status_effects/status_effect_green.png"
	status_effect_lane_unit_stamina.status_effect_type = StatusEffectData.STATUS_EFFECT_TYPES.BUFF
	status_effect_lane_unit_stamina.status_effect_action_process_times = [] # never decays; lasts the combat
	status_effect_lane_unit_stamina.status_effect_interceptor_ids = ["interceptor_lane_unit_stamina"]
	Global.register_rod(status_effect_lane_unit_stamina)
	var interceptor_lane_unit_stamina: ActionInterceptorData = ActionInterceptorData.new("interceptor_lane_unit_stamina")
	interceptor_lane_unit_stamina.action_interceptor_script_path = Scripts.INTERCEPTOR_LANE_UNIT_STAMINA_BONUS
	interceptor_lane_unit_stamina.action_intercepted_action_paths = [Scripts.ACTION_SUMMON_UNIT]
	interceptor_lane_unit_stamina.action_interceptor_priority = 1000
	Global.register_rod(interceptor_lane_unit_stamina)
	
	# lane: your units placed here start with +N strength
	var status_effect_lane_unit_strength: StatusEffectData = StatusEffectData.new("status_effect_lane_unit_strength")
	status_effect_lane_unit_strength.status_effect_name = "War Banner: units placed here start with extra strength"
	status_effect_lane_unit_strength.status_effect_texture_path = "external/sprites/status_effects/status_effect_red.png"
	status_effect_lane_unit_strength.status_effect_type = StatusEffectData.STATUS_EFFECT_TYPES.BUFF
	status_effect_lane_unit_strength.status_effect_action_process_times = []
	status_effect_lane_unit_strength.status_effect_interceptor_ids = ["interceptor_lane_unit_strength"]
	Global.register_rod(status_effect_lane_unit_strength)
	var interceptor_lane_unit_strength: ActionInterceptorData = ActionInterceptorData.new("interceptor_lane_unit_strength")
	interceptor_lane_unit_strength.action_interceptor_script_path = Scripts.INTERCEPTOR_LANE_UNIT_STRENGTH_BONUS
	interceptor_lane_unit_strength.action_intercepted_action_paths = [Scripts.ACTION_SUMMON_UNIT]
	interceptor_lane_unit_strength.action_interceptor_priority = 1000
	Global.register_rod(interceptor_lane_unit_strength)
	
	# lane placement hooks (ActionUnitPlacement): change where units land
	# rally point: your units placed in the lanes next to this one come here instead
	var status_effect_lane_rally_point: StatusEffectData = StatusEffectData.new("status_effect_lane_rally_point")
	status_effect_lane_rally_point.status_effect_name = "Rally Point: your units placed in neighbouring lanes are placed here instead"
	status_effect_lane_rally_point.status_effect_texture_path = "external/sprites/status_effects/status_effect_blue.png"
	status_effect_lane_rally_point.status_effect_charge_upper_bound = 1 # on or off
	status_effect_lane_rally_point.status_effect_action_process_times = []
	status_effect_lane_rally_point.status_effect_interceptor_ids = ["interceptor_lane_rally_point"]
	Global.register_rod(status_effect_lane_rally_point)
	var interceptor_lane_rally_point: ActionInterceptorData = ActionInterceptorData.new("interceptor_lane_rally_point")
	interceptor_lane_rally_point.action_interceptor_script_path = Scripts.INTERCEPTOR_LANE_RALLY_POINT
	interceptor_lane_rally_point.action_intercepted_action_paths = [Scripts.ACTION_UNIT_PLACEMENT]
	interceptor_lane_rally_point.action_interceptor_priority = 2000 # lane changes before position changes
	Global.register_rod(interceptor_lane_rally_point)
	
	# spearhead: your units placed in this lane go to the front of the line
	var status_effect_lane_spearhead: StatusEffectData = StatusEffectData.new("status_effect_lane_spearhead")
	status_effect_lane_spearhead.status_effect_name = "Spearhead: your units placed here go to the front of the line"
	status_effect_lane_spearhead.status_effect_texture_path = "external/sprites/status_effects/status_effect_purple.png"
	status_effect_lane_spearhead.status_effect_charge_upper_bound = 1
	status_effect_lane_spearhead.status_effect_action_process_times = []
	status_effect_lane_spearhead.status_effect_interceptor_ids = ["interceptor_lane_spearhead"]
	Global.register_rod(status_effect_lane_spearhead)
	var interceptor_lane_spearhead: ActionInterceptorData = ActionInterceptorData.new("interceptor_lane_spearhead")
	interceptor_lane_spearhead.action_interceptor_script_path = Scripts.INTERCEPTOR_LANE_SPEARHEAD
	interceptor_lane_spearhead.action_intercepted_action_paths = [Scripts.ACTION_UNIT_PLACEMENT]
	interceptor_lane_spearhead.action_interceptor_priority = 1000
	Global.register_rod(interceptor_lane_spearhead)
	
	# unit: at the start of its side's turn the unit regains 1 stamina; charges count down the turns
	var status_effect_second_wind: StatusEffectData = StatusEffectData.new("status_effect_second_wind")
	status_effect_second_wind.status_effect_name = "Second Wind: +1 stamina at the start of each turn"
	status_effect_second_wind.status_effect_texture_path = "external/sprites/status_effects/status_effect_yellow.png"
	status_effect_second_wind.status_effect_type = StatusEffectData.STATUS_EFFECT_TYPES.BUFF
	status_effect_second_wind.status_effect_decay_rate = -1
	status_effect_second_wind.status_effect_action_process_times = [
		StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DRAW_PLAYER_START_TURN, # player units
		StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_ENEMY_TURN, # enemy units
		]
	# the action acts on the unit holding the status (passed in automatically as invoking_status_units)
	var second_wind_actions: Array[Dictionary] = [{Scripts.ACTION_CHANGE_LANE_UNIT_STAMINA: {"stamina_change": 1, "time_delay": 0.2}}]
	status_effect_second_wind.status_effect_player_process_actions = second_wind_actions
	status_effect_second_wind.status_effect_enemy_process_actions = second_wind_actions
	Global.register_rod(status_effect_second_wind)

## Test cards that target a lane rather than an enemy, built on ActionPickLanes.
static func add_test_lane_cards() -> void:
	# every unit in a lane (both sides) loses stamina
	var card_lane_fatigue: CardData = CardData.new("card_lane_fatigue")
	card_lane_fatigue.card_name = "Fatigue"
	card_lane_fatigue.card_type = CardData.CARD_TYPES.SKILL
	card_lane_fatigue.card_rarity = CardData.CARD_RARITIES.COMMON
	card_lane_fatigue.card_color_id = "color_red"
	card_lane_fatigue.card_texture_path = "external/sprites/cards/red/card_red.png"
	card_lane_fatigue.card_energy_cost = 1
	card_lane_fatigue.card_requires_target = false
	card_lane_fatigue.card_values = {"stamina_change": -1}
	card_lane_fatigue.card_description = "Choose a lane. Every unit in it loses 1 stamina"
	card_lane_fatigue.card_first_upgrade_property_changes = {"card_energy_cost": 0}
	# can't be played into an empty battlefield
	card_lane_fatigue.card_play_validators = [{Scripts.VALIDATOR_LANE_PICKABLE: {"lane_pick_filter": ActionBasePickLanes.LANE_PICK_FILTERS.HAS_UNITS}}]
	card_lane_fatigue.card_play_actions = [{
		Scripts.ACTION_PICK_LANES: {
			"lane_pick_filter": ActionBasePickLanes.LANE_PICK_FILTERS.HAS_UNITS,
			"action_data": [{Scripts.ACTION_CHANGE_LANE_UNIT_STAMINA: {}}], # stamina_change comes from card_values
		}
	}]
	Global.register_rod(card_lane_fatigue)
	
	# your units in a lane pull harder
	var card_lane_rally: CardData = CardData.new("card_lane_rally")
	card_lane_rally.card_name = "Rally"
	card_lane_rally.card_type = CardData.CARD_TYPES.SKILL
	card_lane_rally.card_rarity = CardData.CARD_RARITIES.COMMON
	card_lane_rally.card_color_id = "color_red"
	card_lane_rally.card_texture_path = "external/sprites/cards/red/card_red.png"
	card_lane_rally.card_energy_cost = 1
	card_lane_rally.card_requires_target = false
	card_lane_rally.card_values = {"strength_change": 2}
	card_lane_rally.card_upgrade_value_improvements = {"strength_change": 1}
	card_lane_rally.card_description = "Choose a lane. Your units in it gain [strength_change] strength"
	card_lane_rally.card_play_validators = [{Scripts.VALIDATOR_LANE_PICKABLE: {"lane_pick_filter": ActionBasePickLanes.LANE_PICK_FILTERS.HAS_PLAYER_UNITS}}]
	card_lane_rally.card_play_actions = [{
		Scripts.ACTION_PICK_LANES: {
			"lane_pick_filter": ActionBasePickLanes.LANE_PICK_FILTERS.HAS_PLAYER_UNITS,
			"lane_pick_text": "Choose a lane to rally",
			"action_data": [{Scripts.ACTION_CHANGE_LANE_UNIT_STRENGTH: {"unit_owner_filter": Unit.UNIT_OWNERS.PLAYER}}],
		}
	}]
	Global.register_rod(card_lane_rally)
	
	add_test_lane_and_unit_statuses()
	
	# lane powers: put a status on your side of the chosen lane for the whole combat
	var card_power_supply_line: CardData = create_lane_power_card("card_power_supply_line", "Supply Line",
		"Choose a lane. Your units placed there start with +[status_charge_amount] stamina",
		"status_effect_lane_unit_stamina", 1, 1)
	Global.register_rod(card_power_supply_line)
	
	var card_power_war_banner: CardData = create_lane_power_card("card_power_war_banner", "War Banner",
		"Choose a lane. Your units placed there start with +[status_charge_amount] strength",
		"status_effect_lane_unit_strength", 1, 1)
	Global.register_rod(card_power_war_banner)
	
	# lane powers that change where your units land (ActionUnitPlacement hooks)
	var card_power_rally_point: CardData = create_lane_power_card("card_power_rally_point", "Rally Point",
		"Choose a lane. Your units placed in the lanes next to it are placed there instead",
		"status_effect_lane_rally_point", 1, 1)
	card_power_rally_point.card_upgrade_value_improvements = {}
	card_power_rally_point.card_first_upgrade_property_changes = {"card_energy_cost": 0}
	Global.register_rod(card_power_rally_point)
	
	var card_power_spearhead: CardData = create_lane_power_card("card_power_spearhead", "Spearhead",
		"Choose a lane. Your units placed there go to the front of the line",
		"status_effect_lane_spearhead", 1, 0)
	card_power_spearhead.card_upgrade_value_improvements = {}
	Global.register_rod(card_power_spearhead)
	
	# unit status: applied to each of your units in the chosen lane
	var card_lane_second_wind: CardData = CardData.new("card_lane_second_wind")
	card_lane_second_wind.card_name = "Second Wind"
	card_lane_second_wind.card_type = CardData.CARD_TYPES.SKILL
	card_lane_second_wind.card_rarity = CardData.CARD_RARITIES.COMMON
	card_lane_second_wind.card_color_id = "color_red"
	card_lane_second_wind.card_texture_path = "external/sprites/cards/red/card_red.png"
	card_lane_second_wind.card_energy_cost = 1
	card_lane_second_wind.card_requires_target = false
	card_lane_second_wind.card_values = {"status_charge_amount": 2, "status_effect_object_id": "status_effect_second_wind"}
	card_lane_second_wind.card_upgrade_value_improvements = {"status_charge_amount": 1}
	card_lane_second_wind.card_description = "Choose a lane. Your units there gain [status_charge_amount] Second Wind (+1 stamina at the start of each turn)"
	card_lane_second_wind.card_play_validators = [{Scripts.VALIDATOR_LANE_PICKABLE: {"lane_pick_filter": ActionBasePickLanes.LANE_PICK_FILTERS.HAS_PLAYER_UNITS}}]
	card_lane_second_wind.card_play_actions = [{
		Scripts.ACTION_PICK_LANES: {
			"lane_pick_filter": ActionBasePickLanes.LANE_PICK_FILTERS.HAS_PLAYER_UNITS,
			"action_data": [{Scripts.ACTION_APPLY_STATUS: {"status_target_type": StatusEffectHolder.STATUS_TARGET_TYPES.UNIT}}],
		}
	}]
	Global.register_rod(card_lane_second_wind)
