extends CharacterBody2D

@export var max_health = 50
@export var speed = 150.0
@export var attack_damage = 10
@export var attack_range = 50.0
@export var detection_range = 300.0
@export var attack_cooldown = 1.0
@export var patrol_distance = 100.0  # How far to patrol left and right

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_health
var can_attack = true
var is_attacking = false
var target = null
var is_alive = true

# Patrol variables
var initial_position: Vector2
var moving_right = true

@onready var anim_sprite = $AnimatedSprite2D

signal health_changed(new_health)
signal enemy_died

func _ready():
	current_health = max_health
	initial_position = global_position
	# Set collision layer to 2 (for enemy)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)  # Detect player (layer 1)
	
	if not anim_sprite:
		push_error("AnimatedSprite2D node not found! Please add an AnimatedSprite2D as a child of the Enemy node.")

func _physics_process(delta):
	if not is_alive or is_attacking:
		return
		
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if target:
		chase_target()
	else:
		patrol()
		find_target()
	
	move_and_slide()

func patrol():
	var patrol_limit_right = initial_position.x + patrol_distance
	var patrol_limit_left = initial_position.x - patrol_distance
	
	if moving_right:
		velocity.x = speed
		if global_position.x >= patrol_limit_right:
			moving_right = false
	else:
		velocity.x = -speed
		if global_position.x <= patrol_limit_left:
			moving_right = true
	
	# Update facing direction
	anim_sprite.flip_h = not moving_right
	play_animation("run")

func chase_target():
	var direction = (target.global_position - global_position).normalized()
	
	# Only move horizontally
	velocity.x = direction.x * speed
	
	# Update facing direction
	anim_sprite.flip_h = velocity.x < 0
		
	# Check if within attack range
	if global_position.distance_to(target.global_position) <= attack_range and can_attack:
		attack()
	else:
		play_animation("run")

func find_target():
	# Look for player in detection range in both directions
	var space_state = get_world_2d().direct_space_state
	
	# Look right
	var query_right = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(detection_range, 0))
	query_right.collision_mask = 1  # Player layer
	var result_right = space_state.intersect_ray(query_right)
	
	# Look left
	var query_left = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(-detection_range, 0))
	query_left.collision_mask = 1  # Player layer
	var result_left = space_state.intersect_ray(query_left)
	
	# Check both results
	if result_right and result_right.collider.has_method("take_damage"):
		target = result_right.collider
	elif result_left and result_left.collider.has_method("take_damage"):
		target = result_left.collider
	else:
		target = null

func attack():
	is_attacking = true
	can_attack = false
	play_animation("attack")
	
	# Deal damage if player is still in range
	if target and global_position.distance_to(target.global_position) <= attack_range:
		target.take_damage(attack_damage)
	
	await anim_sprite.animation_finished
	
	# Add attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	
	is_attacking = false
	can_attack = true

func take_damage(amount):
	if not is_alive:
		return
		
	current_health -= amount
	emit_signal("health_changed", current_health)
	
	if current_health <= 0:
		die()
	else:
		# Play hurt animation
		play_animation("hurt")
		await anim_sprite.animation_finished
		play_animation("idle")

func die():
	is_alive = false
	play_animation("death")
	emit_signal("enemy_died")
	# Disable collision
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	# Queue free after death animation
	await anim_sprite.animation_finished
	queue_free()

func play_animation(anim_name: String):
	if not anim_sprite:
		return
		
	if anim_sprite.animation == anim_name and anim_sprite.is_playing():
		return
	
	anim_sprite.play(anim_name)
