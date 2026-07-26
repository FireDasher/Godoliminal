extends CharacterBody3D

const SPEED = 4.5
const ACCELERATION = 8.0
const JUMP_VELOCITY = 5.0

const MOUSE_SENSITIVITY = 0.002

@onready var camera: Camera3D = $Camera3D
@onready var grab_sound: AudioStreamPlayer = $Grab
@onready var drop_sound: AudioStreamPlayer = $Drop

@onready var cursor: TextureRect = $"../UI/Cursor"
const dot_cursor: Texture2D = preload("res://cursors/circle.bmp")
const pointer_cursor: Texture2D = preload("res://cursors/pointerCursor.bmp")
const grab_cursor: Texture2D = preload("res://cursors/grabCursor.bmp")

var grabbing: Grabbable
var grabbing_points: PackedVector3Array
var grab_distance: float
var grab_basis: Basis
var grab_mass: float
var grab_offset: Vector3
var initial_rotation: Vector3

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Helper function used to get the points on a three-dimensional collision shape in model-space
func get_points(shape: CollisionShape3D) -> PackedVector3Array:
	if shape.shape is BoxShape3D:
		const subdivisions = 8
		var size: Vector3 = shape.shape.size
		var extents: Vector3 = size * 0.5
		var step: Vector3 = size / float(subdivisions)
		var array := PackedVector3Array()
		for x in range(subdivisions + 1):
			var vx := -extents.x + (x * step.x)
			for y in range(subdivisions + 1):
				var vy := -extents.y + (y * step.y)
				for z in range(subdivisions + 1):
					var vz := -extents.z + (z * step.z)
					array.append(Vector3(vx, vy, vz))
		return array
			
	elif shape.shape is ConvexPolygonShape3D:
		return shape.shape.points
	elif shape.shape is ConcavePolygonShape3D:
		var points: PackedVector3Array = shape.shape.get_faces()
		var unique: Dictionary[Vector3, bool] = {}
		for point in points:
			unique[point] = true
		return PackedVector3Array(unique.keys())
	else:
		return PackedVector3Array()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized() * SPEED
	var air_multiplier := 1.0 if is_on_floor() else 0.25
	velocity.x = lerp(velocity.x, direction.x, ACCELERATION*air_multiplier*delta)
	velocity.z = lerp(velocity.z, direction.z, ACCELERATION*air_multiplier*delta)

	move_and_slide()

	# Pick up and drop objects
	var result := raycast(camera.global_position, -camera.global_basis.z, 1)
	# Setting the texture every frame is safe because internally if the assigned texture is the same as the current one then it returns
	if grabbing:
		cursor.texture = grab_cursor
	elif result and result.collider is Grabbable:
		cursor.texture = pointer_cursor
	else:
		cursor.texture = dot_cursor
	if Input.is_action_just_pressed("grab"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if grabbing:
			grabbing.freeze = false
			grabbing.collision_layer = 1
			grabbing = null
			drop_sound.play()
		else:
			if result and result.collider is Grabbable:
				grabbing = result.collider
				grabbing.freeze = true
				grabbing.collision_layer = 2
				grab_distance = camera.global_position.distance_to(grabbing.global_position)
				grab_offset = camera.global_basis.inverse() * camera.global_position.direction_to(grabbing.global_position)
				grab_basis = grabbing.basis
				initial_rotation = camera.global_rotation
				grab_mass = grabbing.mass
				grabbing_points = get_points(grabbing.get_node("Collision"))
				grab_sound.play()


func _process(delta: float) -> void:
	# This is where the effect happens
	if grabbing:
		var smooth_factor := 1.0 - exp(-5.0 * delta)
		# rotation
		var offset := camera.global_rotation - initial_rotation
		var gbasis: Basis = grab_basis
		if grabbing.grab_mode == 0:
			# as far as I am aware this is the only way to do this
			grab_basis = grab_basis.orthonormalized().slerp(Basis.from_euler(Vector3(0.0, grab_basis.get_euler().y, 0.0)), smooth_factor).scaled(grab_basis.get_scale())
			gbasis = grab_basis.rotated(Vector3.UP, offset.y)
		elif grabbing.grab_mode == 1:
			gbasis = grab_basis.rotated(Vector3.UP, offset.y)
		elif grabbing.grab_mode == 2:
			gbasis = grab_basis.rotated(Vector3.UP, offset.y).rotated(camera.global_basis.x, offset.x)
			
		# smoothing
		grab_offset = grab_offset.slerp(Vector3.FORWARD, smooth_factor)
		var forward := camera.global_basis * grab_offset
		var center := camera.global_position + forward * grab_distance
		# get nearest corrected length
		var nearest := 100.0
		for point in grabbing_points:
			var real_point := center + gbasis * point
			var result := raycast(camera.global_position, camera.global_position.direction_to(real_point), 1)
			if result:
				# Math
				var axis := forward + gbasis * point / grab_distance
				var length: float = (result.position - camera.global_position).dot(axis) / axis.length_squared()
				if length < nearest:
					nearest = length
		# move and scale object
		var s: float = (nearest / grab_distance)
		grabbing.global_position = camera.global_position + forward * nearest
		grabbing.basis = gbasis * s
		grabbing.mass = grab_mass * (s*s*s)
		# reset velocity so it doesn't start falling super fast when you drop it or something
		grabbing.linear_velocity = Vector3.ZERO
		grabbing.angular_velocity = Vector3.ZERO

# Helper function to reduce boilerplate
func raycast(from: Vector3, dir: Vector3, mask: int) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0, mask))

# Camera movement and rotate objects
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_pressed("rotate_held") and grabbing: # It's called that because it rotates the currently held object, not because it checks if the rotate button is currently held down
			grab_basis = grab_basis.rotated(Vector3.UP, event.relative.x * MOUSE_SENSITIVITY)
		else:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			camera.rotation.x = clampf(camera.rotation.x, -1.5, 1.5)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
