extends CharacterBody3D

@onready var head = $head
@onready var standing_collision_shape = $standing_collision_shape
@onready var crouching_collision_shape = $crouching_collision_shape
@onready var raycast = $raycast
@onready var eyes = $head/eyes
@onready var camera = $head/eyes/camera

# The current speed of the character
var current_speed = 5.0

# Increase mouse sensitivity to increase movement with camera
const MOUSE_SENSITIVITY = 0.25

var gradual_speed = 10.0

var direction = Vector3.ZERO

var crouching_depth = -0.5

@export var jump_velocity = 4.5
@export var walking_speed = 5.0
@export var sprinting_speed = 8.0
@export var crouching_speed = 3.0
@export var height = 1.8
@export var is_jumping_allowed = false
@export var is_flashlight_present = false


# Variables below are for the actions in the Input Maps
@export var jump_action = "jump"
@export var forward_action = "forward"
@export var back_action = "backward"
@export var left_action = "left"
@export var right_action = "right"
@export var sprinting_action = "sprint"
@export var crouching_action = "crouch"
@export var flashlight_action = "flashlight"
@export var flashlight = SpotLight3D.new()
@export var flashlight_switch = AudioStreamPlayer3D.new()

# Variables for head bobbing
const HEAD_BOBBING_SPRINTING_SPEED = 22.0
const HEAD_BOBBING_WALKING_SPEED = 14.0
const HEAD_BOBBING_CROUCHING_SPEED = 10.0

const HEAD_BOBBING_CROUCHING_INTENSITY = 0.025
const HEAD_BOBBING_SPRINTING_INTENSITY = 0.2
const HEAD_BOBBING_WALKING_INTENSITY = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

# Flashlight movement smooth
var flashlight_rotation_smoothness = 15.0
var flashlight_position_smoothness = 20.0

# State
var is_running = false
var is_walking = false

# Ensure smooth transition of flashlight
func update_flashlight(delta: float) -> void:
	flashlight.global_transform = Transform3D(
		flashlight.global_transform.basis.slerp(camera.global_transform.basis, delta * flashlight_rotation_smoothness),
		flashlight.global_transform.origin.slerp(camera.global_transform.origin, delta * flashlight_position_smoothness),
	).orthonormalized()

func adjust_head_bobbing(bobbing_intensity, bobbing_speed, delta) -> void:
	head_bobbing_current_intensity = bobbing_intensity
	head_bobbing_index += bobbing_speed * delta

func set_states(running_state, walking_state):
	is_running = running_state
	is_walking = walking_state

func toggle_flashlight():
	# Check if flashlight is enabled, and check if flashlight action is pressed
	flashlight.visible = not flashlight.visible
	flashlight_switch.play()

func _ready():
	# Ensure that the mouse is hidden when playing
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# To ensure that the head rotates with the movement of the mouse
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
		head.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENSITIVITY))
		
		# To ensure that the head doesn't rotate all the way around
		head.rotation.x = clamp(head.rotation.x,deg_to_rad(-89),deg_to_rad(89))
	
	if is_flashlight_present:
		if Input.is_action_pressed(flashlight_action):
			toggle_flashlight()

func _process(delta):
	update_flashlight(delta)

func _physics_process(delta):
	# If crouch action is pressed, then the player crouches, otherwise checks if the player is running/walking
	if Input.is_action_pressed(crouching_action):
		set_states(false, false)
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, 1.8 + crouching_depth, delta * gradual_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
	elif !raycast.is_colliding():
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, height, delta * gradual_speed)
		# If sprint action is pressed, character sprints, otherwise character will walk
		if Input.is_action_pressed(sprinting_action):
			set_states(true, false)
			current_speed = sprinting_speed
		else:
			set_states(false, true)
			current_speed = walking_speed
	
	# Handle head bob
	if is_running:
		adjust_head_bobbing(HEAD_BOBBING_SPRINTING_INTENSITY, HEAD_BOBBING_SPRINTING_SPEED, delta)
	elif is_walking:
		adjust_head_bobbing(HEAD_BOBBING_WALKING_INTENSITY, HEAD_BOBBING_WALKING_SPEED, delta)
	else:
		adjust_head_bobbing(HEAD_BOBBING_CROUCHING_INTENSITY, HEAD_BOBBING_CROUCHING_SPEED, delta)
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if is_jumping_allowed:
		if Input.is_action_just_pressed(jump_action) and is_on_floor():
			velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector(left_action, right_action, forward_action, back_action)
	if is_on_floor() && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2)+0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity/2.0), delta*gradual_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * (head_bobbing_current_intensity/2.0), delta*gradual_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta*gradual_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta*gradual_speed)
		
	
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * gradual_speed)
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
