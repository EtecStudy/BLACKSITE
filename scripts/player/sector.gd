extends Node3D
const AVATAR = preload("res://scenes/player/avatar.tscn")
var avatars: Dictionary = {}
var status_label: Label


func _ready() -> void:
	_build_map()
	_build_hud()
	for peer_id in Net.players:
		add_player_avatar(int(peer_id), Net.players[peer_id].position)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Net.roster_changed.connect(_refresh_roster)


func add_player_avatar(peer_id: int, at: Vector3) -> void:
	if avatars.has(peer_id):
		return
	var avatar = AVATAR.instantiate()
	avatar.name = "Player_%d" % peer_id
	avatar.peer_id = peer_id
	$Players.add_child(avatar)
	avatar.global_position = at
	avatars[peer_id] = avatar
	_refresh_roster()


func remove_player_avatar(peer_id: int) -> void:
	if avatars.has(peer_id):
		avatars[peer_id].queue_free()
		avatars.erase(peer_id)
	_refresh_roster()


func get_player_avatar(peer_id: int) -> CharacterBody3D:
	return avatars.get(peer_id) as CharacterBody3D


func apply_snapshot(data: Dictionary) -> void:
	for peer_id in data:
		var id := int(peer_id)
		if not avatars.has(id):
			add_player_avatar(id, data[peer_id][0])
		var avatar = avatars[id]
		avatar.apply_network_state(data[peer_id][0], data[peer_id][1], data[peer_id][2])


func _refresh_roster() -> void:
	if is_instance_valid(status_label):
		status_label.text = (
			"SALA %d / 4  ·  IDs: %s  ·  Esc: menu"
			% [avatars.size(), ", ".join(Array(avatars.keys()).map(func(v): return str(v)))]
		)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status_label = Label.new()
	status_label.position = Vector2(18, 16)
	layer.add_child(status_label)
	_refresh_roster()
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.add_theme_font_size_override("font_size", 20)
	layer.add_child(cross)
	var exit := Button.new()
	exit.text = "SAIR"
	exit.position = Vector2(18, 48)
	exit.pressed.connect(Net.leave)
	layer.add_child(exit)


func _build_map() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("26343b")
	e.ambient_light_energy = 0.32
	e.fog_enabled = true
	e.fog_light_color = Color("29373a")
	e.fog_density = 0.012
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -28, 0)
	sun.light_energy = 0.18
	add_child(sun)
	var geo := Node3D.new()
	geo.name = "Architecture"
	add_child(geo)
	var floor_mat := _mat(Color("30383a"))
	var wall_mat := _mat(Color("42494a"))
	var trim := _mat(Color("657070"))
	var hazard := _mat(Color("6b362b"))
	var lamp_mat := _mat(Color("aab8a4"), true)
	# Connected entrance, two corridor modules, two laboratories and one side storage room.
	_room(geo, Vector3(0, 0, 0), Vector2(10, 10), floor_mat, wall_mat, trim, 3.4, [-1], [-1])
	_room(geo, Vector3(0, 0, -11), Vector2(5, 12), floor_mat, wall_mat, trim, 3.4, [-1, 1], [-1, 1])
	_room(geo, Vector3(-9.5, 0, -11), Vector2(14, 8), floor_mat, wall_mat, trim, 3.4, [1])
	_room(geo, Vector3(0, 0, -23), Vector2(5, 12), floor_mat, wall_mat, trim, 3.4, [], [1])
	_room(geo, Vector3(9.5, 0, -11), Vector2(14, 8), floor_mat, wall_mat, trim, 3.4, [-1])
	# Supplemental side room opens from entry via framed threshold.
	_room(geo, Vector3(-11, 0, 0), Vector2(12, 8), floor_mat, wall_mat, trim, 3.4, [1])
	# Door frames and closed decorative industrial panels leave connecting apertures open.
	for p in [Vector3(0, 0, -5), Vector3(0, 0, -17)]:
		_door_frame(geo, p, trim, hazard)
	for p in [Vector3(-2.5, 0, -11), Vector3(2.5, 0, -11), Vector3(-5, 0, 0)]:
		_door_frame_side(geo, p, trim, hazard)
	# Storage crates and cabinet forms.
	for p in [
		Vector3(3, 0.7, 2), Vector3(-6, 0.65, -13), Vector3(14, 0.8, -11), Vector3(-12, 0.85, -11)
	]:
		_crate(geo, p, wall_mat, trim)
	# Procedural glTF demo crate, instantiated in the playable map (not yet Blender-generated).
	var crate_asset := load("res://assets/models/blacksite_crate.glb") as PackedScene
	if crate_asset:
		var imported_crate := crate_asset.instantiate()
		imported_crate.position = Vector3(1.4, 0, -2.2)
		imported_crate.scale = Vector3(0.85, 0.85, 0.85)
		geo.add_child(imported_crate)
		var crate_body := StaticBody3D.new()
		crate_body.position = Vector3(1.4, 0.51, -2.2)
		geo.add_child(crate_body)
		var crate_collision := CollisionShape3D.new()
		var crate_shape := BoxShape3D.new()
		crate_shape.size = Vector3(1.2, 1.02, 0.9)
		crate_collision.shape = crate_shape
		crate_body.add_child(crate_collision)
	_panel(geo, Vector3(-3.8, 1.45, 0), trim, hazard)
	for p in [
		Vector3(0, 3.05, 0),
		Vector3(0, 3.05, -11),
		Vector3(-10, 3.05, -11),
		Vector3(0, 3.05, -23),
		Vector3(10, 3.05, -11),
		Vector3(-11, 3.05, 1)
	]:
		_lamp(geo, p, lamp_mat)
	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	add_child(spawns)
	for i in 4:
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % (i + 1)
		marker.position = Vector3((i % 2) * 2.0 - 1.0, 1.0, floori(i / 2) * 2.0 - 1.0)
		spawns.add_child(marker)
	var players := Node3D.new()
	players.name = "Players"
	add_child(players)


func _mat(color: Color, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.7
	return m


func _box(
	parent: Node3D, pos: Vector3, size: Vector3, material: Material, collision := true
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = pos
	parent.add_child(visual)
	if collision:
		var body := StaticBody3D.new()
		body.position = pos
		parent.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	return visual


func _room(
	parent: Node3D,
	center: Vector3,
	size: Vector2,
	floor_mat: Material,
	wall: Material,
	trim: Material,
	height: float,
	open_sides: Array[int] = [],
	open_ends: Array[int] = []
) -> void:
	_box(parent, center + Vector3(0, -0.18, 0), Vector3(size.x, 0.36, size.y), floor_mat)
	_box(parent, center + Vector3(0, height + 0.15, 0), Vector3(size.x, 0.3, size.y), wall)
	# Side walls have 2.2 m service-door openings centered on each room's long axis.
	# Matching openings in neighboring modules form real traversable connections.
	var side_segment_length := (size.y - 1.8) * 0.5
	var side_segment_offset := (size.y + 1.8) * 0.25
	for side in [-1, 1]:
		var x := center.x + side * size.x / 2
		if side not in open_sides:
			_box(parent, Vector3(x, height / 2, center.z), Vector3(0.35, height, size.y), wall)
			continue
		for zsign in [-1, 1]:
			_box(
				parent,
				Vector3(x, height / 2, center.z + zsign * side_segment_offset),
				Vector3(0.35, height, side_segment_length),
				wall
			)
		_box(parent, Vector3(x, height - 0.35, center.z), Vector3(0.35, 0.7, 1.8), wall)
	# End walls are solid except where a neighboring corridor module is attached.
	for zsign in [-1, 1]:
		var z := center.z + zsign * size.y / 2
		if zsign not in open_ends:
			_box(parent, Vector3(center.x, height / 2, z), Vector3(size.x, height, 0.35), wall)
			continue
		_box(
			parent,
			Vector3(center.x - size.x * 0.32, height / 2, z),
			Vector3(size.x * 0.36, height, 0.35),
			wall
		)
		_box(
			parent,
			Vector3(center.x + size.x * 0.32, height / 2, z),
			Vector3(size.x * 0.36, height, 0.35),
			wall
		)
		_box(parent, Vector3(center.x, height - 0.42, z), Vector3(size.x * 0.28, 0.84, 0.35), wall)
	_box(parent, center + Vector3(0, 0.02, 0), Vector3(size.x, 0.025, size.y), trim, false)


func _door_frame(parent: Node3D, pos: Vector3, metal: Material, warning: Material) -> void:
	_box(parent, pos + Vector3(-0.8, 1.55, 0), Vector3(0.18, 3.1, 0.3), metal)
	_box(parent, pos + Vector3(0.8, 1.55, 0), Vector3(0.18, 3.1, 0.3), metal)
	_box(parent, pos + Vector3(0, 3.08, 0), Vector3(1.8, 0.18, 0.3), warning)


func _door_frame_side(parent: Node3D, pos: Vector3, metal: Material, warning: Material) -> void:
	_box(parent, pos + Vector3(0, 1.55, -0.8), Vector3(0.3, 3.1, 0.18), metal)
	_box(parent, pos + Vector3(0, 1.55, 0.8), Vector3(0.3, 3.1, 0.18), metal)
	_box(parent, pos + Vector3(0, 3.08, 0), Vector3(0.3, 0.18, 1.8), warning)


func _crate(parent: Node3D, pos: Vector3, body: Material, metal: Material) -> void:
	_box(parent, pos, Vector3(1.35, 1.2, 1.05), body)
	for x in [-0.5, 0.5]:
		_box(parent, pos + Vector3(x, 0, 0.54), Vector3(0.09, 1.23, 0.06), metal, false)
	_box(parent, pos + Vector3(0, 0.48, 0.56), Vector3(1.25, 0.08, 0.06), metal, false)


func _panel(parent: Node3D, pos: Vector3, metal: Material, warning: Material) -> void:
	_box(parent, pos, Vector3(0.16, 1.5, 1.8), metal)
	_box(parent, pos + Vector3(-0.1, 0.25, 0), Vector3(0.04, 0.45, 1.3), warning, false)
	_box(
		parent,
		pos + Vector3(-0.1, -0.35, 0),
		Vector3(0.04, 0.06, 1.3),
		_mat(Color("a6b59a"), true),
		false
	)


func _lamp(parent: Node3D, pos: Vector3, material: Material) -> void:
	_box(parent, pos, Vector3(1.15, 0.12, 0.28), material, false)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.15, 0)
	light.light_color = Color("b5c4ad")
	light.light_energy = 0.65
	light.omni_range = 6
	parent.add_child(light)
