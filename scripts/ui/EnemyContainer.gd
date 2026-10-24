## Handles containing enemies and spawning them
## Can handle both automatic placement and slot based placement for
## enemies based on EventData.event_enemy_placement_is_automatic positioning type.
## Super Tug of War: enemies stand in a column on the right of the lanes. When they don't fit at full
## size, the whole column is scaled down to fit (see _fit_enemies()).
extends Control

@onready var automatic_enemy_container: BoxContainer = $AutomaticEnemyContainer
@onready var positional_enemy_container: Control = $PositionalEnemyContainer

## Vertical space each enemy needs, including intent icons above and statuses below.
const ENEMY_SLOT_HEIGHT: float = 250.0

func _ready():
	Signals.run_ended.connect(_on_run_ended)
	Signals.enemy_spawn_requested.connect(_on_enemy_spawn_requested)
	automatic_enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	automatic_enemy_container.add_theme_constant_override("separation", 0)

func populate_enemies_from_event(event_data: EventData = Global.get_player_event_data()):
	# populates initial enemies from an event
	clear_enemies()
	
	# determine which container to use
	var enemy_container: Control = automatic_enemy_container
	
	if not event_data.event_enemy_placement_is_automatic:
		enemy_container = positional_enemy_container
		
		# check if spawns will be out of bounds
		# spawns will still happen but not go beyond that
		if not event_data.event_enemy_placement_is_automatic:
			if len(event_data.event_enemy_placement_positions) < len(event_data.event_weighted_enemy_object_ids):
				DebugLogger.log_error("EnemyContainer: Enemy spawns \"{0}\" exceed number of positions \"{1}\" in event \"{2}\"".format([
					len(event_data.event_weighted_enemy_object_ids),
					len(event_data.event_enemy_placement_positions),
					event_data.object_id,
				]))
	
	# spawn enemies using random weights
	var enemy_counter: int = 0
	for enemy_weights: Dictionary in event_data.event_weighted_enemy_object_ids:
		var rng_enemy_spawning: RandomNumberGenerator = Global.player_data.get_player_rng("rng_enemy_spawning")
		var weights: Dictionary[Variant, int] = {}
		weights.assign(enemy_weights)
		# get an enemy id
		var enemy_object_id: String = Random.get_weighted_selection(rng_enemy_spawning, weights)
		
		# stop spawning when positions exceeded
		if not event_data.event_enemy_placement_is_automatic:
			if len(event_data.event_enemy_placement_positions) <= enemy_counter:
				break
		
		if event_data.event_enemy_placement_is_automatic:
			var _enemy: Enemy = _spawn_enemy(enemy_object_id, enemy_container)
		else:
			var _enemy: Enemy = spawn_enemy_at_slot(enemy_object_id, enemy_counter)
		
		enemy_counter += 1
	
	_fit_enemies()

## Helper function for spawning enemies. Supplied a container for either automatic placement or
## positional placement depending on the event.
func _spawn_enemy(enemy_object_id: String, container: Control = automatic_enemy_container) -> Enemy:
	
	var enemy: Enemy = Scenes.ENEMY.instantiate()
	var enemy_data: EnemyData = Global.get_enemy_data_from_prototype(enemy_object_id)
	
	enemy_data.apply_enemy_difficulty_modifiers()
	enemy_data.randomize_health(true)
	
	container.add_child(enemy)
	enemy.init(enemy_data)
	# stack enemies in a centered column, each with room for intents and statuses
	enemy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy.custom_minimum_size.y = ENEMY_SLOT_HEIGHT
	
	return enemy

func spawn_enemy_at_slot(enemy_object_id: String, slot_id: int) -> Enemy:
	var enemy: Enemy = _spawn_enemy(enemy_object_id, positional_enemy_container)
	enemy.enemy_slot = slot_id
	
	# determine non automatic enemy position
	var event_data: EventData = Global.get_player_event_data()
	if len(event_data.event_enemy_placement_positions) > slot_id:
		var pos: Array = event_data.event_enemy_placement_positions[slot_id]
		var enemy_position: Vector2 = Vector2(pos[0], pos[1])
		enemy.position = enemy_position
	else:
		DebugLogger.log_error("EnemyContainer: Spawn slot at index \"{0}\" undefined in event \"{1}\"".format([slot_id, event_data.object_id]))
	
	return enemy

## Scales the enemy column so every enemy fits in this container's rect, never scaling above 1.
func _fit_enemies() -> void:
	# automatic placement: n stacked slots
	var automatic_enemy_count: int = 0
	for child: Node in automatic_enemy_container.get_children():
		if not child.is_queued_for_deletion():
			automatic_enemy_count += 1
	var automatic_scale: float = 1.0
	if automatic_enemy_count > 0:
		automatic_scale = min(1.0, size.y / (automatic_enemy_count * ENEMY_SLOT_HEIGHT))
	_apply_fit_scale(automatic_enemy_container, automatic_scale)
	
	# positional placement: fit the lowest/rightmost slot
	var content_size: Vector2 = Vector2.ZERO
	for child: Node in positional_enemy_container.get_children():
		if child is Control and not child.is_queued_for_deletion():
			content_size.x = max(content_size.x, child.position.x + child.size.x)
			content_size.y = max(content_size.y, child.position.y + ENEMY_SLOT_HEIGHT)
	var positional_scale: float = 1.0
	if content_size.y > 0:
		positional_scale = min(1.0, size.y / content_size.y, size.x / content_size.x)
	_apply_fit_scale(positional_enemy_container, positional_scale)

func _apply_fit_scale(container: Control, fit_scale: float) -> void:
	container.scale = Vector2(fit_scale, fit_scale)
	container.size = size / fit_scale # lay out in unscaled units across the whole rect
	container.position = Vector2.ZERO

func clear_enemies():
	for child in automatic_enemy_container.get_children():
		child.queue_free()
	for child in positional_enemy_container.get_children():
		child.queue_free()

func _on_enemy_spawn_requested(enemy_object_id: String, slot_id: int):
	spawn_enemy_at_slot(enemy_object_id, slot_id)
	_fit_enemies()

func _on_run_ended():
	clear_enemies()
