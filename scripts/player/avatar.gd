extends CharacterBody3D
@export var peer_id := 1
var is_local := false
var pitch := 0.0
var remote_target := Vector3.ZERO
var remote_yaw := 0.0


func _ready() -> void:
	is_local = peer_id == multiplayer.get_unique_id()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	$CollisionShape3D.shape = capsule
	var body := CapsuleMesh.new()
	body.radius = 0.34
	body.height = 1.8
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("59676a")
	bm.roughness = 0.9
	$Body.mesh = body
	$Body.material_override = bm
	var head := BoxMesh.new()
	head.size = Vector3(0.32, 0.32, 0.32)
	$Head.mesh = head
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color("9da7a0")
	$Head.material_override = hm
	$YawPivot/PitchPivot/Camera3D.current = is_local
	if not is_local:
		$YawPivot/PitchPivot/Camera3D.queue_free()
	remote_target = global_position


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		$YawPivot.rotation.y -= event.relative.x * 0.0025
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.45, 1.45)
		$YawPivot/PitchPivot.rotation.x = pitch


func _physics_process(delta: float) -> void:
	if is_local:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		Net.submit_input(input, $YawPivot.rotation.y, pitch, Input.is_action_pressed("sprint"))
		# The authoritative server's snapshot controls position; local smoothing keeps input responsive.
		var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, $YawPivot.rotation.y)
		var speed := 6.5 if Input.is_action_pressed("sprint") else 3.8
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not is_on_floor():
			velocity.y -= 18.0 * delta
		else:
			velocity.y = 0
		move_and_slide()
	else:
		global_position = global_position.lerp(remote_target, minf(delta * 12.0, 1.0))
		$YawPivot.rotation.y = lerp_angle($YawPivot.rotation.y, remote_yaw, minf(delta * 12.0, 1.0))


func apply_network_state(pos: Vector3, yaw: float, remote_pitch: float) -> void:
	if is_local:
		# Server is authoritative; correct predicted position gently.
		global_position = global_position.lerp(pos, 0.18)
	else:
		remote_target = pos
		remote_yaw = yaw
		$YawPivot/PitchPivot.rotation.x = remote_pitch
