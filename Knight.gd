extends CharacterBody2D

@export var SPEED = 300.0
@export var JUMP_FORCE = -400.0
@export var attack_cooldown = 0.0  # Changed to 0 for no cooldown

# Stats
@export var max_health = 100
@export var max_magic = 100
@export var magic_regen_rate = 10  # Magic points per second
@export var attack_damage = 20
@export var magic_attack_cost = 30

# Camera settings
@export var camera_smoothing_speed = 10.0
@export var camera_offset = Vector2(0, -50)  # Offset camera slightly up

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false
var can_attack = true
var facing_right = true

# Current stats
var current_health
var current_magic
var is_alive = true

@onready var anim_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D
@onready var inventory = $Inventory

signal health_changed(new_health)
signal magic_changed(new_magic)
signal knight_died

func _ready():
	# Initialize stats
	current_health = max_health
	current_magic = max_magic
	
	# Add to knight group for UI to find
	add_to_group("knight")
	
	# Check if AnimatedSprite2D exists
	if not anim_sprite:
		push_error("AnimatedSprite2D node not found! Please add an AnimatedSprite2D as a child of the Knight node.")
		return
	
	# Setup camera
	if camera:
		camera.position = camera_offset
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = camera_smoothing_speed
		print("Camera setup successfully")
	else:
		push_error("Camera2D node not found! Please add a Camera2D as a child of the Knight node.")
	
	print("AnimatedSprite2D found successfully")
	# Ensure we start with idle animation
	play_animation("idle")
	
	# Add some test items to inventory
	if inventory:
		inventory.add_test_items()

func _physics_process(delta):
	if not is_alive or (inventory and inventory.is_open):
		return
		
	# Regenerate magic over time
	regenerate_magic(delta)
		
	# Skip all animation calls if AnimatedSprite2D isn't set up
	if not anim_sprite:
		return
		
	if is_attacking:
		return
		
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y < 0:
			play_animation("jump")
		
	# Handle jump
	if Input.is_action_just_pressed("gamepad_jump") and is_on_floor():
		velocity.y = JUMP_FORCE
		play_animation("jump")
	
	# Get horizontal movement input
	var direction = Input.get_axis("gamepad_left", "gamepad_right")
	
	# Handle movement
	if direction:
		velocity.x = direction * SPEED
		# Update facing direction
		if direction > 0:
			facing_right = true
			anim_sprite.flip_h = false
		else:
			facing_right = false
			anim_sprite.flip_h = true
		
		if is_on_floor():
			play_animation("run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			play_animation("idle")
	
	# Handle normal attack
	if Input.is_action_just_pressed("gamepad_attack") and can_attack and not is_attacking:
		attack()
	
	# Handle magic attack
	if Input.is_action_just_pressed("gamepad_magic") and can_attack and not is_attacking and current_magic >= magic_attack_cost:
		magic_attack()
	
	move_and_slide()

func attack():
	if not anim_sprite or is_attacking:
		return
		
	is_attacking = true
	can_attack = false
	
	# Make sure the attack animation doesn't loop
	anim_sprite.sprite_frames.set_animation_loop("attack", false)
	play_animation("attack")
	
	# Create attack hitbox and check for enemies
	check_attack_hit()
	
	# Wait for attack animation to finish
	await anim_sprite.animation_finished
	
	is_attacking = false
	can_attack = true
	
	# Return to idle after attack
	if is_on_floor():
		play_animation("idle")

func magic_attack():
	if not anim_sprite or is_attacking:
		return
		
	is_attacking = true
	can_attack = false
	current_magic -= magic_attack_cost
	emit_signal("magic_changed", current_magic)
	
	# Play magic attack animation (you'll need to add this to your sprite frames)
	anim_sprite.sprite_frames.set_animation_loop("magic_attack", false)
	play_animation("magic_attack")
	
	# Create magic attack effect here
	# You can instantiate a magic projectile scene
	
	await anim_sprite.animation_finished
	
	is_attacking = false
	can_attack = true
	
	if is_on_floor():
		play_animation("idle")

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
	emit_signal("knight_died")
	# Disable collision or change collision layer
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

func regenerate_magic(delta):
	if current_magic < max_magic:
		current_magic = min(current_magic + magic_regen_rate * delta, max_magic)
		emit_signal("magic_changed", current_magic)

func check_attack_hit():
	# Create a hitbox in front of the knight
	var attack_range = 50  # Adjust based on your sprite size
	var attack_position = Vector2(attack_range if facing_right else -attack_range, 0)
	
	# You might want to use Area2D or RayCast2D for more precise hit detection
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + attack_position)
	query.collision_mask = 2  # Set this to match your enemy's collision layer
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.has_method("take_damage"):
		result.collider.take_damage(attack_damage)

func play_animation(anim_name: String):
	if not anim_sprite:
		return
		
	if anim_sprite.animation == anim_name and anim_sprite.is_playing():
		return
	
	print("Playing animation: ", anim_name)
	anim_sprite.play(anim_name) 
