extends CharacterBody2D

@export var max_health = 50
@export var speed = 150.0
@export var attack_damage = 10
@export var attack_range = 50.0
@export var detection_range = 300.0
@export var attack_cooldown = 1.0
@export var patrol_distance = 100.0  # How far to patrol left and right
@export var damage_delay = 0.3  # Time in seconds before damage is dealt during attack animation

# Animation settings
@export var idle_frame_rate = 8
@export var run_frame_rate = 10
@export var attack_frame_rate = 12

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
		return
		
	# Setup animations
	setup_animations()
	
	# Start with idle animation
	play_animation("idle")

func setup_animations():
	# Get the SpriteFrames resource
	var frames = anim_sprite.sprite_frames
	
	# Setup idle animation
	if frames.has_animation("idle"):
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", idle_frame_rate)
	
	# Setup run animation
	if frames.has_animation("run"):
		frames.set_animation_loop("run", true)
		frames.set_animation_speed("run", run_frame_rate)
	
	# Setup attack animation
	if frames.has_animation("attack"):
		frames.set_animation_loop("attack", false)
		frames.set_animation_speed("attack", attack_frame_rate)
	
	# Setup hurt animation if it exists
	if frames.has_animation("hurt"):
		frames.set_animation_loop("hurt", false)
	
	# Setup death animation if it exists
	if frames.has_animation("death"):
		frames.set_animation_loop("death", false)

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
	
	# Play run animation while patrolling
	if velocity.x != 0:
		play_animation("run")
	else:
		play_animation("idle")

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
		if abs(velocity.x) > 0:
			play_animation("run")
		else:
			play_animation("idle")

func attack():
	if not anim_sprite or is_attacking:
		return
		
	is_attacking = true
	can_attack = false
	velocity.x = 0  # Stop moving while attacking
	
	# Play attack animation
	play_animation("attack")
	
	# Wait for the right moment in the animation to deal damage
	await get_tree().create_timer(damage_delay).timeout
	
	# Deal damage if player is still in range
	if target and is_target_in_attack_range():
		print("Enemy dealing damage to knight: ", attack_damage)
		target.take_damage(attack_damage)
	
	# Wait for attack animation to finish
	await anim_sprite.animation_finished
	
	# Add attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	
	is_attacking = false
	can_attack = true
	
	# Return to idle after attack
	play_animation("idle")

func is_target_in_attack_range() -> bool:
	if not target:
		return false
		
	# Get attack hitbox based on facing direction
	var attack_direction = -1 if anim_sprite.flip_h else 1
	var attack_position = Vector2(attack_range * attack_direction, 0)
	
	# Create a raycast to check for the target
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + attack_position,
		1  # Collision mask for player layer
	)
	var result = space_state.intersect_ray(query)
	
	return result and result.collider == target

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

func take_damage(amount):
	if not is_alive:
		return
		
	current_health -= amount
	emit_signal("health_changed", current_health)
	
	if current_health <= 0:
		die()
	else:
		# Play hurt animation if it exists, otherwise flash the sprite
		if anim_sprite.sprite_frames.has_animation("hurt"):
			play_animation("hurt")
			await anim_sprite.animation_finished
		else:
			# Flash the sprite
			anim_sprite.modulate = Color(1, 0, 0, 1)  # Red tint
			await get_tree().create_timer(0.1).timeout
			anim_sprite.modulate = Color(1, 1, 1, 1)  # Reset tint
		
		play_animation("idle")

func die():
	is_alive = false
	if anim_sprite.sprite_frames.has_animation("death"):
		play_animation("death")
	emit_signal("enemy_died")
	# Disable collision
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	# Queue free after death animation or immediately if no death animation
	if anim_sprite.sprite_frames.has_animation("death"):
		await anim_sprite.animation_finished
	queue_free()

func play_animation(anim_name: String):
	if not anim_sprite or not anim_sprite.sprite_frames.has_animation(anim_name):
		return
		
	if anim_sprite.animation == anim_name and anim_sprite.is_playing():
		return
	
	print("Enemy playing animation: ", anim_name)
	anim_sprite.play(anim_name)
