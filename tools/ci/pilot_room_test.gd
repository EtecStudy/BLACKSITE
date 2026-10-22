extends Node
## Teste técnico da Sala-Piloto Visual (Etapa de direção visual).
##
## Valida a sala independente sem alterar o controlador:
## - estrutura de nós, grupos arquitetônicos e equipamentos esperados;
## - dimensões internas aproximadas por raios físicos (piso, teto e paredes);
## - porta, janela de observação, spawn e centro;
## - pontos livres e um percurso curto com o jogador real já existente;
## - contagens de nós/malhas e número de materiais distintos carregados.
##
## Rode com:  godot --headless --script res://tools/ci/pilot_room_test.gd

const ROOM_SCENE: String = "res://maps/pilot/pilot_research_room.tscn"
const SESSION_SCENE: String = "res://match/scenes/pilot_room.tscn"
const TIME_LIMIT_MS: int = 45000

var _failures: int = 0
var _checks: int = 0
var _start_msec: int = 0


func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	_run()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[PILOT OK] %s" % message)
	else:
		_failures += 1
		printerr("[PILOT FALHA] %s" % message)


func _run() -> void:
	while Time.get_ticks_msec() - _start_msec < TIME_LIMIT_MS:
		if PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS) >= 0:
			break
		await get_tree().physics_frame

	var room_scene: PackedScene = load(ROOM_SCENE) as PackedScene
	_check(room_scene != null, "A cena da sala-piloto carrega")
	if room_scene == null:
		_finish()
		return
	var room: Node3D = room_scene.instantiate() as Node3D
	add_child(room)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check_nodes(room)
	_check_counts(room)
	_check_dimensions(room)
	await _check_free_space(room)
	await _check_player_route()
	_finish()


func _check_nodes(room: Node3D) -> void:
	for path in [
		"Architecture/Floor/FloorPanel", "Architecture/Ceiling/CeilingPanel",
		"Architecture/Door", "Architecture/ObservationWindow",
		"Furniture/WestBench", "Furniture/IslandBench", "Furniture/EastAnalysisBench",
		"Furniture/WorkstationDesk", "Furniture/Storage",
		"Equipment/FumeHood", "Equipment/BiosafetyCabinet",
		"Equipment/LaboratoryRefrigerator", "Equipment/Incubator",
		"Equipment/IslandInstruments", "Props/Bottle0", "Props/PaperSheet0",
		"TechnicalDetails", "Lighting", "Collision/ArchitectureBodies",
		"Collision/FurnitureBodies", "Spawn", "Center",
	]:
		_check(room.get_node_or_null(path) != null, "Nó esperado existe: %s" % path)

	var spawn := room.get_node_or_null("Spawn") as Marker3D
	_check(spawn != null and absf(spawn.position.x) < 5.0 and absf(spawn.position.z) < 6.0,
		"Spawn fica dentro da sala")
	var center := room.get_node_or_null("Center") as Marker3D
	_check(center != null and center.position.is_equal_approx(Vector3(0.0, 1.6, 0.0)),
		"Centro de referência está em (0; 1,6; 0)")


func _check_counts(room: Node) -> void:
	var nodes: int = 0
	var meshes: int = 0
	var shapes: int = 0
	var lights: int = 0
	var labels: int = 0
	var materials: Dictionary = {}
	var stack: Array[Node] = [room]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		nodes += 1
		if node is MeshInstance3D:
			meshes += 1
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				for surface in range(mesh_instance.mesh.get_surface_count()):
					var material := mesh_instance.mesh.surface_get_material(surface)
					if material != null:
						materials[material.resource_path] = true
		elif node is CollisionShape3D:
			shapes += 1
		elif node is Light3D:
			lights += 1
		elif node is Label3D:
			labels += 1
		for child in node.get_children():
			stack.append(child)
	print("[PILOT] nós=%d malhas=%d formas de colisão=%d luzes=%d rótulos=%d materiais distintos=%d" % [nodes, meshes, shapes, lights, labels, materials.size()])
	_check(nodes >= 550 and nodes <= 950, "Quantidade de nós está na faixa prevista (550-950)")
	_check(meshes >= 350, "A sala tem densidade visual mínima de malhas (>= 350)")
	_check(shapes >= 20, "A sala tem colisões arquitetônicas e de móveis (>= 20)")
	_check(lights >= 7, "A sala tem iluminação principal, técnica e de emergência (>= 7)")
	_check(labels >= 7, "A sinalização textual mínima está presente (>= 7)")
	_check(materials.size() >= 20, "Há pelo menos 20 materiais distintos carregados")


func _ray(room: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	return room.get_world_3d().direct_space_state.intersect_ray(query)


func _check_dimensions(room: Node3D) -> void:
	var floor_hit := _ray(room, Vector3(3.3, 2, 3.4), Vector3(3.3, -0.5, 3.4))
	_check(not floor_hit.is_empty() and absf((floor_hit["position"] as Vector3).y) < 0.06,
		"Piso físico está próximo de y=0")
	var ceiling_hit := _ray(room, Vector3(0, 2, 0), Vector3(0, 4, 0))
	_check(not ceiling_hit.is_empty() and (ceiling_hit["position"] as Vector3).y > 3.0,
		"Teto técnico físico está próximo de y=3,2")
	var window_sign := room.get_node_or_null("Architecture/ObservationWindow/WindowSign") as Label3D
	_check(window_sign != null and absf(window_sign.rotation.y + PI / 2.0) < 0.01,
		"Rótulo da janela está voltado para o interior da sala")
	var safety_sign := room.get_node_or_null("TechnicalDetails/SafetySign") as Label3D
	_check(safety_sign != null and absf(safety_sign.rotation.y - PI / 2.0) < 0.01,
		"Rótulo de EPI da parede oeste está voltado para o interior da sala")
	var main_light := room.get_node_or_null("Lighting/MainLight0") as SpotLight3D
	_check(main_light != null and main_light.position.y > 2.9,
		"Luz principal nasce nas luminárias do forro técnico")
	for spec in [
		[Vector3(0, 1.4, -6.4), Vector3(0, 1.4, 6.4), "norte/sul"],
		[Vector3(-5.4, 1.4, 0), Vector3(5.4, 1.4, 0), "leste/oeste"],
	]:
		var hit := _ray(room, spec[0], spec[1])
		_check(not hit.is_empty(), "Raios cruzam a sala no eixo %s" % spec[2])
	var door_hit := _ray(room, Vector3(-2.2, 1.3, 5.0), Vector3(-2.2, 1.3, 6.5))
	_check(not door_hit.is_empty() and (door_hit["position"] as Vector3).z > 5.8,
		"A porta principal possui volume físico")
	var window_hit := _ray(room, Vector3(4.0, 1.8, -1.0), Vector3(6.0, 1.8, -1.0))
	_check(not window_hit.is_empty() and (window_hit["position"] as Vector3).x > 4.7,
		"A janela de observação possui vidro/moldura física")


func _space_free(room: Node3D, point: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.30
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), point)
	query.collision_mask = 1
	return room.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _check_free_space(room: Node3D) -> void:
	for point in [
		Vector3(0, 0.95, 1.1), Vector3(-2.6, 0.95, 4.35), Vector3(3.3, 0.95, -3.4),
		Vector3(0, 0.95, -3.8), Vector3(-3.8, 0.95, -3.4), Vector3(2.8, 0.95, 3.4),
	]:
		_check(_space_free(room, point), "Ponto de circulação livre em %s" % point)
	# Volumes que precisam bloquear:
	for point in [Vector3(-4.6, 0.95, -1.0), Vector3(-0.25, 0.95, -0.55), Vector3(4.6, 0.95, 2.2)]:
		_check(not _space_free(room, point), "Móvel/equipamento bloqueia em %s" % point)


func _place(player: Node3D, position: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = position
	player.global_rotation = Vector3.ZERO


func _walk_to(player: Node3D, target: Vector3, timeout_sec: float) -> bool:
	var body := player as CharacterBody3D
	var ticks: int = int(timeout_sec * 60.0)
	for i in range(ticks):
		var to_target := target - body.global_position
		to_target.y = 0.0
		if to_target.length() < 0.3:
			Input.action_release("move_forward")
			Input.action_release("move_back")
			Input.action_release("move_left")
			Input.action_release("move_right")
			return true
		var direction := to_target.normalized()
		var forward_amount: float = -player.get_global_transform().basis.z.dot(direction)
		var right_amount: float = player.get_global_transform().basis.x.dot(direction)
		# quando falta virar, gira usando movimento do mouse simulado não é necessário:
		# o controlador aceita olhar programático por set_look, quando disponível.
		if player.has_method("set_look"):
			player.call("set_look", atan2(-direction.x, -direction.z), 0.0)
		Input.action_release("move_forward")
		Input.action_release("move_back")
		Input.action_release("move_left")
		Input.action_release("move_right")
		if forward_amount > 0.25:
			Input.action_press("move_forward")
		elif forward_amount < -0.25:
			Input.action_press("move_back")
		if right_amount > 0.25:
			Input.action_press("move_right")
		elif right_amount < -0.25:
			Input.action_press("move_left")
		await get_tree().physics_frame
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(action)
	return false


func _check_player_route() -> void:
	var session_scene: PackedScene = load(SESSION_SCENE) as PackedScene
	_check(session_scene != null, "A sessão jogável da sala-piloto carrega")
	if session_scene == null:
		return
	var session: Node = session_scene.instantiate()
	add_child(session)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Node3D = session.call("get_player") as Node3D
	_check(player != null, "A sessão usa o jogador existente")
	if player == null:
		session.queue_free()
		await get_tree().process_frame
		return
	var room: Node3D = session.get_node_or_null("PilotRoom") as Node3D
	_check(room != null, "A sessão contém a sala-piloto")
	_place(player, Vector3(-2.6, 0.12, 4.35))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(absf(player.global_position.y - 0.05) < 0.25, "O jogador nasce apoiado no piso da sala")
	var waypoints: Array[Vector3] = [
		Vector3(-1.5, 0.05, 1.3), Vector3(3.3, 0.05, 1.2),
		Vector3(3.3, 0.05, -3.4), Vector3(0.0, 0.05, -3.8),
		Vector3(-3.8, 0.05, -3.4), Vector3(-3.8, 0.05, 1.8),
		Vector3(-2.6, 0.05, 4.35),
	]
	for waypoint in waypoints:
		_check(await _walk_to(player, waypoint, 8.0), "O jogador alcança %s" % waypoint)
	_check(absf(player.global_position.y - 0.05) < 0.3, "O jogador termina o percurso apoiado no piso")
	session.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("[PILOT] %d/%d verificações passaram" % [_checks - _failures, _checks])
	print("[PILOT] %d verificações aprovadas" % (_checks - _failures))
	if _failures == 0:
		print("[PILOT] TESTE DA SALA-PILOTO PASSOU")
		get_tree().quit(0)
	else:
		printerr("[PILOT] TESTE DA SALA-PILOTO FALHOU com %d problema(s)" % _failures)
		get_tree().quit(1)
