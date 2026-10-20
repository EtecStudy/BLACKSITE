extends Node
## Regressão do drop **junto a obstáculos** (correção do bug da Etapa 9).
##
## Uso:
##     godot --headless --path . --fixed-fps 60 --audio-driver Dummy \
##         res://tools/ci/drop_obstacle_test.tscn
##
## O bug relatado no teste manual: itens soltos perto de caixas, pilares e
## paredes podiam ficar apoiados só numa quina, tombar, escorregar para dentro
## do objeto, ficar inacessíveis ou "desaparecer". O teste reproduz os cenários
## na **cena real** e verifica, para cada item solto:
##
##   - a pegada inteira está apoiada na mesma superfície (nada de quina);
##   - a caixa do item não está dentro de nenhum outro colisor;
##   - o item não afunda, não desliza e não desaparece ao assentar;
##   - o item continua recolhível com E (inventário e mundo consistentes).
##
## Também cobre: drop sobre a caixa (deve funcionar), drop ao lado de caixa,
## pilar e parede, espaço insuficiente (recusa sem perder o item), drops
## repetidos e os quatro itens A/B/C/D.
##
## Sai com 0 em caso de sucesso e 1 em caso de falha.

const MOVEMENT_SCENE := "res://match/scenes/movement_test.tscn"

## Quanto esperar o item assentar antes de medir (60 Hz → ~0,75 s).
const SETTLE_FRAMES := 45
## Deslocamento máximo aceito entre nascer e assentar, em metros.
const SETTLE_DRIFT := 0.06
## Tolerância de altura entre as amostras de apoio, em metros.
const SUPPORT_TOLERANCE := 0.04
## Grade de amostras de apoio (3x3 = 9 raios sobre a pegada).
const SUPPORT_GRID := 3

## Geometria da sala de teste (`maps/scenes/test_room.tscn`).
const CRATE1 := Vector3(3.0, 0.5, 2.0)
const PILLAR1 := Vector3(-6.0, 2.0, -6.0)
const WEST_WALL_FACE_X := -11.75
const FLOOR_Y := 0.0

const YAW_NEG_Z := 0.0
const YAW_POS_Z := PI
const YAW_NEG_X := PI * 0.5

const WATCHDOG_MS := 60000

var _scene: Node = null
var _player: PlayerController = null
var _inventory: Inventory = null
var _dropper: ItemDropper = null
var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _finished: bool = false
var _last_progress_ms: int = 0
var _last_step: String = "início"


func _ready() -> void:
	print("=== Black Sight · teste do drop junto a obstáculos ===")
	_touch("início")
	await _start_scene()
	if _scene == null:
		_finish()
		return

	await _test_open_floor()
	await _test_on_crate()
	await _test_beside_crate()
	await _test_beside_pillar()
	await _test_beside_wall()
	await _test_no_space()
	await _test_repeated_drops()
	await _test_multiple_items()
	await _test_pause_with_items()
	await _test_final_state()

	_finish()


## Watchdog: nunca deixar o CI pendurado se uma coroutine morrer.
func _process(_delta: float) -> void:
	if _finished:
		return
	var idle: int = Time.get_ticks_msec() - _last_progress_ms
	if idle <= WATCHDOG_MS:
		return
	_finished = true
	printerr("DROP OBSTACLE TEST TRAVOU — %d ms sem progresso (última etapa: %s)" % [idle, _last_step])
	printerr("verificações até aqui: %d · falhas: %d" % [_checks, _failures.size()])
	get_tree().quit(2)


func _touch(step: String = "") -> void:
	_last_progress_ms = Time.get_ticks_msec()
	if not step.is_empty():
		_last_step = step


# --- Montagem ---------------------------------------------------------------

func _start_scene() -> void:
	var packed: PackedScene = load(MOVEMENT_SCENE) as PackedScene
	_expect(packed != null, "cena de teste carrega")
	if packed == null:
		return
	_scene = packed.instantiate()
	add_child(_scene)
	await _frames(12)
	_player = _scene.get_node_or_null("Player") as PlayerController
	_expect(_player != null, "jogador instanciado")
	if _player == null:
		return
	_inventory = _player.get_inventory()
	_dropper = _player.get_item_dropper()
	_expect(_inventory != null, "jogador tem inventário")
	_expect(_dropper != null, "jogador tem o componente de drop")
	await _reset()


# --- Casos ------------------------------------------------------------------

func _test_open_floor() -> void:
	_touch("[1] chão aberto")
	print("[1] Chão aberto")
	await _prepare(Vector3(0.0, 0.05, 0.0), YAW_NEG_Z, &"fix_a", "ITEM A")
	var item: WorldItem = await _drop_ok("chão aberto")
	if item == null:
		return
	var base: Vector3 = item.global_position
	_expect(base.y < 0.15, "chão aberto: assenta no piso (y=%.3f)" % base.y)
	await _check_safe(item, "chão aberto")
	await _check_settled(item, base, "chão aberto")
	await _check_collect(item, "chão aberto")


func _test_on_crate() -> void:
	_touch("[2] sobre a caixa")
	print("[2] Sobre a caixa")
	await _prepare(Vector3(CRATE1.x, 0.05, 0.85), YAW_POS_Z, &"fix_b", "ITEM B")
	var item: WorldItem = await _drop_ok("sobre a caixa")
	if item == null:
		return
	var base: Vector3 = item.global_position
	_expect(base.y > 0.9, "sobre a caixa: item fica no topo (y=%.3f)" % base.y)
	_expect(absf(base.x - CRATE1.x) < 0.45, "sobre a caixa: centralizado em X (%.3f)" % base.x)
	await _check_safe(item, "sobre a caixa")
	await _check_settled(item, base, "sobre a caixa")
	await _check_collect(item, "sobre a caixa")


func _test_beside_crate() -> void:
	_touch("[3] ao lado da caixa")
	print("[3] Ao lado da caixa")
	await _prepare(Vector3(CRATE1.x, 0.05, 0.2), YAW_POS_Z, &"fix_c", "ITEM C")
	var item: WorldItem = await _drop_ok("ao lado da caixa")
	if item == null:
		return
	var base: Vector3 = item.global_position
	_expect(base.y < 0.15, "ao lado da caixa: fica no piso (y=%.3f)" % base.y)
	_expect(base.z < CRATE1.z - 0.5, "ao lado da caixa: fora da caixa (z=%.3f)" % base.z)
	await _check_safe(item, "ao lado da caixa")
	await _check_settled(item, base, "ao lado da caixa")
	await _check_collect(item, "ao lado da caixa")


func _test_beside_pillar() -> void:
	_touch("[4] ao lado do pilar")
	print("[4] Ao lado do pilar")
	await _prepare(Vector3(PILLAR1.x, 0.05, PILLAR1.z + 1.4), YAW_NEG_Z, &"fix_d", "ITEM D")
	var item: WorldItem = await _drop_ok("ao lado do pilar")
	if item == null:
		return
	var base: Vector3 = item.global_position
	_expect(base.y < 0.15, "ao lado do pilar: fica no piso (y=%.3f)" % base.y)
	_expect(base.z > PILLAR1.z + 0.4, "ao lado do pilar: fora do pilar (z=%.3f)" % base.z)
	await _check_safe(item, "ao lado do pilar")
	await _check_settled(item, base, "ao lado do pilar")
	await _check_collect(item, "ao lado do pilar")


func _test_beside_wall() -> void:
	_touch("[5] ao lado da parede")
	print("[5] Ao lado da parede")
	await _prepare(Vector3(-10.6, 0.05, -3.0), YAW_NEG_X, &"fix_e", "ITEM E")
	var item: WorldItem = await _drop_ok("ao lado da parede")
	if item == null:
		return
	var base: Vector3 = item.global_position
	_expect(base.y < 0.15, "ao lado da parede: fica no piso (y=%.3f)" % base.y)
	_expect(base.x > WEST_WALL_FACE_X + 0.2, "ao lado da parede: fora da parede (x=%.3f)" % base.x)
	await _check_safe(item, "ao lado da parede")
	await _check_settled(item, base, "ao lado da parede")
	await _check_collect(item, "ao lado da parede")


func _test_no_space() -> void:
	_touch("[6] espaço insuficiente")
	print("[6] Espaço insuficiente (encostado na parede)")
	await _prepare(Vector3(-11.2, 0.05, -3.0), YAW_NEG_X, &"fix_f", "ITEM F")
	await _drop_rejected("espaço insuficiente")


func _test_repeated_drops() -> void:
	_touch("[7] drops repetidos")
	print("[7] Drops repetidos perto dos obstáculos")
	await _reset()
	var spots: Array = [
		[Vector3(CRATE1.x, 0.05, 0.85), YAW_POS_Z, "repetido 1 (topo da caixa)"],
		[Vector3(CRATE1.x, 0.05, 0.2), YAW_POS_Z, "repetido 2 (piso junto à caixa)"],
		[Vector3(PILLAR1.x, 0.05, PILLAR1.z + 1.4), YAW_NEG_Z, "repetido 3 (piso junto ao pilar)"],
	]
	var kept: Array = []
	for index: int in spots.size():
		var spot: Array = spots[index]
		await _prepare(spot[0], spot[1], StringName("repet_%d" % index), "REPETIDO %d" % (index + 1))
		var item: WorldItem = await _drop_ok("repetido %d" % (index + 1))
		if item == null:
			continue
		kept.append(item)
		await _check_safe(item, "repetido %d" % (index + 1))
		await _frames(SETTLE_FRAMES)
	_expect(_world_items().size() == kept.size(), "drops repetidos: nenhum item desapareceu (%d de %d)" % [_world_items().size(), kept.size()])
	_expect(kept.size() == spots.size(), "drops repetidos: todos os drops aconteceram (%d de %d)" % [kept.size(), spots.size()])
	for item: WorldItem in kept:
		if not is_instance_valid(item):
			continue
		await _check_collect(item, "repetido")
	_expect(_world_items().is_empty(), "drops repetidos: todos recolhidos")


func _test_multiple_items() -> void:
	_touch("[8] itens A, B, C e D")
	print("[8] Quatro itens soltos ao mesmo tempo")
	await _reset()
	var plan: Array = [
		[Vector3(CRATE1.x, 0.05, 0.85), YAW_POS_Z, &"multi_a", "ITEM A"],
		[Vector3(CRATE1.x, 0.05, 0.2), YAW_POS_Z, &"multi_b", "ITEM B"],
		[Vector3(PILLAR1.x, 0.05, PILLAR1.z + 1.4), YAW_NEG_Z, &"multi_c", "ITEM C"],
		[Vector3(-10.6, 0.05, -3.0), YAW_NEG_X, &"multi_d", "ITEM D"],
	]
	var expected_ids: Array[StringName] = [&"multi_a", &"multi_b", &"multi_c", &"multi_d"]
	for entry: Array in plan:
		await _prepare(entry[0], entry[1], entry[2], entry[3])
		var item: WorldItem = await _drop_ok("item %s" % String(entry[3]))
		if item == null:
			continue
		await _check_safe(item, "item %s" % String(entry[3]))
		await _frames(6)
	_expect(_world_items().size() == 4, "quatro itens no mundo (%d)" % _world_items().size())
	for expected: StringName in expected_ids:
		var found: WorldItem = _find_item(expected)
		_expect(found != null, "item %s continua no mundo" % String(expected))
	# Inventário cheio: o quarto item tem de continuar no chão.
	var full_target: WorldItem = _find_item(&"multi_d")
	if full_target != null:
		await _look_at_item(full_target)
		await _fill_inventory()
		await _look_at_item(full_target)
		await _tap("interact")
		_expect(is_instance_valid(full_target) and not full_target.is_queued_for_deletion(), "inventário cheio: item continua no chão")
		_expect(_world_items().size() == 4, "inventário cheio: nada foi removido do mundo")
		_inventory.clear()
		await _frames(4)
	# Recolher todos.
	for expected: StringName in expected_ids:
		var item: WorldItem = _find_item(expected)
		if item == null:
			continue
		await _check_collect(item, "item %s" % String(expected))
		if _inventory.get_used_slot_count() >= Inventory.SLOT_COUNT:
			_inventory.clear()
			await _frames(4)
	_expect(_world_items().is_empty(), "todos os itens recolhidos ao final")


func _test_pause_with_items() -> void:
	_touch("[9] pausa com item no chão")
	print("[9] Pausa com item solto perto da caixa")
	await _prepare(Vector3(CRATE1.x, 0.05, 0.2), YAW_POS_Z, &"pause_a", "ITEM PAUSA")
	var item: WorldItem = await _drop_ok("pausa: item solto")
	if item == null:
		return
	await _check_safe(item, "pausa")
	await _prepare(Vector3(CRATE1.x, 0.05, 0.2), YAW_POS_Z, &"pause_b", "ITEM PAUSA 2")
	var world_before: int = _world_items().size()
	_scene.pause_session()
	await _frames(6)
	await _tap("inventory_drop")
	_expect(_world_items().size() == world_before, "pausa: G não solta")
	await _tap("inventory_remove")
	_expect(_inventory.get_used_slot_count() == 1, "pausa: R não remove")
	_scene.resume_session()
	await _frames(8)
	_inventory.clear()
	await _frames(4)
	await _check_collect(item, "pausa: item recolhível depois da pausa")


func _test_final_state() -> void:
	_touch("[10] estado final")
	print("[10] Estado final")
	await _reset()
	_expect(_world_items().is_empty(), "final: nenhum item solto")
	_expect(_inventory.get_used_slot_count() == 0, "final: inventário vazio")


# --- Operações do drop ------------------------------------------------------

func _prepare(position: Vector3, yaw: float, item_id: StringName, item_name: String) -> void:
	await _place(position, yaw)
	if not _inventory.is_slot_empty(0):
		_inventory.clear()
	_inventory.add_item(ItemDefinition.new(item_id, item_name))
	_inventory.select_slot(0)
	await _frames(4)


func _drop_ok(label: String) -> WorldItem:
	var before: Array[int] = _item_ids()
	await _tap("inventory_drop")
	var item: WorldItem = _new_item(before)
	if item == null:
		_expect(false, "%s: nenhum item novo no mundo" % label)
		return null
	_expect(_inventory.is_slot_empty(0), "%s: slot 1 ficou vazio" % label)
	return item


func _drop_rejected(label: String) -> void:
	var before: Array[int] = _item_ids()
	var used_before: int = _inventory.get_used_slot_count()
	await _tap("inventory_drop")
	_expect(_world_items().size() == before.size(), "%s: nenhum objeto criado" % label)
	_expect(_inventory.get_used_slot_count() == used_before, "%s: item continua no inventário" % label)
	_expect(_world_items().is_empty() or _new_item(before) == null, "%s: nada novo no mundo" % label)
	var hud: PlayerHud = _scene.get_hud()
	_expect(
		hud != null and hud.get_full_message_text() == ItemDropper.REASON_NO_SPACE,
		"%s: aviso '%s' (recebido '%s')" % [
			label,
			ItemDropper.REASON_NO_SPACE,
			hud.get_full_message_text() if hud != null else "sem HUD",
		]
	)


func _check_safe(item: WorldItem, label: String) -> void:
	if item == null or not is_instance_valid(item):
		return
	var base: Vector3 = item.global_position
	var size: Vector3 = item.get_footprint()
	var ratio: float = _support_ratio(base, size)
	_expect(ratio >= 0.999, "%s: pegada inteiramente apoiada (%.0f%%)" % [label, ratio * 100.0])
	var overlaps: int = _overlaps_at(item, base, size)
	_expect(overlaps == 0, "%s: não nasce dentro de nada (%d colisões)" % [label, overlaps])
	var floor_y: float = _floor_at(base)
	_expect(base.y > floor_y - 0.03, "%s: não afunda (base %.3f, piso %.3f)" % [label, base.y, floor_y])


func _check_settled(item: WorldItem, base_before: Vector3, label: String) -> void:
	await _frames(SETTLE_FRAMES)
	_expect(is_instance_valid(item) and not item.is_queued_for_deletion(), "%s: objeto continua no mundo" % label)
	if not is_instance_valid(item):
		return
	var base: Vector3 = item.global_position
	_expect(base.distance_to(base_before) < SETTLE_DRIFT, "%s: fica onde foi solto (%.3f m)" % [label, base.distance_to(base_before)])
	_expect(base.y > base_before.y - 0.05, "%s: não afunda ao assentar" % label)
	_expect(_overlaps_at(item, base, item.get_footprint()) == 0, "%s: continua fora de tudo ao assentar" % label)


func _check_collect(item: WorldItem, label: String) -> void:
	if item == null or not is_instance_valid(item):
		return
	await _look_at_item(item)
	var focused: Node = _player.get_interaction_detector().get_current_interactable()
	_expect(focused == item, "%s: item é detectado pelo olhar" % label)
	if focused != item:
		return
	var world_before: int = _world_items().size()
	var used_before: int = _inventory.get_used_slot_count()
	await _tap("interact")
	_expect(not is_instance_valid(item) or item.is_queued_for_deletion(), "%s: recolhido com E" % label)
	_expect(_world_items().size() == world_before - 1, "%s: um item a menos no mundo" % label)
	_expect(_inventory.get_used_slot_count() == used_before + 1, "%s: item voltou ao inventário" % label)


# --- Medições independentes do SpaceProbe -----------------------------------

## Fração da pegada (grade 3x3) que repousa na mesma superfície da base.
func _support_ratio(base: Vector3, size: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null:
		return 0.0
	var half_x: float = size.x * 0.5
	var half_z: float = size.z * 0.5
	var from_y: float = base.y + size.y + 0.05
	var to_y: float = base.y - 0.2
	var hits: int = 0
	var total: int = 0
	for ix: int in SUPPORT_GRID:
		for iz: int in SUPPORT_GRID:
			var tx: float = float(ix) / float(SUPPORT_GRID - 1)
			var tz: float = float(iz) / float(SUPPORT_GRID - 1)
			var px: float = base.x - half_x + 2.0 * half_x * tx
			var pz: float = base.z - half_z + 2.0 * half_z * tz
			total += 1
			var hit: Dictionary = _ray(space, Vector3(px, from_y, pz), Vector3(px, to_y, pz))
			if hit.is_empty():
				continue
			if absf((hit["position"] as Vector3).y - base.y) > SUPPORT_TOLERANCE:
				continue
			if (hit.get("normal", Vector3.UP) as Vector3).dot(Vector3.UP) < 0.7:
				continue
			hits += 1
	return float(hits) / float(maxi(total, 1))


## Quantos corpos (fora o próprio item e o jogador) a caixa do item toca.
func _overlaps_at(item: WorldItem, base: Vector3, size: Vector3) -> int:
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null:
		return 999
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, base + Vector3(0.0, size.y * 0.5 + 0.02, 0.0))
	query.collision_mask = 1
	query.exclude = _exclude_for(item)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_shape(query, 8).size()


func _exclude_for(item: WorldItem) -> Array[RID]:
	var exclude: Array[RID] = []
	if _player is CollisionObject3D:
		exclude.append((_player as CollisionObject3D).get_rid())
	if item != null and is_instance_valid(item):
		for child: Node in item.get_children():
			if child is CollisionObject3D:
				exclude.append((child as CollisionObject3D).get_rid())
	return exclude


## Altura da superfície logo abaixo da base do item.
func _floor_at(base: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null:
		return -INF
	var hit: Dictionary = _ray(space, base + Vector3(0, 0.5, 0), base + Vector3(0, -0.6, 0))
	if hit.is_empty():
		return -INF
	return (hit["position"] as Vector3).y


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, 1, _exclude_for(null))
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.hit_from_inside = false
	return space.intersect_ray(params)


func _space() -> PhysicsDirectSpaceState3D:
	if _player == null or not is_instance_valid(_player):
		return null
	return _player.get_world_3d().direct_space_state


# --- Utilidades -------------------------------------------------------------

func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().physics_frame
	_touch()


func _place(position: Vector3, yaw: float) -> void:
	_release_all()
	_player.velocity = Vector3.ZERO
	_player.global_position = position
	_player.set_look(yaw, 0.0)
	await _frames(12)


func _look_at_item(item: WorldItem) -> void:
	if item == null or not is_instance_valid(item):
		return
	var body: Node3D = item.get_node_or_null("Body") as Node3D
	var center: Vector3 = body.global_position if body != null else item.global_position
	center.y += 0.18
	var camera: Camera3D = _player.get_node_or_null("Head/Camera") as Camera3D
	var eye: Vector3 = camera.global_position if camera != null else _player.global_position
	var delta: Vector3 = center - eye
	var horizontal: float = Vector2(delta.x, delta.z).length()
	_player.set_look(atan2(-delta.x, -delta.z), atan2(delta.y, maxf(horizontal, 0.001)))
	await _frames(12)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(3)


func _release_all() -> void:
	for action: String in ["inventory_drop", "inventory_remove", "inventory_slot_1", "inventory_slot_2", "inventory_slot_3", "interact"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _fill_inventory() -> void:
	var index: int = 1
	while _inventory.has_free_slot() and index < 10:
		_inventory.add_item(ItemDefinition.new(StringName("fill_%d" % index), "ENCHIMENTO %d" % index))
		index += 1
	await _frames(4)


func _reset() -> void:
	_release_all()
	await _clear_world_items()
	_inventory.clear()
	await _frames(4)


func _clear_world_items() -> void:
	for node: Node in get_tree().get_nodes_in_group(WorldItem.WORLD_GROUP):
		if is_instance_valid(node):
			node.queue_free()
	await _frames(4)


func _world_items() -> Array:
	var found: Array = []
	for node: Node in get_tree().get_nodes_in_group(WorldItem.WORLD_GROUP):
		if node is WorldItem and is_instance_valid(node) and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _item_ids() -> Array[int]:
	var ids: Array[int] = []
	for node: WorldItem in _world_items():
		ids.append(node.get_instance_id())
	return ids


func _new_item(previous: Array[int]) -> WorldItem:
	for node: WorldItem in _world_items():
		if not previous.has(node.get_instance_id()):
			return node
	return null


func _find_item(item_id: StringName) -> WorldItem:
	for node: WorldItem in _world_items():
		var defined: ItemDefinition = node.get_item()
		if defined != null and defined.id == item_id:
			return node
	return null


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	_touch()
	if condition:
		print("  ✓ ", message)
		return
	_failures.append(message)
	printerr("  ✗ ", message)


func _finish() -> void:
	_finished = true
	_touch("fim")
	_release_all()
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	await get_tree().process_frame
	print("")
	if _failures.is_empty():
		print("DROP OBSTACLE TEST OK — %d verificações aprovadas" % _checks)
		get_tree().quit(0)
		return
	printerr("DROP OBSTACLE TEST FALHOU — %d de %d verificações" % [_failures.size(), _checks])
	for failure: String in _failures:
		printerr("   - ", failure)
	get_tree().quit(1)
